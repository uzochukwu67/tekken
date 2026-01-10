// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IGameEngine.sol";
import "./interfaces/ILiquidityPool.sol";

/**
 * @title BettingPoolV2
 * @notice Pool-based betting system with infinite scalability
 * @dev Uses parimutuel betting model - all bets aggregate into match outcome pools
 *
 * KEY FEATURES:
 * - No loops through users (O(1) settlement for unlimited users)
 * - Market-driven odds based on betting volume
 * - Pull-based claims (users claim their own winnings)
 * - LP exploit prevention (reserves full winner liability before revenue distribution)
 * - Multibet bonuses distributed across match pools
 */
contract BettingPoolV2 is Ownable, ReentrancyGuard {
    // ============ State Variables ============

    IERC20 public immutable leagueToken;
    IGameEngine public immutable gameEngine;
    ILiquidityPool public immutable liquidityPool;

    address public protocolTreasury;
    address public rewardsDistributor;

    // Protocol parameters
    uint256 public constant PROTOCOL_CUT = 3000; // 30% of losing bets
    uint256 public constant SEASON_POOL_SHARE = 200; // 2% of losing bets

    // Multibet bonus rates (basis points)
    uint256 public constant BONUS_2_MATCH = 500;   // 5%
    uint256 public constant BONUS_3_MATCH = 1000;  // 10%
    uint256 public constant BONUS_4_PLUS = 2000;   // 20%

    uint256 public protocolReserve;
    uint256 public seasonRewardPool;
    uint256 public nextBetId;

    // ============ Structs ============

    struct MatchPool {
        uint256 homeWinPool;    // Total LEAGUE bet on HOME_WIN (outcome 1)
        uint256 awayWinPool;    // Total LEAGUE bet on AWAY_WIN (outcome 2)
        uint256 drawPool;       // Total LEAGUE bet on DRAW (outcome 3)
        uint256 totalPool;      // Sum of all three pools
    }

    struct RoundAccounting {
        // Match-level pools (10 matches per round)
        mapping(uint256 => MatchPool) matchPools;

        // Round totals
        uint256 totalBetVolume;         // Total LEAGUE bet in this round
        uint256 totalWinningPool;       // Sum of all winning outcome pools (after settlement)
        uint256 totalLosingPool;        // Sum of all losing outcome pools
        uint256 totalReservedForWinners; // Total owed to winners (calculated from pools)
        uint256 totalClaimed;            // Total LEAGUE claimed so far

        // Revenue distribution
        uint256 protocolRevenueShare;   // Protocol's share of net revenue
        uint256 lpRevenueShare;          // LP's share of net revenue
        uint256 seasonRevenueShare;      // Season pool share
        bool revenueDistributed;         // Has revenue been distributed?

        // Timestamps
        uint256 roundStartTime;
        uint256 roundEndTime;
        bool settled;
    }

    struct Prediction {
        uint256 matchIndex;         // 0-9
        uint8 predictedOutcome;     // 1=HOME_WIN, 2=AWAY_WIN, 3=DRAW
        uint256 amountInPool;       // How much LEAGUE was added to this pool
    }

    struct Bet {
        address bettor;
        uint256 roundId;
        uint256 amount;             // User's stake (without bonus)
        uint256 bonus;              // Protocol bonus added
        Prediction[] predictions;   // Match predictions
        bool settled;               // Has round been settled?
        bool claimed;               // Has user claimed winnings?
    }

    // ============ Mappings ============

    mapping(uint256 => RoundAccounting) public roundAccounting;
    mapping(uint256 => Bet) public bets;
    mapping(address => uint256[]) public userBets;

    // ============ Events ============

    event BetPlaced(
        uint256 indexed betId,
        address indexed bettor,
        uint256 indexed roundId,
        uint256 amount,
        uint256 bonus,
        uint256[] matchIndices,
        uint8[] outcomes
    );

    event RoundSettled(
        uint256 indexed roundId,
        uint256 totalWinningPool,
        uint256 totalLosingPool,
        uint256 totalReserved
    );

    event WinningsClaimed(
        uint256 indexed betId,
        address indexed bettor,
        uint256 payout
    );

    event BetLost(uint256 indexed betId, address indexed bettor);

    event RoundRevenueFinalized(
        uint256 indexed roundId,
        uint256 netRevenue,
        uint256 toProtocol,
        uint256 toLP,
        uint256 toSeason
    );

    event ProtocolReserveFunded(address indexed funder, uint256 amount);

    // ============ Constructor ============

    constructor(
        address _leagueToken,
        address _gameEngine,
        address _liquidityPool,
        address _protocolTreasury,
        address _rewardsDistributor,
        address _initialOwner
    ) Ownable(_initialOwner) {
        require(_leagueToken != address(0), "Invalid token");
        require(_gameEngine != address(0), "Invalid game engine");
        require(_liquidityPool != address(0), "Invalid liquidity pool");

        leagueToken = IERC20(_leagueToken);
        gameEngine = IGameEngine(_gameEngine);
        liquidityPool = ILiquidityPool(_liquidityPool);
        protocolTreasury = _protocolTreasury;
        rewardsDistributor = _rewardsDistributor;
    }

    // ============ Betting Functions ============

    /**
     * @notice Place a bet on multiple match outcomes
     * @param matchIndices Array of match indices (0-9)
     * @param outcomes Array of predicted outcomes (1=HOME, 2=AWAY, 3=DRAW)
     * @param amount Total LEAGUE to bet (protocol bonus added on top)
     */
    function placeBet(
        uint256[] calldata matchIndices,
        uint8[] calldata outcomes,
        uint256 amount
    ) external nonReentrant returns (uint256 betId) {
        require(amount > 0, "Amount must be > 0");
        require(matchIndices.length == outcomes.length, "Array length mismatch");
        require(matchIndices.length > 0 && matchIndices.length <= 10, "Invalid bet count");

        uint256 currentRoundId = gameEngine.getCurrentRound();
        require(currentRoundId > 0, "No active round");
        require(!gameEngine.isRoundSettled(currentRoundId), "Round already settled");

        // Transfer user's stake
        require(
            leagueToken.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        RoundAccounting storage accounting = roundAccounting[currentRoundId];

        // Calculate multibet bonus (paid by protocol)
        uint256 bonus = _calculateMultibetBonus(amount, matchIndices.length);
        require(protocolReserve >= bonus, "Insufficient protocol reserve for bonus");
        protocolReserve -= bonus;

        uint256 totalWithBonus = amount + bonus;
        accounting.totalBetVolume += totalWithBonus;

        // Split bet evenly across matches and add to pools
        uint256 amountPerMatch = totalWithBonus / matchIndices.length;

        // Store bet first (without predictions)
        betId = nextBetId++;
        Bet storage bet = bets[betId];
        bet.bettor = msg.sender;
        bet.roundId = currentRoundId;
        bet.amount = amount;
        bet.bonus = bonus;
        bet.settled = false;
        bet.claimed = false;

        // Now add predictions and update pools
        for (uint256 i = 0; i < matchIndices.length; i++) {
            uint256 matchIndex = matchIndices[i];
            uint8 outcome = outcomes[i];

            require(matchIndex < 10, "Invalid match index");
            require(outcome >= 1 && outcome <= 3, "Invalid outcome");

            // Add to appropriate match pool
            MatchPool storage pool = accounting.matchPools[matchIndex];

            if (outcome == 1) {
                pool.homeWinPool += amountPerMatch;
            } else if (outcome == 2) {
                pool.awayWinPool += amountPerMatch;
            } else {
                pool.drawPool += amountPerMatch;
            }
            pool.totalPool += amountPerMatch;

            // Push prediction to storage array
            bet.predictions.push(Prediction({
                matchIndex: matchIndex,
                predictedOutcome: outcome,
                amountInPool: amountPerMatch
            }));
        }

        userBets[msg.sender].push(betId);

        emit BetPlaced(
            betId,
            msg.sender,
            currentRoundId,
            amount,
            bonus,
            matchIndices,
            outcomes
        );
    }

    /**
     * @notice Claim winnings for a bet (pull pattern)
     * @param betId The bet ID to claim
     */
    function claimWinnings(uint256 betId) external nonReentrant {
        Bet storage bet = bets[betId];
        require(bet.bettor == msg.sender, "Not your bet");
        require(!bet.claimed, "Already claimed");

        RoundAccounting storage accounting = roundAccounting[bet.roundId];
        require(accounting.settled, "Round not settled");

        // Calculate if bet won and payout amount
        (bool won, uint256 payout) = _calculateBetPayout(betId);

        bet.claimed = true;

        if (won && payout > 0) {
            accounting.totalClaimed += payout;

            // Transfer winnings
            require(leagueToken.transfer(msg.sender, payout), "Transfer failed");

            emit WinningsClaimed(betId, msg.sender, payout);
        } else {
            emit BetLost(betId, msg.sender);
        }
    }

    // ============ Settlement Functions ============

    /**
     * @notice Settle round after VRF generates results (called by admin or automation)
     * @param roundId The round to settle
     */
    function settleRound(uint256 roundId) external nonReentrant {
        require(gameEngine.isRoundSettled(roundId), "Round not settled in GameEngine");

        RoundAccounting storage accounting = roundAccounting[roundId];
        require(!accounting.settled, "Already settled");

        // Calculate winning and losing pools by iterating MATCHES (not bets!)
        // This is O(10) = constant time, works for unlimited users
        for (uint256 matchIndex = 0; matchIndex < 10; matchIndex++) {
            IGameEngine.Match memory matchResult = gameEngine.getMatch(roundId, matchIndex);
            MatchPool storage pool = accounting.matchPools[matchIndex];

            IGameEngine.MatchOutcome winningOutcome = matchResult.outcome;
            uint256 winningPool;
            uint256 losingPool;

            if (winningOutcome == IGameEngine.MatchOutcome.HOME_WIN) {
                // HOME won
                winningPool = pool.homeWinPool;
                losingPool = pool.awayWinPool + pool.drawPool;
            } else if (winningOutcome == IGameEngine.MatchOutcome.AWAY_WIN) {
                // AWAY won
                winningPool = pool.awayWinPool;
                losingPool = pool.homeWinPool + pool.drawPool;
            } else if (winningOutcome == IGameEngine.MatchOutcome.DRAW) {
                // DRAW
                winningPool = pool.drawPool;
                losingPool = pool.homeWinPool + pool.awayWinPool;
            } else {
                // No result yet, skip
                continue;
            }

            accounting.totalWinningPool += winningPool;
            accounting.totalLosingPool += losingPool;
        }

        // Calculate total owed to winners (prevents LP exploit)
        accounting.totalReservedForWinners = _calculateTotalWinningPayouts(roundId);

        accounting.settled = true;
        accounting.roundEndTime = block.timestamp;

        emit RoundSettled(
            roundId,
            accounting.totalWinningPool,
            accounting.totalLosingPool,
            accounting.totalReservedForWinners
        );
    }

    /**
     * @notice Finalize round revenue distribution (after claim period)
     * @param roundId The round to finalize
     */
    function finalizeRoundRevenue(uint256 roundId) external nonReentrant {
        RoundAccounting storage accounting = roundAccounting[roundId];
        require(accounting.settled, "Round not settled");
        require(!accounting.revenueDistributed, "Already distributed");

        // Optional: wait 24-48 hours for claims
        // require(block.timestamp >= accounting.roundEndTime + 24 hours, "Wait for claim period");

        // Calculate net revenue (totalLosingPool - totalReservedForWinners)
        uint256 totalLosingPool = accounting.totalLosingPool;
        uint256 totalOwed = accounting.totalReservedForWinners;

        require(totalLosingPool >= totalOwed, "Round was unprofitable");
        uint256 netRevenue = totalLosingPool - totalOwed;

        // Distribute revenue
        uint256 toProtocol = (netRevenue * 7000) / 10000; // 70% to protocol
        uint256 toSeason = (netRevenue * SEASON_POOL_SHARE) / 10000; // 2%
        uint256 toLP = netRevenue - toProtocol - toSeason; // Remaining ~28%

        accounting.protocolRevenueShare = toProtocol;
        accounting.lpRevenueShare = toLP;
        accounting.seasonRevenueShare = toSeason;
        accounting.revenueDistributed = true;

        // Add to protocol reserve
        protocolReserve += toProtocol;

        // Add to LP pool (increases vLP token value)
        if (toLP > 0) {
            require(leagueToken.approve(address(liquidityPool), toLP), "Approval failed");
            liquidityPool.addLiquidity(toLP);
        }

        // Add to season pool
        seasonRewardPool += toSeason;

        emit RoundRevenueFinalized(roundId, netRevenue, toProtocol, toLP, toSeason);
    }

    // ============ Internal Helper Functions ============

    /**
     * @notice Calculate multibet bonus based on number of matches
     */
    function _calculateMultibetBonus(uint256 amount, uint256 numMatches)
        internal
        pure
        returns (uint256)
    {
        if (numMatches == 1) return 0;
        if (numMatches == 2) return (amount * BONUS_2_MATCH) / 10000;
        if (numMatches == 3) return (amount * BONUS_3_MATCH) / 10000;
        return (amount * BONUS_4_PLUS) / 10000; // 4+ matches
    }

    /**
     * @notice Calculate bet payout (all predictions must be correct for multibet)
     */
    function _calculateBetPayout(uint256 betId)
        internal
        view
        returns (bool won, uint256 payout)
    {
        Bet storage bet = bets[betId];
        RoundAccounting storage accounting = roundAccounting[bet.roundId];

        bool allCorrect = true;
        uint256 totalPayout = 0;

        for (uint256 i = 0; i < bet.predictions.length; i++) {
            Prediction memory pred = bet.predictions[i];
            IGameEngine.Match memory matchResult = gameEngine.getMatch(
                bet.roundId,
                pred.matchIndex
            );

            // Check if prediction is correct
            // Compare enum to uint8 by casting pred.predictedOutcome to the enum
            IGameEngine.MatchOutcome predictedEnum;
            if (pred.predictedOutcome == 1) predictedEnum = IGameEngine.MatchOutcome.HOME_WIN;
            else if (pred.predictedOutcome == 2) predictedEnum = IGameEngine.MatchOutcome.AWAY_WIN;
            else predictedEnum = IGameEngine.MatchOutcome.DRAW;

            if (matchResult.outcome != predictedEnum) {
                allCorrect = false;
                break; // Multibet failed
            }

            // Calculate payout for this match using pool ratios
            MatchPool storage pool = accounting.matchPools[pred.matchIndex];
            uint256 winningPool = _getWinningPoolAmount(pool, pred.predictedOutcome);
            uint256 losingPool = pool.totalPool - winningPool;

            if (winningPool == 0) {
                // No one bet on this outcome (shouldn't happen)
                totalPayout += pred.amountInPool;
                continue;
            }

            // Calculate share of losing pool (70% goes to winners)
            uint256 distributedLosingPool = (losingPool * 7000) / 10000;

            // User's share is proportional to their bet in the winning pool
            uint256 multiplier = 1e18 + (distributedLosingPool * 1e18) / winningPool;
            uint256 matchPayout = (pred.amountInPool * multiplier) / 1e18;

            totalPayout += matchPayout;
        }

        return (allCorrect, totalPayout);
    }

    /**
     * @notice Calculate total payouts owed to ALL winners (prevents LP exploit)
     */
    function _calculateTotalWinningPayouts(uint256 roundId)
        internal
        view
        returns (uint256 totalOwed)
    {
        RoundAccounting storage accounting = roundAccounting[roundId];

        for (uint256 matchIndex = 0; matchIndex < 10; matchIndex++) {
            IGameEngine.Match memory matchResult = gameEngine.getMatch(roundId, matchIndex);
            MatchPool storage pool = accounting.matchPools[matchIndex];

            IGameEngine.MatchOutcome winningOutcome = matchResult.outcome;
            if (winningOutcome == IGameEngine.MatchOutcome.PENDING) continue; // No result yet

            // Convert enum to uint8 for _getWinningPoolAmount
            uint8 outcomeAsUint8;
            if (winningOutcome == IGameEngine.MatchOutcome.HOME_WIN) outcomeAsUint8 = 1;
            else if (winningOutcome == IGameEngine.MatchOutcome.AWAY_WIN) outcomeAsUint8 = 2;
            else outcomeAsUint8 = 3; // DRAW

            uint256 winningPool = _getWinningPoolAmount(pool, outcomeAsUint8);
            uint256 losingPool = pool.totalPool - winningPool;

            if (winningPool == 0) {
                // No winners (shouldn't happen), no payout
                continue;
            }

            // Calculate total to be distributed to winners (70% of losing pool)
            uint256 distributedLosingPool = (losingPool * 7000) / 10000;

            // Total owed = original winning pool + their share of losing pool
            uint256 totalOwedForMatch = winningPool + distributedLosingPool;
            totalOwed += totalOwedForMatch;
        }

        return totalOwed;
    }

    /**
     * @notice Get the winning pool amount for a given outcome
     */
    function _getWinningPoolAmount(MatchPool storage pool, uint8 outcome)
        internal
        view
        returns (uint256)
    {
        if (outcome == 1) return pool.homeWinPool;
        if (outcome == 2) return pool.awayWinPool;
        if (outcome == 3) return pool.drawPool;
        return 0;
    }

    // ============ Admin Functions ============

    /**
     * @notice Fund protocol reserve (for bonus payouts)
     */
    function fundProtocolReserve(uint256 amount) external {
        require(
            leagueToken.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );
        protocolReserve += amount;
        emit ProtocolReserveFunded(msg.sender, amount);
    }

    /**
     * @notice Update protocol treasury address
     */
    function setProtocolTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid address");
        protocolTreasury = _treasury;
    }

    /**
     * @notice Update rewards distributor address
     */
    function setRewardsDistributor(address _distributor) external onlyOwner {
        require(_distributor != address(0), "Invalid address");
        rewardsDistributor = _distributor;
    }

    // ============ View Functions ============

    /**
     * @notice Get match pool data for odds calculation
     */
    function getMatchPoolData(uint256 roundId, uint256 matchIndex)
        external
        view
        returns (
            uint256 homeWinPool,
            uint256 awayWinPool,
            uint256 drawPool,
            uint256 totalPool
        )
    {
        MatchPool storage pool = roundAccounting[roundId].matchPools[matchIndex];
        return (pool.homeWinPool, pool.awayWinPool, pool.drawPool, pool.totalPool);
    }

    /**
     * @notice Get user's bet IDs
     */
    function getUserBets(address user) external view returns (uint256[] memory) {
        return userBets[user];
    }

    /**
     * @notice Get bet details
     */
    function getBet(uint256 betId)
        external
        view
        returns (
            address bettor,
            uint256 roundId,
            uint256 amount,
            uint256 bonus,
            bool settled,
            bool claimed
        )
    {
        Bet storage bet = bets[betId];
        return (
            bet.bettor,
            bet.roundId,
            bet.amount,
            bet.bonus,
            bet.settled,
            bet.claimed
        );
    }

    /**
     * @notice Get round accounting data
     */
    function getRoundAccounting(uint256 roundId)
        external
        view
        returns (
            uint256 totalBetVolume,
            uint256 totalWinningPool,
            uint256 totalLosingPool,
            uint256 totalReservedForWinners,
            uint256 totalClaimed,
            bool settled,
            bool revenueDistributed
        )
    {
        RoundAccounting storage accounting = roundAccounting[roundId];
        return (
            accounting.totalBetVolume,
            accounting.totalWinningPool,
            accounting.totalLosingPool,
            accounting.totalReservedForWinners,
            accounting.totalClaimed,
            accounting.settled,
            accounting.revenueDistributed
        );
    }
}

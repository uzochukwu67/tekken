// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IGameEngine.sol";

/**
 * @title SeasonPredictorV2
 * @notice Efficient season winner prediction system with 2% revenue pool
 * @dev NO LOOPS - Uses counters and mappings for O(1) operations
 *
 * HOW IT WORKS:
 * 1. Users predict winning team (free, once per season)
 * 2. Contract tracks predictor count per team
 * 3. When season ends, owner marks winning team
 * 4. Winners claim their share: (pool / predictorCount)
 * 5. NO loops needed - all O(1) operations
 */
contract SeasonPredictorV2 is Ownable {

    // ============================================
    // STATE VARIABLES
    // ============================================

    IERC20 public immutable leagueToken;
    IGameEngine public immutable gameEngine;

    /// @notice User predictions per season (seasonId => user => teamId+1, 0 = no prediction)
    mapping(uint256 => mapping(address => uint256)) public userPredictions;

    /// @notice Count of predictors per team (seasonId => teamId => count)
    mapping(uint256 => mapping(uint256 => uint256)) public teamPredictorCount;

    /// @notice Prize pool per season (seasonId => amount)
    mapping(uint256 => uint256) public seasonPrizePool;

    /// @notice Winning team per season (seasonId => teamId+1, 0 = not set)
    mapping(uint256 => uint256) public seasonWinningTeam;

    /// @notice Claimed status per user per season
    mapping(uint256 => mapping(address => bool)) public hasClaimed;

    /// @notice Total predictions made across all seasons
    uint256 public totalPredictions;

    // ============================================
    // EVENTS
    // ============================================

    event PredictionMade(
        address indexed user,
        uint256 indexed seasonId,
        uint256 teamId,
        uint256 timestamp
    );

    event PrizePoolFunded(
        uint256 indexed seasonId,
        uint256 amount,
        uint256 newTotal
    );

    event WinnerDeclared(
        uint256 indexed seasonId,
        uint256 winningTeamId,
        uint256 prizePool,
        uint256 winnersCount
    );

    event PrizeClaimed(
        address indexed user,
        uint256 indexed seasonId,
        uint256 amount
    );

    event UnclaimedPrizeWithdrawn(
        uint256 indexed seasonId,
        address indexed recipient,
        uint256 amount
    );

    // ============================================
    // ERRORS
    // ============================================

    error InvalidTeamId();
    error InvalidSeason();
    error SeasonNotActive();
    error PredictionsLocked();
    error AlreadyPredicted();
    error SeasonNotCompleted();
    error WinnerNotDeclared();
    error AlreadyClaimed();
    error IncorrectPrediction();
    error NoPrizeAvailable();
    error TransferFailed();

    // ============================================
    // CONSTRUCTOR
    // ============================================

    constructor(
        address _leagueToken,
        address _gameEngine,
        address _initialOwner
    ) Ownable(_initialOwner) {
        require(_leagueToken != address(0), "Invalid token");
        require(_gameEngine != address(0), "Invalid engine");

        leagueToken = IERC20(_leagueToken);
        gameEngine = IGameEngine(_gameEngine);
    }

    // ============================================
    // USER FUNCTIONS
    // ============================================

    /**
     * @notice Make a free prediction for season winner
     * @dev Can only predict before round 1 starts (during round 0)
     * @param teamId Team predicted to win (0-19)
     */
    function makePrediction(uint256 teamId) external {
        // Validate team ID
        if (teamId >= 20) revert InvalidTeamId();

        // Get current season
        uint256 seasonId = gameEngine.getCurrentSeason();
        if (seasonId == 0) revert InvalidSeason();

        // Get season info
        IGameEngine.Season memory season = gameEngine.getSeason(seasonId);
        if (!season.active) revert SeasonNotActive();

        // Can only predict during round 0 (before season starts)
        if (season.currentRound > 0) revert PredictionsLocked();

        // Check if user already predicted
        if (userPredictions[seasonId][msg.sender] != 0) revert AlreadyPredicted();

        // Store prediction (add 1 to distinguish from default 0)
        userPredictions[seasonId][msg.sender] = teamId + 1;

        // Increment team predictor count
        teamPredictorCount[seasonId][teamId]++;

        // Increment total predictions
        totalPredictions++;

        emit PredictionMade(msg.sender, seasonId, teamId, block.timestamp);
    }

    /**
     * @notice Claim prize for correct prediction
     * @param seasonId Season to claim for
     */
    function claimPrize(uint256 seasonId) external {
        // Check if winner declared
        uint256 winningTeamPlusOne = seasonWinningTeam[seasonId];
        if (winningTeamPlusOne == 0) revert WinnerNotDeclared();

        // Check if already claimed
        if (hasClaimed[seasonId][msg.sender]) revert AlreadyClaimed();

        // Get user's prediction
        uint256 predictedTeamPlusOne = userPredictions[seasonId][msg.sender];
        if (predictedTeamPlusOne == 0) revert IncorrectPrediction();

        // Check if prediction was correct
        if (predictedTeamPlusOne != winningTeamPlusOne) revert IncorrectPrediction();

        // Get prize pool and winner count
        uint256 prizePool = seasonPrizePool[seasonId];
        uint256 winningTeamId = winningTeamPlusOne - 1;
        uint256 winnersCount = teamPredictorCount[seasonId][winningTeamId];

        // Calculate share
        if (winnersCount == 0 || prizePool == 0) revert NoPrizeAvailable();
        uint256 share = prizePool / winnersCount;

        if (share == 0) revert NoPrizeAvailable();

        // Mark as claimed
        hasClaimed[seasonId][msg.sender] = true;

        // Transfer prize
        bool success = leagueToken.transfer(msg.sender, share);
        if (!success) revert TransferFailed();

        emit PrizeClaimed(msg.sender, seasonId, share);
    }

    // ============================================
    // OWNER FUNCTIONS
    // ============================================

    /**
     * @notice Fund prize pool for a season (called by BettingPool)
     * @dev Anyone can fund, typically BettingPool sends 2% of revenue
     * @param seasonId Season to fund
     * @param amount Amount to add
     */
    function fundPrizePool(uint256 seasonId, uint256 amount) external {
        bool success = leagueToken.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        seasonPrizePool[seasonId] += amount;

        emit PrizePoolFunded(seasonId, amount, seasonPrizePool[seasonId]);
    }

    /**
     * @notice Declare winning team after season completes
     * @dev Owner calls this once season is settled by GameEngine
     * @param seasonId Season ID
     */
    function declareWinner(uint256 seasonId) external onlyOwner {
        // Verify season is completed
        IGameEngine.Season memory season = gameEngine.getSeason(seasonId);
        if (!season.completed) revert SeasonNotCompleted();

        // Check if already declared
        if (seasonWinningTeam[seasonId] != 0) {
            revert("Winner already declared");
        }

        // Get winning team from game engine
        uint256 winningTeamId = season.winningTeamId;

        // Store winning team (add 1 to distinguish from default 0)
        seasonWinningTeam[seasonId] = winningTeamId + 1;

        // Get stats for event
        uint256 prizePool = seasonPrizePool[seasonId];
        uint256 winnersCount = teamPredictorCount[seasonId][winningTeamId];

        emit WinnerDeclared(seasonId, winningTeamId, prizePool, winnersCount);
    }

    /**
     * @notice Withdraw unclaimed prizes after deadline
     * @dev Only callable if no winners or after sufficient time passed
     * @param seasonId Season to withdraw from
     * @param recipient Address to receive funds
     */
    function withdrawUnclaimedPrize(
        uint256 seasonId,
        address recipient
    ) external onlyOwner {
        require(recipient != address(0), "Invalid recipient");

        // Winner must be declared
        uint256 winningTeamPlusOne = seasonWinningTeam[seasonId];
        if (winningTeamPlusOne == 0) revert WinnerNotDeclared();

        uint256 prizePool = seasonPrizePool[seasonId];
        if (prizePool == 0) revert NoPrizeAvailable();

        uint256 winningTeamId = winningTeamPlusOne - 1;
        uint256 winnersCount = teamPredictorCount[seasonId][winningTeamId];

        // Only allow withdrawal if no winners
        require(winnersCount == 0, "Has winners - cannot withdraw");

        // Reset prize pool
        seasonPrizePool[seasonId] = 0;

        // Transfer unclaimed prize
        bool success = leagueToken.transfer(recipient, prizePool);
        if (!success) revert TransferFailed();

        emit UnclaimedPrizeWithdrawn(seasonId, recipient, prizePool);
    }

    // ============================================
    // VIEW FUNCTIONS
    // ============================================

    /**
     * @notice Get user's prediction for a season
     * @param seasonId Season ID
     * @param user User address
     * @return teamId Team predicted (0-19), or type(uint256).max if no prediction
     */
    function getUserPrediction(uint256 seasonId, address user)
        external
        view
        returns (uint256)
    {
        uint256 prediction = userPredictions[seasonId][user];
        if (prediction == 0) return type(uint256).max;
        return prediction - 1;
    }

    /**
     * @notice Get number of predictors for a team
     * @param seasonId Season ID
     * @param teamId Team ID (0-19)
     * @return count Number of predictors
     */
    function getTeamPredictorCount(uint256 seasonId, uint256 teamId)
        external
        view
        returns (uint256)
    {
        return teamPredictorCount[seasonId][teamId];
    }

    /**
     * @notice Get prize pool for a season
     * @param seasonId Season ID
     * @return amount Prize pool amount
     */
    function getSeasonPrizePool(uint256 seasonId)
        external
        view
        returns (uint256)
    {
        return seasonPrizePool[seasonId];
    }

    /**
     * @notice Get winning team for a season
     * @param seasonId Season ID
     * @return teamId Winning team (0-19), or type(uint256).max if not declared
     */
    function getWinningTeam(uint256 seasonId)
        external
        view
        returns (uint256)
    {
        uint256 winningTeamPlusOne = seasonWinningTeam[seasonId];
        if (winningTeamPlusOne == 0) return type(uint256).max;
        return winningTeamPlusOne - 1;
    }

    /**
     * @notice Check if user can claim prize and how much
     * @param seasonId Season ID
     * @param user User address
     * @return canClaim Whether user can claim
     * @return amount Prize amount if claimable
     */
    function canClaimPrize(uint256 seasonId, address user)
        external
        view
        returns (bool canClaim, uint256 amount)
    {
        // Check if winner declared
        uint256 winningTeamPlusOne = seasonWinningTeam[seasonId];
        if (winningTeamPlusOne == 0) return (false, 0);

        // Check if already claimed
        if (hasClaimed[seasonId][user]) return (false, 0);

        // Get user's prediction
        uint256 predictedTeamPlusOne = userPredictions[seasonId][user];
        if (predictedTeamPlusOne == 0) return (false, 0);

        // Check if prediction correct
        if (predictedTeamPlusOne != winningTeamPlusOne) return (false, 0);

        // Calculate share
        uint256 prizePool = seasonPrizePool[seasonId];
        uint256 winningTeamId = winningTeamPlusOne - 1;
        uint256 winnersCount = teamPredictorCount[seasonId][winningTeamId];

        if (winnersCount == 0 || prizePool == 0) return (false, 0);

        uint256 share = prizePool / winnersCount;
        return (share > 0, share);
    }

    /**
     * @notice Get prediction statistics for a season
     * @param seasonId Season ID
     * @return prizePool Total prize pool
     * @return totalPredictors Total predictors across all teams
     * @return winnerDeclared Whether winner has been declared
     * @return winningTeamId Winning team (if declared)
     * @return winnersCount Number of correct predictors (if declared)
     */
    function getSeasonStats(uint256 seasonId)
        external
        view
        returns (
            uint256 prizePool,
            uint256 totalPredictors,
            bool winnerDeclared,
            uint256 winningTeamId,
            uint256 winnersCount
        )
    {
        prizePool = seasonPrizePool[seasonId];

        // Calculate total predictors (sum across all teams)
        for (uint256 i = 0; i < 20; i++) {
            totalPredictors += teamPredictorCount[seasonId][i];
        }

        uint256 winningTeamPlusOne = seasonWinningTeam[seasonId];
        winnerDeclared = (winningTeamPlusOne != 0);

        if (winnerDeclared) {
            winningTeamId = winningTeamPlusOne - 1;
            winnersCount = teamPredictorCount[seasonId][winningTeamId];
        } else {
            winningTeamId = type(uint256).max;
            winnersCount = 0;
        }
    }

    /**
     * @notice Get prediction distribution (for frontend display)
     * @param seasonId Season ID
     * @return counts Array of predictor counts per team (index = teamId)
     */
    function getPredictionDistribution(uint256 seasonId)
        external
        view
        returns (uint256[20] memory counts)
    {
        for (uint256 i = 0; i < 20; i++) {
            counts[i] = teamPredictorCount[seasonId][i];
        }
    }
}

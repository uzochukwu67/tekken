// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/DataTypes.sol";
import "../libraries/Constants.sol";
import "../core/BettingCore.sol";
import "./SwapRouter.sol";

/**
 * @title BettingRouter
 * @notice User-facing router for betting operations with LBT
 * @dev Handles LBT betting with optional token swaps and convenience functions
 *
 * Features:
 * - Single-token (LBT) betting
 * - Optional swap from USDC/USDT/ETH to LBT
 * - Batch bet placement
 * - Parlay bet helper
 * - Deadline protection
 * - Slippage protection for odds
 */
contract BettingRouter is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // ============ State ============

    /// @notice Core betting contract
    BettingCore public bettingCore;

    /// @notice LBT token address
    IERC20 public lbtToken;

    /// @notice Swap router for USDC/USDT/ETH -> LBT
    SwapRouter public swapRouter;

    /// @notice Default slippage tolerance (basis points)
    uint256 public defaultSlippageBps = 100; // 1%

    // ============ Events ============

    event BetPlaced(
        address indexed bettor,
        uint256 indexed betId,
        uint256 amount
    );

    event ParlayPlaced(
        address indexed bettor,
        uint256 betId,
        uint256 totalAmount
    );

    event BatchBetsPlaced(
        address indexed bettor,
        uint256[] betIds
    );

    event WinningsClaimed(
        address indexed bettor,
        uint256 indexed betId,
        uint256 amount
    );

    event BetPlacedWithSwap(
        address indexed bettor,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 lbtReceived,
        uint256 betId
    );

    // ============ Errors ============

    error DeadlineExpired();
    error OddsSlippageExceeded();
    error InsufficientAllowance();
    error InvalidBettingCore();
    error EmptyBets();
    error ArrayLengthMismatch();
    error ZeroAmount();
    error InvalidSwapRouter();

    // ============ Structs ============

    /// @notice Parameters for a single bet placement
    struct BetParams {
        uint256 matchIndex;
        uint8 prediction;       // 1=HOME, 2=AWAY, 3=DRAW
        uint256 amount;
        uint256 minOdds;        // Minimum acceptable odds (slippage protection)
    }

    /// @notice Parameters for parlay bet
    struct ParlayParams {
        uint256[] matchIndices;
        uint8[] predictions;
        uint256 amount;
        uint256 minMultiplier;  // Minimum acceptable multiplier
    }

    // ============ Constructor ============

    constructor(
        address _bettingCore,
        address _lbtToken,
        address _swapRouter,
        address _initialOwner
    ) Ownable(_initialOwner) {
        require(_bettingCore != address(0), "Invalid betting core");
        require(_lbtToken != address(0), "Invalid LBT token");

        bettingCore = BettingCore(_bettingCore);
        lbtToken = IERC20(_lbtToken);

        if (_swapRouter != address(0)) {
            swapRouter = SwapRouter(payable(_swapRouter));
        }
    }

    // ============ Betting Functions (LBT Direct) ============

    /**
     * @notice Place a single bet with LBT (direct, no swap)
     * @param params Bet parameters
     * @param deadline Transaction deadline
     * @return betId ID of placed bet
     */
    function placeBet(
        BetParams calldata params,
        uint256 deadline
    ) external nonReentrant returns (uint256 betId) {
        // Deadline check
        if (block.timestamp > deadline) revert DeadlineExpired();

        // Amount check
        if (params.amount == 0) revert ZeroAmount();

        // Check current odds meet minimum
        uint256 currentOdds = _getCurrentOdds(params.matchIndex, params.prediction);
        if (currentOdds < params.minOdds) revert OddsSlippageExceeded();

        // Transfer LBT from user
        lbtToken.safeTransferFrom(msg.sender, address(this), params.amount);

        // Approve betting core
        lbtToken.approve(address(bettingCore), params.amount);

        // Build arrays for single bet
        uint256[] memory matchIndices = new uint256[](1);
        matchIndices[0] = params.matchIndex;

        uint8[] memory predictions = new uint8[](1);
        predictions[0] = params.prediction;

        // Place bet via core (NEW SIGNATURE: no token parameter!)
        betId = bettingCore.placeBet(params.amount, matchIndices, predictions);

        emit BetPlaced(msg.sender, betId, params.amount);
    }

    /**
     * @notice Place multiple bets in a single transaction (LBT direct)
     * @param bets Array of bet parameters
     * @param deadline Transaction deadline
     * @return betIds Array of placed bet IDs
     */
    function placeBatchBets(
        BetParams[] calldata bets,
        uint256 deadline
    ) external nonReentrant returns (uint256[] memory betIds) {
        if (block.timestamp > deadline) revert DeadlineExpired();
        if (bets.length == 0) revert EmptyBets();

        // Calculate total amount
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < bets.length; i++) {
            totalAmount += bets[i].amount;
        }

        // Transfer total LBT amount
        lbtToken.safeTransferFrom(msg.sender, address(this), totalAmount);

        // Approve betting core
        lbtToken.approve(address(bettingCore), totalAmount);

        // Place each bet
        betIds = new uint256[](bets.length);
        for (uint256 i = 0; i < bets.length; i++) {
            // Check odds slippage
            uint256 currentOdds = _getCurrentOdds(bets[i].matchIndex, bets[i].prediction);
            if (currentOdds < bets[i].minOdds) revert OddsSlippageExceeded();

            // Build arrays for single bet
            uint256[] memory matchIndices = new uint256[](1);
            matchIndices[0] = bets[i].matchIndex;

            uint8[] memory predictions = new uint8[](1);
            predictions[0] = bets[i].prediction;

            // NEW SIGNATURE: no token parameter
            betIds[i] = bettingCore.placeBet(bets[i].amount, matchIndices, predictions);
        }

        emit BatchBetsPlaced(msg.sender, betIds);
    }

    /**
     * @notice Place a parlay bet with LBT (direct)
     * @param params Parlay parameters
     * @param deadline Transaction deadline
     * @return betId ID of placed parlay bet
     */
    function placeParlay(
        ParlayParams calldata params,
        uint256 deadline
    ) external nonReentrant returns (uint256 betId) {
        if (block.timestamp > deadline) revert DeadlineExpired();
        if (params.matchIndices.length != params.predictions.length) revert ArrayLengthMismatch();
        if (params.matchIndices.length < 2) revert EmptyBets();
        if (params.amount == 0) revert ZeroAmount();

        // Check multiplier meets minimum (slippage protection)
        uint256 currentMultiplier = _calculateParlayMultiplier(
            params.matchIndices,
            params.predictions
        );
        if (currentMultiplier < params.minMultiplier) revert OddsSlippageExceeded();

        // Transfer LBT
        lbtToken.safeTransferFrom(msg.sender, address(this), params.amount);

        // Approve betting core
        lbtToken.approve(address(bettingCore), params.amount);

        // Place parlay (multiple legs in one bet) - NEW SIGNATURE
        betId = bettingCore.placeBet(params.amount, params.matchIndices, params.predictions);

        emit ParlayPlaced(msg.sender, betId, params.amount);
    }

    // ============ Betting Functions (With Swap) ============

    /**
     * @notice Place bet by swapping from USDC/USDT/ETH to LBT first
     * @param tokenIn Input token (USDC/USDT) or address(0) for ETH
     * @param amountIn Amount of input token
     * @param minLBTOut Minimum LBT to receive from swap
     * @param params Bet parameters (amount should match expected LBT out)
     * @param deadline Transaction deadline
     * @return betId ID of placed bet
     */
    function placeBetWithSwap(
        address tokenIn,
        uint256 amountIn,
        uint256 minLBTOut,
        BetParams calldata params,
        uint256 deadline
    ) external payable nonReentrant returns (uint256 betId) {
        if (block.timestamp > deadline) revert DeadlineExpired();
        if (address(swapRouter) == address(0)) revert InvalidSwapRouter();

        // Check current odds meet minimum
        uint256 currentOdds = _getCurrentOdds(params.matchIndex, params.prediction);
        if (currentOdds < params.minOdds) revert OddsSlippageExceeded();

        uint256 lbtReceived;

        // Handle ETH swap
        if (tokenIn == address(0)) {
            require(msg.value == amountIn, "ETH amount mismatch");
            lbtReceived = swapRouter.swapToLBT{value: msg.value}(
                tokenIn,
                amountIn,
                minLBTOut
            );
        } else {
            // Handle ERC20 swap (USDC/USDT)
            IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
            IERC20(tokenIn).approve(address(swapRouter), amountIn);

            lbtReceived = swapRouter.swapToLBT(
                tokenIn,
                amountIn,
                minLBTOut
            );
        }

        // Approve betting core for LBT
        lbtToken.approve(address(bettingCore), lbtReceived);

        // Build arrays for single bet
        uint256[] memory matchIndices = new uint256[](1);
        matchIndices[0] = params.matchIndex;

        uint8[] memory predictions = new uint8[](1);
        predictions[0] = params.prediction;

        // Place bet with received LBT
        betId = bettingCore.placeBet(lbtReceived, matchIndices, predictions);

        emit BetPlacedWithSwap(msg.sender, tokenIn, amountIn, lbtReceived, betId);
        emit BetPlaced(msg.sender, betId, lbtReceived);
    }

    /**
     * @notice Place parlay bet by swapping to LBT first
     * @param tokenIn Input token (USDC/USDT) or address(0) for ETH
     * @param amountIn Amount of input token
     * @param minLBTOut Minimum LBT to receive from swap
     * @param params Parlay parameters
     * @param deadline Transaction deadline
     * @return betId ID of placed parlay bet
     */
    function placeParlayWithSwap(
        address tokenIn,
        uint256 amountIn,
        uint256 minLBTOut,
        ParlayParams calldata params,
        uint256 deadline
    ) external payable nonReentrant returns (uint256 betId) {
        if (block.timestamp > deadline) revert DeadlineExpired();
        if (address(swapRouter) == address(0)) revert InvalidSwapRouter();
        if (params.matchIndices.length != params.predictions.length) revert ArrayLengthMismatch();
        if (params.matchIndices.length < 2) revert EmptyBets();

        // Check multiplier meets minimum
        uint256 currentMultiplier = _calculateParlayMultiplier(
            params.matchIndices,
            params.predictions
        );
        if (currentMultiplier < params.minMultiplier) revert OddsSlippageExceeded();

        uint256 lbtReceived;

        // Handle ETH swap
        if (tokenIn == address(0)) {
            require(msg.value == amountIn, "ETH amount mismatch");
            lbtReceived = swapRouter.swapToLBT{value: msg.value}(
                tokenIn,
                amountIn,
                minLBTOut
            );
        } else {
            // Handle ERC20 swap
            IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
            IERC20(tokenIn).approve(address(swapRouter), amountIn);

            lbtReceived = swapRouter.swapToLBT(
                tokenIn,
                amountIn,
                minLBTOut
            );
        }

        // Approve betting core for LBT
        lbtToken.approve(address(bettingCore), lbtReceived);

        // Place parlay with received LBT
        betId = bettingCore.placeBet(lbtReceived, params.matchIndices, params.predictions);

        emit BetPlacedWithSwap(msg.sender, tokenIn, amountIn, lbtReceived, betId);
        emit ParlayPlaced(msg.sender, betId, lbtReceived);
    }

    // ============ Claim Functions ============

    /**
     * @notice Claim winnings for a single bet
     * @param betId Bet ID to claim
     * @param minPayout Minimum payout (slippage protection)
     * @return payout Amount received
     */
    function claimWinnings(
        uint256 betId,
        uint256 minPayout
    ) external nonReentrant returns (uint256 payout) {
        payout = bettingCore.claimWinnings(betId, minPayout);
        emit WinningsClaimed(msg.sender, betId, payout);
    }

    /**
     * @notice Claim winnings for multiple bets
     * @param betIds Array of bet IDs to claim
     * @return totalPayout Total amount received
     */
    function batchClaim(uint256[] calldata betIds) external nonReentrant returns (uint256 totalPayout) {
        totalPayout = bettingCore.batchClaim(betIds);
    }

    /**
     * @notice Cancel a bet before round starts
     * @param betId Bet ID to cancel
     */
    function cancelBet(uint256 betId) external nonReentrant {
        bettingCore.cancelBet(betId);
    }

    // ============ View Functions ============

    /**
     * @notice Get current odds for a prediction
     * @param matchIndex Match index
     * @param prediction Predicted outcome (1-3)
     * @return odds Current odds (scaled by PRECISION)
     */
    function getCurrentOdds(
        uint256 matchIndex,
        uint8 prediction
    ) external view returns (uint256 odds) {
        return _getCurrentOdds(matchIndex, prediction);
    }

    /**
     * @notice Calculate expected payout for a bet
     * @param matchIndex Match index
     * @param prediction Predicted outcome
     * @param amount Bet amount
     * @return expectedPayout Expected payout if won
     */
    function calculateExpectedPayout(
        uint256 matchIndex,
        uint8 prediction,
        uint256 amount
    ) external view returns (uint256 expectedPayout) {
        uint256 odds = _getCurrentOdds(matchIndex, prediction);
        expectedPayout = (amount * odds) / Constants.PRECISION;
    }

    /**
     * @notice Calculate parlay multiplier
     * @param matchIndices Array of match indices
     * @param predictions Array of predictions
     * @return multiplier Combined multiplier
     */
    function calculateParlayMultiplier(
        uint256[] calldata matchIndices,
        uint8[] calldata predictions
    ) external view returns (uint256 multiplier) {
        return _calculateParlayMultiplier(matchIndices, predictions);
    }

    /**
     * @notice Preview swap: how much LBT for given input token
     * @param tokenIn Input token address (or address(0) for ETH)
     * @param amountIn Amount of input token
     * @return expectedLBT Expected LBT output
     * @return minLBT Minimum LBT with default slippage
     */
    function previewSwap(
        address tokenIn,
        uint256 amountIn
    ) external view returns (uint256 expectedLBT, uint256 minLBT) {
        if (address(swapRouter) == address(0)) return (0, 0);

        expectedLBT = swapRouter.getAmountOut(tokenIn, amountIn);
        minLBT = swapRouter.getMinAmountOut(tokenIn, amountIn);
    }

    /**
     * @notice Get bet details
     * @param betId Bet ID
     * @return bet Bet struct
     * @return predictions Bet predictions
     */
    function getBet(uint256 betId) external view returns (
        DataTypes.Bet memory bet,
        DataTypes.BetPredictions memory predictions
    ) {
        return bettingCore.getBet(betId);
    }

    /**
     * @notice Check if a bet is claimable
     * @param betId Bet ID
     * @return claimable Whether bet can be claimed
     */
    function isClaimable(uint256 betId) external view returns (bool claimable) {
        (DataTypes.Bet memory bet, ) = bettingCore.getBet(betId);
        return bet.status == DataTypes.BetStatus.Won;
    }

    /**
     * @notice Get LBT token address
     * @return token LBT token address
     */
    function getLBTToken() external view returns (address token) {
        return address(lbtToken);
    }

    /**
     * @notice Get current round ID
     * @return roundId Current round
     */
    function currentRoundId() external view returns (uint256) {
        return bettingCore.getCurrentRound();
    }

    // ============ Admin Functions ============

    /**
     * @notice Update betting core address
     * @param newBettingCore New betting core address
     */
    function setBettingCore(address newBettingCore) external onlyOwner {
        if (newBettingCore == address(0)) revert InvalidBettingCore();
        bettingCore = BettingCore(newBettingCore);
    }

    /**
     * @notice Update swap router
     * @param newSwapRouter New swap router address
     */
    function setSwapRouter(address newSwapRouter) external onlyOwner {
        swapRouter = SwapRouter(payable(newSwapRouter));
    }

    /**
     * @notice Update default slippage tolerance
     * @param newSlippageBps New slippage in basis points
     */
    function setDefaultSlippage(uint256 newSlippageBps) external onlyOwner {
        require(newSlippageBps <= 1000, "Max 10% slippage");
        defaultSlippageBps = newSlippageBps;
    }

    /**
     * @notice Emergency token recovery
     * @param token Token to recover
     * @param to Recipient address
     * @param amount Amount to recover
     */
    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        IERC20(token).safeTransfer(to, amount);
    }

    /**
     * @notice Emergency ETH recovery
     * @param to Recipient address
     * @param amount Amount to recover
     */
    function emergencyWithdrawETH(
        address payable to,
        uint256 amount
    ) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        to.transfer(amount);
    }

    // ============ Internal Functions ============

    /**
     * @notice Get current odds for a prediction
     * @param matchIndex Match index
     * @param prediction Predicted outcome
     * @return odds Current odds
     */
    function _getCurrentOdds(
        uint256 matchIndex,
        uint8 prediction
    ) internal view returns (uint256 odds) {
        // Get current round and fetch odds from core
        uint256 roundId = bettingCore.getCurrentRound();
        return bettingCore.getOdds(roundId, matchIndex, prediction);
    }

    /**
     * @notice Calculate combined parlay multiplier
     * @param matchIndices Array of match indices
     * @param predictions Array of predictions
     * @return multiplier Combined multiplier
     */
    function _calculateParlayMultiplier(
        uint256[] calldata matchIndices,
        uint8[] calldata predictions
    ) internal view returns (uint256 multiplier) {
        multiplier = Constants.PRECISION;

        for (uint256 i = 0; i < matchIndices.length; i++) {
            uint256 odds = _getCurrentOdds(matchIndices[i], predictions[i]);
            multiplier = (multiplier * odds) / Constants.PRECISION;
        }

        // Apply parlay multiplier based on leg count
        uint256 parlayMult = _getParlayMultiplier(matchIndices.length);
        multiplier = (multiplier * parlayMult) / Constants.PRECISION;
    }

    /**
     * @notice Get parlay multiplier for number of legs
     * @param legs Number of parlay legs
     * @return mult Parlay multiplier (1e18 scale)
     */
    function _getParlayMultiplier(uint256 legs) internal pure returns (uint256 mult) {
        if (legs == 1) return Constants.PARLAY_MULT_1_MATCH;
        if (legs == 2) return Constants.PARLAY_MULT_2_MATCHES;
        if (legs == 3) return Constants.PARLAY_MULT_3_MATCHES;
        if (legs == 4) return Constants.PARLAY_MULT_4_MATCHES;
        if (legs == 5) return Constants.PARLAY_MULT_5_MATCHES;
        if (legs == 6) return Constants.PARLAY_MULT_6_MATCHES;
        if (legs == 7) return Constants.PARLAY_MULT_7_MATCHES;
        if (legs == 8) return Constants.PARLAY_MULT_8_MATCHES;
        if (legs == 9) return Constants.PARLAY_MULT_9_MATCHES;
        return Constants.PARLAY_MULT_10_MATCHES;
    }

    // Allow receiving ETH for swap operations
    receive() external payable {}
}

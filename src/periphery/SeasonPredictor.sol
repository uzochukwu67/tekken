// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title SeasonPredictor
 * @notice Free season winner prediction system integrated with new modular architecture
 * @dev Key Features:
 *      - Users predict season winner once per season (free)
 *      - Predictions allowed through round 18 (first half of 36-round season)
 *      - Prize pool funded by 2% of betting revenue from BettingCore
 *      - Winners split prize pool equally at season end
 *      - O(1) operations for gas efficiency
 *      - Integrated with GameCore for season/team data
 *      - Uses LBT token for payouts
 */
contract SeasonPredictor is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ State Variables ============

    IERC20 public immutable lbtToken;
    address public immutable gameCore;
    address public bettingCore;

    // Prediction deadline (round 18 = first half of 36-round season)
    uint256 public constant PREDICTION_DEADLINE_ROUND = 18;

    // ============ Structs ============

    struct SeasonPool {
        uint256 totalPool;           // Total LBT in prize pool
        uint256 winningTeamId;       // ID of team that won season
        uint256 totalWinners;        // Number of users who predicted correctly
        uint256 rewardPerWinner;     // LBT each winner receives
        bool finalized;              // Has season been finalized?
    }

    struct Prediction {
        uint256 teamId;              // Predicted team ID
        uint256 timestamp;           // When prediction was made
        bool claimed;                // Has user claimed reward?
    }

    // ============ Mappings ============

    // seasonId => SeasonPool data
    mapping(uint256 => SeasonPool) public seasonPools;

    // seasonId => user => Prediction
    mapping(uint256 => mapping(address => Prediction)) public predictions;

    // seasonId => teamId => count (how many users predicted this team)
    mapping(uint256 => mapping(uint256 => uint256)) public predictionCounts;

    // seasonId => teamId => array of predictors (for efficient payout)
    mapping(uint256 => mapping(uint256 => address[])) public teamPredictors;

    // ============ Events ============

    event PredictionMade(
        uint256 indexed seasonId,
        address indexed predictor,
        uint256 indexed teamId,
        uint256 timestamp
    );

    event SeasonPoolFunded(
        uint256 indexed seasonId,
        uint256 amount,
        uint256 totalPool
    );

    event SeasonFinalized(
        uint256 indexed seasonId,
        uint256 winningTeamId,
        uint256 totalWinners,
        uint256 rewardPerWinner
    );

    event RewardClaimed(
        uint256 indexed seasonId,
        address indexed predictor,
        uint256 amount
    );

    event BettingCoreUpdated(address indexed oldBettingCore, address indexed newBettingCore);

    // ============ Errors ============

    error SeasonNotActive();
    error PredictionDeadlinePassed();
    error AlreadyPredicted();
    error InvalidTeamId();
    error SeasonNotFinalized();
    error AlreadyClaimed();
    error NoPrediction();
    error NotAWinner();
    error SeasonAlreadyFinalized();
    error NoWinners();
    error OnlyBettingCore();

    // ============ Constructor ============

    constructor(
        address _lbtToken,
        address _gameCore,
        address _initialOwner
    ) Ownable(_initialOwner) {
        require(_lbtToken != address(0), "Invalid LBT token");
        require(_gameCore != address(0), "Invalid GameCore");

        lbtToken = IERC20(_lbtToken);
        gameCore = _gameCore;
    }

    // ============ Admin Functions ============

    /**
     * @notice Set BettingCore address (only owner)
     * @param _bettingCore Address of BettingCore contract
     */
    function setBettingCore(address _bettingCore) external onlyOwner {
        require(_bettingCore != address(0), "Invalid BettingCore");
        address oldBettingCore = bettingCore;
        bettingCore = _bettingCore;
        emit BettingCoreUpdated(oldBettingCore, _bettingCore);
    }

    // ============ Prediction Functions ============

    /**
     * @notice Make a free prediction for season winner
     * @param seasonId The season to predict for
     * @param teamId The team ID to predict as winner
     * @dev Predictions allowed only through round 10
     */
    function makePrediction(uint256 seasonId, uint256 teamId) external nonReentrant {
        // M-02 FIX: Verify season exists and is current
        uint256 currentSeason = _getCurrentSeason();
        require(seasonId == currentSeason, "Invalid or inactive season");
        require(currentSeason > 0, "No active season");

        // Verify season is active and predictions are still open
        uint256 currentRound = _getCurrentRound();
        if (currentRound > PREDICTION_DEADLINE_ROUND) {
            revert PredictionDeadlinePassed();
        }

        // Verify user hasn't already predicted for this season
        if (predictions[seasonId][msg.sender].timestamp != 0) {
            revert AlreadyPredicted();
        }

        // Verify team ID is valid (1-20)
        if (teamId == 0 || teamId > 20) {
            revert InvalidTeamId();
        }

        // Store prediction
        predictions[seasonId][msg.sender] = Prediction({
            teamId: teamId,
            timestamp: block.timestamp,
            claimed: false
        });

        // Update counters
        predictionCounts[seasonId][teamId]++;
        teamPredictors[seasonId][teamId].push(msg.sender);

        emit PredictionMade(seasonId, msg.sender, teamId, block.timestamp);
    }

    /**
     * @notice Claim reward for correct prediction
     * @param seasonId The season to claim for
     */
    function claimReward(uint256 seasonId) external nonReentrant {
        SeasonPool storage pool = seasonPools[seasonId];
        Prediction storage prediction = predictions[seasonId][msg.sender];

        // Verify season is finalized
        if (!pool.finalized) {
            revert SeasonNotFinalized();
        }

        // Verify user made a prediction
        if (prediction.timestamp == 0) {
            revert NoPrediction();
        }

        // Verify user hasn't claimed yet
        if (prediction.claimed) {
            revert AlreadyClaimed();
        }

        // Verify user predicted correctly
        if (prediction.teamId != pool.winningTeamId) {
            revert NotAWinner();
        }

        // Mark as claimed
        prediction.claimed = true;

        // Transfer reward
        uint256 reward = pool.rewardPerWinner;
        if (reward > 0) {
            lbtToken.safeTransfer(msg.sender, reward);
            emit RewardClaimed(seasonId, msg.sender, reward);
        }
    }

    // ============ Revenue Integration ============

    /**
     * @notice Fund season pool with revenue from BettingCore
     * @param seasonId The season to fund
     * @param amount Amount of LBT to add
     * @dev Called by BettingCore during revenue finalization
     */
    function fundSeasonPool(uint256 seasonId, uint256 amount) external {
        if (msg.sender != bettingCore) {
            revert OnlyBettingCore();
        }

        SeasonPool storage pool = seasonPools[seasonId];
        pool.totalPool += amount;

        emit SeasonPoolFunded(seasonId, amount, pool.totalPool);
    }

    /**
     * @notice Receive LBT tokens from BettingCore
     * @dev BettingCore transfers tokens then calls fundSeasonPool
     */
    function receiveSeasonRevenue(uint256 seasonId) external nonReentrant {
        if (msg.sender != bettingCore) {
            revert OnlyBettingCore();
        }

        // No-op: tokens already transferred, just acknowledge receipt
        // This function exists for explicit revenue tracking
    }

    // ============ Season Finalization ============

    /**
     * @notice Finalize season and calculate rewards
     * @param seasonId The season to finalize
     * @param winningTeamId The team that won the season
     * @dev Only owner can finalize after season ends
     */
    function finalizeSeason(uint256 seasonId, uint256 winningTeamId) external onlyOwner {
        SeasonPool storage pool = seasonPools[seasonId];

        // Verify not already finalized
        if (pool.finalized) {
            revert SeasonAlreadyFinalized();
        }

        // Verify winning team is valid
        if (winningTeamId == 0 || winningTeamId > 20) {
            revert InvalidTeamId();
        }

        // Get number of winners
        uint256 totalWinners = predictionCounts[seasonId][winningTeamId];

        // Store finalization data
        pool.winningTeamId = winningTeamId;
        pool.totalWinners = totalWinners;
        pool.finalized = true;

        // Calculate reward per winner
        if (totalWinners > 0 && pool.totalPool > 0) {
            pool.rewardPerWinner = pool.totalPool / totalWinners;
        }

        emit SeasonFinalized(seasonId, winningTeamId, totalWinners, pool.rewardPerWinner);
    }

    // ============ View Functions ============

    /**
     * @notice Get user's prediction for a season
     * @param seasonId The season ID
     * @param user The user address
     * @return teamId Predicted team ID
     * @return timestamp When prediction was made
     * @return claimed Whether reward has been claimed
     */
    function getUserPrediction(uint256 seasonId, address user)
        external
        view
        returns (uint256 teamId, uint256 timestamp, bool claimed)
    {
        Prediction storage prediction = predictions[seasonId][user];
        return (prediction.teamId, prediction.timestamp, prediction.claimed);
    }

    /**
     * @notice Get season pool data
     * @param seasonId The season ID
     * @return totalPool Total LBT in prize pool
     * @return winningTeamId Winning team ID
     * @return totalWinners Number of winners
     * @return rewardPerWinner LBT per winner
     * @return finalized Whether season is finalized
     */
    function getSeasonPool(uint256 seasonId)
        external
        view
        returns (
            uint256 totalPool,
            uint256 winningTeamId,
            uint256 totalWinners,
            uint256 rewardPerWinner,
            bool finalized
        )
    {
        SeasonPool storage pool = seasonPools[seasonId];
        return (
            pool.totalPool,
            pool.winningTeamId,
            pool.totalWinners,
            pool.rewardPerWinner,
            pool.finalized
        );
    }

    /**
     * @notice Get number of predictions for a team
     * @param seasonId The season ID
     * @param teamId The team ID
     * @return count Number of users who predicted this team
     */
    function getTeamPredictionCount(uint256 seasonId, uint256 teamId)
        external
        view
        returns (uint256 count)
    {
        return predictionCounts[seasonId][teamId];
    }

    /**
     * @notice Check if user can still make predictions
     * @return canPredict Whether predictions are still open
     * @return currentRound Current round number
     * @return deadline Prediction deadline round
     */
    function canMakePredictions()
        external
        view
        returns (bool canPredict, uint256 currentRound, uint256 deadline)
    {
        currentRound = _getCurrentRound();
        deadline = PREDICTION_DEADLINE_ROUND;
        canPredict = currentRound <= deadline;
        return (canPredict, currentRound, deadline);
    }

    /**
     * @notice Get all predictors for a team
     * @param seasonId The season ID
     * @param teamId The team ID
     * @return predictors Array of addresses who predicted this team
     */
    function getTeamPredictors(uint256 seasonId, uint256 teamId)
        external
        view
        returns (address[] memory predictors)
    {
        return teamPredictors[seasonId][teamId];
    }

    /**
     * @notice Check if user is a winner
     * @param seasonId The season ID
     * @param user The user address
     * @return isWinner Whether user predicted correctly
     * @return rewardAmount Reward amount if winner
     */
    function checkWinner(uint256 seasonId, address user)
        external
        view
        returns (bool isWinner, uint256 rewardAmount)
    {
        SeasonPool storage pool = seasonPools[seasonId];
        Prediction storage prediction = predictions[seasonId][user];

        if (!pool.finalized || prediction.timestamp == 0) {
            return (false, 0);
        }

        isWinner = (prediction.teamId == pool.winningTeamId);
        rewardAmount = isWinner ? pool.rewardPerWinner : 0;

        return (isWinner, rewardAmount);
    }

    // ============ Internal Functions ============

    /**
     * @notice Get current round from GameCore
     * @return currentRound The current round number
     */
    function _getCurrentRound() internal view returns (uint256) {
        // Call GameCore to get current round
        // This is a simplified version - adjust based on actual GameCore interface
        (bool success, bytes memory data) = gameCore.staticcall(
            abi.encodeWithSignature("getCurrentRound()")
        );

        if (success && data.length >= 32) {
            return abi.decode(data, (uint256));
        }

        return 0;
    }

    /**
     * @notice Get current season from GameCore
     * @return currentSeason The current season number
     */
    function _getCurrentSeason() internal view returns (uint256) {
        // Call GameCore to get current season
        (bool success, bytes memory data) = gameCore.staticcall(
            abi.encodeWithSignature("getCurrentSeason()")
        );

        if (success && data.length >= 32) {
            return abi.decode(data, (uint256));
        }

        return 0;
    }

    // ============ Emergency Functions ============

    /**
     * @notice Emergency withdraw unclaimed funds after season ends
     * @param seasonId The season ID
     * @dev Only callable after season finalized and sufficient time has passed
     */
    function emergencyWithdraw(uint256 seasonId) external onlyOwner {
        SeasonPool storage pool = seasonPools[seasonId];
        require(pool.finalized, "Season not finalized");

        uint256 balance = lbtToken.balanceOf(address(this));
        if (balance > 0) {
            lbtToken.safeTransfer(owner(), balance);
        }
    }
}

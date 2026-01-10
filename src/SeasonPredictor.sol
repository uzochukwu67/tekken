// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IGameEngine.sol";

/**
 * @title SeasonPredictor
 * @notice Manages free season winner predictions and 2% revenue pool distribution
 * @dev Users predict which team will win the season for free
 */
contract SeasonPredictor is Ownable {
    IERC20 public immutable leagueToken;
    IGameEngine public immutable gameEngine;

    struct Prediction {
        address predictor;
        uint256 seasonId;
        uint256 predictedTeamId;
        uint256 timestamp;
        bool claimed;
    }

    // State
    mapping(uint256 => mapping(address => uint256)) public userPredictions; // seasonId => user => teamId
    mapping(uint256 => mapping(uint256 => address[])) public teamPredictors; // seasonId => teamId => predictors
    mapping(uint256 => uint256) public seasonPrizePool; // seasonId => prize pool amount
    mapping(uint256 => bool) public seasonDistributed; // seasonId => distributed status

    uint256 public predictionCount;

    // Events
    event PredictionMade(
        address indexed predictor,
        uint256 indexed seasonId,
        uint256 predictedTeamId,
        uint256 timestamp
    );
    event PrizePoolFunded(uint256 indexed seasonId, uint256 amount);
    event PrizeDistributed(
        uint256 indexed seasonId,
        uint256 winningTeamId,
        uint256 totalPrize,
        uint256 winnersCount
    );
    event RewardClaimed(
        address indexed predictor,
        uint256 indexed seasonId,
        uint256 amount
    );

    constructor(
        address _leagueToken,
        address _gameEngine,
        address _initialOwner
    ) Ownable(_initialOwner) {
        leagueToken = IERC20(_leagueToken);
        gameEngine = IGameEngine(_gameEngine);
    }

    /**
     * @notice Make a free prediction for season winner
     * @param seasonId Season to predict
     * @param teamId Team predicted to win
     */
    function makePrediction(uint256 seasonId, uint256 teamId) external {
        require(teamId < 20, "Invalid team ID");
        require(seasonId == gameEngine.getCurrentSeason(), "Invalid season");

        IGameEngine.Season memory season = gameEngine.getSeason(seasonId);
        require(season.active, "Season not active");
        require(season.currentRound == 0, "Predictions closed");
        require(userPredictions[seasonId][msg.sender] == 0, "Already predicted");

        // Store prediction (adding 1 to distinguish from unset)
        userPredictions[seasonId][msg.sender] = teamId + 1;
        teamPredictors[seasonId][teamId].push(msg.sender);
        predictionCount++;

        emit PredictionMade(msg.sender, seasonId, teamId, block.timestamp);
    }

    /**
     * @notice Fund the prize pool for a season (called by BettingPool)
     * @param seasonId Season to fund
     * @param amount Amount to add to pool
     */
    function fundPrizePool(uint256 seasonId, uint256 amount) external {
        require(
            leagueToken.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );
        seasonPrizePool[seasonId] += amount;
        emit PrizePoolFunded(seasonId, amount);
    }

    /**
     * @notice Distribute prizes to correct predictors after season ends
     * @param seasonId Season to distribute prizes for
     */
    function distributePrizes(uint256 seasonId) external onlyOwner {
        IGameEngine.Season memory season = gameEngine.getSeason(seasonId);
        require(season.completed, "Season not completed");
        require(!seasonDistributed[seasonId], "Already distributed");

        uint256 winningTeamId = season.winningTeamId;
        address[] memory winners = teamPredictors[seasonId][winningTeamId];
        uint256 prizePool = seasonPrizePool[seasonId];

        require(prizePool > 0, "No prize pool");

        if (winners.length == 0) {
            // No winners - keep in pool or roll over
            seasonDistributed[seasonId] = true;
            emit PrizeDistributed(seasonId, winningTeamId, 0, 0);
            return;
        }

        seasonDistributed[seasonId] = true;

        emit PrizeDistributed(seasonId, winningTeamId, prizePool, winners.length);
    }

    /**
     * @notice Claim prize for correct prediction
     * @param seasonId Season to claim for
     */
    function claimPrize(uint256 seasonId) external {
        require(seasonDistributed[seasonId], "Prizes not distributed yet");

        IGameEngine.Season memory season = gameEngine.getSeason(seasonId);
        uint256 predictedTeamId = userPredictions[seasonId][msg.sender];

        require(predictedTeamId > 0, "No prediction made");
        predictedTeamId -= 1; // Adjust back from storage offset

        require(predictedTeamId == season.winningTeamId, "Incorrect prediction");

        // Calculate share
        address[] memory winners = teamPredictors[seasonId][season.winningTeamId];
        uint256 prizePool = seasonPrizePool[seasonId];
        uint256 share = prizePool / winners.length;

        require(share > 0, "No prize available");

        // Mark as claimed (set to max value to indicate claimed)
        userPredictions[seasonId][msg.sender] = type(uint256).max;

        require(leagueToken.transfer(msg.sender, share), "Transfer failed");

        emit RewardClaimed(msg.sender, seasonId, share);
    }

    // View functions
    function getUserPrediction(uint256 seasonId, address user)
        external
        view
        returns (uint256)
    {
        uint256 prediction = userPredictions[seasonId][user];
        if (prediction == 0 || prediction == type(uint256).max) return type(uint256).max;
        return prediction - 1;
    }

    function getTeamPredictorCount(uint256 seasonId, uint256 teamId)
        external
        view
        returns (uint256)
    {
        return teamPredictors[seasonId][teamId].length;
    }

    function getSeasonPrizePool(uint256 seasonId) external view returns (uint256) {
        return seasonPrizePool[seasonId];
    }

    function canClaimPrize(uint256 seasonId, address user)
        external
        view
        returns (bool, uint256)
    {
        if (!seasonDistributed[seasonId]) return (false, 0);

        uint256 predictedTeamId = userPredictions[seasonId][user];
        if (predictedTeamId == 0 || predictedTeamId == type(uint256).max) {
            return (false, 0);
        }

        predictedTeamId -= 1;
        IGameEngine.Season memory season = gameEngine.getSeason(seasonId);

        if (predictedTeamId != season.winningTeamId) return (false, 0);

        address[] memory winners = teamPredictors[seasonId][season.winningTeamId];
        uint256 prizePool = seasonPrizePool[seasonId];
        uint256 share = prizePool / winners.length;

        return (true, share);
    }
}

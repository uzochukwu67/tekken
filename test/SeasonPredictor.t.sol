// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/periphery/SeasonPredictor.sol";
import "../src/tokens/LeagueBetToken.sol";

contract SeasonPredictorTest is Test {
    SeasonPredictor public seasonPredictor;
    LeagueBetToken public lbt;
    MockGameCore public gameCore;

    address public owner;
    address public alice;
    address public bob;
    address public charlie;
    address public bettingCore;

    // Events to test
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

    function setUp() public {
        // Setup accounts
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        bettingCore = makeAddr("bettingCore");

        // Deploy LBT token
        lbt = new LeagueBetToken(1_000_000 ether);

        // Deploy mock GameCore
        gameCore = new MockGameCore();
        gameCore.setCurrentSeason(1);
        gameCore.setCurrentRound(1);

        // Deploy SeasonPredictor
        seasonPredictor = new SeasonPredictor(
            address(lbt),
            address(gameCore),
            owner
        );

        // Set BettingCore
        seasonPredictor.setBettingCore(bettingCore);

        // Fund test accounts with LBT
        lbt.transfer(alice, 10000 ether);
        lbt.transfer(bob, 10000 ether);
        lbt.transfer(charlie, 10000 ether);
    }

    // ============ Helper Functions ============

    /**
     * @notice Helper to fund season pool properly
     * @dev Transfers LBT to SeasonPredictor, then calls fundSeasonPool from BettingCore
     */
    function _fundSeasonPool(uint256 seasonId, uint256 amount) internal {
        // Transfer tokens to SeasonPredictor
        lbt.transfer(address(seasonPredictor), amount);

        // Call fundSeasonPool from BettingCore
        vm.prank(bettingCore);
        seasonPredictor.fundSeasonPool(seasonId, amount);
    }

    // ============ Prediction Tests ============

    function test_MakePrediction() public {
        uint256 seasonId = 1;
        uint256 teamId = 5;

        // Alice makes prediction
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit PredictionMade(seasonId, alice, teamId, block.timestamp);
        seasonPredictor.makePrediction(seasonId, teamId);

        // Verify prediction was stored
        (uint256 predictedTeam, uint256 timestamp, bool claimed) =
            seasonPredictor.getUserPrediction(seasonId, alice);

        assertEq(predictedTeam, teamId, "Team ID should match");
        assertEq(timestamp, block.timestamp, "Timestamp should match");
        assertFalse(claimed, "Should not be claimed yet");

        // Verify prediction count increased
        uint256 count = seasonPredictor.getTeamPredictionCount(seasonId, teamId);
        assertEq(count, 1, "Count should be 1");
    }

    function test_CannotPredictAfterDeadline() public {
        uint256 seasonId = 1;

        // Warp past deadline (round 18)
        gameCore.setCurrentRound(19);

        // Try to make prediction
        vm.prank(alice);
        vm.expectRevert();
        seasonPredictor.makePrediction(seasonId, 5);
    }

    function test_CannotPredictTwice() public {
        uint256 seasonId = 1;

        // Alice makes first prediction
        vm.prank(alice);
        seasonPredictor.makePrediction(seasonId, 5);

        // Try to predict again
        vm.prank(alice);
        vm.expectRevert();
        seasonPredictor.makePrediction(seasonId, 10);
    }

    function test_CannotPredictInvalidTeam() public {
        uint256 seasonId = 1;

        // Try to predict team 0 (invalid, must be 1-20)
        vm.prank(alice);
        vm.expectRevert();
        seasonPredictor.makePrediction(seasonId, 0);

        // Try to predict team 21 (invalid, must be 1-20)
        vm.prank(alice);
        vm.expectRevert();
        seasonPredictor.makePrediction(seasonId, 21);
    }

    function test_MultiplePredictorsSameTeam() public {
        uint256 seasonId = 1;
        uint256 teamId = 7;

        // Alice, Bob, Charlie all predict team 7
        vm.prank(alice);
        seasonPredictor.makePrediction(seasonId, teamId);

        vm.prank(bob);
        seasonPredictor.makePrediction(seasonId, teamId);

        vm.prank(charlie);
        seasonPredictor.makePrediction(seasonId, teamId);

        // Verify count
        uint256 count = seasonPredictor.getTeamPredictionCount(seasonId, teamId);
        assertEq(count, 3, "Should have 3 predictors");

        // Verify predictors array
        address[] memory predictors = seasonPredictor.getTeamPredictors(seasonId, teamId);
        assertEq(predictors.length, 3, "Should have 3 addresses");
        assertEq(predictors[0], alice);
        assertEq(predictors[1], bob);
        assertEq(predictors[2], charlie);
    }

    // ============ Season Pool Funding Tests ============

    function test_FundSeasonPool() public {
        uint256 seasonId = 1;
        uint256 amount = 1000 ether;

        // Transfer tokens to SeasonPredictor first
        lbt.transfer(address(seasonPredictor), amount);

        // Fund from BettingCore
        vm.prank(bettingCore);
        vm.expectEmit(true, false, false, true);
        emit SeasonPoolFunded(seasonId, amount, amount);
        seasonPredictor.fundSeasonPool(seasonId, amount);

        // Verify pool balance
        (uint256 totalPool,,,,) = seasonPredictor.getSeasonPool(seasonId);
        assertEq(totalPool, amount, "Pool should have correct amount");
    }

    function test_OnlyBettingCoreCanFundPool() public {
        uint256 seasonId = 1;
        uint256 amount = 1000 ether;

        // Try to fund from non-BettingCore address
        vm.prank(alice);
        vm.expectRevert();
        seasonPredictor.fundSeasonPool(seasonId, amount);
    }

    function test_MultipleFundingRounds() public {
        uint256 seasonId = 1;

        // Fund multiple times using helper
        _fundSeasonPool(seasonId, 1000 ether);
        _fundSeasonPool(seasonId, 1500 ether);
        _fundSeasonPool(seasonId, 2500 ether);

        // Verify total
        (uint256 totalPool,,,,) = seasonPredictor.getSeasonPool(seasonId);
        assertEq(totalPool, 5000 ether, "Pool should accumulate correctly");
    }

    // ============ Season Finalization Tests ============

    function test_FinalizeSeason() public {
        uint256 seasonId = 1;
        uint256 winningTeam = 5;

        // Make predictions
        vm.prank(alice);
        seasonPredictor.makePrediction(seasonId, winningTeam); // Winner

        vm.prank(bob);
        seasonPredictor.makePrediction(seasonId, 10); // Loser

        vm.prank(charlie);
        seasonPredictor.makePrediction(seasonId, winningTeam); // Winner

        // Fund pool
        _fundSeasonPool(seasonId, 1000 ether);

        // Finalize season
        vm.expectEmit(true, false, false, true);
        emit SeasonFinalized(seasonId, winningTeam, 2, 500 ether);
        seasonPredictor.finalizeSeason(seasonId, winningTeam);

        // Verify pool data
        (
            uint256 totalPool,
            uint256 winningTeamId,
            uint256 totalWinners,
            uint256 rewardPerWinner,
            bool finalized
        ) = seasonPredictor.getSeasonPool(seasonId);

        assertEq(totalPool, 1000 ether, "Total pool should match");
        assertEq(winningTeamId, winningTeam, "Winning team should match");
        assertEq(totalWinners, 2, "Should have 2 winners");
        assertEq(rewardPerWinner, 500 ether, "Each winner gets 500 LBT");
        assertTrue(finalized, "Should be finalized");
    }

    function test_OnlyOwnerCanFinalize() public {
        uint256 seasonId = 1;

        // Try to finalize as non-owner
        vm.prank(alice);
        vm.expectRevert();
        seasonPredictor.finalizeSeason(seasonId, 5);
    }

    function test_CannotFinalizeWithNoPredictions() public {
        uint256 seasonId = 1;
        uint256 winningTeam = 5;

        // Fund pool but no predictions
        lbt.transfer(bettingCore, 1000 ether);
        vm.prank(bettingCore);
        lbt.approve(address(seasonPredictor), 1000 ether);
        vm.prank(bettingCore);
        seasonPredictor.fundSeasonPool(seasonId, 1000 ether);

        // Try to finalize with no winners
        seasonPredictor.finalizeSeason(seasonId, winningTeam);

        // Should finalize but with 0 winners
        (,,uint256 totalWinners,,) = seasonPredictor.getSeasonPool(seasonId);
        assertEq(totalWinners, 0, "Should have 0 winners");
    }

    // ============ Reward Claiming Tests ============

    function test_ClaimReward() public {
        uint256 seasonId = 1;
        uint256 winningTeam = 5;

        // Alice predicts correctly
        vm.prank(alice);
        seasonPredictor.makePrediction(seasonId, winningTeam);

        // Fund pool
        _fundSeasonPool(seasonId, 1000 ether);

        // Finalize
        seasonPredictor.finalizeSeason(seasonId, winningTeam);

        // Check winner status before claim
        (bool isWinner, uint256 rewardAmount) = seasonPredictor.checkWinner(seasonId, alice);
        assertTrue(isWinner, "Alice should be winner");
        assertEq(rewardAmount, 1000 ether, "Should get full pool");

        // Claim reward
        uint256 balanceBefore = lbt.balanceOf(alice);

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit RewardClaimed(seasonId, alice, 1000 ether);
        seasonPredictor.claimReward(seasonId);

        uint256 balanceAfter = lbt.balanceOf(alice);
        assertEq(balanceAfter - balanceBefore, 1000 ether, "Should receive reward");

        // Verify claimed status
        (,, bool claimed) = seasonPredictor.getUserPrediction(seasonId, alice);
        assertTrue(claimed, "Should be marked as claimed");
    }

    function test_CannotClaimTwice() public {
        uint256 seasonId = 1;
        uint256 winningTeam = 5;

        // Setup and claim once
        vm.prank(alice);
        seasonPredictor.makePrediction(seasonId, winningTeam);

        _fundSeasonPool(seasonId, 1000 ether);

        seasonPredictor.finalizeSeason(seasonId, winningTeam);

        vm.prank(alice);
        seasonPredictor.claimReward(seasonId);

        // Try to claim again
        vm.prank(alice);
        vm.expectRevert();
        seasonPredictor.claimReward(seasonId);
    }

    function test_LoserCannotClaim() public {
        uint256 seasonId = 1;
        uint256 winningTeam = 5;

        // Bob predicts wrong team
        vm.prank(bob);
        seasonPredictor.makePrediction(seasonId, 10);

        // Fund and finalize
        lbt.transfer(bettingCore, 1000 ether);
        vm.prank(bettingCore);
        lbt.approve(address(seasonPredictor), 1000 ether);
        vm.prank(bettingCore);
        seasonPredictor.fundSeasonPool(seasonId, 1000 ether);

        seasonPredictor.finalizeSeason(seasonId, winningTeam);

        // Bob should not be winner
        (bool isWinner,) = seasonPredictor.checkWinner(seasonId, bob);
        assertFalse(isWinner, "Bob should not be winner");

        // Try to claim
        vm.prank(bob);
        vm.expectRevert();
        seasonPredictor.claimReward(seasonId);
    }

    function test_CannotClaimBeforeFinalization() public {
        uint256 seasonId = 1;

        vm.prank(alice);
        seasonPredictor.makePrediction(seasonId, 5);

        // Try to claim before finalization
        vm.prank(alice);
        vm.expectRevert();
        seasonPredictor.claimReward(seasonId);
    }

    function test_MultipleWinnersSplitPrize() public {
        uint256 seasonId = 1;
        uint256 winningTeam = 7;

        // 3 winners
        vm.prank(alice);
        seasonPredictor.makePrediction(seasonId, winningTeam);

        vm.prank(bob);
        seasonPredictor.makePrediction(seasonId, winningTeam);

        vm.prank(charlie);
        seasonPredictor.makePrediction(seasonId, winningTeam);

        // Fund with 3000 LBT
        _fundSeasonPool(seasonId, 3000 ether);

        // Finalize
        seasonPredictor.finalizeSeason(seasonId, winningTeam);

        // Each should get 1000 LBT
        (,,,uint256 rewardPerWinner,) = seasonPredictor.getSeasonPool(seasonId);
        assertEq(rewardPerWinner, 1000 ether, "Each gets 1000 LBT");

        // All claim
        vm.prank(alice);
        seasonPredictor.claimReward(seasonId);

        vm.prank(bob);
        seasonPredictor.claimReward(seasonId);

        vm.prank(charlie);
        seasonPredictor.claimReward(seasonId);

        // Verify all received correct amount
        (bool aliceWon, uint256 aliceReward) = seasonPredictor.checkWinner(seasonId, alice);
        (bool bobWon, uint256 bobReward) = seasonPredictor.checkWinner(seasonId, bob);
        (bool charlieWon, uint256 charlieReward) = seasonPredictor.checkWinner(seasonId, charlie);

        assertTrue(aliceWon && bobWon && charlieWon, "All should be winners");
        assertEq(aliceReward, 1000 ether);
        assertEq(bobReward, 1000 ether);
        assertEq(charlieReward, 1000 ether);
    }

    // ============ View Function Tests ============

    function test_CanMakePredictions() public {
        // At round 1, should be able to predict
        (bool canPredict, uint256 currentRound, uint256 deadline) =
            seasonPredictor.canMakePredictions();

        assertTrue(canPredict, "Should be able to predict");
        assertEq(currentRound, 1, "Current round should be 1");
        assertEq(deadline, 18, "Deadline should be round 18");

        // Move to round 18 (still can predict)
        gameCore.setCurrentRound(18);
        (canPredict,,) = seasonPredictor.canMakePredictions();
        assertTrue(canPredict, "Should still be able to predict at round 18");

        // Move to round 19 (cannot predict)
        gameCore.setCurrentRound(19);
        (canPredict,,) = seasonPredictor.canMakePredictions();
        assertFalse(canPredict, "Should not be able to predict at round 19");
    }

    // ============ Edge Case Tests ============

    function test_EmptyPoolNoClaims() public {
        uint256 seasonId = 1;
        uint256 winningTeam = 5;

        // Make prediction
        vm.prank(alice);
        seasonPredictor.makePrediction(seasonId, winningTeam);

        // Finalize with empty pool
        seasonPredictor.finalizeSeason(seasonId, winningTeam);

        // Alice is winner but reward is 0
        (bool isWinner, uint256 rewardAmount) = seasonPredictor.checkWinner(seasonId, alice);
        assertTrue(isWinner, "Should be winner");
        assertEq(rewardAmount, 0, "Reward should be 0");

        // Try to claim (should work but get nothing)
        uint256 balanceBefore = lbt.balanceOf(alice);
        vm.prank(alice);
        seasonPredictor.claimReward(seasonId);

        uint256 balanceAfter = lbt.balanceOf(alice);
        assertEq(balanceAfter, balanceBefore, "Balance should not change");
    }

    function test_PredictionDistribution() public {
        uint256 seasonId = 1;

        // Various predictions
        vm.prank(alice);
        seasonPredictor.makePrediction(seasonId, 1);

        vm.prank(bob);
        seasonPredictor.makePrediction(seasonId, 1);

        vm.prank(charlie);
        seasonPredictor.makePrediction(seasonId, 5);

        // Check counts
        assertEq(seasonPredictor.getTeamPredictionCount(seasonId, 1), 2);
        assertEq(seasonPredictor.getTeamPredictionCount(seasonId, 5), 1);
        assertEq(seasonPredictor.getTeamPredictionCount(seasonId, 10), 0);
    }
}

// ============ Mock Contracts ============

contract MockGameCore {
    uint256 public currentSeason = 1;
    uint256 public currentRound = 0;

    function getCurrentSeason() external view returns (uint256) {
        return currentSeason;
    }

    function getCurrentRound() external view returns (uint256) {
        return currentRound;
    }

    function setCurrentSeason(uint256 _season) external {
        currentSeason = _season;
    }

    function setCurrentRound(uint256 _round) external {
        currentRound = _round;
    }
}

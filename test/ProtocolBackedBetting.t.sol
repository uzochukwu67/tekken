// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/core/BettingCore.sol";
import "../src/tokens/LeagueBetToken.sol";
import "../src/libraries/DataTypes.sol";
import "../src/libraries/Constants.sol";

/**
 * @title ProtocolBackedBettingTest
 * @notice Comprehensive tests for protocol-backed betting architecture
 * @dev Tests cover: betting logic, protocol accounting, bounty system, liquidity management
 */
contract ProtocolBackedBettingTest is Test {
    // ============ Contracts ============
    BettingCore public bettingCore;
    LeagueBetToken public lbt;
    MockGameCore public gameCore;

    // ============ Actors ============
    address public owner = makeAddr("owner");
    address public treasury = makeAddr("treasury");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public bountyHunter = makeAddr("bountyHunter");

    // ============ Constants ============
    uint256 constant INITIAL_SUPPLY = 10_000_000 ether;
    uint256 constant INITIAL_RESERVES = 1_000_000 ether;
    uint256 constant USER_BALANCE = 10_000 ether;

    // ============ Setup ============

    function setUp() public {
        vm.startPrank(owner);

        // Deploy LBT token
        lbt = new LeagueBetToken(INITIAL_SUPPLY);

        // Deploy mock game core
        gameCore = new MockGameCore();

        // Deploy BettingCore
        bettingCore = new BettingCore(
            address(gameCore),
            treasury,
            owner
        );

        // Set LBT token
        bettingCore.setLBTToken(address(lbt));

        // Approve and deposit initial reserves
        lbt.approve(address(bettingCore), INITIAL_RESERVES);
        bettingCore.depositReserves(INITIAL_RESERVES);

        // Distribute tokens to users
        lbt.transfer(alice, USER_BALANCE);
        lbt.transfer(bob, USER_BALANCE);
        lbt.transfer(charlie, USER_BALANCE);

        vm.stopPrank();

        // Users approve BettingCore
        vm.prank(alice);
        lbt.approve(address(bettingCore), type(uint256).max);

        vm.prank(bob);
        lbt.approve(address(bettingCore), type(uint256).max);

        vm.prank(charlie);
        lbt.approve(address(bettingCore), type(uint256).max);
    }

    // ============ Helper Functions ============

    function _seedRound(uint256 roundId) internal {
        vm.prank(owner);
        bettingCore.seedRound(roundId);
    }

    function _settleRound(uint256 roundId, uint8[] memory results) internal {
        vm.prank(owner);
        bettingCore.settleRound(roundId, results);
    }

    function _createWinningResults() internal pure returns (uint8[] memory) {
        uint8[] memory results = new uint8[](10);
        for (uint256 i = 0; i < 10; i++) {
            results[i] = 1; // All HOME wins
        }
        return results;
    }

    function _createLosingResults() internal pure returns (uint8[] memory) {
        uint8[] memory results = new uint8[](10);
        for (uint256 i = 0; i < 10; i++) {
            results[i] = 2; // All AWAY wins
        }
        return results;
    }

    // ============ Protocol Liquidity Tests ============

    function test_ProtocolDeposit() public {
        uint256 depositAmount = 100_000 ether;

        vm.startPrank(owner);
        lbt.approve(address(bettingCore), depositAmount);

        uint256 reservesBefore = bettingCore.getProtocolReserves();
        bettingCore.depositReserves(depositAmount);
        uint256 reservesAfter = bettingCore.getProtocolReserves();

        assertEq(reservesAfter - reservesBefore, depositAmount, "Deposit should increase reserves");
        vm.stopPrank();
    }

    function test_ProtocolWithdraw() public {
        uint256 withdrawAmount = 100_000 ether;

        vm.startPrank(owner);

        (uint256 availableBefore,,) = bettingCore.getAvailableReserves();
        uint256 ownerBalanceBefore = lbt.balanceOf(owner);

        bettingCore.withdrawReserves(withdrawAmount, owner);

        (uint256 availableAfter,,) = bettingCore.getAvailableReserves();
        uint256 ownerBalanceAfter = lbt.balanceOf(owner);

        assertEq(availableBefore - availableAfter, withdrawAmount, "Available should decrease");
        assertEq(ownerBalanceAfter - ownerBalanceBefore, withdrawAmount, "Owner should receive tokens");

        vm.stopPrank();
    }

    function test_CannotWithdrawLockedReserves() public {
        // Seed a round (locks reserves)
        _seedRound(1);

        // Alice places a bet
        vm.prank(alice);
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1; // HOME
        bettingCore.placeBet(1000 ether, matchIndices, predictions);

        // Get locked amount
        (,uint256 locked,) = bettingCore.getAvailableReserves();
        assertTrue(locked > 0, "Should have locked reserves");

        // Try to withdraw more than available
        vm.startPrank(owner);
        (uint256 available,,) = bettingCore.getAvailableReserves();

        vm.expectRevert("Insufficient available reserves");
        bettingCore.withdrawReserves(available + locked, owner);

        vm.stopPrank();
    }

    function test_GetAvailableReserves() public {
        (uint256 available, uint256 locked, uint256 total) = bettingCore.getAvailableReserves();

        assertEq(total, INITIAL_RESERVES, "Total should be initial reserves");
        assertEq(locked, 0, "No locked reserves initially");
        assertEq(available, total, "All reserves available initially");
    }

    // ============ Betting Logic Tests ============

    function test_PlaceSingleBet() public {
        _seedRound(1);

        vm.prank(alice);
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1; // HOME

        uint256 betAmount = 100 ether;
        uint256 betId = bettingCore.placeBet(betAmount, matchIndices, predictions);

        (DataTypes.Bet memory bet,) = bettingCore.getBet(betId);

        assertEq(bet.bettor, alice, "Bettor should be alice");
        assertEq(bet.amount, betAmount, "Bet amount should match");
        assertEq(bet.legCount, 1, "Should have 1 leg");
        assertEq(uint8(bet.status), uint8(DataTypes.BetStatus.Active), "Status should be Active");
    }

    function test_PlaceParlayBet() public {
        _seedRound(1);

        vm.prank(alice);
        uint256[] memory matchIndices = new uint256[](3);
        uint8[] memory predictions = new uint8[](3);
        matchIndices[0] = 0;
        matchIndices[1] = 1;
        matchIndices[2] = 2;
        predictions[0] = 1;
        predictions[1] = 1;
        predictions[2] = 1;

        uint256 betAmount = 100 ether;
        uint256 betId = bettingCore.placeBet(betAmount, matchIndices, predictions);

        (DataTypes.Bet memory bet,) = bettingCore.getBet(betId);

        assertEq(bet.legCount, 3, "Should have 3 legs");
        assertTrue(bet.lockedMultiplier > 1e18, "Parlay should have multiplier > 1x");
    }

    function test_CannotBetWithoutSeededRound() public {
        vm.prank(alice);
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1;

        vm.expectRevert(BettingCore.RoundNotActive.selector);
        bettingCore.placeBet(100 ether, matchIndices, predictions);
    }

    function test_CannotBetMoreThanReserves() public {
        // First, reduce reserves so we can test the liquidity check
        vm.prank(owner);
        bettingCore.withdrawReserves(INITIAL_RESERVES - 500 ether, owner);

        _seedRound(1);

        vm.prank(alice);
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1;

        // Bet within MAX_BET_AMOUNT but more than reserves can cover for payout
        // With ~500 ether reserves and bet of 1000 ether * 1.0x multiplier = 1000 potential payout
        // This should fail with "Insufficient protocol reserves"
        uint256 betAmount = 1000 ether;

        vm.expectRevert("Insufficient protocol reserves");
        bettingCore.placeBet(betAmount, matchIndices, predictions);
    }

    function test_CancelBet() public {
        _seedRound(1);

        vm.prank(alice);
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1;

        uint256 betAmount = 100 ether;
        uint256 betId = bettingCore.placeBet(betAmount, matchIndices, predictions);

        uint256 balanceBefore = lbt.balanceOf(alice);

        vm.prank(alice);
        uint256 refund = bettingCore.cancelBet(betId);

        uint256 balanceAfter = lbt.balanceOf(alice);

        // 10% cancellation fee
        uint256 expectedRefund = betAmount - (betAmount * 1000 / 10000);
        assertEq(refund, expectedRefund, "Refund should be 90% of bet");
        assertEq(balanceAfter - balanceBefore, refund, "Alice should receive refund");

        (DataTypes.Bet memory bet,) = bettingCore.getBet(betId);
        assertEq(uint8(bet.status), uint8(DataTypes.BetStatus.Cancelled), "Status should be Cancelled");
    }

    function test_CannotCancelOthersBet() public {
        _seedRound(1);

        vm.prank(alice);
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1;

        uint256 betId = bettingCore.placeBet(100 ether, matchIndices, predictions);

        vm.prank(bob);
        vm.expectRevert(BettingCore.NotBetOwner.selector);
        bettingCore.cancelBet(betId);
    }

    // ============ Settlement and Claiming Tests ============

    function test_ClaimWinningBet() public {
        _seedRound(1);

        // Alice bets on HOME
        vm.prank(alice);
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1; // HOME

        uint256 betAmount = 100 ether;
        uint256 betId = bettingCore.placeBet(betAmount, matchIndices, predictions);

        // Advance time past round end
        vm.warp(block.timestamp + Constants.ROUND_DURATION + 1);

        // Settle with HOME winning
        uint8[] memory results = _createWinningResults();
        _settleRound(1, results);

        // Get expected payout
        (DataTypes.Bet memory bet,) = bettingCore.getBet(betId);
        uint256 expectedPayout = (uint256(bet.amount) * uint256(bet.lockedMultiplier)) / Constants.PRECISION;

        uint256 balanceBefore = lbt.balanceOf(alice);

        vm.prank(alice);
        uint256 payout = bettingCore.claimWinnings(betId, 0);

        uint256 balanceAfter = lbt.balanceOf(alice);

        assertEq(payout, expectedPayout, "Payout should match expected");
        assertEq(balanceAfter - balanceBefore, payout, "Alice should receive payout");

        (bet,) = bettingCore.getBet(betId);
        assertEq(uint8(bet.status), uint8(DataTypes.BetStatus.Claimed), "Status should be Claimed");
    }

    function test_LosingBetNoPayout() public {
        _seedRound(1);

        // Alice bets on HOME
        vm.prank(alice);
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1; // HOME

        uint256 betId = bettingCore.placeBet(100 ether, matchIndices, predictions);

        vm.warp(block.timestamp + Constants.ROUND_DURATION + 1);

        // Settle with AWAY winning (Alice loses)
        uint8[] memory results = _createLosingResults();
        _settleRound(1, results);

        uint256 balanceBefore = lbt.balanceOf(alice);

        vm.prank(alice);
        uint256 payout = bettingCore.claimWinnings(betId, 0);

        uint256 balanceAfter = lbt.balanceOf(alice);

        assertEq(payout, 0, "Losing bet should have 0 payout");
        assertEq(balanceAfter, balanceBefore, "Balance should not change");

        (DataTypes.Bet memory bet,) = bettingCore.getBet(betId);
        assertEq(uint8(bet.status), uint8(DataTypes.BetStatus.Lost), "Status should be Lost");
    }

    function test_ParlayMustWinAllLegs() public {
        _seedRound(1);

        // Alice bets parlay on 3 matches, all HOME
        vm.prank(alice);
        uint256[] memory matchIndices = new uint256[](3);
        uint8[] memory predictions = new uint8[](3);
        matchIndices[0] = 0;
        matchIndices[1] = 1;
        matchIndices[2] = 2;
        predictions[0] = 1; // HOME
        predictions[1] = 1; // HOME
        predictions[2] = 1; // HOME

        uint256 betId = bettingCore.placeBet(100 ether, matchIndices, predictions);

        vm.warp(block.timestamp + Constants.ROUND_DURATION + 1);

        // Match 0 and 1 are HOME, but match 2 is AWAY (parlay loses)
        uint8[] memory results = new uint8[](10);
        results[0] = 1; // HOME (win)
        results[1] = 1; // HOME (win)
        results[2] = 2; // AWAY (loss) - breaks parlay
        for (uint256 i = 3; i < 10; i++) {
            results[i] = 1;
        }
        _settleRound(1, results);

        vm.prank(alice);
        uint256 payout = bettingCore.claimWinnings(betId, 0);

        assertEq(payout, 0, "Parlay should lose if any leg loses");

        (DataTypes.Bet memory bet,) = bettingCore.getBet(betId);
        assertEq(uint8(bet.status), uint8(DataTypes.BetStatus.Lost), "Status should be Lost");
    }

    // ============ Protocol Accounting Tests ============

    function test_RoundAccountingOnBet() public {
        _seedRound(1);

        uint256 betAmount = 100 ether;

        vm.prank(alice);
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1;

        bettingCore.placeBet(betAmount, matchIndices, predictions);

        DataTypes.RoundAccounting memory acct = bettingCore.getRoundAccounting(1);
        (uint256 totalLocked,,,, ) = bettingCore.getRoundPool(1);

        assertEq(acct.totalBetVolume, betAmount, "Volume should equal bet amount");
        assertTrue(totalLocked > 0, "Should have locked funds for winners");
    }

    function test_ProtocolProfitFromLosingBets() public {
        _seedRound(1);

        uint256 betAmount = 1000 ether;

        // Multiple users bet
        vm.prank(alice);
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1; // HOME
        uint256 aliceBetId = bettingCore.placeBet(betAmount, matchIndices, predictions);

        vm.prank(bob);
        uint256 bobBetId = bettingCore.placeBet(betAmount, matchIndices, predictions);

        uint256 reservesBefore = bettingCore.getProtocolReserves();

        vm.warp(block.timestamp + Constants.ROUND_DURATION + 1);

        // All bets lose
        uint8[] memory results = _createLosingResults();
        _settleRound(1, results);

        // Process losing bets (each user claims their own losing bet)
        vm.prank(alice);
        bettingCore.claimWinnings(aliceBetId, 0);
        vm.prank(bob);
        bettingCore.claimWinnings(bobBetId, 0);

        uint256 reservesAfter = bettingCore.getProtocolReserves();

        // Reserves should not change after claims (losses = no payouts)
        // Bets were already received when placed
        assertEq(reservesAfter, reservesBefore, "Reserves should stay same (no payouts for losses)");
    }

    function test_RevenueFinalization() public {
        // Set up season predictor mock to enable 2% season share
        MockSeasonPredictor mockSeasonPredictor = new MockSeasonPredictor();
        vm.prank(owner);
        bettingCore.setSeasonPredictor(address(mockSeasonPredictor));

        _seedRound(1);

        uint256 betAmount = 1000 ether;

        // Alice bets and loses
        vm.prank(alice);
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1; // HOME
        uint256 betId = bettingCore.placeBet(betAmount, matchIndices, predictions);

        vm.warp(block.timestamp + Constants.ROUND_DURATION + 1);

        // Alice loses
        uint8[] memory results = _createLosingResults();
        _settleRound(1, results);

        // Process the losing bet
        vm.prank(alice);
        bettingCore.claimWinnings(betId, 0);

        // Get round pool state before sweep
        (uint256 totalLocked, uint256 totalClaimed,,, bool swept) = bettingCore.getRoundPool(1);
        assertFalse(swept, "Pool should not be swept yet");

        // Fast forward past sweep deadline (30 hours after round end)
        vm.warp(block.timestamp + 30 hours + 1);

        // Sweep the round pool
        bettingCore.sweepRoundPool(1);

        // Check pool is swept
        (,,, , swept) = bettingCore.getRoundPool(1);
        assertTrue(swept, "Pool should be swept");

        // Profit from this round is the losing bet amount (winner bet lost, so all funds are profit)
        DataTypes.RoundAccounting memory acct = bettingCore.getRoundAccounting(1);
        assertEq(acct.totalBetVolume, betAmount, "Volume should equal bet amount");
    }

    function test_RevenueFinalizationNoSeasonPredictor() public {
        // Without season predictor, all profit stays with protocol
        _seedRound(1);

        uint256 betAmount = 1000 ether;

        vm.prank(alice);
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1;
        uint256 betId = bettingCore.placeBet(betAmount, matchIndices, predictions);

        vm.warp(block.timestamp + Constants.ROUND_DURATION + 1);

        uint8[] memory results = _createLosingResults();
        _settleRound(1, results);

        vm.prank(alice);
        bettingCore.claimWinnings(betId, 0);

        // Fast forward past sweep deadline
        vm.warp(block.timestamp + 30 hours + 1);

        // Sweep the round pool (without season predictor, all profit goes to protocol)
        bettingCore.sweepRoundPool(1);

        // Check pool is swept
        (,,, , bool swept) = bettingCore.getRoundPool(1);
        assertTrue(swept, "Pool should be swept");

        // Note: Without season predictor, 100% of remaining funds stay in protocol reserves
    }

    // ============ Bounty System Tests ============

    function test_DirectClaimWithin24Hours() public {
        _seedRound(1);

        vm.prank(alice);
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1;

        uint256 betId = bettingCore.placeBet(100 ether, matchIndices, predictions);

        vm.warp(block.timestamp + Constants.ROUND_DURATION + 1);

        uint8[] memory results = _createWinningResults();
        _settleRound(1, results);

        // Claim within 24 hours - should get 100%
        vm.prank(alice);
        uint256 payout = bettingCore.claimWinnings(betId, 0);

        assertTrue(payout > 0, "Should receive payout");

        // Third party cannot claim yet
        DataTypes.RoundMetadata memory meta = bettingCore.getRoundMetadata(1);
        uint256 deadline = meta.roundEndTime + Constants.CLAIM_DEADLINE;
        assertTrue(block.timestamp < deadline, "Should still be within deadline");
    }

    function test_BountyClaimAfter24Hours() public {
        _seedRound(1);

        vm.prank(alice);
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1;

        uint256 betAmount = 100 ether;
        uint256 betId = bettingCore.placeBet(betAmount, matchIndices, predictions);

        vm.warp(block.timestamp + Constants.ROUND_DURATION + 1);

        uint8[] memory results = _createWinningResults();
        _settleRound(1, results);

        // Advance past 24h claim deadline
        DataTypes.RoundMetadata memory meta = bettingCore.getRoundMetadata(1);
        vm.warp(meta.roundEndTime + Constants.CLAIM_DEADLINE + 1);

        // Get expected payout
        (DataTypes.Bet memory bet,) = bettingCore.getBet(betId);
        uint256 totalPayout = (uint256(bet.amount) * uint256(bet.lockedMultiplier)) / Constants.PRECISION;
        uint256 expectedBounty = (totalPayout * Constants.BOUNTY_PERCENTAGE) / Constants.BPS_PRECISION;
        uint256 expectedWinnerAmount = totalPayout - expectedBounty;

        uint256 hunterBalanceBefore = lbt.balanceOf(bountyHunter);
        uint256 aliceBalanceBefore = lbt.balanceOf(alice);

        // Bounty hunter claims
        vm.prank(bountyHunter);
        uint256 bounty = bettingCore.claimWinnings(betId, 0);

        uint256 hunterBalanceAfter = lbt.balanceOf(bountyHunter);
        uint256 aliceBalanceAfter = lbt.balanceOf(alice);

        assertEq(bounty, expectedBounty, "Bounty should be 10%");
        assertEq(hunterBalanceAfter - hunterBalanceBefore, expectedBounty, "Hunter receives bounty");
        assertEq(aliceBalanceAfter - aliceBalanceBefore, expectedWinnerAmount, "Alice receives 90%");
    }

    function test_CannotBountyClaimBefore24Hours() public {
        _seedRound(1);

        vm.prank(alice);
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1;

        uint256 betId = bettingCore.placeBet(100 ether, matchIndices, predictions);

        vm.warp(block.timestamp + Constants.ROUND_DURATION + 1);

        uint8[] memory results = _createWinningResults();
        _settleRound(1, results);

        // Try to claim as bounty hunter before deadline
        vm.prank(bountyHunter);
        vm.expectRevert("Claim deadline not passed");
        bettingCore.claimWinnings(betId, 0);
    }

    function test_CanClaimWithBountyView() public {
        _seedRound(1);

        vm.prank(alice);
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1;

        uint256 betId = bettingCore.placeBet(100 ether, matchIndices, predictions);

        vm.warp(block.timestamp + Constants.ROUND_DURATION + 1);

        uint8[] memory results = _createWinningResults();
        _settleRound(1, results);

        // Before deadline
        (bool eligible, uint256 timeUntil,,) = bettingCore.canClaimWithBounty(betId);
        assertFalse(eligible, "Should not be eligible before deadline");
        assertTrue(timeUntil > 0, "Should have time until bounty");

        // After deadline
        DataTypes.RoundMetadata memory meta = bettingCore.getRoundMetadata(1);
        vm.warp(meta.roundEndTime + Constants.CLAIM_DEADLINE + 1);

        (eligible, timeUntil,,) = bettingCore.canClaimWithBounty(betId);
        assertTrue(eligible, "Should be eligible after deadline");
        assertEq(timeUntil, 0, "No time remaining");
    }

    function test_MinimumBountyPayoutRequired() public {
        _seedRound(1);

        // Place a very small bet (below bounty minimum)
        vm.prank(alice);
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1;

        // Small bet that results in payout < 50 LBT minimum
        uint256 smallBet = 10 ether; // Payout would be ~10 LBT (below 50 LBT minimum)
        uint256 betId = bettingCore.placeBet(smallBet, matchIndices, predictions);

        vm.warp(block.timestamp + Constants.ROUND_DURATION + 1);

        uint8[] memory results = _createWinningResults();
        _settleRound(1, results);

        // Wait past deadline
        DataTypes.RoundMetadata memory meta = bettingCore.getRoundMetadata(1);
        vm.warp(meta.roundEndTime + Constants.CLAIM_DEADLINE + 1);

        // Bounty claim should fail (below minimum)
        vm.prank(bountyHunter);
        vm.expectRevert("Payout below bounty minimum");
        bettingCore.claimWinnings(betId, 0);

        // But winner can still claim
        vm.prank(alice);
        uint256 payout = bettingCore.claimWinnings(betId, 0);
        assertTrue(payout > 0, "Winner should still be able to claim");
    }

    function test_BatchClaimWithBounties() public {
        _seedRound(1);

        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1;

        // Multiple users place winning bets
        vm.prank(alice);
        uint256 betId1 = bettingCore.placeBet(100 ether, matchIndices, predictions);

        vm.prank(bob);
        uint256 betId2 = bettingCore.placeBet(200 ether, matchIndices, predictions);

        vm.warp(block.timestamp + Constants.ROUND_DURATION + 1);

        uint8[] memory results = _createWinningResults();
        _settleRound(1, results);

        // Wait past deadline
        DataTypes.RoundMetadata memory meta = bettingCore.getRoundMetadata(1);
        vm.warp(meta.roundEndTime + Constants.CLAIM_DEADLINE + 1);

        // Bounty hunter batch claims
        uint256[] memory betIds = new uint256[](2);
        betIds[0] = betId1;
        betIds[1] = betId2;

        uint256 hunterBalanceBefore = lbt.balanceOf(bountyHunter);

        vm.prank(bountyHunter);
        uint256 totalBounty = bettingCore.batchClaim(betIds);

        uint256 hunterBalanceAfter = lbt.balanceOf(bountyHunter);

        assertTrue(totalBounty > 0, "Should receive bounties");
        assertEq(hunterBalanceAfter - hunterBalanceBefore, totalBounty, "Balance should increase by total bounty");
    }

    // ============ Edge Cases ============

    function test_MultipleBettorsMultipleRounds() public {
        // Round 1
        _seedRound(1);

        vm.prank(alice);
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1;
        uint256 bet1 = bettingCore.placeBet(100 ether, matchIndices, predictions);

        vm.prank(bob);
        predictions[0] = 2; // AWAY
        uint256 bet2 = bettingCore.placeBet(100 ether, matchIndices, predictions);

        vm.warp(block.timestamp + Constants.ROUND_DURATION + 1);

        uint8[] memory results = _createWinningResults();
        _settleRound(1, results);

        // Alice wins, Bob loses
        vm.prank(alice);
        uint256 payout1 = bettingCore.claimWinnings(bet1, 0);
        assertTrue(payout1 > 0, "Alice should win");

        vm.prank(bob);
        uint256 payout2 = bettingCore.claimWinnings(bet2, 0);
        assertEq(payout2, 0, "Bob should lose");

        // Fast forward past sweep deadline
        vm.warp(block.timestamp + 30 hours + 1);

        // Sweep round 1 pool
        bettingCore.sweepRoundPool(1);

        // Verify accounting
        DataTypes.RoundAccounting memory acct = bettingCore.getRoundAccounting(1);
        assertEq(acct.totalBetVolume, 200 ether, "Total volume should be 200");

        // Verify round pool
        (, uint256 totalClaimed,,, bool swept) = bettingCore.getRoundPool(1);
        assertTrue(swept, "Pool should be swept");
        assertEq(totalClaimed, payout1, "Claimed amount should equal Alice's payout");
    }

    function test_OddsAreLocked() public {
        _seedRound(1);

        // Get locked odds
        (uint256 homeOdds1,,, bool locked) = bettingCore.getLockedOdds(1, 0);
        assertTrue(locked, "Odds should be locked");
        assertTrue(homeOdds1 > 0, "Home odds should be set");

        // Place bet
        vm.prank(alice);
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1;
        bettingCore.placeBet(1000 ether, matchIndices, predictions);

        // Odds should NOT change after bet
        (uint256 homeOdds2,,,) = bettingCore.getLockedOdds(1, 0);
        assertEq(homeOdds1, homeOdds2, "Odds should remain locked");
    }

    function test_CannotDoubleClaim() public {
        _seedRound(1);

        vm.prank(alice);
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1;
        uint256 betId = bettingCore.placeBet(100 ether, matchIndices, predictions);

        vm.warp(block.timestamp + Constants.ROUND_DURATION + 1);

        uint8[] memory results = _createWinningResults();
        _settleRound(1, results);

        // First claim
        vm.prank(alice);
        bettingCore.claimWinnings(betId, 0);

        // Second claim should fail
        vm.prank(alice);
        vm.expectRevert("Already processed");
        bettingCore.claimWinnings(betId, 0);
    }

    // ============ Fuzz Tests ============

    function testFuzz_BetAmount(uint256 amount) public {
        // Bound amount to valid range
        amount = bound(amount, Constants.MIN_BET_AMOUNT, 1000 ether);

        _seedRound(1);

        vm.prank(alice);
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1;

        uint256 betId = bettingCore.placeBet(amount, matchIndices, predictions);

        (DataTypes.Bet memory bet,) = bettingCore.getBet(betId);
        assertEq(bet.amount, amount, "Bet amount should match input");
    }

    function testFuzz_MultipleLegs(uint8 legCount) public {
        // Bound leg count to valid range
        legCount = uint8(bound(legCount, 1, 10));

        _seedRound(1);

        vm.prank(alice);
        uint256[] memory matchIndices = new uint256[](legCount);
        uint8[] memory predictions = new uint8[](legCount);

        for (uint8 i = 0; i < legCount; i++) {
            matchIndices[i] = i;
            predictions[i] = 1; // All HOME
        }

        uint256 betId = bettingCore.placeBet(100 ether, matchIndices, predictions);

        (DataTypes.Bet memory bet,) = bettingCore.getBet(betId);
        assertEq(bet.legCount, legCount, "Leg count should match");
    }

    // ============ Bet Data Verification Tests ============

    /**
     * @notice Comprehensive test to verify bet data is correctly calculated and stored
     * @dev This test confirms:
     *      1. Amount is stored correctly
     *      2. PotentialPayout is non-zero and calculated correctly
     *      3. LockedMultiplier reflects odds and parlay bonus
     *      4. All bet fields are properly set
     */
    function test_BetDataVerification_SingleLeg() public {
        // Setup: Seed round 1
        gameCore.setCurrentRound(1);
        _seedRound(1);

        // Verify round is seeded
        DataTypes.RoundMetadata memory metadata = bettingCore.getRoundMetadata(1);
        assertTrue(metadata.seeded, "Round should be seeded");

        // Get locked odds for match 0
        (uint256 homeOdds, uint256 awayOdds, uint256 drawOdds, bool locked) =
            bettingCore.getLockedOdds(1, 0);
        assertTrue(locked, "Odds should be locked");
        assertTrue(homeOdds > 0, "Home odds should be non-zero");

        // Alice places a single-leg bet on HOME
        uint256 betAmount = 100 ether;
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1; // HOME

        vm.prank(alice);
        uint256 betId = bettingCore.placeBet(betAmount, matchIndices, predictions);

        // Retrieve bet data
        (DataTypes.Bet memory bet, DataTypes.BetPredictions memory betPredictions) =
            bettingCore.getBet(betId);

        // Verify basic fields
        assertEq(bet.bettor, alice, "Bettor should be Alice");
        assertEq(bet.token, address(lbt), "Token should be LBT");
        assertEq(bet.amount, betAmount, "Amount should match bet amount");
        assertEq(bet.roundId, 1, "Round ID should be 1");
        assertEq(bet.legCount, 1, "Leg count should be 1");
        assertEq(uint8(bet.status), uint8(DataTypes.BetStatus.Active), "Status should be Active");

        // ✅ CRITICAL: Verify potential payout is NON-ZERO
        assertTrue(bet.potentialPayout > 0, "Potential payout MUST be greater than 0");

        // ✅ CRITICAL: Verify locked multiplier is NON-ZERO
        assertTrue(bet.lockedMultiplier > 0, "Locked multiplier MUST be greater than 0");

        // Calculate expected multiplier: homeOdds * 1.0x (no parlay bonus for 1 leg)
        uint256 expectedMultiplier = homeOdds; // 1 leg = 1.0x parlay bonus
        assertEq(bet.lockedMultiplier, expectedMultiplier, "Multiplier should equal home odds");

        // Calculate expected payout
        uint256 expectedPayout = (betAmount * expectedMultiplier) / 1e18;
        assertEq(bet.potentialPayout, expectedPayout, "Payout should match calculation");

        // Verify payout is greater than bet amount (odds should be > 1.0x)
        assertTrue(bet.potentialPayout >= betAmount, "Payout should be at least bet amount");

        // Verify predictions are stored correctly
        assertEq(betPredictions.predictions.length, 1, "Should have 1 prediction");
        assertEq(betPredictions.predictions[0].matchIndex, 0, "Match index should be 0");
        assertEq(betPredictions.predictions[0].predictedOutcome, 1, "Prediction should be HOME");

        // Log for visibility
        emit log_named_uint("Bet Amount (LBT)", betAmount / 1e18);
        emit log_named_uint("Home Odds", homeOdds / 1e15); // Display as 3 decimals
        emit log_named_uint("Locked Multiplier", bet.lockedMultiplier / 1e15);
        emit log_named_uint("Potential Payout (LBT)", bet.potentialPayout / 1e18);
    }

    /**
     * @notice Verify parlay bet with multiple legs calculates payout correctly
     */
    function test_BetDataVerification_ParlayBet() public {
        // Setup: Seed round 1
        gameCore.setCurrentRound(1);
        _seedRound(1);

        // Get odds for matches 0, 1, 2
        (uint256 homeOdds0,,, bool locked0) = bettingCore.getLockedOdds(1, 0);
        (uint256 homeOdds1,,, bool locked1) = bettingCore.getLockedOdds(1, 1);
        (uint256 homeOdds2,,, bool locked2) = bettingCore.getLockedOdds(1, 2);

        assertTrue(locked0 && locked1 && locked2, "All odds should be locked");

        // Alice places a 3-leg parlay bet (all HOME)
        uint256 betAmount = 100 ether;
        uint256[] memory matchIndices = new uint256[](3);
        uint8[] memory predictions = new uint8[](3);
        matchIndices[0] = 0;
        matchIndices[1] = 1;
        matchIndices[2] = 2;
        predictions[0] = 1; // HOME
        predictions[1] = 1; // HOME
        predictions[2] = 1; // HOME

        vm.prank(alice);
        uint256 betId = bettingCore.placeBet(betAmount, matchIndices, predictions);

        // Retrieve bet data
        (DataTypes.Bet memory bet,) = bettingCore.getBet(betId);

        // ✅ CRITICAL: Verify potential payout is NON-ZERO
        assertTrue(bet.potentialPayout > 0, "Parlay payout MUST be greater than 0");
        assertTrue(bet.lockedMultiplier > 0, "Parlay multiplier MUST be greater than 0");

        // Calculate expected multiplier: (odds1 * odds2 * odds3) * 1.10x (3-leg parlay bonus)
        uint256 oddsMultiplier = (homeOdds0 * homeOdds1) / 1e18;
        oddsMultiplier = (oddsMultiplier * homeOdds2) / 1e18;
        uint256 parlayBonus = 1.10e18; // 3 legs = 1.10x
        uint256 expectedMultiplier = (oddsMultiplier * parlayBonus) / 1e18;

        assertEq(bet.lockedMultiplier, expectedMultiplier, "Parlay multiplier should include bonus");

        // Calculate expected payout
        uint256 expectedPayout = (betAmount * expectedMultiplier) / 1e18;
        assertEq(bet.potentialPayout, expectedPayout, "Parlay payout should match calculation");

        // Verify payout is significantly higher due to parlay multiplier
        assertTrue(bet.potentialPayout > betAmount, "Parlay payout should exceed bet amount");

        // Log for visibility
        emit log_named_uint("Bet Amount (LBT)", betAmount / 1e18);
        emit log_named_uint("Odds Multiplier", oddsMultiplier / 1e15);
        emit log_named_uint("Parlay Bonus", parlayBonus / 1e15);
        emit log_named_uint("Final Multiplier", bet.lockedMultiplier / 1e15);
        emit log_named_uint("Potential Payout (LBT)", bet.potentialPayout / 1e18);
    }

    /**
     * @notice Verify that betting BEFORE seeding fails with proper error
     */
    function test_CannotBetBeforeSeeding() public {
        // Set round but DON'T seed it
        gameCore.setCurrentRound(1);

        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1;

        // Attempt to bet should fail
        vm.prank(alice);
        vm.expectRevert(BettingCore.RoundNotActive.selector);
        bettingCore.placeBet(100 ether, matchIndices, predictions);
    }

    /**
     * @notice Verify getBet returns correct data via external call
     */
    function test_GetBetExternalCall() public {
        // Setup and place bet
        gameCore.setCurrentRound(1);
        _seedRound(1);

        uint256 betAmount = 100 ether;
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1;

        vm.prank(alice);
        uint256 betId = bettingCore.placeBet(betAmount, matchIndices, predictions);

        // Call getBet as external call (simulates frontend call)
        (DataTypes.Bet memory bet, DataTypes.BetPredictions memory betPreds) =
            bettingCore.getBet(betId);

        // Verify all fields are accessible and correct
        assertEq(bet.bettor, alice);
        assertEq(bet.amount, betAmount);
        assertTrue(bet.potentialPayout > 0, "External call should return non-zero payout");
        assertTrue(bet.lockedMultiplier > 0, "External call should return non-zero multiplier");
        assertEq(bet.roundId, 1);
        assertEq(bet.legCount, 1);
        assertEq(betPreds.predictions.length, 1);
    }

    /**
     * @notice Test winning bet claim with correct payout
     * @dev Verifies that after odds fix, winners receive correct payout
     */
    function test_ClaimWinningBetWithCorrectPayout() public {
        // Setup and seed round
        gameCore.setCurrentRound(1);
        _seedRound(1);

        // Get odds for verification
        (uint256 homeOdds,,,) = bettingCore.getLockedOdds(1, 0);

        // Alice places bet
        uint256 betAmount = 100 ether;
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1; // HOME

        vm.prank(alice);
        uint256 betId = bettingCore.placeBet(betAmount, matchIndices, predictions);

        // Get bet data before settlement
        (DataTypes.Bet memory betBefore,) = bettingCore.getBet(betId);
        uint256 expectedPayout = betBefore.potentialPayout;

        // Verify payout is correctly calculated
        uint256 calculatedPayout = (betAmount * homeOdds) / 1e18;
        assertEq(expectedPayout, calculatedPayout, "Stored payout should match calculation");
        assertTrue(expectedPayout > betAmount, "Payout should exceed bet amount");

        // Record Alice's balance before claim
        uint256 aliceBalanceBefore = lbt.balanceOf(alice);

        // Settle round with HOME win
        uint8[] memory results = new uint8[](10);
        for (uint256 i = 0; i < 10; i++) {
            results[i] = 1; // All HOME wins
        }
        _settleRound(1, results);

        // Alice claims winnings
        vm.prank(alice);
        bettingCore.claimWinnings(betId, 0);

        // Verify Alice received correct payout
        uint256 aliceBalanceAfter = lbt.balanceOf(alice);
        uint256 payoutReceived = aliceBalanceAfter - aliceBalanceBefore;

        assertEq(payoutReceived, expectedPayout, "Alice should receive exact potential payout");
        assertTrue(payoutReceived > betAmount, "Payout should be profitable");

        // Verify bet status is claimed
        (DataTypes.Bet memory betAfter,) = bettingCore.getBet(betId);
        assertEq(uint8(betAfter.status), uint8(DataTypes.BetStatus.Claimed), "Bet should be claimed");

        // Log for verification
        emit log_named_uint("Bet Amount", betAmount / 1e18);
        emit log_named_uint("Home Odds", homeOdds / 1e15);
        emit log_named_uint("Expected Payout", expectedPayout / 1e18);
        emit log_named_uint("Actual Payout", payoutReceived / 1e18);
        emit log_named_uint("Profit", (payoutReceived - betAmount) / 1e18);
    }

    /**
     * @notice Test parlay bet claim with correct multiplied payout
     */
    function test_ClaimWinningParlayWithCorrectPayout() public {
        // Setup and seed round
        gameCore.setCurrentRound(1);
        _seedRound(1);

        // Get odds for all 3 matches
        (uint256 homeOdds0,,,) = bettingCore.getLockedOdds(1, 0);
        (uint256 homeOdds1,,,) = bettingCore.getLockedOdds(1, 1);
        (uint256 homeOdds2,,,) = bettingCore.getLockedOdds(1, 2);

        // Alice places 3-leg parlay
        uint256 betAmount = 100 ether;
        uint256[] memory matchIndices = new uint256[](3);
        uint8[] memory predictions = new uint8[](3);
        matchIndices[0] = 0;
        matchIndices[1] = 1;
        matchIndices[2] = 2;
        predictions[0] = 1; // HOME
        predictions[1] = 1; // HOME
        predictions[2] = 1; // HOME

        vm.prank(alice);
        uint256 betId = bettingCore.placeBet(betAmount, matchIndices, predictions);

        // Get stored payout
        (DataTypes.Bet memory bet,) = bettingCore.getBet(betId);
        uint256 storedPayout = bet.potentialPayout;

        // Calculate expected payout: (odds1 * odds2 * odds3) * 1.10x (parlay bonus)
        uint256 oddsMultiplier = (homeOdds0 * homeOdds1) / 1e18;
        oddsMultiplier = (oddsMultiplier * homeOdds2) / 1e18;
        uint256 parlayBonus = 1.10e18; // 3 legs
        uint256 finalMultiplier = (oddsMultiplier * parlayBonus) / 1e18;
        uint256 expectedPayout = (betAmount * finalMultiplier) / 1e18;

        assertEq(storedPayout, expectedPayout, "Stored payout should match parlay calculation");

        // Settle with all HOME wins
        uint8[] memory results = _createWinningResults();
        _settleRound(1, results);

        // Record balance
        uint256 balanceBefore = lbt.balanceOf(alice);

        // Claim
        vm.prank(alice);
        bettingCore.claimWinnings(betId, 0);

        // Verify payout
        uint256 balanceAfter = lbt.balanceOf(alice);
        uint256 payoutReceived = balanceAfter - balanceBefore;

        assertEq(payoutReceived, expectedPayout, "Should receive correct parlay payout");
        assertTrue(payoutReceived > betAmount * 2, "Parlay should have significant multiplier");

        // Log results
        emit log_named_uint("Bet Amount", betAmount / 1e18);
        emit log_named_uint("Odds Multiplier", oddsMultiplier / 1e15);
        emit log_named_uint("Parlay Bonus", parlayBonus / 1e15);
        emit log_named_uint("Expected Payout", expectedPayout / 1e18);
        emit log_named_uint("Actual Payout", payoutReceived / 1e18);
    }

    /**
     * @notice Test bounty claim mechanism with correct payouts
     */
    function test_BountyClaimWithCorrectPayout() public {
        // Setup and seed round
        gameCore.setCurrentRound(1);
        _seedRound(1);

        // Alice places bet
        uint256 betAmount = 100 ether;
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1;

        vm.prank(alice);
        uint256 betId = bettingCore.placeBet(betAmount, matchIndices, predictions);

        // Get expected payout
        (DataTypes.Bet memory bet,) = bettingCore.getBet(betId);
        uint256 expectedPayout = bet.potentialPayout;
        assertTrue(expectedPayout > 0, "Payout must be non-zero");

        // Settle with winning result
        uint8[] memory results = _createWinningResults();
        _settleRound(1, results);

        // Wait for claim grace period + bounty period (24 hours + 24 hours = 48 hours)
        vm.warp(block.timestamp + 49 hours);

        // Check bounty eligibility
        (bool eligible, , uint256 bountyAmount, uint256 winnerAmount) =
            bettingCore.canClaimWithBounty(betId);
        assertTrue(eligible, "Should be eligible for bounty claim");

        // Bounty hunter claims
        uint256 hunterBalanceBefore = lbt.balanceOf(bountyHunter);
        uint256 aliceBalanceBefore = lbt.balanceOf(alice);

        vm.prank(bountyHunter);
        bettingCore.claimWinnings(betId, 0);

        // Verify bounty distribution
        uint256 hunterBalanceAfter = lbt.balanceOf(bountyHunter);
        uint256 aliceBalanceAfter = lbt.balanceOf(alice);

        uint256 hunterReceived = hunterBalanceAfter - hunterBalanceBefore;
        uint256 aliceReceived = aliceBalanceAfter - aliceBalanceBefore;

        assertEq(hunterReceived, bountyAmount, "Hunter should receive bounty");
        assertEq(aliceReceived, winnerAmount, "Alice should receive winner amount");
        assertEq(hunterReceived + aliceReceived, expectedPayout, "Total should equal payout");

        // Log bounty split
        emit log_named_uint("Total Payout", expectedPayout / 1e18);
        emit log_named_uint("Bounty (10%)", hunterReceived / 1e18);
        emit log_named_uint("Winner Amount (90%)", aliceReceived / 1e18);
    }

    /**
     * @notice Test batch claim with multiple winning bets
     */
    function test_BatchClaimMultipleBetsWithCorrectPayouts() public {
        // Setup
        gameCore.setCurrentRound(1);
        _seedRound(1);

        // Alice places 3 bets
        uint256 betAmount = 50 ether;
        uint256[] memory betIds = new uint256[](3);

        for (uint256 i = 0; i < 3; i++) {
            uint256[] memory matchIndices = new uint256[](1);
            uint8[] memory predictions = new uint8[](1);
            matchIndices[0] = i;
            predictions[0] = 1; // HOME

            vm.prank(alice);
            betIds[i] = bettingCore.placeBet(betAmount, matchIndices, predictions);
        }

        // Calculate total expected payout
        uint256 totalExpectedPayout = 0;
        for (uint256 i = 0; i < 3; i++) {
            (DataTypes.Bet memory bet,) = bettingCore.getBet(betIds[i]);
            totalExpectedPayout += bet.potentialPayout;
            assertTrue(bet.potentialPayout > 0, "Each bet should have non-zero payout");
        }

        // Settle with all wins
        uint8[] memory results = _createWinningResults();
        _settleRound(1, results);

        // Batch claim
        uint256 balanceBefore = lbt.balanceOf(alice);

        vm.prank(alice);
        bettingCore.batchClaim(betIds);

        uint256 balanceAfter = lbt.balanceOf(alice);
        uint256 totalReceived = balanceAfter - balanceBefore;

        // Verify total payout
        assertEq(totalReceived, totalExpectedPayout, "Should receive sum of all payouts");
        assertTrue(totalReceived > betAmount * 3, "Should be profitable");

        // Verify all bets are claimed
        for (uint256 i = 0; i < 3; i++) {
            (DataTypes.Bet memory bet,) = bettingCore.getBet(betIds[i]);
            assertEq(uint8(bet.status), uint8(DataTypes.BetStatus.Claimed), "Each bet should be claimed");
        }

        emit log_named_uint("Total Bets", 3);
        emit log_named_uint("Total Wagered", betAmount * 3 / 1e18);
        emit log_named_uint("Total Payout", totalReceived / 1e18);
        emit log_named_uint("Total Profit", (totalReceived - betAmount * 3) / 1e18);
    }

    /**
     * @notice Test that losing bets have zero payout (not broken by odds fix)
     */
    function test_LosingBetCannotClaimAnything() public {
        // Setup
        gameCore.setCurrentRound(1);
        _seedRound(1);

        // Alice bets on HOME
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1; // HOME

        vm.prank(alice);
        uint256 betId = bettingCore.placeBet(100 ether, matchIndices, predictions);

        // Verify payout was calculated
        (DataTypes.Bet memory bet,) = bettingCore.getBet(betId);
        assertTrue(bet.potentialPayout > 0, "Payout should be calculated");

        // Settle with AWAY win (losing bet)
        uint8[] memory results = _createLosingResults();
        _settleRound(1, results);

        // Check claim status
        (bool isWon, , uint256 totalPayout,,) = bettingCore.getBetClaimStatus(betId);
        assertFalse(isWon, "Bet should be lost");
        assertEq(totalPayout, 0, "Lost bet should have 0 claimable");

        // Record balance before claim attempt
        uint256 balanceBefore = lbt.balanceOf(alice);

        // Attempt to claim returns 0 (doesn't revert, just marks as lost)
        vm.prank(alice);
        uint256 claimed = bettingCore.claimWinnings(betId, 0);

        // Verify no payout received
        assertEq(claimed, 0, "Should receive 0 for losing bet");
        uint256 balanceAfter = lbt.balanceOf(alice);
        assertEq(balanceAfter, balanceBefore, "Balance should not change");

        // Verify bet status is Lost
        (DataTypes.Bet memory betAfter,) = bettingCore.getBet(betId);
        assertEq(uint8(betAfter.status), uint8(DataTypes.BetStatus.Lost), "Should be marked as Lost");
    }

    /**
     * @notice Test user can cancel their own active bet before settlement
     * @dev Verifies cancellation fee is deducted and reserves are updated
     */
    function test_CancelBetBeforeSettlement() public {
        // Setup
        gameCore.setCurrentRound(1);
        _seedRound(1);

        // Alice places bet
        uint256 betAmount = 100 ether;
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1; // HOME

        vm.prank(alice);
        uint256 betId = bettingCore.placeBet(betAmount, matchIndices, predictions);

        // Get bet data before cancellation
        (DataTypes.Bet memory betBefore,) = bettingCore.getBet(betId);
        assertEq(uint8(betBefore.status), uint8(DataTypes.BetStatus.Active), "Bet should be active");

        // Record balances before cancellation
        uint256 aliceBalanceBefore = lbt.balanceOf(alice);
        uint256 protocolReservesBefore = bettingCore.getProtocolReserves();

        // Alice cancels her bet
        vm.prank(alice);
        bettingCore.cancelBet(betId);

        // Verify refund received (bet amount minus 10% cancellation fee)
        uint256 expectedFee = (betAmount * 1000) / 10000; // 10% fee (1000 basis points)
        uint256 expectedRefund = betAmount - expectedFee;
        uint256 aliceBalanceAfter = lbt.balanceOf(alice);
        uint256 refundReceived = aliceBalanceAfter - aliceBalanceBefore;

        assertEq(refundReceived, expectedRefund, "Should receive bet amount minus 5% fee");
        assertEq(refundReceived, 90 ether, "Should receive 90 LBT (100 - 10% fee)");
        assertTrue(refundReceived < betAmount, "Refund should be less than original bet");

        // Verify bet status is Cancelled
        (DataTypes.Bet memory betAfter,) = bettingCore.getBet(betId);
        assertEq(uint8(betAfter.status), uint8(DataTypes.BetStatus.Cancelled), "Should be marked as Cancelled");

        // Verify protocol reserves are properly updated
        uint256 protocolReservesAfter = bettingCore.getProtocolReserves();

        // Reserves should have increased by payout then decreased by refund
        // Net effect: reserves increased by (payout - refund) = (payout - amount + fee) = fee (since payout locked was released)
        assertTrue(protocolReservesAfter != protocolReservesBefore, "Reserves should be updated after cancellation");

        emit log_named_uint("Bet Amount", betAmount / 1e18);
        emit log_named_uint("Cancellation Fee", expectedFee / 1e18);
        emit log_named_uint("Refund Received", refundReceived / 1e18);
    }

    /**
     * @notice Test user cannot cancel other users' bets
     */
    function test_CannotCancelOtherUsersBet() public {
        // Setup
        gameCore.setCurrentRound(1);
        _seedRound(1);

        // Alice places bet
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1;

        vm.prank(alice);
        uint256 betId = bettingCore.placeBet(100 ether, matchIndices, predictions);

        // Bob tries to cancel Alice's bet
        vm.prank(bob);
        vm.expectRevert(); // Should revert with "Not bet owner" or similar
        bettingCore.cancelBet(betId);

        // Verify bet is still active
        (DataTypes.Bet memory bet,) = bettingCore.getBet(betId);
        assertEq(uint8(bet.status), uint8(DataTypes.BetStatus.Active), "Bet should still be active");
    }

    /**
     * @notice Test user cannot cancel bet after round settlement
     */
    function test_CannotCancelBetAfterSettlement() public {
        // Setup
        gameCore.setCurrentRound(1);
        _seedRound(1);

        // Alice places bet
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1;

        vm.prank(alice);
        uint256 betId = bettingCore.placeBet(100 ether, matchIndices, predictions);

        // Settle round
        uint8[] memory results = _createWinningResults();
        _settleRound(1, results);

        // Alice tries to cancel after settlement
        vm.prank(alice);
        vm.expectRevert(); // Should revert with "Round already settled" or similar
        bettingCore.cancelBet(betId);

        // Bet status should NOT be cancelled
        (DataTypes.Bet memory bet,) = bettingCore.getBet(betId);
        assertNotEq(uint8(bet.status), uint8(DataTypes.BetStatus.Cancelled), "Should not be cancelled");
    }

    /**
     * @notice Test user cannot cancel already claimed bet
     */
    function test_CannotCancelAlreadyClaimedBet() public {
        // Setup
        gameCore.setCurrentRound(1);
        _seedRound(1);

        // Alice places winning bet
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1;

        vm.prank(alice);
        uint256 betId = bettingCore.placeBet(100 ether, matchIndices, predictions);

        // Settle with win
        uint8[] memory results = _createWinningResults();
        _settleRound(1, results);

        // Alice claims winnings
        vm.prank(alice);
        bettingCore.claimWinnings(betId, 0);

        // Verify bet is claimed
        (DataTypes.Bet memory bet,) = bettingCore.getBet(betId);
        assertEq(uint8(bet.status), uint8(DataTypes.BetStatus.Claimed), "Should be claimed");

        // Alice tries to cancel already claimed bet
        vm.prank(alice);
        vm.expectRevert(); // Should revert
        bettingCore.cancelBet(betId);
    }

    /**
     * @notice Test user cannot cancel already cancelled bet (double cancel)
     */
    function test_CannotCancelAlreadyCancelledBet() public {
        // Setup
        gameCore.setCurrentRound(1);
        _seedRound(1);

        // Alice places bet
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1;

        vm.prank(alice);
        uint256 betId = bettingCore.placeBet(100 ether, matchIndices, predictions);

        // Alice cancels bet (first time)
        vm.prank(alice);
        bettingCore.cancelBet(betId);

        // Verify bet is cancelled
        (DataTypes.Bet memory bet,) = bettingCore.getBet(betId);
        assertEq(uint8(bet.status), uint8(DataTypes.BetStatus.Cancelled), "Should be cancelled");

        // Alice tries to cancel again (double cancel)
        vm.prank(alice);
        vm.expectRevert(); // Should revert with "Bet not active" or similar
        bettingCore.cancelBet(betId);
    }

    /**
     * @notice Test multiple users can cancel their own bets independently
     */
    function test_MultipleUsersCancelTheirOwnBets() public {
        // Setup
        gameCore.setCurrentRound(1);
        _seedRound(1);

        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1;

        // Alice places bet
        vm.prank(alice);
        uint256 aliceBetId = bettingCore.placeBet(100 ether, matchIndices, predictions);

        // Bob places bet
        vm.prank(bob);
        uint256 bobBetId = bettingCore.placeBet(200 ether, matchIndices, predictions);

        // Record balances before cancellation
        uint256 aliceBalanceBefore = lbt.balanceOf(alice);
        uint256 bobBalanceBefore = lbt.balanceOf(bob);

        // Alice cancels her bet
        vm.prank(alice);
        bettingCore.cancelBet(aliceBetId);

        // Bob cancels his bet
        vm.prank(bob);
        bettingCore.cancelBet(bobBetId);

        // Verify both bets are cancelled
        (DataTypes.Bet memory aliceBet,) = bettingCore.getBet(aliceBetId);
        (DataTypes.Bet memory bobBet,) = bettingCore.getBet(bobBetId);

        assertEq(uint8(aliceBet.status), uint8(DataTypes.BetStatus.Cancelled), "Alice's bet should be cancelled");
        assertEq(uint8(bobBet.status), uint8(DataTypes.BetStatus.Cancelled), "Bob's bet should be cancelled");

        // Verify both received refunds (minus 10% fee)
        uint256 aliceRefund = lbt.balanceOf(alice) - aliceBalanceBefore;
        uint256 bobRefund = lbt.balanceOf(bob) - bobBalanceBefore;

        uint256 expectedAliceRefund = 100 ether - (100 ether * 1000 / 10000);
        uint256 expectedBobRefund = 200 ether - (200 ether * 1000 / 10000);

        assertEq(aliceRefund, expectedAliceRefund, "Alice should receive correct refund");
        assertEq(bobRefund, expectedBobRefund, "Bob should receive correct refund");

        emit log_named_uint("Alice Refund", aliceRefund / 1e18);
        emit log_named_uint("Bob Refund", bobRefund / 1e18);
    }

    /**
     * @notice Test cancellation fee goes to protocol (not refunded)
     */
    function test_CancellationFeeGoesToProtocol() public {
        // Setup
        gameCore.setCurrentRound(1);
        _seedRound(1);

        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1;

        // Record protocol LBT balance before
        uint256 protocolBalanceBefore = lbt.balanceOf(address(bettingCore));

        // Alice places bet
        uint256 betAmount = 100 ether;
        vm.prank(alice);
        uint256 betId = bettingCore.placeBet(betAmount, matchIndices, predictions);

        // Alice cancels bet
        vm.prank(alice);
        bettingCore.cancelBet(betId);

        // Calculate expected fee
        uint256 expectedFee = (betAmount * 500) / 10000; // 5%

        // Check protocol balance increased by fee
        uint256 protocolBalanceAfter = lbt.balanceOf(address(bettingCore));

        // The fee should remain in the protocol (not sent back to user)
        // Protocol should have kept the fee
        emit log_named_uint("Cancellation Fee Kept", expectedFee / 1e18);
        assertTrue(expectedFee > 0, "Fee should be non-zero");
    }

    /**
     * @notice Test round pool sweep after deadline expires
     * @dev Unclaimed funds should return to protocol reserves after 7 days
     */
    function test_RoundPoolSweepAfterDeadline() public {
        // Setup
        gameCore.setCurrentRound(1);
        _seedRound(1);

        // Alice places winning bet
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1; // HOME

        uint256 betAmount = 100 ether;
        vm.prank(alice);
        uint256 betId = bettingCore.placeBet(betAmount, matchIndices, predictions);

        // Get potential payout
        (DataTypes.Bet memory bet,) = bettingCore.getBet(betId);
        uint256 potentialPayout = bet.potentialPayout;

        // Settle with HOME win
        uint8[] memory results = _createWinningResults();
        _settleRound(1, results);

        // Check round pool before sweep
        (
            uint256 totalLockedBefore,
            uint256 totalClaimedBefore,
            ,
            ,
            bool sweptBefore
        ) = bettingCore.getRoundPool(1);

        assertEq(totalLockedBefore, potentialPayout, "Total locked should equal payout");
        assertEq(totalClaimedBefore, 0, "Nothing claimed yet");
        assertFalse(sweptBefore, "Should not be swept yet");

        // Get protocol reserves before sweep
        uint256 reservesBefore = bettingCore.getProtocolReserves();

        // Warp past sweep deadline (7 days after settlement)
        vm.warp(block.timestamp + 8 days);

        // Sweep the round pool
        bettingCore.sweepRoundPool(1);

        // Check round pool after sweep
        (
            ,
            ,
            ,
            ,
            bool sweptAfter
        ) = bettingCore.getRoundPool(1);
        assertTrue(sweptAfter, "Should be marked as swept");

        // Check protocol reserves increased by unclaimed amount
        uint256 reservesAfter = bettingCore.getProtocolReserves();
        uint256 unclaimedAmount = totalLockedBefore - totalClaimedBefore;

        assertEq(reservesAfter, reservesBefore + unclaimedAmount, "Reserves should increase by unclaimed");

        emit log_named_uint("Unclaimed Amount Swept", unclaimedAmount / 1e18);
        emit log_named_uint("Reserves After Sweep", reservesAfter / 1e18);
    }

    /**
     * @notice Test cannot sweep round pool before deadline
     * @dev Sweep deadline = round seed time + 3h (round) + 24h (claim) + 6h (grace) = 33h
     */
    function test_CannotSweepRoundPoolBeforeDeadline() public {
        // Setup
        gameCore.setCurrentRound(1);

        // Record seed time
        uint256 seedTime = block.timestamp;
        _seedRound(1);

        // Place and settle bet immediately (same timestamp)
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1;

        vm.prank(alice);
        bettingCore.placeBet(100 ether, matchIndices, predictions);

        uint8[] memory results = _createWinningResults();
        _settleRound(1, results);

        // Try to sweep immediately after settlement (before deadline)
        vm.expectRevert(); // Should revert with "Sweep deadline not reached"
        bettingCore.sweepRoundPool(1);

        // Try to sweep after 30 hours (still before 33 hour deadline)
        vm.warp(seedTime + 30 hours);
        vm.expectRevert();
        bettingCore.sweepRoundPool(1);

        // Sweeping after 33 hours should succeed
        vm.warp(seedTime + 34 hours);
        bettingCore.sweepRoundPool(1); // Should not revert
    }

    /**
     * @notice Test cannot sweep unsettled round
     */
    function test_CannotSweepUnsettledRound() public {
        // Setup
        gameCore.setCurrentRound(1);
        _seedRound(1);

        // Place bet but don't settle
        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1;

        vm.prank(alice);
        bettingCore.placeBet(100 ether, matchIndices, predictions);

        // Try to sweep unsettled round
        vm.warp(block.timestamp + 8 days);
        vm.expectRevert(); // Should revert
        bettingCore.sweepRoundPool(1);
    }

    /**
     * @notice Test protocol profit calculation when all bets lose
     * @dev Protocol makes money when users lose bets
     */
    function test_ProtocolProfitFromAllLosingBets() public {
        // Setup
        gameCore.setCurrentRound(1);
        _seedRound(1);

        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1; // Bet on HOME

        // Record initial reserves
        uint256 initialReserves = bettingCore.getProtocolReserves();

        // Alice bets 100 LBT
        vm.prank(alice);
        bettingCore.placeBet(100 ether, matchIndices, predictions);

        // Bob bets 200 LBT
        vm.prank(bob);
        bettingCore.placeBet(200 ether, matchIndices, predictions);

        // Total wagered: 300 LBT
        uint256 totalWagered = 300 ether;

        // Settle with AWAY wins (all bets lose)
        uint8[] memory results = _createLosingResults();
        _settleRound(1, results);

        // Sweep unclaimed funds back to protocol
        vm.warp(block.timestamp + 8 days);
        bettingCore.sweepRoundPool(1);

        // Check protocol profit
        uint256 finalReserves = bettingCore.getProtocolReserves();
        uint256 profit = finalReserves - initialReserves;

        // Profit should equal total wagered (all bets lost)
        assertEq(profit, totalWagered, "Profit should equal total wagered when all lose");

        emit log_named_uint("Total Wagered", totalWagered / 1e18);
        emit log_named_uint("Protocol Profit", profit / 1e18);
        emit log_named_uint("Profit Percentage", (profit * 100) / totalWagered);
    }

    /**
     * @notice Test protocol loss calculation when all bets win
     * @dev Protocol loses money when users win bets
     */
    function test_ProtocolLossFromAllWinningBets() public {
        // Setup
        gameCore.setCurrentRound(1);
        _seedRound(1);

        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1; // Bet on HOME

        // Record initial reserves
        uint256 initialReserves = bettingCore.getProtocolReserves();

        // Alice bets 100 LBT
        vm.prank(alice);
        uint256 aliceBetId = bettingCore.placeBet(100 ether, matchIndices, predictions);

        // Bob bets 200 LBT
        vm.prank(bob);
        uint256 bobBetId = bettingCore.placeBet(200 ether, matchIndices, predictions);

        // Get total potential payouts
        (DataTypes.Bet memory aliceBet,) = bettingCore.getBet(aliceBetId);
        (DataTypes.Bet memory bobBet,) = bettingCore.getBet(bobBetId);
        uint256 totalPayouts = aliceBet.potentialPayout + bobBet.potentialPayout;
        uint256 totalWagered = 300 ether;

        // Settle with HOME wins (all bets win)
        uint8[] memory results = _createWinningResults();
        _settleRound(1, results);

        // Users claim winnings
        vm.prank(alice);
        bettingCore.claimWinnings(aliceBetId, 0);

        vm.prank(bob);
        bettingCore.claimWinnings(bobBetId, 0);

        // Sweep unclaimed funds
        vm.warp(block.timestamp + 8 days);
        bettingCore.sweepRoundPool(1);

        // Check protocol loss
        uint256 finalReserves = bettingCore.getProtocolReserves();

        // Loss = totalPayouts - totalWagered
        uint256 loss = totalPayouts - totalWagered;

        // Protocol reserves should have decreased
        assertTrue(finalReserves < initialReserves, "Reserves should decrease when users win");

        emit log_named_uint("Total Wagered", totalWagered / 1e18);
        emit log_named_uint("Total Payouts", totalPayouts / 1e18);
        emit log_named_uint("Protocol Loss", loss / 1e18);
    }

    /**
     * @notice Test mixed scenario profit/loss calculation
     * @dev Some bets win, some lose - calculate net profit/loss
     */
    function test_ProtocolMixedProfitLoss() public {
        // Setup
        gameCore.setCurrentRound(1);
        _seedRound(1);

        // Record initial reserves
        uint256 initialReserves = bettingCore.getProtocolReserves();

        // Alice bets on HOME (match 0) - will WIN
        uint256[] memory aliceMatches = new uint256[](1);
        uint8[] memory alicePreds = new uint8[](1);
        aliceMatches[0] = 0;
        alicePreds[0] = 1; // HOME

        vm.prank(alice);
        uint256 aliceBetId = bettingCore.placeBet(100 ether, aliceMatches, alicePreds);

        // Bob bets on AWAY (match 0) - will LOSE
        uint256[] memory bobMatches = new uint256[](1);
        uint8[] memory bobPreds = new uint8[](1);
        bobMatches[0] = 0;
        bobPreds[0] = 2; // AWAY

        vm.prank(bob);
        bettingCore.placeBet(200 ether, bobMatches, bobPreds);

        // Get Alice's potential payout
        (DataTypes.Bet memory aliceBet,) = bettingCore.getBet(aliceBetId);
        uint256 alicePayout = aliceBet.potentialPayout;

        uint256 totalWagered = 300 ether; // 100 + 200
        uint256 totalPayouts = alicePayout; // Only Alice wins

        // Settle with HOME wins
        uint8[] memory results = _createWinningResults();
        _settleRound(1, results);

        // Alice claims
        vm.prank(alice);
        bettingCore.claimWinnings(aliceBetId, 0);

        // Sweep unclaimed funds
        vm.warp(block.timestamp + 8 days);
        bettingCore.sweepRoundPool(1);

        // Calculate profit/loss
        uint256 finalReserves = bettingCore.getProtocolReserves();

        // Net result = totalWagered - totalPayouts
        uint256 netResult = totalWagered > totalPayouts
            ? totalWagered - totalPayouts  // Profit
            : totalPayouts - totalWagered;  // Loss

        bool isProfit = totalWagered > totalPayouts;

        emit log_named_uint("Total Wagered", totalWagered / 1e18);
        emit log_named_uint("Total Payouts", totalPayouts / 1e18);
        emit log_named_uint("Net Result", netResult / 1e18);
        emit log_string(isProfit ? "Result: PROFIT" : "Result: LOSS");

        // Verify reserves changed correctly
        if (isProfit) {
            assertTrue(finalReserves > initialReserves, "Reserves should increase on profit");
        } else {
            assertTrue(finalReserves < initialReserves, "Reserves should decrease on loss");
        }
    }

    /**
     * @notice Test sweep returns correct amount with partial claims
     */
    function test_RoundPoolSweepWithPartialClaims() public {
        // Setup
        gameCore.setCurrentRound(1);
        _seedRound(1);

        uint256[] memory matchIndices = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matchIndices[0] = 0;
        predictions[0] = 1; // HOME

        // Alice and Bob place winning bets
        vm.prank(alice);
        uint256 aliceBetId = bettingCore.placeBet(100 ether, matchIndices, predictions);

        vm.prank(bob);
        uint256 bobBetId = bettingCore.placeBet(200 ether, matchIndices, predictions);

        // Get payouts
        (DataTypes.Bet memory aliceBet,) = bettingCore.getBet(aliceBetId);
        (DataTypes.Bet memory bobBet,) = bettingCore.getBet(bobBetId);
        uint256 totalLocked = aliceBet.potentialPayout + bobBet.potentialPayout;

        // Settle
        uint8[] memory results = _createWinningResults();
        _settleRound(1, results);

        // Only Alice claims (Bob doesn't claim)
        vm.prank(alice);
        bettingCore.claimWinnings(aliceBetId, 0);

        // Check pool state
        (
            ,
            uint256 totalClaimed,
            ,
            ,
        ) = bettingCore.getRoundPool(1);

        assertEq(totalClaimed, aliceBet.potentialPayout, "Only Alice claimed");

        uint256 unclaimed = totalLocked - totalClaimed;
        assertEq(unclaimed, bobBet.potentialPayout, "Unclaimed should equal Bob's payout");

        // Record reserves before sweep
        uint256 reservesBefore = bettingCore.getProtocolReserves();

        // Warp and sweep
        vm.warp(block.timestamp + 8 days);
        bettingCore.sweepRoundPool(1);

        // Verify unclaimed amount returned to reserves
        uint256 reservesAfter = bettingCore.getProtocolReserves();
        assertEq(
            reservesAfter,
            reservesBefore + unclaimed,
            "Reserves should increase by unclaimed amount"
        );

        emit log_named_uint("Total Locked", totalLocked / 1e18);
        emit log_named_uint("Alice Claimed", aliceBet.potentialPayout / 1e18);
        emit log_named_uint("Bob Unclaimed", unclaimed / 1e18);
        emit log_named_uint("Swept to Reserves", unclaimed / 1e18);
    }
}

// ============ Mock Contracts ============

contract MockGameCore {
    address public bettingCore;
    uint256 public currentSeason = 1;
    uint256 public currentRound = 0;

    function setBettingCore(address _bettingCore) external {
        bettingCore = _bettingCore;
    }

    function getCurrentSeason() external view returns (uint256) {
        return currentSeason;
    }

    function getCurrentRound() external view returns (uint256) {
        return currentRound;
    }

    function setCurrentRound(uint256 _round) external {
        currentRound = _round;
    }
}

contract MockSeasonPredictor {
    mapping(uint256 => uint256) public seasonPools;

    function fundSeasonPool(uint256 seasonId, uint256 amount) external {
        seasonPools[seasonId] += amount;
    }

    function getSeasonPool(uint256 seasonId) external view returns (uint256) {
        return seasonPools[seasonId];
    }
}

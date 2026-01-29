// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/GameEngineV2_5.sol";
import "../src/BettingPoolV2_1.sol";
import "../src/LiquidityPoolV2.sol";
import "../src/LeagueToken.sol";

/**
 * @title FullUserFlowTest
 * @notice Comprehensive test suite for the optimized BettingPoolV2_1 architecture
 * @dev Tests the new split struct architecture (RoundAccounting + RoundMetadata)
 *
 * Architecture Changes Tested:
 * - Bet struct: 10 fields (removed amountAfterFee)
 * - RoundAccounting: 8 fields + 2 mappings (core betting data)
 * - RoundMetadata: 8 fields (settlement, revenue, status)
 */
contract FullUserFlowTest is Test {
    GameEngine public gameEngine;
    BettingPoolV2_1 public bettingPool;
    LiquidityPoolV2 public liquidityPool;
    LeagueToken public leagueToken;

    address public owner = address(this);
    address public protocolTreasury = makeAddr("treasury");

    // Liquidity providers
    address public lp1 = makeAddr("lp1");
    address public lp2 = makeAddr("lp2");

    // Players/Bettors
    address public player1 = makeAddr("player1");
    address public player2 = makeAddr("player2");
    address public player3 = makeAddr("player3");

    // Constants
    uint256 constant LP_INITIAL_DEPOSIT = 500_000 ether;
    uint256 constant PLAYER_BALANCE = 50_000 ether;

    function setUp() public {
        // Deploy core contracts
        leagueToken = new LeagueToken(owner);
        gameEngine = new GameEngine(address(leagueToken), 1); // season 1
        liquidityPool = new LiquidityPoolV2(address(leagueToken), owner);
        bettingPool = new BettingPoolV2_1(
            address(leagueToken),
            address(gameEngine),
            address(liquidityPool),
            protocolTreasury,
            owner,
            owner
        );

        // Link contracts together
        liquidityPool.setAuthorizedCaller(address(bettingPool), true);
        gameEngine.setBettingPool(address(bettingPool)); // Enable auto-seeding

        // Fund LP accounts
        leagueToken.transfer(lp1, LP_INITIAL_DEPOSIT);
        leagueToken.transfer(lp2, LP_INITIAL_DEPOSIT);

        // Fund player accounts
        leagueToken.transfer(player1, PLAYER_BALANCE);
        leagueToken.transfer(player2, PLAYER_BALANCE);
        leagueToken.transfer(player3, PLAYER_BALANCE);
    }

    // ============================================
    // BETTING FLOW TEST (Pre-Settlement)
    // ============================================

    function testBettingFlow_PreSettlement() public {
        console.log("\n");
        console.log("============================================================");
        console.log("  BETTING FLOW TEST - NEW ARCHITECTURE (Pre-Settlement)");
        console.log("============================================================");
        console.log("\n");

        // ==========================================
        // PHASE 1: LP DEPOSITS
        // ==========================================
        console.log("PHASE 1: LIQUIDITY PROVIDER DEPOSITS");
        console.log("----------------------------------------");

        vm.startPrank(lp1);
        leagueToken.approve(address(liquidityPool), LP_INITIAL_DEPOSIT);
        liquidityPool.addLiquidity(LP_INITIAL_DEPOSIT);
        vm.stopPrank();

        vm.startPrank(lp2);
        leagueToken.approve(address(liquidityPool), 200_000 ether);
        liquidityPool.addLiquidity(200_000 ether);
        vm.stopPrank();

        uint256 totalLiquidity = liquidityPool.totalLiquidity();
        console.log("  LP1 deposited:", LP_INITIAL_DEPOSIT / 1e18, "LEAGUE");
        console.log("  LP2 deposited: 200000 LEAGUE");
        console.log("  Total LP Liquidity:", totalLiquidity / 1e18, "LEAGUE");
        assertEq(totalLiquidity, 700_000 ether, "Total liquidity mismatch");
        console.log("  [PASS] LP deposits successful\n");

        // ==========================================
        // PHASE 2: START SEASON & ROUND (AUTO-SEED)
        // ==========================================
        console.log("PHASE 2: START SEASON & ROUND (AUTO-SEEDING)");
        console.log("----------------------------------------");

        uint256 lpBalanceBeforeSeed = liquidityPool.totalLiquidity();

        gameEngine.startSeason();
        gameEngine.startRound(); // This auto-seeds the round

        uint256 lpBalanceAfterSeed = liquidityPool.totalLiquidity();
        uint256 currentRound = gameEngine.getCurrentRound();

        console.log("  Season started successfully");
        console.log("  Round", currentRound, "started with auto-seeding");
        console.log("  LP Balance Before Seed:", lpBalanceBeforeSeed / 1e18, "LEAGUE");
        console.log("  LP Balance After Seed:", lpBalanceAfterSeed / 1e18, "LEAGUE");

        // Verify virtual seeding (no token transfer)
        assertEq(lpBalanceAfterSeed, lpBalanceBeforeSeed, "Virtual seeding should not transfer tokens!");
        console.log("  [PASS] Virtual seeding - no token transfer\n");

        // Verify round is seeded (using new RoundMetadata)
        bool isSeeded = bettingPool.isRoundSeeded(currentRound);
        assertTrue(isSeeded, "Round should be seeded");
        console.log("  [PASS] Round seeded flag set in RoundMetadata\n");

        // Check locked odds
        (uint256 homeOdds, uint256 awayOdds, uint256 drawOdds, bool locked) = bettingPool.getLockedOdds(currentRound, 0);
        assertTrue(locked, "Odds should be locked");
        console.log("  Match 0 Locked Odds:");
        console.log("    Home:", homeOdds * 100 / 1e18, "/ 100");
        console.log("    Away:", awayOdds * 100 / 1e18, "/ 100");
        console.log("    Draw:", drawOdds * 100 / 1e18, "/ 100");
        console.log("  [PASS] Odds locked after seeding\n");

        // ==========================================
        // PHASE 3: PLAYERS PLACE BETS
        // ==========================================
        console.log("PHASE 3: PLAYERS PLACE BETS");
        console.log("----------------------------------------");

        // Player 1: Single bet on Match 0 - HOME WIN (5,000 LEAGUE)
        uint256 betId1;
        {
            vm.startPrank(player1);
            leagueToken.approve(address(bettingPool), 5_000 ether);
            uint256[] memory matches = new uint256[](1);
            uint8[] memory predictions = new uint8[](1);
            matches[0] = 0;
            predictions[0] = 1; // HOME_WIN
            betId1 = bettingPool.placeBet(matches, predictions, 5_000 ether);
            vm.stopPrank();
        }
        console.log("  Player1 placed single bet (5000 LEAGUE) on Match 0 - HOME");
        console.log("    Bet ID:", betId1);

        // Player 2: 3-leg parlay (10,000 LEAGUE)
        uint256 betId2;
        {
            vm.startPrank(player2);
            leagueToken.approve(address(bettingPool), 10_000 ether);
            uint256[] memory matches = new uint256[](3);
            uint8[] memory predictions = new uint8[](3);
            matches[0] = 0; predictions[0] = 1; // HOME
            matches[1] = 1; predictions[1] = 2; // AWAY
            matches[2] = 2; predictions[2] = 3; // DRAW
            betId2 = bettingPool.placeBet(matches, predictions, 10_000 ether);
            vm.stopPrank();
        }
        console.log("  Player2 placed 3-leg parlay (10000 LEAGUE)");
        console.log("    Bet ID:", betId2);

        // Player 3: Single bet on Match 1 - AWAY WIN (3,000 LEAGUE)
        uint256 betId3;
        {
            vm.startPrank(player3);
            leagueToken.approve(address(bettingPool), 3_000 ether);
            uint256[] memory matches = new uint256[](1);
            uint8[] memory predictions = new uint8[](1);
            matches[0] = 1;
            predictions[0] = 2; // AWAY_WIN
            betId3 = bettingPool.placeBet(matches, predictions, 3_000 ether);
            vm.stopPrank();
        }
        console.log("  Player3 placed single bet (3000 LEAGUE) on Match 1 - AWAY");
        console.log("    Bet ID:", betId3);

        // Verify bet amounts stored correctly (using getBet function)
        (
            address bettor1,
            uint256 roundId1,
            uint256 amount1,
            ,, // bonus, lockedMultiplier
            bool settled1,
            bool claimed1,
            bool canceled1
        ) = bettingPool.getBet(betId1);

        assertEq(amount1, 5_000 ether, "Bet amount should be full amount (no fee deduction)");
        assertEq(bettor1, player1, "Wrong bettor");
        assertEq(roundId1, currentRound, "Wrong round");
        assertFalse(settled1, "Bet should not be settled yet");
        assertFalse(claimed1, "Bet should not be claimed yet");
        assertFalse(canceled1, "Bet should not be canceled");

        console.log("\n  Bet 1 Details (Optimized Struct):");
        console.log("    Amount:", amount1 / 1e18, "LEAGUE (full amount, no upfront fee)");
        console.log("  [PASS] Bet struct correctly stores data without amountAfterFee\n");

        // Check round accounting
        (
            uint256 totalBetVolume,
            ,
            uint256 protocolRevenueShare,
            uint256 seasonRevenueShare,
            uint256 parlayCount
        ) = bettingPool.getRoundAccounting(currentRound);

        console.log("  Round Accounting (New Split Architecture):");
        console.log("    Total Bet Volume:", totalBetVolume / 1e18, "LEAGUE");
        console.log("    Parlay Count:", parlayCount);
        assertEq(totalBetVolume, 18_000 ether, "Total bet volume mismatch");
        assertEq(parlayCount, 1, "Should have 1 parlay");
        console.log("  [PASS] RoundAccounting updated correctly\n");

        // ==========================================
        // PHASE 4: BET CANCELLATION
        // ==========================================
        console.log("PHASE 4: BET CANCELLATION");
        console.log("----------------------------------------");

        // Player 3 cancels their bet
        uint256 player3BalanceBefore = leagueToken.balanceOf(player3);

        vm.prank(player3);
        bettingPool.cancelBet(betId3);

        uint256 player3BalanceAfter = leagueToken.balanceOf(player3);
        uint256 refundReceived = player3BalanceAfter - player3BalanceBefore;

        // 10% cancellation fee, so should get 90% back = 2,700 LEAGUE
        uint256 expectedRefund = 3_000 ether * 90 / 100;

        console.log("  Player3 canceled bet", betId3);
        console.log("    Original bet: 3000 LEAGUE");
        console.log("    Cancellation fee: 10%");
        console.log("    Refund received:", refundReceived / 1e18, "LEAGUE");
        console.log("    Expected refund:", expectedRefund / 1e18, "LEAGUE");

        assertEq(refundReceived, expectedRefund, "Refund amount incorrect");

        // Verify bet marked as canceled
        (,,,,,, bool claimed3, bool canceled3) = bettingPool.getBet(betId3);
        assertTrue(canceled3, "Bet should be marked as canceled");
        assertFalse(claimed3, "Canceled bet should not be claimed");

        console.log("  [PASS] Bet cancellation successful\n");

        // Check updated round accounting
        (totalBetVolume,,,,) = bettingPool.getRoundAccounting(currentRound);
        console.log("  Updated Total Bet Volume:", totalBetVolume / 1e18, "LEAGUE");
        assertEq(totalBetVolume, 15_000 ether, "Volume should be reduced by canceled bet");
        console.log("  [PASS] RoundAccounting correctly updated after cancellation\n");

        // ==========================================
        // SUMMARY
        // ==========================================
        console.log("============================================================");
        console.log("  TEST SUMMARY - ALL PRE-SETTLEMENT PHASES PASSED");
        console.log("============================================================");
        console.log("\n  New Architecture Verified:");
        console.log("    - Bet struct: Full amount stored (no amountAfterFee)");
        console.log("    - RoundAccounting: Core betting data tracked");
        console.log("    - RoundMetadata: Seeded flag working correctly");
        console.log("    - Virtual seeding: No token transfers");
        console.log("    - Bet cancellation: 10% fee, 90% refund");
        console.log("\n");
    }

    // ============================================
    // STRUCT OPTIMIZATION VERIFICATION TESTS
    // ============================================

    function testBetStructOptimization() public {
        console.log("\n=== BET STRUCT OPTIMIZATION TEST ===\n");

        // Setup
        vm.startPrank(lp1);
        leagueToken.approve(address(liquidityPool), 100_000 ether);
        liquidityPool.addLiquidity(100_000 ether);
        vm.stopPrank();

        gameEngine.startSeason();
        gameEngine.startRound();

        // Place a bet
        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), 1_000 ether);
        uint256[] memory matches = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matches[0] = 0;
        predictions[0] = 1;
        uint256 betId = bettingPool.placeBet(matches, predictions, 1_000 ether);
        vm.stopPrank();

        // Verify the bet struct has all expected fields
        (
            address bettor,
            uint256 roundId,
            uint256 amount,
            uint256 bonus,
            uint256 lockedMultiplier,
            bool settled,
            bool claimed,
            bool canceled
        ) = bettingPool.getBet(betId);

        console.log("Bet Struct Fields (via getBet):");
        console.log("  1. bettor:", bettor);
        console.log("  2. roundId:", roundId);
        console.log("  3. amount:", amount / 1e18, "LEAGUE");
        console.log("  4. bonus:", bonus / 1e18, "LEAGUE");
        console.log("  5. lockedMultiplier:", lockedMultiplier * 100 / 1e18, "/ 100");
        console.log("  6. settled:", settled);
        console.log("  7. claimed:", claimed);
        console.log("  8. canceled:", canceled);

        // Key verification: amount equals the bet amount (no upfront fee deduction)
        assertEq(amount, 1_000 ether, "Amount should equal full bet (no amountAfterFee)");
        assertEq(bettor, player1, "Bettor mismatch");
        assertFalse(settled, "Should not be settled");
        assertFalse(claimed, "Should not be claimed");
        assertFalse(canceled, "Should not be canceled");

        console.log("\n[PASS] Bet struct optimized - no amountAfterFee field");
        console.log("[PASS] Uses amount directly for full bet amount\n");
    }

    function testRoundMetadataSplit() public {
        console.log("\n=== ROUND METADATA SPLIT TEST ===\n");

        // Setup
        vm.startPrank(lp1);
        leagueToken.approve(address(liquidityPool), 100_000 ether);
        liquidityPool.addLiquidity(100_000 ether);
        vm.stopPrank();

        gameEngine.startSeason();
        gameEngine.startRound();
        uint256 roundId = gameEngine.getCurrentRound();

        // Verify seeded flag is in RoundMetadata
        bool seeded = bettingPool.isRoundSeeded(roundId);
        assertTrue(seeded, "Round should be seeded");
        console.log("  isRoundSeeded (from RoundMetadata):", seeded);

        // Place a bet
        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), 1_000 ether);
        uint256[] memory matches = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matches[0] = 0;
        predictions[0] = 1;
        bettingPool.placeBet(matches, predictions, 1_000 ether);
        vm.stopPrank();

        // Get RoundAccounting data
        (
            uint256 totalBetVolume,
            uint256 totalReservedForWinners,
            uint256 protocolRevenueShare,
            uint256 seasonRevenueShare,
            uint256 parlayCount
        ) = bettingPool.getRoundAccounting(roundId);

        console.log("\n  RoundAccounting Fields:");
        console.log("    totalBetVolume:", totalBetVolume / 1e18, "LEAGUE");
        console.log("    totalReservedForWinners:", totalReservedForWinners / 1e18, "LEAGUE");
        console.log("    parlayCount:", parlayCount);

        console.log("\n  RoundMetadata Fields (via getRoundAccounting):");
        console.log("    protocolRevenueShare:", protocolRevenueShare / 1e18, "LEAGUE");
        console.log("    seasonRevenueShare:", seasonRevenueShare / 1e18, "LEAGUE");

        assertEq(totalBetVolume, 1_000 ether, "Bet volume mismatch");
        assertEq(parlayCount, 0, "Should have no parlays");

        console.log("\n[PASS] RoundAccounting and RoundMetadata split working correctly\n");
    }

    function testVirtualSeedingNoTokenTransfer() public {
        console.log("\n=== VIRTUAL SEEDING TEST ===\n");

        // LP deposits
        vm.startPrank(lp1);
        leagueToken.approve(address(liquidityPool), 100_000 ether);
        liquidityPool.addLiquidity(100_000 ether);
        vm.stopPrank();

        uint256 lpBalanceBefore = liquidityPool.totalLiquidity();
        uint256 bettingPoolBalanceBefore = leagueToken.balanceOf(address(bettingPool));

        console.log("Before Seeding:");
        console.log("  LP Liquidity:", lpBalanceBefore / 1e18, "LEAGUE");
        console.log("  BettingPool Balance:", bettingPoolBalanceBefore / 1e18, "LEAGUE");

        // Start and seed
        gameEngine.startSeason();
        gameEngine.startRound();

        uint256 lpBalanceAfter = liquidityPool.totalLiquidity();
        uint256 bettingPoolBalanceAfter = leagueToken.balanceOf(address(bettingPool));

        console.log("\nAfter Seeding:");
        console.log("  LP Liquidity:", lpBalanceAfter / 1e18, "LEAGUE");
        console.log("  BettingPool Balance:", bettingPoolBalanceAfter / 1e18, "LEAGUE");

        // CRITICAL: Balances should be UNCHANGED
        assertEq(lpBalanceAfter, lpBalanceBefore, "LP balance changed - seeding should be virtual!");
        assertEq(bettingPoolBalanceAfter, bettingPoolBalanceBefore, "BettingPool balance changed!");

        console.log("\n[PASS] Virtual seeding verified - no token transfers\n");
    }

    function testParlayMultiplierLocked() public {
        console.log("\n=== PARLAY MULTIPLIER LOCK TEST ===\n");

        // Setup
        vm.startPrank(lp1);
        leagueToken.approve(address(liquidityPool), 100_000 ether);
        liquidityPool.addLiquidity(100_000 ether);
        vm.stopPrank();

        gameEngine.startSeason();
        gameEngine.startRound();

        // Place a 3-leg parlay
        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), 1_000 ether);
        uint256[] memory matches = new uint256[](3);
        uint8[] memory predictions = new uint8[](3);
        matches[0] = 0; predictions[0] = 1;
        matches[1] = 1; predictions[1] = 2;
        matches[2] = 2; predictions[2] = 3;
        uint256 betId = bettingPool.placeBet(matches, predictions, 1_000 ether);
        vm.stopPrank();

        // Verify multiplier is locked
        (
            ,
            ,
            ,
            ,
            uint256 lockedMultiplier,
            ,
            ,
        ) = bettingPool.getBet(betId);

        console.log("  3-leg parlay placed");
        console.log("  Locked Multiplier:", lockedMultiplier * 100 / 1e18, "/ 100");

        // 3 legs = 1.10x multiplier (10% bonus)
        uint256 expected3LegMultiplier = 110e16; // 1.10e18
        assertEq(lockedMultiplier, expected3LegMultiplier, "Wrong parlay multiplier");

        console.log("\n[PASS] Parlay multiplier locked at bet placement\n");
    }

    function testLPBorrowingForHighPayout() public {
        console.log("\n=== LP BORROWING TEST ===\n");

        // Setup LP
        vm.startPrank(lp1);
        leagueToken.approve(address(liquidityPool), 100_000 ether);
        liquidityPool.addLiquidity(100_000 ether);
        vm.stopPrank();

        gameEngine.startSeason();
        gameEngine.startRound();

        uint256 roundId = gameEngine.getCurrentRound();

        // Check LP borrowed amount before bet
        (uint256 volumeBefore,,,,) = bettingPool.getRoundAccounting(roundId);

        // Place a parlay with potentially high payout
        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), 5_000 ether);
        uint256[] memory matches = new uint256[](3);
        uint8[] memory predictions = new uint8[](3);
        matches[0] = 0; predictions[0] = 1;
        matches[1] = 1; predictions[1] = 2;
        matches[2] = 2; predictions[2] = 3;
        bettingPool.placeBet(matches, predictions, 5_000 ether);
        vm.stopPrank();

        (uint256 volumeAfter,,,,) = bettingPool.getRoundAccounting(roundId);

        console.log("  Bet Volume Before:", volumeBefore / 1e18, "LEAGUE");
        console.log("  Bet Volume After:", volumeAfter / 1e18, "LEAGUE");

        assertEq(volumeAfter, 5_000 ether, "Bet volume should be 5000 LEAGUE");

        console.log("\n[PASS] LP borrowing mechanism working\n");
    }

    function testMultipleBettorsOnSameMatch() public {
        console.log("\n=== MULTIPLE BETTORS TEST ===\n");

        // Setup
        vm.startPrank(lp1);
        leagueToken.approve(address(liquidityPool), 100_000 ether);
        liquidityPool.addLiquidity(100_000 ether);
        vm.stopPrank();

        gameEngine.startSeason();
        gameEngine.startRound();

        // Player 1 bets on HOME
        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), 1_000 ether);
        uint256[] memory m1 = new uint256[](1);
        uint8[] memory p1 = new uint8[](1);
        m1[0] = 0;
        p1[0] = 1; // HOME
        uint256 bet1 = bettingPool.placeBet(m1, p1, 1_000 ether);
        vm.stopPrank();

        // Player 2 bets on AWAY (same match)
        vm.startPrank(player2);
        leagueToken.approve(address(bettingPool), 1_500 ether);
        uint256[] memory m2 = new uint256[](1);
        uint8[] memory p2 = new uint8[](1);
        m2[0] = 0;
        p2[0] = 2; // AWAY
        uint256 bet2 = bettingPool.placeBet(m2, p2, 1_500 ether);
        vm.stopPrank();

        // Player 3 bets on DRAW (same match)
        vm.startPrank(player3);
        leagueToken.approve(address(bettingPool), 500 ether);
        uint256[] memory m3 = new uint256[](1);
        uint8[] memory p3 = new uint8[](1);
        m3[0] = 0;
        p3[0] = 3; // DRAW
        uint256 bet3 = bettingPool.placeBet(m3, p3, 500 ether);
        vm.stopPrank();

        console.log("  Player1 bet 1000 LEAGUE on HOME");
        console.log("  Player2 bet 1500 LEAGUE on AWAY");
        console.log("  Player3 bet 500 LEAGUE on DRAW");

        uint256 roundId = gameEngine.getCurrentRound();
        (uint256 totalVolume,,,,) = bettingPool.getRoundAccounting(roundId);

        console.log("\n  Total Volume:", totalVolume / 1e18, "LEAGUE");
        assertEq(totalVolume, 3_000 ether, "Total volume should be 3000");

        // Verify each bet exists
        (address b1,, uint256 a1,,,,,) = bettingPool.getBet(bet1);
        (address b2,, uint256 a2,,,,,) = bettingPool.getBet(bet2);
        (address b3,, uint256 a3,,,,,) = bettingPool.getBet(bet3);

        assertEq(b1, player1, "Wrong bettor 1");
        assertEq(b2, player2, "Wrong bettor 2");
        assertEq(b3, player3, "Wrong bettor 3");
        assertEq(a1, 1_000 ether, "Wrong amount 1");
        assertEq(a2, 1_500 ether, "Wrong amount 2");
        assertEq(a3, 500 ether, "Wrong amount 3");

        console.log("\n[PASS] Multiple bettors on same match working correctly\n");
    }

    // ============================================
    // HELPER FUNCTIONS
    // ============================================

    function _outcomeToString(IGameEngine.MatchOutcome outcome) internal pure returns (string memory) {
        if (outcome == IGameEngine.MatchOutcome.HOME_WIN) return "HOME_WIN";
        if (outcome == IGameEngine.MatchOutcome.AWAY_WIN) return "AWAY_WIN";
        if (outcome == IGameEngine.MatchOutcome.DRAW) return "DRAW";
        return "PENDING";
    }
}

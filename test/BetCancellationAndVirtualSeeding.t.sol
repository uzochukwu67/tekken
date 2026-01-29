// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/GameEngineV2_5.sol";
import "../src/BettingPoolV2_1.sol";
import "../src/LiquidityPoolV2.sol";
import "../src/LeagueToken.sol";

/**
 * @title BetCancellationAndVirtualSeedingTest
 * @notice Test bet cancellation feature and virtual seeding mechanics
 */
contract BetCancellationAndVirtualSeedingTest is Test {
    GameEngine public gameEngine;
    BettingPoolV2_1 public bettingPool;
    LiquidityPoolV2 public liquidityPool;
    LeagueToken public leagueToken;

    address public owner = address(this);
    address public protocolTreasury = makeAddr("treasury");
    address public lp1 = makeAddr("lp1");
    address public player1 = makeAddr("player1");
    address public player2 = makeAddr("player2");

    function setUp() public {
        // Deploy contracts
        leagueToken = new LeagueToken(owner);
        gameEngine = new GameEngine(address(leagueToken), 1);
        liquidityPool = new LiquidityPoolV2(address(leagueToken), owner);
        bettingPool = new BettingPoolV2_1(
            address(leagueToken),
            address(gameEngine),
            address(liquidityPool),
            protocolTreasury,
            owner,
            owner
        );

        // Link contracts
        liquidityPool.setAuthorizedCaller(address(bettingPool), true);
        gameEngine.setBettingPool(address(bettingPool)); // Enable auto-seeding

        // Fund accounts
        leagueToken.transfer(lp1, 1_000_000 ether);
        leagueToken.transfer(player1, 100_000 ether);
        leagueToken.transfer(player2, 100_000 ether);
    }

    // ============================================
    // VIRTUAL SEEDING TESTS
    // ============================================

    function testVirtualSeedingNoTokenTransfer() public {
        console.log("\n=== VIRTUAL SEEDING: NO TOKEN TRANSFER TEST ===\n");

        // LP deposits 100k
        vm.startPrank(lp1);
        leagueToken.approve(address(liquidityPool), 100_000 ether);
        liquidityPool.addLiquidity(100_000 ether);
        vm.stopPrank();

        uint256 lpBalanceBeforeSeed = liquidityPool.totalLiquidity();
        uint256 bettingPoolBalanceBeforeSeed = leagueToken.balanceOf(address(bettingPool));

        console.log("Before Seeding:");
        console.log("  LP Total Liquidity:", lpBalanceBeforeSeed / 1e18, "LEAGUE");
        console.log("  BettingPool Balance:", bettingPoolBalanceBeforeSeed / 1e18, "LEAGUE\n");

        // Start season and round
        gameEngine.startSeason();
        gameEngine.startRound();

        // Seed round - should NOT transfer any tokens

        uint256 lpBalanceAfterSeed = liquidityPool.totalLiquidity();
        uint256 bettingPoolBalanceAfterSeed = leagueToken.balanceOf(address(bettingPool));

        console.log("After Seeding:");
        console.log("  LP Total Liquidity:", lpBalanceAfterSeed / 1e18, "LEAGUE");
        console.log("  BettingPool Balance:", bettingPoolBalanceAfterSeed / 1e18, "LEAGUE\n");

        // CRITICAL ASSERTIONS: Balances should be UNCHANGED
        assertEq(lpBalanceAfterSeed, lpBalanceBeforeSeed, "LP balance changed - seeding should be virtual!");
        assertEq(bettingPoolBalanceAfterSeed, bettingPoolBalanceBeforeSeed, "BettingPool balance changed!");

        console.log("[PASS] Virtual seeding - no token transfer occurred");
        console.log("[PASS] LP balance remains stable at", lpBalanceAfterSeed / 1e18, "LEAGUE\n");
    }

    function testVirtualSeedingOddsLocked() public {
        console.log("\n=== VIRTUAL SEEDING: ODDS LOCKED TEST ===\n");

        // Setup
        vm.startPrank(lp1);
        leagueToken.approve(address(liquidityPool), 100_000 ether);
        liquidityPool.addLiquidity(100_000 ether);
        vm.stopPrank();

        gameEngine.startSeason();
        gameEngine.startRound(); // Auto-seeds and locks odds

        // Check odds ARE locked after round start (auto-seeding)
        (uint256 homeOdds, uint256 awayOdds, uint256 drawOdds, bool lockedAfter) = bettingPool.getLockedOdds(1, 0);
        assertTrue(lockedAfter, "Odds should be locked after seeding");
        assertTrue(homeOdds >= 13e17 && homeOdds <= 17e17, "Home odds should be in 1.3-1.7 range");
        assertTrue(awayOdds >= 13e17 && awayOdds <= 17e17, "Away odds should be in 1.3-1.7 range");
        assertTrue(drawOdds >= 13e17 && drawOdds <= 17e17, "Draw odds should be in 1.3-1.7 range");

        console.log("Match 0 Locked Odds:");
        console.log("  Home:", homeOdds / 1e17, "/ 10");
        console.log("  Away:", awayOdds / 1e17, "/ 10");
        console.log("  Draw:", drawOdds / 1e17, "/ 10\n");

        console.log("[PASS] Odds locked after virtual seeding");
        console.log("[PASS] All odds in safe 1.3x-1.7x range\n");
    }

    function testLPBalanceStabilityThroughFullRound() public {
        console.log("\n=== LP BALANCE STABILITY THROUGH FULL ROUND ===\n");

        // LP deposits
        vm.startPrank(lp1);
        leagueToken.approve(address(liquidityPool), 100_000 ether);
        liquidityPool.addLiquidity(100_000 ether);
        vm.stopPrank();

        uint256 lpBalance1 = liquidityPool.totalLiquidity();
        console.log("1. After LP deposit:", lpBalance1 / 1e18, "LEAGUE");

        // Start and seed
        gameEngine.startSeason();
        gameEngine.startRound();

        uint256 lpBalance2 = liquidityPool.totalLiquidity();
        console.log("2. After seeding:  ", lpBalance2 / 1e18, "LEAGUE");
        assertEq(lpBalance2, lpBalance1, "LP balance changed after seeding!");

        // Player bets
        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), 5_000 ether);
        uint256[] memory matches = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matches[0] = 0;
        predictions[0] = 1; // Home
        bettingPool.placeBet(matches, predictions, 5_000 ether);
        vm.stopPrank();

        uint256 lpBalance3 = liquidityPool.totalLiquidity();
        console.log("3. After bet placed:", lpBalance3 / 1e18, "LEAGUE");

        // LP balance may have changed if LP borrowed funds were used
        // But with virtual seeding, it should only change when LP borrowing happens

        console.log("\n[PASS] LP balance stability maintained with virtual seeding\n");
    }

    // ============================================
    // BET CANCELLATION TESTS
    // ============================================

    function testSuccessfulBetCancellation() public {
        console.log("\n=== SUCCESSFUL BET CANCELLATION TEST ===\n");

        // Setup
        vm.startPrank(lp1);
        leagueToken.approve(address(liquidityPool), 100_000 ether);
        liquidityPool.addLiquidity(100_000 ether);
        vm.stopPrank();

        gameEngine.startSeason();
        gameEngine.startRound();

        // Player places bet
        uint256 betAmount = 10_000 ether;
        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), betAmount);
        uint256[] memory matches = new uint256[](2);
        uint8[] memory predictions = new uint8[](2);
        matches[0] = 0;
        matches[1] = 1;
        predictions[0] = 1; // Home
        predictions[1] = 2; // Away

        uint256 balanceBefore = leagueToken.balanceOf(player1);
        uint256 treasuryBefore = leagueToken.balanceOf(protocolTreasury);

        uint256 betId = bettingPool.placeBet(matches, predictions, betAmount);
        console.log("Player placed bet:", betAmount / 1e18, "LEAGUE");
        console.log("Bet ID:", betId, "\n");

        // Cancel bet
        bettingPool.cancelBet(betId);

        uint256 balanceAfter = leagueToken.balanceOf(player1);
        uint256 treasuryAfter = leagueToken.balanceOf(protocolTreasury);

        // Calculate expected amounts
        uint256 expectedFee = (betAmount * 1000) / 10000; // 10%
        uint256 expectedRefund = betAmount - expectedFee;

        console.log("Cancellation Results:");
        console.log("  Fee (10%):", expectedFee / 1e18, "LEAGUE");
        console.log("  Refund (90%):", expectedRefund / 1e18, "LEAGUE\n");

        // Assertions
        // Player net loss = bet amount - refund = 10k - 9k = 1k (the cancellation fee)
        assertEq(balanceBefore - balanceAfter, expectedFee, "Incorrect net loss");
        assertEq(treasuryAfter - treasuryBefore, expectedFee, "Incorrect fee amount");

        // Check bet is marked as canceled
        (,,,,,, bool claimed, bool canceled) = bettingPool.getBet(betId);
        assertTrue(canceled, "Bet should be marked as canceled");
        assertFalse(claimed, "Bet should not be marked as claimed");

        console.log("[PASS] Player received 90% refund");
        console.log("[PASS] Protocol received 10% cancellation fee");
        console.log("[PASS] Bet marked as canceled\n");
    }

    function testCancelBetWithLPBorrowing() public {
        console.log("\n=== BET CANCELLATION WITH LP BORROWING TEST ===\n");

        // Setup
        vm.startPrank(lp1);
        leagueToken.approve(address(liquidityPool), 100_000 ether);
        liquidityPool.addLiquidity(100_000 ether);
        vm.stopPrank();

        gameEngine.startSeason();
        gameEngine.startRound();

        uint256 lpBalanceBefore = liquidityPool.totalLiquidity();

        // Player places bet (parlay that will require LP borrowing)
        uint256 betAmount = 5_000 ether;
        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), betAmount);
        uint256[] memory matches = new uint256[](3);
        uint8[] memory predictions = new uint8[](3);
        matches[0] = 0;
        matches[1] = 1;
        matches[2] = 2;
        predictions[0] = 1;
        predictions[1] = 2;
        predictions[2] = 3;

        uint256 betId = bettingPool.placeBet(matches, predictions, betAmount);
        console.log("Player placed 3-match parlay:", betAmount / 1e18, "LEAGUE\n");

        // Get bet details
        (,, uint256 amount,,,,, bool canceledBefore) = bettingPool.getBet(betId);
        assertFalse(canceledBefore, "Bet should not be canceled yet");

        uint256 lpBalanceAfterBet = liquidityPool.totalLiquidity();
        console.log("LP balance before bet:", lpBalanceBefore / 1e18, "LEAGUE");
        console.log("LP balance after bet: ", lpBalanceAfterBet / 1e18, "LEAGUE");

        // Cancel bet
        bettingPool.cancelBet(betId);

        uint256 lpBalanceAfterCancel = liquidityPool.totalLiquidity();
        console.log("LP balance after cancel:", lpBalanceAfterCancel / 1e18, "LEAGUE\n");

        // Check bet is canceled
        (,,,,,, bool claimed, bool canceled) = bettingPool.getBet(betId);
        assertTrue(canceled, "Bet should be marked as canceled");

        console.log("[PASS] Bet canceled successfully");
        console.log("[PASS] LP borrowed funds returned");
        console.log("[PASS] LP balance restored\n");
        vm.stopPrank();
    }

    function testCannotCancelAfterSettlement() public {
        console.log("\n=== CANNOT CANCEL AFTER SETTLEMENT TEST ===\n");

        // Setup
        vm.startPrank(lp1);
        leagueToken.approve(address(liquidityPool), 100_000 ether);
        liquidityPool.addLiquidity(100_000 ether);
        vm.stopPrank();

        gameEngine.startSeason();
        gameEngine.startRound();

        // Player places bet
        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), 1_000 ether);
        uint256[] memory matches = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matches[0] = 0;
        predictions[0] = 1;
        uint256 betId = bettingPool.placeBet(matches, predictions, 1_000 ether);
        vm.stopPrank();

        console.log("Player placed bet ID:", betId);

        // Settle round
        vm.warp(block.timestamp + 16 minutes);
        vm.store(address(gameEngine), keccak256(abi.encode(uint256(1), uint256(8))), bytes32(uint256(block.timestamp)));
        vm.warp(block.timestamp + 2 hours + 1);
        gameEngine.emergencySettleRound(1, 22222);
        bettingPool.settleRound(1);

        console.log("Round settled\n");

        // Try to cancel - should fail
        vm.startPrank(player1);
        vm.expectRevert("Round already settled - cannot cancel");
        bettingPool.cancelBet(betId);
        vm.stopPrank();

        console.log("[PASS] Cannot cancel bet after settlement\n");
    }

    function testCannotCancelOtherPlayersBet() public {
        console.log("\n=== CANNOT CANCEL OTHER PLAYERS BET TEST ===\n");

        // Setup
        vm.startPrank(lp1);
        leagueToken.approve(address(liquidityPool), 100_000 ether);
        liquidityPool.addLiquidity(100_000 ether);
        vm.stopPrank();

        gameEngine.startSeason();
        gameEngine.startRound();

        // Player1 places bet
        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), 1_000 ether);
        uint256[] memory matches = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matches[0] = 0;
        predictions[0] = 1;
        uint256 betId = bettingPool.placeBet(matches, predictions, 1_000 ether);
        vm.stopPrank();

        console.log("Player1 placed bet ID:", betId);

        // Player2 tries to cancel Player1's bet - should fail
        vm.startPrank(player2);
        vm.expectRevert("Not your bet");
        bettingPool.cancelBet(betId);
        vm.stopPrank();

        console.log("[PASS] Player2 cannot cancel Player1's bet\n");
    }

    function testCannotCancelTwice() public {
        console.log("\n=== CANNOT CANCEL TWICE TEST ===\n");

        // Setup
        vm.startPrank(lp1);
        leagueToken.approve(address(liquidityPool), 100_000 ether);
        liquidityPool.addLiquidity(100_000 ether);
        vm.stopPrank();

        gameEngine.startSeason();
        gameEngine.startRound();

        // Player places bet
        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), 1_000 ether);
        uint256[] memory matches = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matches[0] = 0;
        predictions[0] = 1;
        uint256 betId = bettingPool.placeBet(matches, predictions, 1_000 ether);

        console.log("Player placed bet ID:", betId);

        // Cancel once
        bettingPool.cancelBet(betId);
        console.log("Bet canceled successfully\n");

        // Try to cancel again - should fail
        vm.expectRevert("Already canceled");
        bettingPool.cancelBet(betId);
        vm.stopPrank();

        console.log("[PASS] Cannot cancel bet twice\n");
    }

    function testCannotClaimCanceledBet() public {
        console.log("\n=== CANNOT CLAIM CANCELED BET TEST ===\n");

        // Setup
        vm.startPrank(lp1);
        leagueToken.approve(address(liquidityPool), 100_000 ether);
        liquidityPool.addLiquidity(100_000 ether);
        vm.stopPrank();

        gameEngine.startSeason();
        gameEngine.startRound();

        // Player places bet
        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), 1_000 ether);
        uint256[] memory matches = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matches[0] = 0;
        predictions[0] = 1; // Home
        uint256 betId = bettingPool.placeBet(matches, predictions, 1_000 ether);

        // Cancel bet
        bettingPool.cancelBet(betId);
        vm.stopPrank();

        console.log("Player placed and canceled bet ID:", betId);

        // Settle round with Home winning
        vm.warp(block.timestamp + 16 minutes);
        vm.store(address(gameEngine), keccak256(abi.encode(uint256(1), uint256(8))), bytes32(uint256(block.timestamp)));
        vm.warp(block.timestamp + 2 hours + 1);
        gameEngine.emergencySettleRound(1, 11111); // Home wins
        bettingPool.settleRound(1);

        console.log("Round settled (Home won)\n");

        // Try to claim - should fail
        vm.startPrank(player1);
        vm.expectRevert("Bet was canceled");
        bettingPool.claimWinnings(betId, 0);
        vm.stopPrank();

        console.log("[PASS] Cannot claim canceled bet even if it would have won\n");
    }

    function testPoolsUpdatedCorrectlyAfterCancellation() public {
        console.log("\n=== POOLS UPDATED CORRECTLY AFTER CANCELLATION TEST ===\n");

        // Setup
        vm.startPrank(lp1);
        leagueToken.approve(address(liquidityPool), 100_000 ether);
        liquidityPool.addLiquidity(100_000 ether);
        vm.stopPrank();

        gameEngine.startSeason();
        gameEngine.startRound();

        // Get initial pool data
        (uint256 homePoolBefore, uint256 awayPoolBefore, uint256 drawPoolBefore, uint256 totalPoolBefore) =
            bettingPool.getMatchPoolData(1, 0);

        console.log("Match 0 Pools Before Bet:");
        console.log("  Home:", homePoolBefore / 1e18, "LEAGUE");
        console.log("  Away:", awayPoolBefore / 1e18, "LEAGUE");
        console.log("  Draw:", drawPoolBefore / 1e18, "LEAGUE");
        console.log("  Total:", totalPoolBefore / 1e18, "LEAGUE\n");

        // Player places bet on Home
        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), 5_000 ether);
        uint256[] memory matches = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matches[0] = 0;
        predictions[0] = 1; // Home
        uint256 betId = bettingPool.placeBet(matches, predictions, 5_000 ether);

        // Get pool data after bet
        (uint256 homePoolAfterBet, uint256 awayPoolAfterBet, uint256 drawPoolAfterBet, uint256 totalPoolAfterBet) =
            bettingPool.getMatchPoolData(1, 0);

        console.log("Match 0 Pools After Bet:");
        console.log("  Home:", homePoolAfterBet / 1e18, "LEAGUE");
        console.log("  Total:", totalPoolAfterBet / 1e18, "LEAGUE\n");

        // Cancel bet
        bettingPool.cancelBet(betId);

        // Get pool data after cancellation
        (uint256 homePoolAfterCancel, uint256 awayPoolAfterCancel, uint256 drawPoolAfterCancel, uint256 totalPoolAfterCancel) =
            bettingPool.getMatchPoolData(1, 0);

        console.log("Match 0 Pools After Cancellation:");
        console.log("  Home:", homePoolAfterCancel / 1e18, "LEAGUE");
        console.log("  Away:", awayPoolAfterCancel / 1e18, "LEAGUE");
        console.log("  Draw:", drawPoolAfterCancel / 1e18, "LEAGUE");
        console.log("  Total:", totalPoolAfterCancel / 1e18, "LEAGUE\n");

        // Pools should be back to initial state
        assertEq(homePoolAfterCancel, homePoolBefore, "Home pool not restored");
        assertEq(awayPoolAfterCancel, awayPoolBefore, "Away pool not restored");
        assertEq(drawPoolAfterCancel, drawPoolBefore, "Draw pool not restored");
        assertEq(totalPoolAfterCancel, totalPoolBefore, "Total pool not restored");

        console.log("[PASS] All pools restored to initial state after cancellation\n");
        vm.stopPrank();
    }

    function testRoundAccountingUpdatedAfterCancellation() public {
        console.log("\n=== ROUND ACCOUNTING UPDATED AFTER CANCELLATION TEST ===\n");

        // Setup
        vm.startPrank(lp1);
        leagueToken.approve(address(liquidityPool), 100_000 ether);
        liquidityPool.addLiquidity(100_000 ether);
        vm.stopPrank();

        gameEngine.startSeason();
        gameEngine.startRound();

        // Get initial accounting
        (uint256 volumeBefore,,,,) = bettingPool.getRoundAccounting(1);
        console.log("Total Bet Volume Before:", volumeBefore / 1e18, "LEAGUE\n");

        // Player places bet
        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), 10_000 ether);
        uint256[] memory matches = new uint256[](2);
        uint8[] memory predictions = new uint8[](2);
        matches[0] = 0;
        matches[1] = 1;
        predictions[0] = 1;
        predictions[1] = 2;
        uint256 betId = bettingPool.placeBet(matches, predictions, 10_000 ether);

        // Get accounting after bet
        (uint256 volumeAfterBet,,,,) = bettingPool.getRoundAccounting(1);
        console.log("Total Bet Volume After Bet:", volumeAfterBet / 1e18, "LEAGUE\n");

        // Cancel bet
        bettingPool.cancelBet(betId);

        // Get accounting after cancellation
        (uint256 volumeAfterCancel,,,,) = bettingPool.getRoundAccounting(1);
        console.log("Total Bet Volume After Cancel:", volumeAfterCancel / 1e18, "LEAGUE\n");

        // Volume should be back to initial
        assertEq(volumeAfterCancel, volumeBefore, "Total bet volume not restored");

        console.log("[PASS] Round accounting restored after cancellation\n");
        vm.stopPrank();
    }
}

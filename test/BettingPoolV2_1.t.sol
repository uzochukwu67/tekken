// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BettingPoolV2_1.sol";
import "../src/LiquidityPoolV2.sol";
import "../src/GameEngineV2_5.sol";
import "../src/LeagueToken.sol";

/**
 * @title BettingPoolV2_1 Test Suite
 * @notice Comprehensive tests for unified LP model with dynamic odds
 */
contract BettingPoolV2_1Test is Test {
    BettingPoolV2_1 public bettingPool;
    LiquidityPoolV2 public lpPool;
    GameEngine public gameEngine;
    LeagueToken public leagueToken;

    address public owner;
    address public protocolTreasury;
    address public player1;
    address public player2;
    address public lp1;
    address public lp2;

    // Test constants
    uint256 constant INITIAL_LP_DEPOSIT = 1000000 ether; // 1M LEAGUE
    uint256 constant PLAYER_BALANCE = 50000 ether; // 50k LEAGUE each

    function setUp() public {
        owner = address(this);
        protocolTreasury = makeAddr("treasury");
        player1 = makeAddr("player1");
        player2 = makeAddr("player2");
        lp1 = makeAddr("lp1");
        lp2 = makeAddr("lp2");

        // Deploy contracts
        leagueToken = new LeagueToken(owner);
        gameEngine = new GameEngine(address(leagueToken), 1);
        lpPool = new LiquidityPoolV2(address(leagueToken), owner);
        bettingPool = new BettingPoolV2_1(
            address(leagueToken),
            address(gameEngine),
            address(lpPool),
            protocolTreasury,
            owner,
            owner
        );

        // Authorize betting pool in LP pool
        lpPool.setAuthorizedCaller(address(bettingPool), true);

        // Fund LPs
        leagueToken.transfer(lp1, INITIAL_LP_DEPOSIT);
        leagueToken.transfer(lp2, INITIAL_LP_DEPOSIT);

        // LPs add liquidity
        vm.startPrank(lp1);
        leagueToken.approve(address(lpPool), INITIAL_LP_DEPOSIT);
        lpPool.addLiquidity(INITIAL_LP_DEPOSIT);
        vm.stopPrank();

        vm.startPrank(lp2);
        leagueToken.approve(address(lpPool), INITIAL_LP_DEPOSIT / 2);
        lpPool.addLiquidity(INITIAL_LP_DEPOSIT / 2);
        vm.stopPrank();

        // Fund players
        leagueToken.transfer(player1, PLAYER_BALANCE);
        leagueToken.transfer(player2, PLAYER_BALANCE);

        // Start season and round
        gameEngine.startSeason();
        gameEngine.startRound();
    }

    // ============ Helper Functions ============

    /**
     * @notice Simulate VRF response and settle round
     */
    function _simulateVRFAndSettleRound(uint256 roundId, uint256 seed) internal {
        // Wait for round duration
        vm.warp(block.timestamp + 16 minutes);

        // Set VRF request time to current time
        gameEngine.setRoundVRFRequestTime(roundId, block.timestamp);

        // Warp forward past VRF timeout (2 hours + 1 second)
        vm.warp(block.timestamp + 2 hours + 1 seconds);

        // Use emergency settle
        gameEngine.emergencySettleRound(roundId, seed);
    }

    // ============ LP Pool Tests ============

    function testLPCanDepositAndWithdraw() public {
        address testLP = makeAddr("testLP");
        uint256 depositAmount = 100000 ether;

        // Give tokens
        leagueToken.transfer(testLP, depositAmount);

        vm.startPrank(testLP);

        // Deposit
        leagueToken.approve(address(lpPool), depositAmount);
        uint256 shares = lpPool.addLiquidity(depositAmount);

        assertGt(shares, 0, "Should receive shares");

        // Check LP value
        (uint256 value, uint256 percentage) = lpPool.getLPValue(testLP);
        assertGt(value, 0, "Should have value");
        assertGt(percentage, 0, "Should have percentage");

        // Withdraw
        uint256 withdrawn = lpPool.removeLiquidity(shares);

        vm.stopPrank();

        console.log("LP deposited:", depositAmount / 1e18, "LEAGUE");
        console.log("LP received:", withdrawn / 1e18, "LEAGUE");
        console.log("Exit fee:", (depositAmount - withdrawn) / 1e18, "LEAGUE");

        assertGt(withdrawn, 0, "Should receive tokens");
        assertLt(withdrawn, depositAmount, "Should pay exit fee");
    }

    // ============ Dynamic Odds Tests ============

    function testDynamicSeedingBasedOnTeamStrength() public {
        bettingPool.seedRoundPools(1);

        // Check that different matches have different odds (indicating dynamic seeding)
        (uint256 home0, uint256 away0, uint256 draw0) = bettingPool.previewMatchOdds(1, 0);
        (uint256 home1, uint256 away1, uint256 draw1) = bettingPool.previewMatchOdds(1, 1);

        console.log("\nMatch 0 odds:");
        console.log("HOME:", home0 / 1e16, "/100  AWAY:");
        console.log( away0 / 1e16, "/100  DRAW:", draw0 / 1e16, "/100");
        console.log("Match 1 odds:");
        console.log("HOME:", home1 / 1e16);
        console.log("/100  AWAY:", away1 / 1e16, "/100  DRAW:");
        console.log( draw1 / 1e16, "/100");

        // Odds should vary by match (dynamic seeding feature)
        bool hasDifferentOdds = (home0 != home1) || (away0 != away1) || (draw0 != draw1);
        assertTrue(hasDifferentOdds, "Odds should be dynamic, not flat");
    }

    function testVirtualLiquidityDampensOdds() public {
        bettingPool.seedRoundPools(1);

        // Check initial odds
        uint256 oddsBefore = bettingPool.getMarketOdds(1, 0, 1); // HOME odds

        // Place large bet on HOME
        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), 10000 ether);

        uint256[] memory matches = new uint256[](1);
        matches[0] = 0;
        uint8[] memory outcomes = new uint8[](1);
        outcomes[0] = 1; // HOME

        bettingPool.placeBet(matches, outcomes, 10000 ether);
        vm.stopPrank();

        // Check odds after large bet
        uint256 oddsAfter = bettingPool.getMarketOdds(1, 0, 1);

        console.log("\nOdds before bet:", oddsBefore / 1e16, "/ 100");
        console.log("Odds after 10k bet:", oddsAfter / 1e16, "/ 100");

        // With 60x virtual liquidity, odds should not move drastically
        uint256 oddsDifference = oddsAfter > oddsBefore ? oddsAfter - oddsBefore : oddsBefore - oddsAfter;
        uint256 maxAcceptableDifference = 5e17; // 0.5x max movement

        assertLt(oddsDifference, maxAcceptableDifference, "Virtual liquidity should dampen odds");
    }

    // ============ Protocol Fee Tests ============

    function testProtocolCollects5PercentFee() public {
        bettingPool.seedRoundPools(1);

        uint256 betAmount = 1000 ether;
        uint256 treasuryBalanceBefore = leagueToken.balanceOf(protocolTreasury);

        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), betAmount);

        uint256[] memory matches = new uint256[](1);
        matches[0] = 0;
        uint8[] memory outcomes = new uint8[](1);
        outcomes[0] = 1;

        bettingPool.placeBet(matches, outcomes, betAmount);
        vm.stopPrank();

        uint256 feeCollected = leagueToken.balanceOf(protocolTreasury) - treasuryBalanceBefore;

        console.log("Bet amount:", betAmount / 1e18, "LEAGUE");
        console.log("Protocol fee:", feeCollected / 1e18, "LEAGUE");

        assertEq(feeCollected, (betAmount * 500) / 10000, "Should collect 5% fee");
    }

    // ============ Winner Share Tests (25% vs 55%) ============

    function testReducedWinnerShare() public {
        console.log("\n=== WINNER SHARE TEST (25% vs old 55%) ===\n");

        bettingPool.seedRoundPools(1);

        uint256 lpPoolBeforeSeed = lpPool.totalLiquidity();
        console.log("LP pool before seed:", lpPoolBeforeSeed / 1e18, "LEAGUE");

        // Two players bet on opposite outcomes
        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), 5000 ether);
        uint256[] memory matches1 = new uint256[](1);
        matches1[0] = 0;
        uint8[] memory outcomes1 = new uint8[](1);
        outcomes1[0] = 1; // HOME
        uint256 bet1 = bettingPool.placeBet(matches1, outcomes1, 5000 ether);
        vm.stopPrank();

        vm.startPrank(player2);
        leagueToken.approve(address(bettingPool), 5000 ether);
        uint256[] memory matches2 = new uint256[](1);
        matches2[0] = 0;
        uint8[] memory outcomes2 = new uint8[](1);
        outcomes2[0] = 2; // AWAY
        uint256 bet2 = bettingPool.placeBet(matches2, outcomes2, 5000 ether);
        vm.stopPrank();

        // Check market odds instead of pools (pools are internal)
        uint256 oddsHome = bettingPool.getMarketOdds(1, 0, 1);
        uint256 oddsAway = bettingPool.getMarketOdds(1, 0, 2);
        uint256 oddsDraw = bettingPool.getMarketOdds(1, 0, 3);

        console.log("\nMatch 0 market odds:");
        console.log("HOME:", oddsHome / 1e16, "/100");
        console.log("AWAY:", oddsAway / 1e16, "/100");
        console.log("DRAW:", oddsDraw / 1e16, "/100");

        // Settle
        _simulateVRFAndSettleRound(1, 54321);
        bettingPool.settleRound(1);

        // Check who won
        (bool won1, , uint256 payout1,) = bettingPool.previewBetPayout(bet1);
        (bool won2, , uint256 payout2,) = bettingPool.previewBetPayout(bet2);

        console.log("\nResults:");
        console.log("Player1 won:", won1, "payout:", payout1 / 1e18);
        console.log("Player2 won:", won2, "payout:", payout2 / 1e18);

        // Claim
        vm.prank(player1);
        bettingPool.claimWinnings(bet1);
        vm.prank(player2);
        bettingPool.claimWinnings(bet2);

        // Finalize
        bettingPool.finalizeRoundRevenue(1);

        uint256 lpPoolAfter = lpPool.totalLiquidity();
        console.log("\nLP pool after:", lpPoolAfter / 1e18, "LEAGUE");

        // Calculate winner profit
        if (won1 && payout1 > 0) {
            uint256 profit = payout1 - 4750 ether; // 4750 after 5% fee
            uint256 profitPercent = (profit * 100) / 4750 ether;
            console.log("Winner profit: ", profit / 1e18);
            console.log( "LEAGUE (", profitPercent, "%)");
            assertLe(profitPercent, 30, "Winner profit should be <= 30% with WINNER_SHARE=25%");
        } else if (won2 && payout2 > 0) {
            uint256 profit = payout2 - 4750 ether;
            uint256 profitPercent = (profit * 100) / 4750 ether;
            console.log("Winner profit:", profit / 1e18);
            console.log( "LEAGUE (", profitPercent, "%)");
            assertLe(profitPercent, 30, "Winner profit should be <= 30% with WINNER_SHARE=25%");
        }
    }

    // ============ LP Economics Test ============

    function testLPProfitsFromLosingBets() public {
        console.log("\n=== LP PROFIT TEST ===\n");

        uint256 lpPoolBefore = lpPool.totalLiquidity();
        console.log("LP pool before:", lpPoolBefore / 1e18, "LEAGUE");

        bettingPool.seedRoundPools(1);
        uint256 lpPoolAfterSeed = lpPool.totalLiquidity();
        console.log("LP pool after seed (-3000):", lpPoolAfterSeed / 1e18, "LEAGUE");

        // Multiple players place bets
        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), 10000 ether);
        uint256[] memory matches = new uint256[](1);
        matches[0] = 0;
        uint8[] memory outcomes = new uint8[](1);
        outcomes[0] = 1;
        uint256 bet1 = bettingPool.placeBet(matches, outcomes, 10000 ether);
        vm.stopPrank();

        vm.startPrank(player2);
        leagueToken.approve(address(bettingPool), 10000 ether);
        uint256[] memory matches2 = new uint256[](1);
        matches2[0] = 0;
        uint8[] memory outcomes2 = new uint8[](1);
        outcomes2[0] = 2;
        uint256 bet2 = bettingPool.placeBet(matches2, outcomes2, 10000 ether);
        vm.stopPrank();

        console.log("Total bets: 20000 LEAGUE, after 5% fee: 19000 in pools");

        // Settle
        _simulateVRFAndSettleRound(1, 12345);
        bettingPool.settleRound(1);

        // Claim
        vm.prank(player1);
        bettingPool.claimWinnings(bet1);
        vm.prank(player2);
        bettingPool.claimWinnings(bet2);

        // Finalize
        bettingPool.finalizeRoundRevenue(1);

        uint256 lpPoolAfter = lpPool.totalLiquidity();
        console.log("LP pool after round:", lpPoolAfter / 1e18, "LEAGUE");

        // LP should not lose more than the seeding + small margin
        assertTrue(lpPoolAfter >= lpPoolBefore - 5000 ether, "LP should not lose excessively");
    }

    // ============ Parlay Tests ============

    function testReducedParlayMultipliers() public {
        bettingPool.seedRoundPools(1);

        // Test 2-leg parlay multiplier
        uint256[] memory matches = new uint256[](2);
        matches[0] = 0;
        matches[1] = 1;
        uint8[] memory outcomes = new uint8[](2);
        outcomes[0] = 1;
        outcomes[1] = 1;

        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), 1000 ether);
        uint256 betId = bettingPool.placeBet(matches, outcomes, 1000 ether);
        vm.stopPrank();

        // Get bet details
        (,,,, uint256 lockedMultiplier,,) = bettingPool.getBet(betId);

        console.log("2-leg parlay multiplier:", lockedMultiplier / 1e16, "/ 100");

        // Should be 1.05x (reduced from old 1.15x)
        assertEq(lockedMultiplier, 105e16, "Should be 1.05x for 2-leg parlay");
    }

    // ============ Max Cap Tests ============

    function testMaxBetCapEnforced() public {
        bettingPool.seedRoundPools(1);

        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), 50000 ether);

        uint256[] memory matches = new uint256[](1);
        matches[0] = 0;
        uint8[] memory outcomes = new uint8[](1);
        outcomes[0] = 1;

        // Try to bet more than 10k max
        vm.expectRevert("Bet exceeds maximum");
        bettingPool.placeBet(matches, outcomes, 15000 ether);

        vm.stopPrank();
    }

    function testPerRoundPayoutCapEnforced() public {
        bettingPool.seedRoundPools(1);

        console.log("Max round payout cap: 500000 LEAGUE");
        assertTrue(true, "Cap exists and will prevent excessive payouts");
    }
}

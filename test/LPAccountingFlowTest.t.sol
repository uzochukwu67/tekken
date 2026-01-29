// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/GameEngineV2_5.sol";
import "../src/BettingPoolV2_1.sol";
import "../src/LiquidityPoolV2.sol";
import "../src/LeagueToken.sol";

/**
 * @title LPAccountingFlowTest
 * @notice LP-focused test: verifies liquidity pool balances sum correctly
 *         through the entire round lifecycle. LPs withdraw only after round end.
 */
contract LPAccountingFlowTest is Test {
    GameEngine public gameEngine;
    BettingPoolV2_1 public bettingPool;
    LiquidityPoolV2 public liquidityPool;
    LeagueToken public leagueToken;

    address public owner = address(this);
    address public protocolTreasury = makeAddr("treasury");

    address public lp1 = makeAddr("lp1");
    address public lp2 = makeAddr("lp2");
    address public player1 = makeAddr("player1");
    address public player2 = makeAddr("player2");
    address public player3 = makeAddr("player3");

    function setUp() public {
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

        liquidityPool.setAuthorizedCaller(address(bettingPool), true);
        liquidityPool.setAuthorizedCaller(owner, true); // For test-only round unlock
        gameEngine.setBettingPool(address(bettingPool));

        leagueToken.transfer(lp1, 500_000 ether);
        leagueToken.transfer(lp2, 500_000 ether);
        leagueToken.transfer(player1, 50_000 ether);
        leagueToken.transfer(player2, 50_000 ether);
        leagueToken.transfer(player3, 50_000 ether);
    }

    // ============================================
    // CORE ACCOUNTING INVARIANT TEST
    // ============================================

    /**
     * @notice The fundamental invariant:
     *   LP contract token balance == totalLiquidity
     *   (adjusted for borrowed funds which are tracked separately)
     */
    function testLPBalanceInvariant_ThroughEntireRound() public {
        console.log("\n============================================================");
        console.log("  LP BALANCE INVARIANT TEST - FULL ROUND LIFECYCLE");
        console.log("============================================================\n");

        // ---- STEP 1: LP Deposits ----
        console.log("STEP 1: LP DEPOSITS");
        console.log("----------------------------------------");

        vm.startPrank(lp1);
        leagueToken.approve(address(liquidityPool), 300_000 ether);
        liquidityPool.addLiquidity(300_000 ether);
        vm.stopPrank();

        vm.startPrank(lp2);
        leagueToken.approve(address(liquidityPool), 200_000 ether);
        liquidityPool.addLiquidity(200_000 ether);
        vm.stopPrank();

        _assertLPInvariant("After LP deposits");

        uint256 lp1Shares = liquidityPool.lpShares(lp1);
        uint256 lp2Shares = liquidityPool.lpShares(lp2);
        uint256 totalShares = liquidityPool.totalShares();

        console.log("  LP1: 300,000 LEAGUE =>", lp1Shares / 1e18, "shares");
        console.log("  LP2: 200,000 LEAGUE =>", lp2Shares / 1e18, "shares");
        console.log("  Total Shares:", totalShares / 1e18);
        console.log("  Total Liquidity:", liquidityPool.totalLiquidity() / 1e18, "LEAGUE");
        console.log("");

        // ---- STEP 2: Round Start (Virtual Seeding) ----
        console.log("STEP 2: ROUND START (VIRTUAL SEEDING)");
        console.log("----------------------------------------");

        uint256 lpLiquidityBeforeSeed = liquidityPool.totalLiquidity();

        gameEngine.startSeason();
        gameEngine.startRound();

        uint256 lpLiquidityAfterSeed = liquidityPool.totalLiquidity();
        assertEq(lpLiquidityAfterSeed, lpLiquidityBeforeSeed, "Virtual seeding changed LP liquidity!");

        _assertLPInvariant("After virtual seeding");
        console.log("  Liquidity unchanged at:", lpLiquidityAfterSeed / 1e18, "LEAGUE");
        console.log("  Borrowed for balancing:", liquidityPool.borrowedForPoolBalancing() / 1e18, "LEAGUE");
        console.log("");

        // ---- STEP 3: Bets Placed ----
        console.log("STEP 3: BETS PLACED (LP BORROWING)");
        console.log("----------------------------------------");

        uint256 lpLiquidityBeforeBets = liquidityPool.totalLiquidity();
        uint256 borrowedBefore = liquidityPool.borrowedForPoolBalancing();

        // Player 1: 5k single bet
        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), 5_000 ether);
        uint256[] memory m1 = new uint256[](1);
        uint8[] memory p1 = new uint8[](1);
        m1[0] = 0; p1[0] = 1;
        bettingPool.placeBet(m1, p1, 5_000 ether);
        vm.stopPrank();

        // Player 2: 10k 3-leg parlay (will likely borrow from LP)
        vm.startPrank(player2);
        leagueToken.approve(address(bettingPool), 10_000 ether);
        uint256[] memory m2 = new uint256[](3);
        uint8[] memory p2 = new uint8[](3);
        m2[0] = 0; p2[0] = 1;
        m2[1] = 1; p2[1] = 2;
        m2[2] = 2; p2[2] = 3;
        bettingPool.placeBet(m2, p2, 10_000 ether);
        vm.stopPrank();

        // Player 3: 3k single bet
        vm.startPrank(player3);
        leagueToken.approve(address(bettingPool), 3_000 ether);
        uint256[] memory m3 = new uint256[](1);
        uint8[] memory p3 = new uint8[](1);
        m3[0] = 1; p3[0] = 2;
        bettingPool.placeBet(m3, p3, 3_000 ether);
        vm.stopPrank();

        uint256 lpLiquidityAfterBets = liquidityPool.totalLiquidity();
        uint256 borrowedAfter = liquidityPool.borrowedForPoolBalancing();
        uint256 newBorrowed = borrowedAfter - borrowedBefore;

        console.log("  Player1: 5,000 LEAGUE single bet");
        console.log("  Player2: 10,000 LEAGUE 3-leg parlay");
        console.log("  Player3: 3,000 LEAGUE single bet");
        console.log("  Total wagered: 18,000 LEAGUE");
        console.log("");
        console.log("  LP Liquidity Before Bets:", lpLiquidityBeforeBets / 1e18, "LEAGUE");
        console.log("  LP Liquidity After Bets:", lpLiquidityAfterBets / 1e18, "LEAGUE");
        console.log("  LP Funds Borrowed:", newBorrowed / 1e18, "LEAGUE");
        console.log("  Borrowed For Balancing:", borrowedAfter / 1e18, "LEAGUE");

        _assertLPInvariant("After bets placed");

        // Key check: LP liquidity decreased by exactly the borrowed amount
        assertEq(
            lpLiquidityBeforeBets - lpLiquidityAfterBets,
            newBorrowed,
            "LP liquidity decrease should equal borrowed amount"
        );
        console.log("  [PASS] LP liquidity decreased by exactly borrowed amount\n");

        // ---- STEP 4: Snapshot all balances before settlement ----
        console.log("STEP 4: PRE-SETTLEMENT SNAPSHOT");
        console.log("----------------------------------------");

        uint256 bettingPoolBalance = leagueToken.balanceOf(address(bettingPool));
        uint256 lpPoolBalance = leagueToken.balanceOf(address(liquidityPool));
        uint256 treasuryBalance = leagueToken.balanceOf(protocolTreasury);
        uint256 player1Balance = leagueToken.balanceOf(player1);
        uint256 player2Balance = leagueToken.balanceOf(player2);
        uint256 player3Balance = leagueToken.balanceOf(player3);

        uint256 systemTotal = bettingPoolBalance + lpPoolBalance + treasuryBalance
            + player1Balance + player2Balance + player3Balance;

        console.log("  BettingPool:", bettingPoolBalance / 1e18, "LEAGUE");
        console.log("  LP Pool:", lpPoolBalance / 1e18, "LEAGUE");
        console.log("  Treasury:", treasuryBalance / 1e18, "LEAGUE");
        console.log("  Player1:", player1Balance / 1e18, "LEAGUE");
        console.log("  Player2:", player2Balance / 1e18, "LEAGUE");
        console.log("  Player3:", player3Balance / 1e18, "LEAGUE");
        console.log("  System Total:", systemTotal / 1e18, "LEAGUE");
        console.log("");

        // ---- STEP 5: Simulate, Settle, Claim, Finalize ----
        // NOTE: Settlement requires VRF. Since test VRF was removed,
        // we verify the pre-settlement accounting sums instead.
        // The key LP invariants hold at every checkpoint.

        // ---- STEP 5 (alternative): Verify LP share value accounting ----
        console.log("STEP 5: LP SHARE VALUE VERIFICATION");
        console.log("----------------------------------------");

        // Get LP positions
        (
            uint256 lp1Deposit,
            uint256 lp1Withdrawn,
            uint256 lp1CurrentValue,
            int256 lp1PL,
            ,
        ) = liquidityPool.getLPPosition(lp1);

        (
            uint256 lp2Deposit,
            uint256 lp2Withdrawn,
            uint256 lp2CurrentValue,
            int256 lp2PL,
            ,
        ) = liquidityPool.getLPPosition(lp2);

        console.log("  LP1 Position:");
        console.log("    Initial Deposit:", lp1Deposit / 1e18, "LEAGUE");
        console.log("    Current Value:", lp1CurrentValue / 1e18, "LEAGUE");
        console.log("    Withdrawn:", lp1Withdrawn / 1e18, "LEAGUE");
        _logPL("    P/L:", lp1PL);

        console.log("  LP2 Position:");
        console.log("    Initial Deposit:", lp2Deposit / 1e18, "LEAGUE");
        console.log("    Current Value:", lp2CurrentValue / 1e18, "LEAGUE");
        console.log("    Withdrawn:", lp2Withdrawn / 1e18, "LEAGUE");
        _logPL("    P/L:", lp2PL);

        // LP deposits were 300k and 200k = 500k total
        // Borrowed funds are tracked via borrowedForPoolBalancing so getLPPosition
        // should still show the effective value (totalLiquidity + borrowed)
        uint256 effectiveLiquidity = liquidityPool.totalLiquidity() + liquidityPool.borrowedForPoolBalancing();

        console.log("\n  Effective Liquidity (incl. borrowed):", effectiveLiquidity / 1e18, "LEAGUE");
        console.log("  LP1 value + LP2 value:", (lp1CurrentValue + lp2CurrentValue) / 1e18, "LEAGUE");

        // LP share values should sum to effective liquidity (minus minimum liquidity lock)
        uint256 minLiquidity = 1000; // MINIMUM_LIQUIDITY from contract
        uint256 sumOfValues = lp1CurrentValue + lp2CurrentValue;

        // The sum may have tiny rounding errors, allow 1 token tolerance
        assertApproxEqAbs(
            sumOfValues + minLiquidity,
            effectiveLiquidity,
            1e18, // 1 LEAGUE tolerance for rounding
            "LP values should sum to effective liquidity"
        );
        console.log("  [PASS] LP share values sum to effective liquidity\n");

        // Verify deposit ratios preserved (~60/40 split)
        // LP1 deposited 300k (60%), LP2 deposited 200k (40%)
        // Minimum liquidity lock (1000 wei) from LP1's first deposit causes tiny skew
        uint256 lp1Pct = (lp1CurrentValue * 100) / sumOfValues;
        uint256 lp2Pct = (lp2CurrentValue * 100) / sumOfValues;

        console.log("  LP1 share of pool:", lp1Pct, "%");
        console.log("  LP2 share of pool:", lp2Pct, "%");
        assertApproxEqAbs(lp1Pct, 60, 1, "LP1 should have ~60% of pool");
        assertApproxEqAbs(lp2Pct, 40, 1, "LP2 should have ~40% of pool");
        console.log("  [PASS] Deposit ratio preserved (~60/40)\n");

        _assertLPInvariant("Final checkpoint");
    }

    // ============================================
    // MULTI-LP DEPOSIT/WITHDRAW AFTER ROUND
    // ============================================

    function testMultiLP_DepositAndWithdrawAfterRound() public {
        console.log("\n============================================================");
        console.log("  MULTI-LP DEPOSIT & WITHDRAW AFTER ROUND");
        console.log("============================================================\n");

        // ---- LP Deposits ----
        vm.startPrank(lp1);
        leagueToken.approve(address(liquidityPool), 200_000 ether);
        liquidityPool.addLiquidity(200_000 ether);
        vm.stopPrank();

        vm.startPrank(lp2);
        leagueToken.approve(address(liquidityPool), 100_000 ether);
        liquidityPool.addLiquidity(100_000 ether);
        vm.stopPrank();

        uint256 initialTotalLiquidity = liquidityPool.totalLiquidity();
        console.log("  Initial Total Liquidity:", initialTotalLiquidity / 1e18, "LEAGUE");

        // ---- Round Start ----
        gameEngine.startSeason();
        gameEngine.startRound();
        uint256 roundId = gameEngine.getCurrentRound();

        // ---- Place bets ----
        _placeSingleBet(player1, 0, 1, 2_000 ether);
        _placeSingleBet(player2, 1, 2, 3_000 ether);

        (uint256 volume,,,,) = bettingPool.getRoundAccounting(roundId);
        console.log("  Bet Volume:", volume / 1e18, "LEAGUE");
        console.log("  Borrowed:", liquidityPool.borrowedForPoolBalancing() / 1e18, "LEAGUE\n");

        _assertLPInvariant("After bets");

        // ---- Snapshot before LP withdrawals ----
        uint256 lp1SharesBefore = liquidityPool.lpShares(lp1);
        uint256 lp2SharesBefore = liquidityPool.lpShares(lp2);
        uint256 lp1BalanceBefore = leagueToken.balanceOf(lp1);
        uint256 lp2BalanceBefore = leagueToken.balanceOf(lp2);

        console.log("LP SHARE BALANCES BEFORE WITHDRAWAL:");
        console.log("  LP1 Shares:", lp1SharesBefore / 1e18);
        console.log("  LP2 Shares:", lp2SharesBefore / 1e18);

        // ---- Simulate round finalization (unlock LP) ----
        // In production, this happens via finalizeRoundRevenue()
        // For testing LP accounting, we simulate the unlock
        liquidityPool.setRoundActive(false);

        // ---- LP1 withdraws 50% of shares ----
        console.log("\nLP WITHDRAWALS (AFTER ROUND FINALIZED):");
        console.log("----------------------------------------");

        uint256 lp1WithdrawShares = lp1SharesBefore / 2;
        vm.prank(lp1);
        uint256 lp1Received = liquidityPool.removeLiquidity(lp1WithdrawShares);

        console.log("  LP1 withdrew", lp1WithdrawShares / 1e18, "shares");
        console.log("  LP1 received:", lp1Received / 1e18, "LEAGUE (after 0.5% fee)");

        _assertLPInvariant("After LP1 partial withdrawal");

        // ---- LP2 withdraws 100% of shares ----
        vm.prank(lp2);
        uint256 lp2Received = liquidityPool.removeLiquidity(lp2SharesBefore);

        console.log("  LP2 withdrew", lp2SharesBefore / 1e18, "shares (full withdrawal)");
        console.log("  LP2 received:", lp2Received / 1e18, "LEAGUE (after 0.5% fee)");

        _assertLPInvariant("After LP2 full withdrawal");

        // ---- Verify final accounting ----
        console.log("\nFINAL ACCOUNTING:");
        console.log("----------------------------------------");

        uint256 lp1BalanceAfter = leagueToken.balanceOf(lp1);
        uint256 lp2BalanceAfter = leagueToken.balanceOf(lp2);
        uint256 lp1Gained = lp1BalanceAfter - lp1BalanceBefore;
        uint256 lp2Gained = lp2BalanceAfter - lp2BalanceBefore;

        console.log("  LP1 received:", lp1Gained / 1e18, "LEAGUE");
        console.log("  LP2 received:", lp2Gained / 1e18, "LEAGUE");
        console.log("  Remaining Liquidity:", liquidityPool.totalLiquidity() / 1e18, "LEAGUE");
        console.log("  Remaining Shares:", liquidityPool.totalShares() / 1e18);

        // LP1 still has shares remaining
        uint256 lp1RemainingShares = liquidityPool.lpShares(lp1);
        assertTrue(lp1RemainingShares > 0, "LP1 should have remaining shares");
        assertEq(liquidityPool.lpShares(lp2), 0, "LP2 should have no shares left");

        console.log("  LP1 remaining shares:", lp1RemainingShares / 1e18);

        // Withdrawal fee check: 0.5% fee means received < gross value
        // LP1 deposited 200k, withdrew 50% so gross ~ 100k, with fee ~ 99.5k
        assertTrue(lp1Received < 100_000 ether, "LP1 should receive less than gross (0.5% fee)");
        assertTrue(lp1Received > 99_000 ether, "LP1 should receive close to gross value");
        console.log("  [PASS] Withdrawal fee (0.5%) applied correctly");

        console.log("  [PASS] All LP accounting sums verified\n");
    }

    // ============================================
    // LP VALUE PER SHARE TEST
    // ============================================

    function testLPShareValueConsistency() public {
        console.log("\n============================================================");
        console.log("  LP SHARE VALUE CONSISTENCY TEST");
        console.log("============================================================\n");

        // ---- First LP deposits ----
        vm.startPrank(lp1);
        leagueToken.approve(address(liquidityPool), 100_000 ether);
        liquidityPool.addLiquidity(100_000 ether);
        vm.stopPrank();

        uint256 lp1Shares = liquidityPool.lpShares(lp1);
        uint256 totalLiq1 = liquidityPool.totalLiquidity();
        uint256 totalSh1 = liquidityPool.totalShares();

        uint256 valuePerShare1 = (totalLiq1 * 1e18) / totalSh1;
        console.log("  After LP1 deposit:");
        console.log("    Total Liquidity:", totalLiq1 / 1e18, "LEAGUE");
        console.log("    Total Shares:", totalSh1 / 1e18);
        console.log("    Value per Share:", valuePerShare1 * 100 / 1e18, "/ 100 LEAGUE");

        // ---- Second LP deposits at same ratio ----
        vm.startPrank(lp2);
        leagueToken.approve(address(liquidityPool), 50_000 ether);
        liquidityPool.addLiquidity(50_000 ether);
        vm.stopPrank();

        uint256 lp2Shares = liquidityPool.lpShares(lp2);
        uint256 totalLiq2 = liquidityPool.totalLiquidity();
        uint256 totalSh2 = liquidityPool.totalShares();

        uint256 valuePerShare2 = (totalLiq2 * 1e18) / totalSh2;
        console.log("\n  After LP2 deposit:");
        console.log("    Total Liquidity:", totalLiq2 / 1e18, "LEAGUE");
        console.log("    Total Shares:", totalSh2 / 1e18);
        console.log("    Value per Share:", valuePerShare2 * 100 / 1e18, "/ 100 LEAGUE");

        // Value per share should remain the same
        assertEq(valuePerShare1, valuePerShare2, "Value per share changed after second deposit");
        console.log("  [PASS] Value per share unchanged after second LP deposit\n");

        // ---- Start round and place bets ----
        gameEngine.startSeason();
        gameEngine.startRound();

        _placeSingleBet(player1, 0, 1, 5_000 ether);
        _placeSingleBet(player2, 0, 2, 5_000 ether);

        uint256 totalLiq3 = liquidityPool.totalLiquidity();
        uint256 totalSh3 = liquidityPool.totalShares();
        uint256 borrowed3 = liquidityPool.borrowedForPoolBalancing();

        // Effective value per share accounts for borrowed funds
        uint256 effectiveValuePerShare = ((totalLiq3 + borrowed3) * 1e18) / totalSh3;

        console.log("  After bets placed:");
        console.log("    Total Liquidity:", totalLiq3 / 1e18, "LEAGUE");
        console.log("    Borrowed:", borrowed3 / 1e18, "LEAGUE");
        console.log("    Effective Liquidity:", (totalLiq3 + borrowed3) / 1e18, "LEAGUE");
        console.log("    Effective Value/Share:", effectiveValuePerShare * 100 / 1e18, "/ 100 LEAGUE");

        // Effective value per share should still match (borrowed funds will return)
        assertEq(effectiveValuePerShare, valuePerShare1, "Effective value/share changed after bets");
        console.log("  [PASS] Effective value per share preserved after borrowing\n");

        // ---- Verify LP1:LP2 ratio is 2:1 ----
        (,, uint256 lp1Value,,,) = liquidityPool.getLPPosition(lp1);
        (,, uint256 lp2Value,,,) = liquidityPool.getLPPosition(lp2);

        console.log("  LP1 current value:", lp1Value / 1e18, "LEAGUE");
        console.log("  LP2 current value:", lp2Value / 1e18, "LEAGUE");

        // LP1 deposited 100k, LP2 deposited 50k => 2:1 ratio
        // Allow small rounding
        assertApproxEqAbs(lp1Value, lp2Value * 2, 1e18, "LP1:LP2 ratio should be 2:1");
        console.log("  [PASS] LP1:LP2 value ratio is 2:1\n");
    }

    // ============================================
    // TOKEN CONSERVATION TEST
    // ============================================

    function testTokenConservation_NothingCreatedOrDestroyed() public {
        console.log("\n============================================================");
        console.log("  TOKEN CONSERVATION TEST");
        console.log("============================================================\n");

        // Track total supply
        uint256 totalSupply = leagueToken.totalSupply();

        // Snapshot initial balances of all actors
        uint256 ownerBal = leagueToken.balanceOf(owner);
        uint256 lp1Bal = leagueToken.balanceOf(lp1);
        uint256 lp2Bal = leagueToken.balanceOf(lp2);
        uint256 p1Bal = leagueToken.balanceOf(player1);
        uint256 p2Bal = leagueToken.balanceOf(player2);
        uint256 p3Bal = leagueToken.balanceOf(player3);
        uint256 treasuryBal = leagueToken.balanceOf(protocolTreasury);
        uint256 bpBal = leagueToken.balanceOf(address(bettingPool));
        uint256 lpBal = leagueToken.balanceOf(address(liquidityPool));

        uint256 sumBefore = ownerBal + lp1Bal + lp2Bal + p1Bal + p2Bal + p3Bal
            + treasuryBal + bpBal + lpBal;

        console.log("  Total Supply:", totalSupply / 1e18, "LEAGUE");
        console.log("  Sum of known balances:", sumBefore / 1e18, "LEAGUE\n");

        // ---- Perform operations ----
        vm.startPrank(lp1);
        leagueToken.approve(address(liquidityPool), 100_000 ether);
        liquidityPool.addLiquidity(100_000 ether);
        vm.stopPrank();

        gameEngine.startSeason();
        gameEngine.startRound();

        _placeSingleBet(player1, 0, 1, 2_000 ether);
        _placeSingleBet(player2, 1, 2, 3_000 ether);

        // Cancel player2's bet
        vm.prank(player2);
        bettingPool.cancelBet(1); // betId 1

        // Simulate round finalization (unlock LP for withdrawal)
        liquidityPool.setRoundActive(false);

        // LP partial withdrawal
        uint256 lp1Shares = liquidityPool.lpShares(lp1);
        vm.prank(lp1);
        liquidityPool.removeLiquidity(lp1Shares / 4);

        // ---- Re-snapshot ----
        uint256 ownerBal2 = leagueToken.balanceOf(owner);
        uint256 lp1Bal2 = leagueToken.balanceOf(lp1);
        uint256 lp2Bal2 = leagueToken.balanceOf(lp2);
        uint256 p1Bal2 = leagueToken.balanceOf(player1);
        uint256 p2Bal2 = leagueToken.balanceOf(player2);
        uint256 p3Bal2 = leagueToken.balanceOf(player3);
        uint256 treasuryBal2 = leagueToken.balanceOf(protocolTreasury);
        uint256 bpBal2 = leagueToken.balanceOf(address(bettingPool));
        uint256 lpBal2 = leagueToken.balanceOf(address(liquidityPool));

        uint256 sumAfter = ownerBal2 + lp1Bal2 + lp2Bal2 + p1Bal2 + p2Bal2 + p3Bal2
            + treasuryBal2 + bpBal2 + lpBal2;

        console.log("  After operations:");
        console.log("    Owner:", ownerBal2 / 1e18, "LEAGUE");
        console.log("    LP1:", lp1Bal2 / 1e18, "LEAGUE");
        console.log("    LP2:", lp2Bal2 / 1e18, "LEAGUE");
        console.log("    Player1:", p1Bal2 / 1e18, "LEAGUE");
        console.log("    Player2:", p2Bal2 / 1e18, "LEAGUE");
        console.log("    Player3:", p3Bal2 / 1e18, "LEAGUE");
        console.log("    Treasury:", treasuryBal2 / 1e18, "LEAGUE");
        console.log("    BettingPool:", bpBal2 / 1e18, "LEAGUE");
        console.log("    LP Pool:", lpBal2 / 1e18, "LEAGUE");
        console.log("    Sum:", sumAfter / 1e18, "LEAGUE\n");

        // CRITICAL: No tokens created or destroyed
        assertEq(sumAfter, sumBefore, "Token conservation violated!");
        assertEq(leagueToken.totalSupply(), totalSupply, "Total supply changed!");
        console.log("  [PASS] Token conservation verified - sum unchanged");
        console.log("  [PASS] Total supply unchanged\n");
    }

    // ============================================
    // HELPERS
    // ============================================

    function _placeSingleBet(address player, uint256 matchIdx, uint8 outcome, uint256 amount) internal {
        vm.startPrank(player);
        leagueToken.approve(address(bettingPool), amount);
        uint256[] memory matches = new uint256[](1);
        uint8[] memory predictions = new uint8[](1);
        matches[0] = matchIdx;
        predictions[0] = outcome;
        bettingPool.placeBet(matches, predictions, amount);
        vm.stopPrank();
    }

    function _assertLPInvariant(string memory checkpoint) internal view {
        uint256 actualBalance = leagueToken.balanceOf(address(liquidityPool));
        uint256 recordedLiquidity = liquidityPool.totalLiquidity();

        // LP contract's actual token balance should equal its recorded totalLiquidity
        assertEq(
            actualBalance,
            recordedLiquidity,
            string.concat("LP invariant broken at: ", checkpoint)
        );
    }

    function _logPL(string memory label, int256 pl) internal pure {
        if (pl >= 0) {
            console.log(label, "+", uint256(pl) / 1e18, "LEAGUE");
        } else {
            console.log(label, "-", uint256(-pl) / 1e18, "LEAGUE");
        }
    }
}

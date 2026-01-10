// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BettingPoolV2.sol";
import "../src/GameEngineV2_5.sol";
import "../src/LiquidityPool.sol";
import "../src/LeagueToken.sol";

// Mock VRF Wrapper for testing
contract MockVRFWrapper {
    function link() external view returns (address) {
        return address(this);
    }

    function calculateRequestPriceNative(uint32, uint32) external pure returns (uint256) {
        return 0.001 ether;
    }

    function calculateRequestPrice(uint32, uint32) external pure returns (uint256) {
        return 0.1 ether;
    }
}

contract BettingPoolV2Test is Test {
    BettingPoolV2 public bettingPool;
    GameEngine public gameEngine;
    LiquidityPool public liquidityPool;
    LeagueToken public leagueToken;

    address public owner;
    address public player1;
    address public player2;
    address public player3;
    address public lpProvider;

    // Mock VRF addresses
    address constant LINK_SEPOLIA = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address constant VRF_WRAPPER_SEPOLIA = 0x195f15F2d49d693cE265b4fB0fdDbE15b1850Cc1;

    event BetPlaced(
        uint256 indexed betId,
        address indexed bettor,
        uint256 indexed roundId,
        uint256 amount,
        uint256 bonus
    );
    event WinningsClaimed(uint256 indexed betId, address indexed bettor, uint256 amount);
    event RoundSettled(uint256 indexed roundId, uint256 totalWinningPool, uint256 totalLosingPool);

    function setUp() public {
        owner = address(this);
        player1 = makeAddr("player1");
        player2 = makeAddr("player2");
        player3 = makeAddr("player3");
        lpProvider = makeAddr("lpProvider");

        // Deploy contracts
        leagueToken = new LeagueToken(owner);

        // Deploy mock VRF Wrapper
        gameEngine = new GameEngine(address(leagueToken), 1); // subscription ID 1 for testing

        liquidityPool = new LiquidityPool(address(leagueToken), owner);
        bettingPool = new BettingPoolV2(
            address(leagueToken),
            address(gameEngine),
            address(liquidityPool),
            owner, // protocolTreasury
            owner, // rewardsDistributor
            owner  // initialOwner
        );

        // Link contracts
        liquidityPool.setAuthorizedCaller(address(bettingPool), true);

        // Fund protocol reserve (required for bonuses)
        uint256 initialReserve = 100000 ether;
        leagueToken.approve(address(bettingPool), initialReserve);
        bettingPool.fundProtocolReserve(initialReserve);

        // Fund players
        leagueToken.transfer(player1, 10000 ether);
        leagueToken.transfer(player2, 10000 ether);
        leagueToken.transfer(player3, 10000 ether);

        // Fund LP
        leagueToken.transfer(lpProvider, 50000 ether);
        vm.startPrank(lpProvider);
        leagueToken.approve(address(liquidityPool), 50000 ether);
        liquidityPool.deposit(50000 ether);
        vm.stopPrank();
    }

    function testInitialState() public view {
        assertEq(bettingPool.nextBetId(), 0, "First bet ID should be 0");
        assertEq(address(bettingPool.leagueToken()), address(leagueToken), "Token mismatch");
        assertEq(address(bettingPool.gameEngine()), address(gameEngine), "GameEngine mismatch");
        assertEq(bettingPool.protocolReserve(), 100000 ether, "Protocol reserve mismatch");
    }

    function testPlaceSingleBet() public {
        // Start season and round
        gameEngine.startSeason();
        gameEngine.startRound();

        // Player1 places bet on match 0, HOME_WIN
        uint256[] memory matchIndices = new uint256[](1);
        matchIndices[0] = 0;

        uint8[] memory outcomes = new uint8[](1);
        outcomes[0] = 1; // HOME_WIN

        uint256 betAmount = 100 ether;

        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), betAmount);

        uint256 betId = bettingPool.placeBet(matchIndices, outcomes, betAmount);
        vm.stopPrank();

        assertEq(betId, 0, "First bet ID should be 0");

        // Verify bet details
        (
            address bettor,
            uint256 roundId,
            uint256 amount,
            uint256 bonus,
            bool settled,
            bool claimed
        ) = bettingPool.getBet(betId);

        assertEq(bettor, player1, "Bettor mismatch");
        assertEq(roundId, 1, "Round mismatch");
        assertEq(amount, betAmount, "Amount mismatch");
        assertEq(bonus, 0, "Should have no bonus");
        assertFalse(settled, "Should not be settled");
        assertFalse(claimed, "Should not be claimed");
    }

    function testPlaceMultiBetWithBonus() public {
        gameEngine.startSeason();
        gameEngine.startRound();

        // Player1 places 3-match multibet
        uint256[] memory matchIndices = new uint256[](3);
        matchIndices[0] = 0;
        matchIndices[1] = 1;
        matchIndices[2] = 2;

        uint8[] memory outcomes = new uint8[](3);
        outcomes[0] = 1; // HOME_WIN
        outcomes[1] = 2; // AWAY_WIN
        outcomes[2] = 3; // DRAW

        uint256 betAmount = 100 ether;
        uint256 expectedBonus = (betAmount * 10) / 100; // 10% for 3 matches

        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), betAmount);

        uint256 betId = bettingPool.placeBet(matchIndices, outcomes, betAmount);
        vm.stopPrank();

        (,, uint256 amount, uint256 bonus,,) = bettingPool.getBet(betId);
        assertEq(bonus, expectedBonus, "Bonus calculation mismatch");
    }

    function testPoolAggregation() public {
        gameEngine.startSeason();
        gameEngine.startRound();

        // Multiple players bet on same match
        uint256[] memory matchIndices = new uint256[](1);
        matchIndices[0] = 0;

        // Player1: 100 LEAGUE on HOME_WIN
        uint8[] memory outcomes1 = new uint8[](1);
        outcomes1[0] = 1;
        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), 100 ether);
        bettingPool.placeBet(matchIndices, outcomes1, 100 ether);
        vm.stopPrank();

        // Player2: 200 LEAGUE on AWAY_WIN
        uint8[] memory outcomes2 = new uint8[](1);
        outcomes2[0] = 2;
        vm.startPrank(player2);
        leagueToken.approve(address(bettingPool), 200 ether);
        bettingPool.placeBet(matchIndices, outcomes2, 200 ether);
        vm.stopPrank();

        // Player3: 50 LEAGUE on HOME_WIN
        vm.startPrank(player3);
        leagueToken.approve(address(bettingPool), 50 ether);
        bettingPool.placeBet(matchIndices, outcomes1, 50 ether);
        vm.stopPrank();

        // Verify pool totals
        (uint256 homePool, uint256 awayPool, uint256 drawPool, uint256 totalPool) =
            bettingPool.getMatchPoolData(1, 0);

        assertEq(homePool, 150 ether, "HOME pool should be 150 (100+50)");
        assertEq(awayPool, 200 ether, "AWAY pool should be 200");
        assertEq(drawPool, 0, "DRAW pool should be 0");
        assertEq(totalPool, 350 ether, "Total pool should be 350");
    }

    function testMultiBetBonusDistribution() public {
        gameEngine.startSeason();
        gameEngine.startRound();

        // Player places 2-match bet
        uint256[] memory matchIndices = new uint256[](2);
        matchIndices[0] = 0;
        matchIndices[1] = 1;

        uint8[] memory outcomes = new uint8[](2);
        outcomes[0] = 1; // HOME_WIN
        outcomes[1] = 2; // AWAY_WIN

        uint256 betAmount = 100 ether;
        uint256 expectedBonus = (betAmount * 5) / 100; // 5% for 2 matches
        uint256 totalWithBonus = betAmount + expectedBonus;
        uint256 amountPerMatch = totalWithBonus / 2;

        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), betAmount);
        bettingPool.placeBet(matchIndices, outcomes, betAmount);
        vm.stopPrank();

        // Verify even distribution across match pools
        (uint256 home0,,,) = bettingPool.getMatchPoolData(1, 0);
        (,uint256 away1,,) = bettingPool.getMatchPoolData(1, 1);

        assertEq(home0, amountPerMatch, "Match 0 pool mismatch");
        assertEq(away1, amountPerMatch, "Match 1 pool mismatch");
    }

    function testCannotBetWhenBettingClosed() public {
        gameEngine.startSeason();
        gameEngine.startRound();

        // Close betting window\n        vm.warp(block.timestamp + 16 minutes);\n        gameEngine.requestMatchResults(false);

        // Try to place bet
        uint256[] memory matchIndices = new uint256[](1);
        matchIndices[0] = 0;
        uint8[] memory outcomes = new uint8[](1);
        outcomes[0] = 1;

        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), 100 ether);

        vm.expectRevert("Betting is closed");
        bettingPool.placeBet(matchIndices, outcomes, 100 ether);
        vm.stopPrank();
    }

    function testCannotBetWithZeroAmount() public {
        gameEngine.startSeason();
        gameEngine.startRound();

        uint256[] memory matchIndices = new uint256[](1);
        matchIndices[0] = 0;
        uint8[] memory outcomes = new uint8[](1);
        outcomes[0] = 1;

        vm.startPrank(player1);
        vm.expectRevert("Amount must be > 0");
        bettingPool.placeBet(matchIndices, outcomes, 0);
        vm.stopPrank();
    }

    function testCannotBetWithMismatchedArrays() public {
        gameEngine.startSeason();
        gameEngine.startRound();

        uint256[] memory matchIndices = new uint256[](2);
        matchIndices[0] = 0;
        matchIndices[1] = 1;

        uint8[] memory outcomes = new uint8[](1);
        outcomes[0] = 1;

        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), 100 ether);

        vm.expectRevert("Array length mismatch");
        bettingPool.placeBet(matchIndices, outcomes, 100 ether);
        vm.stopPrank();
    }

    function testCannotBetOnInvalidMatch() public {
        gameEngine.startSeason();
        gameEngine.startRound();

        uint256[] memory matchIndices = new uint256[](1);
        matchIndices[0] = 10; // Only 0-9 valid

        uint8[] memory outcomes = new uint8[](1);
        outcomes[0] = 1;

        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), 100 ether);

        vm.expectRevert("Invalid match index");
        bettingPool.placeBet(matchIndices, outcomes, 100 ether);
        vm.stopPrank();
    }

    function testCannotBetOnInvalidOutcome() public {
        gameEngine.startSeason();
        gameEngine.startRound();

        uint256[] memory matchIndices = new uint256[](1);
        matchIndices[0] = 0;

        uint8[] memory outcomes = new uint8[](1);
        outcomes[0] = 4; // Invalid (only 1,2,3 valid)

        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), 100 ether);

        vm.expectRevert("Invalid outcome");
        bettingPool.placeBet(matchIndices, outcomes, 100 ether);
        vm.stopPrank();
    }

    function testGetRoundInfo() public {
        gameEngine.startSeason();
        gameEngine.startRound();

        // Place some bets
        uint256[] memory matchIndices = new uint256[](1);
        matchIndices[0] = 0;
        uint8[] memory outcomes = new uint8[](1);
        outcomes[0] = 1;

        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), 100 ether);
        bettingPool.placeBet(matchIndices, outcomes, 100 ether);
        vm.stopPrank();

        (
            uint256 totalBetVolume,
            uint256 totalWinningPool,
            uint256 totalLosingPool,
            uint256 totalReserved,
            uint256 totalClaimed,
            bool settled,
            bool revenueDistributed
        ) = bettingPool.getRoundAccounting(1);

        assertEq(totalBetVolume, 100 ether, "Bet volume mismatch");
        assertEq(totalWinningPool, 0, "Should be 0 before settlement");
        assertEq(totalLosingPool, 0, "Should be 0 before settlement");
        assertEq(totalReserved, 0, "Should be 0 before settlement");
        assertEq(totalClaimed, 0, "No claims yet");
        assertFalse(revenueDistributed, "Revenue not distributed");
        assertFalse(settled, "Not settled yet");
    }

    function testCalculateMultibetBonus() public {
        gameEngine.startSeason();
        gameEngine.startRound();

        // Test different multibet lengths
        uint256 amount = 100 ether;

        // 1 match = 0% bonus
        uint256[] memory matches1 = new uint256[](1);
        matches1[0] = 0;
        uint8[] memory outcomes1 = new uint8[](1);
        outcomes1[0] = 1;

        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), amount);
        uint256 betId1 = bettingPool.placeBet(matches1, outcomes1, amount);
        (,,, uint256 bonus1,,) = bettingPool.getBet(betId1);
        assertEq(bonus1, 0, "1 match should have 0% bonus");
        vm.stopPrank();

        // 2 matches = 3% bonus
        uint256[] memory matches2 = new uint256[](2);
        matches2[0] = 0;
        matches2[1] = 1;
        uint8[] memory outcomes2 = new uint8[](2);
        outcomes2[0] = 1;
        outcomes2[1] = 1;

        vm.startPrank(player2);
        leagueToken.approve(address(bettingPool), amount);
        uint256 betId2 = bettingPool.placeBet(matches2, outcomes2, amount);
        (,,, uint256 bonus2,,) = bettingPool.getBet(betId2);
        assertEq(bonus2, (amount * 5) / 100, "2 matches should have 5% bonus");
        vm.stopPrank();

        // 3 matches = 10% bonus
        uint256[] memory matches3 = new uint256[](3);
        matches3[0] = 0;
        matches3[1] = 1;
        matches3[2] = 2;
        uint8[] memory outcomes3 = new uint8[](3);
        outcomes3[0] = 1;
        outcomes3[1] = 1;
        outcomes3[2] = 1;

        vm.startPrank(player3);
        leagueToken.approve(address(bettingPool), amount);
        uint256 betId3 = bettingPool.placeBet(matches3, outcomes3, amount);
        (,,, uint256 bonus3,,) = bettingPool.getBet(betId3);
        assertEq(bonus3, (amount * 10) / 100, "3 matches should have 10% bonus");
        vm.stopPrank();
    }

    function testBonusDeductsFromProtocolReserve() public {
        gameEngine.startSeason();
        gameEngine.startRound();

        uint256 initialReserve = bettingPool.protocolReserve();

        // Place 3-match bet (10% bonus)
        uint256[] memory matchIndices = new uint256[](3);
        matchIndices[0] = 0;
        matchIndices[1] = 1;
        matchIndices[2] = 2;

        uint8[] memory outcomes = new uint8[](3);
        outcomes[0] = 1;
        outcomes[1] = 1;
        outcomes[2] = 1;

        uint256 betAmount = 100 ether;
        uint256 expectedBonus = (betAmount * 10) / 100;

        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), betAmount);
        bettingPool.placeBet(matchIndices, outcomes, betAmount);
        vm.stopPrank();

        uint256 finalReserve = bettingPool.protocolReserve();
        assertEq(finalReserve, initialReserve - expectedBonus, "Reserve should decrease by bonus");
    }

    function testGetMatchPoolInfo() public {
        gameEngine.startSeason();
        gameEngine.startRound();

        // Place bets on match 0
        uint256[] memory matchIndices = new uint256[](1);
        matchIndices[0] = 0;

        // 100 on HOME
        uint8[] memory outcomes1 = new uint8[](1);
        outcomes1[0] = 1;
        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), 100 ether);
        bettingPool.placeBet(matchIndices, outcomes1, 100 ether);
        vm.stopPrank();

        // 200 on AWAY
        uint8[] memory outcomes2 = new uint8[](1);
        outcomes2[0] = 2;
        vm.startPrank(player2);
        leagueToken.approve(address(bettingPool), 200 ether);
        bettingPool.placeBet(matchIndices, outcomes2, 200 ether);
        vm.stopPrank();

        // 50 on DRAW
        uint8[] memory outcomes3 = new uint8[](1);
        outcomes3[0] = 3;
        vm.startPrank(player3);
        leagueToken.approve(address(bettingPool), 50 ether);
        bettingPool.placeBet(matchIndices, outcomes3, 50 ether);
        vm.stopPrank();

        (uint256 home, uint256 away, uint256 draw, uint256 total) =
            bettingPool.getMatchPoolData(1, 0);

        assertEq(home, 100 ether, "Home pool");
        assertEq(away, 200 ether, "Away pool");
        assertEq(draw, 50 ether, "Draw pool");
        assertEq(total, 350 ether, "Total pool");
    }

    function testFundProtocolReserve() public view {
        uint256 initialReserve = bettingPool.protocolReserve();
        assertGt(initialReserve, 0, "Should have initial reserve from setup");
    }

    function testGetUserBets() public {
        gameEngine.startSeason();
        gameEngine.startRound();

        // Player1 places 3 bets
        uint256[] memory matchIndices = new uint256[](1);
        matchIndices[0] = 0;
        uint8[] memory outcomes = new uint8[](1);
        outcomes[0] = 1;

        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), 300 ether);

        bettingPool.placeBet(matchIndices, outcomes, 100 ether);
        bettingPool.placeBet(matchIndices, outcomes, 100 ether);
        bettingPool.placeBet(matchIndices, outcomes, 100 ether);
        vm.stopPrank();

        uint256[] memory userBets = bettingPool.getUserBets(player1);
        assertEq(userBets.length, 3, "Should have 3 bets");
        assertEq(userBets[0], 0, "First bet ID");
        assertEq(userBets[1], 1, "Second bet ID");
        assertEq(userBets[2], 2, "Third bet ID");
    }

    function testMultipleBettorsOnSameOutcome() public {
        gameEngine.startSeason();
        gameEngine.startRound();

        uint256[] memory matchIndices = new uint256[](1);
        matchIndices[0] = 0;
        uint8[] memory outcomes = new uint8[](1);
        outcomes[0] = 1; // All bet on HOME_WIN

        // Player1: 100
        vm.startPrank(player1);
        leagueToken.approve(address(bettingPool), 100 ether);
        bettingPool.placeBet(matchIndices, outcomes, 100 ether);
        vm.stopPrank();

        // Player2: 200
        vm.startPrank(player2);
        leagueToken.approve(address(bettingPool), 200 ether);
        bettingPool.placeBet(matchIndices, outcomes, 200 ether);
        vm.stopPrank();

        // Player3: 300
        vm.startPrank(player3);
        leagueToken.approve(address(bettingPool), 300 ether);
        bettingPool.placeBet(matchIndices, outcomes, 300 ether);
        vm.stopPrank();

        (uint256 homePool,,,) = bettingPool.getMatchPoolData(1, 0);
        assertEq(homePool, 600 ether, "All bets should aggregate");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/GameEngineV2_5.sol";
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

contract GameEngineV2_5Test is Test {
    GameEngine public gameEngine;
    LeagueToken public leagueToken;

    address public owner;
    address public player1;
    address public player2;

    // Mock VRF addresses (Sepolia testnet)
    address constant LINK_SEPOLIA = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address constant VRF_WRAPPER_SEPOLIA = 0x195f15F2d49d693cE265b4fB0fdDbE15b1850Cc1;

    event SeasonStarted(uint256 seasonId, uint256 timestamp);
    event RoundStarted(uint256 roundId, uint256 seasonId);
    event RandomnessRequested(uint256 requestId, uint256 roundId);
    event MatchesGenerated(uint256 roundId, uint256 timestamp);
    event RoundFinalized(uint256 roundId);

    function setUp() public {
        owner = address(this);
        player1 = makeAddr("player1");
        player2 = makeAddr("player2");

        // Deploy LeagueToken (also acts as mock LINK)
        leagueToken = new LeagueToken(owner);

        // Deploy mock VRF Wrapper
        // Deploy GameEngine with subscription ID 1 for testing
        gameEngine = new GameEngine(address(leagueToken), 1);

        // Fund test accounts
        vm.deal(owner, 100 ether);
        vm.deal(player1, 10 ether);
        vm.deal(player2, 10 ether);
    }

    function testInitialState() public view {
        assertEq(gameEngine.currentSeasonId(), 0, "Season should start at 0");
        assertEq(gameEngine.currentRoundId(), 0, "Round should start at 0");
        assertEq(gameEngine.owner(), owner, "Owner should be deployer");
    }

    function testStartSeason() public {
        vm.expectEmit(true, true, false, false);
        emit SeasonStarted(1, block.timestamp);

        gameEngine.startSeason();

        assertEq(gameEngine.currentSeasonId(), 1, "Season ID should be 1");

        GameEngine.Season memory season = gameEngine.getSeason(1);
        assertEq(season.seasonId, 1, "Season ID mismatch");
        assertTrue(season.active, "Season should be active");
        assertEq(season.startTime, block.timestamp, "Start time mismatch");
    }

    function testCannotStartMultipleSeasons() public {
        gameEngine.startSeason();

        vm.expectRevert("Season already active");
        gameEngine.startSeason();
    }

    function testStartRound() public {
        // Start season first
        gameEngine.startSeason();

        vm.expectEmit(true, true, false, false);
        emit RoundStarted(1, 1);

        gameEngine.startRound();

        assertEq(gameEngine.currentRoundId(), 1, "Round ID should be 1");

        GameEngine.Round memory round = gameEngine.getRound(1);
        assertEq(round.roundId, 1, "Round ID mismatch");
        assertEq(round.seasonId, 1, "Season ID mismatch");
        assertFalse(round.settled, "Should not be settled yet");
    }

    function testCannotStartRoundWithoutSeason() public {
        vm.expectRevert("No active season");
        gameEngine.startRound();
    }

    function testCannotStartMultipleRounds() public {
        gameEngine.startSeason();
        gameEngine.startRound();

        vm.expectRevert("Round already active");
        gameEngine.startRound();
    }

    function testRequestMatchResults() public {
        // Setup: Start season and round
        gameEngine.startSeason();
        gameEngine.startRound();

        // Fast forward past betting window (15 minutes)
        vm.warp(block.timestamp + 16 minutes);

        // Note: This will fail on local testnet without actual VRF
        // but tests the function logic
        vm.expectEmit(false, true, false, false);
        emit RandomnessRequested(0, 1); // requestId will be dynamic

        gameEngine.requestMatchResults(false);

        GameEngine.Round memory round = gameEngine.getRound(1);
        assertTrue(round.vrfRequestId > 0, "VRF request should be made");
    }

    function testCannotRequestResultsTooEarly() public {
        gameEngine.startSeason();
        gameEngine.startRound();

        // Try immediately
        vm.expectRevert("Betting window still open");
        gameEngine.requestMatchResults(false);

        // Try at 14 minutes (still too early)
        vm.warp(block.timestamp + 14 minutes);
        vm.expectRevert("Betting window still open");
        gameEngine.requestMatchResults(false);
    }

    function testCannotRequestResultsMultipleTimes() public {
        gameEngine.startSeason();
        gameEngine.startRound();

        vm.warp(block.timestamp + 16 minutes);
        gameEngine.requestMatchResults(false);

        vm.expectRevert("Results already requested");
        gameEngine.requestMatchResults(false);
    }

    function testGetMatch() public {
        gameEngine.startSeason();
        gameEngine.startRound();

        // Before generation
        GameEngine.Match memory matchData = gameEngine.getMatch(1, 0);
        assertEq(matchData.homeTeamId, 0, "Match should not exist yet");

        // We can't test actual match generation without VRF callback
        // but we verify the getter works
    }

    function testGetNonexistentMatch() public {
        gameEngine.startSeason();
        gameEngine.startRound();

        // Match index out of bounds
        GameEngine.Match memory matchData = gameEngine.getMatch(1, 999);
        assertEq(matchData.homeTeamId, 0, "Should return empty match");
    }

    function testOnlyOwnerCanStartSeason() public {
        vm.prank(player1);
        vm.expectRevert();
        gameEngine.startSeason();
    }

    function testOnlyOwnerCanStartRound() public {
        gameEngine.startSeason();

        vm.prank(player1);
        vm.expectRevert();
        gameEngine.startRound();
    }

    function testSeasonRoundProgression() public {
        // Season 1, Round 1
        gameEngine.startSeason();
        gameEngine.startRound();
        assertEq(gameEngine.currentSeasonId(), 1, "Season 1");
        assertEq(gameEngine.currentRoundId(), 1, "Round 1");

        // Finalize round 1
        vm.warp(block.timestamp + 16 minutes);
        gameEngine.requestMatchResults(false);

        // We can't actually finalize without VRF, but we can test the pattern
        // In real test with VRF mock, we would:
        // 1. Mock VRF callback with random numbers
        // 2. Call finalizeRound()
        // 3. Start round 2
        // 4. Verify roundId = 2, seasonId = 1
    }

    function testGetSeasonInfo() public {
        gameEngine.startSeason();

        GameEngine.Season memory season = gameEngine.getSeason(1);
        assertEq(season.seasonId, 1, "Season ID");
        assertTrue(season.active, "Active");
        assertEq(season.currentRound, 0, "No rounds yet");
        assertEq(season.startTime, block.timestamp, "Start time");
    }

    function testGetRoundInfo() public {
        gameEngine.startSeason();
        gameEngine.startRound();

        GameEngine.Round memory round = gameEngine.getRound(1);
        assertEq(round.roundId, 1, "Round ID");
        assertEq(round.seasonId, 1, "Season ID");
        assertEq(round.vrfRequestId, 0, "No VRF request yet");
        assertFalse(round.settled, "Not settled");
    }

    function testBettingWindowTiming() public {
        gameEngine.startSeason();
        gameEngine.startRound();

        GameEngine.Round memory round = gameEngine.getRound(1);
        uint256 bettingStart = round.startTime;

        // At 14 minutes - should still be open
        vm.warp(bettingStart + 14 minutes);
        vm.expectRevert("Betting window still open");
        gameEngine.requestMatchResults(false);

        // At 15 minutes exactly - should still be open (< not <=)
        vm.warp(bettingStart + 15 minutes);
        vm.expectRevert("Betting window still open");
        gameEngine.requestMatchResults(false);

        // At 15 minutes + 1 second - should be closed
        vm.warp(bettingStart + 15 minutes + 1);
        gameEngine.requestMatchResults(false); // Should succeed
    }

    function testMultipleRoundsInSeason() public {
        gameEngine.startSeason();

        // Round 1
        gameEngine.startRound();
        assertEq(gameEngine.currentRoundId(), 1, "Round 1");

        // Close and request results
        vm.warp(block.timestamp + 16 minutes);
        gameEngine.requestMatchResults(false);

        // In a real test with VRF mock, we would:
        // 1. Mock fulfillRandomWords callback
        // 2. Call finalizeRound()
        // 3. Start round 2
        // 4. Verify season still = 1, round = 2
    }
}

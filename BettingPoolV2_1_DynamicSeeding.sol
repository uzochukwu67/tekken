// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Dynamic Seeding Extension for BettingPoolV2_1
 * @notice Add these functions to BettingPoolV2_1.sol to enable dynamic odds seeding
 * @dev Uses hybrid approach: pseudo-random for early rounds, team stats for later rounds
 */

// ADD THIS TO BettingPoolV2_1.sol:

/**
 * @notice Calculate differentiated seed amounts for a match (HYBRID MODEL)
 * @dev Round 1-3: Pseudo-random based on team IDs (no stats yet)
 *      Round 4+: Stats-based using actual team performance
 * @param roundId The round ID
 * @param matchIndex The match index (0-9)
 * @return homeSeed Amount to seed home pool
 * @return awaySeed Amount to seed away pool
 * @return drawSeed Amount to seed draw pool
 */
function _calculateMatchSeeds(uint256 roundId, uint256 matchIndex)
    internal
    view
    returns (uint256 homeSeed, uint256 awaySeed, uint256 drawSeed)
{
    // Get match from game engine
    (
        uint256 homeTeamId,
        uint256 awayTeamId,
        ,
        ,
        ,
        ,
        ,

    ) = gameEngine.getMatch(roundId, matchIndex);

    // Get current season and round number
    uint256 seasonId = gameEngine.getCurrentSeasonId();
    uint256 seasonRound = gameEngine.getCurrentSeasonRound();

    // Use pseudo-random for first 3 rounds (no meaningful stats yet)
    if (seasonRound <= 3) {
        return _calculatePseudoRandomSeeds(homeTeamId, awayTeamId, roundId);
    }

    // Use actual team stats from round 4 onwards
    return _calculateStatsBasedSeeds(seasonId, homeTeamId, awayTeamId);
}

/**
 * @notice Calculate seeds using pseudo-random distribution (for early rounds)
 * @dev Deterministic but varied based on team IDs
 */
function _calculatePseudoRandomSeeds(
    uint256 homeTeamId,
    uint256 awayTeamId,
    uint256 roundId
)
    internal
    pure
    returns (uint256 homeSeed, uint256 awaySeed, uint256 drawSeed)
{
    // Generate deterministic pseudo-random seed
    uint256 seed = uint256(
        keccak256(abi.encodePacked(homeTeamId, awayTeamId, roundId))
    );

    // Extract strength values (0-99)
    uint256 homeStrength = (seed >> 0) % 100;
    uint256 awayStrength = (seed >> 8) % 100;
    uint256 drawBias = (seed >> 16) % 100;

    uint256 totalSeed = SEED_PER_MATCH; // 300 LEAGUE

    // Calculate absolute difference
    uint256 diff = homeStrength > awayStrength
        ? homeStrength - awayStrength
        : awayStrength - homeStrength;

    if (diff > 30) {
        // Lopsided match (strong favorite)
        if (homeStrength > awayStrength) {
            // Strong home favorite
            homeSeed = (totalSeed * 50) / 100;  // 150 LEAGUE → 1.2x odds
            awaySeed = (totalSeed * 25) / 100;  //  75 LEAGUE → 1.8x odds
            drawSeed = (totalSeed * 25) / 100;  //  75 LEAGUE → 1.8x odds
        } else {
            // Strong away favorite
            homeSeed = (totalSeed * 25) / 100;  //  75 LEAGUE → 1.8x odds
            awaySeed = (totalSeed * 50) / 100;  // 150 LEAGUE → 1.2x odds
            drawSeed = (totalSeed * 25) / 100;  //  75 LEAGUE → 1.8x odds
        }
    } else if (diff <= 10) {
        // Balanced match
        homeSeed = (totalSeed * 35) / 100;  // 105 LEAGUE → 1.43x odds
        awaySeed = (totalSeed * 35) / 100;  // 105 LEAGUE → 1.43x odds
        drawSeed = (totalSeed * 30) / 100;  //  90 LEAGUE → 1.56x odds
    } else {
        // Moderate favorite (11-30 difference)
        if (homeStrength > awayStrength) {
            homeSeed = (totalSeed * 40) / 100;  // 120 LEAGUE → 1.33x odds
            awaySeed = (totalSeed * 27) / 100;  //  80 LEAGUE → 1.67x odds
            drawSeed = (totalSeed * 33) / 100;  // 100 LEAGUE → 1.50x odds
        } else {
            homeSeed = (totalSeed * 27) / 100;  //  80 LEAGUE → 1.67x odds
            awaySeed = (totalSeed * 40) / 100;  // 120 LEAGUE → 1.33x odds
            drawSeed = (totalSeed * 33) / 100;  // 100 LEAGUE → 1.50x odds
        }
    }

    // Apply draw bias modifier for defensive matchups
    if (drawBias > 75) {
        // High draw probability (defensive teams)
        uint256 drawBoost = (drawSeed * 30) / 100; // +30% to draw pool
        drawSeed += drawBoost;
        homeSeed -= drawBoost / 2;
        awaySeed -= drawBoost / 2;
    }

    return (homeSeed, awaySeed, drawSeed);
}

/**
 * @notice Calculate seeds using actual team stats (for mid-late season)
 * @dev Uses points, goal difference, and form to determine realistic odds
 */
function _calculateStatsBasedSeeds(
    uint256 seasonId,
    uint256 homeTeamId,
    uint256 awayTeamId
)
    internal
    view
    returns (uint256 homeSeed, uint256 awaySeed, uint256 drawSeed)
{
    // Get team stats from game engine
    (
        ,
        uint256 homeWins,
        uint256 homeDraws,
        uint256 homeLosses,
        uint256 homePoints,
        uint256 homeGoalsFor,
        uint256 homeGoalsAgainst
    ) = gameEngine.getTeamStats(seasonId, homeTeamId);

    (
        ,
        uint256 awayWins,
        uint256 awayDraws,
        uint256 awayLosses,
        uint256 awayPoints,
        uint256 awayGoalsFor,
        uint256 awayGoalsAgainst
    ) = gameEngine.getTeamStats(seasonId, awayTeamId);

    uint256 totalSeed = SEED_PER_MATCH; // 300 LEAGUE

    // Calculate adjusted points (home advantage: +10%)
    uint256 adjustedHomePoints = (homePoints * 110) / 100;

    // Calculate point difference
    uint256 totalPoints = adjustedHomePoints + awayPoints;

    if (totalPoints == 0) {
        // Fallback to moderate home favorite if no data
        return (120 ether, 80 ether, 100 ether);
    }

    // Calculate goal difference for fine-tuning
    int256 homeGD = int256(homeGoalsFor) - int256(homeGoalsAgainst);
    int256 awayGD = int256(awayGoalsFor) - int256(awayGoalsAgainst);

    // Base distribution inversely proportional to points
    // More points → Higher win probability → MORE seed → LOWER odds
    uint256 baseHomeSeed = (totalSeed * adjustedHomePoints) / totalPoints;
    uint256 baseAwaySeed = (totalSeed * awayPoints) / totalPoints;

    // Calculate point difference for draw probability
    uint256 pointDiff = adjustedHomePoints > awayPoints
        ? adjustedHomePoints - awayPoints
        : awayPoints - adjustedHomePoints;

    // Determine draw seed based on how close the match is
    uint256 baseDrawSeed;
    if (pointDiff <= 3) {
        // Very close match → High draw probability
        baseDrawSeed = (totalSeed * 40) / 100;  // 120 LEAGUE → Lower draw odds
    } else if (pointDiff <= 6) {
        // Moderately close
        baseDrawSeed = (totalSeed * 33) / 100;  // 100 LEAGUE
    } else if (pointDiff <= 10) {
        // Decent gap
        baseDrawSeed = (totalSeed * 25) / 100;  // 75 LEAGUE
    } else {
        // Large gap → Low draw probability
        baseDrawSeed = (totalSeed * 20) / 100;  // 60 LEAGUE → Higher draw odds
    }

    // Adjust home/away seeds to accommodate draw seed
    uint256 remainingSeed = totalSeed - baseDrawSeed;
    homeSeed = (remainingSeed * adjustedHomePoints) / totalPoints;
    awaySeed = remainingSeed - homeSeed;
    drawSeed = baseDrawSeed;

    // Fine-tune based on goal difference
    // Teams with better GD get slightly more seed (lower odds)
    if (homeGD > awayGD + 5) {
        // Home has much better GD
        uint256 gdBoost = (homeSeed * 5) / 100;  // +5% to home seed
        homeSeed += gdBoost;
        awaySeed -= gdBoost;
    } else if (awayGD > homeGD + 5) {
        // Away has much better GD
        uint256 gdBoost = (awaySeed * 5) / 100;  // +5% to away seed
        awaySeed += gdBoost;
        homeSeed -= gdBoost;
    }

    // Check for defensive teams (low goals for/against → higher draw probability)
    uint256 homeTotalGames = homeWins + homeDraws + homeLosses;
    uint256 awayTotalGames = awayWins + awayDraws + awayLosses;

    if (homeTotalGames > 0 && awayTotalGames > 0) {
        uint256 homeAvgGoals = (homeGoalsFor + homeGoalsAgainst) / homeTotalGames;
        uint256 awayAvgGoals = (awayGoalsFor + awayGoalsAgainst) / awayTotalGames;

        // If both teams average < 2 goals per game → Defensive match → More draws
        if (homeAvgGoals < 2 && awayAvgGoals < 2) {
            uint256 drawBoost = (drawSeed * 20) / 100;  // +20% to draw
            drawSeed += drawBoost;
            homeSeed -= drawBoost / 2;
            awaySeed -= drawBoost / 2;
        }
    }

    // Ensure seeds are reasonable (no zero or negative values)
    if (homeSeed < 50 ether) homeSeed = 50 ether;
    if (awaySeed < 50 ether) awaySeed = 50 ether;
    if (drawSeed < 50 ether) drawSeed = 50 ether;

    // Normalize to exactly SEED_PER_MATCH
    uint256 actualTotal = homeSeed + awaySeed + drawSeed;
    homeSeed = (homeSeed * totalSeed) / actualTotal;
    awaySeed = (awaySeed * totalSeed) / actualTotal;
    drawSeed = totalSeed - homeSeed - awaySeed; // Remainder goes to draw

    return (homeSeed, awaySeed, drawSeed);
}

/**
 * @notice Updated seedRoundPools function with dynamic seeding
 * @dev REPLACE the existing seedRoundPools function with this
 */
function seedRoundPools(uint256 roundId) external onlyOwner {
    RoundAccounting storage accounting = roundAccounting[roundId];
    require(!accounting.seeded, "Round already seeded");
    require(currentRoundId == roundId, "Not current round");

    uint256 totalSeedAmount = 0;

    // Seed each match with DIFFERENTIATED amounts
    for (uint256 i = 0; i < 10; i++) {
        (uint256 homeSeed, uint256 awaySeed, uint256 drawSeed) = _calculateMatchSeeds(roundId, i);

        MatchPool storage pool = accounting.matchPools[i];
        pool.homeWinPool = homeSeed;
        pool.awayWinPool = awaySeed;
        pool.drawPool = drawSeed;
        pool.totalPool = homeSeed + awaySeed + drawSeed;

        totalSeedAmount += pool.totalPool;
    }

    // Deduct from protocol reserve
    require(protocolReserve >= totalSeedAmount, "Insufficient reserve");
    protocolReserve -= totalSeedAmount;
    accounting.protocolSeedAmount = totalSeedAmount;
    accounting.seeded = true;

    emit RoundSeeded(roundId, totalSeedAmount);
}

/**
 * @notice Get preview of match odds before seeding (for frontend)
 * @dev Useful for showing users what odds will look like
 */
function previewMatchOdds(uint256 roundId, uint256 matchIndex)
    external
    view
    returns (
        uint256 homeOdds,
        uint256 awayOdds,
        uint256 drawOdds
    )
{
    (uint256 homeSeed, uint256 awaySeed, uint256 drawSeed) = _calculateMatchSeeds(roundId, matchIndex);

    // Calculate odds (inverse of seed ratio)
    // odds = (total pool) / (outcome pool)
    uint256 totalPool = homeSeed + awaySeed + drawSeed;

    homeOdds = (totalPool * 1e18) / homeSeed;
    awayOdds = (totalPool * 1e18) / awaySeed;
    drawOdds = (totalPool * 1e18) / drawSeed;

    return (homeOdds, awayOdds, drawOdds);
}

# Dynamic Odds Seeding Solution

## Problem Statement

**Current Issue**: All matches in a round are seeded identically (120/80/100 LEAGUE), resulting in the same starting odds for every match. This looks unrealistic and boring to users.

**Expected Behavior**: Each match should have unique odds reflecting team strength differences:
- Match 1: HOME 1.2x, AWAY 1.5x, DRAW 1.8x (strong home favorite)
- Match 2: HOME 1.35x, AWAY 1.44x, DRAW 1.6x (more balanced)
- Match 3: HOME 1.8x, AWAY 1.15x, DRAW 2.0x (strong away favorite)
- etc.

---

## Solution: Deterministic Pseudo-Random Seeding

### Approach

Use the **match metadata** (homeTeamId, awayTeamId, roundId) to generate deterministic but varied seed amounts for each match. This ensures:

1. ✅ **Different odds per match** - Each match looks unique
2. ✅ **Deterministic** - Same teams always get same odds in same round
3. ✅ **No gas overhead** - No need to store team stats on-chain
4. ✅ **Realistic distribution** - Some matches are balanced, others are lopsided

---

## Implementation

### Option 1: Deterministic Hash-Based Seeding (Recommended)

```solidity
// BettingPoolV2_1.sol

/**
 * @notice Calculate differentiated seed amounts for a match
 * @dev Uses team IDs to generate pseudo-random but deterministic seeds
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
    // Get match details from GameEngine
    IGameEngine.Match memory matchData = gameEngine.getMatchData(roundId, matchIndex);

    // Generate pseudo-random value based on team IDs
    // This ensures same teams always get same odds in a round
    uint256 seed = uint256(
        keccak256(abi.encodePacked(
            matchData.homeTeamId,
            matchData.awayTeamId,
            roundId
        ))
    );

    // Extract different values from seed
    uint256 homeStrength = (seed >> 0) % 100;   // 0-99
    uint256 awayStrength = (seed >> 8) % 100;   // 0-99
    uint256 drawBias = (seed >> 16) % 100;      // 0-99

    // Total seed per match (same as before)
    uint256 totalSeed = SEED_PER_MATCH; // 300 LEAGUE

    // Calculate distribution based on relative strengths
    // HomeStrength vs AwayStrength determines favorite

    if (homeStrength > awayStrength + 20) {
        // Strong home favorite (e.g., 75 vs 40)
        // Home gets MORE seed → LOWER odds
        homeSeed = (totalSeed * 50) / 100;  // 150 LEAGUE → ~1.2x odds
        awaySeed = (totalSeed * 25) / 100;  //  75 LEAGUE → ~1.8x odds
        drawSeed = (totalSeed * 25) / 100;  //  75 LEAGUE → ~1.8x odds

    } else if (awayStrength > homeStrength + 20) {
        // Strong away favorite (e.g., 40 vs 75)
        homeSeed = (totalSeed * 25) / 100;  //  75 LEAGUE → ~1.8x odds
        awaySeed = (totalSeed * 50) / 100;  // 150 LEAGUE → ~1.2x odds
        drawSeed = (totalSeed * 25) / 100;  //  75 LEAGUE → ~1.8x odds

    } else if (abs(homeStrength - awayStrength) <= 10) {
        // Balanced match (e.g., 50 vs 55)
        homeSeed = (totalSeed * 35) / 100;  // 105 LEAGUE → ~1.4x odds
        awaySeed = (totalSeed * 35) / 100;  // 105 LEAGUE → ~1.4x odds
        drawSeed = (totalSeed * 30) / 100;  //  90 LEAGUE → ~1.5x odds

    } else {
        // Moderate favorite (e.g., 60 vs 45)
        if (homeStrength > awayStrength) {
            homeSeed = (totalSeed * 40) / 100;  // 120 LEAGUE (default)
            awaySeed = (totalSeed * 27) / 100;  //  80 LEAGUE (default)
            drawSeed = (totalSeed * 33) / 100;  // 100 LEAGUE (default)
        } else {
            homeSeed = (totalSeed * 27) / 100;  //  80 LEAGUE
            awaySeed = (totalSeed * 40) / 100;  // 120 LEAGUE
            drawSeed = (totalSeed * 33) / 100;  // 100 LEAGUE
        }
    }

    // Apply draw bias modifier
    if (drawBias > 70) {
        // High draw probability match (defensive teams)
        uint256 drawBoost = (drawSeed * 20) / 100; // +20% to draw
        drawSeed += drawBoost;
        homeSeed -= drawBoost / 2;
        awaySeed -= drawBoost / 2;
    }

    return (homeSeed, awaySeed, drawSeed);
}

/**
 * @notice Helper function for absolute value
 */
function abs(uint256 a, uint256 b) internal pure returns (uint256) {
    return a > b ? a - b : b - a;
}
```

### Updated `seedRoundPools` Function

```solidity
function seedRoundPools(uint256 roundId) external onlyOwner {
    RoundAccounting storage accounting = roundAccounting[roundId];
    require(!accounting.seeded, "Round already seeded");
    require(currentRoundId == roundId, "Not current round");

    uint256 totalSeedAmount = 0;

    // Seed each match with DIFFERENT amounts
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
```

---

## Example Output

With this implementation, a round might have:

```
Match 0: HOME 150, AWAY  75, DRAW  75 → HOME 1.20x, AWAY 1.80x, DRAW 1.80x (home favorite)
Match 1: HOME 105, AWAY 105, DRAW  90 → HOME 1.43x, AWAY 1.43x, DRAW 1.56x (balanced)
Match 2: HOME  75, AWAY 150, DRAW  75 → HOME 1.80x, AWAY 1.20x, DRAW 1.80x (away favorite)
Match 3: HOME 120, AWAY  80, DRAW 100 → HOME 1.33x, AWAY 1.67x, DRAW 1.50x (moderate home)
Match 4: HOME  80, AWAY 120, DRAW 100 → HOME 1.67x, AWAY 1.33x, DRAW 1.50x (moderate away)
Match 5: HOME 105, AWAY 105, DRAW  90 → HOME 1.43x, AWAY 1.43x, DRAW 1.56x (balanced)
Match 6: HOME 150, AWAY  75, DRAW  75 → HOME 1.20x, AWAY 1.80x, DRAW 1.80x (home favorite)
Match 7: HOME  90, AWAY  90, DRAW 120 → HOME 1.56x, AWAY 1.56x, DRAW 1.25x (draw likely)
Match 8: HOME 120, AWAY  80, DRAW 100 → HOME 1.33x, AWAY 1.67x, DRAW 1.50x (moderate home)
Match 9: HOME  75, AWAY 150, DRAW  75 → HOME 1.80x, AWAY 1.20x, DRAW 1.80x (away favorite)
```

**Total seed: ~3000 LEAGUE** (same as before, just distributed differently)

---

## Option 2: On-Chain Team Stats (More Realistic, Higher Gas)

If you want **truly realistic odds** based on actual team performance:

```solidity
struct TeamStats {
    uint256 wins;
    uint256 draws;
    uint256 losses;
    uint256 goalsFor;
    uint256 goalsAgainst;
    uint256 points;
}

mapping(uint256 => TeamStats) public teamStats; // teamId => stats

function _calculateMatchSeeds(uint256 roundId, uint256 matchIndex)
    internal
    view
    returns (uint256 homeSeed, uint256 awaySeed, uint256 drawSeed)
{
    IGameEngine.Match memory matchData = gameEngine.getMatchData(roundId, matchIndex);

    TeamStats memory homeTeam = teamStats[matchData.homeTeamId];
    TeamStats memory awayTeam = teamStats[matchData.awayTeamId];

    // Calculate win probability based on points
    uint256 homePoints = homeTeam.points;
    uint256 awayPoints = awayTeam.points;
    uint256 totalPoints = homePoints + awayPoints;

    if (totalPoints == 0) {
        // First round - use default seeding
        return (120 ether, 80 ether, 100 ether);
    }

    // Distribute seed inversely to win probability
    // Higher points → Higher win probability → MORE seed → LOWER odds

    uint256 totalSeed = SEED_PER_MATCH;

    // Home advantage: +10% to home points for calculation
    uint256 adjustedHomePoints = (homePoints * 110) / 100;

    homeSeed = (totalSeed * adjustedHomePoints) / (adjustedHomePoints + awayPoints);
    awaySeed = (totalSeed * awayPoints) / (adjustedHomePoints + awayPoints);

    // Draw seed is inverse of point difference
    uint256 pointDiff = abs(homePoints, awayPoints);
    if (pointDiff < 5) {
        // Close match → Higher draw probability → MORE seed → LOWER odds
        drawSeed = (totalSeed * 35) / 100;
        homeSeed = (homeSeed * 65) / 100;
        awaySeed = (awaySeed * 65) / 100;
    } else {
        drawSeed = (totalSeed * 20) / 100;
        homeSeed = (homeSeed * 80) / 100;
        awaySeed = (awaySeed * 80) / 100;
    }

    return (homeSeed, awaySeed, drawSeed);
}
```

**Trade-offs**:
- ✅ More realistic odds
- ✅ Evolves over season
- ❌ Higher gas costs
- ❌ Need to update stats after each round

---

## Option 3: Hybrid Approach (Best of Both)

**Recommendation**: Use **deterministic pseudo-random** (Option 1) for initial seeding, then gradually blend in actual team stats as season progresses.

```solidity
function _calculateMatchSeeds(uint256 roundId, uint256 matchIndex)
    internal
    view
    returns (uint256 homeSeed, uint256 awaySeed, uint256 drawSeed)
{
    IGameEngine.Match memory matchData = gameEngine.getMatchData(roundId, matchIndex);

    // Get current season round number
    uint256 seasonRound = gameEngine.getCurrentSeasonRound();

    if (seasonRound <= 5) {
        // First 5 rounds: Use deterministic pseudo-random (no team data yet)
        return _calculatePseudoRandomSeeds(roundId, matchIndex);
    } else {
        // After round 5: Use actual team stats
        return _calculateStatsBasedSeeds(roundId, matchIndex);
    }
}
```

---

## Frontend Impact

### Before (Static Odds)
```
Match 1: Manchester vs Liverpool    HOME 1.33x  AWAY 1.67x  DRAW 1.50x
Match 2: Arsenal vs Chelsea         HOME 1.33x  AWAY 1.67x  DRAW 1.50x
Match 3: Barcelona vs Real Madrid   HOME 1.33x  AWAY 1.67x  DRAW 1.50x
```
❌ **Looks fake and static**

### After (Dynamic Odds)
```
Match 1: Manchester vs Liverpool    HOME 1.20x  AWAY 1.80x  DRAW 1.80x
Match 2: Arsenal vs Chelsea         HOME 1.43x  AWAY 1.43x  DRAW 1.56x
Match 3: Barcelona vs Real Madrid   HOME 1.80x  AWAY 1.20x  DRAW 1.80x
```
✅ **Looks realistic and dynamic**

---

## Gas Cost Analysis

| Approach | Gas Cost per Round | Realism | Complexity |
|----------|-------------------|---------|------------|
| **Current (static)** | ~50k gas | ❌ Poor | ✅ Simple |
| **Option 1 (pseudo-random)** | ~60k gas | ✅ Good | ✅ Simple |
| **Option 2 (team stats)** | ~120k gas | ✅✅ Excellent | ⚠️ Complex |
| **Option 3 (hybrid)** | ~60-120k gas | ✅✅ Excellent | ⚠️ Medium |

**Recommendation**: Start with **Option 1** (pseudo-random) for V2.1, plan **Option 3** (hybrid) for V2.2.

---

## Implementation Steps

### Immediate (V2.1)

1. Add `_calculateMatchSeeds()` function with deterministic pseudo-random logic
2. Update `seedRoundPools()` to call `_calculateMatchSeeds()` for each match
3. Add `abs()` helper function
4. Test with 10 matches to ensure odds look differentiated

### Short-term (V2.2)

1. Add `TeamStats` struct to GameEngine
2. Update stats after each round settlement
3. Implement `_calculateStatsBasedSeeds()` with actual team data
4. Gradually transition from pseudo-random to stats-based after round 5

---

## Code to Add to BettingPoolV2_1.sol

```solidity
/**
 * @notice Calculate differentiated seed amounts for a match
 * @dev Uses deterministic pseudo-random based on team IDs
 */
function _calculateMatchSeeds(uint256 roundId, uint256 matchIndex)
    internal
    view
    returns (uint256 homeSeed, uint256 awaySeed, uint256 drawSeed)
{
    // Get match from game engine
    (uint256 homeTeamId, uint256 awayTeamId,,,,,,) = gameEngine.getMatch(roundId, matchIndex);

    // Generate deterministic pseudo-random seed
    uint256 seed = uint256(
        keccak256(abi.encodePacked(homeTeamId, awayTeamId, roundId))
    );

    // Extract strength values (0-99)
    uint256 homeStrength = (seed >> 0) % 100;
    uint256 awayStrength = (seed >> 8) % 100;
    uint256 drawBias = (seed >> 16) % 100;

    uint256 totalSeed = SEED_PER_MATCH; // 300 LEAGUE

    // Calculate distribution
    uint256 diff = homeStrength > awayStrength
        ? homeStrength - awayStrength
        : awayStrength - homeStrength;

    if (diff > 25) {
        // Lopsided match (strong favorite)
        if (homeStrength > awayStrength) {
            homeSeed = (totalSeed * 50) / 100;  // 150 LEAGUE
            awaySeed = (totalSeed * 25) / 100;  //  75 LEAGUE
            drawSeed = (totalSeed * 25) / 100;  //  75 LEAGUE
        } else {
            homeSeed = (totalSeed * 25) / 100;  //  75 LEAGUE
            awaySeed = (totalSeed * 50) / 100;  // 150 LEAGUE
            drawSeed = (totalSeed * 25) / 100;  //  75 LEAGUE
        }
    } else if (diff <= 10) {
        // Balanced match
        homeSeed = (totalSeed * 35) / 100;  // 105 LEAGUE
        awaySeed = (totalSeed * 35) / 100;  // 105 LEAGUE
        drawSeed = (totalSeed * 30) / 100;  //  90 LEAGUE
    } else {
        // Moderate favorite
        if (homeStrength > awayStrength) {
            homeSeed = (totalSeed * 40) / 100;  // 120 LEAGUE
            awaySeed = (totalSeed * 27) / 100;  //  80 LEAGUE
            drawSeed = (totalSeed * 33) / 100;  // 100 LEAGUE
        } else {
            homeSeed = (totalSeed * 27) / 100;  //  80 LEAGUE
            awaySeed = (totalSeed * 40) / 100;  // 120 LEAGUE
            drawSeed = (totalSeed * 33) / 100;  // 100 LEAGUE
        }
    }

    // Apply draw bias for defensive matchups
    if (drawBias > 75) {
        uint256 drawBoost = (drawSeed * 25) / 100; // +25% draw
        drawSeed += drawBoost;
        homeSeed -= drawBoost / 2;
        awaySeed -= drawBoost / 2;
    }

    return (homeSeed, awaySeed, drawSeed);
}
```

---

## Expected Odds Distribution

With this implementation, across 10 matches you'll see:

- **2-3 matches**: Strong favorites (1.2x vs 1.8x)
- **2-3 matches**: Balanced (1.4x vs 1.4x)
- **2-3 matches**: Moderate favorites (1.33x vs 1.67x)
- **1-2 matches**: Draw-heavy (1.5x vs 1.5x vs 1.3x)

This creates a **realistic and engaging** betting experience where users see varied odds that make sense intuitively.

---

## Conclusion

**Immediate Action**: Implement Option 1 (deterministic pseudo-random seeding) in V2.1 to fix the static odds issue.

**Result**: Each match will have unique, realistic-looking odds without requiring on-chain team stats or significant gas overhead.

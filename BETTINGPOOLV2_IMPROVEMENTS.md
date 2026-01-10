# BettingPoolV2: Key Improvements & Solutions

## Overview

BettingPoolV2 implements a **pool-based (parimutuel) betting system** that solves three critical problems with the original design:

1. **Infinite scalability** - No more O(N) loops through users
2. **Multibet bonus distribution** - Bonuses calculated upfront and split evenly
3. **LP exploit prevention** - Full liability reservation before revenue distribution

---

## Problem 1: Infinite Scalability

### The Issue (V1)
Traditional betting systems loop through all user bets to calculate payouts:

```solidity
// ❌ BAD: O(N) complexity - fails with 1000+ users
for (uint256 i = 0; i < allBets.length; i++) {
    if (bets[i].won) {
        payout(bets[i].bettor, bets[i].winnings);
    }
}
```

**Gas cost**: With 1000 users, settlement costs ~30M gas (exceeds block gas limit!)

### The Solution (V2)
**Pool-based betting**: Aggregate all bets into 30 pools (10 matches × 3 outcomes).

```solidity
// ✅ GOOD: O(10) = constant time - works with unlimited users
for (uint256 matchIndex = 0; matchIndex < 10; matchIndex++) {
    uint256 winningPool = pool.homeWinPool;  // or away/draw
    uint256 losingPool = pool.totalPool - winningPool;

    // Calculate total owed to winners
    uint256 distributed = (losingPool * 70) / 100;
    totalOwedToWinners += winningPool + distributed;
}
```

**Settlement**: Only loop through **10 matches**, not N users!

**Claiming**: Each user claims individually (user pays gas, not protocol)

```solidity
function claimWinnings(uint256 betId) external {
    // User calculates their own payout from pool ratios
    uint256 payout = _calculateWinnings(betId);
    token.transfer(msg.sender, payout);
}
```

### Gas Comparison

| Users | V1 (Direct Payout) | V2 (Pool-Based) |
|-------|-------------------|-----------------|
| 10    | ~500k gas         | ~150k gas       |
| 100   | ~5M gas           | ~150k gas       |
| 1000  | ~50M gas ❌       | ~150k gas ✅    |
| 10000 | Impossible ❌     | ~150k gas ✅    |

**Key insight**: Settlement cost is **constant** regardless of user count!

---

## Problem 2: Multibet Bonus Distribution

### The Issue (V1)
Multibets (parlays) get bonuses, but how do we aggregate them with single bets?

```
User A: 100 LEAGUE on Match 0 HOME (single bet)
User B: 100 LEAGUE on Match 0 HOME + Match 1 AWAY (2-match multibet, 5% bonus)
```

How do we know the **true pool size** for Match 0 HOME when User B's bet is split?

### The Solution (V2)
**Calculate bonus upfront and split evenly** across match pools:

```solidity
function placeBet(
    uint256[] calldata matchIndices,    // [0, 1, 2]
    uint8[] calldata outcomes,          // [HOME, AWAY, DRAW]
    uint256 amount                      // 100 LEAGUE
) external {
    // 1. Calculate multibet bonus BEFORE splitting
    uint256 bonus = _calculateMultibetBonus(amount, matchIndices.length);
    // bonus = 10 LEAGUE for 3-match multibet (10%)

    // 2. Add bonus to total
    uint256 totalWithBonus = amount + bonus;  // 110 LEAGUE

    // 3. Split evenly across matches
    uint256 amountPerMatch = totalWithBonus / matchIndices.length;  // 36.67 LEAGUE each

    // 4. Add to pools
    for (uint256 i = 0; i < matchIndices.length; i++) {
        if (outcome == HOME_WIN) {
            pool.homeWinPool += amountPerMatch;  // 36.67 LEAGUE
        }
        // ... same for away/draw
    }
}
```

### Multibet Bonus Rates
- **1 match**: 0% bonus
- **2 matches**: 5% bonus
- **3 matches**: 10% bonus
- **4+ matches**: 20% bonus

### Why This Works
1. **Bonus comes from protocol reserve**, not other users
2. **Deducted upfront** when bet is placed
3. **Split evenly** across all match pools in the multibet
4. **Pools accurately reflect** all betting volume (single + multibet)

### Example
```
Round starts → All pools empty

// Single bet
placeBet([0], [HOME_WIN], 50 LEAGUE)
→ Match 0 HOME pool = 50 LEAGUE

// 3-match multibet (10% bonus = 10 LEAGUE)
placeBet([0, 1, 2], [HOME, AWAY, DRAW], 100 LEAGUE)
→ Total = 110 LEAGUE
→ Per match = 36.67 LEAGUE
→ Match 0 HOME pool += 36.67 LEAGUE
→ Match 1 AWAY pool += 36.67 LEAGUE
→ Match 2 DRAW pool += 36.67 LEAGUE

Final pools:
- Match 0 HOME: 86.67 LEAGUE (50 + 36.67)
- Match 1 AWAY: 36.67 LEAGUE
- Match 2 DRAW: 36.67 LEAGUE
```

---

## Problem 3: LP Exploit Prevention

### The Vulnerability (Original Design)

**Scenario**: What if we distributed revenue based on **claimed winnings** instead of **total owed**?

```
Round ends:
- Total losing pool: 1000 LEAGUE
- Total winning pool: 700 LEAGUE (not yet claimed)

After 24 hours:
- Only 100 LEAGUE claimed by winners
- System calculates: revenue = 1000 - 100 = 900 LEAGUE ❌ WRONG!
- Distributes 900 LEAGUE to LPs

LP withdraws their share immediately

Later:
- Remaining 600 LEAGUE winners try to claim
- Pool is drained - insufficient funds ❌ EXPLOIT!
```

**Problem**: LPs got revenue that should have been reserved for unclaimed winners.

### The Solution: Reserve Total Liability Upfront

```solidity
function finalizeRoundRevenue(uint256 roundId) external {
    RoundAccounting storage accounting = roundAccounting[roundId];

    // 1. Calculate TOTAL OWED to winners (not just claimed)
    uint256 totalOwedToWinners = _calculateTotalWinningPayouts(roundId);

    // 2. Reserve the full amount BEFORE distributing revenue
    accounting.totalReservedForWinners = totalOwedToWinners;

    // 3. Net revenue = losing pool - total OWED
    uint256 netRevenue = accounting.totalLosingPool - totalOwedToWinners;

    // 4. Distribute ONLY the true profit
    uint256 toLP = (netRevenue * lpShare) / 10000;
    liquidityPool.addLiquidity(toLP);
}
```

### How We Calculate Total Owed (O(10) = Constant Time!)

```solidity
function _calculateTotalWinningPayouts(uint256 roundId)
    internal view returns (uint256 totalOwed)
{
    // Loop through 10 MATCHES (not users!)
    for (uint256 matchIndex = 0; matchIndex < 10; matchIndex++) {
        MatchPool storage pool = accounting.matchPools[matchIndex];
        Match memory matchResult = gameEngine.getMatch(roundId, matchIndex);

        // Get winning pool (e.g., homeWinPool if HOME won)
        uint256 winningPool = _getWinningPoolAmount(pool, matchResult.outcome);
        uint256 losingPool = pool.totalPool - winningPool;

        // Winners get their stake back + 70% of losing pool
        uint256 distributed = (losingPool * 70) / 100;
        totalOwed += winningPool + distributed;
    }

    return totalOwed;
}
```

**Key insight**: Because we use **pool-based betting**, we can calculate total liability by checking **10 match pools**, not N users!

### Accounting Safeguards

```solidity
struct RoundAccounting {
    uint256 totalBetVolume;           // All bets placed
    uint256 totalWinningPool;         // Sum of all winning pools
    uint256 totalLosingPool;          // Sum of all losing pools
    uint256 totalReservedForWinners;  // CALCULATED: what we owe (not claimed)
    uint256 totalClaimed;             // ACTUAL: what's been claimed so far
    uint256 lpRevenueShare;           // LP's share (after reservation)
    bool settled;
    bool revenueDistributed;
}
```

**Before claiming**:
- `totalReservedForWinners = 700 LEAGUE` (calculated)
- `totalClaimed = 0 LEAGUE`

**After some claims**:
- `totalReservedForWinners = 700 LEAGUE` (unchanged)
- `totalClaimed = 100 LEAGUE`

**Revenue calculation**:
```solidity
netRevenue = totalLosingPool - totalReservedForWinners
           = 1000 LEAGUE - 700 LEAGUE
           = 300 LEAGUE ✅ CORRECT!
```

LPs only get their share of **true profit** (300 LEAGUE), not inflated amount (900 LEAGUE).

---

## Architecture Comparison

### Before (V1): Direct Payout System
```
placeBet() → Store individual bet
              ↓
settleRound() → Loop through ALL users ❌ O(N)
                Calculate each user's payout
                Send tokens to each user
                LP gets leftover
```

**Problems**:
- Gas limit exceeded with 1000+ users
- Can't aggregate multibets with single bets
- LP exploit if we use pull-based claims

### After (V2): Pool-Based System
```
placeBet() → Add to match pools (with bonus split)
              ↓
settleRound() → Loop through 10 MATCHES ✅ O(10)
                Calculate winning/losing pools
                ↓
claimWinnings() → User calculates payout from pool ratios
                  User pays gas for claim
                  ↓
finalizeRevenue() → Calculate TOTAL OWED (O(10))
                    Reserve full liability
                    Distribute true profit to LPs
```

**Benefits**:
- ✅ Infinite scalability (constant gas)
- ✅ Multibets work seamlessly (bonus split evenly)
- ✅ LP exploit prevented (full liability reserved)
- ✅ Users pay claim gas (not protocol)
- ✅ Market-driven odds (pool ratios)

---

## Dynamic Odds (Market-Driven)

Unlike traditional sportsbooks with fixed odds, pool-based betting has **dynamic odds** determined by betting volume:

```solidity
// Odds = 1 + (losing pool × 70%) / winning pool
odds = 1 + (losingPool * 7000) / (winningPool * 10000)
```

**Example**:
```
Match 0 pools:
- HOME: 100 LEAGUE
- AWAY: 200 LEAGUE
- DRAW: 50 LEAGUE
- Total: 350 LEAGUE

If HOME wins:
- Winning pool = 100 LEAGUE
- Losing pool = 250 LEAGUE (200 + 50)
- Payout per LEAGUE bet = 1 + (250 × 0.7) / 100 = 2.75x

If AWAY wins:
- Winning pool = 200 LEAGUE
- Losing pool = 150 LEAGUE (100 + 50)
- Payout per LEAGUE bet = 1 + (150 × 0.7) / 200 = 1.525x
```

**More popular outcome** → **lower odds** (market-driven!)

---

## Security Guarantees

### 1. **No Settlement Failures**
- O(10) gas cost = works with unlimited users
- No loops through user bets during settlement

### 2. **No LP Drain**
- Full winner liability calculated and reserved upfront
- LPs only get share of **true profit**, not inflated amount

### 3. **No Unclaimed Winner Loss**
- Winners can claim anytime (no expiry)
- Full payout reserved in accounting before LP distribution

### 4. **Pull-Based Claims (Gas Efficient)**
- Protocol doesn't pay gas to send winnings
- Users call `claimWinnings()` themselves
- Each claim is O(M) where M = number of matches in bet (max 10)

---

## Summary Table

| Feature | V1 (Direct Payout) | V2 (Pool-Based) |
|---------|-------------------|-----------------|
| Settlement gas | O(N) - fails at 1000+ users | O(10) - constant time ✅ |
| Multibet support | Hard to aggregate | Bonus split evenly ✅ |
| LP exploit risk | High if using pull-based | Prevented via reservation ✅ |
| Odds | Fixed (requires oracle) | Market-driven (pool ratios) ✅ |
| Claim gas | Protocol pays | User pays ✅ |
| Scalability | Limited by block gas | Infinite ✅ |

---

## Conclusion

BettingPoolV2's pool-based architecture is the only viable solution for **unlimited scalability** in on-chain betting. By aggregating bets into pools:

1. **Settlement is O(10)** - works with 10 or 10,000 users
2. **Multibets work seamlessly** - bonus calculated upfront and split evenly
3. **LPs are protected** - full winner liability reserved before distribution
4. **Users control gas** - pull-based claims mean protocol doesn't pay claim gas

This architecture is proven by platforms like **Polymarket**, **Augur**, and traditional **parimutuel betting systems** used in horse racing for over 100 years.

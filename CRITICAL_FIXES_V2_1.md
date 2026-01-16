# BettingPoolV2.1 - Critical Fixes Implemented

## Date: 2026-01-12

## Overview

This document details the critical security and economic fixes implemented in BettingPoolV2.1 based on the recommendations analysis.

---

## Fix #1: Multiplier Consistency Bug 🚨 CRITICAL

### Problem Identified

**Severity:** Critical - Could cause insolvency

The parlay multiplier was calculated **twice** with potentially different values:

1. **At bet placement**: Used to reserve parlay bonus from protocol
2. **At payout**: Recalculated dynamically, potentially different value

### Example of the Bug

```solidity
// Bet placement (reserves 1.5x multiplier bonus)
placeBet([match0, match1, match2], [HOME, HOME, HOME], 100 LEAGUE)
→ 3 legs detected
→ Reserves bonus for 1.5x multiplier

// Settlement (recalculates multiplier)
claimWinnings(betId)
→ One match pushed/voided, now 4 effective legs
→ Uses 2.0x multiplier (recalculated!)
→ Payout EXCEEDS reserved amount ❌ Insolvency risk!
```

### Root Cause

```solidity
// OLD CODE - placeBet()
uint256 parlayMultiplier = _getParlayMultiplierDynamicPreview(...);
_reserveParlayBonus(totalStake, parlayMultiplier);
// Multiplier NOT stored in bet struct ❌

// OLD CODE - _calculateBetPayout()
uint256 parlayMultiplier = _getParlayMultiplierDynamic(betId); // Recalculates! ❌
uint256 finalPayout = basePayout * parlayMultiplier;
```

### Solution Implemented

**Store the locked multiplier in the Bet struct at placement time:**

```solidity
// UPDATED Bet struct
struct Bet {
    address bettor;
    uint256 roundId;
    uint256 amount;
    uint256 bonus;
    uint256 lockedMultiplier;   // ✅ NEW: Locked at bet placement
    Prediction[] predictions;
    bool settled;
    bool claimed;
}

// UPDATED placeBet()
bet.lockedMultiplier = parlayMultiplier;  // ✅ Store at placement

// UPDATED _calculateBetPayout()
uint256 parlayMultiplier = bet.lockedMultiplier;  // ✅ Use locked value
```

### Impact

- ✅ **Economic Safety**: Reserved bonus always matches payout multiplier
- ✅ **No Overpayment**: Protocol can never pay more than reserved
- ✅ **Fairness**: Users locked in their multiplier at bet time (cannot game system)

---

## Fix #2: Parlay Bonus Structure Update

### Old Structure (Tier-Based)

```
1 leg:  1.0x (no bonus)
2 legs: 1.2x
3 legs: 1.5x
4 legs: 2.0x
5+ legs: 2.5x (capped)
```

**Problem:** Large jumps between tiers, not scalable to 10 matches

### New Structure (Linear Scaling)

**Formula:** Linear progression from 1.15x (2 matches) to 1.5x (10 matches)

```
1 match:  1.00x (no bonus)
2 matches: 1.15x
3 matches: 1.194x
4 matches: 1.238x
5 matches: 1.281x
6 matches: 1.325x
7 matches: 1.369x
8 matches: 1.413x
9 matches: 1.456x
10 matches: 1.50x (max)
```

### Mathematical Formula

```
multiplier = 1.15 + ((numMatches - 2) * 0.35 / 8)

where:
- Base = 1.15x (2 matches)
- Max = 1.50x (10 matches)
- Range = 0.35 (1.5 - 1.15)
- Steps = 8 (from 2 to 10 matches)
- Increment per match = 0.35 / 8 = 0.04375
```

### Benefits

✅ **Smoother Progression**: No sudden jumps
✅ **Scalable**: Works for all match counts 1-10
✅ **Conservative**: Lower max multiplier (1.5x vs 2.5x) reduces protocol risk
✅ **Still Attractive**: 15-50% bonus on winning parlays

### Economic Impact

| Scenario | Old Multiplier | New Multiplier | Protocol Savings |
|----------|----------------|----------------|------------------|
| 3-leg parlay win (1000 LEAGUE payout) | 1.5x → 1500 LEAGUE | 1.194x → 1194 LEAGUE | 306 LEAGUE (20%) |
| 4-leg parlay win (1000 LEAGUE payout) | 2.0x → 2000 LEAGUE | 1.238x → 1238 LEAGUE | 762 LEAGUE (38%) |
| 5-leg parlay win (1000 LEAGUE payout) | 2.5x → 2500 LEAGUE | 1.281x → 1281 LEAGUE | 1219 LEAGUE (49%) |

**Result:** ~20-50% reduction in parlay bonus costs while maintaining user appeal

---

## Fix #3: Circuit Breaker for Round Seeding 🔴 CRITICAL

### Problem Identified

**Severity:** High - Could prevent round from starting

Without a circuit breaker, the protocol could attempt to seed a round without sufficient reserves, causing:
- Transaction revert
- Round stuck (cannot start)
- User confusion
- Manual intervention required

### Solution Implemented

```solidity
function seedRoundPools(uint256 roundId) external onlyOwner {
    // ... existing checks ...

    // CIRCUIT BREAKER: Ensure protocol reserve can cover seeding + safety buffer
    uint256 totalSeedAmount = SEED_PER_ROUND; // 3,000 LEAGUE
    uint256 minRequiredReserve = totalSeedAmount * 3; // 9,000 LEAGUE minimum
    require(
        protocolReserve >= minRequiredReserve,
        "Circuit breaker: Insufficient protocol reserve - replenish before seeding"
    );

    // ... continue with seeding ...
}
```

### Rationale

- **3x Buffer**: Ensures reserve can handle:
  - 1x for seeding (3,000 LEAGUE)
  - 1x for parlay bonuses in current round (~3,000 LEAGUE expected)
  - 1x for safety buffer (unexpected high parlay volume)

### Benefits

✅ **Prevents Stuck Rounds**: Never attempt seeding without sufficient funds
✅ **Early Warning**: Forces operator to replenish reserve before running low
✅ **Safety Margin**: 3x buffer handles unexpected parlay volume
✅ **Clear Error Message**: Operator knows exactly what to do

### Example Scenario

```
Current Protocol Reserve: 5,000 LEAGUE

Attempt to seed round:
→ Required: 9,000 LEAGUE (3x 3,000 seed cost)
→ Available: 5,000 LEAGUE
→ ❌ Transaction reverts with clear message
→ ✅ Operator adds 10,000 LEAGUE to reserve
→ ✅ Can now seed round successfully
```

---

## Additional Updates

### Updated View Functions

```solidity
// getBet() now returns lockedMultiplier
function getBet(uint256 betId) external view returns (
    address bettor,
    uint256 roundId,
    uint256 amount,
    uint256 bonus,
    uint256 lockedMultiplier,  // ✅ NEW
    bool settled,
    bool claimed
)

// previewBetPayout() uses locked multiplier
function previewBetPayout(uint256 betId) external view returns (
    bool won,
    uint256 basePayout,
    uint256 finalPayout,
    uint256 parlayMultiplier  // ✅ Uses bet.lockedMultiplier
)
```

---

## Testing Requirements

### Critical Tests Needed

1. **Multiplier Consistency Test**
   ```solidity
   - Place 3-leg parlay (expects 1.194x)
   - Verify locked multiplier stored correctly
   - Simulate round settlement
   - Claim winnings
   - Assert payout uses exact locked multiplier (not recalculated)
   ```

2. **New Parlay Structure Test**
   ```solidity
   - Test all 10 multiplier levels (1-10 matches)
   - Verify linear progression
   - Compare payouts: old vs new structure
   ```

3. **Circuit Breaker Test**
   ```solidity
   - Drain protocol reserve below 9,000 LEAGUE
   - Attempt seedRoundPools()
   - Assert transaction reverts with correct message
   - Fund reserve above threshold
   - Assert seeding succeeds
   ```

---

## Migration Notes

### Breaking Changes

⚠️ **Bet struct has changed** - adds `lockedMultiplier` field

**Impact:**
- New bets will include locked multiplier
- Old bets (placed before upgrade) will have `lockedMultiplier = 0`
- Fallback: Use `_getParlayMultiplier(predictions.length)` for old bets

### Backwards Compatibility

```solidity
// Handle old bets (before upgrade)
function _calculateBetPayout(uint256 betId) internal view returns (...) {
    Bet storage bet = bets[betId];

    // If old bet (no locked multiplier), use fallback
    uint256 parlayMultiplier = bet.lockedMultiplier;
    if (parlayMultiplier == 0) {
        parlayMultiplier = _getParlayMultiplier(bet.predictions.length);
    }

    // ... rest of logic
}
```

---

## Deployment Checklist

- [ ] Update contract with fixes
- [ ] Test locally with Foundry
- [ ] Deploy to testnet (Sepolia)
- [ ] Run integration tests
- [ ] Ensure protocol reserve > 10,000 LEAGUE before mainnet
- [ ] Deploy to mainnet
- [ ] Seed first round (verify circuit breaker works)
- [ ] Monitor first 10 bets for correct multiplier locking

---

## Economic Analysis

### Protocol Reserve Requirements (Updated)

**Per Round:**
- Seeding: 3,000 LEAGUE
- Average parlay bonuses: ~2,000 LEAGUE (with new 1.15x-1.5x structure)
- Safety buffer: 3,000 LEAGUE
- **Total per round: ~8,000 LEAGUE**

**Circuit Breaker Requirement: 9,000 LEAGUE minimum**

### Cost Savings vs Old Structure

With new linear parlay structure:
- **20% reduction** in 3-leg parlay costs
- **38% reduction** in 4-leg parlay costs
- **49% reduction** in 5-leg parlay costs

**Estimated annual savings:** ~30% on total parlay bonus costs

---

## Status

✅ **All Fixes Implemented**
✅ **Code Updated**
⏳ **Testing Required**
⏳ **Deployment Pending**

---

## References

- Original recommendations: [Recommendation.md](./Recommendation.md)
- Virtual liquidity implementation: [ODDS_STABILITY_SOLUTION.md](./ODDS_STABILITY_SOLUTION.md)
- Updated contract: [BettingPoolV2_1.sol](./src/BettingPoolV2_1.sol)

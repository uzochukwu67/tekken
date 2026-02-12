# Critical Bug Report: Odds Scaling Mismatch in BettingCore

## Summary
**Severity:** CRITICAL
**Status:** Confirmed via Foundry tests
**Impact:** All bets have incorrect `potentialPayout` and `lockedMultiplier` calculated

## Root Cause

The `LockedOdds` struct stores odds with 6-decimal precision (1e6 scale):

```solidity
// src/libraries/DataTypes.sol:87-92
struct LockedOdds {
    uint64 homeOdds;  // Stored as 1e6 scale (e.g., 1.332e6 = 1.332x)
    uint64 awayOdds;
    uint64 drawOdds;
    bool locked;
}
```

However, `placeBet()` in BettingCore.sol uses these odds directly in calculations that expect 18-decimal precision:

```solidity
// src/core/BettingCore.sol:207-216
uint256 matchOdds;
if (prediction == 1) {
    matchOdds = odds.homeOdds;  // ❌ Using 6-decimal value (1.332e6)
} else if (prediction == 2) {
    matchOdds = odds.awayOdds;
} else {
    matchOdds = odds.drawOdds;
}

// Multiply odds together: expects 18-decimal values!
oddsMultiplier = (oddsMultiplier * matchOdds) / Constants.PRECISION;  // ❌ PRECISION = 1e18
```

## The Problem

### Expected Behavior (18 decimals):
```solidity
amount = 100 ether (100e18)
homeOdds = 1.332e18 (18 decimals)
finalMultiplier = homeOdds = 1.332e18
potentialPayout = (100e18 * 1.332e18) / 1e18 = 133.2e18 ✓
```

### Actual Behavior (6 decimals):
```solidity
amount = 100 ether (100e18)
homeOdds = 1.332e6 (6 decimals) ❌
finalMultiplier = homeOdds = 1.332e6 ❌
potentialPayout = (100e18 * 1.332e6) / 1e18 = 133.2e6 = 0.0001332 LBT ❌
```

## Test Evidence

From `test_BetDataVerification_SingleLeg()`:

```
[FAIL: Multiplier should equal home odds: 1332051 != 1332051000000000000]

Traces:
  emit BetPlaced(..., parlayMultiplier: 1332051 [1.332e6], ...)  // ❌ Wrong scale!

  Bet({
    amount: 100000000000000000000 [1e20],
    potentialPayout: 133205100 [1.332e8],  // ❌ Should be 133.2e18!
    lockedMultiplier: 1332051 [1.332e6],   // ❌ Should be 1.332e18!
    ...
  })
```

## Impact

1. **All bets have incorrect payouts** - Winners receive ~1/1,000,000,000,000th of expected payout
2. **Protocol reserves calculations are wrong** - Not locking enough funds
3. **User bets from before this fix cannot be claimed properly**
4. **Frontend displays from `getLockedOdds()` don't match actual bet calculations**

## Why Frontend Shows Correct Odds

The `getLockedOdds()` function correctly scales up to 18 decimals for external callers:

```solidity
function getLockedOdds(...) external view returns (...) {
    DataTypes.LockedOdds storage odds = s.lockedOdds[roundId][matchIndex];
    return (
        uint256(odds.homeOdds) * 1e12,  // ✓ Scale 1e6 → 1e18
        uint256(odds.awayOdds) * 1e12,
        uint256(odds.drawOdds) * 1e12,
        odds.locked
    );
}
```

But internal `placeBet()` accesses storage directly and uses the raw 6-decimal values!

## Solution

### Option 1: Scale odds in placeBet (RECOMMENDED)
```solidity
// src/core/BettingCore.sol:207-213
uint256 matchOdds;
if (prediction == 1) {
    matchOdds = uint256(odds.homeOdds) * 1e12;  // ✅ Scale to 18 decimals
} else if (prediction == 2) {
    matchOdds = uint256(odds.awayOdds) * 1e12;
} else {
    matchOdds = uint256(odds.drawOdds) * 1e12;
}
```

### Option 2: Change LockedOdds to uint256
```solidity
struct LockedOdds {
    uint256 homeOdds;  // Store as 18 decimals
    uint256 awayOdds;
    uint256 drawOdds;
    bool locked;
}
```
⚠️ This breaks storage layout for existing deployments!

## Recommendation

1. **Fix Option 1 immediately** - Scale odds to 18 decimals in placeBet()
2. **Add unit test** to verify potentialPayout calculation (already written in test file)
3. **Redeploy contracts** with fix
4. **Note:** Existing bets with 0 or very low payouts cannot be fixed retroactively

## Files Affected

- `src/libraries/DataTypes.sol` - LockedOdds struct definition
- `src/core/BettingCore.sol` - placeBet() calculation (lines 207-216)
- `test/ProtocolBackedBetting.t.sol` - New tests added to verify fix

## Test Coverage

Added comprehensive tests in `test/ProtocolBackedBetting.t.sol`:
- `test_BetDataVerification_SingleLeg()` - Verifies single bet payout calculation
- `test_BetDataVerification_ParlayBet()` - Verifies parlay multiplier calculation
- `test_CannotBetBeforeSeeding()` - Ensures odds must be locked first
- `test_GetBetExternalCall()` - Verifies getBet() returns correct data

Run tests:
```bash
forge test --match-test test_BetDataVerification -vv
```

---

**Date:** 2026-02-12
**Discovered by:** Claude Code analysis + Foundry testing
**Severity:** CRITICAL - Affects all bet payouts

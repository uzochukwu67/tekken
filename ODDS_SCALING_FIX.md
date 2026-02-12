# Odds Scaling Bug - FIXED ✅

## Status: RESOLVED
**Date:** 2026-02-12
**Tests:** ✅ All 32 tests passing
**Ready for deployment:** YES

---

## The Bug

The `placeBet()` function was using odds with **6-decimal precision** (1e6) directly from storage, but all calculations expected **18-decimal precision** (1e18). This caused potential payouts to be calculated as **1 trillionth** of the correct value.

### Example Impact:
```
Expected: 100 LBT bet at 1.33x odds = 133 LBT payout
Actual:   100 LBT bet at 1.33x odds = 0.000133 LBT payout ❌
```

---

## The Fix

**File:** `src/core/BettingCore.sol` (lines 205-217)

### Before (BROKEN):
```solidity
uint256 matchOdds;
if (prediction == 1) {
    matchOdds = odds.homeOdds;  // ❌ Using 6-decimal value (1.332e6)
} else if (prediction == 2) {
    matchOdds = odds.awayOdds;
} else {
    matchOdds = odds.drawOdds;
}
```

### After (FIXED):
```solidity
// ⚠️ CRITICAL FIX: Odds are stored as uint64 with 6 decimals (1e6)
// Must scale to 18 decimals (1e18) for calculations
uint256 matchOdds;
if (prediction == 1) {
    matchOdds = uint256(odds.homeOdds) * 1e12; // ✅ Scale 1e6 → 1e18
} else if (prediction == 2) {
    matchOdds = uint256(odds.awayOdds) * 1e12; // ✅ Scale 1e6 → 1e18
} else {
    matchOdds = uint256(odds.drawOdds) * 1e12; // ✅ Scale 1e6 → 1e18
}
```

---

## Test Results

### New Tests Added:
1. ✅ `test_BetDataVerification_SingleLeg()` - Verifies correct payout calculation for single bets
2. ✅ `test_BetDataVerification_ParlayBet()` - Verifies correct payout for parlay bets
3. ✅ `test_CannotBetBeforeSeeding()` - Ensures odds must be locked
4. ✅ `test_GetBetExternalCall()` - Verifies getBet() returns correct data

### All Tests Passing:
```bash
forge test --match-contract ProtocolBackedBettingTest

Ran 32 tests for test/ProtocolBackedBetting.t.sol:ProtocolBackedBettingTest
[PASS] testFuzz_BetAmount(uint256) (runs: 256)
[PASS] testFuzz_MultipleLegs(uint8) (runs: 256)
[PASS] test_BetDataVerification_ParlayBet() ✅
[PASS] test_BetDataVerification_SingleLeg() ✅
... [28 more tests passing]

Suite result: ok. 32 passed; 0 failed; 0 skipped
```

---

## Verification

The fix correctly scales odds from storage (6 decimals) to calculation precision (18 decimals):

**Example calculation (100 LBT bet, 1.33x odds):**
```solidity
// Storage value
odds.homeOdds = 1332051 (uint64, 6 decimals = 1.332051x)

// After fix
matchOdds = 1332051 * 1e12 = 1332051000000000000 (18 decimals)

// Payout calculation
finalMultiplier = matchOdds * parlayBonus / 1e18 = 1.332e18
potentialPayout = (100e18 * 1.332e18) / 1e18 = 133.2e18 ✅
```

---

## Impact on Existing Bets

⚠️ **Existing bets placed before this fix** (like bets #1, #2, #3 from testing) have incorrect payout values stored on-chain:
- These bets have `potentialPayout` values that are too small (1 trillionth of correct value)
- These bets **cannot be retroactively fixed** without redeployment
- Users should be notified that existing bets are invalid

### Recommendation:
1. ✅ **Fix is ready** - Deploy new contracts with fix
2. **Cancel old bets** - Notify users with bets on current deployment
3. **Seed new round** - Start fresh after redeployment

---

## Deployment Checklist

- [x] Bug identified and root cause confirmed
- [x] Fix implemented in BettingCore.sol
- [x] Comprehensive tests added
- [x] All existing tests still passing
- [x] Fix verified with test output
- [ ] Deploy to testnet
- [ ] Verify deployment contracts
- [ ] Test with real bets on testnet
- [ ] Extract ABIs
- [ ] Update frontend hooks
- [ ] Update manage-betting.sh with new addresses
- [ ] Deploy to mainnet (when ready)

---

## Files Modified

1. **src/core/BettingCore.sol**
   - Lines 205-217: Added 1e12 scaling multiplier to odds
   - Added explanatory comments

2. **test/ProtocolBackedBetting.t.sol**
   - Lines 879-1064: Added 4 new comprehensive bet data verification tests

3. **BUG_REPORT_ODDS_SCALING.md**
   - Detailed bug analysis and evidence

4. **ODDS_SCALING_FIX.md** (this file)
   - Fix summary and deployment guide

---

## Run Tests Yourself

```bash
# Run bet data verification tests
forge test --match-test test_BetDataVerification -vv

# Run all BettingCore tests
forge test --match-contract ProtocolBackedBettingTest

# Run full test suite
forge test
```

---

**Fix Status:** ✅ COMPLETE & VERIFIED
**Ready for deployment:** YES
**Breaking change:** YES (requires redeployment)

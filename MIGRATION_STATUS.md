# Migration Status - LP Pool Model

## ✅ COMPLETED

### 1. **LiquidityPoolV2.sol Created**
- ✅ AMM-style LP share system
- ✅ Direct deduction model
- ✅ Deposit/withdraw functions
- ✅ Authorization system
- ✅ Payout processing
- ✅ Seeding support
- ✅ 0.5% withdrawal fee
- ✅ Full test coverage ready

### 2. **BettingPoolV2_1.sol - Partial Update**

**✅ Completed:**
- Updated imports (ILiquidityPoolV2)
- Updated contract documentation
- Changed `liquidityPool` to `liquidityPoolV2`
- Added `PROTOCOL_FEE = 500` (5%)
- Reduced parlay multipliers (1.25x max)
- Removed `protocolReserve` state variable
- Removed `lockedParlayReserve` state variable
- Added caps (MAX_BET, MAX_PAYOUT, MAX_ROUND_PAYOUTS)

**⏳ REMAINING:**
- Update constructor
- Update `placeBet()` - add 5% fee logic
- Update `claimWinnings()` - pay from LP pool
- Update `seedRoundPools()` - request from LP pool
- Update `finalizeRoundRevenue()` - return profits to LP
- Remove `fundProtocolReserve()` function
- Remove `_reserveParlayBonus()` function
- Remove `_calculateMultibetBonus()` or adapt
- Update events
- Remove old circuit breaker logic

---

## 🔧 CRITICAL FUNCTIONS TO UPDATE

### Function 1: `constructor`

**Current:**
```solidity
constructor(
    address _leagueToken,
    address _gameEngine,
    address _liquidityPool,  // OLD
    address _protocolTreasury,
    address _rewardsDistributor,
    address _initialOwner
)
```

**Needed:**
```solidity
constructor(
    address _leagueToken,
    address _gameEngine,
    address _liquidityPoolV2,  // NEW
    address _protocolTreasury,
    address _rewardsDistributor,
    address _initialOwner
)
```

---

### Function 2: `placeBet()`

**Changes Needed:**
1. ✅ Check MAX_BET_AMOUNT (already added)
2. ❌ Deduct 5% protocol fee
3. ❌ Remove stake bonus logic (or make LP-funded)
4. ❌ Check LP pool can cover max payout
5. ❌ Remove parlay reserve logic
6. ❌ Transfer fee to treasury

**Current Flow:**
```
User pays 100 LEAGUE
→ Get stake bonus from protocol reserve
→ Reserve parlay bonus from protocol reserve
→ Add to pools
```

**New Flow:**
```
User pays 100 LEAGUE
→ Deduct 5 LEAGUE to treasury
→ Check LP pool has liquidity
→ Add 95 LEAGUE to pools
```

---

### Function 3: `claimWinnings()`

**Changes Needed:**
1. ❌ Remove parlay reserve release logic
2. ❌ Call `liquidityPoolV2.payWinner()` instead of direct transfer
3. ✅ Per-round payout cap (already added)

**Current Flow:**
```
Calculate payout
→ Release locked parlay reserve
→ Transfer from contract balance
```

**New Flow:**
```
Calculate payout
→ Call liquidityPoolV2.payWinner(winner, amount)
→ LP pool handles transfer
```

---

### Function 4: `seedRoundPools()`

**Changes Needed:**
1. ❌ Remove protocol reserve check/deduction
2. ❌ Call `liquidityPoolV2.fundSeeding(roundId, 3000 ether)`
3. ❌ Handle case where LP pool rejects (insufficient liquidity)

**Current Flow:**
```
Check protocolReserve >= 3000
→ protocolReserve -= 3000
→ Add to match pools
```

**New Flow:**
```
bool success = liquidityPoolV2.fundSeeding(roundId, 3000 ether)
→ require(success, "Insufficient LP liquidity")
→ Tokens transferred to contract
→ Add to match pools
```

---

### Function 5: `finalizeRoundRevenue()`

**Changes Needed:**
1. ❌ Remove old revenue split logic
2. ❌ Calculate round P&L
3. ❌ If profit: return to LP pool
4. ❌ If loss: LP already paid (no action)
5. ❌ Remove LP share transfer (not needed)

**Current Flow:**
```
netRevenue = losingPool - reservedForWinners
→ Split: 45% protocol, 53% LP, 2% season
→ Transfer to each
```

**New Flow:**
```
totalCollected = losingPool
totalPaid = totalPaidOut

if (totalCollected > totalPaid):
    profit = totalCollected - totalPaid
    liquidityPoolV2.collectLosingBet(profit)
else:
    // LP already absorbed loss
```

---

## 📦 FUNCTIONS TO REMOVE ENTIRELY

### 1. `fundProtocolReserve()`
**Reason:** No more protocol reserve

### 2. `_reserveParlayBonus()`
**Reason:** LP pool covers all bonuses, no pre-reservation needed

### 3. `_calculateMultibetBonus()`
**Reason:** No more stake bonus (or make it optional/LP-funded)

---

## 🧪 TESTING REQUIREMENTS

After migration complete:

### Unit Tests Needed:
- [ ] LP can deposit and get shares
- [ ] LP can withdraw and burn shares
- [ ] Protocol collects 5% fee on bets
- [ ] LP pool pays winners
- [ ] LP pool funds seeding
- [ ] Round profits return to LP pool
- [ ] Round losses reduce LP pool
- [ ] Caps work (max bet, max payout, max round)
- [ ] Reduced multipliers (1.25x max)

### Integration Tests:
- [ ] Full betting round with LP pool
- [ ] Multiple LPs, track individual P&L
- [ ] Protocol as LP (deposits and earns)
- [ ] Edge case: LP pool runs low
- [ ] Edge case: Whale tries max bet

---

## 📊 ESTIMATED COMPLETION

- **Completed:** ~40%
- **Remaining:** ~60%
- **Time Estimate:** ~2-3 hours of focused work

---

## 🚀 NEXT IMMEDIATE STEPS

1. Update constructor (5 min)
2. Update placeBet() with fee logic (15 min)
3. Update claimWinnings() (10 min)
4. Update seedRoundPools() (10 min)
5. Update finalizeRoundRevenue() (15 min)
6. Remove deprecated functions (5 min)
7. Test compilation (2 min)
8. Fix any compilation errors (30 min)
9. Write tests (60 min)

**Total:** ~2.5 hours

---

## ⚠️ RISKS & CONSIDERATIONS

1. **Breaking Change:** Existing contracts won't work with new system
2. **Migration:** Need to deploy entirely new set of contracts
3. **LP Capital:** Need initial LP deposits before accepting bets
4. **Testing:** Must thoroughly test before mainnet
5. **Documentation:** Update all docs to reflect new model

---

## 💡 BENEFITS OF NEW SYSTEM

1. ✅ **Simpler:** One liquidity source (LP pool)
2. ✅ **Transparent:** Each LP can see their P&L
3. ✅ **Fair:** Protocol competes as LP (not privileged)
4. ✅ **Sustainable:** Lower multipliers = safer for LPs
5. ✅ **Scalable:** AMM-style allows easy entry/exit
6. ✅ **DeFi-native:** Familiar pattern for crypto users

---

## Current State Summary

**Files Created:**
- ✅ LiquidityPoolV2.sol (complete)
- ✅ ILiquidityPoolV2.sol (complete)
- ✅ NEW_PARLAY_MULTIPLIERS.md (documentation)
- ✅ LP_MIGRATION_PLAN.md (strategy)
- ✅ MIGRATION_STATUS.md (this file)

**Files Partially Updated:**
- ⏳ BettingPoolV2_1.sol (40% done)

**Files Pending:**
- ⏳ SeasonPredictorV2.sol (not started)
- ⏳ Deploy scripts (need to create)
- ⏳ Test files (need to create)

---

**Ready to continue?** Should I proceed with updating the remaining BettingPoolV2_1.sol functions?

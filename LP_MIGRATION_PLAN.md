# LP Migration Plan - Complete System Overhaul

## 🎯 Goal
Convert from **protocol reserve model** to **unified LP pool model** where:
- All risk flows through LP pool
- Protocol earns 5% fee on bets
- LPs cover all payouts and seeding
- Clean, maintainable architecture

---

## 📋 Files to Update

### 1. **BettingPoolV2_1.sol** (MAJOR CHANGES)
**Remove:**
- `protocolReserve` state variable
- `lockedParlayReserve` state variable
- `fundProtocolReserve()` function
- All reserve management logic

**Add:**
- 5% protocol fee deduction on every bet
- Integration with `LiquidityPoolV2`
- New reduced parlay multipliers (1.25x max)
- LP pool checks before accepting bets

**Update:**
- `placeBet()` - deduct 5% fee, check LP pool
- `claimWinnings()` - pay from LP pool
- `seedRoundPools()` - request from LP pool
- `_reserveParlayBonus()` - remove (no more reserve)
- All payout logic - route through LP pool

---

### 2. **LiquidityPool.sol** (DEPRECATE)
**Action:** Mark as deprecated, do not modify
**Reason:** Replaced by LiquidityPoolV2.sol

---

### 3. **LiquidityPoolV2.sol** (NEW - ALREADY CREATED ✅)
**Status:** Complete, ready for integration
**Features:**
- AMM-style LP shares
- Direct deduction model
- Covers all payouts
- Funds seeding
- 0.5% exit fee

---

### 4. **SeasonPredictorV2.sol** (MINOR CHANGES)
**Update:**
- Remove dependency on protocol reserve
- Get rewards from LP pool or separate reward pool
- Update reward distribution logic

---

## 🔄 Step-by-Step Migration

### **Phase 1: Update Constants** ✅ NEXT

Update BettingPoolV2_1.sol constants:

```solidity
// OLD - Remove these
uint256 public protocolReserve;
uint256 public lockedParlayReserve;

// NEW - Add these
uint256 public constant PROTOCOL_FEE = 500; // 5% in basis points
ILiquidityPoolV2 public immutable liquidityPoolV2;
address public immutable protocolTreasury;

// Update parlay multipliers (1.25x max instead of 1.5x)
uint256 public constant PARLAY_MULTIPLIER_2_MATCHES = 105e16;  // 1.05x (was 1.15x)
uint256 public constant PARLAY_MULTIPLIER_3_MATCHES = 11e17;   // 1.10x (was 1.194x)
// ... etc
uint256 public constant PARLAY_MULTIPLIER_10_MATCHES = 125e16; // 1.25x (was 1.5x)
```

---

### **Phase 2: Update Constructor**

```solidity
constructor(
    address _leagueToken,
    address _gameEngine,
    address _liquidityPoolV2,    // NEW
    address _protocolTreasury,   // NEW
    address _rewardsDistributor,
    address _initialOwner
) Ownable(_initialOwner) {
    require(_liquidityPoolV2 != address(0), "Invalid LP pool");
    require(_protocolTreasury != address(0), "Invalid treasury");

    liquidityPoolV2 = ILiquidityPoolV2(_liquidityPoolV2);
    protocolTreasury = _protocolTreasury;
    // ... rest
}
```

---

### **Phase 3: Update placeBet()**

```solidity
function placeBet(...) external nonReentrant returns (uint256 betId) {
    // Existing validations...

    // Transfer user's stake
    require(leagueToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

    // NEW: Deduct 5% protocol fee
    uint256 protocolFee = (amount * PROTOCOL_FEE) / 10000;
    uint256 amountAfterFee = amount - protocolFee;

    // Transfer fee to treasury
    require(leagueToken.transfer(protocolTreasury, protocolFee), "Fee transfer failed");

    // OLD: Get stake bonus from protocol reserve ❌
    // NEW: Stake bonus comes from LP pool ✅
    // For now, remove stake bonus or make it optional

    // Check LP pool can cover potential payout
    uint256 maxPayout = _calculateMaxPayout(amountAfterFee, matchIndices.length);
    require(liquidityPoolV2.canCoverPayout(maxPayout), "Insufficient LP liquidity");

    // Rest of bet logic...
    // Allocate amountAfterFee to pools (not amount)
}
```

---

### **Phase 4: Update claimWinnings()**

```solidity
function claimWinnings(uint256 betId) external nonReentrant {
    // Existing validation...

    (bool won, uint256 basePayout, uint256 finalPayout) = _calculateBetPayout(betId);

    bet.claimed = true;

    if (won && finalPayout > 0) {
        accounting.totalClaimed += finalPayout;
        accounting.totalPaidOut += finalPayout;

        // NEW: Pay from LP pool (instead of contract balance)
        liquidityPoolV2.payWinner(msg.sender, finalPayout);

        emit WinningsClaimed(betId, msg.sender, basePayout, bet.lockedMultiplier, finalPayout);
    } else {
        emit BetLost(betId, msg.sender);
    }
}
```

---

### **Phase 5: Update seedRoundPools()**

```solidity
function seedRoundPools(uint256 roundId) external nonReentrant {
    // Existing validations...

    uint256 totalSeedAmount = SEED_PER_ROUND; // 3,000 LEAGUE

    // NEW: Request seeding from LP pool
    bool success = liquidityPoolV2.fundSeeding(roundId, totalSeedAmount);
    require(success, "LP pool cannot fund seeding");

    // Distribute to match pools
    for (uint256 i = 0; i < 10; i++) {
        MatchPool storage pool = accounting.matchPools[i];
        pool.homeWinPool += SEED_HOME_POOL;
        pool.awayWinPool += SEED_AWAY_POOL;
        pool.drawPool += SEED_DRAW_POOL;
        pool.totalPool += SEED_PER_MATCH;
    }

    accounting.protocolSeedAmount = totalSeedAmount;
    accounting.seeded = true;

    emit RoundSeeded(roundId, totalSeedAmount);
}
```

---

### **Phase 6: Update finalizeRoundRevenue()**

```solidity
function finalizeRoundRevenue(uint256 roundId) external nonReentrant {
    RoundAccounting storage accounting = roundAccounting[roundId];
    require(accounting.settled, "Round not settled");
    require(!accounting.revenueDistributed, "Already distributed");

    // Calculate net result for the round
    uint256 totalCollected = accounting.totalLosingPool;
    uint256 totalPaid = accounting.totalPaidOut;

    if (totalCollected > totalPaid) {
        // Round was profitable - add to LP pool
        uint256 profit = totalCollected - totalPaid;

        // Transfer profit back to LP pool
        require(leagueToken.approve(address(liquidityPoolV2), profit), "Approval failed");
        liquidityPoolV2.collectLosingBet(profit);

    } else if (totalPaid > totalCollected) {
        // Round was unprofitable - LP pool already paid the difference
        // No action needed, LPs already took the loss
    }

    // Season pool share (optional - from protocol fees or separate)
    uint256 seasonShare = (totalCollected * SEASON_POOL_SHARE) / 10000;
    seasonRewardPool += seasonShare;

    accounting.revenueDistributed = true;

    emit RoundRevenueFinalized(roundId, totalCollected, totalPaid, seasonShare);
}
```

---

### **Phase 7: Remove Deprecated Functions**

Delete these functions entirely:
- `fundProtocolReserve()`
- `_reserveParlayBonus()`
- `_calculateMultibetBonus()` (or simplify)

---

### **Phase 8: Update Events**

```solidity
// Remove old events
// event ParlayBonusReserved(...)
// event ParlayBonusReleased(...)

// Add new events
event ProtocolFeeCollected(uint256 amount);
event LPPayoutProcessed(address indexed winner, uint256 amount);
event RoundProfitToLP(uint256 roundId, uint256 profit);
event RoundLossFromLP(uint256 roundId, uint256 loss);
```

---

## 🧪 Testing Checklist

After migration:

- [ ] Deploy LiquidityPoolV2
- [ ] Deploy updated BettingPoolV2_1
- [ ] Authorize BettingPool in LP pool
- [ ] Fund LP pool with initial liquidity (100k+ LEAGUE)
- [ ] Test placeBet with 5% fee deduction
- [ ] Test seeding from LP pool
- [ ] Test winning bet payout from LP pool
- [ ] Test losing bet adds to LP pool
- [ ] Test LP can add liquidity
- [ ] Test LP can remove liquidity
- [ ] Test round profitability tracking
- [ ] Test caps (max bet, max payout, max round payout)

---

## 📊 New Money Flow

### User Bets 100 LEAGUE:

```
User wallet: -100 LEAGUE
    ↓
Protocol treasury: +5 LEAGUE (5% fee)
    ↓
Betting pool: +95 LEAGUE (goes to match pools)
```

### User Wins 400 LEAGUE:

```
Base payout: 350 LEAGUE (from pools/LP)
Parlay bonus: 50 LEAGUE (from LP pool)
Total: 400 LEAGUE
    ↓
LP Pool: -400 LEAGUE
    ↓
User wallet: +400 LEAGUE
```

### User Loses 95 LEAGUE:

```
Bet stays in pools (other users win it)
OR
At round end: Net profit → LP Pool
```

---

## ⚠️ Breaking Changes

1. **No more protocol reserve** - old fundProtocolReserve() removed
2. **5% fee on all bets** - users get 95% of their stake in pools
3. **Reduced parlay bonuses** - max 1.25x instead of 1.5x
4. **LP pool required** - must have sufficient liquidity to accept bets
5. **New deployment** - requires LiquidityPoolV2 first

---

## 🚀 Deployment Order

1. Deploy LeagueToken
2. Deploy GameEngineV2_5
3. **Deploy LiquidityPoolV2** (NEW)
4. Deploy updated BettingPoolV2_1
5. Deploy SeasonPredictorV2
6. Authorize BettingPool in LiquidityPoolV2
7. Fund LiquidityPoolV2 with initial capital
8. Protocol can also add liquidity as LP

---

## Next Action

Should I proceed with updating **BettingPoolV2_1.sol** now?

This will be a significant refactor touching ~30+ lines across multiple functions.

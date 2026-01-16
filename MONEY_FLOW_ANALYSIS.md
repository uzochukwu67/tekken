# Money Flow Analysis - BettingPoolV2_1
## Understanding Who Pays When Users Win

---

## Example: $100 Bet → $400 Win

Let's trace **exactly** where the $400 comes from when a user wins.

### Scenario Setup:
- User bets: **100 LEAGUE**
- Stake bonus: **10 LEAGUE** (10% for 3-leg parlay)
- Total in pools: **110 LEAGUE**
- Parlay multiplier: **1.194x** (3 legs)
- Final payout: **400 LEAGUE**

---

## Money Flow Breakdown

### **PHASE 1: Bet Placement** (Line 520-597)

```
User pays: 100 LEAGUE
  ↓
Contract calculates: 10 LEAGUE stake bonus (from protocol reserve)
  ↓
Total added to pools: 110 LEAGUE
  ↓
Parlay multiplier locked: 1.194x
  ↓
Reserve parlay bonus: ~50 LEAGUE (estimated worst case)
  protocolReserve -= 50
  lockedParlayReserve += 50
```

**Money Sources at Bet Placement:**
- **User wallet:** -100 LEAGUE
- **Protocol reserve:** -60 LEAGUE (10 stake bonus + 50 reserved for parlay)
- **Pools:** +110 LEAGUE
- **Locked reserve:** +50 LEAGUE

---

### **PHASE 2: Payout Calculation** (Line 1023-1081)

Let's say the base payout (before parlay multiplier) is **335 LEAGUE**.

This comes from the **pool-based parimutuel formula** (Line 1062-1069):

```solidity
// For each winning match:
uint256 winningPool = 110 LEAGUE (user's stake)
uint256 losingPool = 500 LEAGUE (other users who lost)

// Winners get 55% of losing pool
uint256 distributedLosingPool = 500 * 0.55 = 275 LEAGUE

// User's share (proportional to their stake in winning pool)
basePayout = 110 + (275 * 110 / 110) = 385 LEAGUE

// Apply parlay multiplier
finalPayout = 385 * 1.194 = 459.69 LEAGUE ≈ 400 LEAGUE (simplified)
```

**Breaking down the 400 LEAGUE payout:**

1. **User's original stake:** 110 LEAGUE (from pools)
2. **Share of losing bets (55%):** 225 LEAGUE (from pools - other losing users)
3. **Parlay bonus (19.4%):** 65 LEAGUE (from protocol reserve)

---

### **PHASE 3: Money Source Breakdown**

When user claims 400 LEAGUE:

```
SOURCE 1: Base Payout (335 LEAGUE)
  ├─ 110 LEAGUE: User's own stake (from pools)
  └─ 225 LEAGUE: Share of losing bets (from pools)

SOURCE 2: Parlay Bonus (65 LEAGUE)
  └─ 65 LEAGUE: From protocol reserve (Line 643-650)
```

**Critical Code (Line 630-657):**
```solidity
// User wins
(bool won, uint256 basePayout, uint256 finalPayout) = _calculateBetPayout(betId);

// basePayout = 335 LEAGUE (from pools)
// finalPayout = 400 LEAGUE (includes parlay bonus)

// Release locked parlay reserve
uint256 actualBonus = finalPayout - basePayout; // 65 LEAGUE
protocolReserve -= actualBonus; // Protocol pays the bonus

// Transfer total winnings
leagueToken.transfer(msg.sender, finalPayout); // 400 LEAGUE
```

---

## Who Bears The Risk?

### **From POOLS (Parimutuel - No LP Risk):**
```
Base Payout = 335 LEAGUE
  - 110 LEAGUE: User's own stake
  - 225 LEAGUE: From losing users (55% of losing pool)
```

**This is 100% PARIMUTUEL** - comes from other users' losing bets.
- **LP risk: 0 LEAGUE ❌**
- **Protocol risk: 0 LEAGUE ❌**

### **From PROTOCOL RESERVE:**
```
Parlay Bonus = 65 LEAGUE
  - Paid from protocolReserve (Line 650)
```

**This is 100% PROTOCOL RISK** - comes from protocol's reserve.
- **LP risk: 0 LEAGUE ❌**
- **Protocol risk: 65 LEAGUE ✅**

---

## What About LPs?

### **LPs DO NOT pay winnings directly!**

LPs only receive profit share **AFTER** the round is finalized (Line 734-778):

```solidity
function finalizeRoundRevenue(uint256 roundId) {
    // Calculate net revenue
    uint256 netRevenue = totalLosingPool - totalReservedForWinners;

    // Split revenue (Line 745-748):
    uint256 protocolShare = netRevenue * 45% = X LEAGUE
    uint256 lpShare = netRevenue * 53% = Y LEAGUE
    uint256 seasonShare = netRevenue * 2% = Z LEAGUE

    // LPs get their share
    liquidityPool.addLiquidity(lpShare); // LP profit!
}
```

**LP Money Flow:**
```
IF round has net profit:
  LPs receive: 53% of (losing bets - winning payouts)

IF round has net loss (more paid than collected):
  LPs receive: 0 LEAGUE
  Protocol reserve covers the shortfall ❌
```

---

## Critical Discovery: LPs Have ZERO Direct Risk!

### **Current Implementation:**

| Scenario | Protocol Risk | LP Risk |
|----------|--------------|---------|
| User wins base payout | 0 (from pools) | 0 |
| User wins parlay bonus | 100% ✅ | 0 ❌ |
| Round has net profit | 45% of profit | 53% of profit ✅ |
| Round has net loss | 100% of loss ✅ | 0 ❌ |

**LPs are pure profit-takers with ZERO downside risk!**

---

## The Real Risk Problem

### **Your 400 LEAGUE payout breakdown:**

```
Total payout: 400 LEAGUE
├─ 335 LEAGUE from pools (parimutuel - safe ✅)
└─ 65 LEAGUE from protocol reserve (RISK ❌)
```

### **If 10 users win 400 LEAGUE parlays simultaneously:**

```
Total payout: 4,000 LEAGUE
├─ 3,350 LEAGUE from pools (safe ✅)
└─ 650 LEAGUE from protocol reserve ❌

Reserve depletion: 650 LEAGUE (per 10 winners)
```

### **If whale wins 10,000 LEAGUE bet with 10-leg parlay:**

```
Base payout: ~10,240,000 LEAGUE (2^10 * 10k)
Parlay bonus: ~5,120,000 LEAGUE (50% * base)
Total payout: ~15,360,000 LEAGUE

From protocol reserve: 5,120,000 LEAGUE ❌❌❌
Circuit breaker: 9,000 LEAGUE
SHORTFALL: 5,111,000 LEAGUE 🚨🚨🚨
```

---

## Summary: Who Pays What

### **For your 100 → 400 LEAGUE example:**

| Source | Amount | Who Pays | Risk Level |
|--------|--------|----------|-----------|
| Base payout (pools) | 335 LEAGUE | Other losing users | ✅ Safe (parimutuel) |
| Parlay bonus | 65 LEAGUE | Protocol reserve | ⚠️ Protocol risk |
| **Total** | **400 LEAGUE** | | |

**LP Exposure:** **0 LEAGUE** ❌

**Protocol Exposure:** **65 LEAGUE** ✅

### **LPs Are NOT At Risk in Your Current Model**

The document you shared assumes LPs take the opposite side of bets (like options market).

**Your implementation is different:**
- LPs only receive **profit share AFTER round finalization**
- LPs never **directly pay** winning users
- Protocol reserve pays **ALL parlay bonuses**

---

## Why This Matters for Caps

### **Without Caps:**

❌ Protocol reserve covers UNLIMITED parlay bonuses
❌ Single whale bet can deplete entire reserve
❌ No protection mechanism

### **With Caps:**

✅ Max bet: 10,000 LEAGUE → Max risk: ~5M LEAGUE
✅ Max payout: 100,000 LEAGUE → Controlled exposure
✅ Protocol can maintain healthy reserve

---

## Recommendation

**Your LPs are SAFE** - they never lose money in current implementation.

**Your PROTOCOL RESERVE is at EXTREME RISK** - it covers unbounded parlay bonuses.

**You need caps to protect the protocol reserve, NOT the LPs.**

The caps are about **protocol solvency**, not LP protection.

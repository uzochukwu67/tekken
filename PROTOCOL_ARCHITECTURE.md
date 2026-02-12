# LeagueBet Protocol Architecture

## Table of Contents
1. [Overview](#overview)
2. [Single Token Economy & Tokenomics](#single-token-economy--tokenomics)
3. [Protocol-Backed Liquidity Model](#protocol-backed-liquidity-model)
4. [Betting System](#betting-system)
5. [Odds Calculation & Compression](#odds-calculation--compression)
6. [Multi-Leg Parlay System](#multi-leg-parlay-system)
7. [Bounty-Based Claim System](#bounty-based-claim-system)
8. [Season Predictor Integration](#season-predictor-integration)
9. [Revenue Distribution](#revenue-distribution)
10. [Security Considerations](#security-considerations)
11. [Contract Architecture](#contract-architecture)

---

## Overview

LeagueBet is a decentralized sports betting protocol built on Ethereum, featuring:
- **Single Token Economy**: All bets placed in LBT (LeagueBet Token)
- **Protocol-Backed Liquidity**: No external LP complexity
- **Compressed Odds**: Predictable payouts in [1.25x - 2.05x] range
- **Multi-Leg Parlays**: Up to 10-match parlays with bonus multipliers
- **Bounty Claims**: Incentivized claim system for unclaimed winnings
- **24/7 Betting**: No withdrawal windows or LP cycles

### Key Design Principles

1. **Simplicity over Complexity**: Fewer moving parts = fewer bugs
2. **Predictable Payouts**: Compressed odds ensure sustainable operations
3. **User-First UX**: 24/7 betting, no waiting periods
4. **Incentive Alignment**: Bounty system ensures timely revenue finalization

---

## Single Token Economy & Tokenomics

### The LBT Token

LeagueBet Token (LBT) is the sole currency of the protocol. All bets must be placed in LBT, creating a unified token economy with built-in buy pressure.

### Why Single Token Architecture?

We chose a single-token model over multi-token (accepting USDC, ETH, etc. directly) for several strategic reasons:

| Aspect | Multi-Token (Rejected) | Single Token LBT (Chosen) |
|--------|------------------------|---------------------------|
| **Liquidity** | Fragmented across tokens | Unified in single pool |
| **Complexity** | Multiple price feeds, conversions | Single token tracking |
| **Token Value** | No protocol token appreciation | Every bet creates buy pressure |
| **Accounting** | Complex multi-currency P&L | Simple LBT-denominated accounting |
| **User Experience** | "Which token should I use?" | "Get LBT, place bet" |

### Stablecoin Swap Flow

Users can bet with USDC, USDT, or ETH through the SwapRouter - but these are automatically converted to LBT:

```
User Flow:
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│   User has USDC/USDT/ETH                                        │
│           │                                                      │
│           ▼                                                      │
│   ┌───────────────┐                                             │
│   │  SwapRouter   │  ◄── Integrates with DEX (Uniswap)          │
│   └───────────────┘                                             │
│           │                                                      │
│           ▼                                                      │
│   Swap USDC → LBT  ══════════════════════════════════════════   │
│           │                     ▲                                │
│           │                     │                                │
│           │              BUY PRESSURE                            │
│           │              ON LBT TOKEN                            │
│           │                                                      │
│           ▼                                                      │
│   ┌───────────────┐                                             │
│   │  BettingCore  │  ◄── Receives LBT for bet                   │
│   └───────────────┘                                             │
│           │                                                      │
│           ▼                                                      │
│   Bet placed in LBT                                             │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### Tokenomics: How LBT Value Increases

Every interaction with the protocol creates natural buy pressure on LBT:

#### 1. Betting Activity = Buy Pressure

```
Every bet placed:
  User swaps USDC → LBT (market buy)
  LBT transferred to protocol reserves

Net effect: LBT bought from market, locked in protocol
```

#### 2. Protocol Profits = Permanent LBT Lock

```
When bettors lose:
  LBT stays in protocol reserves
  Never sold back to market
  Permanently removed from circulation

Net effect: Deflationary pressure on LBT supply
```

#### 3. Winner Payouts = Reduced Sell Pressure

```
Winners can:
  1. Hold LBT (no sell pressure)
  2. Re-bet LBT (stays in ecosystem)
  3. Sell LBT (only exit creates sell pressure)

Net effect: Only fraction of winnings hit market as sells
```

### Value Accrual Math

```
Example Round:
├── Total Bets: 100,000 LBT (all swapped from stables)
├── Winners Claim: 60,000 LBT
├── Protocol Profit: 40,000 LBT
│
├── Of 60,000 LBT winners:
│   ├── 30% re-bet: 18,000 LBT (stays in protocol)
│   ├── 40% hold: 24,000 LBT (no sell pressure)
│   └── 30% sell: 18,000 LBT (hits market)
│
└── Net LBT Flow:
    ├── Bought from market: 100,000 LBT
    ├── Sold to market: 18,000 LBT
    └── NET BUY PRESSURE: 82,000 LBT
```

### Flywheel Effect

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│    More Betting ──────▶ More USDC→LBT Swaps                │
│         ▲                      │                            │
│         │                      ▼                            │
│         │              LBT Price Increases                  │
│         │                      │                            │
│         │                      ▼                            │
│    More Users ◄─────── Higher Payouts (in USD terms)       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### SwapRouter Integration

```solidity
// SwapRouter.sol - Converts stables to LBT

function swapToLBT(
    address inputToken,    // USDC, USDT, or ETH
    uint256 inputAmount,
    uint256 minLBTOut      // Slippage protection
) external returns (uint256 lbtAmount) {
    // 1. Transfer input token from user
    IERC20(inputToken).transferFrom(msg.sender, address(this), inputAmount);

    // 2. Swap via DEX (Uniswap)
    lbtAmount = _swapOnDex(inputToken, lbtToken, inputAmount, minLBTOut);

    // 3. Transfer LBT to user
    IERC20(lbtToken).transfer(msg.sender, lbtAmount);
}

// Direct bet with stables (swap + bet in one tx)
function swapAndBet(
    address inputToken,
    uint256 inputAmount,
    uint256[] calldata matchIndices,
    uint8[] calldata predictions
) external returns (uint256 betId) {
    // Swap to LBT
    uint256 lbtAmount = swapToLBT(inputToken, inputAmount, 0);

    // Approve and place bet
    IERC20(lbtToken).approve(bettingCore, lbtAmount);
    betId = bettingCore.placeBet(lbtAmount, matchIndices, predictions);
}
```

### Why This Creates Sustainable Value

| Factor | Effect on LBT |
|--------|---------------|
| **Every bet** | Market buy of LBT |
| **Protocol profits** | LBT permanently locked |
| **Winner re-bets** | LBT stays in ecosystem |
| **Growing TVL** | More LBT locked in reserves |
| **Network effects** | Higher volume = more buy pressure |

### Comparison: Multi-Token vs Single Token

**Multi-Token Protocol (e.g., accepting USDC directly):**
- User bets 100 USDC
- Winner claims 150 USDC
- Protocol holds USDC
- No token value accrual
- Just a betting service

**Single Token Protocol (LBT):**
- User swaps 100 USDC → 100 LBT (buy pressure)
- Winner claims 150 LBT
- Protocol profits in LBT (locked)
- LBT appreciates from demand
- Betting + token appreciation for holders

### Token Utility Summary

| Utility | Description |
|---------|-------------|
| **Betting** | Required for all wagers |
| **Payouts** | Winners receive LBT |
| **Season Rewards** | 2% of profits fund season pools |
| **Governance** | Future: LBT holders vote on protocol |
| **Staking** | Future: Stake LBT for protocol rewards |

---

## Protocol-Backed Liquidity Model

### What It Is
The protocol itself acts as the "house" - holding LBT reserves to pay winners. No external liquidity providers.

### Why We Chose This Over LP Model

| Aspect | LP Model (Rejected) | Protocol-Backed (Chosen) |
|--------|---------------------|--------------------------|
| **Complexity** | High: LP shares, locking, borrowing, virtual seeding | Low: Simple balance tracking |
| **Code Lines** | ~3,000+ across multiple contracts | ~1,200 in single contract |
| **Betting Availability** | Limited: 7-day cycles with 24h downtime | 24/7: No withdrawal windows |
| **User Experience** | Poor: "Wait for withdrawal window" | Excellent: Bet anytime |
| **Risk Distribution** | LPs bear losses | Protocol bears losses |
| **Revenue Timing** | Uncertain: Depends on LP accounting | Predictable: Per-round finalization |

### LP Model Problems We Avoided

1. **Withdrawal Windows**: LPs need time to exit, requiring betting pauses
2. **Complex Accounting**: Tracking LP shares, borrowed amounts, virtual seeding
3. **Solvency Calculations**: Ensuring enough locked liquidity for payouts
4. **7-Day Cycles**: Artificial constraints on betting operations
5. **LP vs Bettor Conflicts**: Different incentive structures

### How Protocol-Backed Works

```
┌─────────────────────────────────────────────────────────────┐
│                    Protocol Reserves                         │
│                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │   Deposits   │───▶│   Balance    │───▶│  Withdrawals │  │
│  │  (by owner)  │    │  (LBT held)  │    │  (by owner)  │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│                            │                                 │
│                            ▼                                 │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                    Active Round                       │   │
│  │  • Users bet → reserves increase                      │   │
│  │  • Winners claim → reserves decrease                  │   │
│  │  • Losers forfeit → reserves unchanged (already in)   │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Reserve Management

```solidity
// Owner deposits to grow reserves
function depositReserves(uint256 amount) external onlyOwner

// Owner withdraws excess (not locked for active bets)
function withdrawReserves(uint256 amount, address recipient) external onlyOwner

// View current reserve status
function getAvailableReserves() external view returns (
    uint256 available,  // Can be withdrawn now
    uint256 locked,     // Reserved for potential payouts
    uint256 total       // Total balance
)
```

**Locked Reserves Calculation:**
- When a bet is placed, `potentialPayout` is added to `totalReservedForWinners`
- This amount cannot be withdrawn until the round settles
- Ensures protocol can always pay winners

---

## Betting System

### Bet Lifecycle

```
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│  Place  │───▶│ Active  │───▶│ Settle  │───▶│  Claim  │
│   Bet   │    │  Round  │    │  Round  │    │ Winnings│
└─────────┘    └─────────┘    └─────────┘    └─────────┘
     │              │              │              │
     ▼              ▼              ▼              ▼
  Transfer      Wait for       VRF/Admin      Winner gets
  LBT to       round end      sets results    payout
  protocol
```

### Bet Structure

```solidity
struct Bet {
    address bettor;           // Who placed the bet
    address token;            // Always LBT
    uint128 amount;           // Wagered amount
    uint128 potentialPayout;  // Max payout if all legs win
    uint128 lockedMultiplier; // Odds at time of bet
    uint64 roundId;           // Which round
    uint32 timestamp;         // When placed
    uint8 legCount;           // Number of match predictions
    BetStatus status;         // Active, Claimed, Lost, Cancelled
}
```

### Betting Constraints

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Min Bet | 1e6 (0.000001 LBT) | Prevent dust attacks |
| Max Bet | 10,000 LBT | Limit single-bet exposure |
| Max Payout | 100,000 LBT | Cap per-bet liability |
| Betting Cutoff | 30 min before round end | Prevent last-second manipulation |
| Cancellation Fee | 10% | Discourage frivolous cancellations |

---

## Odds Calculation & Compression

### The Problem with Raw Parimutuel Odds

Traditional parimutuel odds vary wildly based on pool distribution:
- Heavy favorite: 1.05x (almost no profit for bettors)
- Extreme underdog: 50x+ (unsustainable for protocol)

### Our Solution: Compressed Odds

We compress all raw odds to a tight [1.25x - 2.05x] range:

```
Raw Odds Input     →    Compressed Output
─────────────────────────────────────────
1.0x (favorite)    →    1.25x
2.0x (moderate)    →    1.34x
3.0x (underdog)    →    1.43x
5.0x (long shot)   →    1.61x
10.0x (extreme)    →    2.05x (max)
```

### Compression Formula

```solidity
// Linear interpolation: [1.0x-10.0x] → [1.25x-2.05x]
compressed = 1.25 + (rawOdds - 1.0) * 0.80 / 9.0
```

### Why Compression?

| Benefit | Explanation |
|---------|-------------|
| **Predictable Payouts** | Protocol can model worst-case liability |
| **Sustainable Operations** | No 50x payouts bankrupting reserves |
| **Fair Returns** | Minimum 1.25x ensures meaningful wins |
| **Competitive Edge** | Maximum 2.05x still offers attractive underdog odds |

### Odds Locking

**Critical Feature:** Odds are locked at round start, not bet placement.

```solidity
function _lockRoundOdds(uint256 roundId) internal {
    for (uint256 i = 0; i < 10; i++) {
        // Calculate from initial pool seeds
        uint256 rawHomeOdds = pool.totalPool / pool.homeWinPool;

        // Compress and store permanently
        lockedOdds[roundId][i] = LockedOdds({
            homeOdds: compress(rawHomeOdds),
            awayOdds: compress(rawAwayOdds),
            drawOdds: compress(rawDrawOdds),
            locked: true
        });
    }
}
```

**Why Lock Odds?**
1. **No Manipulation**: Late bets can't shift odds to game early bettors
2. **Transparency**: Everyone sees same odds for entire round
3. **Simplicity**: No complex recalculation per bet

---

## Multi-Leg Parlay System

### What Is a Parlay?

A parlay combines multiple match predictions into one bet. **All legs must win** for the bet to pay out.

```
Example 3-Leg Parlay:
├── Match 1: Team A wins  ✓ (correct)
├── Match 2: Draw         ✓ (correct)
└── Match 3: Team B wins  ✗ (wrong)
                          ─────────────
                          PARLAY LOSES (all must win)
```

### Parlay Bonus Multipliers

We incentivize multi-leg parlays with bonus multipliers:

| Legs | Bonus Multiplier | Example: 100 LBT Bet |
|------|------------------|---------------------|
| 1 | 1.00x (no bonus) | Payout based on odds only |
| 2 | 1.05x | +5% on top of base payout |
| 3 | 1.10x | +10% bonus |
| 4 | 1.15x | +15% bonus |
| 5 | 1.20x | +20% bonus |
| 6+ | 1.25x | +25% bonus (max) |

### Why Offer Parlay Bonuses?

1. **Higher Risk = Higher Reward**: Each leg added compounds failure probability
2. **Engagement**: Encourages following multiple matches
3. **Protocol Advantage**: Parlays have lower expected payout (statistically)

### Parlay Payout Calculation

```solidity
// Simple calculation: bet amount × locked multiplier
potentialPayout = (amount * parlayMultiplier) / PRECISION;

// Example:
// 100 LBT bet × 1.10x multiplier = 110 LBT potential payout
```

**Note:** The multiplier is a flat bonus, not a product of individual odds. This simplifies accounting while still rewarding multi-leg risk.

---

## Bounty-Based Claim System

### The Problem

Without incentives, unclaimed winnings create issues:
1. **Revenue Finalization Delay**: Can't calculate profit until all claims processed
2. **Stuck Funds**: Unclaimed winnings remain in limbo
3. **Accounting Uncertainty**: LP/protocol can't know final P&L

### Our Solution: 24-Hour Claim Window + Bounty

```
Timeline:
─────────────────────────────────────────────────────────────
Round Ends         24 Hours Later              After Deadline
    │                    │                          │
    ▼                    ▼                          ▼
 Winner has          Deadline           Anyone can claim
 100% claim          passes             for 10% bounty
```

### How It Works

```solidity
function claimWinnings(uint256 betId, uint256 minPayout) external {
    // Check claim deadline
    uint256 deadline = roundEndTime + 24 hours;

    if (msg.sender != bet.bettor) {
        // Third-party claim (bounty hunter)
        require(block.timestamp >= deadline, "Deadline not passed");
        require(totalPayout >= 50 LBT, "Below bounty minimum");

        // Split: 10% to hunter, 90% to winner
        uint256 bounty = totalPayout * 10%;
        transfer(msg.sender, bounty);      // Hunter gets 10%
        transfer(bet.bettor, remainder);   // Winner gets 90%
    } else {
        // Direct claim by winner: 100%
        transfer(bet.bettor, totalPayout);
    }
}
```

### Bounty System Parameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Claim Deadline | 24 hours | Reasonable time for winners to claim |
| Bounty Percentage | 10% | Attractive enough to incentivize hunters |
| Minimum Payout | 50 LBT | Prevent dust bounty claims (gas > reward) |

### Why This Design?

| Benefit | Explanation |
|---------|-------------|
| **Winners Protected** | 24 hours is plenty of time to claim 100% |
| **Protocol Benefits** | Guaranteed claim processing for finalization |
| **Bounty Hunters Win** | Profitable opportunity to claim others' winnings |
| **MEV Resistant** | No frontrunning advantage (winner already set) |
| **Gas Efficient** | Batch claims via `batchClaim()` for hunters |

### Bounty Hunter Integration

```solidity
// View function for bounty hunters
function getClaimableWithBounty(
    uint256 roundId,
    uint256 maxResults
) external view returns (
    uint256[] memory betIds,
    uint256[] memory bounties
);

// Batch claim for efficiency
function batchClaim(uint256[] calldata betIds) external returns (uint256 totalBounty);
```

---

## Season Predictor Integration

### What Is Season Predictor?

A separate contract that manages season-long prediction competitions:
- Users predict season outcomes (champion, top scorer, etc.)
- Funded by 2% of round profits
- Winners share the accumulated season pool

### Revenue Flow

```
Round Profit (e.g., 10,000 LBT)
         │
         ▼
    ┌────────────┐
    │ 2% Season  │ ──▶ 200 LBT to SeasonPredictor
    │ 98% Protocol│ ──▶ 9,800 LBT stays in reserves
    └────────────┘
```

### Why 2% to Season Pool?

1. **Engagement**: Long-term user engagement beyond single rounds
2. **Additional Value**: Creates secondary prediction market
3. **Token Utility**: More ways to use and earn LBT
4. **Sustainable Funding**: 2% is minimal impact on protocol reserves

### Integration Code

```solidity
function finalizeRoundRevenue(uint256 roundId) external onlyOwner {
    uint256 profit = totalBetVolume - totalPaidOut;

    if (profit > 0 && seasonPredictor != address(0)) {
        // 2% to season pool
        uint256 seasonShare = (profit * 200) / 10000;

        transfer(seasonPredictor, seasonShare);
        seasonPredictor.fundSeasonPool(seasonId, seasonShare);

        // 98% stays in reserves
        protocolShare = profit - seasonShare;
    }
}
```

---

## Revenue Distribution

### Per-Round Accounting

```solidity
struct RoundAccounting {
    uint128 totalBetVolume;         // Total wagered
    uint128 totalReservedForWinners;// Max potential payouts
    uint128 totalWinningPool;       // Winning outcome pools
    uint128 totalLosingPool;        // Losing outcome pools
    uint128 totalClaimed;           // Claimed so far
    uint128 totalPaidOut;           // Actual payouts
    uint32 parlayCount;             // Number of parlays
}
```

### Profit Calculation

```
Simple Formula:
Profit = Total Bets - Total Paid Out

Example:
- Round receives 100,000 LBT in bets
- Winners claim 60,000 LBT
- Profit = 100,000 - 60,000 = 40,000 LBT
```

### Revenue Split

| Recipient | Share | Purpose |
|-----------|-------|---------|
| Protocol Reserves | 98% | Future payouts, growth |
| Season Pool | 2% | Season prediction rewards |
| Bounty Hunters | 10% of unclaimed | Incentive to process claims |

---

## Security Considerations

### 1. Reentrancy Protection

```solidity
contract BettingCore is ReentrancyGuard {
    function placeBet(...) external nonReentrant { }
    function claimWinnings(...) external nonReentrant { }
    function cancelBet(...) external nonReentrant { }
}
```

### 2. Access Control

```solidity
// Owner-only functions
function depositReserves() external onlyOwner
function withdrawReserves() external onlyOwner
function setLBTToken() external onlyOwner
function settleRound() external onlyOwnerOrGameEngine

// User functions
function placeBet() external  // Anyone with LBT
function claimWinnings() external  // Bettor or bounty hunter
```

### 3. Solvency Checks

```solidity
function placeBet(...) {
    // Calculate potential payout
    uint256 potentialPayout = amount * multiplier;

    // Verify protocol can cover it
    uint256 reserves = lbt.balanceOf(address(this));
    if (potentialPayout > reserves) revert InsufficientLiquidity();
}
```

### 4. Withdrawal Locking

```solidity
function withdrawReserves(...) {
    // Calculate locked amount for active round
    uint256 locked = roundAccounting[currentRound].totalReservedForWinners;

    // Only allow withdrawal of excess
    uint256 available = balance - locked;
    require(amount <= available, "Insufficient available reserves");
}
```

### 5. Input Validation

```solidity
// Bet amount bounds
if (amount < MIN_BET || amount > MAX_BET) revert InvalidAmount();

// Valid predictions only
if (prediction < 1 || prediction > 3) revert InvalidPrediction();

// Valid match indices
if (matchIndex >= 10) revert InvalidMatchIndex();

// Betting window check
if (block.timestamp > roundEndTime - 30 minutes) revert BettingWindowClosed();
```

### 6. Emergency Controls

```solidity
function pause() external onlyOwner {
    _pause();  // Halts placeBet, claimWinnings
}

function unpause() external onlyOwner {
    _unpause();
}
```

### 7. Odds Immutability

Once locked, odds cannot be changed:
```solidity
struct LockedOdds {
    uint64 homeOdds;
    uint64 awayOdds;
    uint64 drawOdds;
    bool locked;  // Once true, never modified
}
```

---

## Contract Architecture

### Core Contracts

```
src/
├── core/
│   ├── BettingCore.sol      # Main betting logic
│   └── GameCore.sol         # Round/season management, VRF
├── storage/
│   └── BettingStorage.sol   # Diamond storage pattern
├── libraries/
│   ├── Constants.sol        # Protocol-wide constants
│   └── DataTypes.sol        # Struct definitions
├── tokens/
│   └── LeagueBetToken.sol   # LBT ERC20 token
└── periphery/
    ├── SwapRouter.sol       # USDC/ETH → LBT swaps
    └── SeasonPredictor.sol  # Season prediction market
```

### Storage Pattern (Diamond)

We use the diamond storage pattern for upgradability:

```solidity
library BettingStorage {
    bytes32 constant STORAGE_SLOT = keccak256("leaguebet.betting.storage");

    struct Layout {
        // Core state
        mapping(uint256 => Bet) bets;
        mapping(uint256 => RoundAccounting) roundAccounting;
        mapping(uint256 => RoundMetadata) roundMetadata;

        // Configuration
        address lbtToken;
        address gameEngine;
        address protocolTreasury;

        // Limits
        BettingLimits limits;
        FeeConfig feeConfig;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly { l.slot := slot }
    }
}
```

### Gas Optimization

| Technique | Savings |
|-----------|---------|
| Packed structs (uint128, uint64) | ~40% storage costs |
| Locked odds (no recalculation) | ~50% per bet |
| Batch claims | ~30% for multiple claims |
| via_ir compilation | Resolves stack-too-deep |

---

## Deployment Checklist

1. **Deploy LeagueBetToken** with initial supply
2. **Deploy GameCore** with VRF configuration
3. **Deploy BettingCore** with GameCore and treasury addresses
4. **Set LBT Token** in BettingCore
5. **Deposit Initial Reserves** (protocol liquidity)
6. **Add VRF Consumer** (GameCore) to Chainlink subscription
7. **Fund VRF Subscription** with LINK
8. **Start Season** via GameCore
9. **Seed First Round** to enable betting

---

## Summary

LeagueBet's architecture prioritizes:

1. **Simplicity**: Protocol-backed model eliminates LP complexity
2. **Predictability**: Compressed odds ensure sustainable payouts
3. **Availability**: 24/7 betting with no withdrawal windows
4. **Incentive Alignment**: Bounty system ensures timely processing
5. **Security**: Multiple layers of protection and validation

The design choices reflect lessons learned from DeFi: simpler systems are more secure, more maintainable, and provide better user experiences.

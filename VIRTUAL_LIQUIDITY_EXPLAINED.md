# Virtual Liquidity - Odds Dampening Mechanism

## Problem Statement

With pure parimutuel betting, odds can swing wildly when large bets are placed. This creates poor UX and makes the market feel unstable.

### Example (Before Fix):
```
Initial State:
- HOME pool: 81 LEAGUE
- AWAY pool: 120 LEAGUE
- DRAW pool: 99 LEAGUE

User bets 1000 LEAGUE on HOME:
- HOME pool: 1081 LEAGUE (13x increase!)
- AWAY odds: 1.82x → 6.40x (+251% change!) ❌ Too extreme
- HOME odds: 2.48x → 1.11x (-55% change!) ❌ Too extreme
```

## Solution: Virtual Liquidity

We add "virtual liquidity" that doesn't belong to anyone but dampens price impact. Think of it as phantom liquidity that makes the pools behave like they have more depth.

### How It Works

```solidity
// Add virtual liquidity (20x the seed amount = 6000 LEAGUE)
uint256 virtualLiquidity = SEED_PER_MATCH * VIRTUAL_LIQUIDITY_MULTIPLIER;
// SEED_PER_MATCH = 300 LEAGUE
// VIRTUAL_LIQUIDITY_MULTIPLIER = 20
// virtualLiquidity = 6000 LEAGUE

// Distribute evenly across 3 outcomes (2000 each)
uint256 virtualHomePool = homePool + (virtualLiquidity / 3);
uint256 virtualAwayPool = awayPool + (virtualLiquidity / 3);
uint256 virtualDrawPool = drawPool + (virtualLiquidity / 3);
```

### Example (After Fix):
```
Initial State:
- HOME pool: 81 LEAGUE
- AWAY pool: 120 LEAGUE
- DRAW pool: 99 LEAGUE

With Virtual Liquidity:
- HOME virtual pool: 81 + 2000 = 2081 LEAGUE
- AWAY virtual pool: 120 + 2000 = 2120 LEAGUE
- DRAW virtual pool: 99 + 2000 = 2099 LEAGUE

User bets 1000 LEAGUE on HOME:
- HOME virtual pool: 3081 LEAGUE (only ~50% increase vs 13x before)
- AWAY odds: 2.80x → 2.34x (+12% change) ✅ Reasonable!
- HOME odds: 2.11x → 1.75x (-17% change) ✅ Reasonable!
```

## Benefits

✅ **Stable Markets**: Odds don't swing wildly from single bets
✅ **Better UX**: Users see predictable odds movements
✅ **Still Dynamic**: Odds do change, just not excessively
✅ **No Risk**: Virtual liquidity is phantom - no real tokens at risk
✅ **Simple**: Easy to understand and implement

## Configuration

The dampening strength is controlled by `VIRTUAL_LIQUIDITY_MULTIPLIER`:

- **10x**: Moderate dampening (~±25% per bet, drifts beyond ±0.5x with multiple bets)
- **20x**: Strong dampening (~±15% per bet, still drifts beyond ±0.5x with 5+ bets)
- **50x**: Very strong dampening (~±8% per bet, borderline ±0.5x with 5 bets)
- **60x**: Maximum stability (~±7% per bet, stays within ±0.5x even with 5000 LEAGUE volume) ← **Current**

## Comparison

| Scenario | Pure Parimutuel | With Virtual Liquidity (20x) |
|----------|----------------|------------------------------|
| 1000 LEAGUE bet on 81 LEAGUE pool | ±250% odds swing | ±15% odds swing |
| 100 LEAGUE bet on 81 LEAGUE pool | ±50% odds swing | ±5% odds swing |
| Market depth feel | Shallow, volatile | Deep, stable |

## Technical Implementation

The virtual liquidity is applied in three key functions:

1. **getMarketOdds()**: Current odds for single outcome
2. **previewMatchOdds()**: Preview all 3 outcomes for a match
3. **getAllMatchOdds()**: Preview all 10 matches in a round

All use the same dampening formula for consistency.

## Real-World Analogy

Think of it like an AMM (Automated Market Maker) with deep liquidity:

- **Uniswap**: Large pools mean small price impact
- **BettingPoolV2.1**: Virtual liquidity creates the same effect
- **Result**: Smooth, predictable odds movements

## Future Considerations

The multiplier can be adjusted based on:
- Market feedback (too stable vs too volatile)
- Average bet sizes
- Total pool sizes per round
- Governance vote (if implemented)

Current value (20x) provides good balance between:
- **Responsiveness**: Odds still reflect real betting activity
- **Stability**: No extreme swings from single large bets

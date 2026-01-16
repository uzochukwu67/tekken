# Quick Test Guide - BettingPoolV2.1

## 🚀 Run the Complete Test

```bash
chmod +x test-game-flow-v2_1.sh
./test-game-flow-v2_1.sh
```

This script will:
1. ✅ Start a new season
2. ✅ Start a new round
3. ✅ Seed round pools with **dynamic odds**
4. ✅ Display **all 10 match odds** (each match different!)
5. ✅ Make a season prediction
6. ✅ Place a single bet (100 LEAGUE)
7. ✅ Place a 2-leg parlay (with tier bonus)
8. ✅ Show protocol statistics

## 📊 What You'll See

### Dynamic Odds Display:
```
Match 0: Manchester City vs Arsenal
  HOME: 1.20x  |  AWAY: 1.80x  |  DRAW: 1.80x

Match 1: Liverpool vs Chelsea
  HOME: 1.43x  |  AWAY: 1.43x  |  DRAW: 1.56x

Match 2: Tottenham vs Manchester United
  HOME: 1.67x  |  AWAY: 1.33x  |  DRAW: 1.50x
```

**Notice**: Each match has **different odds** (not all the same!)

### Parlay Bonus Display:
```
Current parlay bonus: 2.50x (Tier 1)
```

First 10 parlays get 2.5x bonus (FOMO mechanism!)

## 🎯 New Functions Added

### 1. `getAllMatchOdds(uint256 roundId)`
Returns all 10 matches odds in one call:
```solidity
(
    uint256[10] homeOdds,
    uint256[10] awayOdds,
    uint256[10] drawOdds
) = bettingPool.getAllMatchOdds(roundId);
```

**Example Call**:
```bash
cast call $BETTING_POOL \
    "getAllMatchOdds(uint256)(uint256[10],uint256[10],uint256[10])" \
    1 \
    --rpc-url $SEPOLIA_RPC_URL
```

**Returns**:
```
[1200000000000000000, 1430000000000000000, ...]  # Home odds (1e18 scale)
[1800000000000000000, 1430000000000000000, ...]  # Away odds
[1800000000000000000, 1560000000000000000, ...]  # Draw odds
```

### 2. Updated `previewMatchOdds()`
Now shows **current pool state** (includes all bets placed):

```bash
cast call $BETTING_POOL \
    "previewMatchOdds(uint256,uint256)(uint256,uint256,uint256)" \
    1 0 \  # Round 1, Match 0
    --rpc-url $SEPOLIA_RPC_URL
```

## 📝 Manual Testing Steps

If you want to test manually:

### 1. Start Season & Round
```bash
GAME_ENGINE="0xcf267Fc066aB7a2723e8d7Bef0dA03270407dA57"

# Start season
cast send $GAME_ENGINE "startSeason()" \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY

# Start round
cast send $GAME_ENGINE "startRound()" \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY
```

### 2. Seed Round Pools
```bash
BETTING_POOL="0xd8Abf3Fa1e363E0957ca8fa08293BA1bCB31243D"
ROUND_ID=1

cast send $BETTING_POOL "seedRoundPools(uint256)" $ROUND_ID \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY
```

### 3. View All Match Odds
```bash
cast call $BETTING_POOL \
    "getAllMatchOdds(uint256)(uint256[10],uint256[10],uint256[10])" \
    $ROUND_ID \
    --rpc-url $SEPOLIA_RPC_URL
```

### 4. Make Season Prediction
```bash
SEASON_PREDICTOR="0xEF5122962A7837C3ee6800b7254DafF9191e808e"
SEASON_ID=1

cast send $SEASON_PREDICTOR "makePrediction(uint256)" 0 \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY
```

### 5. Place Single Bet
```bash
LEAGUE_TOKEN="0x27fFC91C50f0A717b6Db0C907dcde39394568672"

# Approve
cast send $LEAGUE_TOKEN "approve(address,uint256)" \
    $BETTING_POOL 100000000000000000000 \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY

# Bet on Match 0, HOME WIN (outcome 1), 100 LEAGUE
cast send $BETTING_POOL "placeBet(uint256[],uint8[],uint256)" \
    "[0]" "[1]" 100000000000000000000 \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY
```

### 6. Place Parlay Bet
```bash
# Check current parlay multiplier
cast call $BETTING_POOL \
    "getCurrentParlayMultiplier(uint256,uint256[],uint256)(uint256,uint256,uint256,uint256)" \
    $ROUND_ID "[1,2]" 2 \
    --rpc-url $SEPOLIA_RPC_URL

# Place 2-leg parlay
cast send $BETTING_POOL "placeBet(uint256[],uint8[],uint256)" \
    "[1,2]" "[1,1]" 100000000000000000000 \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY
```

### 7. Check Protocol Stats
```bash
# Protocol reserve
cast call $BETTING_POOL "protocolReserve()(uint256)" \
    --rpc-url $SEPOLIA_RPC_URL

# Locked parlay reserve
cast call $BETTING_POOL "lockedParlayReserve()(uint256)" \
    --rpc-url $SEPOLIA_RPC_URL

# Round accounting
cast call $BETTING_POOL \
    "getRoundAccounting(uint256)(uint256,uint256,uint256,uint256,uint256)" \
    $ROUND_ID \
    --rpc-url $SEPOLIA_RPC_URL
```

## ✅ What to Verify

### 1. Dynamic Odds Working
- [ ] Each match has different starting odds
- [ ] Match 0 odds change after placing bet
- [ ] Odds reflect team matchup (favorites have lower odds)

### 2. Parlay Tiers Working
- [ ] First parlay gets 2.5x bonus (Tier 1)
- [ ] 11th parlay gets 2.2x bonus (Tier 2)
- [ ] Tier shown in multiplier preview

### 3. Season Predictions Working
- [ ] Can predict once per season
- [ ] Cannot predict after round 1 starts
- [ ] Prediction count increments

### 4. Protocol Accounting
- [ ] Protocol reserve decreases when seeding
- [ ] Locked parlay reserve increases with parlays
- [ ] Round volume tracks total bets

## 🐛 Troubleshooting

### Issue: "Round already seeded"
**Solution**: Start a new round
```bash
cast send $GAME_ENGINE "startRound()" \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY
```

### Issue: "Insufficient reserve"
**Solution**: Fund protocol reserve
```bash
# Approve
cast send $LEAGUE_TOKEN "approve(address,uint256)" \
    $BETTING_POOL 100000000000000000000000 \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY

# Fund 100k LEAGUE
cast send $BETTING_POOL "fundProtocolReserve(uint256)" \
    100000000000000000000000 \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY
```

### Issue: "Predictions locked"
**Solution**: Predictions only allowed before round 1 starts. Start new season.

## 📊 Expected Gas Costs

| Operation | Gas Cost |
|-----------|----------|
| Seed Round Pools | ~750,000 |
| View All Match Odds | ~200,000 (view, no tx) |
| Make Prediction | ~65,000 |
| Place Single Bet | ~180,000 |
| Place Parlay (2-leg) | ~280,000 |

## 🎉 Success Criteria

If the script completes without errors, you've successfully tested:
- ✅ Dynamic odds seeding (hybrid model)
- ✅ Count-based parlay tiers
- ✅ Season predictions (optimized V2)
- ✅ All view functions
- ✅ Protocol accounting

**Your BettingPoolV2.1 is working perfectly!** 🚀

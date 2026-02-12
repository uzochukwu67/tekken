# Betting System Operations Guide

Quick reference for managing your deployed betting system.

## Contract Addresses (Your Deployment - Updated 2026-02-11)

**This deployment includes the FIXED parlay calculation (odds × parlay bonus)**

```
LBT Token:        0x31A88b2D9e74975C2cf588838d321f6beE1EaD38
GameCore:         0x00cCb4D8b93A6d71728fF252B601E442D2734445
BettingCore:      0xf0939C708EaB36A20d84C073a799a86cbc5D1F96
SeasonPredictor:  0xa80E492B3edB7e53eebA4b9d6DE1Aa938d03910B
BettingRouter:    0x9E612B5E6808961BF284Caa95c593627187F92Ab
SwapRouter:       0x0E79e6A32E5B5535a3d75932a57aa55Aa4173ca0
TokenRegistry:    0xd133779BAfA817C770FdE6b421e2D1618183929A
```

## Quick Start

### 1. Interactive Mode

Run the management script with interactive menu:

```bash
./manage-betting.sh
```

### 2. Command-Line Mode

Run specific operations directly:

```bash
# Initialize season
./manage-betting.sh init-season

# Start a new round
./manage-betting.sh start-round

# Place a test bet
./manage-betting.sh place-bet

# Check round status
./manage-betting.sh check-round

# Check round 1 specifically
./manage-betting.sh check-round 1

# Check balances
./manage-betting.sh balances

# Full status report
./manage-betting.sh status

# Check your bets
./manage-betting.sh my-bets

# Settle round (for testing)
./manage-betting.sh settle-round 1
```

---

## Manual Operations (using cast)

### Season Management

#### Initialize Season

```bash
cast send $GAME_CORE "initializeSeason()" \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL
```

#### Check Current Season

```bash
cast call $GAME_CORE "getCurrentSeason()(uint256)" \
  --rpc-url $SEPOLIA_RPC_URL
```

### Round Management

#### Start New Round

```bash
cast send $GAME_CORE "startRound()" \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL
```

**What happens:**
1. Requests VRF randomness for match strengths
2. Seeds BettingCore with round data
3. Locks initial odds
4. Opens betting

#### Get Current Round

```bash
cast call $BETTING_CORE "getCurrentRound()(uint256)" \
  --rpc-url $SEPOLIA_RPC_URL
```

#### Check Round Status

```bash
# Get round metadata
cast call $BETTING_CORE "getRoundMetadata(uint256)(uint64,uint64,bool,bool)" 1 \
  --rpc-url $SEPOLIA_RPC_URL

# Get round pool
cast call $BETTING_CORE "getRoundPool(uint256)(uint256,uint256,uint256,uint256,bool)" 1 \
  --rpc-url $SEPOLIA_RPC_URL

# Get round accounting
cast call $BETTING_CORE "getRoundAccounting(uint256)(uint128,uint32,uint32)" 1 \
  --rpc-url $SEPOLIA_RPC_URL
```

### Betting Operations

#### Approve LBT Spending

```bash
# Approve BettingCore to spend 100 LBT
cast send $LBT_TOKEN "approve(address,uint256)" \
  $BETTING_CORE \
  100000000000000000000 \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL
```

#### Place a Bet

**Single Match Bet (10 LBT on Match 0, Home Win):**

```bash
cast send $BETTING_CORE \
  "placeBet(uint256,uint256,uint8[],uint8[])" \
  1 \
  10000000000000000000 \
  "[0]" \
  "[1]" \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL
```

**Parlay Bet (10 LBT on Matches 0,1, Home Win + Away Win):**

```bash
cast send $BETTING_CORE \
  "placeBet(uint256,uint256,uint8[],uint8[])" \
  1 \
  10000000000000000000 \
  "[0,1]" \
  "[1,2]" \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL
```

**Predictions:**
- `1` = Home Win
- `2` = Away Win
- `3` = Draw

#### Check Your Bets

```bash
# Get your bet IDs
cast call $BETTING_CORE "getUserBets(address)(uint256[])" $YOUR_ADDRESS \
  --rpc-url $SEPOLIA_RPC_URL

# Get bet details
cast call $BETTING_CORE "getBet(uint256)(address,address,uint128,uint128,uint128,uint64,uint32,uint8,uint8)" 1 \
  --rpc-url $SEPOLIA_RPC_URL
```

#### Claim Winnings

```bash
# Claim single bet
cast send $BETTING_CORE "claimWinnings(uint256,uint256)" \
  <BET_ID> \
  0 \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL

# Batch claim multiple bets
cast send $BETTING_CORE "batchClaim(uint256[])" \
  "[1,2,3]" \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL
```

### Round Settlement

#### Settle Round (Manual - for testing)

```bash
# Settle round 1 with all home wins
cast send $BETTING_CORE "settleRound(uint256,uint8[])" \
  1 \
  "[1,1,1,1,1,1,1,1,1,1]" \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL
```

**Results format:** Array of 10 results (1=Home, 2=Away, 3=Draw)

#### Sweep Round Pool

After 30 hours (24h claim + 6h grace):

```bash
cast send $BETTING_CORE "sweepRoundPool(uint256)" 1 \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL
```

### Balance Checks

#### Check LBT Balance

```bash
cast call $LBT_TOKEN "balanceOf(address)(uint256)" $YOUR_ADDRESS \
  --rpc-url $SEPOLIA_RPC_URL
```

#### Check Protocol Reserves

```bash
cast call $BETTING_CORE "getProtocolReserves()(uint256)" \
  --rpc-url $SEPOLIA_RPC_URL
```

#### Check Available Reserves

```bash
cast call $BETTING_CORE "getAvailableReserves()(uint256,uint256,uint256)" \
  --rpc-url $SEPOLIA_RPC_URL
```

Returns: `(available, locked, total)`

---

## Round Pool Accounting

### Understanding the Flow

1. **Bet Placed:**
   - User's bet amount → Protocol Reserves
   - Potential payout locked: Protocol Reserves → Round Pool

2. **Bet Won (On-time claim):**
   - Payout comes from Round Pool
   - Round Pool balance decreases

3. **Bet Won (Late claim after sweep):**
   - 15% late fee charged
   - Payout comes from Protocol Reserves

4. **Bet Lost:**
   - Bet amount stays in Protocol Reserves
   - Locked payout returns: Round Pool → Protocol Reserves

5. **Round Sweep (30h after round end):**
   - Remaining funds: Round Pool → Protocol Reserves
   - 2% to Season Predictor, 98% to Protocol

### Round Pool States

```
┌─────────────┐
│ Round Start │
└─────┬───────┘
      │
      ▼
┌─────────────────────┐
│ Betting Open        │ ← Bets placed, funds locked
│ - totalLocked grows │
└─────┬───────────────┘
      │
      ▼
┌──────────────────────┐
│ Round Settled        │ ← VRF fulfilled, results known
│ - 24h claim window   │
└─────┬────────────────┘
      │
      ▼
┌──────────────────────┐
│ Claim Deadline       │ ← 24h passed, bounty claims allowed
│ - +6h grace period   │
└─────┬────────────────┘
      │
      ▼
┌──────────────────────┐
│ Sweep Available      │ ← 30h total, pool can be swept
│ - Late claims (15%)  │
└─────┬────────────────┘
      │
      ▼
┌──────────────────────┐
│ Pool Swept           │ ← Remaining → Protocol Reserves
│ - Round finalized    │
└──────────────────────┘
```

---

## Season Predictor

### Make Prediction

Predictions allowed until round 18:

```bash
cast send $SEASON_PREDICTOR "makePrediction(uint256,uint8)" \
  1 \
  5 \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL
```

Parameters:
- `seasonId`: Season ID
- `teamIndex`: Your predicted winner (0-19)

### Check Prediction

```bash
cast call $SEASON_PREDICTOR "getUserPrediction(uint256,address)(bool,uint8,uint128)" \
  1 \
  $YOUR_ADDRESS \
  --rpc-url $SEPOLIA_RPC_URL
```

Returns: `(exists, teamIndex, amountInPool)`

### Claim Season Prize

After season 1 ends (36 rounds):

```bash
cast send $SEASON_PREDICTOR "claimPrize(uint256)" 1 \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL
```

---

## Admin Operations

### Deposit Protocol Reserves

```bash
# First approve
cast send $LBT_TOKEN "approve(address,uint256)" \
  $BETTING_CORE \
  100000000000000000000 \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL

# Then deposit
cast send $BETTING_CORE "depositReserves(uint256)" \
  100000000000000000000 \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL
```

### Withdraw Reserves

```bash
cast send $BETTING_CORE "withdrawReserves(uint256,address)" \
  50000000000000000000 \
  $RECIPIENT_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL
```

### Update Configuration

```bash
# Update bet limits
cast send $BETTING_CORE "updateLimits(uint128,uint128,uint128,uint128)" \
  1000000000000000000 \
  10000000000000000000000 \
  50000000000000000000000 \
  100000000000000000 \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL
```

---

## Troubleshooting

### "Insufficient protocol reserves"

**Problem:** Not enough LBT in protocol reserves to lock for bet payout.

**Solution:**
```bash
./manage-betting.sh balances
# Then deposit more reserves if needed
```

### "Round not seeded"

**Problem:** Trying to bet before round is properly initialized.

**Solution:**
```bash
# Check round status
./manage-betting.sh check-round

# If not seeded, the round wasn't started properly
# Start a new round
./manage-betting.sh start-round
```

### "VRF request pending"

**Problem:** VRF randomness hasn't been fulfilled yet.

**Solution:** Wait 1-2 minutes for Chainlink VRF to fulfill the randomness request.

### "Claim deadline not passed"

**Problem:** Trying to claim bounty before 24h deadline.

**Solution:** Wait until 24 hours after round end, then claim.

---

## Gas Optimization Tips

1. **Batch Claims:** Use `batchClaim()` to claim multiple bets in one transaction
2. **Approve Once:** Approve large amount for BettingCore to avoid repeated approvals
3. **Off-Peak Times:** Execute on Sepolia during off-peak hours for lower gas

---

## Monitoring & Analytics

### Track Round Performance

```bash
# Run this periodically
watch -n 10 './manage-betting.sh check-round'
```

### Export Round Data

```bash
# Get all data for round 1
{
  echo "=== Round 1 Report ==="
  ./manage-betting.sh check-round 1
} > round_1_report.txt
```

### Monitor Protocol Health

```bash
# Create health check script
./manage-betting.sh status > health_check.txt
cat health_check.txt
```

---

## Production Checklist

Before going to production:

- [ ] VRF subscription funded with sufficient LINK
- [ ] Protocol reserves adequately funded (100k+ LBT)
- [ ] All contracts verified on Etherscan
- [ ] Emergency pause tested
- [ ] Frontend integrated with correct addresses
- [ ] Multiple test rounds completed successfully
- [ ] Claim and settlement flows tested
- [ ] Season predictor flow tested
- [ ] Monitoring/alerting set up

---

## Support

For issues or questions:
- Check contract events on Etherscan
- Review test suite: `forge test -vvv`
- See `DEPLOYMENT_GUIDE.md` for deployment details

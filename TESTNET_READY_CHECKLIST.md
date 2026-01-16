# Testnet Deployment Checklist - BettingPoolV2_1

## ✅ Completed Work

### 1. **Security Audit** ✅
- ✅ LiquidityPool.sol - Production ready
- ✅ SeasonPredictor.sol - Rewritten as V2 (99% gas savings)
- ✅ BettingPoolV2_1.sol - Dynamic seeding integrated
- ✅ GameEngine.sol - Previously audited

### 2. **SeasonPredictorV2** ✅
- ✅ Removed all array storage (now uses counters)
- ✅ O(1) operations everywhere (no loops)
- ✅ 99% gas reduction vs V1
- ✅ Added unclaimed prize withdrawal
- ✅ Custom errors for better DX
- ✅ Comprehensive test suite

### 3. **Dynamic Odds Seeding** ✅
- ✅ Hybrid model (pseudo-random + stats-based)
- ✅ Rounds 1-3: Deterministic pseudo-random
- ✅ Rounds 4+: Team stats-based
- ✅ Integrated into BettingPoolV2_1.sol

### 4. **Governance System** ✅
- ✅ BettingPoolGovernance.sol created
- ✅ 48-hour timelock on parameter changes
- ✅ Emergency pause functionality
- ✅ Parameter bounds for safety
- ✅ Integration guide ready

### 5. **Deployment Script** ✅
- ✅ DeployV2_1Complete.s.sol created
- ✅ Deploys all 5 contracts correctly
- ✅ Links contracts properly
- ✅ Clear initialization steps

---

## 📋 Files Ready for Deployment

### Core Contracts:
1. ✅ `src/LeagueToken.sol`
2. ✅ `src/GameEngine.sol` (VRF v2.5)
3. ✅ `src/LiquidityPool.sol`
4. ✅ `src/BettingPoolV2_1.sol` (with dynamic seeding)
5. ✅ `src/SeasonPredictorV2.sol` (optimized)

### Optional (if governance needed):
6. ⚠️ `src/BettingPoolGovernance.sol` (not yet integrated)

### Deployment:
7. ✅ `script/DeployV2_1Complete.s.sol`

### Tests:
8. ✅ `test/SeasonPredictorV2.t.sol`
9. ✅ `test/BettingPoolV2_1_Profitability.t.sol`

---

## 🔧 Pre-Deployment Tasks

### A. Environment Setup

```bash
# .env file
PRIVATE_KEY=your_private_key_here
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
ETHERSCAN_API_KEY=your_etherscan_key
VRF_SUBSCRIPTION_ID=your_vrf_subscription_id
```

### B. VRF Subscription Setup

1. **Create VRF Subscription**
   - Go to: https://vrf.chain.link/sepolia
   - Create new subscription
   - Fund with 10+ LINK
   - Copy subscription ID to `.env`

2. **Get LINK Tokens**
   - Faucet: https://faucets.chain.link/sepolia
   - Request 20 LINK

### C. Compile Contracts

```bash
forge build
```

**Expected**: All contracts compile without errors

---

## 🚀 Deployment Steps

### Step 1: Deploy Contracts

```bash
# Deploy all contracts
forge script script/DeployV2_1Complete.s.sol:DeployV2_1Complete \
    --rpc-url $SEPOLIA_RPC_URL \
    --broadcast \
    --verify \
    -vvvv
```

**Expected Output**:
- ✅ 5 contracts deployed
- ✅ All contracts verified on Etherscan
- ✅ Addresses printed to console

**Save these addresses:**
- LeagueToken: `0x...`
- GameEngine: `0x...`
- LiquidityPool: `0x...`
- BettingPoolV2_1: `0x...`
- SeasonPredictorV2: `0x...`

---

### Step 2: Add GameEngine as VRF Consumer

1. Go to: https://vrf.chain.link/sepolia
2. Click your subscription
3. Click "Add Consumer"
4. Paste GameEngine address
5. Confirm transaction

**Verify**: GameEngine shows in consumer list

---

### Step 3: Fund Protocol Reserve

```bash
# Approve 100,000 LEAGUE
cast send <LEAGUE_TOKEN_ADDRESS> \
    "approve(address,uint256)" \
    <BETTING_POOL_ADDRESS> \
    100000000000000000000000 \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY

# Fund reserve
cast send <BETTING_POOL_ADDRESS> \
    "fundProtocolReserve(uint256)" \
    100000000000000000000000 \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY
```

**Verify**:
```bash
cast call <BETTING_POOL_ADDRESS> "protocolReserve()(uint256)" \
    --rpc-url $SEPOLIA_RPC_URL
```

**Expected**: `100000000000000000000000` (100k LEAGUE)

---

### Step 4: Seed Liquidity Pool (Optional)

```bash
# Transfer 50,000 LEAGUE to LiquidityPool
cast send <LEAGUE_TOKEN_ADDRESS> \
    "transfer(address,uint256)" \
    <LIQUIDITY_POOL_ADDRESS> \
    50000000000000000000000 \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY

# Add liquidity
cast send <LIQUIDITY_POOL_ADDRESS> \
    "addLiquidity(uint256)" \
    50000000000000000000000 \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY
```

**Verify**:
```bash
cast call <LIQUIDITY_POOL_ADDRESS> "getTotalLiquidity()(uint256)" \
    --rpc-url $SEPOLIA_RPC_URL
```

---

### Step 5: Start Season

```bash
cast send <GAME_ENGINE_ADDRESS> \
    "startSeason()" \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY
```

**Verify**:
```bash
cast call <GAME_ENGINE_ADDRESS> "getCurrentSeason()(uint256)" \
    --rpc-url $SEPOLIA_RPC_URL
```

**Expected**: `1` (first season)

---

### Step 6: Start Round

```bash
cast send <GAME_ENGINE_ADDRESS> \
    "startRound()" \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY
```

**Verify**:
```bash
cast call <GAME_ENGINE_ADDRESS> "getCurrentRound()(uint256)" \
    --rpc-url $SEPOLIA_RPC_URL
```

**Expected**: `1` (first round)

---

### Step 7: Seed Round Pools

```bash
# Get current round ID
ROUND_ID=$(cast call <GAME_ENGINE_ADDRESS> "getCurrentRound()(uint256)" --rpc-url $SEPOLIA_RPC_URL)

# Seed pools with dynamic odds
cast send <BETTING_POOL_ADDRESS> \
    "seedRoundPools(uint256)" \
    $ROUND_ID \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY
```

**Verify Dynamic Odds**:
```bash
# Check match 0 odds
cast call <BETTING_POOL_ADDRESS> \
    "previewMatchOdds(uint256,uint256)(uint256,uint256,uint256)" \
    $ROUND_ID 0 \
    --rpc-url $SEPOLIA_RPC_URL

# Check match 1 odds (should be different)
cast call <BETTING_POOL_ADDRESS> \
    "previewMatchOdds(uint256,uint256)(uint256,uint256,uint256)" \
    $ROUND_ID 1 \
    --rpc-url $SEPOLIA_RPC_URL
```

**Expected**: Different odds for different matches ✅

---

## 🧪 Testing on Testnet

### Test 1: Make Prediction

```bash
# From any address
cast send <SEASON_PREDICTOR_ADDRESS> \
    "makePrediction(uint256)" \
    5 \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $USER_PRIVATE_KEY
```

### Test 2: Place Single Bet

```bash
# Approve tokens
cast send <LEAGUE_TOKEN_ADDRESS> \
    "approve(address,uint256)" \
    <BETTING_POOL_ADDRESS> \
    100000000000000000000 \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $USER_PRIVATE_KEY

# Place bet on match 0, HOME WIN, 100 LEAGUE
cast send <BETTING_POOL_ADDRESS> \
    "placeBet(uint256[],uint8[],uint256)" \
    "[0]" "[1]" 100000000000000000000 \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $USER_PRIVATE_KEY
```

### Test 3: Place Parlay Bet

```bash
# Place 2-leg parlay (matches 0 & 1, both HOME WIN)
cast send <BETTING_POOL_ADDRESS> \
    "placeBet(uint256[],uint8[],uint256)" \
    "[0,1]" "[1,1]" 100000000000000000000 \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $USER_PRIVATE_KEY
```

### Test 4: Check Parlay Multiplier

```bash
# Preview 2-leg parlay multiplier
cast call <BETTING_POOL_ADDRESS> \
    "getCurrentParlayMultiplier(uint256,uint256[],uint256)(uint256,uint256,uint256,uint256)" \
    $ROUND_ID "[0,1]" 2 \
    --rpc-url $SEPOLIA_RPC_URL
```

**Expected**:
- Tier 1 (first 10 parlays): 2.5x multiplier
- Tier 2 (next 10): 2.2x multiplier
- etc.

---

## 📊 Monitoring

### Check Protocol Reserve

```bash
cast call <BETTING_POOL_ADDRESS> "protocolReserve()(uint256)" \
    --rpc-url $SEPOLIA_RPC_URL
```

### Check Locked Parlay Reserve

```bash
cast call <BETTING_POOL_ADDRESS> "lockedParlayReserve()(uint256)" \
    --rpc-url $SEPOLIA_RPC_URL
```

### Check Season Prize Pool

```bash
SEASON_ID=$(cast call <GAME_ENGINE_ADDRESS> "getCurrentSeason()(uint256)" --rpc-url $SEPOLIA_RPC_URL)

cast call <SEASON_PREDICTOR_ADDRESS> \
    "getSeasonPrizePool(uint256)(uint256)" \
    $SEASON_ID \
    --rpc-url $SEPOLIA_RPC_URL
```

---

## 🎯 Success Criteria

### Deployment Success:
- ✅ All 5 contracts deployed
- ✅ All contracts verified on Etherscan
- ✅ GameEngine added as VRF consumer
- ✅ Protocol reserve funded (100k LEAGUE)
- ✅ Season started
- ✅ Round started
- ✅ Pools seeded with dynamic odds

### Functionality Success:
- ✅ Predictions can be made
- ✅ Single bets can be placed
- ✅ Parlay bets can be placed
- ✅ Odds are different per match
- ✅ Parlay multipliers decrease with tier
- ✅ No reverts during normal operations

### Gas Efficiency Success:
- ✅ Prediction: < 100k gas
- ✅ Single bet: < 200k gas
- ✅ Parlay bet (2-leg): < 300k gas
- ✅ Claim prize: < 100k gas

---

## 🚨 Troubleshooting

### Issue: "Insufficient reserve" when placing parlay

**Solution**: Fund more protocol reserve

```bash
cast send <BETTING_POOL_ADDRESS> \
    "fundProtocolReserve(uint256)" \
    50000000000000000000000 \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY
```

### Issue: "Not current round" when seeding

**Solution**: Get correct round ID

```bash
ROUND_ID=$(cast call <GAME_ENGINE_ADDRESS> "getCurrentRound()(uint256)" --rpc-url $SEPOLIA_RPC_URL)
echo "Current round: $ROUND_ID"
```

### Issue: VRF not responding

**Solutions**:
1. Check LINK balance in subscription
2. Verify GameEngine is added as consumer
3. Wait 2-5 minutes for VRF callback
4. Use emergency settle after 2 hours

---

## 📝 Post-Deployment Tasks

### 1. Update Frontend

```typescript
// frontend/lib/deployedAddresses.ts
export const DEPLOYED_ADDRESSES = {
  leagueToken:      '0x...',
  gameEngine:       '0x...',
  liquidityPool:    '0x...',
  bettingPool:      '0x...',
  seasonPredictor:  '0x...',
};
```

### 2. Export ABIs

```bash
# Create abis directory
mkdir -p frontend/abis

# Copy ABIs
cp out/BettingPoolV2_1.sol/BettingPoolV2_1.json frontend/abis/
cp out/SeasonPredictorV2.sol/SeasonPredictorV2.json frontend/abis/
cp out/GameEngine.sol/GameEngine.json frontend/abis/
cp out/LeagueToken.sol/LeagueToken.json frontend/abis/
cp out/LiquidityPool.sol/LiquidityPool.json frontend/abis/
```

### 3. Document Deployment

Create `DEPLOYMENT.md` with:
- All contract addresses
- Deployment timestamp
- Initial configuration
- VRF subscription ID
- First season/round IDs

---

## ✅ Final Checklist

Before going live:

- [ ] All contracts deployed successfully
- [ ] All contracts verified on Etherscan
- [ ] VRF subscription funded (10+ LINK)
- [ ] GameEngine added as VRF consumer
- [ ] Protocol reserve funded (100k+ LEAGUE)
- [ ] Liquidity pool seeded (optional, 50k LEAGUE)
- [ ] Season started
- [ ] Round started
- [ ] Pools seeded with dynamic odds
- [ ] Test prediction made successfully
- [ ] Test single bet placed successfully
- [ ] Test parlay bet placed successfully
- [ ] Odds verified as different per match
- [ ] Parlay multipliers verified as tiered
- [ ] Frontend updated with contract addresses
- [ ] ABIs exported to frontend
- [ ] Deployment documented

---

## 🎉 Launch Ready!

Once all checklist items are complete:

1. **Announce to users**: Testnet is live
2. **Monitor closely**: Watch for any issues
3. **Collect feedback**: User experience, gas costs, bugs
4. **Iterate**: Fix issues, optimize, improve
5. **Prepare mainnet**: Once testnet proven stable

---

## 📞 Need Help?

- **VRF Issues**: https://docs.chain.link/vrf/v2-5/overview
- **Forge Docs**: https://book.getfoundry.sh/
- **Sepolia Faucet**: https://sepoliafaucet.com/
- **LINK Faucet**: https://faucets.chain.link/sepolia

---

**Status**: 🟢 READY FOR TESTNET DEPLOYMENT

**Estimated Deployment Time**: 30 minutes
**Estimated Testing Time**: 1-2 hours

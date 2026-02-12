# 🚀 Betting Platform Deployment Guide

Complete guide to deploy the modular betting platform with BettingCore, GameCore, SeasonPredictor, and LBT token.

## 📋 Pre-Deployment Checklist

### 1. Environment Setup

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your configuration
nano .env
```

**Required variables:**
- `PRIVATE_KEY` - Your deployer wallet private key
- `SEPOLIA_RPC_URL` - RPC endpoint (Alchemy, Infura, or public)
- `VRF_SUBSCRIPTION_ID` - Chainlink VRF subscription ID (get from https://vrf.chain.link)
- `ETHERSCAN_API_KEY` - For contract verification

**Optional variables:**
- `PROTOCOL_TREASURY` - Treasury address (defaults to deployer)
- `DEPLOYER_ADDRESS` - Explicit deployer address

### 2. Get Testnet ETH & LINK

**Sepolia Faucets:**
- ETH: https://sepoliafaucet.com
- LINK: https://faucets.chain.link/sepolia

**Required amounts:**
- ~0.5 ETH for deployment gas
- ~5 LINK for VRF subscription

### 3. Create Chainlink VRF Subscription

1. Visit https://vrf.chain.link
2. Connect wallet
3. Select Sepolia network
4. Click "Create Subscription"
5. Fund with 5 LINK tokens
6. Copy subscription ID to `.env`

**Note:** You'll add GameCore as consumer AFTER deployment

---

## 🎯 Deployment Steps

### Step 1: Compile Contracts

```bash
forge build --force
```

**Expected output:** All contracts compile successfully

### Step 2: Update VRF Subscription ID

Edit `script/DeployBettingSystem.s.sol`:

```solidity
uint64 constant SUBSCRIPTION_ID = YOUR_SUBSCRIPTION_ID_HERE;
```

### Step 3: Deploy to Sepolia

```bash
forge script script/DeployBettingSystem.s.sol:DeployBettingSystem \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  -vvvv
```

**Deployment order:**
1. LeagueBetToken (LBT)
2. GameCore (with VRF)
3. BettingCore
4. SeasonPredictor
5. BettingRouter
6. SwapRouter
7. TokenRegistry

**Configuration (automatic):**
- Sets LBT token in BettingCore
- Links SeasonPredictor ↔ BettingCore
- Links GameCore ↔ BettingCore
- Seeds 100k LBT protocol reserves

### Step 4: Save Deployment Addresses

The script will output all addresses. Save them to `deployment.json`:

```json
{
  "network": "11155111",
  "deployer": "0x...",
  "contracts": {
    "lbtToken": "0x...",
    "gameCore": "0x...",
    "bettingCore": "0x...",
    "seasonPredictor": "0x...",
    "bettingRouter": "0x...",
    "swapRouter": "0x...",
    "tokenRegistry": "0x..."
  }
}
```

---

## ⚙️ Post-Deployment Configuration

### Step 5: Add VRF Consumer

1. Go to https://vrf.chain.link
2. Select your subscription
3. Click "Add Consumer"
4. Add GameCore address
5. Confirm transaction

**Verify:**
```bash
# Check if GameCore is added as consumer
cast call $GAME_CORE "s_subscriptionId()" --rpc-url $SEPOLIA_RPC_URL
```

### Step 6: Initialize First Season

```bash
# Initialize season 1
cast send $GAME_CORE "initializeSeason()" \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL
```

**Expected:** Season 1 initialized, ready for rounds

### Step 7: Start First Round

```bash
# Start round 1 (automatically seeds BettingCore)
cast send $GAME_CORE "startRound()" \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL
```

**This will:**
- Request VRF randomness for match strengths
- Seed BettingCore with round 1
- Lock initial odds
- Open betting

### Step 8: Extract ABIs

```bash
# Extract all contract ABIs for frontend
node extract-abis.js
```

**Output:** ABIs in `abis/` directory

---

## ✅ Verification Checklist

### Contract Verification

```bash
# Verify BettingCore
forge verify-contract $BETTING_CORE \
  src/core/BettingCore.sol:BettingCore \
  --chain-id 11155111 \
  --watch

# Verify GameCore
forge verify-contract $GAME_CORE \
  src/core/GameCore.sol:GameCore \
  --chain-id 11155111 \
  --watch

# Verify SeasonPredictor
forge verify-contract $SEASON_PREDICTOR \
  src/periphery/SeasonPredictor.sol:SeasonPredictor \
  --chain-id 11155111 \
  --watch
```

### Functional Tests

```bash
# 1. Check protocol reserves
cast call $BETTING_CORE "getProtocolReserves()" --rpc-url $SEPOLIA_RPC_URL

# Expected: 100000000000000000000000 (100k LBT in wei)

# 2. Check round status
cast call $BETTING_CORE "getCurrentRound()" --rpc-url $SEPOLIA_RPC_URL

# Expected: 1

# 3. Check season predictor setup
cast call $SEASON_PREDICTOR "canMakePredictions()(bool,uint256,uint256)" \
  --rpc-url $SEPOLIA_RPC_URL

# Expected: true, 1, 18

# 4. Check LBT balance
cast call $LBT_TOKEN "balanceOf(address)(uint256)" $DEPLOYER_ADDRESS \
  --rpc-url $SEPOLIA_RPC_URL

# Expected: 999900000000000000000000000 (999.9M LBT in wei)
```

---

## 📊 System Overview

### Contract Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Frontend/Users                     │
└─────────────────┬───────────────────────────────────┘
                  │
         ┌────────┴─────────┐
         │                  │
    ┌────▼────┐      ┌─────▼──────┐
    │ LBT     │◄─────┤ BettingCore│
    │ Token   │      │            │
    └─────────┘      │ • Place bet│
                     │ • Claim    │
                     │ • Sweep    │
                     └──┬───▲─────┘
                        │   │
           ┌────────────┘   └─────────────┐
           │                               │
      ┌────▼────┐                    ┌────▼────────┐
      │GameCore │                    │   Season    │
      │         │                    │  Predictor  │
      │ • VRF   │                    │             │
      │ • Rounds│                    │ • Predict   │
      │ • Season│                    │ • Claim     │
      └─────────┘                    └─────────────┘
```

### Key Features

**BettingCore:**
- Isolated round pool accounting
- 24h claim window + 6h grace period
- 10% bounty for late claims
- 15% late fee after sweep
- Protocol-backed (single LBT token)

**GameCore:**
- Chainlink VRF integration
- 36 rounds per season
- Automatic settlement
- Match result storage

**SeasonPredictor:**
- Free predictions until round 18
- 2% of betting revenue
- User self-claim system
- Equal prize split among winners

---

## 🔧 Troubleshooting

### Deployment Issues

**Problem:** "VRF subscription not found"
- **Solution:** Make sure VRF_SUBSCRIPTION_ID in script matches your actual subscription

**Problem:** "Insufficient LINK balance"
- **Solution:** Fund VRF subscription with at least 5 LINK

**Problem:** "Transaction underpriced"
- **Solution:** Increase gas price in foundry.toml or use `--gas-price` flag

### Runtime Issues

**Problem:** "Insufficient protocol reserves"
- **Solution:** Deposit more LBT: `bettingCore.depositReserves(amount)`

**Problem:** "Round not settled"
- **Solution:** Wait for VRF fulfillment or manually settle with results

**Problem:** "Can't make prediction - deadline passed"
- **Solution:** Predictions only allowed in rounds 1-18

---

## 📞 Support & Resources

- **Documentation:** `/docs` directory
- **Tests:** `forge test -vvv`
- **Gas Report:** `forge test --gas-report`
- **Chainlink VRF:** https://docs.chain.link/vrf/v2/subscription
- **Sepolia Explorer:** https://sepolia.etherscan.io

---

## 🎉 You're Ready!

Your betting platform is now deployed and configured. Next steps:

1. **Build Frontend:** Use the ABIs in `abis/` directory
2. **Test Betting:** Place some test bets
3. **Test Season Predictions:** Make predictions for the season
4. **Monitor:** Watch rounds progress and bets resolve

**Happy Betting! 🎲**

#!/bin/bash

# System Configuration Script
# Run this after deployment to configure contract relationships

set -e

# Load environment variables
source .env 2>/dev/null || true

# Contract Addresses (from latest deployment)
LBT_TOKEN="0x6a48dfd4151c5412ef228f3dc1772d0180ac15ae"
GAME_CORE="0xc5e37040aa1e05dceedee53ccbe4ebbce9c6d4ec"
BETTING_CORE="0x1df27ed5fc799c373f9a16a27314f8ee8d1d5159"
SEASON_PREDICTOR="0x724a69c2791726d4774e4a6f0d32ef70e62c31b4"

# RPC URL
RPC_URL="${SEPOLIA_RPC_URL:-https://ethereum-sepolia-rpc.publicnode.com}"

# Private key
PRIVATE_KEY="${PRIVATE_KEY}"

# Initial reserves: 100k LBT
INITIAL_RESERVES="100000000000000000000000" # 100k * 1e18

echo "========================================="
echo "System Configuration"
echo "========================================="
echo ""
echo "Contracts:"
echo "  LBT Token:        $LBT_TOKEN"
echo "  GameCore:         $GAME_CORE"
echo "  BettingCore:      $BETTING_CORE"
echo "  SeasonPredictor:  $SEASON_PREDICTOR"
echo ""

# Step 1: Set LBT token in BettingCore
echo "[1/5] Setting LBT token in BettingCore..."
cast send $BETTING_CORE "setLBTToken(address)" $LBT_TOKEN \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 100000

echo "  ✓ LBT token set"
echo ""

# Step 2: Set SeasonPredictor in BettingCore
echo "[2/5] Setting SeasonPredictor in BettingCore..."
cast send $BETTING_CORE "setSeasonPredictor(address)" $SEASON_PREDICTOR \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 100000

echo "  ✓ SeasonPredictor set"
echo ""

# Step 3: Set BettingCore in SeasonPredictor
echo "[3/5] Setting BettingCore in SeasonPredictor..."
cast send $SEASON_PREDICTOR "setBettingCore(address)" $BETTING_CORE \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 100000

echo "  ✓ BettingCore set in SeasonPredictor"
echo ""

# Step 4: Set BettingCore in GameCore
echo "[4/5] Setting BettingCore in GameCore..."
cast send $GAME_CORE "setBettingCore(address)" $BETTING_CORE \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 100000

echo "  ✓ BettingCore set in GameCore"
echo ""

# Step 5: Approve and deposit reserves
echo "[5/5] Seeding protocol reserves (100k LBT)..."

# First approve
echo "  Approving BettingCore to spend LBT..."
cast send $LBT_TOKEN "approve(address,uint256)" $BETTING_CORE $INITIAL_RESERVES \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 100000

echo "  ✓ Approval granted"

# Then deposit
echo "  Depositing reserves..."
cast send $BETTING_CORE "depositReserves(uint256)" $INITIAL_RESERVES \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL \
    --gas-limit 200000

echo "  ✓ Reserves deposited"
echo ""

echo "========================================="
echo "Configuration Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Initialize season: cast send $GAME_CORE 'initializeSeason()' --private-key \$PRIVATE_KEY --rpc-url \$RPC_URL"
echo "  2. Start first round: cast send $GAME_CORE 'startRound()' --private-key \$PRIVATE_KEY --rpc-url \$RPC_URL"
echo "  3. Run: ./manage-betting.sh"
echo ""

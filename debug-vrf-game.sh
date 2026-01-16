#!/bin/bash

# Debug VRF Request Issues for GameEngine
# This script checks the current state and identifies why requestMatchResults() might be reverting

SEPOLIA_RPC_URL="${SEPOLIA_RPC_URL:-https://ethereum-sepolia-rpc.publicnode.com}"
GAME_ENGINE="${GAME_ENGINE:-}"
PRIVATE_KEY="${PRIVATE_KEY:-}"

if [ -z "$GAME_ENGINE" ]; then
    echo "❌ Error: GAME_ENGINE environment variable not set"
    echo "Usage: export GAME_ENGINE=0x... && ./debug-vrf-game.sh"
    exit 1
fi

echo "🔍 Debugging GameEngine VRF Issue"
echo "=================================="
echo "GameEngine: $GAME_ENGINE"
echo ""

# 1. Check current season
echo "1️⃣ Checking Season State..."
CURRENT_SEASON=$(cast call $GAME_ENGINE "currentSeasonId()(uint256)" --rpc-url $SEPOLIA_RPC_URL)
echo "   Current Season ID: $CURRENT_SEASON"

if [ "$CURRENT_SEASON" -eq "0" ]; then
    echo "   ⚠️  No season started yet!"
    echo ""
    echo "   To fix, run:"
    echo "   cast send $GAME_ENGINE \"startSeason()\" --rpc-url \$SEPOLIA_RPC_URL --private-key \$PRIVATE_KEY"
    exit 1
fi

# Get season details
echo "   Fetching season details..."
SEASON_DATA=$(cast call $GAME_ENGINE "seasons(uint256)(uint256,uint256,uint256,bool,bool,uint256)" $CURRENT_SEASON --rpc-url $SEPOLIA_RPC_URL)
echo "   Season Data: $SEASON_DATA"
echo ""

# 2. Check current round
echo "2️⃣ Checking Round State..."
CURRENT_ROUND=$(cast call $GAME_ENGINE "currentRoundId()(uint256)" --rpc-url $SEPOLIA_RPC_URL)
echo "   Current Round ID: $CURRENT_ROUND"

if [ "$CURRENT_ROUND" -eq "0" ]; then
    echo "   ⚠️  No round started yet!"
    echo ""
    echo "   To fix, run:"
    echo "   cast send $GAME_ENGINE \"startRound()\" --rpc-url \$SEPOLIA_RPC_URL --private-key \$PRIVATE_KEY"
    exit 1
fi

# Get round details
echo "   Fetching round details..."

# Get round basic info
ROUND_START=$(cast call $GAME_ENGINE "rounds(uint256)" $CURRENT_ROUND --rpc-url $SEPOLIA_RPC_URL | grep -A 2 "startTime" | tail -1 | tr -d ' ')
ROUND_SETTLED=$(cast call $GAME_ENGINE "rounds(uint256)" $CURRENT_ROUND --rpc-url $SEPOLIA_RPC_URL | grep "settled" | tail -1 | tr -d ' ')

echo "   Round Start Time: $ROUND_START (Unix timestamp)"
echo "   Round Settled: $ROUND_SETTLED"
echo ""

# 3. Check timing requirement
echo "3️⃣ Checking Timing Requirement..."
CURRENT_TIME=$(date +%s)
ROUND_DURATION=900  # 15 minutes = 900 seconds
ELAPSED=$((CURRENT_TIME - ROUND_START))
REMAINING=$((ROUND_DURATION - ELAPSED))

echo "   Current Time: $CURRENT_TIME"
echo "   Elapsed Time: ${ELAPSED}s ($(($ELAPSED / 60)) minutes)"
echo "   Required Duration: ${ROUND_DURATION}s (15 minutes)"

if [ "$ELAPSED" -lt "$ROUND_DURATION" ]; then
    echo "   ⚠️  ROUND DURATION NOT ELAPSED!"
    echo "   Need to wait: ${REMAINING}s ($(($REMAINING / 60)) minutes) more"
    echo ""
    echo "   This is why requestMatchResults() is reverting!"
    echo "   Error message: 'Round duration not elapsed'"
    echo ""
    echo "   Options:"
    echo "   1. Wait $(($REMAINING / 60)) more minutes"
    echo "   2. For testing, modify ROUND_DURATION in contract to 1 minute"
    exit 1
else
    echo "   ✅ Timing requirement satisfied (elapsed: $(($ELAPSED / 60))m)"
fi
echo ""

# 4. Check if already settled
echo "4️⃣ Checking Settlement Status..."
if [ "$ROUND_SETTLED" = "true" ]; then
    echo "   ⚠️  ROUND ALREADY SETTLED!"
    echo "   This is why requestMatchResults() is reverting!"
    echo "   Error message: 'Round already settled'"
    echo ""
    echo "   To start a new round:"
    echo "   cast send $GAME_ENGINE \"startRound()\" --rpc-url \$SEPOLIA_RPC_URL --private-key \$PRIVATE_KEY"
    exit 1
else
    echo "   ✅ Round not settled yet"
fi
echo ""

# 5. Check VRF subscription
echo "5️⃣ Checking VRF Configuration..."
VRF_SUB_ID=$(cast call $GAME_ENGINE "s_subscriptionId()(uint256)" --rpc-url $SEPOLIA_RPC_URL)
echo "   VRF Subscription ID: $VRF_SUB_ID"

if [ "$VRF_SUB_ID" -eq "0" ]; then
    echo "   ⚠️  VRF Subscription not configured!"
    exit 1
fi
echo ""

# 6. Test if VRF request would succeed
echo "6️⃣ All Checks Passed! ✅"
echo "=================================="
echo ""
echo "The requestMatchResults() call should work now."
echo ""
echo "To request match results:"
echo ""
echo "cast send $GAME_ENGINE \\"
echo "    \"requestMatchResults(bool)\" \\"
echo "    false \\"
echo "    --rpc-url \$SEPOLIA_RPC_URL \\"
echo "    --private-key \$PRIVATE_KEY"
echo ""
echo "Expected outcome:"
echo "  - Transaction succeeds"
echo "  - VRF request sent to Chainlink"
echo "  - Wait 2-5 minutes for VRF callback"
echo "  - Round automatically settles with random scores"
echo ""
echo "To monitor VRF fulfillment:"
echo "while true; do"
echo "    SETTLED=\$(cast call $GAME_ENGINE \"rounds(uint256)\" $CURRENT_ROUND --rpc-url \$SEPOLIA_RPC_URL | grep settled | tail -1)"
echo "    echo \"Round settled: \$SETTLED\""
echo "    if echo \"\$SETTLED\" | grep -q \"true\"; then"
echo "        echo \"✅ Round settled!\""
echo "        break"
echo "    fi"
echo "    sleep 15"
echo "done"

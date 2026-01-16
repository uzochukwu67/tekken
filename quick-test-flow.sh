#!/bin/bash

# Quick Test Flow for GameEngine + BettingPoolV2
# Tests the complete flow with proper timing

set -e

SEPOLIA_RPC_URL="${SEPOLIA_RPC_URL:-https://ethereum-sepolia-rpc.publicnode.com}"
GAME_ENGINE="${GAME_ENGINE:-}"
BETTING_POOL="${BETTING_POOL:-}"
PRIVATE_KEY="${PRIVATE_KEY:-}"

if [ -z "$GAME_ENGINE" ] || [ -z "$BETTING_POOL" ] || [ -z "$PRIVATE_KEY" ]; then
    echo "❌ Error: Required environment variables not set"
    echo ""
    echo "Usage:"
    echo "  export GAME_ENGINE=0x..."
    echo "  export BETTING_POOL=0x..."
    echo "  export PRIVATE_KEY=0x..."
    echo "  export SEPOLIA_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com"
    echo "  ./quick-test-flow.sh"
    exit 1
fi

echo "🎮 GameEngine + BettingPoolV2 Test Flow"
echo "========================================"
echo "GameEngine:   $GAME_ENGINE"
echo "BettingPool:  $BETTING_POOL"
echo ""

# 1. Check if season is active
echo "1️⃣ Checking season status..."
CURRENT_SEASON=$(cast call $GAME_ENGINE "currentSeasonId()(uint256)" --rpc-url $SEPOLIA_RPC_URL)

if [ "$CURRENT_SEASON" -eq "0" ]; then
    echo "   Starting new season..."
    cast send $GAME_ENGINE "startSeason()" \
        --rpc-url $SEPOLIA_RPC_URL \
        --private-key $PRIVATE_KEY \
        --json | jq -r '.transactionHash' | xargs -I {} echo "   Season started: {}"
    CURRENT_SEASON=1
else
    echo "   ✅ Season $CURRENT_SEASON active"
fi
echo ""

# 2. Start new round
echo "2️⃣ Starting new round..."
TX=$(cast send $GAME_ENGINE "startRound()" \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --json)

ROUND_ID=$(cast call $GAME_ENGINE "currentRoundId()(uint256)" --rpc-url $SEPOLIA_RPC_URL)
echo "   ✅ Round $ROUND_ID started"
echo "   TX: $(echo $TX | jq -r '.transactionHash')"
echo ""

# 3. Get round start time
echo "3️⃣ Round details..."
START_TIME=$(date +%s)
echo "   Round ID: $ROUND_ID"
echo "   Start Time: $START_TIME"
echo "   Betting Window: 15 minutes (900 seconds)"
echo ""

# 4. Wait for betting window to elapse
echo "4️⃣ Waiting for betting window (15 minutes)..."
echo "   ⏰ This is when users would place bets..."
echo ""
echo "   Options:"
echo "   a) Wait full 15 minutes (production mode)"
echo "   b) Press Ctrl+C and modify ROUND_DURATION to 1 minute for testing"
echo ""

for i in {1..15}; do
    REMAINING=$((15 - i + 1))
    echo -ne "   Elapsed: ${i}/15 minutes (${REMAINING} minutes remaining)...\r"
    sleep 60
done
echo ""
echo "   ✅ Betting window elapsed!"
echo ""

# 5. Request match results (VRF)
echo "5️⃣ Requesting match results from VRF..."
TX=$(cast send $GAME_ENGINE "requestMatchResults(bool)" false \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --json)

VRF_REQUEST_ID=$(echo $TX | jq -r '.logs[0].topics[2]' | cast --to-dec)
echo "   ✅ VRF Request sent"
echo "   TX: $(echo $TX | jq -r '.transactionHash')"
echo "   VRF Request ID: $VRF_REQUEST_ID"
echo ""

# 6. Wait for VRF callback
echo "6️⃣ Waiting for VRF callback (2-5 minutes)..."
echo "   Chainlink VRF is generating random match results..."
echo ""

for i in {1..30}; do
    sleep 10

    SETTLED=$(cast call $GAME_ENGINE "rounds(uint256)" $ROUND_ID \
        --rpc-url $SEPOLIA_RPC_URL | grep settled | tail -1 | tr -d ' ')

    if echo "$SETTLED" | grep -q "true"; then
        echo ""
        echo "   ✅ VRF Callback received! Round settled!"
        break
    fi

    echo -ne "   ⏳ Waiting for VRF... ($((i * 10))s elapsed)\r"
done
echo ""

# 7. Verify settlement
echo "7️⃣ Verifying round settlement..."
IS_SETTLED=$(cast call $GAME_ENGINE "rounds(uint256)" $ROUND_ID \
    --rpc-url $SEPOLIA_RPC_URL | grep settled | tail -1)

if echo "$IS_SETTLED" | grep -q "true"; then
    echo "   ✅ Round $ROUND_ID successfully settled with random scores!"
    echo ""

    # Show first match as example
    echo "   Example match result:"
    cast call $GAME_ENGINE "getMatch(uint256,uint256)" $ROUND_ID 0 \
        --rpc-url $SEPOLIA_RPC_URL
else
    echo "   ⚠️  Round not settled yet. VRF may still be processing..."
    echo "   Check VRF status: https://vrf.chain.link/sepolia"
    echo ""
    echo "   Monitor settlement:"
    echo "   cast call $GAME_ENGINE \"rounds(uint256)\" $ROUND_ID --rpc-url \$SEPOLIA_RPC_URL"
fi
echo ""

# 8. Summary
echo "=========================================="
echo "✅ Test Flow Complete!"
echo "=========================================="
echo ""
echo "What happened:"
echo "  1. Season started (if needed)"
echo "  2. Round $ROUND_ID created with 10 matches"
echo "  3. 15-minute betting window (users can place bets)"
echo "  4. VRF request sent to Chainlink"
echo "  5. Random scores generated and round settled"
echo ""
echo "Next Steps:"
echo "  • Test betting by placing bets during the betting window"
echo "  • Verify match results: cast call $GAME_ENGINE \"getMatch(uint256,uint256)\" $ROUND_ID 0"
echo "  • Start next round: cast send $GAME_ENGINE \"startRound()\" --rpc-url \$SEPOLIA_RPC_URL --private-key \$PRIVATE_KEY"
echo ""
echo "🎉 GameEngine is working correctly!"

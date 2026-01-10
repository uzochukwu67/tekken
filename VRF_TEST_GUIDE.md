# VRF Testing Guide

## Overview

The GameEngine contract now includes a `requestRandomSample()` function to test if Chainlink VRF is working correctly before using it in production rounds.

## New Functions Added

### 1. Request Test VRF Sample

```solidity
function requestRandomSample(bool enableNativePayment, uint32 wordsToRequest)
    external onlyOwner returns (uint256 requestId)
```

**Parameters:**
- `enableNativePayment`: Set to `true` to pay in native ETH, `false` to pay in LINK
- `wordsToRequest`: Number of random words to request (1-10)

**Returns:**
- `requestId`: The VRF request ID that can be used to check results

### 2. Get Test VRF Result

```solidity
function getTestVRFResult(uint256 requestId)
    external view returns (
        bool exists,
        bool fulfilled,
        uint256 requestTime,
        uint256[] memory randomWords
    )
```

**Returns:**
- `exists`: Whether the request exists
- `fulfilled`: Whether VRF has responded
- `requestTime`: Timestamp when request was made
- `randomWords`: Array of random numbers received (empty if not fulfilled)

### 3. Get Last Test Result

```solidity
function getLastTestVRFResult()
    external view returns (
        uint256 requestId,
        bool exists,
        bool fulfilled,
        uint256 requestTime,
        uint256[] memory randomWords
    )
```

Convenient function to check the most recent test request without needing the request ID.

## Testing VRF on Sepolia

### Step 1: Request a Test Sample

```bash
# Request 3 random words using LINK payment
cast send $GAME_ENGINE \
    "requestRandomSample(bool,uint32)" \
    false 3 \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY

# Or with native ETH payment (if GameEngine has ETH balance)
cast send $GAME_ENGINE \
    "requestRandomSample(bool,uint32)" \
    true 3 \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY
```

### Step 2: Get the Request ID

```bash
# Get the last test request ID and status
cast call $GAME_ENGINE \
    "getLastTestVRFResult()(uint256,bool,bool,uint256,uint256[])" \
    --rpc-url $SEPOLIA_RPC_URL
```

**Output format:**
```
requestId: 123456789...
exists: true
fulfilled: false  (will be true after VRF responds)
requestTime: 1704123456
randomWords: []  (will contain random numbers after fulfillment)
```

### Step 3: Wait for VRF Response

VRF typically responds in **2-5 minutes** on Sepolia testnet.

Check status periodically:

```bash
# Check every 30 seconds
while true; do
    echo "Checking VRF status..."
    RESULT=$(cast call $GAME_ENGINE \
        "getLastTestVRFResult()(uint256,bool,bool,uint256,uint256[])" \
        --rpc-url $SEPOLIA_RPC_URL)

    echo "$RESULT"

    # Check if fulfilled (you'll see fulfilled: true in output)
    if echo "$RESULT" | grep -q "true.*true"; then
        echo "✅ VRF Request Fulfilled!"
        break
    fi

    sleep 30
done
```

### Step 4: View Random Numbers

Once fulfilled, the random numbers will be visible:

```bash
cast call $GAME_ENGINE \
    "getLastTestVRFResult()(uint256,bool,bool,uint256,uint256[])" \
    --rpc-url $SEPOLIA_RPC_URL
```

**Example output:**
```
requestId: 123456789...
exists: true
fulfilled: true ✅
requestTime: 1704123456
randomWords: [
    98765432109876543210987654321098765432109876543210...,
    12345678901234567890123456789012345678901234567890...,
    55555555555555555555555555555555555555555555555555...
]
```

## Troubleshooting

### VRF Request Fails

**Error: "Insufficient LINK"**
```bash
# Check LINK balance
cast call $LINK_TOKEN \
    "balanceOf(address)(uint256)" \
    $GAME_ENGINE \
    --rpc-url $SEPOLIA_RPC_URL

# Send LINK to GameEngine
cast send $LINK_TOKEN \
    "transfer(address,uint256)" \
    $GAME_ENGINE \
    2000000000000000000 \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY
```

**Error: "Consumer not registered"**
- Go to https://vrf.chain.link/sepolia
- Find your subscription
- Add GameEngine address as a consumer

### VRF Takes Too Long

If VRF hasn't responded after 10 minutes:

1. Check VRF subscription has LINK: https://vrf.chain.link/sepolia
2. Verify GameEngine is registered as consumer
3. Check transaction didn't revert: Look up the request transaction on Sepolia Etherscan
4. Try requesting again with fewer words (e.g., 1 instead of 10)

## Complete Test Script

```bash
#!/bin/bash

SEPOLIA_RPC_URL="https://ethereum-sepolia-rpc.publicnode.com"
GAME_ENGINE="0x..." # Your GameEngine address
PRIVATE_KEY="0x..."

echo "🎲 Testing Chainlink VRF..."

# 1. Request random sample
echo "1️⃣ Requesting 3 random words..."
TX=$(cast send $GAME_ENGINE \
    "requestRandomSample(bool,uint32)" \
    false 3 \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --json)

echo "✅ Request sent!"

# 2. Get request ID
echo ""
echo "2️⃣ Getting request ID..."
RESULT=$(cast call $GAME_ENGINE \
    "getLastTestVRFResult()(uint256,bool,bool,uint256,uint256[])" \
    --rpc-url $SEPOLIA_RPC_URL)

REQUEST_ID=$(echo "$RESULT" | head -1 | awk '{print $1}')
echo "Request ID: $REQUEST_ID"

# 3. Wait for fulfillment
echo ""
echo "3️⃣ Waiting for VRF response (2-5 minutes)..."

for i in {1..20}; do
    sleep 15

    RESULT=$(cast call $GAME_ENGINE \
        "getTestVRFResult(uint256)(bool,bool,uint256,uint256[])" \
        $REQUEST_ID \
        --rpc-url $SEPOLIA_RPC_URL)

    FULFILLED=$(echo "$RESULT" | sed -n '2p' | tr -d ' ')

    if [ "$FULFILLED" = "true" ]; then
        echo ""
        echo "✅ VRF Request Fulfilled!"
        echo ""
        echo "Random Numbers Received:"
        cast call $GAME_ENGINE \
            "getTestVRFResult(uint256)(bool,bool,uint256,uint256[])" \
            $REQUEST_ID \
            --rpc-url $SEPOLIA_RPC_URL
        exit 0
    fi

    echo -ne "\r  ⏳ Waiting... ($((i * 15))s)"
done

echo ""
echo "⚠️  VRF taking longer than expected. Check status manually:"
echo "cast call $GAME_ENGINE 'getTestVRFResult(uint256)(bool,bool,uint256,uint256[])' $REQUEST_ID --rpc-url $SEPOLIA_RPC_URL"
```

## Integration with Main Game Flow

Once VRF is confirmed working, you can proceed with confidence to:

1. Start a season: `gameEngine.startSeason()`
2. Start a round: `gameEngine.startRound()`
3. Wait 15 minutes for betting window
4. Request match results: `gameEngine.requestMatchResults(false)`
5. VRF will automatically settle the round with random match scores

## Events to Monitor

### Test VRF Events

```solidity
event TestVRFRequested(uint256 indexed requestId, uint256 timestamp);
event TestVRFFulfilled(uint256 indexed requestId, uint256[] randomWords);
```

### Production VRF Events

```solidity
event VRFRequested(uint256 indexed roundId, uint256 requestId, uint256 paid);
event VRFFulfilled(uint256 indexed requestId, uint256 indexed roundId);
```

## Next Steps

After confirming VRF works:

1. ✅ **VRF Test Passed** - Random numbers are being received
2. 🎮 **Run Full Game Flow** - Use the test-game-flow.sh script
3. 💰 **Profitability Analysis** - Run tests to verify protocol and LP economics
4. 🚀 **Deploy to Mainnet** - Once all tests pass

---

**Note**: The test VRF function is completely separate from production round settlement. You can test VRF without affecting any active rounds or bets.

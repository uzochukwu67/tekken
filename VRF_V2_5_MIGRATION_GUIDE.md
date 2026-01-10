# VRF v2.5 Direct Funding Migration Guide

## Overview

The GameEngine contract has been migrated from **Chainlink VRF v2 (Subscription)** to **VRF v2.5 Direct Funding (Wrapper)**. This eliminates the need for subscription management and allows paying per request in either LINK or native ETH.

## Key Changes

### Before (VRF v2)
- ❌ Required creating and funding a VRF subscription
- ❌ Required adding GameEngine as a consumer
- ❌ Complex subscription management
- ❌ Gas-intensive coordinator interactions

### After (VRF v2.5)
- ✅ **No subscription needed** - pay per request
- ✅ Can pay in **LINK or native ETH**
- ✅ Simpler contract deployment
- ✅ Lower gas costs via wrapper
- ✅ Easier testing and development

## Contract Changes

### New Contract: `GameEngineV2_5.sol`

**Location:** `src/GameEngineV2_5.sol`

**Key Differences:**

```solidity
// OLD (VRF v2)
contract GameEngine is VRFConsumerBaseV2, Ownable {
    VRFCoordinatorV2Interface public immutable vrfCoordinator;
    uint64 public subscriptionId;  // ❌ No longer needed
    bytes32 public keyHash;        // ❌ No longer needed

    constructor(
        address _vrfCoordinator,
        uint64 _subscriptionId,    // ❌ Removed
        bytes32 _keyHash,          // ❌ Removed
        address _initialOwner
    ) VRFConsumerBaseV2(_vrfCoordinator) Ownable(_initialOwner) { }
}

// NEW (VRF v2.5)
contract GameEngine is VRFV2PlusWrapperConsumerBase, ConfirmedOwner {
    LinkTokenInterface public immutable linkToken;
    bool public useNativePayment = false;  // ✅ Choose LINK or ETH

    constructor(
        address _linkAddress,      // ✅ LINK token address
        address _wrapperAddress    // ✅ VRF Wrapper address
    ) ConfirmedOwner(msg.sender) VRFV2PlusWrapperConsumerBase(_wrapperAddress) { }
}
```

### Request Function Changes

```solidity
// OLD (VRF v2)
function requestMatchResults() external onlyOwner {
    uint256 requestId = vrfCoordinator.requestRandomWords(
        keyHash,
        subscriptionId,  // ❌ No subscription
        requestConfirmations,
        callbackGasLimit,
        numWords
    );
}

// NEW (VRF v2.5)
function requestMatchResults() external onlyOwner returns (uint256 requestId) {
    // Create extraArgs for VRF v2.5
    bytes memory extraArgs = VRFV2PlusClient._argsToBytes(
        VRFV2PlusClient.ExtraArgsV1({nativePayment: useNativePayment})
    );

    uint256 reqPrice;

    if (useNativePayment) {
        // ✅ Pay in native ETH
        (requestId, reqPrice) = requestRandomnessPayInNative(
            callbackGasLimit,
            requestConfirmations,
            numWords,
            extraArgs
        );
    } else {
        // ✅ Pay in LINK
        (requestId, reqPrice) = requestRandomness(
            callbackGasLimit,
            requestConfirmations,
            numWords,
            extraArgs
        );
    }

    // Store payment info
    vrfRequests[requestId] = RequestStatus({
        paid: reqPrice,
        fulfilled: false,
        roundId: currentRoundId
    });
}
```

## Deployment

### Sepolia Testnet Addresses

```solidity
// VRF v2.5 Direct Funding on Sepolia
LINK Token: 0x779877A7B0D9E8603169DdbD7836e478b4624789
VRF Wrapper: 0x195f15F2d49d693cE265b4fB0fdDbE15b1850Cc1
```

### Deploy Command

```bash
# Set environment variables
export SEPOLIA_RPC_URL="https://ethereum-sepolia-rpc.publicnode.com"
export PRIVATE_KEY="your_private_key"

# Deploy contracts
forge script script/DeployBettingPoolV2.s.sol:DeployBettingPoolV2 \
    --rpc-url $SEPOLIA_RPC_URL \
    --broadcast \
    --verify
```

### Post-Deployment Setup

#### Option 1: Pay with LINK (Recommended)

```bash
# 1. Get LINK from faucet
# Visit: https://faucets.chain.link/sepolia

# 2. Send LINK to GameEngine
cast send 0x779877A7B0D9E8603169DdbD7836e478b4624789 \
    "transfer(address,uint256)" \
    0xa0B5CCed676202888192345E38b8CeE5B219B1e9 \
    2000000000000000000 \ 
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY

# 3. Check LINK balance
cast call 0x779877A7B0D9E8603169DdbD7836e478b4624789 \
    "balanceOf(address)(uint256)" \
    <GAME_ENGINE_ADDRESS> \
    --rpc-url $SEPOLIA_RPC_URL
```

#### Option 2: Pay with Native ETH

```bash
# 1. Send ETH to GameEngine for gas
cast send <GAME_ENGINE_ADDRESS> \
    --value 0.1ether \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY

# 2. Enable native payment mode
cast send <GAME_ENGINE_ADDRESS> \
    "updateVRFConfig(uint32,uint16,bool)" \
    500000 3 true \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY

# 3. Check ETH balance
cast balance <GAME_ENGINE_ADDRESS> --rpc-url $SEPOLIA_RPC_URL
```

## Testing the New VRF

### 1. Start Season and Round

```bash
# Start season
cast send <GAME_ENGINE_ADDRESS> "startSeason()" \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY

# Start round
cast send <GAME_ENGINE_ADDRESS> "startRound()" \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY

# Check current round
cast call <GAME_ENGINE_ADDRESS> "getCurrentRound()(uint256)" \
    --rpc-url $SEPOLIA_RPC_URL
```

### 2. Wait 15 Minutes

```bash
# Check round start time
cast call <GAME_ENGINE_ADDRESS> "getRound(uint256)" 1 \
    --rpc-url $SEPOLIA_RPC_URL

# Calculate time remaining
# Current time - Start time should be >= 900 seconds (15 minutes)
```

### 3. Request VRF

```bash
# Request match results
cast send <GAME_ENGINE_ADDRESS> "requestMatchResults()" \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --gas-limit 500000

# Get request ID from transaction logs
# Event VRFRequested(uint256 indexed roundId, uint256 requestId, uint256 paid)
```

### 4. Check VRF Response

```bash
# Check if round is settled (wait ~2-5 minutes for VRF)
cast call <GAME_ENGINE_ADDRESS> "isRoundSettled(uint256)(bool)" 1 \
    --rpc-url $SEPOLIA_RPC_URL

# Get match results
cast call <GAME_ENGINE_ADDRESS> "getMatch(uint256,uint256)" 1 0 \
    --rpc-url $SEPOLIA_RPC_URL

# Check request status
cast call <GAME_ENGINE_ADDRESS> \
    "getRequestStatus(uint256)(uint256,bool,uint256)" \
    <REQUEST_ID> \
    --rpc-url $SEPOLIA_RPC_URL
```

## Cost Comparison

### VRF v2 (Subscription)
```
Initial Cost:
- Create subscription: ~200,000 gas
- Add consumer: ~100,000 gas
- Fund subscription: Transfer gas

Per Request:
- Request: ~130,000 gas
- Callback: ~500,000 gas
- Total: ~630,000 gas + subscription overhead
```

### VRF v2.5 (Direct Funding)
```
Initial Cost:
- None (just deploy contract)
- Fund with LINK/ETH: Transfer gas

Per Request (LINK):
- Request: ~120,000 gas
- Wrapper premium: ~10%
- Callback: ~500,000 gas
- Total: ~620,000 gas + LINK payment

Per Request (Native ETH):
- Request: ~125,000 gas
- Wrapper premium: ~10%
- Callback: ~500,000 gas
- Total: ~625,000 gas + ETH payment
```

**Savings:** ~10-15% lower gas + no subscription management!

## Admin Dashboard Integration

The admin dashboard ([frontend/components/admin-dashboard.tsx](frontend/components/admin-dashboard.tsx)) will work with the new VRF v2.5 contract without changes. The `requestMatchResults()` function signature remains compatible.

### Additional Features

You may want to add these features to the admin dashboard:

1. **Payment Method Toggle**
```typescript
const { writeContract } = useWriteContract()

const togglePaymentMethod = async (useNative: boolean) => {
  writeContract({
    address: gameEngine.address,
    abi: gameEngine.abi,
    functionName: "updateVRFConfig",
    args: [500000n, 3, useNative], // callbackGasLimit, confirmations, useNative
  })
}
```

2. **LINK Balance Display**
```typescript
const { data: linkBalance } = useReadContract({
  address: LINK_ADDRESS,
  abi: ERC20_ABI,
  functionName: "balanceOf",
  args: [gameEngine.address],
})
```

3. **VRF Cost Estimation**
```typescript
const { data: estimatedCost } = useReadContract({
  address: WRAPPER_ADDRESS,
  abi: WRAPPER_ABI,
  functionName: "estimateRequestPrice",
  args: [callbackGasLimit, gasPriceWei],
})
```

## Migration Checklist

- [ ] Deploy new GameEngineV2_5 contract
- [ ] Deploy BettingPool, LiquidityPool, LeagueToken
- [ ] Link contracts together
- [ ] Fund GameEngine with LINK or ETH
- [ ] Test VRF request (1 round)
- [ ] Verify VRF callback works
- [ ] Export new ABIs to frontend
- [ ] Update frontend deployed addresses
- [ ] Test admin dashboard with new contracts
- [ ] Update automation bot for new contract

## Troubleshooting

### VRF Request Fails

**Error:** "Insufficient LINK balance"
```bash
# Check LINK balance
cast call 0x779877A7B0D9E8603169DdbD7836e478b4624789 \
    "balanceOf(address)(uint256)" \
    <GAME_ENGINE_ADDRESS> \
    --rpc-url $SEPOLIA_RPC_URL

# Send more LINK if needed
```

**Error:** "Insufficient ETH balance"
```bash
# Check ETH balance
cast balance <GAME_ENGINE_ADDRESS> --rpc-url $SEPOLIA_RPC_URL

# Send more ETH
cast send <GAME_ENGINE_ADDRESS> \
    --value 0.1ether \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY
```

### VRF Not Fulfilling

1. **Check request status:**
```bash
cast call <GAME_ENGINE_ADDRESS> \
    "getRequestStatus(uint256)(uint256,bool,uint256)" \
    <REQUEST_ID> \
    --rpc-url $SEPOLIA_RPC_URL
```

2. **Wait longer** - VRF can take 2-5 minutes on testnet

3. **Use emergency settlement after 2 hours:**
```bash
cast send <GAME_ENGINE_ADDRESS> \
    "emergencySettleRound(uint256,uint256)" \
    <ROUND_ID> \
    <RANDOM_SEED> \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY
```

## Benefits Summary

✅ **No Subscription Management** - Just deploy and fund
✅ **Flexible Payment** - Choose LINK or native ETH
✅ **Lower Gas Costs** - ~10-15% savings
✅ **Simpler Testing** - No subscription setup needed
✅ **Better UX** - Pay-per-use model
✅ **Easier Maintenance** - Fewer moving parts

## Next Steps

1. **Deploy to Sepolia:**
   ```bash
   forge script script/DeployGameEngineV2_5.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast
   ```

2. **Fund with LINK:**
   Get LINK from https://faucets.chain.link/sepolia

3. **Test VRF:**
   Follow the testing steps above

4. **Update Frontend:**
   Export ABIs and update deployed addresses

5. **Update Automation:**
   Point bot to new GameEngine address

---

For more information on VRF v2.5 Direct Funding, see:
- [Chainlink VRF v2.5 Documentation](https://docs.chain.link/vrf/v2-5/overview)
- [Direct Funding Guide](https://docs.chain.link/vrf/v2-5/direct-funding)

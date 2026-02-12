#!/bin/bash

# BNB Testnet Deployment Script

set -e

# Load environment variables
source .env 2>/dev/null || true

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}BNB Testnet Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "RPC URL: ${BNBT_RPC_URL}"
echo "Deployer: ${DEPLOYER_ADDRESS}"
echo "VRF Subscription: 1578109526430208923092936074832940743930817264043206076350506979961752447843"
echo ""

# Check if private key is set
if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}Error: PRIVATE_KEY not set in .env file${NC}"
    exit 1
fi

# Check if RPC URL is set
if [ -z "$BNBT_RPC_URL" ]; then
    echo -e "${YELLOW}Warning: BNBT_RPC_URL not set, using default${NC}"
    BNBT_RPC_URL="https://bsc-testnet.drpc.org"
fi

echo -e "${YELLOW}Starting deployment...${NC}"
echo ""

# Deploy contracts
forge script script/DeployBNBtestnet.s.sol:DeployBNBTestnet \
  --rpc-url $BNBT_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --legacy \
  -vvv

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Check broadcast/DeployBNBtestnet.s.sol/97/run-latest.json for deployed addresses"
echo "  2. Add GameCore as VRF consumer at https://vrf.chain.link"
echo "  3. Fund VRF subscription with LINK tokens"
echo "  4. Initialize season: gameCore.initializeSeason()"
echo "  5. Start first round: gameCore.startRound()"
echo ""

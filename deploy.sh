#!/bin/bash

# Betting Platform Deployment Script
# Quick deployment helper for Sepolia testnet

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Betting Platform Deployment Helper                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found!${NC}"
    echo -e "${YELLOW}Please copy .env.example to .env and fill in your configuration${NC}"
    echo ""
    echo "  cp .env.example .env"
    echo "  nano .env"
    exit 1
fi

# Load environment variables
source .env

# Check required variables
if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}Error: PRIVATE_KEY not set in .env${NC}"
    exit 1
fi

if [ -z "$SEPOLIA_RPC_URL" ]; then
    echo -e "${RED}Error: SEPOLIA_RPC_URL not set in .env${NC}"
    exit 1
fi

if [ -z "$VRF_SUBSCRIPTION_ID" ] || [ "$VRF_SUBSCRIPTION_ID" = "your_subscription_id_here" ]; then
    echo -e "${RED}Error: VRF_SUBSCRIPTION_ID not set in .env${NC}"
    echo -e "${YELLOW}Get a subscription ID from https://vrf.chain.link${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Environment variables loaded"
echo ""

# Check if contracts are compiled
if [ ! -d "out" ]; then
    echo -e "${YELLOW}Compiling contracts...${NC}"
    forge build --force
    echo -e "${GREEN}✓${NC} Contracts compiled"
else
    echo -e "${GREEN}✓${NC} Contracts already compiled"
fi
echo ""

# Deployment options
echo -e "${BLUE}Deployment Options:${NC}"
echo "  1. Deploy to Sepolia (with verification)"
echo "  2. Deploy to Sepolia (no verification)"
echo "  3. Deploy to Local Anvil"
echo "  4. Extract ABIs only"
echo "  5. Exit"
echo ""
read -p "Select option [1-5]: " option

case $option in
    1)
        echo ""
        echo -e "${YELLOW}Deploying to Sepolia with verification...${NC}"
        echo -e "${YELLOW}This will take a few minutes...${NC}"
        echo ""

        forge script script/DeployBettingSystem.s.sol:DeployBettingSystem \
            --rpc-url $SEPOLIA_RPC_URL \
            --private-key $PRIVATE_KEY \
            --broadcast \
            --verify \
            --etherscan-api-key $ETHERSCAN_API_KEY \
            -vvvv

        echo ""
        echo -e "${GREEN}✓ Deployment complete!${NC}"
        ;;

    2)
        echo ""
        echo -e "${YELLOW}Deploying to Sepolia without verification...${NC}"
        echo ""

        forge script script/DeployBettingSystem.s.sol:DeployBettingSystem \
            --rpc-url $SEPOLIA_RPC_URL \
            --private-key $PRIVATE_KEY \
            --broadcast \
            -vvvv

        echo ""
        echo -e "${GREEN}✓ Deployment complete!${NC}"
        echo -e "${YELLOW}Remember to verify contracts manually later${NC}"
        ;;

    3)
        echo ""
        echo -e "${YELLOW}Deploying to Local Anvil...${NC}"
        echo -e "${YELLOW}Make sure Anvil is running: anvil${NC}"
        echo ""

        forge script script/DeployBettingSystem.s.sol:DeployBettingSystem \
            --rpc-url http://127.0.0.1:8545 \
            --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
            --broadcast \
            -vvvv

        echo ""
        echo -e "${GREEN}✓ Local deployment complete!${NC}"
        ;;

    4)
        echo ""
        echo -e "${YELLOW}Extracting ABIs...${NC}"
        node extract-abis.js
        echo ""
        echo -e "${GREEN}✓ ABIs extracted to abis/ directory${NC}"
        ;;

    5)
        echo "Exiting..."
        exit 0
        ;;

    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

# Post-deployment steps
if [ $option -eq 1 ] || [ $option -eq 2 ] || [ $option -eq 3 ]; then
    echo ""
    echo -e "${BLUE}═════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}         Post-Deployment Steps                        ${NC}"
    echo -e "${BLUE}═════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}1.${NC} Add GameCore as VRF consumer:"
    echo "     https://vrf.chain.link"
    echo ""
    echo -e "${YELLOW}2.${NC} Extract ABIs for frontend:"
    echo "     ./deploy.sh (select option 4)"
    echo ""
    echo -e "${YELLOW}3.${NC} Save deployment addresses from output above"
    echo ""
    echo -e "${YELLOW}4.${NC} Initialize first season and round"
    echo ""
    echo -e "${GREEN}See DEPLOYMENT_GUIDE.md for detailed instructions${NC}"
fi

echo ""
echo -e "${GREEN}Done! 🚀${NC}"

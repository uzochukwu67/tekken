// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/tokens/LeagueBetToken.sol";
import "../src/core/GameCore.sol";
import "../src/core/BettingCore.sol";
import "../src/periphery/SeasonPredictor.sol";
import "../src/periphery/BettingRouter.sol";
import "../src/periphery/SwapRouter.sol";
import "../src/tokens/TokenRegistry.sol";

/**
 * @title DeployBNBTestnet
 * @notice Deployment script for BNB Smart Chain Testnet
 * @dev Deploys: LBT token, GameCore, BettingCore, SeasonPredictor, Routers
 *
 * Usage:
 * forge script script/DeployBNBtestnet.s.sol:DeployBNBTestnet \
 *   --rpc-url $BNBT_RPC_URL \
 *   --private-key $PRIVATE_KEY \
 *   --broadcast \
 *   --legacy \
 *   --verify \
 *   --etherscan-api-key $BSCSCAN_API_KEY
 */
contract DeployBNBTestnet is Script {
    // Deployment addresses (will be populated during deployment)
    LeagueBetToken public lbtToken;
    GameCore public gameCore;
    BettingCore public bettingCore;
    SeasonPredictor public seasonPredictor;
    BettingRouter public bettingRouter;
    SwapRouter public swapRouter;
    TokenRegistry public tokenRegistry;

    // Configuration
    address public deployer;
    address public protocolTreasury;

    // Chainlink VRF Configuration (BNB Testnet)
    address constant LINK_TOKEN = 0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06;
    address constant VRF_COORDINATOR = 0xDA3b641D438362C440Ac5458c57e00a712b66700;
    bytes32 constant KEY_HASH = 0x8596b430971ac45bdf6088665b9ad8e8630c9d5049ab54b14dff711bee7c0e26;
    uint256 constant SUBSCRIPTION_ID = 1578109526430208923092936074832940743930817264043206076350506979961752447843;

    // Swap Router Configuration (BNB Testnet - PancakeSwap V2)
    address constant WBNB = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;
    address constant PANCAKE_ROUTER = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1;

    // Initial supply: 1 billion LBT
    uint256 constant INITIAL_SUPPLY = 1_000_000 ether;

    // Protocol reserves to seed: 100k LBT
    uint256 constant INITIAL_RESERVES = 100_000 ether;

    function setUp() public {
        // deployer will be set to msg.sender in run() after vm.startBroadcast()
        // This ensures deployer matches the actual transaction sender

        console.log("========================================");
        console.log("BNB Testnet Deployment Configuration");
        console.log("========================================");
        console.log("Network Chain ID:", block.chainid);
        console.log("VRF Coordinator:", VRF_COORDINATOR);
        console.log("VRF Subscription:", SUBSCRIPTION_ID);
        console.log("========================================");
    }

    function run() public {
        vm.startBroadcast();

        // Set deployer to actual transaction sender (from private key)
        deployer = msg.sender;
        protocolTreasury = deployer; // Use deployer as treasury

        console.log("Deployer/Treasury:", deployer);
        console.log("");

        console.log("\n[1/7] Deploying LeagueBetToken (LBT)...");
        lbtToken = new LeagueBetToken(INITIAL_SUPPLY);
        console.log("  LBT Token deployed at:", address(lbtToken));
        console.log("  Initial supply:", INITIAL_SUPPLY / 1e18, "LBT");

        console.log("\n[2/7] Deploying GameCore (VRF integration)...");
        gameCore = new GameCore(
            LINK_TOKEN,
            VRF_COORDINATOR,
            SUBSCRIPTION_ID
        );
        console.log("  GameCore deployed at:", address(gameCore));

        console.log("\n[3/7] Deploying BettingCore...");
        bettingCore = new BettingCore(
            address(gameCore),  // _gameEngine parameter
            protocolTreasury,   // _protocolTreasury parameter
            deployer            // _initialOwner parameter
        );
        console.log("  BettingCore deployed at:", address(bettingCore));

        console.log("\n[4/7] Deploying SeasonPredictor...");
        seasonPredictor = new SeasonPredictor(
            address(lbtToken),
            address(gameCore),
            deployer  // Initial owner
        );
        console.log("  SeasonPredictor deployed at:", address(seasonPredictor));

        console.log("\n[5/7] Deploying SwapRouter (PancakeSwap)...");
        swapRouter = new SwapRouter(
            address(lbtToken),
            WBNB,
            PANCAKE_ROUTER
        );
        console.log("  SwapRouter deployed at:", address(swapRouter));

        console.log("\n[6/7] Deploying BettingRouter...");
        bettingRouter = new BettingRouter(
            address(bettingCore),
            address(lbtToken),
            address(swapRouter),
            deployer  // Initial owner
        );
        console.log("  BettingRouter deployed at:", address(bettingRouter));

        console.log("\n[7/7] Deploying TokenRegistry...");
        tokenRegistry = new TokenRegistry(deployer);
        console.log("  TokenRegistry deployed at:", address(tokenRegistry));

        // Configuration Phase
        console.log("\n========================================");
        console.log("Configuration Phase");
        console.log("========================================");

        console.log("\n[1/5] Setting LBT token in BettingCore...");
        bettingCore.setLBTToken(address(lbtToken));
        console.log("  LBT token set successfully");

        console.log("\n[2/5] Setting SeasonPredictor in BettingCore...");
        bettingCore.setSeasonPredictor(address(seasonPredictor));
        console.log("  SeasonPredictor set successfully");

        console.log("\n[3/5] Setting BettingCore in SeasonPredictor...");
        seasonPredictor.setBettingCore(address(bettingCore));
        console.log("  BettingCore set successfully");

        console.log("\n[4/5] Setting BettingCore in GameCore...");
        gameCore.setBettingCore(address(bettingCore));
        console.log("  BettingCore set in GameCore");

        console.log("\n[5/5] Seeding protocol reserves...");
        lbtToken.approve(address(bettingCore), INITIAL_RESERVES);
        bettingCore.depositReserves(INITIAL_RESERVES);
        console.log("  Protocol reserves seeded with", INITIAL_RESERVES / 1e18, "LBT");

        // Note: Token registration in TokenRegistry requires pool address
        // Can be done post-deployment: tokenRegistry.addToken(lbt, pool, isStablecoin, minBet, maxBet)

        vm.stopBroadcast();

        // Print deployment summary
        _printDeploymentSummary();

        // Print post-deployment instructions
        _printPostDeploymentInstructions();
    }

    function _printDeploymentSummary() internal view {
        console.log("\n========================================");
        console.log("DEPLOYMENT SUMMARY");
        console.log("========================================");
        console.log("\nCore Contracts:");
        console.log("  LBT Token:        ", address(lbtToken));
        console.log("  GameCore:         ", address(gameCore));
        console.log("  BettingCore:      ", address(bettingCore));

        console.log("\nPeriphery Contracts:");
        console.log("  SeasonPredictor:  ", address(seasonPredictor));
        console.log("  BettingRouter:    ", address(bettingRouter));
        console.log("  SwapRouter:       ", address(swapRouter));
        console.log("  TokenRegistry:    ", address(tokenRegistry));

        console.log("\nConfiguration:");
        console.log("  Protocol Treasury:", protocolTreasury);
        console.log("  Protocol Reserves:", INITIAL_RESERVES / 1e18, "LBT");
        console.log("  Deployer Balance: ", lbtToken.balanceOf(deployer) / 1e18, "LBT");

        console.log("\n========================================");
    }

    function _printPostDeploymentInstructions() internal view {
        console.log("\nPOST-DEPLOYMENT STEPS");
        console.log("========================================");

        console.log("\n1. VRF Subscription Setup:");
        console.log("   - Go to https://vrf.chain.link");
        console.log("   - Add GameCore as consumer:", address(gameCore));
        console.log("   - Fund subscription with LINK tokens");

        console.log("\n2. Initialize First Season:");
        console.log("   - Call: gameCore.initializeSeason()");

        console.log("\n3. Start First Round:");
        console.log("   - Call: gameCore.startRound()");
        console.log("   - This will automatically seed BettingCore");

        console.log("\n4. Extract ABIs:");
        console.log("   - Run: node extract-abis.js");

        console.log("\n5. Save Addresses:");
        console.log("   - Create deployment.json with all addresses");

        console.log("\n6. Verify Contracts (if not auto-verified):");
        console.log("   forge verify-contract <address> <contract> \\");
        console.log("     --chain-id <chainid> \\");
        console.log("     --watch");

        console.log("\n========================================");
        console.log("Deployment Complete! Save the addresses above.");
        console.log("========================================\n");
    }

    // Helper function to create deployment.json
    function exportDeployment() public view returns (string memory) {
        return string(abi.encodePacked(
            '{\n',
            '  "network": "', vm.toString(block.chainid), '",\n',
            '  "deployer": "', vm.toString(deployer), '",\n',
            '  "contracts": {\n',
            '    "lbtToken": "', vm.toString(address(lbtToken)), '",\n',
            '    "gameCore": "', vm.toString(address(gameCore)), '",\n',
            '    "bettingCore": "', vm.toString(address(bettingCore)), '",\n',
            '    "seasonPredictor": "', vm.toString(address(seasonPredictor)), '",\n',
            '    "bettingRouter": "', vm.toString(address(bettingRouter)), '",\n',
            '    "swapRouter": "', vm.toString(address(swapRouter)), '",\n',
            '    "tokenRegistry": "', vm.toString(address(tokenRegistry)), '"\n',
            '  },\n',
            '  "config": {\n',
            '    "protocolTreasury": "', vm.toString(protocolTreasury), '",\n',
            '    "initialReserves": "', vm.toString(INITIAL_RESERVES), '"\n',
            '  }\n',
            '}\n'
        ));
    }
}

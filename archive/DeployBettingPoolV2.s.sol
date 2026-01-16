// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/GameEngineV2_5.sol";
import "../src/BettingPoolV2.sol";
import "../src/LiquidityPool.sol";
import "../src/LeagueToken.sol";

contract DeployBettingPoolV2 is Script {
    function run() external {
        // Sepolia VRF v2.5 Subscription-based addresses
        address LINK_SEPOLIA = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
        uint256 VRF_SUBSCRIPTION_ID = 61649595677561345965106459863811444540779581533062824797239463574313081724811;

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying Pool-Based Betting System V2");
        console.log("========================================");
        console.log("Deploying with account:", deployer);
        console.log("Account balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy GameEngine (VRF v2.5 Subscription-based)
        console.log("\n1. Deploying GameEngine (VRF v2.5 Subscription-based)...");
        GameEngine gameEngine = new GameEngine(LINK_SEPOLIA, VRF_SUBSCRIPTION_ID);
        console.log("GameEngine deployed at:", address(gameEngine));

        // 2. Deploy LeagueToken
        console.log("\n2. Deploying LeagueToken...");
        LeagueToken leagueToken = new LeagueToken(deployer);
        console.log("LeagueToken deployed at:", address(leagueToken));

        // 3. Deploy LiquidityPool
        console.log("\n3. Deploying LiquidityPool...");
        LiquidityPool liquidityPool = new LiquidityPool(
            address(leagueToken),
            deployer
        );
        console.log("LiquidityPool deployed at:", address(liquidityPool));

        // 4. Deploy BettingPoolV2 (Pool-Based System)
        console.log("\n4. Deploying BettingPoolV2 (Pool-Based Betting)...");
        BettingPoolV2 bettingPool = new BettingPoolV2(
            address(leagueToken),
            address(gameEngine),
            address(liquidityPool),
            deployer, // protocolTreasury
            deployer, // rewardsDistributor
            deployer  // initialOwner
        );
        console.log("BettingPoolV2 deployed at:", address(bettingPool));

        // 5. Link contracts
        console.log("\n5. Linking contracts...");
        liquidityPool.setAuthorizedCaller(address(bettingPool), true);
        console.log("LiquidityPool.setAuthorizedCaller() called");

        vm.stopBroadcast();

        // Log deployment summary
        console.log("\n========== DEPLOYMENT SUMMARY (V2) ==========");
        console.log("LeagueToken:      ", address(leagueToken));
        console.log("GameEngine:       ", address(gameEngine));
        console.log("LiquidityPool:    ", address(liquidityPool));
        console.log("BettingPoolV2:    ", address(bettingPool));

        console.log("\n========== VRF v2.5 SUBSCRIPTION CONFIGURATION ==========");
        console.log("LINK Token:                 ", LINK_SEPOLIA);
        console.log("VRF Subscription ID:        ", VRF_SUBSCRIPTION_ID);
        console.log("VRF Coordinator:             0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B");
        console.log("Payment Method:              Subscription-based (funding handled off-chain)");

        console.log("\n========== NEXT STEPS ==========");
        console.log("1. Register GameEngine as consumer in VRF Subscription:");
        console.log("   Go to: https://vrf.chain.link/sepolia");
        console.log("   Add Consumer: ", address(gameEngine));
        console.log("");
        console.log("2. Fund VRF Subscription with LINK:");
        console.log("   Get LINK from: https://faucets.chain.link/sepolia");
        console.log("   Subscription ID:", VRF_SUBSCRIPTION_ID);
        console.log("");
        console.log("3. Fund Protocol Reserve:");
        console.log("   cast send", address(leagueToken));
        console.log("     \"approve(address,uint256)\"");
        console.log("    ", address(bettingPool), "10000000000000000000000");
        console.log("     --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY");
        console.log("");
        console.log("   cast send", address(bettingPool));
        console.log("     \"fundProtocolReserve(uint256)\" 10000000000000000000000");
        console.log("     --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY");
        console.log("");
        console.log("4. Start Season & Round:");
        console.log("   cast send", address(gameEngine), "\"startSeason()\"");
        console.log("   cast send", address(gameEngine), "\"startRound()\"");
        console.log("");
        console.log("5. Export ABIs to frontend:");
        console.log("   node extract-abis.js");
        console.log("");
        console.log("6. Update frontend/lib/deployedAddresses.ts with:");
        console.log("   BettingPoolV2:", address(bettingPool));
        console.log("");
        console.log("\n** Pool-Based Betting System V2 Ready! **");
        console.log("Features: Infinite scalability, market-driven odds, pull-based claims");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/GameEngineV2_5.sol";
import "../src/BettingPoolV2_1.sol";
import "../src/LiquidityPoolV2.sol";
import "../src/LeagueToken.sol";

contract DeployGameEngineV2_5 is Script {
    function run() external {
        // Sepolia VRF v2.5 Subscription-based addresses
        address LINK_SEPOLIA = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
        uint256 VRF_SUBSCRIPTION_ID = 61649595677561345965106459863811444540779581533062824797239463574313081724811;

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying contracts with account:", deployer);
        console.log("Account balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy LeagueToken
        console.log("\n1. Deploying LeagueToken...");
        LeagueToken leagueToken = new LeagueToken(deployer);
        console.log("LeagueToken deployed at:", address(leagueToken));

        // 2. Deploy GameEngine with VRF v2.5 Subscription-based
        console.log("\n2. Deploying GameEngine (VRF v2.5 Subscription-based)...");
        GameEngine gameEngine = new GameEngine(
            LINK_SEPOLIA,
            VRF_SUBSCRIPTION_ID
        );
        console.log("GameEngine deployed at:", address(gameEngine));

        // 3. Deploy LiquidityPoolV2
        console.log("\n3. Deploying LiquidityPoolV2...");
        LiquidityPoolV2 liquidityPool = new LiquidityPoolV2(
            address(leagueToken),
            deployer
        );
        console.log("LiquidityPoolV2 deployed at:", address(liquidityPool));

        // 4. Deploy BettingPoolV2_1
        console.log("\n4. Deploying BettingPoolV2_1...");
        BettingPoolV2_1 bettingPool = new BettingPoolV2_1(
            address(leagueToken),
            address(gameEngine),
            address(liquidityPool),
            deployer, // protocolTreasury
            deployer, // rewardsDistributor
            deployer  // initialOwner
        );
        console.log("BettingPoolV2_1 deployed at:", address(bettingPool));

        // 5. Link contracts
        console.log("\n5. Linking contracts...");
        liquidityPool.setAuthorizedCaller(address(bettingPool), true);
        console.log("LiquidityPoolV2.setAuthorizedCaller() called");

        vm.stopBroadcast();

        // Log deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("LeagueToken:", address(leagueToken));
        console.log("GameEngine:", address(gameEngine));
        console.log("LiquidityPool:", address(liquidityPool));
        console.log("BettingPool:", address(bettingPool));
        console.log("\n=== VRF v2.5 SUBSCRIPTION CONFIGURATION ===");
        console.log("LINK Token:", LINK_SEPOLIA);
        console.log("VRF Subscription ID:", VRF_SUBSCRIPTION_ID);
        console.log("VRF Coordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B");
        console.log("Payment Method: Direct Funding (no subscription needed)");
        console.log("\n=== NEXT STEPS ===");
        console.log("1. Fund GameEngine with LINK: Send LINK to", address(gameEngine));
        console.log("2. Get LINK from faucet: https://faucets.chain.link/sepolia");
        console.log("3. Or send ETH to GameEngine for native payment (set useNativePayment=true)");
        console.log("4. Call gameEngine.startSeason()");
        console.log("5. Call gameEngine.startRound()");
        console.log("6. Wait 15 minutes, then call gameEngine.requestMatchResults()");
        console.log("\nNo subscription management needed with VRF v2.5 Direct Funding!");
    }
}

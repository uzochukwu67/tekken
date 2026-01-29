// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/GameEngineV2_5.sol";
import "../src/BettingPoolV2_1.sol";
import "../src/LiquidityPoolV2.sol";
import "../src/SeasonPredictorV2.sol";
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

        // 5. Deploy SeasonPredictorV2
        console.log("\n5. Deploying SeasonPredictorV2...");
        SeasonPredictorV2 seasonPredictor = new SeasonPredictorV2(
            address(leagueToken),
            address(gameEngine),
            deployer  // initialOwner
        );
        console.log("SeasonPredictorV2 deployed at:", address(seasonPredictor));

        // 6. Link contracts
        console.log("\n6. Linking contracts...");
        liquidityPool.setAuthorizedCaller(address(bettingPool), true);
        console.log("LiquidityPoolV2.setAuthorizedCaller(bettingPool) called");

        gameEngine.setBettingPool(address(bettingPool));
        console.log("GameEngine.setBettingPool() called");

        vm.stopBroadcast();

        // Log deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("LeagueToken:", address(leagueToken));
        console.log("GameEngine:", address(gameEngine));
        console.log("LiquidityPool:", address(liquidityPool));
        console.log("BettingPool:", address(bettingPool));
        console.log("SeasonPredictor:", address(seasonPredictor));
        console.log("\n=== VRF v2.5 SUBSCRIPTION CONFIGURATION ===");
        console.log("LINK Token:", LINK_SEPOLIA);
        console.log("VRF Subscription ID:", VRF_SUBSCRIPTION_ID);
        console.log("VRF Coordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B");
        console.log("GameEngine Address:", address(gameEngine));
        console.log("\n=== CRITICAL: VRF SUBSCRIPTION SETUP ===");
        console.log("BEFORE using the system, you MUST:");
        console.log("1. Go to https://vrf.chain.link");
        console.log("2. Connect your wallet and switch to Sepolia network");
        console.log("3. Find subscription ID:", VRF_SUBSCRIPTION_ID);
        console.log("4. Add GameEngine as a consumer:", address(gameEngine));
        console.log("5. Fund the subscription with LINK (minimum 2 LINK recommended)");
        console.log("6. Get LINK from: https://faucets.chain.link/sepolia");
        console.log("\n=== SYSTEM USAGE FLOW ===");
        console.log("1. Call gameEngine.startSeason()");
        console.log("2. Call gameEngine.startRound()");
        console.log("3. Call bettingPool.seedRoundPools(roundId) to lock odds (virtual - no transfer!)");
        console.log("4. Users can now place bets via bettingPool.placeBet()");
        console.log("5. Wait 3 hours (ROUND_DURATION), then call gameEngine.requestMatchResults(false)");
        console.log("6. VRF will callback with results (wait ~1-2 minutes)");
        console.log("7. Call bettingPool.settleRound(roundId) [OWNER ONLY]");
        console.log("8. Users claim winnings via bettingPool.claimWinnings(betId, minPayout)");
        console.log("9. Call bettingPool.finalizeRoundRevenue(roundId) to distribute profits to LP");
        console.log("\n=== EMERGENCY SETTLEMENT ===");
        console.log("If VRF fails after 2 hours, call gameEngine.emergencySettleRound(roundId, seed)");
        console.log("\n=== IMPORTANT NOTES ===");
        console.log("- Betting odds are managed by BettingPool, NOT GameEngine");
        console.log("- Get odds: bettingPool.getRoundOdds(roundId) or getMatchOdds(roundId, matchIndex)");
        console.log("- Odds range: 1.3x - 1.7x (compressed from parimutuel)");
        console.log("- Round MUST be seeded before users can bet (locks odds via virtual pools)");
        console.log("- settleRound() requires OWNER access (prevents unauthorized settlement)");
        console.log("- Season rewards: distributeSeasonRewards() for top predictors");
        console.log("- LP withdrawals: Use partialWithdrawal() if liquidity is locked in active rounds");
    }
}

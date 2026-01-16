# BettingPoolV2_1 - Governance-Ready Version

## Summary of Changes

This document outlines the minimal changes needed to make BettingPoolV2_1.sol governance-ready for testnet deployment.

## Key Changes Overview

1. **Inherit from BettingPoolGovernance** instead of just Ownable
2. **Remove hardcoded constants** (now governable parameters)
3. **Add pause protection** to critical functions
4. **Add max bet check** (optional whale protection)
5. **Use governance variables** instead of constants

---

## Detailed Changes

### Change 1: Import Governance Contract

**Line 5-6** - Add import:

```solidity
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
+ import "./BettingPoolGovernance.sol";  // ADD THIS
```

### Change 2: Update Contract Declaration

**Line 26** - Change inheritance:

```solidity
- contract BettingPoolV2_1 is Ownable, ReentrancyGuard {
+ contract BettingPoolV2_1 is BettingPoolGovernance, ReentrancyGuard {
```

### Change 3: Remove Hardcoded Constants

**Lines 36-88** - DELETE these constants (now inherited from governance):

```solidity
// DELETE THESE (now in BettingPoolGovernance):
- uint256 public constant PROTOCOL_CUT = 4500;
- uint256 public constant SEASON_POOL_SHARE = 200;
- uint256 public constant SEED_HOME_POOL = 120 ether;
- uint256 public constant SEED_AWAY_POOL = 80 ether;
- uint256 public constant SEED_DRAW_POOL = 100 ether;
- uint256 public constant SEED_PER_MATCH = 300 ether;
- uint256 public constant SEED_PER_ROUND = SEED_PER_MATCH * 10;
- uint256 public constant MIN_IMBALANCE_FOR_FULL_BONUS = 4000;

// KEEP THESE (parlay-specific logic, will be made governable):
uint256 public constant WINNER_SHARE = 5500;
uint256 public constant BONUS_2_MATCH = 500;
uint256 public constant BONUS_3_MATCH = 1000;
uint256 public constant BONUS_4_PLUS = 2000;
uint256 public constant PARLAY_MULTIPLIER_1_LEG = 1e18;
uint256 public constant PARLAY_MULTIPLIER_2_LEGS = 12e17;
uint256 public constant PARLAY_MULTIPLIER_3_LEGS = 15e17;
uint256 public constant PARLAY_MULTIPLIER_4_LEGS = 2e18;
uint256 public constant PARLAY_MULTIPLIER_5_PLUS = 25e17;
uint256 public constant COUNT_TIER_1 = 10;
uint256 public constant COUNT_TIER_2 = 20;
... (keep all count/tier constants for now)
```

### Change 4: Add Pause Protection to placeBet()

Find the `placeBet()` function (around line 300) and add modifier:

```solidity
function placeBet(
    uint256[] calldata matchIndices,
    uint8[] calldata outcomes,
    uint256 totalAmount
- ) external nonReentrant {
+ ) external nonReentrant whenNotPaused {  // ADD whenNotPaused

+     // Optional: Check max bet per match
+     if (maxBetPerMatch > 0) {
+         uint256 avgBetPerMatch = totalAmount / matchIndices.length;
+         require(avgBetPerMatch <= maxBetPerMatch, "Bet exceeds maximum");
+     }

    // ... rest of function
}
```

### Change 5: Update Revenue Distribution

Find revenue calculation (around line 700-750) and replace constants with governance variables:

```solidity
// BEFORE:
uint256 protocolRevenue = (totalRevenue * PROTOCOL_CUT) / 10000;
uint256 seasonRevenue = (totalRevenue * SEASON_POOL_SHARE) / 10000;

// AFTER:
uint256 protocolRevenue = (totalRevenue * protocolCutBps) / 10000;
uint256 seasonRevenue = (totalRevenue * seasonCutBps) / 10000;
```

### Change 6: Update Seeding Logic

In `seedRoundPools()` function (around line 437-465):

```solidity
function seedRoundPools(uint256 roundId) external onlyOwner {
    // ... existing validation ...

    uint256 totalSeedAmount = 0;

    // Seed each match with DIFFERENTIATED amounts
    for (uint256 matchIndex = 0; matchIndex < 10; matchIndex++) {
        (uint256 homeSeed, uint256 awaySeed, uint256 drawSeed) =
            _calculateMatchSeeds(roundId, matchIndex);

        MatchPool storage pool = accounting.matchPools[matchIndex];
        pool.homeWinPool = homeSeed;
        pool.awayWinPool = awaySeed;
        pool.drawPool = drawSeed;
-       pool.totalPool = SEED_PER_MATCH;  // BEFORE
+       pool.totalPool = seedPerMatch;     // AFTER (governance variable)

        totalSeedAmount += pool.totalPool;
        accounting.totalBetVolume += pool.totalPool;
    }

    // ... rest of function
}
```

### Change 7: Update Dynamic Seeding Functions

In `_calculatePseudoRandomSeeds()` (around line 270):

```solidity
function _calculatePseudoRandomSeeds(...) internal pure returns (...) {
-   uint256 totalSeed = SEED_PER_MATCH;  // BEFORE
+   uint256 totalSeed = seedPerMatch;     // AFTER

    // ... rest of function
}
```

In `_calculateStatsBasedSeeds()` (around line 340):

```solidity
function _calculateStatsBasedSeeds(...) internal view returns (...) {
-   uint256 totalSeed = SEED_PER_MATCH;  // BEFORE
+   uint256 totalSeed = seedPerMatch;     // AFTER

    // ... rest of function
}
```

**WAIT!** These functions are marked as `pure` but now need to access state variable `seedPerMatch`.

**Fix**: Change function visibility:

```solidity
- function _calculatePseudoRandomSeeds(...) internal pure returns (...) {
+ function _calculatePseudoRandomSeeds(...) internal view returns (...) {

    uint256 totalSeed = seedPerMatch;  // Now accessible
    // ... rest of function
}
```

### Change 8: Update Imbalance Check

Find imbalance threshold usage (around line 800-900):

```solidity
// BEFORE:
if (poolImbalanceBps >= MIN_IMBALANCE_FOR_FULL_BONUS) {
    // ... bonus logic
}

// AFTER:
if (poolImbalanceBps >= imbalanceThresholdBps) {
    // ... bonus logic
}
```

---

## Constructor Changes

Since we're inheriting from BettingPoolGovernance, the constructor needs to initialize both:

```solidity
constructor(
    address _leagueToken,
    address _gameEngine,
    address _liquidityPool,
    address _protocolTreasury,
    address _rewardsDistributor,
    address initialOwner
- ) Ownable(initialOwner) {
+ ) BettingPoolGovernance() Ownable(initialOwner) {

    leagueToken = IERC20(_leagueToken);
    gameEngine = IGameEngine(_gameEngine);
    liquidityPool = ILiquidityPool(_liquidityPool);
    protocolTreasury = _protocolTreasury;
    rewardsDistributor = _rewardsDistributor;
    currentRoundId = 0;
}
```

---

## Testing the Governance Integration

Create test file: `test/BettingPoolV2_1_Governance.t.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BettingPoolV2_1.sol";
import "../src/GameEngine.sol";
import "../src/LeagueToken.sol";
import "../src/LiquidityPool.sol";

contract BettingPoolV2_1_GovernanceTest is Test {
    BettingPoolV2_1 public bettingPool;
    GameEngine public gameEngine;
    LeagueToken public leagueToken;
    LiquidityPool public liquidityPool;

    address public owner = address(1);
    address public user = address(2);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy contracts
        leagueToken = new LeagueToken(owner);
        liquidityPool = new LiquidityPool(address(leagueToken), owner);
        gameEngine = new GameEngine(address(0), 1);
        bettingPool = new BettingPoolV2_1(
            address(leagueToken),
            address(gameEngine),
            address(liquidityPool),
            owner,
            owner,
            owner
        );

        // Fund protocol reserve
        leagueToken.approve(address(bettingPool), 1000000 ether);
        bettingPool.fundProtocolReserve(1000000 ether);

        vm.stopPrank();
    }

    function testTimelockGovernance() public {
        // Propose change
        vm.prank(owner);
        bettingPool.proposeParameterChange("protocolCutBps", 3500);

        // Check pending
        (uint256 value, uint256 executeAfter, bool exists) =
            bettingPool.getPendingChange("protocolCutBps");

        assertTrue(exists);
        assertEq(value, 3500);

        // Try to execute immediately (should fail)
        vm.prank(owner);
        vm.expectRevert();
        bettingPool.executeParameterChange("protocolCutBps");

        // Wait 48 hours
        vm.warp(executeAfter + 1);

        // Execute change
        vm.prank(owner);
        bettingPool.executeParameterChange("protocolCutBps");

        // Verify
        (uint256 newCut,,,,,,,) = bettingPool.getGovernanceParameters();
        assertEq(newCut, 3500);
    }

    function testEmergencyPause() public {
        // Start season and round
        vm.prank(owner);
        gameEngine.startSeason();

        vm.prank(owner);
        gameEngine.startRound();
        uint256 roundId = gameEngine.getCurrentRound();

        // Seed pools
        vm.prank(owner);
        bettingPool.seedRoundPools(roundId);

        // Pause
        vm.prank(owner);
        bettingPool.pause();

        // Fund user
        vm.prank(owner);
        leagueToken.transfer(user, 1000 ether);

        // Try to bet (should fail)
        vm.startPrank(user);
        leagueToken.approve(address(bettingPool), 100 ether);

        uint256[] memory matches = new uint256[](1);
        matches[0] = 0;
        uint8[] memory outcomes = new uint8[](1);
        outcomes[0] = 1;

        vm.expectRevert();
        bettingPool.placeBet(matches, outcomes, 100 ether);

        vm.stopPrank();

        // Unpause
        vm.prank(owner);
        bettingPool.unpause();

        // Now bet works
        vm.startPrank(user);
        bettingPool.placeBet(matches, outcomes, 100 ether);
        vm.stopPrank();
    }

    function testMaxBetLimit() public {
        // Set max bet to 500 LEAGUE per match
        vm.prank(owner);
        bettingPool.setMaxBetPerMatch(500 ether);

        // Start season and round
        vm.prank(owner);
        gameEngine.startSeason();

        vm.prank(owner);
        gameEngine.startRound();
        uint256 roundId = gameEngine.getCurrentRound();

        vm.prank(owner);
        bettingPool.seedRoundPools(roundId);

        // Fund user
        vm.prank(owner);
        leagueToken.transfer(user, 10000 ether);

        vm.startPrank(user);
        leagueToken.approve(address(bettingPool), 10000 ether);

        // Try to bet 1000 LEAGUE (should fail - exceeds 500 max)
        uint256[] memory matches = new uint256[](1);
        matches[0] = 0;
        uint8[] memory outcomes = new uint8[](1);
        outcomes[0] = 1;

        vm.expectRevert("Bet exceeds maximum");
        bettingPool.placeBet(matches, outcomes, 1000 ether);

        // Bet 500 LEAGUE (should succeed)
        bettingPool.placeBet(matches, outcomes, 500 ether);

        vm.stopPrank();
    }

    function testParameterBounds() public {
        // Try to set protocol cut too high
        vm.prank(owner);
        vm.expectRevert();
        bettingPool.proposeParameterChange("protocolCutBps", 6000); // > 50% max

        // Try to set too low
        vm.prank(owner);
        vm.expectRevert();
        bettingPool.proposeParameterChange("protocolCutBps", 500); // < 10% min

        // Valid range should work
        vm.prank(owner);
        bettingPool.proposeParameterChange("protocolCutBps", 3500);
    }

    function testSeedDistribution() public {
        // Update seed distribution
        vm.prank(owner);
        bettingPool.updateSeedDistribution(
            150 ether,  // Home
            80 ether,   // Away
            70 ether    // Draw
        );
        // Total = 300 ether (matches default seedPerMatch)

        // Try invalid sum (should fail)
        vm.prank(owner);
        vm.expectRevert();
        bettingPool.updateSeedDistribution(
            150 ether,
            80 ether,
            80 ether  // Total = 310, doesn't match seedPerMatch
        );
    }
}
```

---

## Deployment Script

Create: `script/DeployGovernance.s.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/BettingPoolV2_1.sol";
import "../src/GameEngine.sol";
import "../src/LeagueToken.sol";
import "../src/LiquidityPool.sol";

contract DeployGovernance is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // CRITICAL: Use multisig for owner, NOT deployer EOA
        address multisig = vm.envAddress("MULTISIG_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy core contracts
        LeagueToken leagueToken = new LeagueToken(multisig);
        LiquidityPool liquidityPool = new LiquidityPool(
            address(leagueToken),
            multisig
        );

        GameEngine gameEngine = new GameEngine(
            vm.envAddress("LINK_TOKEN"),
            vm.envUint("VRF_SUBSCRIPTION_ID")
        );

        // Deploy governance-enabled betting pool
        BettingPoolV2_1 bettingPool = new BettingPoolV2_1(
            address(leagueToken),
            address(gameEngine),
            address(liquidityPool),
            multisig,  // protocol treasury
            multisig,  // rewards distributor
            multisig   // owner (MUST be multisig!)
        );

        vm.stopBroadcast();

        console.log("Deployed BettingPoolV2_1 with governance:", address(bettingPool));
        console.log("Owner (multisig):", multisig);
        console.log("");
        console.log("VERIFY OWNER IS MULTISIG, NOT EOA!");
    }
}
```

---

## Pre-Testnet Checklist

Before deploying to testnet:

- [ ] All constants replaced with governance variables
- [ ] `whenNotPaused` modifier added to `placeBet()`
- [ ] Max bet check implemented (optional)
- [ ] Constructor properly chains to BettingPoolGovernance
- [ ] All tests pass: `forge test`
- [ ] Governance tests pass: `forge test --match-contract Governance`
- [ ] Owner set to multisig (NOT EOA) in deployment script
- [ ] Timelock duration is 48 hours
- [ ] Parameter bounds are reasonable

---

## Risk Assessment

### HIGH RISK ⚠️
- **Owner control**: Can pause, change parameters, withdraw reserve
  - **Mitigation**: Use 3-of-5 multisig for owner

### MEDIUM RISK ⚠️
- **Parameter changes**: Bad values could break economics
  - **Mitigation**: 48-hour timelock + parameter bounds

### LOW RISK ✅
- **Emergency pause**: Blocks all betting temporarily
  - **Mitigation**: Only owner can pause, transparent on-chain

---

## Summary

**What You Get:**
- ✅ Adjustable parameters without redeployment
- ✅ Emergency pause for exploits
- ✅ Whale protection (max bet limits)
- ✅ Community protection (48-hour timelock)
- ✅ Safety bounds on all parameters
- ✅ Transparent on-chain governance

**What You Need to Do:**
1. Create `BettingPoolGovernance.sol` (already done ✅)
2. Modify `BettingPoolV2_1.sol` (changes outlined above)
3. Test governance functions thoroughly
4. Deploy with multisig owner (NOT EOA!)
5. Monitor parameter changes on testnet

**Ready for testnet deployment!** 🚀

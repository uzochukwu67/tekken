# Governance Integration Guide for BettingPoolV2_1

## Overview

This guide shows how to integrate the minimal governance system into BettingPoolV2_1.sol before testnet deployment.

## Features Added

### 1. **Timelock Governance** (48-hour delay)
- Protocol cut percentage (10-50% range)
- Seed amounts per match (100-1000 LEAGUE range)
- Round duration (5-60 minutes range)
- Imbalance threshold (20-60% range)
- Parlay multipliers (1.5x-20x range)

### 2. **Emergency Controls** (No timelock)
- Pause/unpause betting
- Set maximum bet size per match
- Withdraw protocol reserve (if needed)

### 3. **Safety Mechanisms**
- Parameter bounds prevent extreme values
- 48-hour timelock gives community time to react
- Seed distribution validation (must sum correctly)

---

## Option A: Quick Integration (Inheritance)

### Step 1: Update BettingPoolV2_1.sol

Change the contract declaration to inherit from governance:

```solidity
import "./BettingPoolGovernance.sol";

contract BettingPoolV2_1 is BettingPoolGovernance {
    // ... existing code ...
}
```

### Step 2: Replace Constants with Governance Variables

Remove these lines:
```solidity
// DELETE THESE:
uint256 public constant PROTOCOL_CUT_BPS = 3000;
uint256 public constant SEASON_CUT_BPS = 200;
uint256 public constant LP_BONUS_BPS = 500;
uint256 public constant SEED_HOME_POOL = 120 ether;
uint256 public constant SEED_AWAY_POOL = 80 ether;
uint256 public constant SEED_DRAW_POOL = 100 ether;
uint256 public constant SEED_PER_MATCH = 300 ether;
uint256 public constant ROUND_DURATION = 15 minutes;
uint256 public constant POOL_IMBALANCE_THRESHOLD_BPS = 4000;
```

These are now inherited from `BettingPoolGovernance` and are governable!

### Step 3: Add Pause Check to Betting Functions

Add `whenNotPaused` modifier to critical functions:

```solidity
function placeBet(
    uint256[] calldata matchIndices,
    uint8[] calldata outcomes,
    uint256 totalAmount
) external whenNotPaused {  // ADD THIS
    // ... existing code ...
}
```

### Step 4: Use Governance Variables

Replace constant references:

```solidity
// BEFORE:
uint256 protocolRevenue = (totalRevenue * PROTOCOL_CUT_BPS) / 10000;

// AFTER:
uint256 protocolRevenue = (totalRevenue * protocolCutBps) / 10000;
```

### Step 5: Add Max Bet Check (Optional)

```solidity
function placeBet(...) external whenNotPaused {
    // ... existing validation ...

    // NEW: Check max bet per match
    if (maxBetPerMatch > 0) {
        uint256 avgBetPerMatch = totalAmount / matchIndices.length;
        require(avgBetPerMatch <= maxBetPerMatch, "Bet exceeds max per match");
    }

    // ... rest of function ...
}
```

---

## Option B: Standalone Deployment (No Code Changes)

Deploy `BettingPoolGovernance` as a separate contract and use it to store parameters that you manually sync with BettingPoolV2_1 during redeployment.

**Pros**: No changes to BettingPoolV2_1
**Cons**: Manual process, parameters not automatically enforced

---

## Usage Examples

### Example 1: Change Protocol Cut from 30% → 35%

```solidity
// Step 1: Propose change (owner)
bettingPool.proposeParameterChange("protocolCutBps", 3500);
// ⏱️ Timelock starts: 48 hours

// Step 2: Wait 48 hours...

// Step 3: Execute change (owner)
bettingPool.executeParameterChange("protocolCutBps");
// ✅ Protocol cut now 35%
```

### Example 2: Emergency Pause

```solidity
// Immediate effect, no timelock
bettingPool.pause();
// ❌ All betting now blocked

// Later, unpause
bettingPool.unpause();
// ✅ Betting resumed
```

### Example 3: Update Seed Distribution

```solidity
// Change odds by adjusting seed distribution
// Example: Make home wins more favorable
bettingPool.updateSeedDistribution(
    150 ether,  // Home pool (was 120)
    80 ether,   // Away pool (unchanged)
    70 ether    // Draw pool (was 100)
);
// Must sum to 300 ether (current seedPerMatch)
```

### Example 4: Update Parlay Multiplier

```solidity
// Make 3-leg parlays more attractive
bettingPool.updateParlayMultiplier(3, 5.0e18);  // 4.0x → 5.0x
```

### Example 5: Set Max Bet (Whale Protection)

```solidity
// Prevent single bets over 10,000 LEAGUE per match
bettingPool.setMaxBetPerMatch(10000 ether);
```

### Example 6: Check Pending Changes

```solidity
(uint256 value, uint256 executeAfter, bool exists) =
    bettingPool.getPendingChange("protocolCutBps");

if (exists) {
    uint256 hoursLeft = (executeAfter - block.timestamp) / 3600;
    console.log("Change pending, executable in", hoursLeft, "hours");
}
```

---

## Complete Integration Diff

Here's what changes in BettingPoolV2_1.sol:

```diff
+ import "./BettingPoolGovernance.sol";

- contract BettingPoolV2_1 is Ownable {
+ contract BettingPoolV2_1 is BettingPoolGovernance {

- uint256 public constant PROTOCOL_CUT_BPS = 3000;
- uint256 public constant SEASON_CUT_BPS = 200;
- uint256 public constant LP_BONUS_BPS = 500;
- uint256 public constant SEED_HOME_POOL = 120 ether;
- uint256 public constant SEED_AWAY_POOL = 80 ether;
- uint256 public constant SEED_DRAW_POOL = 100 ether;
- uint256 public constant SEED_PER_MATCH = 300 ether;
- uint256 public constant ROUND_DURATION = 15 minutes;
- uint256 public constant POOL_IMBALANCE_THRESHOLD_BPS = 4000;
+ // These are now inherited from BettingPoolGovernance

  function placeBet(
      uint256[] calldata matchIndices,
      uint8[] calldata outcomes,
      uint256 totalAmount
- ) external {
+ ) external whenNotPaused {

+     // Optional: Max bet check
+     if (maxBetPerMatch > 0) {
+         uint256 avgBetPerMatch = totalAmount / matchIndices.length;
+         require(avgBetPerMatch <= maxBetPerMatch, "Bet exceeds max");
+     }

      // ... rest of function uses governance variables ...

-     uint256 protocolRevenue = (totalRevenue * PROTOCOL_CUT_BPS) / 10000;
+     uint256 protocolRevenue = (totalRevenue * protocolCutBps) / 10000;

-     uint256 seasonRevenue = (totalRevenue * SEASON_CUT_BPS) / 10000;
+     uint256 seasonRevenue = (totalRevenue * seasonCutBps) / 10000;

-     uint256 lpBonus = (totalRevenue * LP_BONUS_BPS) / 10000;
+     uint256 lpBonus = (totalRevenue * lpBonusBps) / 10000;
  }

  function seedRoundPools(uint256 roundId) external onlyOwner {
      // ... existing code ...

      for (uint256 i = 0; i < 10; i++) {
          (uint256 homeSeed, uint256 awaySeed, uint256 drawSeed) =
              _calculateMatchSeeds(roundId, i);

          // Seed pools use governance variables
          pool.homeWinPool = homeSeed;
          pool.awayWinPool = awaySeed;
          pool.drawPool = drawSeed;
-         pool.totalPool = SEED_PER_MATCH;
+         pool.totalPool = seedPerMatch;
      }
  }

  function _calculatePseudoRandomSeeds(...) internal pure returns (...) {
-     uint256 totalSeed = SEED_PER_MATCH;
+     uint256 totalSeed = seedPerMatch;
      // ... rest of function ...
  }

  function _calculateStatsBasedSeeds(...) internal view returns (...) {
-     uint256 totalSeed = SEED_PER_MATCH;
+     uint256 totalSeed = seedPerMatch;
      // ... rest of function ...
  }
```

---

## Testing Governance

```solidity
// test/BettingPoolV2_1_Governance.t.sol

function testTimelockChange() public {
    // Propose change
    vm.prank(owner);
    bettingPool.proposeParameterChange("protocolCutBps", 3500);

    // Try to execute immediately (should fail)
    vm.prank(owner);
    vm.expectRevert(BettingPoolGovernance.TimelockNotExpired.selector);
    bettingPool.executeParameterChange("protocolCutBps");

    // Wait 48 hours
    vm.warp(block.timestamp + 48 hours + 1);

    // Execute change
    vm.prank(owner);
    bettingPool.executeParameterChange("protocolCutBps");

    // Verify change
    (uint256 protocolCut,,,,,,,) = bettingPool.getGovernanceParameters();
    assertEq(protocolCut, 3500);
}

function testEmergencyPause() public {
    vm.prank(owner);
    bettingPool.pause();

    // Try to place bet (should fail)
    uint256[] memory matches = new uint256[](1);
    matches[0] = 0;
    uint8[] memory outcomes = new uint8[](1);
    outcomes[0] = 1;

    vm.expectRevert(BettingPoolGovernance.ContractPaused.selector);
    bettingPool.placeBet(matches, outcomes, 100 ether);

    // Unpause
    vm.prank(owner);
    bettingPool.unpause();

    // Now bet works
    bettingPool.placeBet(matches, outcomes, 100 ether);
}

function testParameterBounds() public {
    // Try to set protocol cut too high (should fail)
    vm.prank(owner);
    vm.expectRevert(BettingPoolGovernance.ParameterOutOfBounds.selector);
    bettingPool.proposeParameterChange("protocolCutBps", 6000); // 60% > MAX (50%)
}
```

---

## Deployment Checklist

Before testnet:

- [ ] Integrate BettingPoolGovernance into BettingPoolV2_1
- [ ] Replace all constant references with governance variables
- [ ] Add `whenNotPaused` modifier to `placeBet()`
- [ ] Add max bet check (optional)
- [ ] Test timelock functionality
- [ ] Test emergency pause
- [ ] Test parameter bounds
- [ ] Verify seed distribution validation
- [ ] Deploy with owner set to multisig/DAO (NOT EOA)

---

## Security Considerations

### 1. Owner Control
**CRITICAL**: Set owner to a multisig or DAO, NOT a single EOA (externally owned account)

**Why**: Owner can pause betting, change parameters, withdraw reserve

**Recommendation**: Use Gnosis Safe with 3-of-5 multisig

### 2. Timelock Protection
**48-hour delay** gives community time to:
- Review proposed changes
- Exit positions if they disagree
- Coordinate governance response

### 3. Parameter Bounds
All parameters have min/max ranges to prevent:
- Setting protocol cut to 100% (would steal all user funds)
- Setting round duration to 1 second (would break game flow)
- Setting seed to 0 (would cause division by zero)

### 4. Emergency Pause
**Immediate effect** in case of:
- Discovered exploit
- Oracle failure
- Abnormal betting patterns

Use sparingly - pausing blocks all user activity.

---

## Future Governance (V3.0)

After testnet validation, consider:

1. **DAO Governance**
   - Token-weighted voting
   - Community proposals
   - On-chain execution

2. **Automated Parameter Adjustment**
   - Dynamic protocol cut based on volume
   - Auto-adjust imbalance threshold
   - ML-optimized seed distribution

3. **Timelocked Upgrades**
   - Proxy pattern for contract upgrades
   - 7-day timelock on proxy changes

---

## Summary

**Minimal governance gives you:**

✅ Ability to adjust parameters without redeployment
✅ Emergency controls for critical situations
✅ Community protection via timelock
✅ Safety bounds prevent catastrophic mistakes
✅ Transparency via on-chain proposals

**Next step**: Integrate into BettingPoolV2_1.sol and test thoroughly before testnet.

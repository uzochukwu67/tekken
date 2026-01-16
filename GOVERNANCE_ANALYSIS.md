# Governance & Admin Control Analysis

## Executive Summary

Currently, **all economic parameters are hardcoded as constants**, which means they **cannot be changed** after deployment without a full contract migration. This analysis identifies which parameters should be made governable and recommends governance mechanisms.

---

## 1. Current Admin Functions

### BettingPoolV2_1.sol

#### ✅ Existing Admin Controls
```solidity
function seedRoundPools(uint256 roundId) external onlyOwner
function setProtocolTreasury(address _treasury) external onlyOwner
function setRewardsDistributor(address _distributor) external onlyOwner
function fundProtocolReserve(uint256 amount) external onlyOwner
```

**Status**: Adequate for operational management

---

### GameEngineV2_5.sol

#### ✅ Existing Admin Controls
```solidity
function startSeason() external onlyOwner
function startRound() external onlyOwner
function requestMatchResults(bool enableNativePayment) external onlyOwner
function updateSubscriptionId(uint256 newSubId) external onlyOwner
function emergencySettleRound(uint256 roundId, uint256 seed) external onlyOwner
function withdrawLink() external onlyOwner
function withdrawNative(uint256 amount) external onlyOwner
```

**Status**: Adequate for operational management

---

## 2. Hardcoded Parameters Requiring Governance

### 🔴 CRITICAL: Economic Parameters (BettingPoolV2_1.sol)

These parameters directly affect profitability and should be governable:

#### Revenue Distribution (Lines 37-39)
```solidity
uint256 public constant PROTOCOL_CUT = 4500;        // 45% of losing bets
uint256 public constant WINNER_SHARE = 5500;        // 55% to winners
uint256 public constant SEASON_POOL_SHARE = 200;    // 2% to season pool
```

**Risk**: Fixed revenue split cannot adapt to market conditions
**Recommendation**: Make governable with limits (e.g., protocol cut: 30-50%)

#### Protocol Seeding (Lines 54-58)
```solidity
uint256 public constant SEED_HOME_POOL = 120 ether;
uint256 public constant SEED_AWAY_POOL = 80 ether;
uint256 public constant SEED_DRAW_POOL = 100 ether;
uint256 public constant SEED_PER_MATCH = 300 ether;
```

**Risk**: Cannot adjust liquidity provision based on market demand
**Recommendation**: Make governable with limits (e.g., 100-500 LEAGUE per match)

#### Count-Based Tier Multipliers (Lines 72-76)
```solidity
uint256 public constant COUNT_MULT_TIER_1 = 25e17;  // 2.5x (first 10)
uint256 public constant COUNT_MULT_TIER_2 = 22e17;  // 2.2x (next 10)
uint256 public constant COUNT_MULT_TIER_3 = 19e17;  // 1.9x (next 10)
uint256 public constant COUNT_MULT_TIER_4 = 16e17;  // 1.6x (next 10)
uint256 public constant COUNT_MULT_TIER_5 = 13e17;  // 1.3x (41+)
```

**Risk**: Cannot adjust FOMO incentives if user behavior changes
**Recommendation**: Make governable with limits (e.g., 1.1x - 3.0x range)

#### Reserve Decay Thresholds (Lines 79-88)
```solidity
uint256 public constant RESERVE_TIER_1 = 100000 ether;
uint256 public constant RESERVE_TIER_2 = 250000 ether;
uint256 public constant RESERVE_TIER_3 = 500000 ether;

uint256 public constant TIER_1_DECAY = 10000; // 100%
uint256 public constant TIER_2_DECAY = 8800;  // 88%
uint256 public constant TIER_3_DECAY = 7600;  // 76%
uint256 public constant TIER_4_DECAY = 6400;  // 64%
```

**Risk**: Fixed thresholds may not scale with protocol growth
**Recommendation**: Make governable based on total liquidity

#### Imbalance Gating (Lines 61-62)
```solidity
uint256 public constant MIN_IMBALANCE_FOR_FULL_BONUS = 4000; // 40%
uint256 public constant MIN_PARLAY_MULTIPLIER = 11e17;       // 1.1x
```

**Risk**: Fixed threshold may be too lenient or restrictive
**Recommendation**: Make governable (e.g., 20-60% range)

---

### 🟡 MEDIUM: Operational Parameters (GameEngineV2_5.sol)

#### Time Constraints (Lines 28, 96)
```solidity
uint256 public constant ROUND_DURATION = 15 minutes;
uint256 public constant VRF_TIMEOUT = 2 hours;
```

**Risk**: Fixed durations cannot adapt to network conditions
**Recommendation**: Make governable with limits
- ROUND_DURATION: 10 minutes - 1 hour
- VRF_TIMEOUT: 1 hour - 6 hours

#### League Structure (Lines 25-27)
```solidity
uint256 public constant TEAMS_COUNT = 20;
uint256 public constant MATCHES_PER_ROUND = 10;
uint256 public constant ROUNDS_PER_SEASON = 36;
```

**Risk**: Cannot expand or modify league structure
**Recommendation**: Keep as constants (structural changes require migration)

---

### 🟢 LOW: Legacy Bonuses (Currently Unused)

These are defined but **NOT USED** in the current implementation:

```solidity
uint256 public constant BONUS_2_MATCH = 500;   // 5%
uint256 public constant BONUS_3_MATCH = 1000;  // 10%
uint256 public constant BONUS_4_PLUS = 2000;   // 20%

uint256 public constant PARLAY_MULTIPLIER_1_LEG = 1e18;
uint256 public constant PARLAY_MULTIPLIER_2_LEGS = 12e17;
uint256 public constant PARLAY_MULTIPLIER_3_LEGS = 15e17;
uint256 public constant PARLAY_MULTIPLIER_4_LEGS = 2e18;
uint256 public constant PARLAY_MULTIPLIER_5_PLUS = 25e17;
```

**Recommendation**: Remove from contract to reduce confusion

---

## 3. Missing Admin Functions

### 🔴 CRITICAL Missing Functions

#### 1. Emergency Pause Mechanism
```solidity
// MISSING: Emergency pause for betting
function pauseBetting() external onlyOwner
function unpauseBetting() external onlyOwner
```

**Risk**: Cannot stop betting during exploits or critical bugs
**Recommendation**: Add pause functionality via OpenZeppelin Pausable

#### 2. Reserve Management
```solidity
// MISSING: Withdraw excess protocol reserve
function withdrawProtocolReserve(uint256 amount) external onlyOwner
```

**Risk**: Protocol profits are locked in contract forever
**Recommendation**: Add withdrawal with safety checks (must keep minimum reserve)

#### 3. Maximum Bet Limits
```solidity
// MISSING: Prevent whale manipulation
function setMaxBetPerMatch(uint256 maxBet) external onlyOwner
function setMaxBetPerRound(uint256 maxBet) external onlyOwner
```

**Risk**: Single user can skew entire pool
**Recommendation**: Add configurable bet limits

---

### 🟡 MEDIUM Missing Functions

#### 1. Parlay Count Reset
```solidity
// MISSING: Reset parlay count if no activity
function resetParlayCount(uint256 roundId) external onlyOwner
```

**Risk**: If round restarts, parlay count should reset
**Recommendation**: Add manual reset for edge cases

#### 2. Blacklist/Whitelist
```solidity
// MISSING: Block malicious addresses
function blacklistAddress(address user, bool status) external onlyOwner
```

**Risk**: Cannot ban MEV bots or exploiters
**Recommendation**: Add address-level controls

#### 3. Migration Path
```solidity
// MISSING: Contract upgrade mechanism
function setNewBettingPool(address newPool) external onlyOwner
```

**Risk**: No way to migrate to V2.2 without losing funds
**Recommendation**: Add migration helpers

---

## 4. Edge Cases & Attack Vectors

### Edge Case #1: Round Never Settles
**Scenario**: VRF fails, emergency settle not called
**Current State**: Funds locked forever
**Mitigation Needed**:
```solidity
function forceSettleStaleRound(uint256 roundId) external onlyOwner {
    require(block.timestamp > roundEndTime + 1 week, "Too early");
    // Force settlement with 33.33% each outcome
}
```

### Edge Case #2: Protocol Reserve Depleted
**Scenario**: Too many parlays win, reserve goes to 0
**Current State**: All future parlays revert
**Mitigation Needed**:
```solidity
function emergencyFundReserve() external payable onlyOwner {
    // Allow emergency top-up from treasury
}
```

### Edge Case #3: Bet Stuck in Unsettled State
**Scenario**: User places bet, round settles, but bet.settled = false
**Current State**: User cannot claim
**Mitigation Needed**:
```solidity
function emergencySettleBet(uint256 betId) external onlyOwner {
    // Manually mark bet as settled
}
```

### Edge Case #4: Locked Reserve Not Released
**Scenario**: Bet loses but locked reserve not freed
**Current State**: Reserve stays locked, reducing capacity
**Mitigation Needed**:
```solidity
function auditLockedReserve(uint256 roundId) external onlyOwner {
    // Calculate correct locked amount and fix discrepancies
}
```

### Edge Case #5: Zero Bets in Round
**Scenario**: Round starts, seeds pools, but no one bets
**Current State**: Protocol loses seed amount
**Mitigation Needed**:
```solidity
function reclaimSeedIfNoBets(uint256 roundId) external onlyOwner {
    require(noBetsPlaced, "Bets exist");
    // Return seed to protocol reserve
}
```

---

## 5. Governance Architecture Recommendations

### Option 1: Simple Timelock (Recommended for V2.1)

```solidity
contract GovernedBettingPool is BettingPoolV2_1 {
    uint256 public constant GOVERNANCE_DELAY = 48 hours;

    struct PendingChange {
        uint256 executeAfter;
        bool executed;
    }

    mapping(bytes32 => PendingChange) public pendingChanges;

    // Example: Change protocol cut with 48h delay
    function proposeProtocolCut(uint256 newCut) external onlyOwner {
        require(newCut >= 3000 && newCut <= 5000, "Out of bounds");
        bytes32 id = keccak256(abi.encodePacked("PROTOCOL_CUT", newCut));
        pendingChanges[id] = PendingChange(block.timestamp + GOVERNANCE_DELAY, false);
    }

    function executeProtocolCut(uint256 newCut) external onlyOwner {
        bytes32 id = keccak256(abi.encodePacked("PROTOCOL_CUT", newCut));
        require(block.timestamp >= pendingChanges[id].executeAfter, "Too early");
        require(!pendingChanges[id].executed, "Already executed");

        protocolCut = newCut; // Make this a state variable instead of constant
        pendingChanges[id].executed = true;
    }
}
```

**Benefits**:
- 48-hour notice prevents rug pulls
- Community can withdraw funds if malicious change proposed
- Simple to implement

---

### Option 2: DAO Governance (Recommended for V3.0)

```solidity
// Integrate with Governor contract (OpenZeppelin)
contract DAOGovernedBettingPool is BettingPoolV2_1, Governor {
    // Token-weighted voting
    // Proposal → Vote → Timelock → Execute
    // Minimum quorum required
}
```

**Benefits**:
- Community ownership
- Transparent on-chain voting
- Token holder alignment

**Requirements**:
- Governance token (LEAGUE or separate GOV token)
- Minimum 100k LEAGUE to propose
- 7-day voting period
- 4% quorum required

---

## 6. Recommended Implementation Plan

### Phase 1: Safety Features (Deploy ASAP)
1. ✅ Add emergency pause mechanism
2. ✅ Add max bet limits per match/round
3. ✅ Add protocol reserve withdrawal
4. ✅ Add emergency bet settlement
5. ✅ Add locked reserve audit function

### Phase 2: Parameter Governance (Deploy in V2.2)
1. ✅ Convert constants to state variables:
   - `protocolCut` (3000-5000 range)
   - `winnerShare` (5000-7000 range)
   - `seedPerMatch` (100-500 LEAGUE range)
   - `countMultTier1-5` (11e17-30e17 range)
   - `minImbalanceForFullBonus` (2000-6000 range)
2. ✅ Add timelock governance (48h delay)
3. ✅ Add bounds checking for all parameters
4. ✅ Emit events for all parameter changes

### Phase 3: DAO Governance (Deploy in V3.0)
1. ✅ Deploy governance token
2. ✅ Integrate OpenZeppelin Governor
3. ✅ Set up voting mechanisms
4. ✅ Transfer ownership to DAO

---

## 7. Specific Parameter Bounds

| Parameter | Current | Min | Max | Reasoning |
|-----------|---------|-----|-----|-----------|
| **PROTOCOL_CUT** | 45% | 30% | 50% | Below 30%: unprofitable; Above 50%: unfair to users |
| **WINNER_SHARE** | 55% | 50% | 70% | Must leave room for protocol + season pool |
| **SEED_PER_MATCH** | 300 | 100 | 500 | Below 100: no odds differentiation; Above 500: too expensive |
| **COUNT_MULT_TIER_1** | 2.5x | 1.5x | 3.0x | Above 3x: reserve risk; Below 1.5x: no FOMO |
| **MIN_IMBALANCE** | 40% | 20% | 60% | Below 20%: too restrictive; Above 60%: too lenient |
| **ROUND_DURATION** | 15 min | 10 min | 60 min | Below 10: rush; Above 60: slow |
| **VRF_TIMEOUT** | 2 hrs | 1 hr | 6 hrs | Below 1hr: premature; Above 6hrs: stale |

---

## 8. Example: Governable Parameter Implementation

```solidity
// BettingPoolV2_2.sol (with governance)

contract BettingPoolV2_2 is BettingPoolV2_1 {
    // Convert constants to state variables
    uint256 public protocolCut = 4500;           // Was constant
    uint256 public winnerShare = 5500;           // Was constant
    uint256 public seasonPoolShare = 200;        // Was constant
    uint256 public seedPerMatch = 300 ether;     // Was constant

    // Parlay tier multipliers
    uint256 public countMultTier1 = 25e17;       // Was constant
    uint256 public countMultTier2 = 22e17;       // Was constant
    uint256 public countMultTier3 = 19e17;       // Was constant
    uint256 public countMultTier4 = 16e17;       // Was constant
    uint256 public countMultTier5 = 13e17;       // Was constant

    // Imbalance gating
    uint256 public minImbalanceForFullBonus = 4000; // Was constant
    uint256 public minParlayMultiplier = 11e17;     // Was constant

    // Timelock mechanism
    uint256 public constant GOVERNANCE_DELAY = 48 hours;

    struct ParameterChange {
        uint256 executeAfter;
        bool executed;
    }

    mapping(bytes32 => ParameterChange) public pendingChanges;

    // Events
    event ParameterChangeProposed(string param, uint256 newValue, uint256 executeAfter);
    event ParameterChangeExecuted(string param, uint256 newValue);
    event ParameterChangeCancelled(string param);

    // Emergency pause
    bool public bettingPaused;

    modifier whenNotPaused() {
        require(!bettingPaused, "Betting is paused");
        _;
    }

    // ===== EMERGENCY FUNCTIONS =====

    function pauseBetting() external onlyOwner {
        bettingPaused = true;
        emit BettingPaused(block.timestamp);
    }

    function unpauseBetting() external onlyOwner {
        bettingPaused = false;
        emit BettingUnpaused(block.timestamp);
    }

    // ===== GOVERNANCE FUNCTIONS =====

    function proposeProtocolCut(uint256 newCut) external onlyOwner {
        require(newCut >= 3000 && newCut <= 5000, "Out of bounds: 30-50%");
        bytes32 id = keccak256(abi.encodePacked("PROTOCOL_CUT", newCut));
        pendingChanges[id] = ParameterChange(block.timestamp + GOVERNANCE_DELAY, false);
        emit ParameterChangeProposed("PROTOCOL_CUT", newCut, block.timestamp + GOVERNANCE_DELAY);
    }

    function executeProtocolCut(uint256 newCut) external onlyOwner {
        bytes32 id = keccak256(abi.encodePacked("PROTOCOL_CUT", newCut));
        ParameterChange storage change = pendingChanges[id];

        require(change.executeAfter > 0, "Not proposed");
        require(block.timestamp >= change.executeAfter, "Timelock active");
        require(!change.executed, "Already executed");

        protocolCut = newCut;
        winnerShare = 10000 - newCut - seasonPoolShare; // Auto-adjust winner share
        change.executed = true;

        emit ParameterChangeExecuted("PROTOCOL_CUT", newCut);
    }

    function cancelProtocolCut(uint256 newCut) external onlyOwner {
        bytes32 id = keccak256(abi.encodePacked("PROTOCOL_CUT", newCut));
        delete pendingChanges[id];
        emit ParameterChangeCancelled("PROTOCOL_CUT");
    }

    // Repeat for all governable parameters...

    // ===== RESERVE MANAGEMENT =====

    function withdrawProtocolProfit(uint256 amount) external onlyOwner {
        uint256 minReserve = 50000 ether; // Must keep 50k LEAGUE minimum
        require(protocolReserve - amount >= minReserve, "Below minimum reserve");

        protocolReserve -= amount;
        leagueToken.transfer(protocolTreasury, amount);

        emit ProtocolProfitWithdrawn(amount, protocolReserve);
    }

    // ===== BET LIMITS =====

    uint256 public maxBetPerMatch = 10000 ether;    // Default: 10k LEAGUE
    uint256 public maxBetPerRound = 50000 ether;    // Default: 50k LEAGUE

    function setMaxBetPerMatch(uint256 newMax) external onlyOwner {
        require(newMax >= 1000 ether && newMax <= 100000 ether, "Out of bounds");
        maxBetPerMatch = newMax;
        emit MaxBetPerMatchUpdated(newMax);
    }

    // Override placeBet to enforce limits
    function placeBet(
        uint256[] calldata matchIndices,
        uint8[] calldata outcomes,
        uint256 amount
    )
        external
        override
        whenNotPaused  // Add pause check
        returns (uint256 betId)
    {
        require(amount <= maxBetPerMatch, "Exceeds max bet per match");

        // Call parent implementation
        return super.placeBet(matchIndices, outcomes, amount);
    }
}
```

---

## 9. Summary of Critical Changes Needed

### Immediate (Before Mainnet Launch)
1. ❌ **Add emergency pause mechanism**
2. ❌ **Add protocol reserve withdrawal**
3. ❌ **Add max bet limits**
4. ❌ **Add emergency bet settlement**
5. ❌ **Add stuck round resolution**

### Short-term (V2.2 - Within 3 months)
1. ❌ **Convert economic constants to state variables**
2. ❌ **Implement timelock governance (48h delay)**
3. ❌ **Add parameter bounds checking**
4. ❌ **Add comprehensive event logging**

### Long-term (V3.0 - Within 6-12 months)
1. ❌ **Deploy governance token**
2. ❌ **Integrate DAO voting**
3. ❌ **Transfer ownership to community**

---

## 10. Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Fixed economic parameters | 🔴 HIGH | Make governable in V2.2 |
| No emergency pause | 🔴 HIGH | Add immediately |
| No bet limits | 🟡 MEDIUM | Add before mainnet |
| Locked protocol profits | 🟡 MEDIUM | Add withdrawal function |
| No round force-settle | 🟡 MEDIUM | Add emergency function |
| Centralized ownership | 🟢 LOW | Plan DAO transition |

---

## Conclusion

The current contracts are **production-ready for testnet** but require governance mechanisms before mainnet deployment. The most critical addition is the **emergency pause** functionality, followed by **governable economic parameters** in V2.2.

**Recommended Action**: Deploy current V2.1 to testnet, gather data for 1-2 months, then launch V2.2 with governance features based on real usage patterns.

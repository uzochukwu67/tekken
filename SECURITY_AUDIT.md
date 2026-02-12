# LeagueBet Protocol Security Audit

## Audit Summary

| Category | Critical | High | Medium | Low | Informational |
|----------|----------|------|--------|-----|---------------|
| Count | 2 | 4 | 6 | 8 | 5 |

---

## CRITICAL SEVERITY

### [C-01] Bet ID Starts at 0 - First Bet Overwrites Empty State

**Location:** [BettingStorage.sol:238-242](src/storage/BettingStorage.sol#L238-L242)

**Description:**
The `getNextBetId()` function returns `nextBetId` before incrementing. Since `nextBetId` starts at 0, the first bet gets ID 0. However, in `claimWinnings()` and other functions, `bet.bettor == address(0)` is used to check if a bet exists. This creates ambiguity - is betId 0 valid or does it represent "no bet"?

```solidity
function getNextBetId() internal returns (uint256 betId) {
    Layout storage s = layout();
    betId = s.nextBetId;  // Returns 0 first time
    s.nextBetId++;
}
```

**Impact:**
- First bettor could have issues claiming (edge case)
- Mapping lookups for non-existent bets return default values, potentially confused with bet 0

**Recommendation:**
Initialize `nextBetId = 1` in constructor or change the logic:

```solidity
function getNextBetId() internal returns (uint256 betId) {
    Layout storage s = layout();
    s.nextBetId++;
    betId = s.nextBetId;  // Now starts at 1
}
```

**Industry Standard:** Uniswap V2/V3, Aave, and Compound all use 1-indexed IDs for positions/loans.

---

### [C-02] Missing Check for Duplicate Match Indices in Parlay

**Location:** [BettingCore.sol:164-167](src/core/BettingCore.sol#L164-L167)

**Description:**
Users can place a parlay bet with duplicate match indices:

```solidity
for (uint256 i = 0; i < legCount; i++) {
    if (matchIndices[i] >= Constants.MAX_MATCHES_PER_ROUND) revert InvalidMatchIndex();
    if (predictions[i] < 1 || predictions[i] > 3) revert InvalidPrediction();
    // NO CHECK FOR DUPLICATES!
}
```

**Attack Vector:**
1. User places a 3-leg parlay with `matchIndices = [0, 0, 0]` (same match 3 times)
2. If match 0 wins, user claims 1.10x multiplier bonus intended for 3 different matches
3. User essentially gets a single-match bet with parlay bonus

**Impact:**
- Protocol loses money on exploited parlay bonuses
- Unfair advantage over honest bettors

**Recommendation:**
Add duplicate check:

```solidity
for (uint256 i = 0; i < legCount; i++) {
    if (matchIndices[i] >= Constants.MAX_MATCHES_PER_ROUND) revert InvalidMatchIndex();
    if (predictions[i] < 1 || predictions[i] > 3) revert InvalidPrediction();

    // Check for duplicates
    for (uint256 j = 0; j < i; j++) {
        if (matchIndices[i] == matchIndices[j]) revert DuplicateMatchIndex();
    }
}
```

**Industry Standard:** All betting protocols validate uniqueness of selections.

---

## HIGH SEVERITY

### [H-01] Race Condition in `placeBet` Solvency Check

**Location:** [BettingCore.sol:176-177](src/core/BettingCore.sol#L176-L177)

**Description:**
The solvency check happens before the transfer, creating a TOCTOU (time-of-check-time-of-use) vulnerability:

```solidity
uint256 currentReserves = IERC20(s.lbtToken).balanceOf(address(this));
if (potentialPayout > currentReserves) revert InsufficientLiquidity();

// Transfer happens AFTER the check
IERC20(s.lbtToken).safeTransferFrom(msg.sender, address(this), amount);
```

**Attack Vector:**
In the same block, multiple large bets could all pass the check before any transfer occurs, resulting in over-commitment of reserves.

**Impact:**
Protocol may accept bets it cannot fully pay if all win simultaneously.

**Recommendation:**
Check against `totalReservedForWinners` instead of current balance, or add cumulative reserve tracking:

```solidity
// Check against committed reserves, not just balance
DataTypes.RoundAccounting storage acct = s.roundAccounting[roundId];
uint256 futureReserved = acct.totalReservedForWinners + potentialPayout;
if (futureReserved > currentReserves + amount) revert InsufficientLiquidity();
```

**Industry Standard:** Aave uses committed liquidity tracking, not spot balance checks.

---

### [H-02] `cancelBet` Doesn't Update `totalBetVolume`

**Location:** [BettingCore.sol:240-242](src/core/BettingCore.sol#L240-L242)

**Description:**
When a bet is cancelled, only `totalReservedForWinners` is updated:

```solidity
// Update accounting
DataTypes.RoundAccounting storage acct = s.roundAccounting[bet.roundId];
acct.totalReservedForWinners -= bet.potentialPayout;
// MISSING: acct.totalBetVolume -= bet.amount;
```

**Impact:**
- `totalBetVolume` overstates actual betting activity
- `finalizeRoundRevenue()` calculates incorrect profit: `profit = totalBets - totalPaid`
- Protocol may distribute more to season pool than actual profit warrants

**Recommendation:**
```solidity
acct.totalReservedForWinners -= bet.potentialPayout;
acct.totalBetVolume -= uint128(bet.amount);  // ADD THIS
```

---

### [H-03] External Call Before State Update in `finalizeRoundRevenue`

**Location:** [BettingCore.sol:530-544](src/core/BettingCore.sol#L530-L544)

**Description:**
The function makes external calls to `seasonPredictor` before updating `meta.revenueDistributed`:

```solidity
// External call
IERC20(s.lbtToken).safeTransfer(s.seasonPredictor, seasonShare);

// Another external call
(success, ) = s.seasonPredictor.call(
    abi.encodeWithSignature("fundSeasonPool(uint256,uint256)", seasonId, seasonShare)
);

// State update happens AFTER external calls
meta.revenueDistributed = true;  // LINE 555
```

**Impact:**
Violates checks-effects-interactions pattern. If `seasonPredictor` is malicious or has a callback, it could potentially re-enter.

**Recommendation:**
Move state update before external calls:

```solidity
// Set flag FIRST
meta.revenueDistributed = true;

// Then external calls
if (profit > 0 && s.seasonPredictor != address(0)) {
    // ... transfers
}
```

**Industry Standard:** Compound's CErc20 and Aave V3 update state before any external calls.

---

### [H-04] No Validation of `roundId` Parameter in `settleRound`

**Location:** [BettingCore.sol:471-492](src/core/BettingCore.sol#L471-L492)

**Description:**
The `settleRound` function doesn't verify that `roundId` equals `currentRoundId`:

```solidity
function settleRound(
    uint256 roundId,  // Could be any roundId
    uint8[] calldata results
) external onlyOwnerOrGameEngine {
    // No check: require(roundId == s.currentRoundId, "Wrong round");
```

**Impact:**
- Operator could accidentally settle the wrong round
- Could settle a future round that hasn't been seeded yet (results stored for future manipulation)

**Recommendation:**
Add round validation:

```solidity
require(roundId == s.currentRoundId, "Can only settle current round");
require(block.timestamp >= meta.roundEndTime, "Round not ended");
```

---

## MEDIUM SEVERITY

### [M-01] `_calculateParlayMultiplier` Ignores `roundId` and `predictions` Parameters

**Location:** [BettingCore.sol:1085-1108](src/core/BettingCore.sol#L1085-L1108)

**Description:**
```solidity
function _calculateParlayMultiplier(
    uint256 roundId,           // UNUSED
    uint256[] calldata matchIndices,  // UNUSED (only length used)
    uint8[] calldata predictions      // UNUSED
) internal pure returns (uint256 multiplier) {
    uint256 legCount = matchIndices.length;
    // Only uses legCount, ignores actual odds
```

**Impact:**
- Wasted gas passing unused parameters
- Misleading function signature suggests odds-based calculation
- Multiplier is fixed regardless of actual odds, which may not match user expectations

**Recommendation:**
Either remove unused parameters or implement actual odds-weighted multiplier:

```solidity
function _calculateParlayMultiplier(uint256 legCount) internal pure returns (uint256)
```

---

### [M-02] No Maximum Length Check on `batchClaim`

**Location:** [BettingCore.sol:344](src/core/BettingCore.sol#L344)

**Description:**
```solidity
function batchClaim(uint256[] calldata betIds) external nonReentrant returns (uint256 totalPayout) {
    for (uint256 i = 0; i < betIds.length; i++) {
        // No limit on array length
```

**Impact:**
- Unbounded loop could hit block gas limit
- DoS if someone creates function call with huge array

**Recommendation:**
Add maximum batch size (Aave uses max 10-20 for batch operations):

```solidity
require(betIds.length <= 50, "Batch too large");
```

---

### [M-03] Weak Entropy Source for Odds Seeding

**Location:** [BettingCore.sol:1122-1128](src/core/BettingCore.sol#L1122-L1128)

**Description:**
```solidity
uint256 entropy = uint256(keccak256(abi.encodePacked(
    roundId,
    matchIndex,
    block.timestamp,      // Predictable
    block.prevrandao      // Can be influenced by validators
)));
```

**Impact:**
- Validators/miners can influence `block.prevrandao`
- `block.timestamp` is predictable
- Sophisticated attackers could predict or influence odds

**Recommendation:**
Use Chainlink VRF for odds randomization (you already have VRF integration in GameCore):

```solidity
// Request VRF before seeding
// Use VRF result for entropy
```

---

### [M-04] `getClaimableWithBounty` Gas Bomb

**Location:** [BettingCore.sol:958-1018](src/core/BettingCore.sol#L958-L1018)

**Description:**
This view function iterates over ALL bets ever placed:

```solidity
uint256 totalBets = s.totalBetsPlaced;
for (uint256 betId = 1; betId <= totalBets && count < maxResults; betId++) {
```

**Impact:**
- After 100,000+ bets, this function becomes unusable
- RPC nodes may timeout
- Frontend integration breaks

**Recommendation:**
Index bets by round for efficient lookups (like Uniswap's position tracking):

```solidity
// Add to storage:
mapping(uint256 => uint256[]) roundBetIds;  // roundId => betIds[]

// In placeBet:
s.roundBetIds[roundId].push(betId);
```

---

### [M-05] Missing Event for `updateLimits` and `updateFeeConfig`

**Location:** [BettingCore.sol:632-642](src/core/BettingCore.sol#L632-L642)

**Description:**
```solidity
function updateLimits(DataTypes.BettingLimits calldata limits) external onlyOwner {
    BettingStorage.layout().limits = limits;
    // NO EVENT EMITTED
}

function updateFeeConfig(DataTypes.FeeConfig calldata config) external onlyOwner {
    BettingStorage.layout().feeConfig = config;
    // NO EVENT EMITTED
}
```

**Impact:**
- Off-chain monitoring cannot track config changes
- No audit trail for fee/limit modifications
- Violates transparency best practices

**Recommendation:**
```solidity
event LimitsUpdated(uint128 minBet, uint128 maxBet, uint128 maxPayout);
event FeeConfigUpdated(uint16 protocolFee, uint16 seasonFee, uint16 cancelFee);
```

---

### [M-06] Cancellation Allows Round-Settled Bets to Be Cancelled

**Location:** [BettingCore.sol:225-253](src/core/BettingCore.sol#L225-L253)

**Description:**
```solidity
function cancelBet(uint256 betId) external nonReentrant returns (uint256 refundAmount) {
    // Checks bet.status == Active
    // Does NOT check if round is settled
```

**Impact:**
- User could cancel a winning bet after seeing results (if they haven't claimed yet)
- Wait, this is actually prevented by status check... BUT if claimWinnings() hasn't been called yet, the bet is still "Active" even after settlement.

**Actual Issue:**
User places bet → Round settles → User sees they lost → User cancels bet (still Active) → Gets 90% refund instead of 0%

**Recommendation:**
```solidity
// Add check
DataTypes.RoundMetadata storage meta = s.roundMetadata[bet.roundId];
require(!meta.settled, "Round already settled");
```

---

## LOW SEVERITY

### [L-01] Hardcoded 1e12 Precision Conversion

**Location:** [BettingCore.sol:852-854](src/core/BettingCore.sol#L852-L854), [BettingCore.sol:1242-1244](src/core/BettingCore.sol#L1242-L1244)

**Description:**
```solidity
homeOdds = uint256(odds.homeOdds) * 1e12;  // Magic number
// ...
homeOdds: uint64(_compressOdds(rawHomeOdds) / 1e12)  // Magic number
```

**Recommendation:**
Define constant:
```solidity
uint256 constant ODDS_STORAGE_PRECISION = 1e12;
```

---

### [L-02] No Zero-Amount Protection in `cancelBet`

**Location:** [BettingCore.sol:244-250](src/core/BettingCore.sol#L244-L250)

**Description:**
If `bet.amount` is somehow 0 (shouldn't happen, but defense in depth):

```solidity
uint256 fee = (bet.amount * s.feeConfig.cancellationFeeBps) / Constants.BPS_PRECISION;
refundAmount = bet.amount - fee;  // Could be 0

IERC20(s.lbtToken).safeTransfer(msg.sender, refundAmount);  // Transfers 0
```

**Recommendation:**
```solidity
require(refundAmount > 0, "Nothing to refund");
```

---

### [L-03] `pauseState` Double Tracking

**Location:** [BettingCore.sol:733-735](src/core/BettingCore.sol#L733-L735)

**Description:**
```solidity
function pause() external onlyOwner {
    _pause();  // OpenZeppelin Pausable
    BettingStorage.layout().paused = true;  // Duplicate state
}
```

**Impact:**
- Wastes gas
- Potential inconsistency if one updates without other

**Recommendation:**
Use only OpenZeppelin's `paused()` function, remove `BettingStorage.paused`.

---

### [L-04] Missing Input Validation for `setSeasonPredictor`

**Location:** [BettingCore.sol:613-617](src/core/BettingCore.sol#L613-L617)

**Description:**
No code validation that `_seasonPredictor` is actually a contract:

```solidity
function setSeasonPredictor(address _seasonPredictor) external onlyOwner {
    require(_seasonPredictor != address(0), "Invalid address");
    // No check if it's a contract
```

**Recommendation:**
```solidity
require(_seasonPredictor.code.length > 0, "Not a contract");
```

---

### [L-05] `withdrawReserves` Only Checks Current Round

**Location:** [BettingCore.sol:681-688](src/core/BettingCore.sol#L681-L688)

**Description:**
```solidity
if (s.currentRoundId > 0) {
    DataTypes.RoundMetadata storage meta = s.roundMetadata[s.currentRoundId];
    if (!meta.settled) {
        // Only checks CURRENT round
```

**Impact:**
If a previous round hasn't finalized (claims still pending), those reserves aren't protected.

**Recommendation:**
Track total active reservations across all unsettled rounds.

---

### [L-06] No Deadline Parameter in `placeBet`

**Location:** [BettingCore.sol:129-133](src/core/BettingCore.sol#L129-L133)

**Description:**
No transaction deadline protection:

```solidity
function placeBet(
    uint256 amount,
    uint256[] calldata matchIndices,
    uint8[] calldata predictions
) external nonReentrant whenNotPaused returns (uint256 betId) {
    // No deadline parameter
```

**Impact:**
Transaction could be pending in mempool, executed after round ends if betting window check is passed earlier.

**Recommendation (Uniswap pattern):**
```solidity
function placeBet(
    uint256 amount,
    uint256[] calldata matchIndices,
    uint8[] calldata predictions,
    uint256 deadline
) external {
    require(block.timestamp <= deadline, "EXPIRED");
```

---

### [L-07] Inconsistent Error Handling (require vs revert)

**Description:**
Mix of `require()` and custom errors:

```solidity
require(meta.seeded, "Round not seeded");  // String error
if (bet.bettor == address(0)) revert BetNotFound();  // Custom error
```

**Recommendation:**
Use custom errors consistently for gas savings (~100 gas per error).

---

### [L-08] `totalProtocolFees` Not Used Anywhere

**Location:** [BettingStorage.sol:98](src/storage/BettingStorage.sol#L98)

**Description:**
```solidity
uint256 totalProtocolFees;  // Accumulated but never read
```

**Impact:**
Dead code, wastes storage writes.

**Recommendation:**
Either use it for reporting or remove it.

---

## INFORMATIONAL

### [I-01] Consider Using Bitmap for Match Results

Instead of `mapping(uint256 => mapping(uint256 => uint8))`, use a single `uint256` per round:
- Each match needs 2 bits (0-3 outcomes)
- 10 matches = 20 bits, fits in single slot
- Saves ~90% gas on result storage

---

### [I-02] Diamond Storage Position Not Unique

```solidity
bytes32 constant STORAGE_POSITION = 0x52c63c9a7e0c799f8e3f3c8b1a6d5e4f3c2b1a0987654321fedcba9876543211;
```

Should use `keccak256("leaguebet.betting.storage.v1")` for guaranteed uniqueness.

---

### [I-03] Consider EIP-712 for Gasless Betting

Allow users to sign bets off-chain, relayer submits. Popular in Uniswap Permit2.

---

### [I-04] Missing NatSpec Documentation

Many functions lack `@param` and `@return` documentation. Aave V3 fully documents all functions.

---

### [I-05] Consider Upgradeable Pattern

Currently non-upgradeable. Consider UUPS proxy pattern (OpenZeppelin) for future upgrades without redeployment.

---

## Gas Optimizations

### [G-01] Cache Storage Variables

```solidity
// Before (multiple storage reads)
DataTypes.Bet storage bet = s.bets[betId];
// bet.bettor, bet.amount, bet.roundId... each is SLOAD

// After (cache in memory)
DataTypes.Bet memory bet = s.bets[betId];
// Then modify only if needed: s.bets[betId].status = ...
```

### [G-02] Use `unchecked` for Safe Math

```solidity
// Guaranteed no overflow
for (uint256 i = 0; i < legCount;) {
    // ...
    unchecked { ++i; }  // Saves ~60 gas per iteration
}
```

### [G-03] Pack Structs Better

`RoundAccounting` has 7 fields totaling 86 bytes. Could pack into 3 slots instead of 4.

### [G-04] Use `calldata` for Read-Only Arrays

Already done correctly in most places - good job!

---

## Summary of Fixes Required

| ID | Severity | Fix Complexity | Status |
|----|----------|----------------|--------|
| C-01 | Critical | Low | TODO |
| C-02 | Critical | Low | TODO |
| H-01 | High | Medium | TODO |
| H-02 | High | Low | TODO |
| H-03 | High | Low | TODO |
| H-04 | High | Low | TODO |
| M-01 | Medium | Low | TODO |
| M-02 | Medium | Low | TODO |
| M-03 | Medium | High | TODO |
| M-04 | Medium | Medium | TODO |
| M-05 | Medium | Low | TODO |
| M-06 | Medium | Low | TODO |

---

## Comparison with Industry Standards

### vs Uniswap V3
- **Uniswap:** Extensive use of `unchecked`, bitmap positions, NatSpec
- **LeagueBet:** Missing `unchecked` optimizations, no bitmaps

### vs Aave V3
- **Aave:** Centralized DataTypes library (you have this - good!)
- **Aave:** Comprehensive input validation on all parameters
- **LeagueBet:** Missing validation (duplicate matches, round checks)

### vs Compound V3
- **Compound:** CEI pattern strictly followed
- **Compound:** Events for ALL state changes
- **LeagueBet:** CEI violated in `finalizeRoundRevenue`, missing events

---

## Recommended Priority

1. **Immediate (before mainnet):** C-01, C-02, H-02, M-06
2. **Before launch:** H-01, H-03, H-04, M-02, M-05
3. **Optimization phase:** M-01, M-04, Gas optimizations
4. **Nice to have:** L-* issues, Informational

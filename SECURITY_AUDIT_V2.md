# LeagueBet Protocol - Comprehensive Security Audit V2

**Audit Date:** February 2026
**Contracts Audited:** All contracts in src/
**Methodology:** Manual review + pattern matching against Uniswap, Aave, Compound standards

---

## Executive Summary

This audit covers the entire LeagueBet protocol including:
- BettingCore.sol (previously audited, fixes verified)
- GameCore.sol
- SwapRouter.sol
- BettingRouter.sol
- SeasonPredictor.sol
- LeagueBetToken.sol
- TokenRegistry.sol

**Findings Summary:**
| Severity | Count |
|----------|-------|
| Critical | 2 |
| High | 5 |
| Medium | 8 |
| Low | 10 |
| Informational | 6 |

---

## Critical Findings

### C-01: Emergency Settlement Entropy Can Be Gamed
**File:** [GameCore.sol:394-433](src/core/GameCore.sol#L394-L433)
**Severity:** Critical
**Status:** Open

**Description:**
The `emergencySettleRound` function accepts a user-provided `seed` parameter which is used to generate pseudo-random match results. An owner (or compromised owner key) can choose a seed that produces favorable results.

```solidity
function emergencySettleRound(uint256 roundId, uint256 seed) external onlyOwner {
    // ...
    for (uint256 i = 0; i < MATCHES_PER_ROUND; i++) {
        uint256 randomWord = uint256(keccak256(abi.encodePacked(
            seed,           // ⚠️ User-controlled
            block.prevrandao,
            block.timestamp,
            roundId,
            i
        )));
        _settleMatch(roundId, i, randomWord);
    }
}
```

**Impact:** Match results can be manipulated to favor specific bet outcomes.

**Recommendation:**
```solidity
function emergencySettleRound(uint256 roundId) external onlyOwner {
    // Use only on-chain entropy, not user-provided seed
    for (uint256 i = 0; i < MATCHES_PER_ROUND; i++) {
        uint256 randomWord = uint256(keccak256(abi.encodePacked(
            block.prevrandao,
            block.timestamp,
            roundId,
            i,
            blockhash(block.number - 1)
        )));
        _settleMatch(roundId, i, randomWord);
    }
}
```

---

### C-02: BettingRouter Doesn't Verify Bet Ownership for Claims/Cancellation
**File:** [BettingRouter.sol:377-400](src/periphery/BettingRouter.sol#L377-L400)
**Severity:** Critical
**Status:** Open

**Description:**
The `claimWinnings` and `cancelBet` functions in BettingRouter call BettingCore without verifying that `msg.sender` owns the bet. While BettingCore has ownership checks, the router emits misleading events with `msg.sender`.

```solidity
function claimWinnings(uint256 betId, uint256 minPayout) external nonReentrant returns (uint256 payout) {
    payout = bettingCore.claimWinnings(betId, minPayout);
    emit WinningsClaimed(msg.sender, betId, payout);  // ⚠️ Emits msg.sender, not actual winner
}

function cancelBet(uint256 betId) external nonReentrant {
    bettingCore.cancelBet(betId);  // ⚠️ No ownership verification
}
```

**Impact:**
1. Misleading event emission for off-chain tracking
2. Anyone can try to cancel anyone's bets (though BettingCore will revert)
3. Gas griefing by calling with invalid bet IDs

**Recommendation:**
```solidity
function claimWinnings(uint256 betId, uint256 minPayout) external nonReentrant returns (uint256 payout) {
    (DataTypes.Bet memory bet, ) = bettingCore.getBet(betId);
    require(bet.bettor == msg.sender, "Not bet owner");
    payout = bettingCore.claimWinnings(betId, minPayout);
    emit WinningsClaimed(msg.sender, betId, payout);
}
```

---

## High Findings

### H-01: SeasonPredictor batchDistributeRewards Can DoS With Large Winner Arrays
**File:** [SeasonPredictor.sol:288-317](src/periphery/SeasonPredictor.sol#L288-L317)
**Severity:** High
**Status:** Open

**Description:**
The `batchDistributeRewards` function iterates from index 0 every time it's called, checking `prediction.claimed` for each winner. If there are many winners, this becomes extremely gas-intensive.

```solidity
function batchDistributeRewards(uint256 seasonId, uint256 maxDistributions) external onlyOwner nonReentrant {
    // ...
    for (uint256 i = 0; i < winners.length && distributed < maxDistributions; i++) {
        // Always starts from 0, re-checks already claimed
        if (!prediction.claimed) {
            // distribute
        }
    }
}
```

**Impact:** With thousands of winners, distribution becomes impractical due to gas costs.

**Recommendation:** Track a `lastDistributedIndex` per season to resume from where left off:
```solidity
mapping(uint256 => uint256) public lastDistributedIndex;

function batchDistributeRewards(...) external {
    uint256 startIndex = lastDistributedIndex[seasonId];
    for (uint256 i = startIndex; i < winners.length && distributed < maxDistributions; i++) {
        // distribute
        lastDistributedIndex[seasonId] = i + 1;
    }
}
```

---

### H-02: SwapRouter Uses block.timestamp as Deadline (Miner Manipulable)
**File:** [SwapRouter.sol:108-114](src/periphery/SwapRouter.sol#L108-L114)
**Severity:** High
**Status:** Open

**Description:**
The swap function uses `block.timestamp` as the deadline parameter, which effectively disables deadline protection.

```solidity
uint256[] memory amounts = IUniswapV2Router(uniswapRouter).swapExactTokensForTokens(
    amountIn,
    minAmountOut,
    path,
    msg.sender,
    block.timestamp  // ⚠️ Always passes, no protection
);
```

**Impact:** Transactions can be held in mempool indefinitely and executed at unfavorable prices.

**Recommendation:**
```solidity
function swapToLBT(
    address tokenIn,
    uint256 amountIn,
    uint256 minAmountOut,
    uint256 deadline  // Add explicit deadline parameter
) external payable nonReentrant returns (uint256 amountOut) {
    require(block.timestamp <= deadline, "Deadline expired");
    // ...
}
```

---

### H-03: GameCore Match Generation Uses Predictable Entropy
**File:** [GameCore.sol:625-638](src/core/GameCore.sol#L625-L638)
**Severity:** High
**Status:** Open

**Description:**
The `_shuffleTeams` function uses only the `roundId` as the seed, making match pairings deterministic and predictable.

```solidity
function _shuffleTeams(uint256 seed) private pure returns (uint256[] memory) {
    // Fisher-Yates with predictable seed
    for (uint256 i = TEAMS_COUNT - 1; i > 0; i--) {
        uint256 j = uint256(keccak256(abi.encodePacked(seed, i))) % (i + 1);
        // ...
    }
}
```

**Impact:** Users can predict which teams will face each other in upcoming rounds before betting.

**Recommendation:** Use VRF or additional entropy sources for match generation.

---

### H-04: BettingRouter Swap Amount Mismatch
**File:** [BettingRouter.sol:256-307](src/periphery/BettingRouter.sol#L256-L307)
**Severity:** High
**Status:** Open

**Description:**
In `placeBetWithSwap`, the `params.amount` is used for odds slippage check, but `lbtReceived` (which may differ) is used for the actual bet.

```solidity
function placeBetWithSwap(..., BetParams calldata params, ...) {
    // Check odds based on params.amount (user-specified expectation)
    uint256 currentOdds = _getCurrentOdds(params.matchIndex, params.prediction);
    if (currentOdds < params.minOdds) revert OddsSlippageExceeded();

    // But bet with lbtReceived (actual swap output)
    lbtReceived = swapRouter.swapToLBT{...}(...);
    betId = bettingCore.placeBet(lbtReceived, ...);  // ⚠️ Different amount
}
```

**Impact:** User's odds calculation is based on wrong amount, leading to unexpected bet sizes.

**Recommendation:** Use `lbtReceived` for odds validation or clearly document behavior.

---

### H-05: SeasonPredictor emergencyWithdraw Drains All Funds
**File:** [SeasonPredictor.sol:465-473](src/periphery/SeasonPredictor.sol#L465-L473)
**Severity:** High
**Status:** Open

**Description:**
The `emergencyWithdraw` function transfers the entire contract balance, ignoring unclaimed rewards from winners.

```solidity
function emergencyWithdraw(uint256 seasonId) external onlyOwner {
    // ...
    uint256 balance = lbtToken.balanceOf(address(this));
    if (balance > 0) {
        lbtToken.safeTransfer(owner(), balance);  // ⚠️ All funds, including pending claims
    }
}
```

**Impact:** Winners lose their rewards if owner calls emergency withdraw.

**Recommendation:**
```solidity
function emergencyWithdraw(uint256 seasonId) external onlyOwner {
    SeasonPool storage pool = seasonPools[seasonId];
    require(pool.finalized, "Season not finalized");

    // Only withdraw unclaimed excess, not pending rewards
    uint256 totalPendingClaims = pool.rewardPerWinner * (pool.totalWinners - _countClaimed(seasonId));
    uint256 balance = lbtToken.balanceOf(address(this));
    uint256 withdrawable = balance > totalPendingClaims ? balance - totalPendingClaims : 0;

    lbtToken.safeTransfer(owner(), withdrawable);
}
```

---

## Medium Findings

### M-01: LeagueBetToken totalMinted Not Decreased on Burn
**File:** [LeagueBetToken.sol:48-62](src/tokens/LeagueBetToken.sol#L48-L62)
**Severity:** Medium
**Status:** Open

**Description:**
When tokens are burned, `totalMinted` is not decreased. This causes misleading accounting.

```solidity
function burn(uint256 amount) external {
    _burn(msg.sender, amount);
    emit TokensBurned(msg.sender, amount);
    // ⚠️ totalMinted not decreased
}
```

**Impact:**
- `totalMinted` becomes inaccurate over time
- Eventually can't mint new tokens even though circulating supply is below MAX_SUPPLY

**Recommendation:** Either decrease `totalMinted` on burn, or rename to `totalEverMinted` to clarify intent.

---

### M-02: SeasonPredictor No Season Validation in makePrediction
**File:** [SeasonPredictor.sol:143-172](src/periphery/SeasonPredictor.sol#L143-L172)
**Severity:** Medium
**Status:** Open

**Description:**
`makePrediction` doesn't verify the seasonId exists or is active. Users can predict for non-existent seasons.

```solidity
function makePrediction(uint256 seasonId, uint256 teamId) external nonReentrant {
    uint256 currentRound = _getCurrentRound();
    // ⚠️ No check that seasonId is valid/current
    if (currentRound > PREDICTION_DEADLINE_ROUND) {
        revert PredictionDeadlinePassed();
    }
    // ...
}
```

**Impact:** Users waste gas predicting for invalid seasons; data pollution.

**Recommendation:** Add season validation by querying GameCore.

---

### M-03: TokenRegistry removeToken O(n) Loop Gas Inefficiency
**File:** [TokenRegistry.sol:142-162](src/tokens/TokenRegistry.sol#L142-L162)
**Severity:** Medium
**Status:** Open

**Description:**
Token removal requires iterating through the entire `allTokens` array, which is O(n).

```solidity
for (uint256 i = 0; i < allTokens.length; i++) {
    if (allTokens[i] == token) {
        allTokens[i] = allTokens[allTokens.length - 1];
        allTokens.pop();
        break;
    }
}
```

**Impact:** If many tokens are added, removal becomes expensive.

**Recommendation:** Use index mapping: `mapping(address => uint256) public tokenIndex;`

---

### M-04: GameCore settleRound Can Be Called for Non-Current Round
**File:** [GameCore.sol:349-387](src/core/GameCore.sol#L349-L387)
**Severity:** Medium
**Status:** Open

**Description:**
The VRF callback doesn't verify that the roundId being settled matches the current active round.

```solidity
function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
    uint256 roundId = request.roundId;
    // ⚠️ No check: roundId == currentSeason.currentRound
    _settleMatch(roundId, i, randomWords[i]);
}
```

**Impact:** Old pending VRF requests could settle wrong rounds.

**Recommendation:** Add validation: `require(roundId == currentSeason.currentRound, "Stale request");`

---

### M-05: SwapRouter forceApprove May Fail for Non-Standard Tokens
**File:** [SwapRouter.sol:100](src/periphery/SwapRouter.sol#L100)
**Severity:** Medium
**Status:** Open

**Description:**
Using `forceApprove` is good, but some tokens may still fail if they have non-standard approval mechanisms.

**Recommendation:** Add a try-catch or use approve(0) + approve(amount) pattern as fallback.

---

### M-06: BettingRouter Batch Functions Have No Size Limits
**File:** [BettingRouter.sol:171-209](src/periphery/BettingRouter.sol#L171-L209)
**Severity:** Medium
**Status:** Open

**Description:**
`placeBatchBets` has no limit on array size, unlike `batchClaim` in BettingCore.

**Impact:** Gas bomb attack possible by passing huge arrays.

**Recommendation:** Add `require(bets.length <= 50, "Batch too large");`

---

### M-07: GameCore Season Can End Prematurely
**File:** [GameCore.sol:708-726](src/core/GameCore.sol#L708-L726)
**Severity:** Medium
**Status:** Open

**Description:**
`_endSeason` can be triggered by `completeSeason()` at any time by owner, even if rounds remain.

**Recommendation:** Add minimum rounds check before allowing manual completion.

---

### M-08: SeasonPredictor Reward Division Loses Dust
**File:** [SeasonPredictor.sol:275-277](src/periphery/SeasonPredictor.sol#L275-L277)
**Severity:** Medium
**Status:** Open

**Description:**
```solidity
if (totalWinners > 0 && pool.totalPool > 0) {
    pool.rewardPerWinner = pool.totalPool / totalWinners;  // ⚠️ Dust lost
}
```

**Impact:** Small amounts of LBT become permanently locked.

**Recommendation:** Track and handle dust separately, or allow owner to recover.

---

## Low Findings

### L-01: Missing Events for VRF Config Updates (GameCore)
`updateVRFConfig` doesn't emit an event for tracking configuration changes.

### L-02: No Minimum Value Check in TokenRegistry addToken
`minBet` could be set higher than `maxBet`.

### L-03: SwapRouter emergencyWithdraw Has No Token Validation
Could accidentally be called with token = address(0) for ERC20 path.

### L-04: GameCore withdrawNative Uses Low-Level Call
Should use `Address.sendValue` from OpenZeppelin for safety.

### L-05: BettingRouter Uses approve() Instead of safeApprove()
Some older tokens return false instead of reverting.

### L-06: SeasonPredictor teamPredictors Array Unbounded
Can grow indefinitely causing gas issues in view functions.

### L-07: GameCore No Check for Zero Subscription ID
Constructor doesn't validate `_subscriptionId != 0`.

### L-08: TokenRegistry getStablecoins Double Loop Gas Inefficiency
Iterates array twice - once to count, once to build.

### L-09: BettingRouter receive() Function May Accept Unwanted ETH
Should validate ETH is only accepted during swap operations.

### L-10: LeagueBetToken Owner Can Mint Anytime
No timelocks or multi-sig protection on minting.

---

## Informational Findings

### I-01: Consider Using ERC2771 for Meta-Transactions
Would improve UX by allowing gasless betting.

### I-02: GameCore Team Names Hardcoded
No ability to update team names for new seasons.

### I-03: Missing NatSpec Documentation
Several functions lack complete documentation.

### I-04: Inconsistent Error Handling
Mix of `require()` and custom errors across contracts.

### I-05: No Getter for All User Predictions in SeasonPredictor
Would help frontend integration.

### I-06: Consider Pausable for All Periphery Contracts
Only BettingCore is pausable currently.

---

## Previously Fixed Issues (BettingCore)

The following issues from the initial audit have been verified as fixed:

| ID | Issue | Status |
|----|-------|--------|
| C-01 | Bet ID starts at 0 | ✅ Fixed |
| C-02 | Duplicate match indices | ✅ Fixed |
| H-02 | totalBetVolume not updated | ✅ Fixed |
| H-03 | CEI violation | ✅ Fixed |
| H-04 | No roundId validation | ✅ Fixed |
| M-02 | No batchClaim limit | ✅ Fixed |
| M-05 | Missing config events | ✅ Fixed |
| M-06 | Cancel after settlement | ✅ Fixed |

---

## Recommendations Summary

### Immediate Actions (Critical/High):
1. Remove user-provided seed from emergencySettleRound
2. Add deadline parameter to SwapRouter
3. Fix BettingRouter ownership verification
4. Add pagination index to SeasonPredictor batch distribution
5. Protect SeasonPredictor emergencyWithdraw from draining pending rewards

### Short-Term Actions (Medium):
1. Fix totalMinted accounting in LeagueBetToken
2. Add season validation to SeasonPredictor
3. Improve TokenRegistry removal gas efficiency
4. Add batch size limits to BettingRouter
5. Handle reward division dust

### Long-Term Improvements:
1. Consider timelock for admin functions
2. Add comprehensive event emission
3. Implement circuit breakers across all contracts
4. Add off-chain monitoring for suspicious activity

---

*This audit is provided for informational purposes. A formal audit by a professional security firm is recommended before mainnet deployment.*

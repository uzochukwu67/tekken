// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LiquidityPoolV2
 * @notice Unified AMM-style liquidity pool for betting protocol
 * @dev All risk and rewards flow through this pool:
 *      - LPs deposit LEAGUE tokens and receive proportional shares
 *      - Pool covers all payouts (base + parlay bonuses)
 *      - Pool funds round seeding (3k per round)
 *      - LPs earn from losing bets, lose from winning bets
 *      - Direct deduction model (losses immediately reduce pool value)
 */
contract LiquidityPoolV2 is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // ============ State Variables ============

    IERC20 public immutable leagueToken;

    // LP share accounting (AMM-style)
    uint256 public totalLiquidity;           // Total LEAGUE in pool
    uint256 public totalShares;              // Total LP shares issued
    mapping(address => uint256) public lpShares; // LP shares per address

    // LP deposit tracking (NEW - for profit/loss visibility)
    mapping(address => uint256) public lpInitialDeposit;    // Total LEAGUE deposited by LP
    mapping(address => uint256) public lpTotalWithdrawn;    // Total LEAGUE withdrawn by LP
    mapping(address => uint256) public lpDepositTimestamp;  // First deposit timestamp

    // Locked liquidity (for pending payouts and seeding)
    uint256 public lockedLiquidity;          // Temporarily locked for settlements
    uint256 public borrowedForPoolBalancing; // Borrowed for odds-weighted allocation (will return)

    // Round-based locking (prevents LP gaming during active rounds)
    bool public roundActive;                 // True when round is active (deposits/withdrawals blocked)

    // Authorized contracts (only betting pool can deduct/add)
    mapping(address => bool) public authorizedCallers;

    // Constants
    uint256 public constant MINIMUM_LIQUIDITY = 1000; // Prevent division by zero
    uint256 public constant WITHDRAWAL_FEE = 50; // 0.5% exit fee (50 basis points)

    // ============ Events ============

    event LiquidityAdded(address indexed provider, uint256 amount, uint256 shares);
    event LiquidityRemoved(address indexed provider, uint256 shares, uint256 amount, uint256 fee);
    event PayoutProcessed(address indexed winner, uint256 amount);
    event LosingBetCollected(uint256 amount);
    event SeedingFunded(uint256 roundId, uint256 amount);
    event LiquidityLocked(uint256 amount, uint256 totalLocked);
    event LiquidityUnlocked(uint256 amount, uint256 totalLocked);
    event EmergencyWithdraw(address indexed owner, uint256 amount);
    event RoundStatusChanged(bool active);   // Emitted when round active status changes

    // ============ Errors ============

    error InsufficientLiquidity();
    error InsufficientShares();
    error Unauthorized();
    error ZeroAmount();
    error TransferFailed();
    error MinimumLiquidityRequired();
    error RoundInProgress();        // LP deposits/withdrawals blocked during active round

    // ============ Constructor ============

    constructor(address _leagueToken, address _initialOwner) Ownable(_initialOwner) {
        require(_leagueToken != address(0), "Invalid token");
        leagueToken = IERC20(_leagueToken);
    }

    // ============ Modifiers ============

    modifier onlyAuthorized() {
        if (!authorizedCallers[msg.sender]) revert Unauthorized();
        _;
    }

    // ============ LP Functions ============

    /**
     * @notice Add liquidity to the pool and receive LP shares
     * @param amount Amount of LEAGUE tokens to deposit
     * @return shares Number of LP shares minted
     */
    function addLiquidity(uint256 amount) external nonReentrant returns (uint256 shares) {
        if (roundActive) revert RoundInProgress();
        if (amount == 0) revert ZeroAmount();

        // Transfer tokens from LP
        leagueToken.safeTransferFrom(msg.sender, address(this), amount);

        // Calculate shares (AMM formula)
        if (totalShares == 0) {
            // First LP: shares = amount (minus minimum liquidity lock)
            shares = amount - MINIMUM_LIQUIDITY;
            lpShares[address(0)] = MINIMUM_LIQUIDITY; // Lock minimum liquidity forever
            lpShares[msg.sender] = shares;
            totalShares = amount; // Total includes locked + LP's shares
            totalLiquidity = amount;
        } else {
            // Subsequent LPs: shares proportional to pool
            // shares = (amount * totalShares) / totalLiquidity
            shares = (amount * totalShares) / totalLiquidity;

            if (shares == 0) revert MinimumLiquidityRequired();

            // Update state
            lpShares[msg.sender] += shares;
            totalShares += shares;
            totalLiquidity += amount;
        }

        // Track deposit for profit/loss calculation
        lpInitialDeposit[msg.sender] += amount;
        if (lpDepositTimestamp[msg.sender] == 0) {
            lpDepositTimestamp[msg.sender] = block.timestamp;
        }

        emit LiquidityAdded(msg.sender, amount, shares);

        return shares;
    }

    /**
     * @notice Remove liquidity from the pool by burning LP shares
     * @param shares Number of LP shares to burn
     * @return amount Amount of LEAGUE tokens received (after withdrawal fee)
     */
    function removeLiquidity(uint256 shares) external nonReentrant returns (uint256 amount) {
        if (roundActive) revert RoundInProgress();
        if (shares == 0) revert ZeroAmount();
        if (lpShares[msg.sender] < shares) revert InsufficientShares();

        // Calculate amount to return
        // amount = (shares * totalLiquidity) / totalShares
        uint256 totalAmount = (shares * totalLiquidity) / totalShares;

        // Apply withdrawal fee (0.5%)
        uint256 fee = (totalAmount * WITHDRAWAL_FEE) / 10000;
        amount = totalAmount - fee;

        // Check sufficient unlocked liquidity
        uint256 availableLiquidity = totalLiquidity - lockedLiquidity;
        if (amount > availableLiquidity) revert InsufficientLiquidity();

        // Update state
        lpShares[msg.sender] -= shares;
        totalShares -= shares;
        totalLiquidity -= amount; // Fee stays in pool (benefits remaining LPs)

        // Track withdrawal for profit/loss calculation
        lpTotalWithdrawn[msg.sender] += amount;

        // Transfer tokens to LP
        leagueToken.safeTransfer(msg.sender, amount);

        emit LiquidityRemoved(msg.sender, shares, amount, fee);

        return amount;
    }

    // ============ Betting Pool Functions (Authorized Only) ============

    /**
     * @notice Collect losing bet into pool (increases LP value)
     * @param amount Amount of LEAGUE from losing bet
     * @dev Called by BettingPool when user loses
     */
    function collectLosingBet(uint256 amount) external onlyAuthorized {
        // Transfer tokens from caller (BettingPool) to this contract
        leagueToken.safeTransferFrom(msg.sender, address(this), amount);

        totalLiquidity += amount;
        emit LosingBetCollected(amount);
    }

    /**
     * @notice Pay out winning bet from pool (decreases LP value)
     * @param winner Address of winner
     * @param amount Total payout (base + parlay bonus)
     * @dev Called by BettingPool when user wins
     */
    function payWinner(address winner, uint256 amount) external onlyAuthorized nonReentrant {
        if (amount > totalLiquidity - lockedLiquidity) revert InsufficientLiquidity();

        // Check if this is a borrow (winner is BettingPool contract)
        bool isBorrow = (winner == msg.sender);

        totalLiquidity -= amount;

        if (isBorrow) {
            // Track borrowed amount (will be returned later)
            borrowedForPoolBalancing += amount;
        }

        leagueToken.safeTransfer(winner, amount);

        emit PayoutProcessed(winner, amount);
    }

    /**
     * @notice Return seed funds and profit to LP pool after round ends
     * @param amount Amount to return (seed + LP's share of profit)
     * @dev Called by BettingPool after round is finalized
     * @dev Tokens are transferred first, then this updates accounting
     */
    function returnSeedFunds(uint256 amount) external onlyAuthorized {
        totalLiquidity += amount;

        // Reduce borrowed tracking (funds are being returned)
        if (borrowedForPoolBalancing > 0) {
            if (amount >= borrowedForPoolBalancing) {
                // All borrowed funds returned
                amount -= borrowedForPoolBalancing;
                borrowedForPoolBalancing = 0;
            } else {
                // Partial return
                borrowedForPoolBalancing -= amount;
                amount = 0;
            }
        }

        emit LosingBetCollected(amount); // Reuse event for consistency
    }

    /**
     * @notice Fund round seeding from LP pool
     * @param roundId Round being seeded
     * @param amount Amount to seed (typically 3,000 LEAGUE)
     * @return success Whether seeding was successful
     * @dev Called by BettingPool before round starts
     */
    function fundSeeding(uint256 roundId, uint256 amount) external onlyAuthorized returns (bool) {
        if (amount > totalLiquidity - lockedLiquidity) {
            return false; // Not enough liquidity
        }

        totalLiquidity -= amount;

        // Track as borrowed (will be returned after round)
        borrowedForPoolBalancing += amount;

        // Transfer to betting pool for seeding
        leagueToken.safeTransfer(msg.sender, amount);

        emit SeedingFunded(roundId, amount);
        return true;
    }

    /**
     * @notice Lock liquidity for pending settlements
     * @param amount Amount to lock
     * @dev Called by BettingPool to reserve liquidity for known payouts
     */
    function lockLiquidity(uint256 amount) external onlyAuthorized {
        if (amount > totalLiquidity - lockedLiquidity) revert InsufficientLiquidity();

        lockedLiquidity += amount;
        emit LiquidityLocked(amount, lockedLiquidity);
    }

    /**
     * @notice Unlock liquidity after settlement
     * @param amount Amount to unlock
     * @dev Called by BettingPool after payouts are processed
     */
    function unlockLiquidity(uint256 amount) external onlyAuthorized {
        if (amount > lockedLiquidity) {
            lockedLiquidity = 0; // Safety: can't unlock more than locked
        } else {
            lockedLiquidity -= amount;
        }
        emit LiquidityUnlocked(amount, lockedLiquidity);
    }

    // ============ View Functions ============

    /**
     * @notice Get LP's share of the pool
     * @param lp Address of LP
     * @return shareAmount Amount of LEAGUE the LP can withdraw
     * @return sharePercentage Percentage of pool owned (in basis points)
     */
    function getLPValue(address lp) external view returns (uint256 shareAmount, uint256 sharePercentage) {
        if (totalShares == 0) return (0, 0);

        uint256 shares = lpShares[lp];
        shareAmount = (shares * totalLiquidity) / totalShares;
        sharePercentage = (shares * 10000) / totalShares; // Basis points

        return (shareAmount, sharePercentage);
    }

    /**
     * @notice Get available (unlocked) liquidity
     * @return available Amount of LEAGUE available for withdrawals/payouts
     */
    function getAvailableLiquidity() external view returns (uint256) {
        return totalLiquidity - lockedLiquidity;
    }

    /**
     * @notice Calculate shares that would be minted for a given deposit
     * @param amount Amount of LEAGUE to deposit
     * @return shares Number of shares that would be minted
     */
    function previewDeposit(uint256 amount) external view returns (uint256 shares) {
        if (totalShares == 0) {
            return amount - MINIMUM_LIQUIDITY;
        }
        return (amount * totalShares) / totalLiquidity;
    }

    /**
     * @notice Calculate LEAGUE amount for burning shares
     * @param shares Number of shares to burn
     * @return amount Amount of LEAGUE that would be received (after fee)
     */
    function previewWithdrawal(uint256 shares) external view returns (uint256 amount) {
        if (totalShares == 0) return 0;

        uint256 totalAmount = (shares * totalLiquidity) / totalShares;
        uint256 fee = (totalAmount * WITHDRAWAL_FEE) / 10000;
        return totalAmount - fee;
    }

    /**
     * @notice Check if pool has enough liquidity for a payout
     * @param amount Amount needed
     * @return sufficient Whether pool can cover the amount
     */
    function canCoverPayout(uint256 amount) external view returns (bool) {
        return amount <= (totalLiquidity - lockedLiquidity);
    }

    /**
     * @notice Get pool utilization rate
     * @return utilizationBPS Percentage of liquidity locked (in basis points)
     */
    function getUtilizationRate() external view returns (uint256 utilizationBPS) {
        if (totalLiquidity == 0) return 0;
        return (lockedLiquidity * 10000) / totalLiquidity;
    }

    /**
     * @notice Get comprehensive LP position details
     * @param lp Address of LP
     * @return initialDeposit Total amount deposited by LP
     * @return totalWithdrawn Total amount withdrawn by LP
     * @return currentValue Current value of LP's shares
     * @return profitLoss Absolute profit/loss (can be negative)
     * @return roiBPS Return on investment in basis points (10000 = 100%)
     * @return depositTimestamp When LP first deposited
     */
    function getLPPosition(address lp)
        external
        view
        returns (
            uint256 initialDeposit,
            uint256 totalWithdrawn,
            uint256 currentValue,
            int256 profitLoss,
            int256 roiBPS,
            uint256 depositTimestamp
        )
    {
        initialDeposit = lpInitialDeposit[lp];
        totalWithdrawn = lpTotalWithdrawn[lp];
        depositTimestamp = lpDepositTimestamp[lp];

        // Calculate current value of shares
        // Add back borrowed funds since they're temporarily out but will return
        uint256 effectiveLiquidity = totalLiquidity + borrowedForPoolBalancing;

        if (totalShares == 0) {
            currentValue = 0;
        } else {
            uint256 shares = lpShares[lp];
            currentValue = (shares * effectiveLiquidity) / totalShares;
        }

        // Calculate profit/loss
        // P/L = (currentValue + totalWithdrawn) - initialDeposit
        uint256 totalReceived = currentValue + totalWithdrawn;

        if (totalReceived >= initialDeposit) {
            profitLoss = int256(totalReceived - initialDeposit);
        } else {
            profitLoss = -int256(initialDeposit - totalReceived);
        }

        // Calculate ROI in basis points
        // ROI = (profitLoss / initialDeposit) * 10000
        if (initialDeposit == 0) {
            roiBPS = 0;
        } else {
            // Convert to int256 for signed math
            roiBPS = (profitLoss * 10000) / int256(initialDeposit);
        }

        return (
            initialDeposit,
            totalWithdrawn,
            currentValue,
            profitLoss,
            roiBPS,
            depositTimestamp
        );
    }

    /**
     * @notice Get LP's profit/loss summary (simplified view)
     * @param lp Address of LP
     * @return netDeposit Amount currently at risk (deposited - withdrawn)
     * @return currentValue Current value of LP's shares
     * @return unrealizedPL Unrealized profit/loss on current position
     * @return realizedPL Realized profit/loss from withdrawals
     */
    function getLPProfitLoss(address lp)
        external
        view
        returns (
            uint256 netDeposit,
            uint256 currentValue,
            int256 unrealizedPL,
            int256 realizedPL
        )
    {
        uint256 initialDeposit = lpInitialDeposit[lp];
        uint256 totalWithdrawn = lpTotalWithdrawn[lp];

        // Net deposit = what's currently at risk
        if (initialDeposit >= totalWithdrawn) {
            netDeposit = initialDeposit - totalWithdrawn;
        } else {
            netDeposit = 0; // Withdrawn more than deposited (profitable)
        }

        // Calculate current value of shares
        // Add back borrowed funds since they're temporarily out but will return
        uint256 effectiveLiquidity = totalLiquidity + borrowedForPoolBalancing;

        if (totalShares == 0) {
            currentValue = 0;
        } else {
            uint256 shares = lpShares[lp];
            currentValue = (shares * effectiveLiquidity) / totalShares;
        }

        // Unrealized P/L = current value vs net deposit
        if (currentValue >= netDeposit) {
            unrealizedPL = int256(currentValue - netDeposit);
        } else {
            unrealizedPL = -int256(netDeposit - currentValue);
        }

        // Realized P/L = withdrawn vs amount that was at risk when withdrawing
        // Simplified: if withdrawn > deposited, that's realized profit
        if (totalWithdrawn >= initialDeposit) {
            realizedPL = int256(totalWithdrawn - initialDeposit);
        } else {
            realizedPL = 0; // No realized profit yet
        }

        return (netDeposit, currentValue, unrealizedPL, realizedPL);
    }

    /**
     * @notice Get all LP addresses and their positions (for frontend dashboard)
     * @dev This is gas-intensive, should only be called off-chain
     * @return lpAddresses Array of LP addresses (empty in this version - would need tracking)
     */
    function getAllLPs() external view returns (address[] memory lpAddresses) {
        // Note: This would require tracking all LP addresses in a separate array
        // For now, frontend should track addresses via events
        return new address[](0);
    }

    /**
     * @notice Check if address is an active LP
     * @param lp Address to check
     * @return isActive Whether address has LP shares
     */
    function isActiveLP(address lp) external view returns (bool isActive) {
        return lpShares[lp] > 0;
    }

    // ============ M-7 Fix: Enhanced LP Profit Tracking ============

    /**
     * @notice Get comprehensive LP position with risk metrics
     * @param lp Address of LP
     * @return initialDeposit Total amount deposited
     * @return totalWithdrawn Total amount withdrawn
     * @return currentValue Current value (optimistic - includes borrowed funds)
     * @return realizedValue Current value (conservative - excludes locked liquidity)
     * @return atRiskAmount Amount currently locked in pending bets
     * @return profitLoss Overall profit/loss
     * @return roiBPS Return on investment in basis points
     */
    function getLPPositionDetailed(address lp)
        external
        view
        returns (
            uint256 initialDeposit,
            uint256 totalWithdrawn,
            uint256 currentValue,
            uint256 realizedValue,
            uint256 atRiskAmount,
            int256 profitLoss,
            int256 roiBPS
        )
    {
        initialDeposit = lpInitialDeposit[lp];
        totalWithdrawn = lpTotalWithdrawn[lp];
        uint256 shares = lpShares[lp];

        if (totalShares == 0 || shares == 0) {
            return (initialDeposit, totalWithdrawn, 0, 0, 0, -int256(initialDeposit), -10000);
        }

        // Optimistic value: includes borrowed funds (will return)
        uint256 effectiveLiquidity = totalLiquidity + borrowedForPoolBalancing;
        currentValue = (shares * effectiveLiquidity) / totalShares;

        // Conservative value: excludes locked liquidity (at risk in pending bets)
        uint256 availableLiquidity = totalLiquidity > lockedLiquidity
            ? totalLiquidity - lockedLiquidity
            : 0;
        realizedValue = (shares * availableLiquidity) / totalShares;

        // Amount at risk in pending bets
        if (currentValue > realizedValue) {
            atRiskAmount = currentValue - realizedValue;
        } else {
            atRiskAmount = 0;
        }

        // Calculate profit/loss using optimistic value
        uint256 totalReceived = currentValue + totalWithdrawn;
        if (totalReceived >= initialDeposit) {
            profitLoss = int256(totalReceived - initialDeposit);
        } else {
            profitLoss = -int256(initialDeposit - totalReceived);
        }

        // Calculate ROI in basis points
        if (initialDeposit == 0) {
            roiBPS = 0;
        } else {
            roiBPS = (profitLoss * 10000) / int256(initialDeposit);
        }

        return (
            initialDeposit,
            totalWithdrawn,
            currentValue,
            realizedValue,
            atRiskAmount,
            profitLoss,
            roiBPS
        );
    }

    // ============ H-6 Fix: Withdrawal Helper Functions ============

    /**
     * @notice Get maximum withdrawable amount for an LP
     * @param lp Address of LP
     * @return maxWithdrawable Maximum amount that can be withdrawn now
     * @return totalValue Total value of LP's shares
     */
    function getMaxWithdrawableAmount(address lp)
        external
        view
        returns (uint256 maxWithdrawable, uint256 totalValue)
    {
        uint256 shares = lpShares[lp];
        if (shares == 0) return (0, 0);

        // Calculate total value of shares
        totalValue = (shares * totalLiquidity) / totalShares;

        // Apply withdrawal fee
        uint256 fee = (totalValue * WITHDRAWAL_FEE) / 10000;
        uint256 amountAfterFee = totalValue - fee;

        // Check available liquidity
        uint256 availableLiquidity = totalLiquidity > lockedLiquidity
            ? totalLiquidity - lockedLiquidity
            : 0;

        // Maximum withdrawable is the lesser of LP's value and available liquidity
        maxWithdrawable = amountAfterFee > availableLiquidity
            ? availableLiquidity
            : amountAfterFee;

        return (maxWithdrawable, totalValue);
    }

    /**
     * @notice Partial withdrawal - withdraw as much as possible up to requested shares
     * @param shares Maximum shares to burn
     * @return amount Amount of LEAGUE tokens received
     * @return sharesBurned Actual shares burned (may be less than requested)
     * @dev Allows partial withdrawals when liquidity is locked
     */
    function partialWithdrawal(uint256 shares)
        external
        nonReentrant
        returns (uint256 amount, uint256 sharesBurned)
    {
        if (shares == 0) revert ZeroAmount();
        if (lpShares[msg.sender] < shares) revert InsufficientShares();

        uint256 availableLiquidity = totalLiquidity > lockedLiquidity
            ? totalLiquidity - lockedLiquidity
            : 0;

        if (availableLiquidity == 0) revert InsufficientLiquidity();

        // Calculate how many shares can be withdrawn based on available liquidity
        // totalAmount = (shares * totalLiquidity) / totalShares
        uint256 requestedAmount = (shares * totalLiquidity) / totalShares;
        uint256 fee = (requestedAmount * WITHDRAWAL_FEE) / 10000;
        uint256 requestedAmountAfterFee = requestedAmount - fee;

        if (requestedAmountAfterFee <= availableLiquidity) {
            // Can withdraw full amount
            sharesBurned = shares;
            amount = requestedAmountAfterFee;
        } else {
            // Can only withdraw partial amount
            // Work backwards: amount = availableLiquidity
            amount = availableLiquidity;

            // Calculate required total (before fee) to get this amount
            // amount = total - (total * fee / 10000)
            // amount = total * (1 - fee/10000)
            // total = amount / (1 - fee/10000)
            uint256 totalNeeded = (amount * 10000) / (10000 - WITHDRAWAL_FEE);

            // Calculate shares needed for this total
            sharesBurned = (totalNeeded * totalShares) / totalLiquidity;

            // Ensure we don't burn more shares than requested
            if (sharesBurned > shares) {
                sharesBurned = shares;
                amount = requestedAmountAfterFee;
            }
        }

        // Update state
        lpShares[msg.sender] -= sharesBurned;
        totalShares -= sharesBurned;
        totalLiquidity -= amount; // Fee stays in pool

        // Track withdrawal
        lpTotalWithdrawn[msg.sender] += amount;

        // Transfer tokens
        leagueToken.safeTransfer(msg.sender, amount);

        emit LiquidityRemoved(msg.sender, sharesBurned, amount, fee);

        return (amount, sharesBurned);
    }

    // ============ Admin Functions ============

    /**
     * @notice Authorize a contract to interact with the pool
     * @param caller Address to authorize (typically BettingPool)
     * @param authorized Whether to authorize or revoke
     */
    function setAuthorizedCaller(address caller, bool authorized) external onlyOwner {
        authorizedCallers[caller] = authorized;
    }

    /**
     * @notice Set round active status to lock/unlock LP deposits and withdrawals
     * @param active True to lock (round in progress), false to unlock (round ended)
     * @dev Called by BettingPool when round starts and after revenue is finalized
     */
    function setRoundActive(bool active) external onlyAuthorized {
        roundActive = active;
        emit RoundStatusChanged(active);
    }

    /**
     * @notice Emergency withdraw (owner only, use with extreme caution)
     * @param amount Amount to withdraw
     * @dev Should only be used in catastrophic scenarios
     */
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        if (amount > leagueToken.balanceOf(address(this))) revert InsufficientLiquidity();

        leagueToken.safeTransfer(owner(), amount);

        emit EmergencyWithdraw(owner(), amount);
    }

    // ============ Recovery Functions ============

    /**
     * @notice Recover ERC20 tokens sent by mistake
     * @param token Token to recover
     * @param amount Amount to recover
     * @dev Cannot recover LEAGUE tokens (would break accounting)
     */
    function recoverERC20(address token, uint256 amount) external onlyOwner {
        require(token != address(leagueToken), "Cannot recover LEAGUE");
        IERC20(token).transfer(owner(), amount);
    }
}

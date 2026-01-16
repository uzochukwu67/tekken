// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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
    // ============ State Variables ============

    IERC20 public immutable leagueToken;

    // LP share accounting (AMM-style)
    uint256 public totalLiquidity;           // Total LEAGUE in pool
    uint256 public totalShares;              // Total LP shares issued
    mapping(address => uint256) public lpShares; // LP shares per address

    // Locked liquidity (for pending payouts and seeding)
    uint256 public lockedLiquidity;          // Temporarily locked for settlements

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

    // ============ Errors ============

    error InsufficientLiquidity();
    error InsufficientShares();
    error Unauthorized();
    error ZeroAmount();
    error TransferFailed();
    error MinimumLiquidityRequired();

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
        if (amount == 0) revert ZeroAmount();

        // Transfer tokens from LP
        if (!leagueToken.transferFrom(msg.sender, address(this), amount)) {
            revert TransferFailed();
        }

        // Calculate shares (AMM formula)
        if (totalShares == 0) {
            // First LP: shares = amount (minus minimum liquidity lock)
            shares = amount - MINIMUM_LIQUIDITY;
            totalShares = amount;
            lpShares[address(0)] = MINIMUM_LIQUIDITY; // Lock minimum liquidity forever
        } else {
            // Subsequent LPs: shares proportional to pool
            // shares = (amount * totalShares) / totalLiquidity
            shares = (amount * totalShares) / totalLiquidity;
        }

        if (shares == 0) revert MinimumLiquidityRequired();

        // Update state
        lpShares[msg.sender] += shares;
        totalShares += shares;
        totalLiquidity += amount;

        emit LiquidityAdded(msg.sender, amount, shares);

        return shares;
    }

    /**
     * @notice Remove liquidity from the pool by burning LP shares
     * @param shares Number of LP shares to burn
     * @return amount Amount of LEAGUE tokens received (after withdrawal fee)
     */
    function removeLiquidity(uint256 shares) external nonReentrant returns (uint256 amount) {
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

        // Transfer tokens to LP
        if (!leagueToken.transfer(msg.sender, amount)) {
            revert TransferFailed();
        }

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
        if (!leagueToken.transferFrom(msg.sender, address(this), amount)) {
            revert TransferFailed();
        }

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

        totalLiquidity -= amount;

        if (!leagueToken.transfer(winner, amount)) {
            revert TransferFailed();
        }

        emit PayoutProcessed(winner, amount);
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

        // Transfer to betting pool for seeding
        if (!leagueToken.transfer(msg.sender, amount)) {
            revert TransferFailed();
        }

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
     * @notice Emergency withdraw (owner only, use with extreme caution)
     * @param amount Amount to withdraw
     * @dev Should only be used in catastrophic scenarios
     */
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        if (amount > leagueToken.balanceOf(address(this))) revert InsufficientLiquidity();

        if (!leagueToken.transfer(owner(), amount)) {
            revert TransferFailed();
        }

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

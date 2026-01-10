// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title LiquidityPool
 * @notice Manages LP deposits, withdrawals, and liquidity locking for betting payouts
 * @dev LPs provide liquidity to back bonus payouts for winning bets
 */
contract LiquidityPool is ERC20, Ownable, ReentrancyGuard {
    IERC20 public immutable leagueToken;

    // Pool parameters
    uint256 public constant MAX_UTILIZATION = 70; // 70% max utilization
    uint256 public constant MAX_BET_PERCENTAGE = 2; // 2% max bet size
    uint256 public constant MIN_POOL_RESERVE = 1000e18; // 1k tokens minimum

    // Pool state
    uint256 public totalLiquidity;
    uint256 public lockedLiquidity;

    // Withdrawal cooldown tracking
    mapping(address => uint256) public lastDepositTime;
    uint256 public constant WITHDRAWAL_COOLDOWN = 15 minutes; // Must wait for round duration

    // Authorized contracts
    mapping(address => bool) public authorizedCallers;

    // Events
    event LiquidityAdded(address indexed provider, uint256 amount, uint256 shares);
    event LiquidityRemoved(address indexed provider, uint256 amount, uint256 shares);
    event LiquidityLocked(uint256 amount, uint256 totalLocked);
    event LiquidityUnlocked(uint256 amount, uint256 totalLocked);
    event PayoutProcessed(address indexed winner, uint256 amount);
    event AuthorizedCallerUpdated(address indexed caller, bool authorized);

    constructor(
        address _leagueToken,
        address _initialOwner
    ) ERC20("IVirtualz LP Token", "vLP") Ownable(_initialOwner) {
        leagueToken = IERC20(_leagueToken);
    }

    modifier onlyAuthorized() {
        require(authorizedCallers[msg.sender], "Not authorized");
        _;
    }

    /**
     * @notice Add liquidity to the pool and receive LP tokens
     * @param amount Amount of LEAGUE tokens to deposit
     */
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be > 0");

        uint256 shares;
        if (totalSupply() == 0 || totalLiquidity == 0) {
            // Initial deposit: 1:1 ratio with minimum to prevent share inflation
            require(amount >= 1000e18, "Initial deposit must be >= 1000 LEAGUE");
            shares = amount;
        } else {
            // Calculate shares based on current pool ratio
            // Account for locked liquidity in calculation
            uint256 effectiveLiquidity = totalLiquidity;
            shares = (amount * totalSupply()) / effectiveLiquidity;
        }

        require(shares > 0, "Shares must be > 0");

        // Transfer tokens from user
        require(
            leagueToken.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        // Update state
        totalLiquidity += amount;
        lastDepositTime[msg.sender] = block.timestamp;

        // Mint LP tokens
        _mint(msg.sender, shares);

        emit LiquidityAdded(msg.sender, amount, shares);
    }

    /**
     * @notice Withdraw liquidity by burning LP tokens
     * @param shares Amount of LP tokens to burn
     */
    function withdraw(uint256 shares) external nonReentrant {
        require(shares > 0, "Shares must be > 0");
        require(balanceOf(msg.sender) >= shares, "Insufficient shares");

        // Enforce withdrawal cooldown (15 minutes = 1 round duration)
        // This prevents LPs from withdrawing immediately before payouts
        require(
            block.timestamp >= lastDepositTime[msg.sender] + WITHDRAWAL_COOLDOWN,
            "Withdrawal cooldown active - wait for round to complete"
        );

        // Calculate underlying token amount
        uint256 amount = (shares * totalLiquidity) / totalSupply();

        // Check if enough liquidity is available (not locked)
        uint256 availableLiquidity = totalLiquidity - lockedLiquidity;
        require(amount <= availableLiquidity, "Insufficient available liquidity");

        // Burn LP tokens
        _burn(msg.sender, shares);

        // Update state
        totalLiquidity -= amount;

        // Transfer tokens to user
        require(leagueToken.transfer(msg.sender, amount), "Transfer failed");

        emit LiquidityRemoved(msg.sender, amount, shares);
    }

    /**
     * @notice Get available (unlocked) liquidity
     */
    function getAvailableLiquidity() public view returns (uint256) {
        return totalLiquidity - lockedLiquidity;
    }

    /**
     * @notice Get total liquidity in pool
     */
    function getTotalLiquidity() public view returns (uint256) {
        return totalLiquidity;
    }

    /**
     * @notice Get current pool utilization percentage
     */
    function getUtilization() public view returns (uint256) {
        if (totalLiquidity == 0) return 0;
        return (lockedLiquidity * 100) / totalLiquidity;
    }

    /**
     * @notice Get dynamic pool bonus multiplier based on utilization
     * @return multiplier in basis points (200 = 2x, 150 = 1.5x, etc.)
     */
    function getPoolMultiplier() public view returns (uint256) {
        uint256 utilization = getUtilization();

        if (utilization < 30) return 200; // 2x pool bonus
        if (utilization < 50) return 150; // 1.5x pool bonus
        if (utilization < 70) return 100; // 1x pool bonus
        if (utilization < 85) return 50;  // 0.5x pool bonus
        return 25; // 0.25x pool bonus (nearly depleted)
    }

    /**
     * @notice Check if liquidity can be locked for a bet
     * @param amount Amount to lock
     */
    function canLockLiquidity(uint256 amount) public view returns (bool) {
        if (totalLiquidity == 0) return false;

        uint256 available = getAvailableLiquidity();
        uint256 newUtilization = ((lockedLiquidity + amount) * 100) / totalLiquidity;
        uint256 maxBetSize = (totalLiquidity * MAX_BET_PERCENTAGE) / 100;

        return amount <= available
            && newUtilization <= MAX_UTILIZATION
            && amount <= maxBetSize
            && totalLiquidity >= MIN_POOL_RESERVE;
    }

    /**
     * @notice Lock liquidity for an active bet
     * @param amount Amount to lock
     */
    function lockLiquidity(uint256 amount) external onlyAuthorized {
        require(canLockLiquidity(amount), "Cannot lock liquidity");
        lockedLiquidity += amount;
        emit LiquidityLocked(amount, lockedLiquidity);
    }

    /**
     * @notice Unlock liquidity when bet is settled (lost)
     * @param amount Amount to unlock
     */
    function unlockLiquidity(uint256 amount) external onlyAuthorized {
        require(lockedLiquidity >= amount, "Insufficient locked liquidity");
        lockedLiquidity -= amount;
        emit LiquidityUnlocked(amount, lockedLiquidity);
    }

    /**
     * @notice Unlock and pay out to winner (bet won)
     * @param winner Address to receive payout
     * @param amount Amount to pay
     */
    function unlockAndPay(address winner, uint256 amount) external onlyAuthorized {
        require(lockedLiquidity >= amount, "Insufficient locked liquidity");
        require(totalLiquidity >= amount, "Insufficient total liquidity");

        lockedLiquidity -= amount;
        totalLiquidity -= amount;

        require(leagueToken.transfer(winner, amount), "Transfer failed");

        emit PayoutProcessed(winner, amount);
        emit LiquidityUnlocked(amount, lockedLiquidity);
    }

    /**
     * @notice Add liquidity from losing bets (protocol contribution)
     * @param amount Amount to add
     */
    function addLiquidity(uint256 amount) external onlyAuthorized {
        totalLiquidity += amount;
    }

    /**
     * @notice Set authorized caller (BettingPool contract)
     * @param caller Address to authorize
     * @param authorized Authorization status
     */
    function setAuthorizedCaller(address caller, bool authorized) external onlyOwner {
        authorizedCallers[caller] = authorized;
        emit AuthorizedCallerUpdated(caller, authorized);
    }

    /**
     * @notice Get LP position value for an address
     * @param account LP address
     */
    function getPositionValue(address account) external view returns (uint256) {
        uint256 shares = balanceOf(account);
        if (shares == 0 || totalSupply() == 0) return 0;
        return (shares * totalLiquidity) / totalSupply();
    }
}

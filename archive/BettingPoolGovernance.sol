// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BettingPoolGovernance
 * @notice Minimal governance layer for BettingPool parameters
 * @dev Extends BettingPoolV2_1 with governable parameters and emergency controls
 *
 * Features:
 * - Timelock on parameter changes (48 hours)
 * - Emergency pause mechanism
 * - Bounded parameter ranges for safety
 * - Reserve management controls
 */
abstract contract BettingPoolGovernance is Ownable {

    // ============================================
    // GOVERNABLE PARAMETERS
    // ============================================

    /// @notice Protocol revenue share (basis points, e.g., 3000 = 30%)
    uint256 public protocolCutBps = 3000; // Default: 30%

    /// @notice Season predictor revenue share (basis points)
    uint256 public seasonCutBps = 200; // Default: 2%

    /// @notice Liquidity pool bonus share (basis points)
    uint256 public lpBonusBps = 500; // Default: 5%

    /// @notice Seed amount per match (total across all outcomes)
    uint256 public seedPerMatch = 300 ether; // Default: 300 LEAGUE

    /// @notice Individual outcome seed amounts (must sum to seedPerMatch)
    uint256 public seedHomePool = 120 ether;
    uint256 public seedAwayPool = 80 ether;
    uint256 public seedDrawPool = 100 ether;

    /// @notice Round duration (seconds)
    uint256 public roundDuration = 15 minutes; // Default: 15 minutes

    /// @notice Pool imbalance threshold for bonus distribution
    uint256 public imbalanceThresholdBps = 4000; // Default: 40%

    /// @notice Parlay multipliers per leg count (1e18 scale)
    mapping(uint256 => uint256) public parlayMultipliers;

    /// @notice Maximum bet size per match (0 = unlimited)
    uint256 public maxBetPerMatch = 0;

    /// @notice Emergency pause state
    bool public paused = false;

    // ============================================
    // TIMELOCK SYSTEM
    // ============================================

    /// @notice Timelock duration (48 hours)
    uint256 public constant TIMELOCK_DURATION = 48 hours;

    /// @notice Pending parameter changes
    struct PendingChange {
        uint256 value;
        uint256 executeAfter;
        bool exists;
    }

    mapping(bytes32 => PendingChange) public pendingChanges;

    // ============================================
    // PARAMETER BOUNDS (Safety Limits)
    // ============================================

    uint256 public constant MIN_PROTOCOL_CUT = 1000; // 10%
    uint256 public constant MAX_PROTOCOL_CUT = 5000; // 50%

    uint256 public constant MIN_SEED_PER_MATCH = 100 ether;
    uint256 public constant MAX_SEED_PER_MATCH = 1000 ether;

    uint256 public constant MIN_ROUND_DURATION = 5 minutes;
    uint256 public constant MAX_ROUND_DURATION = 60 minutes;

    uint256 public constant MIN_IMBALANCE_THRESHOLD = 2000; // 20%
    uint256 public constant MAX_IMBALANCE_THRESHOLD = 6000; // 60%

    // ============================================
    // EVENTS
    // ============================================

    event ParameterChangeProposed(bytes32 indexed paramHash, string paramName, uint256 newValue, uint256 executeAfter);
    event ParameterChangeExecuted(bytes32 indexed paramHash, string paramName, uint256 newValue);
    event ParameterChangeCancelled(bytes32 indexed paramHash, string paramName);
    event EmergencyPause(address indexed caller);
    event EmergencyUnpause(address indexed caller);
    event ProtocolReserveWithdrawn(address indexed to, uint256 amount);
    event MaxBetPerMatchUpdated(uint256 newMaxBet);

    // ============================================
    // ERRORS
    // ============================================

    error ContractPaused();
    error ParameterOutOfBounds();
    error TimelockNotExpired();
    error NoPendingChange();
    error InvalidParameterSum();

    // ============================================
    // MODIFIERS
    // ============================================

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    // ============================================
    // CONSTRUCTOR
    // ============================================

    constructor() {
        // Initialize default parlay multipliers
        parlayMultipliers[2] = 2.5e18;  // 2-leg: 2.5x
        parlayMultipliers[3] = 4.0e18;  // 3-leg: 4.0x
        parlayMultipliers[4] = 6.0e18;  // 4-leg: 6.0x
        parlayMultipliers[5] = 10.0e18; // 5-leg: 10.0x
    }

    // ============================================
    // TIMELOCK FUNCTIONS
    // ============================================

    /**
     * @notice Propose a parameter change (stage 1 of 2)
     * @dev Change executes after TIMELOCK_DURATION
     */
    function proposeParameterChange(string calldata paramName, uint256 newValue)
        external
        onlyOwner
    {
        bytes32 paramHash = keccak256(abi.encodePacked(paramName));

        // Validate bounds based on parameter
        _validateParameterBounds(paramName, newValue);

        pendingChanges[paramHash] = PendingChange({
            value: newValue,
            executeAfter: block.timestamp + TIMELOCK_DURATION,
            exists: true
        });

        emit ParameterChangeProposed(paramHash, paramName, newValue, block.timestamp + TIMELOCK_DURATION);
    }

    /**
     * @notice Execute a pending parameter change (stage 2 of 2)
     * @dev Can only execute after timelock expires
     */
    function executeParameterChange(string calldata paramName)
        external
        onlyOwner
    {
        bytes32 paramHash = keccak256(abi.encodePacked(paramName));
        PendingChange memory change = pendingChanges[paramHash];

        if (!change.exists) revert NoPendingChange();
        if (block.timestamp < change.executeAfter) revert TimelockNotExpired();

        // Execute the change
        _applyParameterChange(paramName, change.value);

        // Clear pending change
        delete pendingChanges[paramHash];

        emit ParameterChangeExecuted(paramHash, paramName, change.value);
    }

    /**
     * @notice Cancel a pending parameter change
     */
    function cancelParameterChange(string calldata paramName)
        external
        onlyOwner
    {
        bytes32 paramHash = keccak256(abi.encodePacked(paramName));

        if (!pendingChanges[paramHash].exists) revert NoPendingChange();

        delete pendingChanges[paramHash];

        emit ParameterChangeCancelled(paramHash, paramName);
    }

    // ============================================
    // INTERNAL PARAMETER LOGIC
    // ============================================

    function _validateParameterBounds(string calldata paramName, uint256 value) internal pure {
        bytes32 paramHash = keccak256(abi.encodePacked(paramName));

        if (paramHash == keccak256("protocolCutBps")) {
            if (value < MIN_PROTOCOL_CUT || value > MAX_PROTOCOL_CUT) {
                revert ParameterOutOfBounds();
            }
        } else if (paramHash == keccak256("seedPerMatch")) {
            if (value < MIN_SEED_PER_MATCH || value > MAX_SEED_PER_MATCH) {
                revert ParameterOutOfBounds();
            }
        } else if (paramHash == keccak256("roundDuration")) {
            if (value < MIN_ROUND_DURATION || value > MAX_ROUND_DURATION) {
                revert ParameterOutOfBounds();
            }
        } else if (paramHash == keccak256("imbalanceThresholdBps")) {
            if (value < MIN_IMBALANCE_THRESHOLD || value > MAX_IMBALANCE_THRESHOLD) {
                revert ParameterOutOfBounds();
            }
        }
        // Note: Other parameters have implicit bounds (e.g., seasonCutBps < 10000)
    }

    function _applyParameterChange(string calldata paramName, uint256 value) internal {
        bytes32 paramHash = keccak256(abi.encodePacked(paramName));

        if (paramHash == keccak256("protocolCutBps")) {
            protocolCutBps = value;
        } else if (paramHash == keccak256("seasonCutBps")) {
            seasonCutBps = value;
        } else if (paramHash == keccak256("lpBonusBps")) {
            lpBonusBps = value;
        } else if (paramHash == keccak256("seedPerMatch")) {
            seedPerMatch = value;
        } else if (paramHash == keccak256("roundDuration")) {
            roundDuration = value;
        } else if (paramHash == keccak256("imbalanceThresholdBps")) {
            imbalanceThresholdBps = value;
        } else {
            revert("Unknown parameter");
        }
    }

    // ============================================
    // SEED DISTRIBUTION GOVERNANCE
    // ============================================

    /**
     * @notice Update individual outcome seed amounts
     * @dev Must sum to seedPerMatch for consistency
     */
    function updateSeedDistribution(
        uint256 newHomePool,
        uint256 newAwayPool,
        uint256 newDrawPool
    ) external onlyOwner {
        // Validate sum
        if (newHomePool + newAwayPool + newDrawPool != seedPerMatch) {
            revert InvalidParameterSum();
        }

        seedHomePool = newHomePool;
        seedAwayPool = newAwayPool;
        seedDrawPool = newDrawPool;
    }

    /**
     * @notice Update parlay multiplier for specific leg count
     */
    function updateParlayMultiplier(uint256 numLegs, uint256 multiplier)
        external
        onlyOwner
    {
        require(numLegs >= 2 && numLegs <= 5, "Invalid leg count");
        require(multiplier >= 1.5e18 && multiplier <= 20e18, "Multiplier out of range");

        parlayMultipliers[numLegs] = multiplier;
    }

    // ============================================
    // EMERGENCY CONTROLS
    // ============================================

    /**
     * @notice Emergency pause all betting activity
     * @dev No timelock - immediate effect
     */
    function pause() external onlyOwner {
        paused = true;
        emit EmergencyPause(msg.sender);
    }

    /**
     * @notice Unpause betting activity
     */
    function unpause() external onlyOwner {
        paused = false;
        emit EmergencyUnpause(msg.sender);
    }

    /**
     * @notice Set maximum bet size per match
     * @dev 0 = unlimited, useful for preventing whale attacks
     */
    function setMaxBetPerMatch(uint256 maxBet) external onlyOwner {
        maxBetPerMatch = maxBet;
        emit MaxBetPerMatchUpdated(maxBet);
    }

    // ============================================
    // VIEW FUNCTIONS
    // ============================================

    /**
     * @notice Get pending change details
     */
    function getPendingChange(string calldata paramName)
        external
        view
        returns (uint256 value, uint256 executeAfter, bool exists)
    {
        bytes32 paramHash = keccak256(abi.encodePacked(paramName));
        PendingChange memory change = pendingChanges[paramHash];
        return (change.value, change.executeAfter, change.exists);
    }

    /**
     * @notice Check if parameter change is ready to execute
     */
    function canExecuteChange(string calldata paramName) external view returns (bool) {
        bytes32 paramHash = keccak256(abi.encodePacked(paramName));
        PendingChange memory change = pendingChanges[paramHash];

        return change.exists && block.timestamp >= change.executeAfter;
    }

    /**
     * @notice Get all current governance parameters
     */
    function getGovernanceParameters()
        external
        view
        returns (
            uint256 _protocolCutBps,
            uint256 _seasonCutBps,
            uint256 _lpBonusBps,
            uint256 _seedPerMatch,
            uint256 _roundDuration,
            uint256 _imbalanceThresholdBps,
            uint256 _maxBetPerMatch,
            bool _paused
        )
    {
        return (
            protocolCutBps,
            seasonCutBps,
            lpBonusBps,
            seedPerMatch,
            roundDuration,
            imbalanceThresholdBps,
            maxBetPerMatch,
            paused
        );
    }
}

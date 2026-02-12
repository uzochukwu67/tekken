// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title TokenRegistry
 * @notice Registry of supported tokens for betting
 * @dev Manages whitelisted tokens and their associated liquidity pools
 */
contract TokenRegistry is Ownable {
    // ============ Structs ============

    struct TokenInfo {
        address pool;           // Associated liquidity pool
        uint8 decimals;         // Token decimals
        bool enabled;           // Whether token is active
        bool isStablecoin;      // Whether token is a stablecoin
        uint256 minBet;         // Minimum bet in this token
        uint256 maxBet;         // Maximum bet in this token
    }

    // ============ State ============

    /// @notice Token address => TokenInfo
    mapping(address => TokenInfo) public tokens;

    /// @notice Array of all registered tokens
    address[] public allTokens;

    /// @notice Default/primary token for the platform
    address public primaryToken;

    // ============ Events ============

    event TokenAdded(
        address indexed token,
        address indexed pool,
        bool isStablecoin
    );

    event TokenUpdated(
        address indexed token,
        address indexed pool,
        bool enabled
    );

    event TokenRemoved(address indexed token);

    event PrimaryTokenChanged(
        address indexed oldToken,
        address indexed newToken
    );

    // ============ Errors ============

    error TokenAlreadyExists();
    error TokenNotFound();
    error InvalidAddress();
    error InvalidDecimals();

    // ============ Constructor ============

    constructor(address _initialOwner) Ownable(_initialOwner) {}

    // ============ Admin Functions ============

    /**
     * @notice Add a new supported token
     * @param token Token address
     * @param pool Associated liquidity pool
     * @param isStablecoin Whether this is a stablecoin
     * @param minBet Minimum bet amount
     * @param maxBet Maximum bet amount
     */
    function addToken(
        address token,
        address pool,
        bool isStablecoin,
        uint256 minBet,
        uint256 maxBet
    ) external onlyOwner {
        if (token == address(0)) revert InvalidAddress();
        if (pool == address(0)) revert InvalidAddress();
        if (tokens[token].pool != address(0)) revert TokenAlreadyExists();

        uint8 decimals = IERC20Metadata(token).decimals();
        if (decimals == 0 || decimals > 18) revert InvalidDecimals();

        tokens[token] = TokenInfo({
            pool: pool,
            decimals: decimals,
            enabled: true,
            isStablecoin: isStablecoin,
            minBet: minBet,
            maxBet: maxBet
        });

        allTokens.push(token);

        // Set as primary if first token
        if (primaryToken == address(0)) {
            primaryToken = token;
        }

        emit TokenAdded(token, pool, isStablecoin);
    }

    /**
     * @notice Update token configuration
     * @param token Token address
     * @param pool New pool address (or address(0) to keep current)
     * @param enabled Whether token is enabled
     * @param minBet New minimum bet
     * @param maxBet New maximum bet
     */
    function updateToken(
        address token,
        address pool,
        bool enabled,
        uint256 minBet,
        uint256 maxBet
    ) external onlyOwner {
        TokenInfo storage info = tokens[token];
        if (info.pool == address(0)) revert TokenNotFound();

        if (pool != address(0)) {
            info.pool = pool;
        }
        info.enabled = enabled;
        info.minBet = minBet;
        info.maxBet = maxBet;

        emit TokenUpdated(token, info.pool, enabled);
    }

    /**
     * @notice Remove a token from registry
     * @param token Token address to remove
     */
    function removeToken(address token) external onlyOwner {
        if (tokens[token].pool == address(0)) revert TokenNotFound();

        delete tokens[token];

        // Remove from array
        for (uint256 i = 0; i < allTokens.length; i++) {
            if (allTokens[i] == token) {
                allTokens[i] = allTokens[allTokens.length - 1];
                allTokens.pop();
                break;
            }
        }

        // Update primary if needed
        if (primaryToken == token) {
            primaryToken = allTokens.length > 0 ? allTokens[0] : address(0);
        }

        emit TokenRemoved(token);
    }

    /**
     * @notice Set the primary token
     * @param token New primary token
     */
    function setPrimaryToken(address token) external onlyOwner {
        if (tokens[token].pool == address(0)) revert TokenNotFound();

        address oldPrimary = primaryToken;
        primaryToken = token;

        emit PrimaryTokenChanged(oldPrimary, token);
    }

    // ============ View Functions ============

    /**
     * @notice Check if token is supported and enabled
     * @param token Token address
     * @return supported Whether token is supported and enabled
     */
    function isSupported(address token) external view returns (bool supported) {
        TokenInfo storage info = tokens[token];
        return info.pool != address(0) && info.enabled;
    }

    /**
     * @notice Get pool for a token
     * @param token Token address
     * @return pool Pool address
     */
    function getPool(address token) external view returns (address pool) {
        return tokens[token].pool;
    }

    /**
     * @notice Get token info
     * @param token Token address
     * @return info Token information
     */
    function getTokenInfo(address token) external view returns (TokenInfo memory info) {
        return tokens[token];
    }

    /**
     * @notice Get all supported tokens
     * @return tokenList Array of token addresses
     */
    function getAllTokens() external view returns (address[] memory tokenList) {
        return allTokens;
    }

    /**
     * @notice Get count of supported tokens
     * @return count Number of tokens
     */
    function getTokenCount() external view returns (uint256 count) {
        return allTokens.length;
    }

    /**
     * @notice Get all enabled stablecoins
     * @return stablecoins Array of stablecoin addresses
     */
    function getStablecoins() external view returns (address[] memory stablecoins) {
        uint256 count = 0;

        // Count stablecoins
        for (uint256 i = 0; i < allTokens.length; i++) {
            if (tokens[allTokens[i]].isStablecoin && tokens[allTokens[i]].enabled) {
                count++;
            }
        }

        // Build array
        stablecoins = new address[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < allTokens.length; i++) {
            if (tokens[allTokens[i]].isStablecoin && tokens[allTokens[i]].enabled) {
                stablecoins[idx++] = allTokens[i];
            }
        }
    }

    /**
     * @notice Validate bet amount for a token
     * @param token Token address
     * @param amount Bet amount
     * @return valid Whether amount is valid
     */
    function validateBetAmount(
        address token,
        uint256 amount
    ) external view returns (bool valid) {
        TokenInfo storage info = tokens[token];
        if (!info.enabled) return false;
        return amount >= info.minBet && amount <= info.maxBet;
    }
}

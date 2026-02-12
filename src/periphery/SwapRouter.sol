// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title SwapRouter
 * @notice Handles swapping of supported tokens (USDC, USDT, ETH) to LBT
 * @dev Integrates with Uniswap V2-style DEX for token swaps
 */
contract SwapRouter is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice LBT token address
    address public immutable lbt;

    /// @notice WETH token address
    address public immutable weth;

    /// @notice Uniswap V2 Router address
    address public uniswapRouter;

    /// @notice Mapping of supported input tokens
    mapping(address => bool) public supportedTokens;

    /// @notice Maximum slippage allowed (basis points, e.g., 100 = 1%)
    uint256 public maxSlippage = 300; // 3% default

    event TokenSwapped(
        address indexed user,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 amountOut
    );
    event SupportedTokenAdded(address indexed token);
    event SupportedTokenRemoved(address indexed token);
    event MaxSlippageUpdated(uint256 newSlippage);
    event UniswapRouterUpdated(address newRouter);

    error UnsupportedToken();
    error InsufficientOutput();
    error SwapFailed();
    error InvalidSlippage();

    /**
     * @notice Constructor
     * @param _lbt LBT token address
     * @param _weth WETH token address
     * @param _uniswapRouter Uniswap V2 Router address
     */
    constructor(
        address _lbt,
        address _weth,
        address _uniswapRouter
    ) Ownable(msg.sender) {
        require(_lbt != address(0), "Invalid LBT");
        require(_weth != address(0), "Invalid WETH");
        require(_uniswapRouter != address(0), "Invalid router");

        lbt = _lbt;
        weth = _weth;
        uniswapRouter = _uniswapRouter;
    }

    /**
     * @notice Swap exact amount of input token for LBT
     * @param tokenIn Input token address (use address(0) for ETH)
     * @param amountIn Amount of input token
     * @param minAmountOut Minimum amount of LBT to receive
     * @return amountOut Amount of LBT received
     */
    function swapToLBT(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) external payable nonReentrant returns (uint256 amountOut) {
        // Handle ETH input
        if (tokenIn == address(0)) {
            require(msg.value == amountIn, "Invalid ETH amount");
            tokenIn = weth;
            // Wrap ETH to WETH
            _wrapETH(amountIn);
        } else {
            require(msg.value == 0, "ETH not expected");
            require(supportedTokens[tokenIn], "Token not supported");

            // Transfer input token from user
            IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        }

        // If tokenIn is already LBT, just transfer it
        if (tokenIn == lbt) {
            amountOut = amountIn;
            IERC20(lbt).safeTransfer(msg.sender, amountOut);
        } else {
            // Approve router to spend tokenIn
            IERC20(tokenIn).forceApprove(uniswapRouter, amountIn);

            // Build swap path
            address[] memory path = new address[](2);
            path[0] = tokenIn;
            path[1] = lbt;

            // Execute swap
            uint256[] memory amounts = IUniswapV2Router(uniswapRouter).swapExactTokensForTokens(
                amountIn,
                minAmountOut,
                path,
                msg.sender,
                block.timestamp
            );

            amountOut = amounts[1];
        }

        require(amountOut >= minAmountOut, "Insufficient output");

        emit TokenSwapped(msg.sender, tokenIn, amountIn, amountOut);
    }

    /**
     * @notice Get expected LBT output for input token amount
     * @param tokenIn Input token address (use address(0) for ETH)
     * @param amountIn Amount of input token
     * @return amountOut Expected amount of LBT
     */
    function getAmountOut(
        address tokenIn,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        if (tokenIn == address(0)) {
            tokenIn = weth;
        }

        if (tokenIn == lbt) {
            return amountIn;
        }

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = lbt;

        uint256[] memory amounts = IUniswapV2Router(uniswapRouter).getAmountsOut(
            amountIn,
            path
        );

        amountOut = amounts[1];
    }

    /**
     * @notice Calculate minimum output with slippage protection
     * @param tokenIn Input token address
     * @param amountIn Amount of input token
     * @return minAmountOut Minimum amount with slippage applied
     */
    function getMinAmountOut(
        address tokenIn,
        uint256 amountIn
    ) external view returns (uint256 minAmountOut) {
        uint256 expectedOut = this.getAmountOut(tokenIn, amountIn);
        minAmountOut = (expectedOut * (10000 - maxSlippage)) / 10000;
    }

    /**
     * @notice Wrap ETH to WETH
     * @param amount Amount to wrap
     */
    function _wrapETH(uint256 amount) internal {
        IWETH(weth).deposit{value: amount}();
    }

    /**
     * @notice Add supported input token
     * @param token Token address
     */
    function addSupportedToken(address token) external onlyOwner {
        require(token != address(0), "Invalid token");
        supportedTokens[token] = true;
        emit SupportedTokenAdded(token);
    }

    /**
     * @notice Remove supported input token
     * @param token Token address
     */
    function removeSupportedToken(address token) external onlyOwner {
        supportedTokens[token] = false;
        emit SupportedTokenRemoved(token);
    }

    /**
     * @notice Update maximum slippage
     * @param _maxSlippage New max slippage in basis points
     */
    function setMaxSlippage(uint256 _maxSlippage) external onlyOwner {
        require(_maxSlippage <= 1000, "Slippage too high"); // Max 10%
        maxSlippage = _maxSlippage;
        emit MaxSlippageUpdated(_maxSlippage);
    }

    /**
     * @notice Update Uniswap router address
     * @param _router New router address
     */
    function setUniswapRouter(address _router) external onlyOwner {
        require(_router != address(0), "Invalid router");
        uniswapRouter = _router;
        emit UniswapRouterUpdated(_router);
    }

    /**
     * @notice Emergency token withdrawal
     * @param token Token address
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            payable(owner()).transfer(amount);
        } else {
            IERC20(token).safeTransfer(owner(), amount);
        }
    }

    receive() external payable {}
}

/**
 * @notice Minimal Uniswap V2 Router interface
 */
interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);
}

/**
 * @notice Minimal WETH interface
 */
interface IWETH {
    function deposit() external payable;
    function withdraw(uint) external;
}

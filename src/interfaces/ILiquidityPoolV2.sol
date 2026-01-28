// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ILiquidityPoolV2
 * @notice Interface for the unified LP pool
 */
interface ILiquidityPoolV2 {
    // ============ LP Functions ============

    function addLiquidity(uint256 amount) external returns (uint256 shares);
    function removeLiquidity(uint256 shares) external returns (uint256 amount);

    // ============ Betting Pool Functions ============

    function collectLosingBet(uint256 amount) external;
    function payWinner(address winner, uint256 amount) external;
    function fundSeeding(uint256 roundId, uint256 amount) external returns (bool);
    function returnSeedFunds(uint256 amount) external;
    function lockLiquidity(uint256 amount) external;
    function unlockLiquidity(uint256 amount) external;
    function setRoundActive(bool active) external;

    // ============ View Functions ============

    function totalLiquidity() external view returns (uint256);
    function lockedLiquidity() external view returns (uint256);
    function roundActive() external view returns (bool);
    function getLPValue(address lp) external view returns (uint256 shareAmount, uint256 sharePercentage);
    function getAvailableLiquidity() external view returns (uint256);
    function canCoverPayout(uint256 amount) external view returns (bool);
    function previewDeposit(uint256 amount) external view returns (uint256 shares);
    function previewWithdrawal(uint256 shares) external view returns (uint256 amount);
}

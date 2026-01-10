// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILiquidityPool {
    function getAvailableLiquidity() external view returns (uint256);
    function getTotalLiquidity() external view returns (uint256);
    function getUtilization() external view returns (uint256);
    function canLockLiquidity(uint256 amount) external view returns (bool);
    function lockLiquidity(uint256 amount) external;
    function unlockLiquidity(uint256 amount) external;
    function unlockAndPay(address winner, uint256 amount) external;
    function addLiquidity(uint256 amount) external;
    function getPoolMultiplier() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IStrategy {
    function deposit(uint256 amount) external;
    
    function withdraw(uint256 amount) external returns (uint256);
    
    function totalAssets() external view returns (uint256);

    function harvest() external returns (uint256 yield);
    
    function emergencyWithdraw() external;
}
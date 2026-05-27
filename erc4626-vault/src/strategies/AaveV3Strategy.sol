// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";

interface IPool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

interface IAToken is IERC20 {}


contract AaveV3Strategy is IStrategy {
    using SafeERC20 for IERC20;

    address public immutable vault;
    IERC20 public immutable asset;
    IPool public immutable aavePool;
    IAToken public immutable aToken;

    error OnlyVault();

    modifier onlyVault() {
        if (msg.sender != vault) revert OnlyVault();
        _;
    }

    constructor(
        address _vault,
        address _asset,
        address _aavePool,
        address _aToken
    ) {
        vault = _vault;
        asset = IERC20(_asset);
        aavePool = IPool(_aavePool);
        aToken = IAToken(_aToken);

        asset.forceApprove(_aavePool, type(uint256).max);
    }

    function deposit(uint256 amount) external onlyVault {
        asset.safeTransferFrom(vault, address(this), amount);
        
        aavePool.supply(address(asset), amount, address(this), 0);
    }

    function withdraw(uint256 amount) external onlyVault returns (uint256) {
        return aavePool.withdraw(address(asset), amount, vault);
    }

    function totalAssets() external view returns (uint256) {
        return aToken.balanceOf(address(this));
    }

    function harvest() external view onlyVault returns (uint256 yield) {
        return 0;
    }

    function emergencyWithdraw() external onlyVault {
        uint256 balance = aToken.balanceOf(address(this));
        if (balance > 0) {
            aavePool.withdraw(address(asset), type(uint256).max, vault);
        }
    }
}
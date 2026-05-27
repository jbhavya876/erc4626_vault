// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {YieldVault} from "../../src/core/YieldVault.sol";
import {AaveV3Strategy} from "../../src/strategies/AaveV3Strategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VaultWithStrategyTest is Test {
    YieldVault public vault;
    AaveV3Strategy public strategy;

    // Ethereum Mainnet Constants
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant AAVE_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address constant AUSDC = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;

    address public alice = makeAddr("alice");
    address public feeRecipient = makeAddr("feeRecipient");
    address public owner = makeAddr("owner");

    function setUp() public {
        // Create mainnet fork
        string memory rpc = vm.envString("ETH_RPC_URL");
        vm.createSelectFork(rpc);

        // Deploy architecture (2. Add owner to constructor)
        vault = new YieldVault(IERC20(USDC), "Yield USDC", "yUSDC", feeRecipient, owner);
        strategy = new AaveV3Strategy(address(vault), USDC, AAVE_POOL, AUSDC);

        // Link strategy (3. Prank as owner to bypass AccessControl)
        vm.prank(owner);
        vault.setStrategy(address(strategy));

        // Fund Alice via Foundry's `deal` cheatcode
        deal(USDC, alice, 10_000e6);
        
        vm.prank(alice);
        IERC20(USDC).approve(address(vault), type(uint256).max);
    }

    function test_Integration_DepositRoutesToAave() public {
        uint256 depositAmount = 1000e6;

        vm.prank(alice);
        vault.deposit(depositAmount, alice);

        // Verify the 90/10 split execution
        uint256 strategyBalance = strategy.totalAssets();
        uint256 vaultIdleBalance = IERC20(USDC).balanceOf(address(vault));

        // Use assertApproxEqAbs to tolerate 2 wei of precision loss
        assertApproxEqAbs(strategyBalance, 900e6, 2); 
        assertEq(vaultIdleBalance, 100e6); // Idle balance does not suffer precision loss
        
        // Vault accounting must also tolerate the 1 wei strategy drop
        assertApproxEqAbs(vault.totalAssets(), depositAmount, 2); 
    }

    function test_Integration_WithdrawPullsFromAave() public {
        // 1. Initial Deposit
        vm.prank(alice);
        uint256 shares = vault.deposit(1000e6, alice);

        // 2. Fast forward 30 days to accrue realistic interest in Aave
        vm.warp(block.timestamp + 30 days);

        // 3. Alice withdraws everything
        vm.prank(alice);
        uint256 assetsReceived = vault.redeem(shares, alice, alice);

        // 4. Verification
        // Due to standard Aave interest, she should receive slightly more than 1000 USDC
        assertGe(assetsReceived, 1000e6);
        
        // Strategy should be empty, buffer might hold dust
        assertApproxEqAbs(strategy.totalAssets(), 0, 10); 
    }
}
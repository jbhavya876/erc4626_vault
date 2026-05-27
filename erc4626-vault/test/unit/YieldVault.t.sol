// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {YieldVault} from "../../src/core/YieldVault.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Lightweight ERC20 Mock matching USDC decimals (6)
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}
    function decimals() public pure override returns (uint8) { return 6; }
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

contract YieldVaultTest is Test {
    YieldVault public vault;
    MockUSDC public usdc;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public feeRecipient = makeAddr("feeRecipient");
    address public owner = makeAddr("owner");

    function setUp() public {
        usdc = new MockUSDC();
        // 2. Add owner to constructor
        vault = new YieldVault(usdc, "Yield USDC", "yUSDC", feeRecipient, owner); 

        // Fund test accounts
        usdc.mint(alice, 10_000e6);
        usdc.mint(bob, 10_000e6);
        
        // Infinite approve for test fluidity
        vm.prank(alice);
        usdc.approve(address(vault), type(uint256).max);
        
        vm.prank(bob);
        usdc.approve(address(vault), type(uint256).max);
    }

    function test_DeploymentState() public view {
        assertEq(vault.name(), "Yield USDC");
        assertEq(vault.symbol(), "yUSDC");
        assertEq(vault.totalSupply(), 0); 
    }

    function test_FirstDeposit() public {
        uint256 depositAmount = 1000e6; // 1,000 USDC
        
        vm.prank(alice);
        uint256 shares = vault.deposit(depositAmount, alice);
        
        // Alice receives 1:1 ratio minus the initial dead shares scaling
        assertEq(vault.balanceOf(alice), shares);
        assertEq(vault.totalAssets(), depositAmount);
    }

    function test_ShareAppreciation_WithYield() public {
        // 1. Alice deposits 1,000 USDC
        vm.prank(alice);
        uint256 aliceShares = vault.deposit(1000e6, alice);

        // 2. Simulate Yield: 100 USDC directly sent to vault (10% APY)
        usdc.mint(address(vault), 100e6);

        // 3. Bob deposits 1,000 USDC
        vm.prank(bob);
        uint256 bobShares = vault.deposit(1000e6, bob);

        // 4. Verification: Bob should receive fewer shares than Alice due to appreciation
        assertLt(bobShares, aliceShares);
        
        // 1100 total assets / 1000 total shares (approx) = 1.1 exchange rate
        // Bob deposits 1000 / 1.1 = ~909 shares
        assertApproxEqRel(bobShares, 909e6, 0.01e18); 
    }

    function test_Withdrawal_CollectsFees() public {
        // 1. Deposit
        vm.prank(alice);
        uint256 shares = vault.deposit(1000e6, alice);

        // 2. Fast forward time by 365 days to accrue 2% fee
        vm.warp(block.timestamp + 365 days);

        // 3. Alice redeems half her shares
        vm.prank(alice);
        vault.redeem(shares / 2, alice, alice);

        // 4. Verification: Fee recipient should now have shares
        uint256 feeShares = vault.balanceOf(feeRecipient);
        assertGt(feeShares, 0);
    }
}
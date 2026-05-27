// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {YieldVault} from "../../src/core/YieldVault.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}
    function decimals() public pure override returns (uint8) { return 6; }
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

contract AccessControlTest is Test {
    YieldVault public vault;
    MockUSDC public usdc;

    address public owner = makeAddr("owner");
    address public keeper = makeAddr("keeper");
    address public emergencyAdmin = makeAddr("emergencyAdmin");
    address public alice = makeAddr("alice");
    address public attacker = makeAddr("attacker");
    address public feeRecipient = makeAddr("feeRecipient");

    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    function setUp() public {
        usdc = new MockUSDC();
        vault = new YieldVault(usdc, "Yield USDC", "yUSDC", feeRecipient, owner);

        vm.startPrank(owner);
        vault.grantRole(KEEPER_ROLE, keeper);
        vault.grantRole(EMERGENCY_ROLE, emergencyAdmin);
        vm.stopPrank();

        usdc.mint(alice, 10_000e6);
    }

    function test_OnlyOwnerCanSetStrategy() public {
        address mockStrategy = makeAddr("strategy");
        
        vm.prank(owner);
        vault.setStrategy(mockStrategy);
        assertEq(address(vault.strategy()), mockStrategy);

        vm.prank(attacker);
        vm.expectRevert();
        vault.setStrategy(makeAddr("malicious"));
    }

    function test_OnlyKeeperCanHarvest() public {
        vm.prank(keeper);
        vault.harvest();

        vm.prank(alice);
        vm.expectRevert();
        vault.harvest();
    }

    function test_EmergencyPauseMechanics() public {
        vm.prank(emergencyAdmin);
        vault.pause();
        assertTrue(vault.paused());

        vm.startPrank(alice);
        usdc.approve(address(vault), 1000e6);
        vm.expectRevert(YieldVault.Paused.selector);
        vault.deposit(1000e6, alice);
        vm.stopPrank();

        vm.prank(attacker);
        vm.expectRevert();
        vault.unpause();

        vm.prank(owner);
        vault.unpause();
        assertFalse(vault.paused());
    }

    function test_EmergencyWithdrawRequiresPause() public {
        vm.prank(emergencyAdmin);
        vm.expectRevert(YieldVault.NotPaused.selector);
        vault.emergencyWithdrawFromStrategy();

        vm.prank(emergencyAdmin);
        vault.pause();

        vm.prank(emergencyAdmin);
        vault.emergencyWithdrawFromStrategy();
    }
}
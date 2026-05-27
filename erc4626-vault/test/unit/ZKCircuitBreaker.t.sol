// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {YieldVault} from "../../src/core/YieldVault.sol";
import {ProofOfReserves} from "../../src/zk/ProofOfReserves.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mocking the auto-generated SnarkJS verifier signature exactly
contract MockGroth16Verifier {
    bool public isValid = true;

    function setValid(bool _valid) external {
        isValid = _valid;
    }

    function verifyProof(
        uint256[2] calldata,
        uint256[2][2] calldata,
        uint256[2] calldata,
        uint256[3] calldata // Aligned to 3 public inputs
    ) external view returns (bool) {
        return isValid;
    }
}

contract ZKCircuitBreakerTest is Test {
    YieldVault public vault;
    ProofOfReserves public oracle;
    MockUSDC public usdc;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice"); // Whale (>10% pool)
    address public bob = makeAddr("bob"); // Retail (<10% pool)
    address public feeRecipient = makeAddr("fee");

    function setUp() public {
        usdc = new MockUSDC();
        vault = new YieldVault(
            usdc,
            "Yield USDC",
            "yUSDC",
            feeRecipient,
            owner
        );

        // 1. Deploy the Mock Verifier
        MockGroth16Verifier verifier = new MockGroth16Verifier();

        // 2. Deploy the PoR Oracle
        oracle = new ProofOfReserves(address(verifier), address(vault));

        // 3. Link the Oracle to the Vault as the Admin
        vm.prank(owner);
        vault.setReserveOracle(address(oracle));

        // 4. Fund users
        usdc.mint(alice, 100_000e6);
        usdc.mint(bob, 5_000e6);

        vm.prank(alice);
        usdc.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(vault), type(uint256).max);

        // 5. Establish initial pool assets (105,000 USDC total)
        vm.prank(alice);
        vault.deposit(100_000e6, alice);
        vm.prank(bob);
        vault.deposit(5_000e6, bob);
    }

    function test_ZK_SmallWithdrawal_BypassesBreaker() public {
        // Bob withdraws 5k (<10% of total pool). Bypasses stale proof check.
        vm.prank(bob);
        vault.withdraw(5_000e6, bob, bob);
        assertEq(usdc.balanceOf(bob), 5_000e6);
    }

    function test_ZK_LargeWithdrawal_EnforcesBreaker() public {
        // Alice tries to extract 50k (>10%). Reverts because no proof is active.
        vm.prank(alice);

        // VULNERABILITY PATCH: Match the actual YieldVault revert string
        vm.expectRevert("YieldVault: ZK Proof Stale");

        vault.withdraw(50_000e6, alice, alice);
    }
}

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

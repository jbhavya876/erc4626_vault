// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {YieldVault} from "../src/core/YieldVault.sol";
import {AaveV3Strategy} from "../src/strategies/AaveV3Strategy.sol";
import {ProofOfReserves} from "../src/zk/ProofOfReserves.sol";
import {Groth16Verifier} from "../src/zk/Groth16Verifier.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeploySepolia is Script {
    // Sepolia Aave V3 Addresses
    address constant USDC = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8; 
    address constant AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
    address constant AUSDC = 0x16dA4541aD1807f4443d92D26044C1147406EB80;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        console2.log("Deploying from:", deployer);

        vm.startBroadcast(deployerKey);

        // 1. Deploy Vault
        YieldVault vault = new YieldVault(
            IERC20(USDC),
            "Yield USDC Vault",
            "yUSDC",
            deployer, // Fee recipient
            deployer  // Owner
        );

        // 2. Deploy Strategy
        AaveV3Strategy strategy = new AaveV3Strategy(
            address(vault),
            USDC,
            AAVE_POOL,
            AUSDC
        );

        // 3. Deploy ZK Infrastructure
        Groth16Verifier verifier = new Groth16Verifier();
        ProofOfReserves oracle = new ProofOfReserves(address(verifier), address(vault));

        // 4. Wire the Architecture
        vault.setStrategy(address(strategy));
        vault.setReserveOracle(address(oracle));
        
        // Grant Keeper Role to deployer so you can manually trigger harvests
        vault.grantRole(vault.KEEPER_ROLE(), deployer);

        vm.stopBroadcast();

        console2.log("=== SEPOLIA DEPLOYMENT SUCCESS ===");
        console2.log("USDC:    ", USDC);
        console2.log("Vault:   ", address(vault));
        console2.log("Strategy:", address(strategy));
        console2.log("Oracle:  ", address(oracle));
    }
}
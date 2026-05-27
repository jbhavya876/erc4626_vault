# ZK-Enabled ERC4626 Yield Vault

A decentralized, zero-knowledge verifiable yield aggregator built on the ERC4626 standard. This protocol accepts USDC deposits, generates yield via the Aave V3 protocol, and utilizes zk-SNARKs (Groth16) to provide cryptographically secure, off-chain proofs of reserves.

## Architecture 

The protocol is divided into four core smart contracts to ensure separation of concerns and upgradability:

1. **YieldVault (ERC4626):** The core user-facing contract managing USDC deposits, share minting, and withdrawal accounting.
2. **AaveV3Strategy:** The yield-generating module that interfaces directly with Aave V3 lending pools to deploy idle vault capital.
3. **ProofOfReserves (Oracle):** An oracle contract that accepts and stores the verified solvency state of the vault.
4. **Groth16Verifier:** An on-chain ZK-SNARK verifier that mathematically guarantees off-chain reserve calculations without exposing sensitive operational data.

### System Flow
* **Deposit:** User deposits USDC into `YieldVault` → Receives vault shares representing fractional ownership.
* **Deploy:** Vault allocates capital to `AaveV3Strategy` → Earns dynamic APY.
* **Verify:** Off-chain keeper generates a ZK proof of total assets → Submits to `ProofOfReserves` → `Groth16Verifier` validates proof → Vault dashboard reflects `VERIFIED` state.

## Live Deployments (Sepolia Testnet)

All contracts are fully verified on Sepolia Etherscan.

* **USDC (Testnet):** `0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8`
* **YieldVault:** `0x265B2E9CA36715E31e1e012A4B076f8f1c3a9D7e`
* **AaveV3Strategy:** `0xa689d363054FF410aD92EeDcAFaB7D743Ad72653`
* **ProofOfReserves:** `0x2560E7C7d787afB262fD81A495a25F4BA3Ea4aDC`
* **Groth16Verifier:** `0xB7011e1362b2B6b13F61E647077A4A61f7D1368C`

## Tech Stack
* **Smart Contracts:** Solidity, Foundry (Forge/Cast)
* **Frontend:** Next.js (React), Tailwind CSS
* **Web3 Integration:** Wagmi, RainbowKit, Viem
* **Zero-Knowledge:** Circom, SnarkJS (Groth16)

---

## Local Environment Setup

### Prerequisites
* [Foundry](https://getfoundry.sh/) (Forge, Cast, Anvil)
* [Node.js](https://nodejs.org/) & [pnpm](https://pnpm.io/)

### 1. Smart Contracts (`erc4626-vault`)
```bash
# Clone the repository
git clone [https://github.com/jbhavya876/erc4626_vault.git](https://github.com/jbhavya876/erc4626_vault.git)
cd erc4626_vault/erc4626-vault

# Install submodules and dependencies
forge install

# Compile contracts
forge build

# Run unit tests
forge test -vvv
```

### 2. Frontend Application (vault-frontend)
```bash
cd ../vault-frontend

# Install dependencies
pnpm install

# Start development server
pnpm run dev
```

### 3. Environment Variables
```bash
Create a .env file in both directories based on the .env.example templates.

Vault .env:

Code snippet
SEPOLIA_RPC_URL="your_alchemy_or_infura_rpc"
PRIVATE_KEY="your_wallet_private_key"
ETHERSCAN_API_KEY="your_etherscan_key"
Frontend .env.local:

Code snippet
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID="your_walletconnect_project_id"
```
---

## Security & Disclaimer
This protocol is deployed on a test network for educational and demonstration purposes. It has not undergone formal security auditing. Do not deploy or use this code with real funds on Mainnet.

Author
Bhavya Jain

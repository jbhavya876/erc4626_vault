# ZK-Enabled ERC4626 Yield Vault

A full-stack, zero-knowledge verifiable yield aggregator. This protocol accepts USDC deposits, generates dynamic yield via the Aave V3 protocol, and utilises zk-SNARKs (Groth16) to provide cryptographically secure, off-chain proofs of reserves directly to the frontend dashboard.

## 🏗️ Repository Structure

This is a monorepo containing both the smart contract protocol and the decentralised frontend application.

* **/erc4626-vault**: Foundry-based smart contract environment. Contains the core ERC4626 vault, Aave strategy, and on-chain ZK verifiers.
* **/vault-frontend**: Next.js (React) application providing the user interface for deposits, withdrawals, and real-time ZK proof verification.

## ⚙️ Core Architecture

The backend protocol is modularised to separate core accounting from yield generation and reserve verification:

1. **YieldVault (ERC4626):** The core user-facing contract managing USDC deposits, fractional share (vUSDC) minting, and withdrawal accounting.
2. **AaveV3Strategy:** The yield-generating module that interfaces directly with Aave V3 lending pools to deploy idle vault capital.
3. **ProofOfReserves (Oracle):** An oracle contract that accepts and stores the verified solvency state of the vault.
4. **Groth16Verifier:** An on-chain ZK-SNARK verifier that mathematically guarantees off-chain reserve calculations without exposing sensitive operational data.

### System Flow
1. **Capital Deployment:** Users deposit USDC → Vault mints vUSDC shares → Vault routes capital to the Aave V3 Strategy.
2. **Zero-Knowledge Verification:** Off-chain system calculates total protocol reserves → Generates a Groth16 zk-SNARK proof → Submits to `ProofOfReserves` oracle.
3. **On-Chain Validation:** The oracle queries `Groth16Verifier`. If the math holds, the state updates.
4. **UI Reflection:** The frontend queries the blockchain. Upon successful verification, the dashboard updates to a `VERIFIED ✓` state.

## 🌐 Live Deployments (Sepolia Testnet)

All contracts are fully verified on the Ethereum Sepolia testnet.

* **USDC (Testnet):** `0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8`
* **YieldVault:** `0x265B2E9CA36715E31e1e012A4B076f8f1c3a9D7e`
* **AaveV3Strategy:** `0xa689d363054FF410aD92EeDcAFaB7D743Ad72653`
* **ProofOfReserves:** `0x2560E7C7d787afB262fD81A495a25F4BA3Ea4aDC`
* **Groth16Verifier:** `0xB7011e1362b2B6b13F61E647077A4A61f7D1368C`

## 💻 Tech Stack

* **Smart Contracts:** Solidity, Foundry (Forge/Cast)
* **Zero-Knowledge:** Circom, SnarkJS (Groth16)
* **Frontend:** Next.js, React, Tailwind CSS
* **Web3 Integration:** Wagmi, RainbowKit, Viem

---

## 🚀 Local Development Setup

### Prerequisites
* [Foundry](https://getfoundry.sh/) (Forge, Cast, Anvil)
* [Node.js](https://nodejs.org/) & [pnpm](https://pnpm.io/)
* A WalletConnect Project ID (from [cloud.walletconnect.com](https://cloud.walletconnect.com/))

### 1. Smart Contracts
Navigate to the vault directory and install dependencies:

```bash
cd erc4626-vault
forge install
forge build
forge test -vvv
```

Create a .env file in erc4626-vault/:

```bash
SEPOLIA_RPC_URL="your_rpc_url"
PRIVATE_KEY="your_private_key"
ETHERSCAN_API_KEY="your_etherscan_key"
```

### 2. Frontend Application
Open a new terminal, navigate to the frontend directory, and start the development server:

```bash
cd vault-frontend
pnpm install
pnpm run dev
```
Create a .env.local file in vault-frontend/:
```bash
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID="your_walletconnect_project_id"
Access the dashboard at http://localhost:3000.
```

## 🔒 Security Disclaimer
This protocol is deployed on a test network for educational and demonstration purposes. It has not undergone formal security auditing. Do not deploy or use this code with real funds on Mainnet.

### Author
Bhavya Jain 

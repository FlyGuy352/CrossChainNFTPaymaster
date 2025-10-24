# 👷 Hardhat Backend for Cross-Chain NFT Paymaster

This repository contains all smart contracts and Hardhat scripts used to power the **Cross-Chain NFT Paymaster** project. It includes the full suite of contracts, deployment configurations, and automation scripts required to compile, test, deploy and manage the system across **Hedera Testnet** and **Ethereum Sepolia**.
<br><br>

## Project Setup

This project uses the **default Hardhat 3 framework**, so all standard Hardhat commands and workflows apply. The main thing to take note of is how the environment and keystore variables are configured.

### 1️⃣ Keystore Configuration

These values are referenced in `hardhat.config.ts` and must be set in the production keystore using:

```bash
npx hardhat keystore set <VARIABLE_NAME>
```

| Variable Name | Description |
|-------------------------------------|-----------------------------------------|
| `HEDERA_RPC_URL` | RPC endpoint for Hedera Testnet |
| `HEDERA_PRIVATE_KEY` | Private key of the Hedera Testnet admin |
| `SEPOLIA_RPC_URL` | RPC endpoint for Ethereum Sepolia |
| `SEPOLIA_PRIVATE_KEY` | Private key of the Ethereum Sepolia admin |

### 2️⃣ Deployment Script Configuration

These values are referenced in the deployment scripts and must be defined in a `.env` file:

| Variable Name | Description |
|-------------------------------------|-----------------------------------------|
| `HEDERA_TESTNET_PUBLIC_KEY_ADMIN` | Public key of the Hedera Testnet admin |
| `ETHEREUM_SEPOLIA_PUBLIC_KEY_ADMIN` | Public key of the Ethereum Sepolia admin |
| `PUBLIC_KEY_USER` | Public key of a demo user; same on both Hedera Testnet and Ethereum Sepolia |

For simplicity, the same account is currently used to deploy the Hedera NFT contract and serve as the admin for signing NFT minting. While these roles can be separated, doing so will involve at a minimum minor refactoring of the deployment scripts.
<br><br>

## Commands Overview

Below are the main scripts and tasks used to deploy, verify, test, and interact with the contracts.

### 🚀 Deployment Instructions

#### 1. Deploy NFT Contract to Hedera Testnet

```bash
npx hardhat run scripts/deployHedera.ts
```

#### 2. Deploy Paymaster, Wallet Factory, and Counter Contracts to Ethereum Sepolia

```bash
npx hardhat ignition deploy ignition/modules/EthereumContracts.ts --network sepolia
```

### 🔍 Contract Verification

#### 3. Verify NFT Contract on Hedera Testnet

```bash
npx hardhat verifyHedera <contractAddress> contracts/HederaHybridNFT_flat.sol HederaHybridNFT_flat.json
```

#### 4. Verify Ethereum Sepolia Contracts

```bash
npx hardhat verify --network sepolia <counterAddress>
npx hardhat verify --network sepolia <paymasterAddress> <deployerAddress> <hederaAdminAddress> 0x0000000000000000000000000000000000000000
npx hardhat verify --network sepolia <walletFactoryAddress> 0x4337084d9e255ff0702461cf8895ce9e3b5ff108
```

### 💸 Contract Interaction

#### 5. Execute Paymaster Deposit to Entrypoint

> The initial Paymaster deployment script also deposits some Ether into the Entrypoint contract. The next script can be run after the Paymaster has sponsored a few transactions and the deposit runs low.

```bash
npx hardhat run scripts/paymasterDeposit.ts
```

#### 6. Send USDC to Smart Contract Wallet

> The smart contract wallet must hold a USDC balance because, on the frontend, swapping USDC to WETH entails withdrawing the USDC amount from it (and not from the user's EOA).

```bash
npx hardhat run scripts/sendUSDCToWallet.ts
```

#### 7. Set Up Demo User

> This script will perform the necessary actions to set up a user's EOA to be used across Hedera Testnet and Ethereum Sepolia.

```bash
npx hardhat run scripts/setupDemoUser.ts
```

### 🧪 Running Tests

#### 8. Run Tests on Hardhat Network

> **Note:** Use the production build profile for optimizer, otherwise you may encounter  
> `Error: Transaction reverted: trying to deploy a contract whose code is too large.`

```bash
npx hardhat test --build-profile production
```
<br>

## ⚙️ Important Notes

- `HederaHybridNFT.sol` tracks the source code for the NFT contract for ease of development and debugging. However, it was flattened into `HederaHybridNFT_flat.sol`, and that version was deployed to the Hedera Testnet because the contract verification service failed to resolve OpenZeppelin imports.

- If the Paymaster contract address changes, `paymasterDeposit.ts` should be updated to reflect the latest address for contract interaction.

- If the Wallet Factory contract address changes, `setupDemoUser.ts` should be updated to reflect the latest address for contract interaction.

- A **custom `verifyHedera.ts` Hardhat task** was implemented since the native `hardhat verify` command does **not** support Hedera Testnet.

- The deployment scripts do **not** deploy `Entrypoint_flat.sol` to any real network. It is included only for local end-to-end testing within the test suite. On Ethereum Sepolia, both the Paymaster and wallet factory reference the **canonical Entrypoint contract address**.

- The deployment scripts do **not** deploy `SmartContractWallet.sol`. Smart contract wallets are instead deployed **on-demand** by the wallet factory contract on the frontend when a user submits their first transaction and no wallet exists for them yet.
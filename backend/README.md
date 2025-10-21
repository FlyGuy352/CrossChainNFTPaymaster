# 👷 Hardhat Backend for Cross-Chain NFT Paymaster

This repository contains all smart contracts and Hardhat scripts used to power the **Cross-Chain NFT Paymaster project**.

## Commands

## 🚀 Deployment Instructions

### 1. Deploy NFT Contract to Hedera Testnet

```bash
npx hardhat run scripts/deployHedera.ts
```

### 2. Deploy Paymaster, Smart Contract Wallet, and Counter Contracts to Ethereum Sepolia

```bash
npx hardhat ignition deploy ignition/modules/EthereumContracts.ts --network sepolia
```

## 🔍 Contract Verification

### 3. Verify NFT Contract on Hedera Testnet

```bash
npx hardhat verifyHedera <contractAddress> contracts/HederaHybridNFT_flat.sol HederaHybridNFT_flat.json
```

### 4. Verify Ethereum Sepolia Contracts

```bash
npx hardhat verify --network sepolia <counterAddress>
npx hardhat verify --network sepolia <paymasterAddress> <deployerAddress> <hederaAdminAddress> 0x0000000000000000000000000000000000000000
npx hardhat verify --network sepolia <smartContractWalletAddress> <userAddress> 0x0000000000000000000000000000000000000000
```

## 💰 Function Calls

### 5. Execute Paymaster Deposit to Entrypoint

> The initial Paymaster deployment script also deposits some Ether into the Entrypoint contract. The next script can be run after the Paymaster has sponsored a few transactions and the deposit runs low.

```bash
npx hardhat run scripts/paymasterDeposit.ts
```

### 6. Run tests

> **Note:** Use the production build profile for optimizer, otherwise you may encounter  
> `Error: Transaction reverted: trying to deploy a contract whose code is too large.`

```bash
npx hardhat test --build-profile production
```

## ⚙️ Important Notes

- **HederaHybridNFT.sol** tracks the source code for the NFT contract for ease of development and debugging. However, it was flattened into **HederaHybridNFT_flat.sol**, and that version was deployed to the Hedera Testnet because the contract verification service failed to resolve OpenZeppelin imports.

- A **custom `verifyHedera.ts` Hardhat task** was implemented since the native `hardhat verify` command does **not** support Hedera Testnet.
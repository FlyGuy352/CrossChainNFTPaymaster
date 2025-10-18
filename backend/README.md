## Deploy NFT Contract to Hedera Testnet

npx hardhat run scripts/deployHedera.ts

## Deploy Paymaster, Smart Contract Wallet, and Counter Contracts to Ethereum Sepolia

npx hardhat ignition deploy ignition/modules/EthereumContracts.ts --network sepolia

### Verify NFT Contract on Hedera Testnet

npx hardhat run scripts/verifyHedera.ts 0x22C159580D114BCfe3DebaD7A0635FF91472A30B contracts/HederaHybridNFT.sol artifacts/contracts/HederaHybridNFT.sol/HederaHybridNFT.json

## Verify Ethereum Sepolia Contracts
npx hardhat verify --network sepolia <counterAddress>
npx hardhat verify --network sepolia <paymasterAddress> <deployerAddress> <hederaAdminAddress>
npx hardhat verify --network sepolia <smartContractWalletAddress> <userAddress>

### Deposit to Paymaster

npx hardhat run scripts/paymasterDeposit.ts
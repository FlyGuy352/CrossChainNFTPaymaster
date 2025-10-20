## Deploy NFT Contract to Hedera Testnet

npx hardhat run scripts/deployHedera.ts

## Deploy Paymaster, Smart Contract Wallet, and Counter Contracts to Ethereum Sepolia

npx hardhat ignition deploy ignition/modules/EthereumContracts.ts --network sepolia

### Verify NFT Contract on Hedera Testnet

npx hardhat verifyHedera <contractAddress> contracts/HederaHybridNFT_flat.sol HederaHybridNFT_flat.json

## Verify Ethereum Sepolia Contracts
npx hardhat verify --network sepolia <counterAddress>
npx hardhat verify --network sepolia <paymasterAddress> <deployerAddress> <hederaAdminAddress>
npx hardhat verify --network sepolia <smartContractWalletAddress> <userAddress>

### Deposit to Paymaster

npx hardhat run scripts/paymasterDeposit.ts

### Run tests (use production profile for optimizer else "Error: Transaction reverted: trying to deploy a contract whose code is too large")

npx hardhat test --build-profile production
## Deploy NFT Contract to Hedera Testnet

forge script script/DeployHedera.sol --rpc-url https://testnet.hashio.io/api --broadcast --skip-simulation

## Deploy and Verify Paymaster, Smart Contract Wallet, and Counter Contracts to Ethereum Sepolia

forge script script/DeployEthereum.sol --rpc-url https://ethereum-sepolia-rpc.publicnode.com --broadcast --verify

### Verify NFT Contract on Hedera Testnet

node verifyHedera.js <address> src/DummyNFT.sol out/DummyNFT.sol/DummyNFT.json
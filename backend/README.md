## Deploy NFT Contract to Hedera Testnet

forge script script/DeployHedera.sol --rpc-url https://testnet.hashio.io/api --broadcast

## Deploy Paymaster, Smart Contract Wallet, and Counter Contracts to Ethereum Sepolia

forge script script/DeployEthereum.sol --rpc-url https://ethereum-sepolia-rpc.publicnode.com --broadcast

### Verify NFT Contract on Hedera Testnet

node verifyHedera.js 0x343C7ea74CBA8943D79a9705E7e6af45FBf39d19 src/DummyNFT.sol out/DummyNFT.sol/DummyNFT.json
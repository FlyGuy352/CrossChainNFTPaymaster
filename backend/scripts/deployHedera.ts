import { network } from "hardhat";
import dotenv from "dotenv";

dotenv.config();

const { ethers } = await network.connect({ network: "hederaTestnet" });
const [deployer] = await ethers.getSigners();

const hederaHybridNft = await ethers.getContractFactory("HederaHybridNFT_flat", deployer);
const contract = await hederaHybridNft.deploy(process.env.HEDERA_TESTNET_PUBLIC_KEY_ADMIN!);
await contract.waitForDeployment();

console.log('Calling createNFTCollection() to create the HTS collection...');
const tx = await contract.createNFTCollection("MyHederaNFT", "HNFT", {
    gasLimit: 250_000,
    value: ethers.parseEther("15")
});
await tx.wait();
console.log(`createNFTCollection() Tx Hash: ${tx.hash}`);

const contractAddress = await contract.getAddress();
console.log(`HederaHybridNFT address: ${contractAddress}`);
const tokenAddress = await contract.tokenAddress();
console.log(`Underlying HTS NFT Collection (ERC721 facade) deployed at: ${tokenAddress}`);
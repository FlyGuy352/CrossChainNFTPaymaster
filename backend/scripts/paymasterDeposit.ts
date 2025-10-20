import { network } from "hardhat";
import metadata from "../artifacts/contracts/CrossChainNFTPaymaster.sol/CrossChainNFTPaymaster.json";

const { ethers } = await network.connect({ network: "sepolia" });

const [deployer] = await ethers.getSigners();
console.log(`Using account: ${deployer.address}`);

// Verify that this is the latest paymaster address
const paymaster = new ethers.Contract("0x14eAAfF87532206fBE056c3Bbc082659d19ea17A", metadata.abi, deployer);

const tx = await paymaster.deposit({ value: ethers.parseEther("0.05") });
console.log(`Depositing 0.05 ETH... tx hash: ${tx.hash}`);
const receipt = await tx.wait();
console.log(`Deposit confirmed in block ${receipt.blockNumber}`);
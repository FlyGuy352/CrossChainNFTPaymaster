import { network } from "hardhat";
import metadata from "../artifacts/contracts/CrossChainNFTPaymaster.sol/CrossChainNFTPaymaster.json";

const { ethers } = await network.connect({ network: "sepolia" });

const [deployer] = await ethers.getSigners();
console.log(`Using account: ${deployer.address}`);

const paymaster = new ethers.Contract("0x50Cd8822CF7c53db4072993Eb4b72366Be7cceBE", metadata.abi, deployer);

const tx = await paymaster.deposit({ value: ethers.parseEther("0.05") });
console.log(`Depositing 0.05 ETH... tx hash: ${tx.hash}`);
const receipt = await tx.wait();
console.log(`Deposit confirmed in block ${receipt.blockNumber}`);
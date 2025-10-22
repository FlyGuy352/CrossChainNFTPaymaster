import { network } from "hardhat";

const { ethers } = await network.connect({ network: "sepolia" });

const [deployer] = await ethers.getSigners();
console.log(`Using account: ${deployer.address}`);

const usdc = new ethers.Contract("0x1c7d4b196cb0c7b01d743fbc6116a902379c7238", [{
    name: "transfer", type: "function", stateMutability: "nonpayable", inputs: [
        { name: "to", type: "address" }, { name: "amount", type: "uint256" }
    ],
    outputs: [ { name: "", type: "bool" } ]
}], deployer);

// Verify that this is the latest smart contract wallet address
const smartContractWalletAddress = "0x54dCE0a0195b923d7F73fC24AD73697b4b281403";

const tx = await usdc.transfer(smartContractWalletAddress, ethers.parseUnits("3", 6));
console.log(`Transferring 3 USDC... tx hash: ${tx.hash}`);
const receipt = await tx.wait();
console.log(`Transfer confirmed in block ${receipt.blockNumber}`);
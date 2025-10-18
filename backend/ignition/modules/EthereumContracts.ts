import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { ethers } from "ethers";
import dotenv from "dotenv";

dotenv.config();

export default buildModule("EthereumContracts", (m) => {
  const deployerAddress = process.env.ETHEREUM_SEPOLIA_PUBLIC_KEY_ADMIN!;
  const hederaAdmin = process.env.HEDERA_TESTNET_PUBLIC_KEY_ADMIN!;
  const userAddress = process.env.PUBLIC_KEY_USER!;

  const counter = m.contract("SimpleCounter");

  const paymaster = m.contract("CrossChainNFTPaymaster", [
    deployerAddress,
    hederaAdmin,
  ]);

  const account = m.contract("SmartContractWallet", [userAddress]);

  m.call(paymaster, "deposit", [], {
    value: ethers.parseEther("0.01"),
  });

  return { counter, paymaster, account };
});

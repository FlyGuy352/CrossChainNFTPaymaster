import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseEther } from "viem";
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
    value: parseEther("0.001"),
  });

  return { counter, paymaster, account };
});

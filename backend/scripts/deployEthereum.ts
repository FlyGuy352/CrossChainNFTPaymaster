/*import hre from "hardhat";
import EthereumContracts from "../ignition/modules/EthereumContracts.js";

async function main() {
    const connection = await hre.network.connect();
    const { counter, paymaster, account } = await connection.ignition.deploy(EthereumContracts);

    console.log(`Counter address: ${counter}`);
    console.log(`Paymaster address: ${paymaster}`);
    console.log(`SmartContractWallet address: ${account}`);
}

main().catch(console.error);*/
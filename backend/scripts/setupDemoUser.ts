import { network } from "hardhat";
import { AccountId, PrivateKey, Client, AccountCreateTransaction, Hbar } from "@hashgraph/sdk"; 
import metadata from "../artifacts/contracts/SmartContractWalletFactory.sol/SmartContractWalletFactory.json";
import dotenv from "dotenv";

dotenv.config();

const accountId = AccountId.fromString(process.env.HEDERA_TESTNET_ACCOUNT_ID_ADMIN!);
const privateKey = PrivateKey.fromStringECDSA(process.env.HEDERA_TESTNET_PRIVATE_KEY_ADMIN!);

const hederaClient = Client.forTestnet();
hederaClient.setOperator(accountId, privateKey);

const userAccountPrivateKey = PrivateKey.generateECDSA();
console.log(`User Private Key: 0x${userAccountPrivateKey.toStringRaw()}`);
const createAccountTx = new AccountCreateTransaction()
    .setECDSAKeyWithAlias(userAccountPrivateKey)
    .setInitialBalance(new Hbar(5));
const createAccountTxResponse = await createAccountTx.execute(hederaClient);
const createAccountTxReceipt = await createAccountTxResponse.getReceipt(hederaClient);
const createAccountTxReceiptStatus = createAccountTxReceipt.status.toString();
if (createAccountTxReceiptStatus !== "SUCCESS") {
    throw new Error(`Hedera AccountCreateTransaction failed with status: ${createAccountTxReceiptStatus}`);
}

const accountCreatedTxId = createAccountTxResponse.transactionId.toString();
console.log(`Hedera AccountCreateTransaction ID: ${accountCreatedTxId}`);
const userAccountId = createAccountTxReceipt.accountId;
console.log(`Hedera User Account ID: ${userAccountId}`);
const userEvmAddress = `0x${userAccountPrivateKey.publicKey.toEvmAddress()}`
console.log(`User EVM Address: ${userEvmAddress}`);

const { ethers } = await network.connect({ network: "sepolia" });
const [deployer] = await ethers.getSigners();
const salt = ethers.keccak256(ethers.getBytes(userEvmAddress));

const factoryAddress = "0x9eE3BCf1Cf484Ee406efE4f84b86B50AA9A5eD27"; // Verify latest contract address
const walletFactory = new ethers.Contract(factoryAddress, metadata.abi, deployer);
const createWalletTx = await walletFactory.createWallet(userEvmAddress, salt);
console.log(`Creating User Wallet On Ethereum... Tx Hash: ${createWalletTx.hash}`);
const userWalletAddress = await walletFactory.getWalletAddress(userEvmAddress, salt);
console.log(`Ethereum User Wallet Address: ${userWalletAddress}`);
const createWalletTxReceipt = await createWalletTx.wait();
console.log(`Transaction confirmed in block ${createWalletTxReceipt.blockNumber}`);

const usdcAddress = "0x1c7d4b196cb0c7b01d743fbc6116a902379c7238";
const usdc = new ethers.Contract(usdcAddress, [{
    name: "transfer", type: "function", stateMutability: "nonpayable", inputs: [
        { name: "to", type: "address" }, { name: "amount", type: "uint256" }
    ],
    outputs: [ { name: "", type: "bool" } ]
}], deployer);
const transferTx = await usdc.transfer(userWalletAddress, ethers.parseUnits("1", 6));
console.log(`Transferring 1 USDC to User Wallet On Ethereum... Tx Hash: ${transferTx.hash}`);
const transferTxReceipt = await transferTx.wait();
console.log(`Transfer confirmed in block ${transferTxReceipt.blockNumber}`);
import { expect } from "chai";
import { network } from "hardhat";
import { type Signer, type BaseWallet, type Contract } from "ethers";

const { ethers } = await network.connect();

describe("UserOperation", function() {
  
  let deployer: Signer, userWallet: BaseWallet, hederaAdmin: BaseWallet;
  let counter: Contract, paymaster: Contract, account: Contract, entrypoint: Contract;

  beforeEach(async function() {
    [deployer] = await ethers.getSigners();
    userWallet = ethers.Wallet.createRandom();
    hederaAdmin = ethers.Wallet.createRandom();

    entrypoint = await ethers.deployContract("EntryPoint_flat");
    const entrypointAddress = await entrypoint.getAddress();
    counter = await ethers.deployContract("SimpleCounter");
    paymaster = await ethers.deployContract("CrossChainNFTPaymaster", [await deployer.getAddress(), hederaAdmin.address, entrypointAddress]);
    account = await ethers.deployContract("SmartContractWallet", [userWallet.address, entrypointAddress]);

    await entrypoint.depositTo(await paymaster.getAddress(), { value: ethers.parseEther("100") });
  });

  async function constructUserOp(
    targetContract: Contract, functionName: string, functionArgs: any[]
  ) {
    const verificationGasLimit = 200000;
    const callGasLimit = 200000;
    const verificationGasLimitBytes = ethers.zeroPadValue(ethers.hexlify(ethers.toBeArray(verificationGasLimit)), 16);
    const callGasLimitLimitBytes = ethers.zeroPadValue(ethers.hexlify(ethers.toBeArray(callGasLimit)), 16);
    const accountGasLimits = ethers.concat([verificationGasLimitBytes, callGasLimitLimitBytes]);

    const maxPriorityFeePerGas = ethers.parseUnits("5", "gwei");
    const maxFeePerGas = ethers.parseUnits("10", "gwei");
    const maxPriorityFeePerGasBytes = ethers.zeroPadValue(ethers.hexlify(ethers.toBeArray(maxPriorityFeePerGas)), 16);
    const maxFeePerGasBytes = ethers.zeroPadValue(ethers.hexlify(ethers.toBeArray(maxFeePerGas)), 16);
    const gasFees = ethers.concat([maxPriorityFeePerGasBytes, maxFeePerGasBytes]);

    const sender = await account.getAddress();
    const callData = account.interface.encodeFunctionData(
        "execute", [await targetContract.getAddress(), 0, targetContract.interface.encodeFunctionData(functionName, functionArgs)]
    );

    const tokenId = 1;
    const adminMessageHash = ethers.solidityPackedKeccak256(["uint256", "address"], [tokenId, userWallet.address]);
    const adminSignature = await hederaAdmin.signMessage(ethers.toBeArray(adminMessageHash));

    const paymasterAddress = await paymaster.getAddress();
    const nonce = 0;
    const userMessageHash = ethers.solidityPackedKeccak256(["address", "uint256"], [paymasterAddress, nonce]);
    const userSignature = await userWallet.signMessage(ethers.getBytes(userMessageHash));

    const paymasterAndData = ethers.solidityPacked(
        ["address", "uint128", "uint128", "bytes", "uint256", "address", "bytes"],
        [paymasterAddress, 200000, 200000, adminSignature, tokenId, userWallet.address, userSignature]
    );

    const userOp = {
      sender,
      nonce: 0,
      initCode: "0x",
      callData,
      accountGasLimits,
      preVerificationGas: 50000,
      gasFees,
      paymasterAndData,
      signature: "0x"
    };
    const userOpHash = await entrypoint.getUserOpHash(userOp);
    userOp.signature = await userWallet.signMessage(ethers.getBytes(userOpHash));

    return userOp;
  };

  it("Should decrease paymaster deposit", async function() {
    const paymasterAddress = await paymaster.getAddress();
    const balance = await entrypoint.balanceOf(paymasterAddress);

    const userOp = await constructUserOp(counter, "increment", []);
    await entrypoint.handleOps([userOp], await deployer.getAddress());

    const newBalance = await entrypoint.balanceOf(paymasterAddress);
    expect(newBalance).to.be.lt(balance);
  });
});

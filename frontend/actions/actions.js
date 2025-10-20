'use server';

import { ethers } from 'ethers';
import contractAddresses from '@/constants/contractAddresses.json';
import networks from '@/constants/networks.json';
import nftAbi from '@/constants/HederaHybridNFT.json';
import entryPointAbi from '@/constants/EntryPoint.json';
import walletAbi from '@/constants/SmartContractWallet.json';

export const signMint = async owner => {
    const provider = new ethers.JsonRpcProvider(networks.NFTChain.rpcUrl, networks.NFTChain.id);
    const nftContract = new ethers.Contract(contractAddresses.HederaHybridNFT, nftAbi, provider);
    const tokenId = await nftContract.latestTokenId();

    const hash = ethers.solidityPackedKeccak256(['uint256', 'address'], [tokenId + BigInt(1), owner]);
    const signature = await new ethers.Wallet(process.env.HEDERA_TESTNET_PRIVATE_KEY_ADMIN).signMessage(ethers.toBeArray(hash));

    return signature;
};

export const constructUserOp = async (
    contractAddress, contractAbi, functionName, functionArgs, tokenId, userAddress, userSignature
) => {
    const transactionChainProvider = new ethers.JsonRpcProvider(
        networks.TransactionChain.rpcUrl, networks.TransactionChain.id
    );

    const entryPoint = new ethers.Contract(contractAddresses.EntryPoint, entryPointAbi, transactionChainProvider);
    const sender = contractAddresses.SmartContractWallet;
    const targetContract = new ethers.Contract(contractAddress, contractAbi);
    const smartContractWallet = new ethers.Contract(sender, walletAbi);
    const callData = smartContractWallet.interface.encodeFunctionData(
        'execute', [contractAddress, 0, targetContract.interface.encodeFunctionData(functionName, functionArgs)]
    );

    const verificationGasLimit = 200000;
    const callGasLimit = 200000;
    const verificationGasLimitBytes = ethers.zeroPadValue(ethers.hexlify(ethers.toBeArray(verificationGasLimit)), 16);
    const callGasLimitLimitBytes = ethers.zeroPadValue(ethers.hexlify(ethers.toBeArray(callGasLimit)), 16);
    const accountGasLimits = ethers.concat([verificationGasLimitBytes, callGasLimitLimitBytes]);

    const maxPriorityFeePerGas = ethers.parseUnits('5', 'gwei');
    const maxFeePerGas = ethers.parseUnits('10', 'gwei');
    const maxPriorityFeePerGasBytes = ethers.zeroPadValue(ethers.hexlify(ethers.toBeArray(maxPriorityFeePerGas)), 16);
    const maxFeePerGasBytes = ethers.zeroPadValue(ethers.hexlify(ethers.toBeArray(maxFeePerGas)), 16);
    const gasFees = ethers.concat([maxPriorityFeePerGasBytes, maxFeePerGasBytes]);

    const nftChainProvider = new ethers.JsonRpcProvider(networks.NFTChain.rpcUrl, Number(networks.NFTChain.id));
    const nftContract = new ethers.Contract(contractAddresses.HederaHybridNFT, nftAbi, nftChainProvider);
    const adminSignature = await nftContract.signatures(tokenId);
    const paymasterAndData = ethers.solidityPacked(
        ['address', 'uint128', 'uint128', 'bytes', 'uint256', 'address', 'bytes'],
        [contractAddresses.PayMaster, 200000, 200000, adminSignature, tokenId, userAddress, userSignature]
    );
    const userOp = {
        sender,
        nonce: (await entryPoint.getNonce(sender, 0)).toString(),
        initCode: '0x',
        callData,
        accountGasLimits,
        preVerificationGas: 50000,
        gasFees,
        paymasterAndData,
        signature: '0x'
    };
    const userOpHash = await entryPoint.getUserOpHash(userOp);

    return { userOp, userOpHash };
};

export const transmitUserOp = async userOp => {
    const provider = new ethers.JsonRpcProvider(networks.TransactionChain.rpcUrl, networks.TransactionChain.id);
    const wallet = new ethers.Wallet(process.env.ETHEREUM_SEPOLIA_PRIVATE_KEY_ADMIN, provider);
    const entryPoint = new ethers.Contract(contractAddresses.EntryPoint, entryPointAbi, wallet);
    try {
        const tx = await entryPoint.handleOps([userOp], process.env.ETHEREUM_SEPOLIA_PUBLIC_KEY_ADMIN);
        await tx.wait();
        return { txHash: tx.hash };
    } catch (error) {
        console.error(`Error transmitting UserOp: ${error}`);
        return { error };
    }
};
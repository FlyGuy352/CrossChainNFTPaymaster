'use server';

import { ethers } from 'ethers';
import contractAddresses from '@/constants/contractAddresses.json';
import networks from '@/constants/networks.json';
import nftAbi from '@/constants/DummyNFT.json';

export const signMint = async owner => {
    const provider = new ethers.JsonRpcProvider(networks.NFTChain.rpcUrl, networks.NFTChain.id);
    const nftContract = new ethers.Contract(contractAddresses.DummyNFT, nftAbi, provider);
    const tokenId = await nftContract.latestTokenId();

    const hash = ethers.solidityPackedKeccak256(['uint256', 'address'], [tokenId + BigInt(1), owner]);
    const signature = await new ethers.Wallet(process.env.HEDERA_TESTNET_PRIVATE_KEY_ADMIN).signMessage(ethers.toBeArray(hash));
    
    return signature;
};

export const hashUserOp = async () => {

};

export const transmitUserOp = async () => {

};
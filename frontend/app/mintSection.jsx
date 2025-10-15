'use client';

import { useEffect, useTransition } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { switchChain } from '@wagmi/core';
import contractAddresses from '@/constants/contractAddresses.json';
import networks from '@/constants/networks.json';
import nftAbi from '@/constants/DummyNFT.json';
import { randomIntFromInterval } from '@/utils/math';
import { wagmiConfig } from './wagmiConfig';
import useIsMounted from '@/hooks/useIsMounted'; 
import useNFTs from '@/hooks/useNFTs'; 
import Image from 'next/image';
import Spinner from './spinner';
import { toast } from 'sonner';
import { signMint } from '@/actions/actions';

export default function MintSection() {

    const { address, isConnected } = useAccount();
    const { data: hash, writeContract } = useWriteContract();
    const [ startTransition] = useTransition();

    const mint = () => {
        if (!isConnected) {
            return toast.error('Please connect your wallet');
        }
        startTransition(async () => {
            let signature;
            try {
                await switchChain(wagmiConfig, { chainId: networks.NFTChain.id });
                signature = await signMint(address);
            } catch (error) {
                return toast.error(error.message);
            }

            const tokenURI = `/assets/images/Dragon_${randomIntFromInterval(1, 4)}.jpg`;
            writeContract({
                address: contractAddresses.DummyNFT,
                abi: nftAbi,
                functionName: 'mint',
                args: [address, tokenURI, signature],
                gas: 1000000
            });
        });
    };

    return (
        <button>
            Mint
        </button>
    );
}
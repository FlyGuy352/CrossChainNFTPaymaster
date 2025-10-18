'use client';

import { useEffect, useTransition } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { switchChain } from '@wagmi/core';
import contractAddresses from '@/constants/contractAddresses.json';
import networks from '@/constants/networks.json';
import nftAbi from '@/constants/HederaHybridNFT.json';
import { randomIntFromInterval } from '@/utils/math';
import { wagmiConfig } from './wagmiConfig';
import useIsMounted from '@/hooks/useIsMounted'; 
import useHederaNFTs from '@/hooks/useHederaNFTs'; 
import Image from 'next/image';
import Spinner from './spinner';
import { toast } from 'sonner';
import { signMint } from '@/actions/actions';

export default function MintSection() {

    const { address, isConnected } = useAccount();
    const isMounted = useIsMounted();
    const { data: nfts, error: loadNFTsError, isFetching, refetch } = useHederaNFTs(address);
    const { data: hash, error: writeError, isPending, writeContract } = useWriteContract();
    const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({ hash });
    const [isPendingTransition, startTransition] = useTransition();
    useEffect(() => {
        if (isConfirmed) {
            const refetchNFTs = async () => {
                await refetch();
            }
    
            refetchNFTs().catch(console.error);
        }
    }, [isConfirmed]);

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
                address: contractAddresses.HederaHybridNFT,
                abi: nftAbi,
                functionName: 'mint',
                args: [address, tokenURI, signature],
                gas: 1000000
            });
        });
    };

    return (
        <div className='h-160 bg-[#4DD2FF]'>
            <div className='h-136 flex justify-center items-center'>
                {
                    (isMounted() && (isFetching || isConfirming)) ? <Spinner/> : (!!nfts?.length && <Image src={nfts[0].uri} width={375} height={375} alt='NFT'/>)
                }
            </div>
            <div className='flex justify-center'>
                {
                    !!nfts?.length ? 
                        <span className='text-2xl font-DynaPuff p-3 tracking-wide'>You have NFT Token ID {nfts[0].id.toString()} on Hedera</span> :                 
                        <button 
                            className='border border-black rounded-3xl bg-white text-xl font-semibold w-96 p-3 tracking-wide disabled:bg-slate-300 disabled:border-slate-600 disabled:text-slate-700 disabled:cursor-not-allowed enabled:hover:scale-[1.025] transition' 
                            onClick={mint}
                            disabled={!isMounted() || isPendingTransition || isPending || isFetching || isConfirming}
                            suppressHydrationWarning
                        >
                            Mint NFT on Hedera
                        </button>
                }
            </div>
        </div>
    );
}
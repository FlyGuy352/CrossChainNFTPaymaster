'use client';

import { useState, useEffect } from 'react';
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
import Button from '@/components/Button';
import Spinner from '@/components/Spinner';
import { toast } from 'sonner';
import { signMint } from '@/actions/actions';

export default function MintSection() {

    const { address, isConnected } = useAccount();
    const isMounted = useIsMounted();
    const { data: nfts, isFetching, refetch } = useHederaNFTs(address);

    const [isSigning, setIsSigning] = useState(false);
    const getButtonText = () => {
        if (isPending || isConfirming) {
            return 'Minting Your NFT...';
        } else if (isSigning) {
            return 'Requesting Admin Signature…';
        } else {
            return 'Mint NFT on Hedera';
        }
    };
    const { data: hash, isPending, writeContract } = useWriteContract();
    const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({ hash });

    useEffect(() => {
        if (isConfirmed) {
            const refetchNFTs = async () => {
                await refetch();
            }
    
            refetchNFTs().then(() => toast.success('NFT Minted!')).catch(console.error);
        }
    }, [isConfirmed]);

    const mint = async () => {
        if (!isConnected) {
            return toast.error('Please connect your wallet');
        }
        let signature;
        try {
            await switchChain(wagmiConfig, { chainId: networks.NFTChain.id });
            setIsSigning(true);
            signature = await signMint(address);
        } catch (error) {
            return toast.error(error.message);
        } finally {
            setIsSigning(false);
        }

        const tokenURI = `/assets/images/Dragon_${randomIntFromInterval(1, 4)}.jpg`;
        writeContract({
            address: contractAddresses.HederaHybridNFT,
            abi: nftAbi,
            functionName: 'mint',
            args: [address, tokenURI, signature],
            gas: 1000000
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
                <div className='flex justify-center px-8'>
                    {
                        !!nfts?.length ? 
                            <span className='text-2xl font-DynaPuff p-3 tracking-wide'>You have NFT Token ID {nfts[0].id.toString()} on Hedera</span> :                 
                        <Button 
                            onClick={mint} getButtonText={getButtonText} 
                            isDisabled={!isMounted() || isSigning || isPending || isFetching || isConfirming} 
                            isLoading={isSigning || isPending || isConfirming} spinnerColor='green-700'
                        >
                        </Button>
                    }
                </div>
            </div>
        </div>
    );
}
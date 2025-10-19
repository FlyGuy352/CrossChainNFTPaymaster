'use client';

import { useTransition } from 'react';
import { useAccount, useReadContract } from 'wagmi';
import networks from '@/constants/networks.json';
import contractAddresses from '@/constants/contractAddresses.json';
import paymasterAbi from '@/constants/CrossChainNFTPaymaster.json';
import useHederaNFTs from '@/hooks/useHederaNFTs';
import Counter from './transactionSection/counter';

export default function CounterSection() {

    const { address } = useAccount();
    const { data: nfts } = useHederaNFTs(address);

    const { data: nonce } = useReadContract({
        abi: paymasterAbi,
        address: contractAddresses.PayMaster,
        functionName: 'nonces',
        args: [address, nfts?.[0]?.id],
        chainId: networks.TransactionChain.id,
        query: {
            enabled: nfts?.length
        }
    });

    const [isPending, startTransition] = useTransition();

    return (
        <div className='h-160 bg-[#C0FF02]'>
            <Counter address={address} nfts={nfts} nonce={nonce} startTransition={startTransition} isPending={isPending} />
        </div>
    );
}
'use client';

import { useReducer } from 'react';
import { useAccount, useReadContract } from 'wagmi';
import networks from '@/constants/networks.json';
import contractAddresses from '@/constants/contractAddresses.json';
import paymasterAbi from '@/constants/CrossChainNFTPaymaster.json';
import useHederaNFTs from '@/hooks/useHederaNFTs';
import Counter from './transactionSection/counter';
import Swap from './transactionSection/swap';

export default function TransactionSection() {

    const [state, dispatch] = useReducer((state, action) => {
        switch (action.type) {
            case 'VIEW_COUNTER':
                return { showCounter: true, showSwap: false };
            case 'VIEW_SWAP':
                return { showCounter: false, showSwap: true };
        }
    }, { showCounter: true, showSwap: false });

    const { address } = useAccount();
    const { data: nfts } = useHederaNFTs(address);

    const { data: nonce, refetch } = useReadContract({
        abi: paymasterAbi,
        address: contractAddresses.PayMaster,
        functionName: 'nonces',
        args: [address, nfts?.[0]?.id],
        chainId: networks.TransactionChain.id,
        enabled: nfts?.length
    });

    return (
        <>
            <div className='h-160 bg-[#E6FFC0] lg:relative lg:overflow-hidden'>
                <div 
                    className={`
                        h-full flex justify-center lg:w-[200%] lg:transition-transform lg:duration-400 lg:ease-in-out
                        ${state.showCounter ? 'lg:translate-x-[0%]' : 'lg:translate-x-[-50%]'}
                    `}
                >
                    <div className='lg:w-1/2 lg:flex-shrink-0 flex flex-col justify-center'>
                        {
                            state.showCounter && <Counter address={address} nfts={nfts} nonce={nonce} dispatch={dispatch} refetchNonce={refetch}/>
                        }
                    </div>
                    <div className='lg:w-1/2 lg:flex-shrink-0'>
                        {
                            state.showSwap && <Swap address={address} nfts={nfts} nonce={nonce} dispatch={dispatch} refetchNonce={refetch}/>
                        }
                    </div>
                </div>
            </div>
        </>
    );
}
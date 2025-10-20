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
            <div className='h-160 bg-[#E6FFC0] lg:hidden'>
                {
                    state.showCounter && <Counter address={address} nfts={nfts} nonce={nonce} dispatch={dispatch} refetchNonce={refetch}/>
                }
                {
                    state.showSwap && <Swap address={address} nfts={nfts} nonce={nonce} dispatch={dispatch} refetchNonce={refetch}/>
                }
            </div>
            <div className='relative overflow-hidden h-160 bg-[#E6FFC0] hidden lg:block'>
                <div
                    className='h-full flex w-[200%] transition-transform duration-400 ease-in-out'
                    style={{
                        transform: state.showCounter
                            ? 'translateX(0%)'
                            : 'translateX(-50%)'
                    }}
                >
                    <div className='w-1/2 flex-shrink-0'>
                        {
                            state.showCounter && <Counter address={address} nfts={nfts} nonce={nonce} dispatch={dispatch} refetchNonce={refetch}/>
                        }
                    </div>
                    <div className='w-1/2 flex-shrink-0'>
                        {
                            state.showSwap && <Swap address={address} nfts={nfts} nonce={nonce} dispatch={dispatch} refetchNonce={refetch}/>
                        }
                    </div>
                </div>
            </div>
        </>
    );
}
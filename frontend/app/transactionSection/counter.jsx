'use client';

import { useState } from 'react';
import { useReadContract, useWatchContractEvent } from 'wagmi';
import { signMessage } from '@wagmi/core';
import { wagmiConfig } from '@/app/wagmiConfig';
import { encodePacked, keccak256 } from 'viem';
import { toast } from 'sonner';
import networks from '@/constants/networks.json';
import contractAddresses from '@/constants/contractAddresses.json';
import counterAbi from '@/constants/SimpleCounter.json';
import { constructUserOp, transmitUserOp } from '@/actions/actions';
import { useNotification, useTransactionPopup } from '@blockscout/app-sdk';

export default function Counter({ address, nfts, nonce, startTransition, isPending }) {

    const { data: count } = useReadContract({
        abi: counterAbi,
        address: contractAddresses.SimpleCounter,
        functionName: 'count',
        chainId: networks.TransactionChain.id
    });
    const [newCount, setNewCount] = useState(null);

    useWatchContractEvent({
        address: contractAddresses.SimpleCounter,
        abi: counterAbi,
        eventName: 'Incremented',
        onLogs(logs) {
            console.log(`Counter event logs received: ${JSON.stringify(logs)}`);
            setNewCount(logs[0].args.newCount);
        },
        chainId: networks.TransactionChain.id
    });

    const { openTxToast } = useNotification();
    const { openPopup } = useTransactionPopup();

    const increment = () => {
        startTransition(async () => {
            try {
                const nonceSignature = await signMessage(wagmiConfig, { message: { raw: keccak256(encodePacked(['address', 'uint256'], [contractAddresses.PayMaster, nonce])) } });
                const { userOp, userOpHash } = await constructUserOp(
                    contractAddresses.SimpleCounter, counterAbi, 'increment', null, nfts[0].id, address, nonceSignature
                );
                const userOpHashSignature = await signMessage(wagmiConfig, { message: { raw: userOpHash } });
                userOp.signature = userOpHashSignature;
                const { error, txHash } = await transmitUserOp(userOp);

                if (error) {
                    return toast.error(JSON.stringify(error));
                } else {
                    // This optimistic update is a workaround because useWatchContractEvent seems unreliable
                    setNewCount(prevCount => (prevCount ?? Number(count)) + 1);
                    openTxToast(networks.TransactionChain.id, txHash);
                }
            } catch(error) {
                toast.error(error.message);
            }
        });
    };

    const showTransactionPopup = () => {
        openPopup({
            chainId: networks.TransactionChain.id,
            address: contractAddresses.SimpleCounter
        });
    };

    return (
        <>
            <div className='h-136'>
                <div className='w-full h-full bg-[url("/assets/images/Smart_Contract.png")] bg-no-repeat bg-center flex justify-center items-center'>
                    <span className='text-9xl cursor-pointer' onClick={showTransactionPopup}>{newCount ?? count?.toString() ?? 0}</span>
                </div>
            </div>
            <div className='flex justify-center'>
                <button 
                    className='border border-black rounded-3xl bg-white text-xl font-semibold w-96 p-3 tracking-wide disabled:bg-slate-300 disabled:border-slate-600 disabled:text-slate-700 disabled:cursor-not-allowed enabled:hover:scale-[1.025] transition' 
                    onClick={increment}
                    disabled={isPending || nfts === undefined || nfts.length === 0}
                >
                    Increment Counter on Ethereum
                </button>
            </div>
        </>
    );
}
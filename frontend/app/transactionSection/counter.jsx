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

export default function Counter({ address, nfts, nonce, dispatch, refetchNonce }) {

    const { data: count } = useReadContract({
        abi: counterAbi,
        address: contractAddresses.SimpleCounter,
        functionName: 'count',
        chainId: networks.TransactionChain.id
    });
    const [newCount, setNewCount] = useState(null);
    const [status, setStatus] = useState('idle');

    const getButtonText = () => {
        switch (status) {
            case 'idle': return 'Increment Counter on Ethereum';
            case 'signingNonce': return 'Signing Paymaster Message...';
            case 'constructing': return 'Building User Operation...';
            case 'signingUserOp': return 'Signing User Operation...';
            case 'transmitting': return 'Submitting to Network...';
            default: return '...';
        }
    };

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

    const increment = async () => {
        try {
            console.log(`Signing nonce for increment: ${nonce}`);
            setStatus('signingNonce');
            const nonceSignature = await signMessage(wagmiConfig, { message: { raw: keccak256(encodePacked(['address', 'uint256'], [contractAddresses.PayMaster, nonce])) } });

            setStatus('constructing');
            const { userOp, userOpHash } = await constructUserOp(
                contractAddresses.SimpleCounter, counterAbi, 'increment', null, nfts[0].id, address, nonceSignature
            );

            setStatus('signingUserOp');
            const userOpHashSignature = await signMessage(wagmiConfig, { message: { raw: userOpHash } });
            userOp.signature = userOpHashSignature;

            setStatus('transmitting');
            const { error, txHash } = await transmitUserOp(userOp);

            if (error) {
                return toast.error(JSON.stringify(error));
            } else {
                await refetchNonce();
                // This optimistic update is a workaround because useWatchContractEvent seems unreliable
                setNewCount(prevCount => (prevCount ?? Number(count)) + 1);
                openTxToast(networks.TransactionChain.id, txHash);
            }
        } catch (error) {
            toast.error(error.message);
        } finally {
            setStatus('idle');
        }
    };

    const showTransactionPopup = () => openPopup({
        chainId: networks.TransactionChain.id,
        address: contractAddresses.SimpleCounter
    });

    const goToSwap = () => dispatch({ type: 'VIEW_SWAP' });

    return (
        <>
            <div className='h-136'>
                <div className='w-full h-full bg-[url("/assets/images/Smart_Contract.png")] bg-no-repeat bg-center flex justify-center items-center'>
                    <span className='text-9xl cursor-pointer' onClick={showTransactionPopup}>{newCount ?? count?.toString() ?? 0}</span>
                </div>
            </div>
            <div className='flex items-center justify-center gap-12'>
                <button className='w-0 h-0 border-t-12 border-b-12 border-r-20 border-t-transparent border-b-transparent border-r-green-700 hover:border-r-green-900 cursor-pointer transition-colors invisible'></button>
                <button className='
                    border border-black rounded-3xl bg-white text-xl font-semibold w-96 p-3 tracking-wide 
                    disabled:bg-slate-300 disabled:border-slate-600 disabled:text-slate-700 disabled:cursor-not-allowed 
                    enabled:hover:scale-[1.025] transition flex justify-center items-center gap-3
                '
                    onClick={increment}
                    disabled={status !== 'idle' || nfts === undefined || nfts.length === 0}
                >
                    {status !== 'idle' && (
                        <span className='animate-spin h-5 w-5 border-4 border-green-700 border-t-transparent rounded-full'></span>
                    )}
                    {getButtonText()}
                </button>
                <button className='w-0 h-0 border-t-12 border-b-12 border-l-20 border-t-transparent border-b-transparent border-l-green-700 hover:border-l-green-900 cursor-pointer transition-colors disabled:cursor-not-allowed' disabled={status !== 'idle'} onClick={goToSwap}></button>
            </div>
        </>
    );
}
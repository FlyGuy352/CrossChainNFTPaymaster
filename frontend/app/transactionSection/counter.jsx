'use client';

import { useState } from 'react';
import { useReadContract, useWatchContractEvent } from 'wagmi';
import { signMessageHash, signHashValue } from '@/utils/cryptography';
import { toast } from 'sonner';
import networks from '@/constants/networks.json';
import contractAddresses from '@/constants/contractAddresses.json';
import counterAbi from '@/constants/SimpleCounter.json';
import { constructUserOp, transmitUserOp } from '@/actions/actions';
import { useNotification, useTransactionPopup } from '@blockscout/app-sdk';
import Button from '@/components/Button';
import GreenArrow from '@/components/GreenArrow';

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
            const nonceSignature = await signMessageHash(['address', 'uint256'], [contractAddresses.PayMaster, nonce]);

            setStatus('constructing');
            const { userOp, userOpHash } = await constructUserOp(
                contractAddresses.SimpleCounter, counterAbi, 'increment', null, nfts[0].id, address, nonceSignature
            );

            setStatus('signingUserOp');
            const userOpHashSignature = await signHashValue(userOpHash);
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
            <div className='h-103 sm:h-126'>
                <div className='w-full h-full bg-[url("/assets/images/Smart_Contract.png")] bg-no-repeat bg-center flex justify-center items-center'>
                    <span className='text-9xl cursor-pointer' onClick={showTransactionPopup}>{newCount ?? count?.toString() ?? 0}</span>
                </div>
            </div>
            <div className='flex items-center justify-center gap-12'>
                <GreenArrow direction='left' elementType='button'></GreenArrow>
                <Button 
                    onClick={increment} getButtonText={getButtonText} 
                    isDisabled={status !== 'idle' || nfts === undefined || nfts.length === 0} 
                    isLoading={status !== 'idle'} spinnerColor='green-700'
                >
                </Button>
                <GreenArrow direction='right' elementType='button' isVisible onClick={goToSwap} disabled={status !== 'idle'}></GreenArrow>
            </div>
            <div className='sm:hidden mt-12'>
                <GreenArrow direction='right' elementType='div' isVisible onClick={goToSwap} disabled={status !== 'idle'}></GreenArrow>
            </div>
        </>
    );
}
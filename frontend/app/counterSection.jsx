'use client';

import { useState, useTransition } from 'react';
import { useAccount, useReadContract, useWatchContractEvent, useWalletClient } from 'wagmi';
import { signMessage } from '@wagmi/core';
import { wagmiConfig } from './wagmiConfig';
import { encodePacked, keccak256 } from 'viem';
import contractAddresses from '@/constants/contractAddresses.json';
import paymasterAbi from '@/constants/CrossChainNFTPaymaster.json';
import networks from '@/constants/networks.json';
import counterAbi from '@/constants/SimpleCounter.json';
import { toast } from 'sonner';
import { constructUserOp, transmitUserOp } from '@/actions/actions';
import useNFTs from '@/hooks/useNFTs';

export default function CounterSection() {

    const { address } = useAccount();
    const { data: nfts, error } = useNFTs(address);
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

    const [isPending, startTransition] = useTransition();

    const increment = () => {
        startTransition(async () => {
            try {
                const nonceSignature = await signMessage(wagmiConfig, { message: { raw: keccak256(encodePacked(['address', 'uint256'], [contractAddresses.PayMaster, nonce])) } });
                const { userOp, userOpHash } = await constructUserOp(nfts[0].id, address, nonceSignature);
                const userOpHashSignature = await signMessage(wagmiConfig, { message: { raw: userOpHash } });
                userOp.signature = userOpHashSignature;
                const error = await transmitUserOp(userOp);
                if (error) {
                    return toast.error(JSON.stringify(error));
                }
            } catch(error) {
                toast.error(error.message);
            }
        });
    };

    return (
        <div className='h-160 bg-[#C0FF02]'>
            <div className='h-136'>
                <div className='w-full h-full bg-[url("/assets/images/Smart_Contract.png")] bg-no-repeat bg-center flex justify-center items-center'>
                    <span className='text-9xl'>{newCount ?? count?.toString() ?? 0}</span>
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
        </div>
    );
}
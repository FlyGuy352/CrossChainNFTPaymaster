'use client';

import { useState, useTransition } from 'react';
import { useAccount, useReadContract, useWatchContractEvent } from 'wagmi';
import { signMessage } from '@wagmi/core';
import { wagmiConfig } from './wagmiConfig';
import { encodePacked, keccak256 } from 'viem';
import contractAddresses from '@/constants/contractAddresses.json';
import paymasterAbi from '@/constants/CrossChainNFTPaymaster.json';
import networks from '@/constants/networks.json';
import counterAbi from '@/constants/SimpleCounter.json';
import { toast } from 'sonner';
import { hashUserOp, transmitUserOp } from '@/actions/actions';
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
          setNewCount(logs[0].args.newCount);
        },
        chainId: networks.TransactionChain.id
    });

    const [startTransition] = useTransition();

    const increment = () => {
        startTransition(async () => {
            const nonceSignature = await signMessage(wagmiConfig, { message: { raw: keccak256(encodePacked(['address', 'uint256'], [contractAddresses.PayMaster, nonce])) } });
            const { userOp, userOpHash } = await hashUserOp(nfts[0].id, address, nonceSignature);
            const userOpHashSignature = await signMessage(wagmiConfig, { message: { raw: userOpHash } });
            userOp.signature = userOpHashSignature;
            const error = await transmitUserOp(userOp);
            if (error) {
                return toast.error(JSON.stringify(error));
            }
        });
    };

    return (
        <div>
            {newCount}
            <button onClick={increment}>
                Increment Counter on Chain B
            </button>
        </div>
    );
}
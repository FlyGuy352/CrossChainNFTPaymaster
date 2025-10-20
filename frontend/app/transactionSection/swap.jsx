'use client';

import { useState } from 'react';
import { useReadContract } from 'wagmi';
import { parseUnits, formatUnits } from 'viem';
import routerAbi from '@/constants/UniswapRouter.json';
import networks from '@/constants/networks.json';
import contractAddresses from '@/constants/contractAddresses.json';
import erc20Abi from '@/constants/ERC20.json';
import { signMessage } from '@wagmi/core';
import { wagmiConfig } from '@/app/wagmiConfig';
import { encodePacked, keccak256 } from 'viem';
import { toast } from 'sonner';
import { constructUserOp, transmitUserOp } from '@/actions/actions';
import { useNotification, useTransactionPopup } from '@blockscout/app-sdk';
import Button from '@/components/Button';

export default function Swap({ address, nfts, nonce, dispatch, refetchNonce }) {

    const [status, setStatus] = useState('idle');
    const getButtonText = () => {
        switch (status) {
            case 'idle': return 'Swap';
            case 'signingApproveNonce': return 'Signing Approval Nonce...';
            case 'constructingApprove': return 'Building Approval Operation...';
            case 'signingApproveUserOp': return 'Signing Approval Operation...';
            case 'transmittingApprove': return 'Submitting Approval Operation...';
            case 'signingSwapNonce': return 'Signing Swap Nonce...';
            case 'constructingSwap': return 'Building Swap Operation...';
            case 'signingSwapUserOp': return 'Signing Swap Operation...';
            case 'transmittingSwap': return 'Submitting Swap Operation...';
            default: return '...';
        }
    };
    const [amount, setAmount] = useState('');
    const [txHash, setTxHash] = useState('');

    const { data: usdcBalance } = useReadContract({
        address: contractAddresses.USDC,
        abi: erc20Abi,
        functionName: 'balanceOf',
        args: [address],
        chainId: networks.TransactionChain.id,
        enabled: address
    })

    const formattedBalance =
        usdcBalance !== undefined ? Number(formatUnits(usdcBalance, 6)).toFixed(2) : '0.00';

    const { openTxToast } = useNotification();
    const { openPopup } = useTransactionPopup();

    const swap = async () => {
        const parsedAmount = parseUnits(amount, 6); // USDC has 6 decimals

        try {
            const { error: approveError } = await approve(parsedAmount);
            if (approveError) {
                return toast.error(JSON.stringify(approveError));
            }
            const { error: swapError, txHash } = await routeSwap(parsedAmount);
            if (swapError) {
                return toast.error(JSON.stringify(swapError));
            }

            openTxToast(networks.TransactionChain.id, txHash);
            setTxHash(txHash);
        } catch (error) {
            toast.error(error.message);
        } finally {
            await refetchNonce(); // Always refetch in case approve succeeds but swap fails
            setStatus('idle');
        }
    };

    const approve = async parsedAmount => {
        console.log(`Signing nonce for approve: ${nonce}`);
        setStatus('signingApproveNonce');
        const nonceSignature = await signMessage(wagmiConfig, { message: { raw: keccak256(encodePacked(['address', 'uint256'], [contractAddresses.PayMaster, nonce])) } });

        setStatus('constructingApprove');
        const { userOp, userOpHash } = await constructUserOp(
            contractAddresses.USDC, erc20Abi, 'approve', [contractAddresses.UniswapRouter, parsedAmount], nfts[0].id, address, nonceSignature
        );

        setStatus('signingApproveUserOp');
        const userOpHashSignature = await signMessage(wagmiConfig, { message: { raw: userOpHash } });
        userOp.signature = userOpHashSignature;

        setStatus('transmittingApprove');
        return await transmitUserOp(userOp);
    };

    const routeSwap = async parsedAmount => {
        const { data: updatedNonce } = await refetchNonce();
        console.log(`Signing nonce for swap: ${updatedNonce}`);
        setStatus('signingSwapNonce');
        const nonceSignature = await signMessage(wagmiConfig, { message: { raw: keccak256(encodePacked(['address', 'uint256'], [contractAddresses.PayMaster, updatedNonce])) } });

        setStatus('constructingSwap');
        const deadline = Math.floor(Date.now() / 1000) + 60 * 10; // 10 minutes
        const swapParams = {
            tokenIn: contractAddresses.USDC,
            tokenOut: contractAddresses.WETH,
            fee: 3000, // 0.3% pool fee
            recipient: address,
            deadline,
            amountIn: parsedAmount,
            amountOutMinimum: 0n,
            sqrtPriceLimitX96: 0n,
        };
        const { userOp, userOpHash } = await constructUserOp(
            contractAddresses.UniswapRouter, routerAbi, 'exactInputSingle', [swapParams], nfts[0].id, address, nonceSignature
        );

        setStatus('signingSwapUserOp');
        const userOpHashSignature = await signMessage(wagmiConfig, { message: { raw: userOpHash } });
        userOp.signature = userOpHashSignature;

        setStatus('transmittingSwap');
        return await transmitUserOp(userOp);
    };

    const showTransactionPopup = () => openPopup({
        chainId: networks.TransactionChain.id,
        address: contractAddresses.SimpleCounter
    });

    const goToCounter = () => dispatch({ type: 'VIEW_COUNTER' });

    return (
        <div className='h-full flex items-center justify-center'>
            <div className='flex items-center justify-center gap-12 w-1/2'>
                <button className='
                    w-0 h-0 border-t-12 border-b-12 border-r-20 border-t-transparent border-b-transparent border-r-green-700 hover:border-r-green-900 cursor-pointer transition-colors disabled:cursor-not-allowed' disabled={status !== 'idle'} onClick={goToCounter}></button>
                <div className='p-6 border rounded-3xl shadow-sm space-y-6 bg-white'>
                    <h2 className='text-2xl font-semibold text-gray-800 text-center'>
                        Swap USDC → WETH (Sepolia)
                    </h2>

                    <div className='flex flex-col space-y-4'>
                        <div className='flex justify-between text-sm text-gray-400'>
                            <span>USDC Balance:</span>
                            <code className='font-mono'>{formattedBalance} USDC</code>
                        </div>

                        <input
                            type='number'
                            min='0'
                            step='0.001'
                            placeholder='Amount in USDC'
                            value={amount}
                            onChange={e => setAmount(e.target.value)}
                            className='border border-gray-300 focus:ring-2 focus:ring-blue-400 focus:outline-none p-3 rounded-lg w-full text-gray-800'
                        />
                        
                        <div className='h-32'>
                            {
                                txHash && 
                                <p className='mt-4 text-sm text-gray-600 break-all'>
                                    ✅ Transaction:&nbsp;
                                    <a
                                        href={`${networks.TransactionChain.blockExplorer}/tx/${txHash}`}
                                        target='_blank'
                                        className='text-blue-600 hover:underline'
                                    >{txHash}</a>
                                </p>
                            }
                        </div>

                        <Button 
                            onClick={swap} getButtonText={getButtonText} 
                            isDisabled={status !== 'idle' || nfts === undefined || nfts.length === 0 || !amount} 
                            isLoading={status !== 'idle'} spinnerColor='green-700'
                        >
                        </Button>
                    </div>
                </div>
                <button className='w-0 h-0 border-t-12 border-b-12 border-l-20 border-t-transparent border-b-transparent border-l-green-700 hover:border-l-green-900 cursor-pointer transition-colors invisible'></button>
            </div>
        </div>
    )
}
import { useState, useCallback } from 'react';
//import { createModularAccountAlchemyClient } from '@alchemy/aa-alchemy';
//import { encodeFunctionData } from 'viem';
import contractAddresses from '@/constants/contractAddresses.json';

export default function useSendUserOp() {
    //const [txHash, setTxHash] = useState();
    const [isPending, setIsPending] = useState(false);
    const [error, setError] = useState(null);

    const sendUserOp = useCallback(async ({ ...userOp }) => {
        try {
            setIsPending(true);
            setError(null);
            const response = await fetch(`https://eth-sepolia.g.alchemy.com/v2/${process.env.NEXT_PUBLIC_ALCHEMY_API_KEY}`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    jsonrpc: '2.0',
                    method: 'eth_sendUserOperation',
                    params: [
                        { ...userOp },
                        contractAddresses.EntryPointLegacy
                    ],
                    id: 1
                }),
            });

            const data = await response.json();
            console.log(data);
        } catch (error) {
            console.error(`User operation failed: ${error}`);
            setError(error);
        } finally {
            setIsPending(false);
        }
    });

    return { isPending, error, sendUserOpToBundler };
    /*const sendUserOp = useCallback(async () => {
        try {
            console.log('start')
            setIsPending(true);
            setError(null);
            setTxHash(undefined);

            const client = await createModularAccountAlchemyClient({
                apiKey: process.env.NEXT_PUBLIC_ALCHEMY_API_KEY,
                chain,
                signer
            });
            console.log('client', client)
            const result = await client.sendUserOperation({
                uo: {
                    target: contractAddress,
                    data: encodeFunctionData({
                        abi,
                        functionName
                    })
                }
            });
            console.log('result ', result)
            const hash = await client.waitForUserOperationTransaction(result);
            setTxHash(hash);
        } catch (error) {
            console.error(`User operation failed: ${error}`);
            setError(error);
        } finally {
            setIsPending(false);
        }
    }, [contractAddress, abi, functionName, chain, signer]);

    return { txHash, isPending, error, sendUserOp };*/
}
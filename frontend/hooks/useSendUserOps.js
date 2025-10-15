import { useState, useCallback } from 'react';
import { createModularAccountAlchemyClient } from '@alchemy/aa-alchemy';
import { encodeFunctionData } from 'viem';

export function useAlchemyUserOperation({
    contractAddress,
    abi,
    functionName,
    chain,
    signer,
}) {
    const [txHash, setTxHash] = useState();
    const [isPending, setIsPending] = useState(false);
    const [error, setError] = useState(null);

    const sendUserOp = useCallback(async () => {
        try {
            setIsPending(true);
            setError(null);
            setTxHash(undefined);

            const client = await createModularAccountAlchemyClient({
                apiKey: process.env.NEXT_PUBLIC_ALCHEMY_API_KEY,
                chain,
                signer
            });

            const result = await client.sendUserOperation({
                uo: {
                    target: contractAddress,
                    data: encodeFunctionData({
                        abi,
                        functionName
                    })
                }
            });

            const hash = await client.waitForUserOperationTransaction(result);
            setTxHash(hash);
        } catch (error) {
            console.error(`User operation failed: ${error}`);
            setError(error);
        } finally {
            setIsPending(false);
        }
    }, [contractAddress, abi, functionName, chain, signer]);

    return { txHash, isPending, error, sendUserOp };
}
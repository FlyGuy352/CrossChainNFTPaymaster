import { useQuery } from '@tanstack/react-query';
import { createPublicClient, http, parseEventLogs } from 'viem';
import { hederaTestnet } from 'viem/chains';
import contractAddresses from '@/constants/contractAddresses.json';
import nftAbi from '@/constants/DummyNFT.json';

export default function useNFTs(ownerAddress) {
    const client = createPublicClient({
        chain: hederaTestnet,
        transport: http(),
    });

    return useQuery({
        queryKey: ['nfts', ownerAddress],
        queryFn: async () => {
            const logs = await getEventLogsFromMirror(ownerAddress);
            const tokenIds = logs.map(log => log.args.tokenId);
            const tokenURIs = await Promise.all(tokenIds.map(tokenId =>
                client.readContract({
                    address: contractAddresses.DummyNFT,
                    abi: nftAbi,
                    functionName: 'tokenURI',
                    args: [tokenId]
                })
            ));
            console.log('tokenURIs ', tokenURIs)
            return tokenIds.map((id, index) => ({ id, uri: tokenURIs[index] }));
        },
        enabled: Boolean(ownerAddress),
        refetchOnWindowFocus: false
    });
}

async function getEventLogsFromMirror(toAddress) {
    const result = await fetch(`https://testnet.mirrornode.hedera.com/api/v1/contracts/${contractAddresses.DummyNFT}/results/logs?order=asc`);
    const data = await result.json();
    if (!data?.logs?.length) {
        return [];
    }
    const logs = parseEventLogs({ abi: nftAbi, logs: data.logs });
    return logs.filter(log => log.eventName === 'Transfer' && log.args.to === toAddress);
}
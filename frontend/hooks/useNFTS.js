import { useQuery } from '@tanstack/react-query';
import { createPublicClient, http } from 'viem';
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
            const events = await client.getContractEvents({
                address: contractAddresses.DummyNFT,
                abi: nftAbi,
                eventName: 'Transfer',
                args: { to: ownerAddress }
            });

            const tokenIds = events.map(event => event.args.tokenId);
            const tokenURIs = await Promise.all(tokenIds.map(tokenId =>
                client.readContract({
                    address: contractAddresses.DummyNFT,
                    abi: nftAbi,
                    functionName: 'tokenURI',
                    args: [tokenId]
                })
            ));
            return tokenIds.map((id, index) => ({ id, uri: tokenURIs[index] }));
        },
        enabled: Boolean(ownerAddress)
    });
}
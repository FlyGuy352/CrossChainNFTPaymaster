import { useQuery } from '@tanstack/react-query';
import { AccountId, PrivateKey, Client } from '@hashgraph/sdk';
import contractAddresses from '@/constants/contractAddresses.json';
import { decodeBase64 } from '@/utils/typeConverter';

export default function useHederaNFTs(ownerAddress) {
    
    // It seems like these can be insecure values because they are just for reading contracts
    const accountId = AccountId.fromString('0.0.7013264');
    const privateKey = PrivateKey.fromStringECDSA('0xbfb2aaae8a4282682fc8930eaec22d7151b3d277e0e7d855aedcb266345fa5f6');

    const client = Client.forTestnet();
    client.setOperator(accountId, privateKey);

    return useQuery({
        queryKey: ['nfts', ownerAddress],
        queryFn: async () => {
            const response = await fetch(
                `https://testnet.mirrornode.hedera.com/api/v1/accounts/${ownerAddress}/nfts?limit=200&order=desc`
            );
            if (!response.ok) {
                return console.error(`HTTP error when fetching NFTs! Status: ${response.status}`);
            }
            const data = await response.json();
            return data.nfts.filter(({ token_id }) => token_id === contractAddresses.HederaTokenId)
                .map(token => ({ id: token.serial_number, uri: decodeBase64(token.metadata) }));
        },
        enabled: Boolean(ownerAddress),
        refetchOnWindowFocus: false
    });
}
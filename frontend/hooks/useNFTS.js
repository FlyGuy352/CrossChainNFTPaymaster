import { useQuery } from '@tanstack/react-query';
import { createPublicClient, http } from 'viem';
import { hederaTestnet } from 'viem/chains';
import contractAddresses from '@/constants/contractAddresses.json';
import nftAbi from '@/constants/DummyNFT.json';

import {
    Client,
    PrivateKey,
    ContractCreateTransaction,
    FileCreateTransaction,
    AccountId, Hbar, ContractExecuteTransaction, ContractCallQuery,
} from '@hashgraph/sdk';

export default function useNFTs(ownerAddress) {
    const client = createPublicClient({
        chain: hederaTestnet,
        transport: http(),
    });

    return useQuery({
        queryKey: ['nfts', ownerAddress],
        queryFn: async () => {
            console.log('running ', ownerAddress, contractAddresses.DummyNFT, nftAbi)
            const events = await client.getContractEvents({
                address: contractAddresses.DummyNFT,
                abi: nftAbi,
                eventName: 'Transfer',
                args: { to: ownerAddress }
            });
            console.log('events ', events)
            
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

/**
 * Gets all the events for a given ContractId from a mirror node
 * Note: To particular filtering is implemented here, in practice you'd only want to query for events
 * in a time range or from a given timestamp for example
 * @param contractId
 */
async function getEventsFromMirror(contractId) {
    console.log(`\nGetting event(s) from mirror`);
    const url = `https://testnet.mirrornode.hedera.com/api/v1/contracts/${contractId.toString()}/results/logs?order=asc`;

    try {
        const response = await fetch(url);
        if (!response.ok) {
            throw new Error(`HTTP error! Status: ${response.status}`);
        }

        const jsonResponse = await response.json();

        jsonResponse.logs.forEach(log => {
            // decode the event data
            const event = decodeEvent('SetMessage', log.data, log.topics.slice(1));

            // output the from address and message stored in the event
            console.log('event ', event);
        });
    } catch (error) {
        console.error(`Error fetching mirror events: ${error}`);
    }
}

/**
 * Decodes event contents using the ABI definition of the event
 * @param eventName the name of the event
 * @param log log data as a Hex string
 * @param topics an array of event topics
 */
function decodeEvent(eventName, log, topics) {
    const eventAbi = abi.find(event => (event.name === eventName && event.type === 'event'));
    const decodedLog = web3.eth.abi.decodeLog(eventAbi.inputs, log, topics);
    return decodedLog;
}
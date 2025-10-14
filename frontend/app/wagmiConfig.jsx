import { http, createConfig } from '@wagmi/core';
import { hederaTestnet, sepolia } from 'wagmi/chains';

export const wagmiConfig = createConfig({
    chains: [hederaTestnet, sepolia],
    transports: { 
        [hederaTestnet.id]: http(),
        [sepolia.id]: http()
    }
});
'use client';

import { WagmiProvider } from 'wagmi';
import { wagmiConfig } from './wagmiConfig';
import { RainbowKitProvider } from '@rainbow-me/rainbowkit';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { NotificationProvider, TransactionPopupProvider } from '@blockscout/app-sdk';

const queryClient = new QueryClient();

export default function Providers({ children }) {
    return (
        <WagmiProvider config={wagmiConfig}>
            <QueryClientProvider client={queryClient}>
                <RainbowKitProvider>
                    <NotificationProvider>
                        <TransactionPopupProvider>
                            {children}
                        </TransactionPopupProvider>
                    </NotificationProvider>
                </RainbowKitProvider>
            </QueryClientProvider>
        </WagmiProvider>
    );
}
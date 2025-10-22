import { signMessage } from '@wagmi/core';
import { wagmiConfig } from '@/app/wagmiConfig';
import { encodePacked, keccak256, toBytes } from 'viem';

export const signMessageHash = async (types, values) => {
    const signature = await signMessage(wagmiConfig, { message: { raw: keccak256(encodePacked(types, values)) } }); 
    return signature;
}

export const signHashValue = async hash => {
    const signature = await signMessage(wagmiConfig, { message: { raw: hash } });
    return signature;
};

export const calculateAddressSalt = address => {
    if (address === undefined) {
        return undefined;
    }
    const salt = keccak256(toBytes(address));
    return salt;
};
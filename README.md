# 💵 Cross-Chain NFT Paymaster

## 📜 Contracts Overview

## 👤 Accounts Overview

## 🔁 Workflow Overview

![Alt text](./assets/Sequence%20Diagram.svg)

<details>
<summary>1️⃣ Minting an NFT</summary>

1. User clicks Mint button on frontend.
    1.1 Frontend calls `adminSign()` backend function with `userAddress`.
    1.2 Backend returns `adminSignature` of concatentation of `tokenId` and `userAddress` to frontend.
    1.3 Frontend prompts user wallet.
    1.4 User confirms transaction to mint NFT.
    1.5 Frontend calls `mint()` function on `NFT Contract` with `userAddress`, `tokenURI`, and `adminSignature`.
    1.6 `NFT Contract` internally calls `_verifySignature()` function with `userAddress`, `tokenId`, and `adminSignature` before minting NFT.
    1.7 Hedera network returns transaction confirmation to frontend.
    1.8 Frontend calls `refetchNFTs()` function with `userAddress` to retrieve the newly minted NFT information.

</details>

<details>
<summary>2️⃣ Incrementing Counter via Paymaster</summary>

2. User clicks Increment button on frontend.
    2.1 Frontend calls `signMessageHash()` function with `paymasterAddress` and `nonce` which prevents paymaster replay attacks. This prompts user to sign the message via his connected wallet.
    2.2 User's connected wallet returns `nonceSignature` to frontend.
    2.3 Frontend calls `constructUserOp()` function on backend with `tokenId`, `userAddress`, and `nonceSignature`.
    2.4 Backend internally calls `calculateAddress()` function with `userAddress` to generate `salt`.
    2.5 Backend calls `getWalletAddress()` function on `Factory Contract` with `userAddress` and `salt`.
    2.6 `Factory Contract` returns `walletAddress` to backend.
    2.7 Backend reads `signatures()` mapping on `NFT Contract` with `tokenId` as key.
    2.8 `NFT Contract` returns `adminSignature` to backend.
    2.9 Backend assigns `paymasterAndData` using `adminSignature`, `tokenId`, `userAddress`, `userSignature` (and other gas-related values).
    2.10 Backend assigns `userOp` using `walletAddress`, `initCode`, `callData`, `paymasterAndData` (and other gas-related values).
    2.11 Backend calls `getUserOpHash()` function on `Entrypoint Contract` with `userOp`.
    2.12 `Entrypoint Contract` returns `userOpHash` to backend.
    2.13 Backend returns `userOp` and `userOpHash` to frontend.
    2.14 Frontend calls `signHashValue()` function with `userOpHash`. This prompts user to sign the message via his connected wallet.
    2.15 User's connected wallet returns `userOpHashSignature` to frontend.
    2.16 Frontend assigns `userOp.signature` to `userOpHashSignature`.
    2.17 Frontend calls `transmitUserOp()` function on backend with `userOp`.
    2.18 Backend calls `handleOps()` function on `Entrypoint Contract` with `userOp` and `adminAccountAddress`.
    2.19 `Entrypoint Contract` internally calls `_createSenderIfNeeded()` function with `initCode` to ensure `Factory Contract` creates a new `Wallet Contract` for the user if needed.
    2.20 `Entrypoint Contract` calls `validateUserOp()` function on `Wallet Contract` with `userOp` and `userOpHash`.
    2.21 `Wallet Contract` internally calls `_rawSignatureVerification()` function with `userOpHash` and `userSignature`.
    2.22 `Wallet Contract` returns `SIG_VALIDATION_SUCCESS` to `Entrypoint Contract`.
    2.23 `Entrypoint Contract` calls `validatePaymasterUserOp()` function on `Paymaster Contract` with `userOp` and `userOpHash`.
    2.24 `Paymaster Contract` internally calls `_verifyAdminSignature()` function with `userAddress`, `tokenId`, and `adminSignature`.
    2.25 `Paymaster Contract` internally calls `_verifyUserSignature()` function with `nonce`, `userAddress`, and `userSignature`.
    2.26 `Paymaster Contract` returns `SIG_VALIDATION_SUCCESS` to `Entrypoint Contract`.
    2.27 `Entrypoint Contract` calls `execute()` function on `Wallet Contract` with `counterAddress` and the string `'increment'`.
    2.28 `Wallet Contract` calls `increment()` function on `Counter Contract`.
    2.29 `Entrypoint Contract` internally calls `_compensate` function with `adminAccountAddress` and `gasFees` to transfer fees to the Admin Account.
    2.30 Ethereum Sepolia blockchain returns transaction confirmation to backend.
    2.31 Backend returns transaction confirmation to backend.

</details>

## 🚧 Future Roadmap & Enhancements
# 💵 Cross-Chain NFT Paymaster

## 👤 Contracts Overview

## 👤 Accounts Overview

## 🔁 Workflow Overview

![Alt text](./assets/Sequence%20Diagram.svg)

<details>
<summary>1️⃣ Minting an NFT</summary>

1. User clicks Mint button on frontend.<br><br>
    1.1 Frontend calls `adminSign()` backend function with `userAddress`.<br><br>
    1.2 Backend returns `adminSignature` of concatentation of `tokenId` and `userAddress` to frontend.<br><br>
    1.3 Frontend prompts user wallet.<br><br>
    1.4 User confirms transaction to mint NFT.<br><br>
    1.5 Frontend calls `mint()` function on NFT Contract with `userAddress`, `tokenURI`, and `adminSignature`.<br><br>
    1.6 NFT Contract internally calls `_verifySignature()` function with `userAddress`, `tokenId`, and `adminSignature` before minting NFT.<br><br>
    1.7 Hedera network returns transaction confirmation to frontend.<br><br>
    1.8 Frontend calls `refetchNFTs()` function with `userAddress` to retrieve the newly minted NFT information.<br><br>

</details>

<details>
<summary>2️⃣ Incrementing Counter via Paymaster</summary>

2. User clicks Increment button on frontend.<br><br>
    2.1 Frontend calls `signMessageHash()` function with `paymasterAddress` and `nonce` which prevents paymaster replay attacks. This prompts user to sign the message via his connected wallet.<br><br>
    2.2 User's connected wallet returns `nonceSignature` to frontend.<br><br>
    2.3 Frontend calls `constructUserOp()` function on backend with `tokenId`, `userAddress`, and `nonceSignature`.<br><br>
    2.4 Backend internally calls `calculateAddress()` function with `userAddress` to generate `salt`.<br><br>
    2.5 Backend calls `getWalletAddress()` function on Factory Contract with `userAddress` and `salt`.<br><br>
    2.6 Factory Contract returns `walletAddress` to backend.<br><br>
    2.7 Backend reads `signatures()` mapping on NFT Contract with `tokenId` as key.<br><br>
    2.8 NFT Contract returns `adminSignature` to backend.<br><br>
    2.9 Backend assigns `paymasterAndData` using `adminSignature`, `tokenId`, `userAddress`, `userSignature` (and other gas-related values).<br><br>
    2.10 Backend assigns `userOp` using `walletAddress`, `initCode`, `callData`, `paymasterAndData` (and other gas-related values).<br><br>
    2.11 Backend calls `getUserOpHash()` function on Entrypoint Contract with `userOp`.<br><br>
    2.12 Entrypoint Contract returns `userOpHash` to backend.<br><br>
    2.13 Backend returns `userOp` and `userOpHash` to frontend.<br><br>
    2.14 Frontend calls `signHashValue()` function with `userOpHash`. This prompts user to sign the message via his connected wallet.<br><br>
    2.15 User's connected wallet returns `userOpHashSignature` to frontend.<br><br>
    2.16 Frontend assigns `userOp.signature` to `userOpHashSignature`.<br><br>
    2.17 Frontend calls `transmitUserOp()` function on backend with `userOp`.<br><br>
    2.18 Backend calls `handleOps()` function on Entrypoint Contract with `userOp` and `adminAccountAddress`.<br><br>
    2.19 Entrypoint Contract internally calls `_createSenderIfNeeded()` function with `initCode` to ensure Factory Contract creates a new Wallet Contract for the user if needed.<br><br>
    2.20 Entrypoint Contract calls `validateUserOp()` function on Wallet Contract with `userOp` and `userOpHash`.<br><br>
    2.21 Wallet Contract internally calls `_rawSignatureVerification()` function with `userOpHash` and `userSignature`.<br><br>
    2.22 Wallet Contract returns `SIG_VALIDATION_SUCCESS` to Entrypoint Contract.<br><br>
    2.23 Entrypoint Contract calls `validatePaymasterUserOp()` function on Paymaster Contract with `userOp` and `userOpHash`.<br><br>
    2.24 Paymaster Contract internally calls `_verifyAdminSignature()` function with `userAddress`, `tokenId`, and `adminSignature`.<br><br>
    2.25 Paymaster Contract internally calls `_verifyUserSignature()` function with `nonce`, `userAddress`, and `userSignature`.<br><br>
    2.26 Paymaster Contract returns `SIG_VALIDATION_SUCCESS` to Entrypoint Contract.<br><br>
    2.27 Entrypoint Contract calls `execute()` function on Wallet Contract with `counterAddress` and the string `'increment'`.<br><br>
    2.28 Wallet Contract calls `increment()` function on Counter Contract.<br><br>
    2.29 Entrypoint Contract internally calls `_compensate` function with `adminAccountAddress` and `gasFees` to transfer fees to the Admin Account.<br><br>
    2.30 Ethereum Sepolia blockchain returns transaction confirmation to backend.<br><br>
    2.31 Backend returns transaction confirmation to backend.<br><br>

</details>

## 🚧 Future Roadmap & Enhancements
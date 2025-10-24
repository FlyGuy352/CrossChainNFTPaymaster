# 💵 Cross-Chain NFT Paymaster

**X-Chain NFTPaymaster** bridges **Hedera** and **Ethereum** by allowing users to mint NFTs on Hedera and then perform **gasless transactions on Ethereum**. It demonstrates a practical cross-chain design where ownership on one network unlocks utility on another through **ECDSA-based signature verification**. The system leverages **Hedera's low-cost minting** and **Ethereum's Account Abstraction (ERC-4337)** to create a secure, user-friendly experience. A **Next.js frontend** handles minting, wallet connections, and cross-network interactions, while a **Hardhat backend** manages smart contract deployment and verification. Overall, the project showcases seamless interoperability between EVM-compatible chains through cryptographic proofs of ownership.

This README does not provide a comprehensive overview of **ERC-4337**. The concept of Account Abstraction introduces a new **User Operation** flow and validation layer on top of traditional externally owned accounts (EOAs). For readers new to this standard or seeking a deeper understanding of its architecture, please visit the [official ERC-4337 documentation](https://docs.erc4337.io/index.html).

## 👤 Contracts Overview

## 👤 Accounts Overview

## 🔁 Workflow Overview

![Alt text](./assets/Sequence%20Diagram.svg)

<details>
<summary><strong>1️⃣ Minting an NFT</strong></summary>
<br>
&nbsp;&nbsp;&nbsp;&nbsp;<strong>1:</strong> User clicks Mint button on frontend.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;1.1: Frontend calls <code>adminSign()</code> backend function with <code>userAddress</code>.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;1.2: Backend returns <code>adminSignature</code> of concatentation of <code>tokenId</code> and <code>userAddress</code> to frontend.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;1.3: Frontend prompts user wallet.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;1.4: User confirms transaction to mint NFT.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;1.5: Frontend calls <code>mint()</code> function on NFT Contract with <code>userAddress</code>, <code>tokenURI</code>, and <code>adminSignature</code>.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;1.6: NFT Contract internally calls <code>_verifySignature()</code> function with <code>userAddress</code>, <code>tokenId</code>, and <code>adminSignature</code> before minting NFT.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;1.7: Hedera network returns transaction confirmation to frontend.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;1.8: Frontend calls <code>refetchNFTs()</code> function with <code>userAddress</code> to retrieve the newly minted NFT information.
</details>

<details>
<summary><strong>2️⃣ Incrementing Counter via Paymaster</strong></summary>
<br>
&nbsp;&nbsp;&nbsp;&nbsp;<strong>2:</strong> User clicks Increment button on frontend.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.1: Frontend calls <code>signMessageHash()</code> function with <code>paymasterAddress</code> and <code>nonce</code> which prevents paymaster replay attacks. This prompts user to sign the message via his connected wallet.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.2: User's connected wallet returns <code>nonceSignature</code> to frontend.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.3: Frontend calls <code>constructUserOp()</code> function on backend with <code>tokenId</code>, <code>userAddress</code>, and <code>nonceSignature</code>.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.4: Backend internally calls <code>calculateAddress()</code> function with <code>userAddress</code> to generate <code>salt</code>.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.5: Backend calls <code>getWalletAddress()</code> function on Factory Contract with <code>userAddress</code> and <code>salt</code>.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.6: Factory Contract returns <code>walletAddress</code> to backend.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.7: Backend reads <code>signatures()</code> mapping on NFT Contract with <code>tokenId</code> as key.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.8: NFT Contract returns <code>adminSignature</code> to backend.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.9: Backend assigns <code>paymasterAndData</code> using <code>adminSignature</code>, <code>tokenId</code>, <code>userAddress</code>, <code>userSignature</code> (and other gas-related values).<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.10: Backend assigns <code>userOp</code> using <code>walletAddress</code>, <code>initCode</code>, <code>callData</code>, <code>paymasterAndData</code> (and other gas-related values).<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.11: Backend calls <code>getUserOpHash()</code> function on Entrypoint Contract with <code>userOp</code>.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.12: Entrypoint Contract returns <code>userOpHash</code> to backend.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.13: Backend returns <code>userOp</code> and <code>userOpHash</code> to frontend.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.14: Frontend calls <code>signHashValue()</code> function with <code>userOpHash</code>. This prompts user to sign the message via his connected wallet.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.15: User's connected wallet returns <code>userOpHashSignature</code> to frontend.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.16: Frontend assigns <code>userOp.signature</code> to <code>userOpHashSignature</code>.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.17: Frontend calls <code>transmitUserOp()</code> function on backend with <code>userOp</code>.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.18: Backend calls <code>handleOps()</code> function on Entrypoint Contract with <code>userOp</code> and <code>adminAccountAddress</code>.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.19: Entrypoint Contract internally calls <code>_createSenderIfNeeded()</code> function with <code>initCode</code> to ensure Factory Contract creates a new Wallet Contract for the user if needed.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.20: Entrypoint Contract calls <code>validateUserOp()</code> function on Wallet Contract with <code>userOp</code> and <code>userOpHash</code>.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.21: Wallet Contract internally calls <code>_rawSignatureVerification()</code> function with <code>userOpHash</code> and <code>userSignature</code>.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.22: Wallet Contract returns <code>SIG_VALIDATION_SUCCESS</code> to Entrypoint Contract.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.23: Entrypoint Contract calls <code>validatePaymasterUserOp()</code> function on Paymaster Contract with <code>userOp</code> and <code>userOpHash</code>.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.24: Paymaster Contract internally calls <code>_verifyAdminSignature()</code> function with <code>userAddress</code>, <code>tokenId</code>, and <code>adminSignature</code>.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.25: Paymaster Contract internally calls <code>_verifyUserSignature()</code> function with <code>nonce</code>, <code>userAddress</code>, and <code>userSignature</code>.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.26: Paymaster Contract returns <code>SIG_VALIDATION_SUCCESS</code> to Entrypoint Contract.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.27: Entrypoint Contract calls <code>execute()</code> function on Wallet Contract with <code>counterAddress</code> and the string 'increment'.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.28: Wallet Contract calls <code>increment()</code> function on Counter Contract.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.29: Entrypoint Contract internally calls <code>_compensate</code> function with <code>adminAccountAddress</code> and <code>gasFees</code> to transfer fees to the Admin Account.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.30: Ethereum Sepolia blockchain returns transaction confirmation to backend.<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2.31: Backend returns transaction confirmation to backend.
</details>

## 🚧 Future Roadmap & Enhancements

### ⚠️ Resolve Security Issue

Although we assume a secure backend generates the admin signature which is required for the NFT contract's <code>mint()</code> function, this value is passed to the frontend since the user executes the mint transaction himself on Hedera testnet. This creates a small window where the signature could be exposed on the frontend, which is not ideal from a security perspective.

#### 🛠️ Mitigation Strategies

There are three potential approaches to mitigate this issue, each carrying different trust and architectural trade-offs.

---

##### 1️⃣ Off-chain Signing Process (Onchain → Offchain)
The NFT contract's <code>mint()</code> function could be redesigned to remove the need for an admin signature at the time of minting. Instead, the function could trigger an oracle that initiates an off-chain signing process. Once the off-chain computation is complete, the resulting admin signature would be submitted back to the contract in a separate transaction, ensuring the signature is never exposed to the frontend.

This approach shifts the trust assumptions to the reliability of the oracle infrastructure and the integrity of the off-chain signing service.

---

##### 2️⃣ Off-chain Signing Process (Offchain → Onchain)
A variation of the first approach would involve an off-chain service that proactively generates and submits admin signatures to the contract, either on demand or in scheduled batches. This removes the need for real-time oracle calls and allows more flexible management of signing workflows.

While this approach simplifies onchain interactions, it shifts full trust to the availability, security, and correctness of the off-chain signing infrastructure.

---

##### 3️⃣ Authenticated Frontend
Lastly, the solution could simply involve designing an authenticated or gated frontend. In this model, only verified users or sessions would be able to request and receive the admin signature from the backend. This can be achieved through authentication tokens, wallet-based access control, or short-lived API sessions.

While this approach is simpler to implement, it does not eliminate the exposure risk entirely - it merely restricts access to trusted users. Therefore, it serves best as a complementary measure alongside one of the off-chain signing strategies described above.

### 📦 Use an Actual Bundler API


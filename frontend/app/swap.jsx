'use client'

import { useState } from 'react'
import { useAccount, useConnect, useDisconnect, usePublicClient, useWalletClient } from 'wagmi'
import { injected } from 'wagmi/connectors'
import { parseEther, zeroAddress } from 'viem';
import swapAbi from '@/constants/UniswapRouter.json';

const UNISWAP_V3_ROUTER = '0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E' // same router on Sepolia
const USDC_SEPOLIA = '0x1c7d4b196cb0c7b01d743fbc6116a902379c7238';
const WETH_SEPOLIA = '0xfff9976782d46cc05630d1f6ebab18b2324d6b14';

export default function SwapETHToUSDC() {
  const [amount, setAmount] = useState('')
  const [txHash, setTxHash] = useState('')
  const [loading, setLoading] = useState(false)

  const { address, isConnected } = useAccount()
  const { connect } = useConnect({ connector: injected() })
  const { disconnect } = useDisconnect()
  const { data: walletClient } = useWalletClient()
  const publicClient = usePublicClient()

  async function handleSwap() {
    if (!walletClient || !address) {
      alert('Connect your wallet first.')
      return
    }

    try {
      setLoading(true)

const erc20Abi = [
  { name: 'approve', type: 'function', stateMutability: 'nonpayable', inputs: [
      { name: 'spender', type: 'address' },
      { name: 'amount', type: 'uint256' }
    ], outputs: [{ name: '', type: 'bool' }]
  },
]
await walletClient.writeContract({
  address: USDC_SEPOLIA,
  abi: erc20Abi,
  functionName: 'approve',
  args: [UNISWAP_V3_ROUTER, amount],
})

      const deadline = Math.floor(Date.now() / 1000) + 60 * 10

      const tx = await walletClient.writeContract({
        address: UNISWAP_V3_ROUTER,
        abi: swapAbi,
        functionName: 'exactInputSingle',
        args: [
          {
            tokenIn: USDC_SEPOLIA, // ETH
            tokenOut: WETH_SEPOLIA,
            fee: 3000, // 0.3% pool fee
            recipient: address,
            deadline,
            amountIn: amount,
            amountOutMinimum: 0n, // no slippage protection (demo)
            sqrtPriceLimitX96: 0n,
          },
        ],
        gas: 8000000n,
      })

      setTxHash(tx)
      console.log('Swap tx:', tx)
    } catch (err) {
      console.error(err)
      alert(err.shortMessage || err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="max-w-md mx-auto mt-10 p-6 border rounded-2xl shadow-sm space-y-4">
      <h2 className="text-xl font-semibold">Swap USDC → WETH (Sepolia)</h2>

      {!isConnected ? (
        <button
          className="px-4 py-2 bg-blue-600 text-white rounded-xl"
          onClick={() => connect()}
        >
          Connect Wallet
        </button>
      ) : (
        <div className="flex flex-col space-y-3">
          <div className="flex justify-between">
            <span>Wallet:</span>
            <code>{address.slice(0, 6)}...{address.slice(-4)}</code>
          </div>

          <input
            type="number"
            min="0"
            step="0.001"
            placeholder="Amount in USDC"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            className="border p-2 rounded-lg w-full"
          />

          <button
            disabled={loading || !amount}
            onClick={handleSwap}
            className="px-4 py-2 bg-green-600 text-white rounded-xl disabled:opacity-50"
          >
            {loading ? 'Swapping...' : 'Swap'}
          </button>

          {txHash && (
            <p className="text-sm text-gray-500 break-all">
              ✅ Tx: <a href={`https://sepolia.etherscan.io/tx/${txHash}`} target="_blank" rel="noreferrer">
                {txHash}
              </a>
            </p>
          )}

          <button
            className="text-red-500 text-sm underline"
            onClick={() => disconnect()}
          >
            Disconnect
          </button>
        </div>
      )}
    </div>
  )
}

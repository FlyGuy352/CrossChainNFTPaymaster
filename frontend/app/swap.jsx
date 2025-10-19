'use client'

import { useState } from 'react'
import {
  useAccount,
  useConnect,
  useDisconnect,
  usePublicClient,
  useWalletClient,
  useReadContract,
} from 'wagmi'
import { injected } from 'wagmi/connectors'
import { parseUnits, formatUnits } from 'viem'
import swapAbi from '@/constants/UniswapRouter.json'

// --- Constants ---
const UNISWAP_V3_ROUTER = '0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E'
const USDC_SEPOLIA = '0x1c7d4b196cb0c7b01d743fbc6116a902379c7238'
const WETH_SEPOLIA = '0xfff9976782d46cc05630d1f6ebab18b2324d6b14'

// --- Minimal ERC20 ABI ---
const erc20Abi = [
  {
    name: 'approve',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'spender', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    outputs: [{ name: '', type: 'bool' }],
  },
  {
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
  },
]

export default function SwapETHToUSDC() {
  const [amount, setAmount] = useState('')
  const [txHash, setTxHash] = useState('')
  const [loading, setLoading] = useState(false)

  const { address, isConnected } = useAccount()
  const { connect } = useConnect({ connector: injected() })
  const { data: walletClient } = useWalletClient()
  const publicClient = usePublicClient()

  // --- Read USDC balance ---
  const { data: usdcBalance } = useReadContract({
    address: USDC_SEPOLIA,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined
  })

  const formattedBalance =
    usdcBalance !== undefined ? Number(formatUnits(usdcBalance, 6)).toFixed(2) : '0.00'

  // --- Swap handler ---
  async function handleSwap() {
    if (!walletClient || !address) {
      alert('Please connect your wallet first.')
      return
    }

    try {
      setLoading(true)

      const parsedAmount = parseUnits(amount, 6) // USDC has 6 decimals
      const deadline = Math.floor(Date.now() / 1000) + 60 * 10 // 10 minutes

      // Approve router to spend USDC
      await walletClient.writeContract({
        address: USDC_SEPOLIA,
        abi: erc20Abi,
        functionName: 'approve',
        args: [UNISWAP_V3_ROUTER, parsedAmount],
      })

      // Swap params
      const swapParams = {
        tokenIn: USDC_SEPOLIA,
        tokenOut: WETH_SEPOLIA,
        fee: 3000, // 0.3% pool fee
        recipient: address,
        deadline,
        amountIn: parsedAmount,
        amountOutMinimum: 0n,
        sqrtPriceLimitX96: 0n,
      }

      // Execute swap
      const tx = await walletClient.writeContract({
        address: UNISWAP_V3_ROUTER,
        abi: swapAbi,
        functionName: 'exactInputSingle',
        args: [swapParams],
        gas: 8_000_000n,
      })

      setTxHash(tx)
      console.log('Swap successful:', tx)
    } catch (err) {
      console.error(err)
      alert(err.shortMessage || err.message)
    } finally {
      setLoading(false)
    }
  }

  // --- UI ---
  return (
    <div className="max-w-md mx-auto mt-12 p-6 border rounded-2xl shadow-sm space-y-6 bg-white">
      <h2 className="text-2xl font-semibold text-gray-800 text-center">
        Swap USDC → WETH (Sepolia)
      </h2>

      {!isConnected ? (
        <button
          onClick={() => connect()}
          className="w-full py-3 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-xl transition"
        >
          Connect Wallet
        </button>
      ) : (
        <div className="flex flex-col space-y-4">
          <div className="flex justify-between text-sm text-gray-600">
            <span>USDC Balance:</span>
            <code className="text-gray-800 font-mono">{formattedBalance} USDC</code>
          </div>

          <input
            type="number"
            min="0"
            step="0.001"
            placeholder="Amount in USDC"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            className="border border-gray-300 focus:ring-2 focus:ring-blue-400 focus:outline-none p-3 rounded-lg w-full text-gray-800"
          />

          <button
            disabled={loading || !amount}
            onClick={handleSwap}
            className={`w-full py-3 font-medium rounded-xl text-white transition ${
              loading || !amount
                ? 'bg-green-400 cursor-not-allowed'
                : 'bg-green-600 hover:bg-green-700'
            }`}
          >
            {loading ? 'Swapping...' : 'Swap'}
          </button>

          {txHash && (
            <p className="text-sm text-gray-600 break-all">
              ✅ Transaction:{' '}
              <a
                href={`https://sepolia.etherscan.io/tx/${txHash}`}
                target="_blank"
                rel="noreferrer"
                className="text-blue-600 hover:underline"
              >
                {txHash}
              </a>
            </p>
          )}
        </div>
      )}
    </div>
  )
}
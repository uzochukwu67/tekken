"use client"

import { useState } from "react"
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from "wagmi"
import { sepolia } from "wagmi/chains"

interface PlaceBetParams {
  matchId: number
  prediction: 0 | 1 | 2 // 0: home, 1: draw, 2: away
  amount: bigint
}

export function usePlaceBet() {
  const { address, chain } = useAccount()
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState(false)

  const { writeContract, data: hash } = useWriteContract()
  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash,
  })

  const placeBet = async (params: PlaceBetParams) => {
    try {
      setIsLoading(true)
      setError(null)
      setSuccess(false)

      // Validate chain
      if (chain?.id !== sepolia.id) {
        throw new Error("Please switch to Sepolia testnet")
      }

      if (!address) {
        throw new Error("Wallet not connected")
      }

      // Replace with your actual contract address and ABI
      const contractAddress = process.env.NEXT_PUBLIC_BETTING_CONTRACT_ADDRESS as `0x${string}`

      if (!contractAddress) {
        throw new Error("Contract address not configured")
      }

      // Call contract with writeContract
      writeContract({
        address: contractAddress,
        abi: [
          {
            name: "placeBet",
            type: "function",
            inputs: [
              { name: "matchId", type: "uint256" },
              { name: "prediction", type: "uint8" },
            ],
            outputs: [{ name: "betId", type: "uint256" }],
            stateMutability: "payable",
          },
        ],
        functionName: "placeBet",
        args: [BigInt(params.matchId), params.prediction],
        value: params.amount,
      })

      setSuccess(true)
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : "Failed to place bet"
      setError(errorMsg)
      console.error("Bet placement error:", err)
    } finally {
      setIsLoading(false)
    }
  }

  return {
    placeBet,
    isLoading: isLoading || isConfirming,
    error,
    success: success || isConfirmed,
    hash,
  }
}

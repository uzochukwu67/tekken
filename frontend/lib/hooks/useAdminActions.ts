"use client"

import { useWriteContract, useWaitForTransactionReceipt, useAccount } from "wagmi"
import { useContracts } from "./useContracts"
import { toast } from "sonner"

export function useAdminActions() {
  const { address } = useAccount()
  const { gameEngine } = useContracts()
  const { writeContract, data: hash, isPending } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const startSeason = async () => {
    if (!gameEngine?.address) {
      toast.error("GameEngine contract not found")
      return
    }

    try {
      writeContract({
        address: gameEngine.address,
        abi: gameEngine.abi,
        functionName: "startSeason",
      })
      toast.success("Starting new season...")
    } catch (error: any) {
      toast.error(error?.message || "Failed to start season")
      console.error("Start season error:", error)
    }
  }

  const startRound = async () => {
    if (!gameEngine?.address) {
      toast.error("GameEngine contract not found")
      return
    }

    try {
      writeContract({
        address: gameEngine.address,
        abi: gameEngine.abi,
        functionName: "startRound",
      })
      toast.success("Starting new round...")
    } catch (error: any) {
      toast.error(error?.message || "Failed to start round")
      console.error("Start round error:", error)
    }
  }

  const requestMatchResults = async () => {
    if (!gameEngine?.address) {
      toast.error("GameEngine contract not found")
      return
    }

    try {
      writeContract({
        address: gameEngine.address,
        abi: gameEngine.abi,
        functionName: "requestMatchResults",
      })
      toast.success("Requesting VRF for match results...")
    } catch (error: any) {
      toast.error(error?.message || "Failed to request match results")
      console.error("Request match results error:", error)
    }
  }

  const emergencySettleRound = async (roundId: bigint, seed: bigint) => {
    if (!gameEngine?.address) {
      toast.error("GameEngine contract not found")
      return
    }

    try {
      writeContract({
        address: gameEngine.address,
        abi: gameEngine.abi,
        functionName: "emergencySettleRound",
        args: [roundId, seed],
      })
      toast.success("Emergency settling round...")
    } catch (error: any) {
      toast.error(error?.message || "Failed to emergency settle")
      console.error("Emergency settle error:", error)
    }
  }

  return {
    startSeason,
    startRound,
    requestMatchResults,
    emergencySettleRound,
    isPending,
    isConfirming,
    isSuccess,
    hash,
  }
}

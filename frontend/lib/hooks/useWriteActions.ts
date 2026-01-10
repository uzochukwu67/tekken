"use client"

import { useCallback } from "react"
import { useContractWrite } from "wagmi"
import { useContracts } from "./useContracts"

type SendResult = {
  send: (args?: unknown[]) => Promise<any>
  isLoading: boolean
  error: any
}

// Generic hook to call any contract write function by name
export function useContractMethod(contractName: "gameEngine" | "bettingPool" | "liquidityPool" | "leagueToken", functionName: string): SendResult | null {
  const contracts = useContracts()
  const contract = (contracts as any)[contractName]

  if (!contract?.address) return null

  const { writeAsync, isLoading, error } = useContractWrite({
    address: contract.address as any,
    abi: contract.abi as any,
    functionName,
  } as any)

  const send = useCallback(
    async (args?: unknown[]) => {
      if (!writeAsync) throw new Error("write function not available")
      return await writeAsync({ args })
    },
    [writeAsync]
  )

  return {
    send,
    isLoading,
    error,
  }
}

// Specific helpers for common actions
export function usePlaceBet() {
  return useContractMethod("bettingPool", "placeBet")
}

export function useDepositLP() {
  return useContractMethod("liquidityPool", "deposit")
}

export function useWithdrawLP() {
  return useContractMethod("liquidityPool", "withdraw")
}

export function useApproveToken() {
  return useContractMethod("leagueToken", "approve")
}

export default useContractMethod

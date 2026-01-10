"use client"

import { useReadContract, useReadContracts } from "wagmi"
import { useContracts } from "./useContracts"
import type { Address } from "viem"

export type Prediction = {
  matchIndex: bigint
  outcome: number // 0=HOME, 1=AWAY, 2=DRAW
}

export type Bet = {
  id: bigint
  bettor: Address
  roundId: bigint
  amount: bigint
  potentialPayout: bigint
  settled: boolean
  won: boolean
  predictions: Prediction[]
}

export function useLiveOdds(roundId: bigint | undefined, matchIndex: bigint | undefined, outcome: number | undefined) {
  const { bettingPool } = useContracts()

  const { data, isLoading } = useReadContract({
    address: bettingPool?.address,
    abi: bettingPool?.abi,
    functionName: "getLiveOdds",
    args:
      roundId !== undefined && matchIndex !== undefined && outcome !== undefined
        ? [roundId, matchIndex, outcome]
        : undefined,
    query: {
      enabled: !!bettingPool?.address && roundId !== undefined && matchIndex !== undefined && outcome !== undefined,
      refetchInterval: 5000, // Update odds every 5 seconds
    },
  })

  return {
    odds: data as bigint | undefined,
    isLoading,
  }
}

export function useAllMatchOdds(roundId: bigint | undefined, matchIndex: bigint | undefined) {
  const { bettingPool } = useContracts()

  const contracts = [0, 1, 2].map((outcome) => ({
    address: bettingPool?.address,
    abi: bettingPool?.abi,
    functionName: "getLiveOdds" as const,
    args: roundId !== undefined && matchIndex !== undefined ? [roundId, matchIndex, outcome] : undefined,
  }))

  const { data, isLoading } = useReadContracts({
    contracts,
    query: {
      enabled: !!bettingPool?.address && roundId !== undefined && matchIndex !== undefined,
      refetchInterval: 5000,
    },
  })

  return {
    homeOdds: data?.[0]?.status === "success" ? (data[0].result as bigint) : undefined,
    awayOdds: data?.[1]?.status === "success" ? (data[1].result as bigint) : undefined,
    drawOdds: data?.[2]?.status === "success" ? (data[2].result as bigint) : undefined,
    isLoading,
  }
}

export function useCalculatePotentialPayout(
  roundId: bigint | undefined,
  amount: bigint | undefined,
  predictions: Prediction[] | undefined
) {
  const { bettingPool } = useContracts()

  const predictionArgs =
    predictions && predictions.length > 0
      ? predictions.map((p) => [p.matchIndex, p.outcome])
      : undefined

  const { data, isLoading } = useReadContract({
    address: bettingPool?.address,
    abi: bettingPool?.abi,
    functionName: "calculatePotentialWinningsWithOdds",
    args: roundId !== undefined && amount !== undefined && predictionArgs ? [roundId, amount, predictionArgs] : undefined,
    query: {
      enabled:
        !!bettingPool?.address &&
        roundId !== undefined &&
        amount !== undefined &&
        amount > 0n &&
        predictionArgs !== undefined,
      refetchInterval: 5000,
    },
  })

  return {
    potentialPayout: data?.[0] as bigint | undefined,
    basePayout: data?.[1] as bigint | undefined,
    poolBonus: data?.[2] as bigint | undefined,
    isLoading,
  }
}

export function useUserBets(userAddress: Address | undefined) {
  const { bettingPool } = useContracts()

  const { data: betIds, isLoading: loadingIds } = useReadContract({
    address: bettingPool?.address,
    abi: bettingPool?.abi,
    functionName: "getUserBets",
    args: userAddress ? [userAddress] : undefined,
    query: {
      enabled: !!bettingPool?.address && !!userAddress,
      refetchInterval: 10000,
    },
  })

  const ids = (betIds as bigint[]) || []

  // Fetch all bet details in parallel
  const betContracts = ids.map((id) => ({
    address: bettingPool?.address,
    abi: bettingPool?.abi,
    functionName: "getBet" as const,
    args: [id],
  }))

  const { data: betsData, isLoading: loadingBets } = useReadContracts({
    contracts: betContracts,
    query: {
      enabled: !!bettingPool?.address && ids.length > 0,
      refetchInterval: 10000,
    },
  })

  const bets = betsData
    ?.map((result, index) => {
      if (result.status === "success") {
        return {
          id: ids[index],
          ...(result.result as Omit<Bet, "id">),
        }
      }
      return null
    })
    .filter(Boolean) as Bet[]

  return {
    bets,
    isLoading: loadingIds || loadingBets,
  }
}

export function useBet(betId: bigint | undefined) {
  const { bettingPool } = useContracts()

  const { data, isLoading } = useReadContract({
    address: bettingPool?.address,
    abi: bettingPool?.abi,
    functionName: "getBet",
    args: betId !== undefined ? [betId] : undefined,
    query: {
      enabled: !!bettingPool?.address && betId !== undefined,
      refetchInterval: 10000,
    },
  })

  return {
    bet: data as Bet | undefined,
    isLoading,
  }
}

export function usePoolStats() {
  const { bettingPool } = useContracts()

  const { data, isLoading } = useReadContracts({
    contracts: [
      {
        address: bettingPool?.address,
        abi: bettingPool?.abi,
        functionName: "protocolReserve",
      },
      {
        address: bettingPool?.address,
        abi: bettingPool?.abi,
        functionName: "seasonPool",
      },
      {
        address: bettingPool?.address,
        abi: bettingPool?.abi,
        functionName: "totalBets",
      },
    ],
    query: {
      enabled: !!bettingPool?.address,
      refetchInterval: 10000,
    },
  })

  return {
    protocolReserve: data?.[0]?.status === "success" ? (data[0].result as bigint) : 0n,
    seasonPool: data?.[1]?.status === "success" ? (data[1].result as bigint) : 0n,
    totalBets: data?.[2]?.status === "success" ? (data[2].result as bigint) : 0n,
    isLoading,
  }
}

"use client"

import { useReadContract, useReadContracts, useBalance } from "wagmi"
import { useContracts } from "./useContracts"
import type { Address } from "viem"

export function useLiquidityPoolStats() {
  const { liquidityPool } = useContracts()

  const { data, isLoading } = useReadContracts({
    contracts: [
      {
        address: liquidityPool?.address,
        abi: liquidityPool?.abi,
        functionName: "getTotalLiquidity",
      },
      {
        address: liquidityPool?.address,
        abi: liquidityPool?.abi,
        functionName: "getAvailableLiquidity",
      },
      {
        address: liquidityPool?.address,
        abi: liquidityPool?.abi,
        functionName: "getUtilization",
      },
      {
        address: liquidityPool?.address,
        abi: liquidityPool?.abi,
        functionName: "getPoolMultiplier",
      },
      {
        address: liquidityPool?.address,
        abi: liquidityPool?.abi,
        functionName: "totalSupply",
      },
    ],
    query: {
      enabled: !!liquidityPool?.address,
      refetchInterval: 10000,
    },
  })

  const totalLiquidity = data?.[0]?.status === "success" ? (data[0].result as bigint) : 0n
  const availableLiquidity = data?.[1]?.status === "success" ? (data[1].result as bigint) : 0n
  const utilization = data?.[2]?.status === "success" ? (data[2].result as bigint) : 0n
  const poolMultiplier = data?.[3]?.status === "success" ? (data[3].result as bigint) : 0n
  const totalShares = data?.[4]?.status === "success" ? (data[4].result as bigint) : 0n

  const lockedLiquidity = totalLiquidity - availableLiquidity

  return {
    totalLiquidity,
    availableLiquidity,
    lockedLiquidity,
    utilization,
    poolMultiplier,
    totalShares,
    isLoading,
  }
}

export function useUserLPPosition(userAddress: Address | undefined) {
  const { liquidityPool } = useContracts()

  const { data, isLoading } = useReadContracts({
    contracts: [
      {
        address: liquidityPool?.address,
        abi: liquidityPool?.abi,
        functionName: "balanceOf",
        args: userAddress ? [userAddress] : undefined,
      },
      {
        address: liquidityPool?.address,
        abi: liquidityPool?.abi,
        functionName: "lastDepositTime",
        args: userAddress ? [userAddress] : undefined,
      },
      {
        address: liquidityPool?.address,
        abi: liquidityPool?.abi,
        functionName: "totalSupply",
      },
      {
        address: liquidityPool?.address,
        abi: liquidityPool?.abi,
        functionName: "getTotalLiquidity",
      },
    ],
    query: {
      enabled: !!liquidityPool?.address && !!userAddress,
      refetchInterval: 10000,
    },
  })

  const userShares = data?.[0]?.status === "success" ? (data[0].result as bigint) : 0n
  const lastDepositTime = data?.[1]?.status === "success" ? (data[1].result as bigint) : 0n
  const totalShares = data?.[2]?.status === "success" ? (data[2].result as bigint) : 0n
  const totalLiquidity = data?.[3]?.status === "success" ? (data[3].result as bigint) : 0n

  // Calculate user's share of pool
  const sharePercentage = totalShares > 0n ? (userShares * 10000n) / totalShares : 0n // In basis points
  const currentValue = totalShares > 0n ? (userShares * totalLiquidity) / totalShares : 0n

  // Check if withdrawal cooldown is active (15 minutes)
  const WITHDRAWAL_COOLDOWN = 15n * 60n
  const currentTime = BigInt(Math.floor(Date.now() / 1000))
  const canWithdraw = currentTime >= lastDepositTime + WITHDRAWAL_COOLDOWN
  const cooldownRemaining = canWithdraw ? 0n : lastDepositTime + WITHDRAWAL_COOLDOWN - currentTime

  return {
    userShares,
    sharePercentage,
    currentValue,
    lastDepositTime,
    canWithdraw,
    cooldownRemaining,
    isLoading,
  }
}

export function useCalculateDepositShares(amount: bigint | undefined) {
  const { liquidityPool } = useContracts()

  const { data, isLoading } = useReadContracts({
    contracts: [
      {
        address: liquidityPool?.address,
        abi: liquidityPool?.abi,
        functionName: "totalSupply",
      },
      {
        address: liquidityPool?.address,
        abi: liquidityPool?.abi,
        functionName: "getTotalLiquidity",
      },
    ],
    query: {
      enabled: !!liquidityPool?.address && amount !== undefined && amount > 0n,
    },
  })

  const totalShares = data?.[0]?.status === "success" ? (data[0].result as bigint) : 0n
  const totalLiquidity = data?.[1]?.status === "success" ? (data[1].result as bigint) : 0n

  let sharesToReceive = 0n
  let shareOfPool = 0n

  if (amount && amount > 0n) {
    if (totalShares === 0n || totalLiquidity === 0n) {
      // First deposit
      sharesToReceive = amount
      shareOfPool = 10000n // 100% in basis points
    } else {
      // Subsequent deposits
      sharesToReceive = (amount * totalShares) / totalLiquidity
      const newTotalShares = totalShares + sharesToReceive
      shareOfPool = (sharesToReceive * 10000n) / newTotalShares
    }
  }

  return {
    sharesToReceive,
    shareOfPool, // In basis points (e.g., 250 = 2.5%)
    isLoading,
  }
}

export function useCalculateWithdrawAmount(shares: bigint | undefined) {
  const { liquidityPool } = useContracts()

  const { data, isLoading } = useReadContracts({
    contracts: [
      {
        address: liquidityPool?.address,
        abi: liquidityPool?.abi,
        functionName: "totalSupply",
      },
      {
        address: liquidityPool?.address,
        abi: liquidityPool?.abi,
        functionName: "getTotalLiquidity",
      },
    ],
    query: {
      enabled: !!liquidityPool?.address && shares !== undefined && shares > 0n,
    },
  })

  const totalShares = data?.[0]?.status === "success" ? (data[0].result as bigint) : 0n
  const totalLiquidity = data?.[1]?.status === "success" ? (data[1].result as bigint) : 0n

  const amountToReceive = totalShares > 0n && shares ? (shares * totalLiquidity) / totalShares : 0n

  return {
    amountToReceive,
    isLoading,
  }
}

"use client"

import { useReadContract } from "wagmi"
import { useContracts } from "./useContracts"
import { useCurrentRound, useCurrentSeason, useRound } from "./useGameData"
import { usePoolStats } from "./useBettingData"

export function useAdminStats() {
  const { gameEngine } = useContracts()
  const { currentRoundId } = useCurrentRound()
  const { currentSeasonId } = useCurrentSeason()
  const { round } = useRound(currentRoundId)
  const { totalPool, seasonPool } = usePoolStats()

  // Get round duration
  const { data: roundDuration } = useReadContract({
    address: gameEngine?.address,
    abi: gameEngine?.abi,
    functionName: "ROUND_DURATION",
    query: {
      enabled: !!gameEngine?.address,
    },
  })

  // Get rounds per season
  const { data: roundsPerSeason } = useReadContract({
    address: gameEngine?.address,
    abi: gameEngine?.abi,
    functionName: "ROUNDS_PER_SEASON",
    query: {
      enabled: !!gameEngine?.address,
    },
  })

  // Calculate time remaining for current round
  const calculateTimeRemaining = () => {
    if (!round?.startTime || !roundDuration) return null

    const startTime = Number(round.startTime)
    const duration = Number(roundDuration)
    const endTime = startTime + duration
    const now = Math.floor(Date.now() / 1000)
    const remaining = Math.max(0, endTime - now)

    return {
      remaining,
      elapsed: now - startTime,
      endTime,
      canSettle: remaining === 0 && !round.settled,
    }
  }

  // Get season info
  const { data: seasonData } = useReadContract({
    address: gameEngine?.address,
    abi: gameEngine?.abi,
    functionName: "getSeason",
    args: currentSeasonId !== undefined ? [currentSeasonId] : undefined,
    query: {
      enabled: !!gameEngine?.address && currentSeasonId !== undefined,
      refetchInterval: 5000,
    },
  })

  const season = seasonData as {
    seasonId: bigint
    startTime: bigint
    currentRound: bigint
    active: boolean
    completed: boolean
    winningTeamId: bigint
  } | undefined

  // Check if round is settled
  const { data: isRoundSettled } = useReadContract({
    address: gameEngine?.address,
    abi: gameEngine?.abi,
    functionName: "isRoundSettled",
    args: currentRoundId !== undefined ? [currentRoundId] : undefined,
    query: {
      enabled: !!gameEngine?.address && currentRoundId !== undefined,
      refetchInterval: 5000,
    },
  })

  // Get VRF request time
  const { data: vrfRequestTime } = useReadContract({
    address: gameEngine?.address,
    abi: gameEngine?.abi,
    functionName: "roundVRFRequestTime",
    args: currentRoundId !== undefined ? [currentRoundId] : undefined,
    query: {
      enabled: !!gameEngine?.address && currentRoundId !== undefined,
      refetchInterval: 5000,
    },
  })

  const timeRemaining = calculateTimeRemaining()

  return {
    currentRoundId,
    currentSeasonId,
    round,
    season,
    roundDuration: roundDuration as bigint | undefined,
    roundsPerSeason: roundsPerSeason as bigint | undefined,
    isRoundSettled: isRoundSettled as boolean | undefined,
    vrfRequestTime: vrfRequestTime as bigint | undefined,
    timeRemaining,
    totalPool,
    seasonPool,
  }
}

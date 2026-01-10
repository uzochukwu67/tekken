"use client"

import { useReadContract, useReadContracts } from "wagmi"
import { useContracts } from "./useContracts"
import type { Address } from "viem"

export type Team = {
  name: string
  wins: bigint
  draws: bigint
  losses: bigint
  points: bigint
  goalsFor: bigint
  goalsAgainst: bigint
}

export type Match = {
  homeTeamId: bigint
  awayTeamId: bigint
  homeScore: number
  awayScore: number
  outcome: number
  settled: boolean
  homeOdds: bigint
  awayOdds: bigint
  drawOdds: bigint
}

export type Round = {
  id: bigint
  seasonId: bigint
  startTime: bigint
  bettingDeadline: bigint
  settled: boolean
  vrfRequestId: bigint
  matches: Match[]
}

export function useCurrentRound() {
  const { gameEngine } = useContracts()

  const { data: currentRoundId, refetch } = useReadContract({
    address: gameEngine?.address,
    abi: gameEngine?.abi,
    functionName: "getCurrentRound",
    query: {
      enabled: !!gameEngine?.address,
      refetchInterval: 5000, // Refetch every 5 seconds
    },
  })

  return { currentRoundId: currentRoundId as bigint | undefined, refetch }
}

export function useRound(roundId: bigint | undefined) {
  const { gameEngine } = useContracts()

  const { data, isLoading, refetch } = useReadContract({
    address: gameEngine?.address,
    abi: gameEngine?.abi,
    functionName: "getRound",
    args: roundId !== undefined ? [roundId] : undefined,
    query: {
      enabled: !!gameEngine?.address && roundId !== undefined,
      refetchInterval: 10000,
    },
  })

  return {
    round: data as Round | undefined,
    isLoading,
    refetch,
  }
}

export function useMatch(roundId: bigint | undefined, matchIndex: bigint | undefined) {
  const { gameEngine } = useContracts()

  const { data, isLoading } = useReadContract({
    address: gameEngine?.address,
    abi: gameEngine?.abi,
    functionName: "getMatch",
    args: roundId !== undefined && matchIndex !== undefined ? [roundId, matchIndex] : undefined,
    query: {
      enabled: !!gameEngine?.address && roundId !== undefined && matchIndex !== undefined,
      refetchInterval: 10000,
    },
  })

  return {
    match: data as Match | undefined,
    isLoading,
  }
}

export function useRoundMatches(roundId: bigint | undefined) {
  const { gameEngine } = useContracts()

  const { data, isLoading, refetch } = useReadContract({
    address: gameEngine?.address,
    abi: gameEngine?.abi,
    functionName: "getRoundMatches",
    args: roundId !== undefined ? [roundId] : undefined,
    query: {
      enabled: !!gameEngine?.address && roundId !== undefined,
      refetchInterval: 10000,
    },
  })

  return {
    matches: data as Match[] | undefined,
    isLoading,
    refetch,
  }
}

export function useTeam(teamId: bigint | undefined) {
  const { gameEngine } = useContracts()

  const { data, isLoading } = useReadContract({
    address: gameEngine?.address,
    abi: gameEngine?.abi,
    functionName: "getTeam",
    args: teamId !== undefined ? [teamId] : undefined,
    query: {
      enabled: !!gameEngine?.address && teamId !== undefined,
    },
  })

  return {
    team: data as Team | undefined,
    isLoading,
  }
}

export function useAllTeams() {
  const { gameEngine } = useContracts()

  // Read all 20 teams in parallel
  const contracts = Array.from({ length: 20 }, (_, i) => ({
    address: gameEngine?.address,
    abi: gameEngine?.abi,
    functionName: "getTeam" as const,
    args: [BigInt(i)],
  }))

  const { data, isLoading } = useReadContracts({
    contracts,
    query: {
      enabled: !!gameEngine?.address,
    },
  })

  const teams = data?.map((result) => {
    if (result.status === "success") {
      return result.result as Team
    }
    return null
  }).filter(Boolean) as Team[]

  return {
    teams,
    isLoading,
  }
}

export function useSeasonStandings(seasonId: bigint | undefined) {
  const { gameEngine } = useContracts()

  // Read standings for all 20 teams
  const contracts = Array.from({ length: 20 }, (_, i) => ({
    address: gameEngine?.address,
    abi: gameEngine?.abi,
    functionName: "seasonStandings" as const,
    args: seasonId !== undefined ? [seasonId, BigInt(i)] : undefined,
  }))

  const { data, isLoading } = useReadContracts({
    contracts,
    query: {
      enabled: !!gameEngine?.address && seasonId !== undefined,
    },
  })

  type StandingData = {
    teamId: bigint
    wins: number
    draws: number
    losses: number
    goalsFor: number
    goalsAgainst: number
    points: number
  }

  const standings = data
    ?.map((result, index) => {
      if (result.status === "success") {
        const standing = result.result as StandingData
        return {
          teamId: BigInt(index),
          ...standing,
          played: standing.wins + standing.draws + standing.losses,
          goalDifference: standing.goalsFor - standing.goalsAgainst,
        }
      }
      return null
    })
    .filter(Boolean)
    .sort((a, b) => {
      // Sort by points, then goal difference, then goals for
      if (b!.points !== a!.points) return b!.points - a!.points
      if (b!.goalDifference !== a!.goalDifference) return b!.goalDifference - a!.goalDifference
      return b!.goalsFor - a!.goalsFor
    })

  return {
    standings,
    isLoading,
  }
}

export function useCurrentSeason() {
  const { gameEngine } = useContracts()

  const { data: currentSeasonId } = useReadContract({
    address: gameEngine?.address,
    abi: gameEngine?.abi,
    functionName: "getCurrentSeason",
    query: {
      enabled: !!gameEngine?.address,
    },
  })

  return { currentSeasonId: currentSeasonId as bigint | undefined }
}

// Derived round/season utilities
export function useRoundStatus(roundId: bigint | undefined) {
  const { gameEngine } = useContracts()

  const { data: roundData, isLoading: loadingRound } = useReadContract({
    address: gameEngine?.address,
    abi: gameEngine?.abi,
    functionName: "getRound",
    args: roundId !== undefined ? [roundId] : undefined,
    query: {
      enabled: !!gameEngine?.address && roundId !== undefined,
      refetchInterval: 5000,
    },
  })

  const { data: roundDurationData } = useReadContract({
    address: gameEngine?.address,
    abi: gameEngine?.abi,
    functionName: "ROUND_DURATION",
    query: {
      enabled: !!gameEngine?.address,
    },
  })

  const round = roundData as any | undefined

  const ROUND_DURATION = (roundDurationData as bigint) || 0n
  const now = BigInt(Math.floor(Date.now() / 1000))

  const startTime: bigint | undefined = round?.startTime
  const settled: boolean = round?.settled ?? false

  let elapsed: bigint | undefined
  let remaining: bigint | undefined
  let isOngoing = false

  if (startTime && startTime > 0n) {
    elapsed = now > startTime ? now - startTime : 0n
    if (ROUND_DURATION > 0n) {
      remaining = elapsed >= ROUND_DURATION ? 0n : ROUND_DURATION - elapsed
    }
    if (ROUND_DURATION === 0n) {
      isOngoing = !settled && now >= startTime
    } else {
      isOngoing = !settled && now >= startTime && now < startTime + ROUND_DURATION
    }
  }

  return {
    round,
    startTime,
    settled,
    elapsed,
    remaining,
    isOngoing,
    isLoading: loadingRound,
  }
}

export function useIsCurrentRoundOngoing() {
  const { currentRoundId } = useCurrentRound()
  return useRoundStatus(currentRoundId as unknown as bigint | undefined)
}

export function useSeasonInfo(seasonId: bigint | undefined) {
  const { gameEngine } = useContracts()

  const { data: seasonData, isLoading } = useReadContract({
    address: gameEngine?.address,
    abi: gameEngine?.abi,
    functionName: "getSeason",
    args: seasonId !== undefined ? [seasonId] : undefined,
    query: {
      enabled: !!gameEngine?.address && seasonId !== undefined,
      refetchInterval: 5000,
    },
  })

  return { season: seasonData as any | undefined, isLoading }
}

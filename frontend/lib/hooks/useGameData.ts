"use client"

import { useReadContract, useReadContracts } from "wagmi"
import { useContracts } from "./useContracts"
import type { Address } from "viem"

export type Team = {
  id: bigint
  name: string
  attack: number
  defense: number
  rating: number
}

export type Match = {
  homeTeam: bigint
  awayTeam: bigint
  homeScore: number
  awayScore: number
  outcome: number
  settled: boolean
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
    functionName: "currentRoundId",
    query: {
      enabled: !!gameEngine?.address,
      refetchInterval: 5000, // Refetch every 5 seconds
    },
  })

  return { currentRoundId, refetch }
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

export function useTeam(teamId: bigint | undefined) {
  const { gameEngine } = useContracts()

  const { data, isLoading } = useReadContract({
    address: gameEngine?.address,
    abi: gameEngine?.abi,
    functionName: "teams",
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
    functionName: "teams" as const,
    args: [BigInt(i)],
  }))

  const { data, isLoading } = useReadContracts({
    contracts,
    query: {
      enabled: !!gameEngine?.address,
    },
  })

  const teams = data?.map((result, index) => {
    if (result.status === "success") {
      return {
        id: BigInt(index),
        ...(result.result as Omit<Team, "id">),
      }
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
    functionName: "currentSeasonId",
    query: {
      enabled: !!gameEngine?.address,
    },
  })

  return { currentSeasonId }
}

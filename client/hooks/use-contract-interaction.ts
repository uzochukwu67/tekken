"use client"

import { useAccount } from "wagmi"
import { useState, useEffect } from "react"
import type { Match } from "@/lib/contract-utils"

export function useGetMatches() {
  const { address } = useAccount()
  const [matches, setMatches] = useState<Match[]>([])
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    if (!address) {
      setMatches([])
      setIsLoading(false)
      return
    }

    // Simulate loading delay
    const timer = setTimeout(() => {
      const now = Math.floor(Date.now() / 1000)

      // Mock Premier League matches for current week
      const mockMatches: Match[] = [
        {
          id: 1,
          homeTeam: "Manchester United",
          awayTeam: "Liverpool",
          scheduledTime: now + 86400,
          homeOdds: 2.1,
          drawOdds: 3.4,
          awayOdds: 3.2,
          status: "upcoming",
        },
        {
          id: 2,
          homeTeam: "Arsenal",
          awayTeam: "Chelsea",
          scheduledTime: now + 172800,
          homeOdds: 1.95,
          drawOdds: 3.5,
          awayOdds: 3.5,
          status: "upcoming",
        },
        {
          id: 3,
          homeTeam: "Manchester City",
          awayTeam: "Tottenham",
          scheduledTime: now + 259200,
          homeOdds: 1.85,
          drawOdds: 3.6,
          awayOdds: 3.8,
          status: "upcoming",
        },
        {
          id: 4,
          homeTeam: "Brighton",
          awayTeam: "Newcastle",
          scheduledTime: now + 345600,
          homeOdds: 2.3,
          drawOdds: 3.3,
          awayOdds: 2.9,
          status: "upcoming",
        },
        {
          id: 5,
          homeTeam: "Aston Villa",
          awayTeam: "Everton",
          scheduledTime: now + 432000,
          homeOdds: 2.05,
          drawOdds: 3.4,
          awayOdds: 3.4,
          status: "upcoming",
        },
        {
          id: 6,
          homeTeam: "Fulham",
          awayTeam: "Bournemouth",
          scheduledTime: now + 518400,
          homeOdds: 2.15,
          drawOdds: 3.35,
          awayOdds: 3.3,
          status: "upcoming",
        },
      ]

      setMatches(mockMatches)
      setIsLoading(false)
    }, 500)

    return () => clearTimeout(timer)
  }, [address])

  return { matches, isLoading, error: null }
}

export function useGetUserBets() {
  const { address } = useAccount()
  const [bets, setBets] = useState([])
  const [isLoading, setIsLoading] = useState(false)

  useEffect(() => {
    if (!address) {
      setBets([])
      return
    }

    setIsLoading(true)
    setTimeout(() => {
      setBets([])
      setIsLoading(false)
    }, 500)
  }, [address])

  return { bets, isLoading, error: null }
}

export function useGetUserBalance() {
  const { address } = useAccount()
  const [balance, setBalance] = useState<string>("0")
  const [isLoading, setIsLoading] = useState(false)

  useEffect(() => {
    if (!address) {
      setBalance("0")
      return
    }

    setIsLoading(true)
    setTimeout(() => {
      setBalance("0")
      setIsLoading(false)
    }, 300)
  }, [address])

  return { balance, isLoading }
}

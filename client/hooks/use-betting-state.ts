"use client"

import { useState, useCallback } from "react"

export interface Bet {
  id: string
  matchId: string
  matchName: string
  prediction: "home" | "draw" | "away"
  predictionLabel: string
  odds: number
  amount: number
  potential: number
  timestamp: number
}

export interface BettingSlip {
  bets: Bet[]
  totalOdds: number
  totalStake: number
  totalPotential: number
}

export function useBettingState() {
  const [slip, setSlip] = useState<BettingSlip>({
    bets: [],
    totalOdds: 1,
    totalStake: 0,
    totalPotential: 0,
  })

  const addBet = useCallback((bet: Bet) => {
    setSlip((prev) => {
      const newBets = [...prev.bets]
      const existingIndex = newBets.findIndex((b) => b.matchId === bet.matchId)

      if (existingIndex >= 0) {
        newBets[existingIndex] = bet
      } else {
        newBets.push(bet)
      }

      const totalOdds = newBets.reduce((acc, b) => acc * b.odds, 1)
      const totalPotential = bet.amount * totalOdds

      return {
        bets: newBets,
        totalOdds,
        totalStake: bet.amount,
        totalPotential,
      }
    })
  }, [])

  const removeBet = useCallback((matchId: string) => {
    setSlip((prev) => {
      const newBets = prev.bets.filter((b) => b.matchId !== matchId)
      const totalOdds = newBets.reduce((acc, b) => acc * b.odds, 1)
      const totalStake = newBets.length > 0 ? newBets[0].amount : 0
      const totalPotential = totalStake * totalOdds

      return {
        bets: newBets,
        totalOdds: newBets.length === 0 ? 1 : totalOdds,
        totalStake,
        totalPotential,
      }
    })
  }, [])

  const clearSlip = useCallback(() => {
    setSlip({
      bets: [],
      totalOdds: 1,
      totalStake: 0,
      totalPotential: 0,
    })
  }, [])

  return {
    slip,
    addBet,
    removeBet,
    clearSlip,
  }
}

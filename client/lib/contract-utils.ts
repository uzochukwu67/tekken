import type { Address } from "viem"

export interface Match {
  id: number
  homeTeam: string
  awayTeam: string
  scheduledTime: number
  homeOdds: number
  drawOdds: number
  awayOdds: number
  status: "upcoming" | "live" | "completed"
}

export interface BettingResult {
  matchId: number
  winner: "home" | "draw" | "away"
  winnerAddress?: Address
}

// Mock ABI for the betting contract
export const BETTING_CONTRACT_ABI = [
  {
    name: "placeBet",
    type: "function",
    inputs: [
      { name: "matchId", type: "uint256" },
      { name: "prediction", type: "uint8" }, // 0: home, 1: draw, 2: away
      { name: "amount", type: "uint256" },
    ],
    outputs: [{ name: "betId", type: "uint256" }],
    stateMutability: "payable",
  },
  {
    name: "getMatches",
    type: "function",
    inputs: [],
    outputs: [
      {
        type: "tuple[]",
        components: [
          { name: "id", type: "uint256" },
          { name: "homeTeam", type: "string" },
          { name: "awayTeam", type: "string" },
          { name: "scheduledTime", type: "uint256" },
          { name: "homeOdds", type: "uint256" },
          { name: "drawOdds", type: "uint256" },
          { name: "awayOdds", type: "uint256" },
        ],
      },
    ],
    stateMutability: "view",
  },
] as const

// Format odds for display
export function formatOdds(odds: number): string {
  return odds.toFixed(2)
}

// Calculate potential winnings
export function calculatePotential(stake: number, odds: number): number {
  return stake * odds
}

// Get prediction label from prediction type
export function getPredictionLabel(prediction: "home" | "draw" | "away"): string {
  const labels = {
    home: "Home Win",
    draw: "Draw",
    away: "Away Win",
  }
  return labels[prediction]
}

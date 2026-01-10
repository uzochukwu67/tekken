export enum PredictionType {
  HomeWin = 0,
  Draw = 1,
  AwayWin = 2,
}

export enum BetStatus {
  Pending = "pending",
  Won = "won",
  Lost = "lost",
  Cancelled = "cancelled",
}

export interface PlacedBet {
  id: string
  matchId: number
  bettor: string
  prediction: PredictionType
  amount: bigint
  potentialWinning: bigint
  odds: number
  timestamp: number
  status: BetStatus
  transactionHash?: string
}

export interface MatchResult {
  matchId: number
  vrfRequestId: bigint
  randomness: bigint
  winner: PredictionType
  timestamp: number
}

export function predictionToString(prediction: PredictionType): string {
  const labels = {
    [PredictionType.HomeWin]: "Home Win",
    [PredictionType.Draw]: "Draw",
    [PredictionType.AwayWin]: "Away Win",
  }
  return labels[prediction]
}

export function calculatePotentialWinning(stake: bigint, odds: number): bigint {
  return BigInt(Math.floor(Number(stake) * odds))
}

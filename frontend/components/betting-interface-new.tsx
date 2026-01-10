"use client"

import { useState, useEffect } from "react"
import { Card, CardContent } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Badge } from "@/components/ui/badge"
import { ArrowUpRight, ArrowDownRight, Minus, Trash2, Loader2 } from "lucide-react"
import { Separator } from "@/components/ui/separator"
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from "wagmi"
import { useContracts } from "@/lib/hooks/useContracts"
import { useCurrentRound, useRoundMatches, useTeam, type Match } from "@/lib/hooks/useGameData"
import { useCalculatePotentialPayout } from "@/lib/hooks/useBettingData"
import { formatUnits, parseUnits } from "viem"
import { toast } from "sonner"

interface Prediction {
  matchIndex: bigint
  homeTeam: string
  awayTeam: string
  outcome: number
  odds: bigint
}

export function BettingInterfaceNew() {
  const { address, isConnected } = useAccount()
  const { gameEngine, bettingPool, leagueToken } = useContracts()
  const { currentRoundId } = useCurrentRound()
  const { matches, isLoading: matchesLoading } = useRoundMatches(currentRoundId)

  const [predictions, setPredictions] = useState<Prediction[]>([])
  const [betAmount, setBetAmount] = useState("")
  const [needsApproval, setNeedsApproval] = useState(true)

  const { writeContract: approve, data: approveHash } = useWriteContract()
  const { writeContract: placeBet, data: placeBetHash } = useWriteContract()

  const { isLoading: isApproving } = useWaitForTransactionReceipt({
    hash: approveHash,
  })

  const { isLoading: isPlacingBet, isSuccess: betPlaced } = useWaitForTransactionReceipt({
    hash: placeBetHash,
  })

  // Calculate potential payout
  const predictionArgs = predictions.map((p) => ({
    matchIndex: p.matchIndex,
    outcome: p.outcome,
  }))

  const betAmountBigInt = betAmount ? parseUnits(betAmount, 18) : 0n

  const { potentialPayout, basePayout, poolBonus } = useCalculatePotentialPayout(
    currentRoundId,
    betAmountBigInt,
    predictionArgs
  )

  // Reset form after successful bet
  useEffect(() => {
    if (betPlaced) {
      setPredictions([])
      setBetAmount("")
      setNeedsApproval(true)
      toast.success("Bet placed successfully!")
    }
  }, [betPlaced])

  const addPrediction = (matchIndex: bigint, homeTeam: string, awayTeam: string, outcome: number, odds: bigint) => {
    // Check if already predicted this match
    const existingIndex = predictions.findIndex((p) => p.matchIndex === matchIndex)
    if (existingIndex >= 0) {
      // Update existing prediction
      const updated = [...predictions]
      updated[existingIndex] = { matchIndex, homeTeam, awayTeam, outcome, odds }
      setPredictions(updated)
      toast.info("Prediction updated")
    } else {
      setPredictions([...predictions, { matchIndex, homeTeam, awayTeam, outcome, odds }])
      toast.success("Prediction added")
    }
  }

  const removePrediction = (index: number) => {
    setPredictions(predictions.filter((_, i) => i !== index))
  }

  const handleApprove = async () => {
    if (!leagueToken?.address || !bettingPool?.address || !betAmountBigInt) return

    try {
      approve({
        address: leagueToken.address,
        abi: leagueToken.abi,
        functionName: "approve",
        args: [bettingPool.address, betAmountBigInt],
      })
      setNeedsApproval(false)
      toast.success("Approval transaction sent")
    } catch (error: any) {
      toast.error(error?.message || "Approval failed")
    }
  }

  const handlePlaceBet = async () => {
    if (!bettingPool?.address || !currentRoundId || predictions.length === 0 || !betAmountBigInt) return

    try {
      const predArgs = predictions.map((p) => [p.matchIndex, p.outcome])

      placeBet({
        address: bettingPool.address,
        abi: bettingPool.abi,
        functionName: "placeBet",
        args: [currentRoundId, betAmountBigInt, predArgs],
      })
      toast.success("Placing bet...")
    } catch (error: any) {
      toast.error(error?.message || "Failed to place bet")
    }
  }

  const MAX_BET = 100000

  return (
    <div className="grid lg:grid-cols-3 gap-6">
      {/* Matches List */}
      <div className="lg:col-span-2 space-y-4">
        <div>
          <h3 className="text-2xl font-bold mb-2">
            Round {currentRoundId?.toString() || "..."} Matches
          </h3>
          <p className="text-sm text-muted-foreground">Select your predictions for this round</p>
        </div>

        <div className="space-y-3">
          {matchesLoading ? (
            Array.from({ length: 10 }, (_, i) => (
              <Card key={i} className="bg-card/50 backdrop-blur border-border/40">
                <CardContent className="p-4">
                  <div className="flex items-center justify-center h-20">
                    <Loader2 className="w-6 h-6 animate-spin text-muted-foreground" />
                  </div>
                </CardContent>
              </Card>
            ))
          ) : matches && matches.length > 0 ? (
            matches.map((match, i) => (
              <MatchCard
                key={i}
                match={match}
                matchIndex={BigInt(i)}
                onAddPrediction={addPrediction}
                isConnected={isConnected}
              />
            ))
          ) : (
            <Card className="bg-card/50 backdrop-blur border-border/40">
              <CardContent className="p-6 text-center text-muted-foreground">
                No matches available for this round
              </CardContent>
            </Card>
          )}
        </div>
      </div>

      {/* Bet Slip */}
      <div className="lg:sticky lg:top-24 h-fit">
        <Card className="bg-gradient-to-br from-card to-card/50 backdrop-blur border-border/40">
          <div className="p-6 space-y-4">
            <div>
              <h3 className="text-xl font-bold">Bet Slip</h3>
              <p className="text-sm text-muted-foreground">
                {predictions.length} prediction{predictions.length !== 1 ? "s" : ""} selected
              </p>
            </div>

            {/* Predictions List */}
            {predictions.length > 0 ? (
              <div className="space-y-2 max-h-60 overflow-y-auto">
                {predictions.map((pred, idx) => (
                  <div key={idx} className="flex items-start justify-between p-2 bg-secondary/50 rounded-lg">
                    <div className="flex-1">
                      <p className="text-sm font-medium">
                        {pred.homeTeam} vs {pred.awayTeam}
                      </p>
                      <div className="flex items-center gap-2 mt-1">
                        <Badge variant="outline" className="text-xs">
                          {pred.outcome === 0 ? "HOME" : pred.outcome === 1 ? "AWAY" : "DRAW"}
                        </Badge>
                        <span className="text-xs text-muted-foreground">
                          {(Number(pred.odds) / 100).toFixed(2)}x
                        </span>
                      </div>
                    </div>
                    <Button variant="ghost" size="sm" className="h-8 w-8 p-0" onClick={() => removePrediction(idx)}>
                      <Trash2 className="w-4 h-4" />
                    </Button>
                  </div>
                ))}
              </div>
            ) : (
              <div className="text-center py-8 text-muted-foreground text-sm">
                Select predictions to build your bet
              </div>
            )}

            {predictions.length > 0 && (
              <>
                <Separator />

                {/* Bet Amount */}
                <div className="space-y-2">
                  <label className="text-sm font-medium">Bet Amount (LEAGUE)</label>
                  <Input
                    type="number"
                    placeholder="0.00"
                    value={betAmount}
                    onChange={(e) => setBetAmount(e.target.value)}
                    disabled={!isConnected}
                    max={MAX_BET}
                  />
                  <p className="text-xs text-muted-foreground">Min: 0.01 | Max: {MAX_BET.toLocaleString()}</p>
                </div>

                {/* Payout Calculation */}
                {potentialPayout && basePayout && poolBonus && (
                  <div className="space-y-2 p-3 bg-secondary/50 rounded-lg">
                    <div className="flex justify-between text-sm">
                      <span className="text-muted-foreground">Base Payout (Odds):</span>
                      <span className="font-bold">{Number(formatUnits(basePayout, 18)).toFixed(2)} LEAGUE</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-muted-foreground">Pool Bonus:</span>
                      <span className="font-bold text-green-500">
                        +{Number(formatUnits(poolBonus, 18)).toFixed(2)} LEAGUE
                      </span>
                    </div>
                    <Separator />
                    <div className="flex justify-between text-sm">
                      <span className="text-muted-foreground">Total Payout:</span>
                      <span className="font-bold text-lg">
                        {Number(formatUnits(potentialPayout, 18)).toFixed(2)} LEAGUE
                      </span>
                    </div>
                  </div>
                )}

                {/* Action Buttons */}
                {isConnected ? (
                  <div className="space-y-2">
                    {needsApproval && (
                      <Button
                        className="w-full"
                        size="lg"
                        onClick={handleApprove}
                        disabled={!betAmount || Number(betAmount) <= 0 || isApproving}
                      >
                        {isApproving && <Loader2 className="w-4 h-4 mr-2 animate-spin" />}
                        {isApproving ? "Approving..." : "Approve LEAGUE"}
                      </Button>
                    )}
                    <Button
                      className="w-full"
                      size="lg"
                      onClick={handlePlaceBet}
                      disabled={
                        needsApproval ||
                        !betAmount ||
                        Number(betAmount) <= 0 ||
                        Number(betAmount) > MAX_BET ||
                        isPlacingBet
                      }
                    >
                      {isPlacingBet && <Loader2 className="w-4 h-4 mr-2 animate-spin" />}
                      {isPlacingBet ? "Placing Bet..." : "Place Bet"}
                    </Button>
                  </div>
                ) : (
                  <Button className="w-full" size="lg" disabled>
                    Connect Wallet to Bet
                  </Button>
                )}
              </>
            )}
          </div>
        </Card>
      </div>
    </div>
  )
}

// Match Card Component
function MatchCard({
  match,
  matchIndex,
  onAddPrediction,
  isConnected,
}: {
  match: Match
  matchIndex: bigint
  onAddPrediction: (matchIndex: bigint, homeTeam: string, awayTeam: string, outcome: number, odds: bigint) => void
  isConnected: boolean
}) {
  const { team: homeTeam, isLoading: homeTeamLoading } = useTeam(match.homeTeamId)
  const { team: awayTeam, isLoading: awayTeamLoading } = useTeam(match.awayTeamId)

  // Odds are included in the match struct from contract
  const homeOdds = match.homeOdds
  const awayOdds = match.awayOdds
  const drawOdds = match.drawOdds

  if (homeTeamLoading || awayTeamLoading || !homeTeam || !awayTeam) {
    return (
      <Card className="bg-card/50 backdrop-blur border-border/40">
        <CardContent className="p-4">
          <div className="flex items-center justify-center h-20">
            <Loader2 className="w-6 h-6 animate-spin text-muted-foreground" />
          </div>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card className="bg-card/50 backdrop-blur border-border/40">
      <CardContent className="p-4">
        <div className="flex items-center justify-between mb-3">
          <Badge variant="outline" className="text-xs">
            Match {(matchIndex + 1n).toString()}
          </Badge>
        </div>

        <div className="grid grid-cols-3 gap-2">
          {/* Home Win */}
          <Button
            variant="outline"
            className="h-auto flex-col py-3 hover:bg-primary hover:text-primary-foreground bg-transparent"
            onClick={() =>
              homeOdds && onAddPrediction(matchIndex, homeTeam.name, awayTeam.name, 0, homeOdds)
            }
            disabled={!isConnected || !homeOdds}
          >
            <span className="text-xs font-medium mb-1 truncate w-full text-center">{homeTeam.name}</span>
            <div className="flex items-center gap-1 text-lg font-bold">
              <ArrowUpRight className="w-4 h-4" />
              {homeOdds ? (Number(homeOdds) / 100).toFixed(2) : "..."}x
            </div>
          </Button>

          {/* Draw */}
          <Button
            variant="outline"
            className="h-auto flex-col py-3 hover:bg-accent hover:text-accent-foreground bg-transparent"
            onClick={() =>
              drawOdds && onAddPrediction(matchIndex, homeTeam.name, awayTeam.name, 2, drawOdds)
            }
            disabled={!isConnected || !drawOdds}
          >
            <span className="text-xs font-medium mb-1">Draw</span>
            <div className="flex items-center gap-1 text-lg font-bold">
              <Minus className="w-4 h-4" />
              {drawOdds ? (Number(drawOdds) / 100).toFixed(2) : "..."}x
            </div>
          </Button>

          {/* Away Win */}
          <Button
            variant="outline"
            className="h-auto flex-col py-3 hover:bg-primary hover:text-primary-foreground bg-transparent"
            onClick={() =>
              awayOdds && onAddPrediction(matchIndex, homeTeam.name, awayTeam.name, 1, awayOdds)
            }
            disabled={!isConnected || !awayOdds}
          >
            <span className="text-xs font-medium mb-1 truncate w-full text-center">{awayTeam.name}</span>
            <div className="flex items-center gap-1 text-lg font-bold">
              <ArrowDownRight className="w-4 h-4" />
              {awayOdds ? (Number(awayOdds) / 100).toFixed(2) : "..."}x
            </div>
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}

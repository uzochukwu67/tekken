"use client"

import { useState } from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Badge } from "@/components/ui/badge"
import { ArrowUpRight, ArrowDownRight, Minus, Trash2 } from "lucide-react"
import { Separator } from "@/components/ui/separator"

interface BettingInterfaceProps {
  isConnected: boolean
}

interface Prediction {
  matchIndex: number
  homeTeam: string
  awayTeam: string
  outcome: "HOME" | "AWAY" | "DRAW"
  odds: number
}

const MATCHES = [
  { index: 0, home: "Manchester City", away: "Liverpool", homeOdds: 1.85, awayOdds: 2.1, drawOdds: 3.2 },
  { index: 1, home: "Arsenal", away: "Chelsea", homeOdds: 2.05, awayOdds: 1.95, drawOdds: 3.4 },
  { index: 2, home: "Barcelona", away: "Real Madrid", homeOdds: 1.75, awayOdds: 2.3, drawOdds: 3.1 },
  { index: 3, home: "Bayern Munich", away: "Dortmund", homeOdds: 1.65, awayOdds: 2.5, drawOdds: 3.6 },
  { index: 4, home: "PSG", away: "Marseille", homeOdds: 1.55, awayOdds: 2.8, drawOdds: 3.8 },
  { index: 5, home: "Juventus", away: "Inter Milan", homeOdds: 1.95, awayOdds: 2.05, drawOdds: 3.3 },
  { index: 6, home: "Atletico Madrid", away: "Sevilla", homeOdds: 1.7, awayOdds: 2.4, drawOdds: 3.5 },
  { index: 7, home: "AC Milan", away: "Napoli", homeOdds: 2.15, awayOdds: 1.9, drawOdds: 3.25 },
  { index: 8, home: "Tottenham", away: "Newcastle", homeOdds: 1.8, awayOdds: 2.2, drawOdds: 3.35 },
  { index: 9, home: "Benfica", away: "Porto", homeOdds: 1.9, awayOdds: 2.1, drawOdds: 3.15 },
]

export function BettingInterface({ isConnected }: BettingInterfaceProps) {
  const [predictions, setPredictions] = useState<Prediction[]>([])
  const [betAmount, setBetAmount] = useState("")

  const addPrediction = (matchIndex: number, outcome: "HOME" | "AWAY" | "DRAW") => {
    const match = MATCHES[matchIndex]
    const odds = outcome === "HOME" ? match.homeOdds : outcome === "AWAY" ? match.awayOdds : match.drawOdds

    setPredictions([
      ...predictions,
      {
        matchIndex,
        homeTeam: match.home,
        awayTeam: match.away,
        outcome,
        odds,
      },
    ])
  }

  const removePrediction = (index: number) => {
    setPredictions(predictions.filter((_, i) => i !== index))
  }

  const totalOdds = predictions.reduce((acc, pred) => acc * pred.odds, 1)
  const potentialPayout = betAmount ? (Number.parseFloat(betAmount) * totalOdds).toFixed(2) : "0.00"

  return (
    <div className="grid lg:grid-cols-3 gap-6">
      {/* Matches List */}
      <div className="lg:col-span-2 space-y-4">
        <div>
          <h3 className="text-2xl font-bold mb-2">Current Round Matches</h3>
          <p className="text-sm text-muted-foreground">Select your predictions for this round</p>
        </div>

        <div className="space-y-3">
          {MATCHES.map((match) => (
            <Card key={match.index} className="bg-card/50 backdrop-blur border-border/40">
              <CardContent className="p-4">
                <div className="flex items-center justify-between mb-3">
                  <Badge variant="outline" className="text-xs">
                    Match {match.index + 1}
                  </Badge>
                </div>

                <div className="grid grid-cols-3 gap-2">
                  {/* Home Win */}
                  <Button
                    variant="outline"
                    className="h-auto flex-col py-3 hover:bg-primary hover:text-primary-foreground bg-transparent"
                    onClick={() => addPrediction(match.index, "HOME")}
                    disabled={!isConnected}
                  >
                    <span className="text-xs font-medium mb-1">{match.home}</span>
                    <div className="flex items-center gap-1 text-lg font-bold">
                      <ArrowUpRight className="w-4 h-4" />
                      {match.homeOdds}x
                    </div>
                  </Button>

                  {/* Draw */}
                  <Button
                    variant="outline"
                    className="h-auto flex-col py-3 hover:bg-accent hover:text-accent-foreground bg-transparent"
                    onClick={() => addPrediction(match.index, "DRAW")}
                    disabled={!isConnected}
                  >
                    <span className="text-xs font-medium mb-1">Draw</span>
                    <div className="flex items-center gap-1 text-lg font-bold">
                      <Minus className="w-4 h-4" />
                      {match.drawOdds}x
                    </div>
                  </Button>

                  {/* Away Win */}
                  <Button
                    variant="outline"
                    className="h-auto flex-col py-3 hover:bg-primary hover:text-primary-foreground bg-transparent"
                    onClick={() => addPrediction(match.index, "AWAY")}
                    disabled={!isConnected}
                  >
                    <span className="text-xs font-medium mb-1">{match.away}</span>
                    <div className="flex items-center gap-1 text-lg font-bold">
                      <ArrowDownRight className="w-4 h-4" />
                      {match.awayOdds}x
                    </div>
                  </Button>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>

      {/* Bet Slip */}
      <div className="lg:sticky lg:top-24 h-fit">
        <Card className="bg-gradient-to-br from-card to-card/50 backdrop-blur border-border/40">
          <CardHeader>
            <CardTitle>Bet Slip</CardTitle>
            <CardDescription>
              {predictions.length} prediction{predictions.length !== 1 ? "s" : ""} selected
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
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
                          {pred.outcome}
                        </Badge>
                        <span className="text-xs text-muted-foreground">{pred.odds}x</span>
                      </div>
                    </div>
                    <Button variant="ghost" size="sm" className="h-8 w-8 p-0" onClick={() => removePrediction(idx)}>
                      <Trash2 className="w-4 h-4" />
                    </Button>
                  </div>
                ))}
              </div>
            ) : (
              <div className="text-center py-8 text-muted-foreground text-sm">Select predictions to build your bet</div>
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
                  />
                  <p className="text-xs text-muted-foreground">Min: 0.01 | Max: 100,000</p>
                </div>

                {/* Payout Calculation */}
                <div className="space-y-2 p-3 bg-secondary/50 rounded-lg">
                  <div className="flex justify-between text-sm">
                    <span className="text-muted-foreground">Total Odds:</span>
                    <span className="font-bold">{totalOdds.toFixed(2)}x</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-muted-foreground">Potential Payout:</span>
                    <span className="font-bold text-lg">{potentialPayout} LEAGUE</span>
                  </div>
                </div>

                {/* Place Bet Button */}
                <Button
                  className="w-full"
                  size="lg"
                  disabled={!isConnected || !betAmount || Number.parseFloat(betAmount) <= 0}
                >
                  {isConnected ? "Place Bet" : "Connect Wallet to Bet"}
                </Button>
              </>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}

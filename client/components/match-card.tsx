"use client"

import { useState } from "react"
import { Card } from "@/components/ui/card"
import type { Match } from "@/lib/contract-utils"

interface MatchCardProps {
  match: Match
  onSelectBet: (matchId: number, prediction: "home" | "draw" | "away", odds: number) => void
}

export function MatchCard({ match, onSelectBet }: MatchCardProps) {
  const [selectedBet, setSelectedBet] = useState<"home" | "draw" | "away" | null>(null)

  const handleBetSelect = (prediction: "home" | "draw" | "away") => {
    setSelectedBet(prediction)
    const odds = prediction === "home" ? match.homeOdds : prediction === "draw" ? match.drawOdds : match.awayOdds
    onSelectBet(match.id, prediction, odds)
  }

  const formatTime = (timestamp: number) => {
    const date = new Date(timestamp * 1000)
    return date.toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    })
  }

  const getStatusColor = (status: string) => {
    if (status === "upcoming") return "bg-blue-50 text-blue-900 border-blue-200"
    if (status === "live") return "bg-red-50 text-red-900 border-red-200"
    return "bg-green-50 text-green-900 border-green-200"
  }

  const getStatusIcon = (status: string) => {
    if (status === "live") return "🔴 Live"
    if (status === "completed") return "✓ Completed"
    return "📅 Upcoming"
  }

  return (
    <Card className="overflow-hidden border border-border hover:shadow-md transition-shadow">
      {/* Header with match status */}
      <div className="border-b border-border bg-yellow-50/50 px-6 py-3">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="font-semibold text-foreground">Premier League</h3>
            <p className="text-xs text-muted-foreground mt-1">{formatTime(match.scheduledTime)}</p>
          </div>
          <span className={`rounded-full px-3 py-1 text-xs font-semibold border ${getStatusColor(match.status)}`}>
            {getStatusIcon(match.status)}
          </span>
        </div>
      </div>

      {/* Match teams */}
      <div className="px-6 py-6">
        <div className="flex items-center justify-between gap-4">
          {/* Home Team */}
          <div className="flex-1 text-center">
            <p className="font-bold text-foreground text-lg">{match.homeTeam}</p>
          </div>

          {/* VS */}
          <div className="text-sm font-semibold text-muted-foreground">VS</div>

          {/* Away Team */}
          <div className="flex-1 text-center">
            <p className="font-bold text-foreground text-lg">{match.awayTeam}</p>
          </div>
        </div>
      </div>

      {/* Betting Options */}
      <div className="border-t border-border bg-white px-6 py-4">
        <div className="grid gap-3 grid-cols-3">
          {/* Home Win */}
          <button
            onClick={() => handleBetSelect("home")}
            disabled={match.status === "completed"}
            className={`rounded-lg border-2 p-3 text-center transition-all disabled:opacity-50 disabled:cursor-not-allowed ${
              selectedBet === "home" ? "border-primary bg-primary/10" : "border-border bg-white hover:border-primary/50"
            }`}
          >
            <p className="text-xs text-muted-foreground">Home Win</p>
            <p className="mt-1 font-bold text-primary text-lg">{match.homeOdds.toFixed(2)}</p>
          </button>

          {/* Draw */}
          <button
            onClick={() => handleBetSelect("draw")}
            disabled={match.status === "completed"}
            className={`rounded-lg border-2 p-3 text-center transition-all disabled:opacity-50 disabled:cursor-not-allowed ${
              selectedBet === "draw" ? "border-primary bg-primary/10" : "border-border bg-white hover:border-primary/50"
            }`}
          >
            <p className="text-xs text-muted-foreground">Draw</p>
            <p className="mt-1 font-bold text-primary text-lg">{match.drawOdds.toFixed(2)}</p>
          </button>

          {/* Away Win */}
          <button
            onClick={() => handleBetSelect("away")}
            disabled={match.status === "completed"}
            className={`rounded-lg border-2 p-3 text-center transition-all disabled:opacity-50 disabled:cursor-not-allowed ${
              selectedBet === "away" ? "border-primary bg-primary/10" : "border-border bg-white hover:border-primary/50"
            }`}
          >
            <p className="text-xs text-muted-foreground">Away Win</p>
            <p className="mt-1 font-bold text-primary text-lg">{match.awayOdds.toFixed(2)}</p>
          </button>
        </div>
      </div>
    </Card>
  )
}

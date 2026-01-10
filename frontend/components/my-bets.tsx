"use client"

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Trophy, XCircle, Clock } from "lucide-react"

interface MyBetsProps {
  isConnected: boolean
}

const SAMPLE_BETS = [
  {
    id: "1",
    roundId: 4,
    amount: 1000,
    potentialPayout: 3420,
    predictions: 3,
    status: "won",
    timestamp: "2025-01-15 14:30",
  },
  {
    id: "2",
    roundId: 5,
    amount: 500,
    potentialPayout: 1850,
    predictions: 2,
    status: "pending",
    timestamp: "2025-01-15 15:45",
  },
  {
    id: "3",
    roundId: 3,
    amount: 2000,
    potentialPayout: 5600,
    predictions: 4,
    status: "lost",
    timestamp: "2025-01-14 18:20",
  },
]

export function MyBets({ isConnected }: MyBetsProps) {
  if (!isConnected) {
    return (
      <Card className="bg-card/50 backdrop-blur border-border/40">
        <CardContent className="py-20 text-center">
          <p className="text-muted-foreground">Connect your wallet to view your bets</p>
        </CardContent>
      </Card>
    )
  }

  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-2xl font-bold mb-2">My Betting History</h3>
        <p className="text-sm text-muted-foreground">Track your bets and claim winnings</p>
      </div>

      <div className="grid gap-4">
        {SAMPLE_BETS.map((bet) => (
          <Card key={bet.id} className="bg-card/50 backdrop-blur border-border/40">
            <CardHeader>
              <div className="flex items-start justify-between">
                <div>
                  <CardTitle className="text-lg">Bet #{bet.id}</CardTitle>
                  <CardDescription>
                    Round {bet.roundId} • {bet.timestamp}
                  </CardDescription>
                </div>
                <Badge
                  variant={bet.status === "won" ? "default" : bet.status === "lost" ? "destructive" : "secondary"}
                  className="flex items-center gap-1"
                >
                  {bet.status === "won" && <Trophy className="w-3 h-3" />}
                  {bet.status === "lost" && <XCircle className="w-3 h-3" />}
                  {bet.status === "pending" && <Clock className="w-3 h-3" />}
                  {bet.status.toUpperCase()}
                </Badge>
              </div>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-3 gap-4 mb-4">
                <div>
                  <p className="text-xs text-muted-foreground mb-1">Amount Wagered</p>
                  <p className="text-lg font-bold">{bet.amount.toLocaleString()} LEAGUE</p>
                </div>
                <div>
                  <p className="text-xs text-muted-foreground mb-1">Potential Payout</p>
                  <p className="text-lg font-bold">{bet.potentialPayout.toLocaleString()} LEAGUE</p>
                </div>
                <div>
                  <p className="text-xs text-muted-foreground mb-1">Predictions</p>
                  <p className="text-lg font-bold">{bet.predictions}</p>
                </div>
              </div>

              {bet.status === "won" && <Button className="w-full">Claim Winnings</Button>}
              {bet.status === "pending" && (
                <Button variant="outline" className="w-full bg-transparent" disabled>
                  Waiting for Settlement
                </Button>
              )}
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  )
}

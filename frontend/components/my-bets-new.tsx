"use client"

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Trophy, XCircle, Clock, Loader2, CheckCircle } from "lucide-react"
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from "wagmi"
import { useUserBets } from "@/lib/hooks/useBettingData"
import { useMatch, useTeam } from "@/lib/hooks/useGameData"
import { useContracts } from "@/lib/hooks/useContracts"
import { formatUnits } from "viem"
import { toast } from "sonner"
import { useState } from "react"

export function MyBetsNew() {
  const { address, isConnected } = useAccount()
  const { bets, isLoading } = useUserBets(address)
  const { bettingPool } = useContracts()

  const { writeContract: settleBet, data: settleHash } = useWriteContract()
  const { isLoading: isSettling, isSuccess: settled } = useWaitForTransactionReceipt({
    hash: settleHash,
  })

  const [settlingBetId, setSettlingBetId] = useState<bigint | null>(null)

  if (!isConnected) {
    return (
      <Card className="bg-card/50 backdrop-blur border-border/40">
        <CardContent className="py-20 text-center">
          <p className="text-muted-foreground">Connect your wallet to view your bets</p>
        </CardContent>
      </Card>
    )
  }

  if (isLoading) {
    return (
      <Card className="bg-card/50 backdrop-blur border-border/40">
        <CardContent className="py-20 text-center">
          <Loader2 className="w-8 h-8 animate-spin mx-auto text-muted-foreground" />
          <p className="text-sm text-muted-foreground mt-4">Loading your bets...</p>
        </CardContent>
      </Card>
    )
  }

  const handleClaim = async (betId: bigint) => {
    if (!bettingPool?.address) return

    try {
      setSettlingBetId(betId)
      settleBet({
        address: bettingPool.address,
        abi: bettingPool.abi,
        functionName: "settleBet",
        args: [betId],
      })
      toast.success("Claiming winnings...")
    } catch (error: any) {
      toast.error(error?.message || "Failed to claim winnings")
      setSettlingBetId(null)
    }
  }

  if (settled && settlingBetId) {
    toast.success("Winnings claimed successfully!")
    setSettlingBetId(null)
  }

  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-2xl font-bold mb-2">My Betting History</h3>
        <p className="text-sm text-muted-foreground">Track your bets and claim winnings</p>
      </div>

      {bets && bets.length > 0 ? (
        <div className="grid gap-4">
          {bets.map((bet) => (
            <BetCard
              key={bet.id.toString()}
              bet={bet}
              onClaim={handleClaim}
              isSettling={isSettling && settlingBetId === bet.id}
            />
          ))}
        </div>
      ) : (
        <Card className="bg-card/50 backdrop-blur border-border/40">
          <CardContent className="py-12 text-center">
            <p className="text-muted-foreground">No bets yet. Place your first bet!</p>
          </CardContent>
        </Card>
      )}
    </div>
  )
}

function BetCard({
  bet,
  onClaim,
  isSettling,
}: {
  bet: any
  onClaim: (betId: bigint) => void
  isSettling: boolean
}) {
  const status = bet.settled ? (bet.won ? "won" : "lost") : "pending"

  return (
    <Card className="bg-card/50 backdrop-blur border-border/40">
      <CardHeader>
        <div className="flex items-start justify-between">
          <div>
            <CardTitle className="text-lg">Bet #{bet.id.toString()}</CardTitle>
            <CardDescription>Round {bet.roundId.toString()}</CardDescription>
          </div>
          <Badge
            variant={status === "won" ? "default" : status === "lost" ? "destructive" : "secondary"}
            className="flex items-center gap-1"
          >
            {status === "won" && <Trophy className="w-3 h-3" />}
            {status === "lost" && <XCircle className="w-3 h-3" />}
            {status === "pending" && <Clock className="w-3 h-3" />}
            {status.toUpperCase()}
          </Badge>
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        {/* Bet Stats */}
        <div className="grid grid-cols-3 gap-4">
          <div>
            <p className="text-xs text-muted-foreground mb-1">Amount Wagered</p>
            <p className="text-lg font-bold">{Number(formatUnits(bet.amount, 18)).toFixed(2)} LEAGUE</p>
          </div>
          <div>
            <p className="text-xs text-muted-foreground mb-1">Potential Payout</p>
            <p className="text-lg font-bold">{Number(formatUnits(bet.potentialPayout, 18)).toFixed(2)} LEAGUE</p>
          </div>
          <div>
            <p className="text-xs text-muted-foreground mb-1">Predictions</p>
            <p className="text-lg font-bold">{bet.predictions.length}</p>
          </div>
        </div>

        {/* Predictions */}
        <div className="space-y-2">
          <p className="text-sm font-medium">Predictions:</p>
          <div className="grid gap-2">
            {bet.predictions.map((pred: any, idx: number) => (
              <PredictionRow key={idx} prediction={pred} roundId={bet.roundId} settled={bet.settled} />
            ))}
          </div>
        </div>

        {/* Action Button */}
        {status === "won" && (
          <Button className="w-full" onClick={() => onClaim(bet.id)} disabled={isSettling}>
            {isSettling && <Loader2 className="w-4 h-4 mr-2 animate-spin" />}
            {isSettling ? "Claiming..." : "Claim Winnings"}
          </Button>
        )}
        {status === "pending" && (
          <Button variant="outline" className="w-full bg-transparent" disabled>
            Waiting for Settlement
          </Button>
        )}
      </CardContent>
    </Card>
  )
}

function PredictionRow({
  prediction,
  roundId,
  settled,
}: {
  prediction: any
  roundId: bigint
  settled: boolean
}) {
  const { match } = useMatch(roundId, prediction.matchIndex)
  const { team: homeTeam } = useTeam(match?.homeTeam)
  const { team: awayTeam } = useTeam(match?.awayTeam)

  if (!match || !homeTeam || !awayTeam) {
    return (
      <div className="flex items-center gap-2 p-2 bg-secondary/30 rounded">
        <Loader2 className="w-4 h-4 animate-spin" />
        <span className="text-sm">Loading match...</span>
      </div>
    )
  }

  const outcomeText = prediction.outcome === 0 ? "HOME" : prediction.outcome === 1 ? "AWAY" : "DRAW"
  const isCorrect = settled && match.settled && match.outcome === prediction.outcome

  return (
    <div className="flex items-center justify-between p-2 bg-secondary/30 rounded">
      <div className="flex-1">
        <p className="text-sm font-medium">
          {homeTeam.name} vs {awayTeam.name}
        </p>
        <div className="flex items-center gap-2 mt-1">
          <Badge variant="outline" className="text-xs">
            {outcomeText}
          </Badge>
          {match.settled && (
            <span className="text-xs text-muted-foreground">
              Score: {match.homeScore}-{match.awayScore}
            </span>
          )}
        </div>
      </div>
      {match.settled && (
        <div>
          {isCorrect ? (
            <CheckCircle className="w-5 h-5 text-green-500" />
          ) : (
            <XCircle className="w-5 h-5 text-red-500" />
          )}
        </div>
      )}
    </div>
  )
}

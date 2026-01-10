"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Separator } from "@/components/ui/separator"
// import { Alert, AlertDescription } from "@/components/ui/alert"
import {
  Play,
  RefreshCw,
  Loader2,
  CheckCircle2,
  AlertCircle,
  Clock,
  Trophy,
  Target,
  Users,
  Coins,
  TrendingUp,
  Calendar,
  Zap,
  Shield,
  Activity,
} from "lucide-react"
import { useAccount } from "wagmi"
import { useAdminActions } from "@/lib/hooks/useAdminActions"
import { useAdminStats } from "@/lib/hooks/useAdminStats"
import { useRoundMatches, useAllTeams } from "@/lib/hooks/useGameData"
import { formatUnits } from "viem"
import { toast } from "sonner"

export function AdminDashboard() {
  const { address, isConnected } = useAccount()
  const {
    startSeason,
    startRound,
    requestMatchResults,
    emergencySettleRound,
    isPending,
    isConfirming,
    isSuccess,
    hash,
  } = useAdminActions()

  const {
    currentRoundId,
    currentSeasonId,
    round,
    season,
    roundDuration,
    roundsPerSeason,
    isRoundSettled,
    vrfRequestTime,
    timeRemaining,
    totalPool,
    seasonPool,
  } = useAdminStats()

  const { matches } = useRoundMatches(currentRoundId)
  const { teams } = useAllTeams()

  const [currentTime, setCurrentTime] = useState(Math.floor(Date.now() / 1000))

  useEffect(() => {
    const interval = setInterval(() => {
      setCurrentTime(Math.floor(Date.now() / 1000))
    }, 1000)
    return () => clearInterval(interval)
  }, [])

  useEffect(() => {
    if (isSuccess && hash) {
      toast.success("Transaction confirmed!", {
        description: `Hash: ${hash.slice(0, 10)}...${hash.slice(-8)}`,
      })
    }
  }, [isSuccess, hash])

  if (!isConnected) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        {/* <Alert className="max-w-md">
          <AlertCircle className="h-4 w-4" />
          <AlertDescription>Please connect your wallet to access the admin dashboard</AlertDescription>
        </Alert> */}
      </div>
    )
  }

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins}m ${secs}s`
  }

  const formatTimestamp = (timestamp: bigint | number) => {
    return new Date(Number(timestamp) * 1000).toLocaleString()
  }

  const canStartSeason = currentSeasonId === 0n || season?.completed
  const canStartRound = season?.active && (currentRoundId === 0n || isRoundSettled)
  const canRequestVRF = timeRemaining?.canSettle && !isRoundSettled

  // Calculate settled and pending matches
  const settledMatches = matches?.filter((m) => m.settled).length || 0
  const pendingMatches = matches?.length ? matches.length - settledMatches : 0

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">Admin Dashboard</h1>
          <p className="text-sm text-muted-foreground mt-1">Manage seasons, rounds, and system operations</p>
        </div>
        {isPending || isConfirming ? (
          <Badge variant="secondary" className="gap-2">
            <Loader2 className="w-4 h-4 animate-spin" />
            {isPending ? "Sending..." : "Confirming..."}
          </Badge>
        ) : null}
      </div>

      {/* Quick Stats Grid */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Card className="bg-gradient-to-br from-blue-500/10 to-blue-600/5 border-blue-500/20">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Current Season</CardTitle>
            <Trophy className="h-4 w-4 text-blue-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{currentSeasonId?.toString() || "0"}</div>
            <p className="text-xs text-muted-foreground mt-1">
              {season?.active ? (
                <Badge variant="default" className="text-xs">
                  Active
                </Badge>
              ) : season?.completed ? (
                <Badge variant="secondary" className="text-xs">
                  Completed
                </Badge>
              ) : (
                <Badge variant="outline" className="text-xs">
                  Not Started
                </Badge>
              )}
            </p>
          </CardContent>
        </Card>

        <Card className="bg-gradient-to-br from-green-500/10 to-green-600/5 border-green-500/20">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Current Round</CardTitle>
            <Target className="h-4 w-4 text-green-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{currentRoundId?.toString() || "0"}</div>
            <p className="text-xs text-muted-foreground mt-1">
              {isRoundSettled ? (
                <Badge variant="secondary" className="text-xs">
                  Settled
                </Badge>
              ) : currentRoundId && currentRoundId > 0n ? (
                <Badge variant="default" className="text-xs">
                  Active
                </Badge>
              ) : (
                <Badge variant="outline" className="text-xs">
                  Not Started
                </Badge>
              )}
            </p>
          </CardContent>
        </Card>

        <Card className="bg-gradient-to-br from-purple-500/10 to-purple-600/5 border-purple-500/20">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Pool</CardTitle>
            <Coins className="h-4 w-4 text-purple-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {totalPool ? `${Number(formatUnits(totalPool, 18)).toFixed(2)}` : "0.00"}
            </div>
            <p className="text-xs text-muted-foreground mt-1">LEAGUE tokens</p>
          </CardContent>
        </Card>

        <Card className="bg-gradient-to-br from-orange-500/10 to-orange-600/5 border-orange-500/20">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Season Pool</CardTitle>
            <TrendingUp className="h-4 w-4 text-orange-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {seasonPool ? `${Number(formatUnits(seasonPool, 18)).toFixed(2)}` : "0.00"}
            </div>
            <p className="text-xs text-muted-foreground mt-1">LEAGUE tokens</p>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        {/* Season Management */}
        <Card className="border-border/40">
          <CardHeader>
            <div className="flex items-center justify-between">
              <div>
                <CardTitle className="flex items-center gap-2">
                  <Trophy className="w-5 h-5" />
                  Season Management
                </CardTitle>
                <CardDescription>Control season lifecycle and view stats</CardDescription>
              </div>
            </div>
          </CardHeader>
          <CardContent className="space-y-4">
            {season && (
              <div className="space-y-3">
                <div className="grid grid-cols-2 gap-3">
                  <div className="space-y-1">
                    <p className="text-xs text-muted-foreground">Season ID</p>
                    <p className="text-sm font-semibold">{season.seasonId.toString()}</p>
                  </div>
                  <div className="space-y-1">
                    <p className="text-xs text-muted-foreground">Rounds Completed</p>
                    <p className="text-sm font-semibold">
                      {season.currentRound.toString()} / {roundsPerSeason?.toString() || "36"}
                    </p>
                  </div>
                  <div className="space-y-1">
                    <p className="text-xs text-muted-foreground">Started At</p>
                    <p className="text-sm font-semibold">{formatTimestamp(season.startTime)}</p>
                  </div>
                  <div className="space-y-1">
                    <p className="text-xs text-muted-foreground">Status</p>
                    <div>
                      {season.active && !season.completed && (
                        <Badge variant="default" className="text-xs">
                          <Activity className="w-3 h-3 mr-1" />
                          Active
                        </Badge>
                      )}
                      {season.completed && (
                        <Badge variant="secondary" className="text-xs">
                          <CheckCircle2 className="w-3 h-3 mr-1" />
                          Completed
                        </Badge>
                      )}
                      {!season.active && !season.completed && (
                        <Badge variant="outline" className="text-xs">
                          Inactive
                        </Badge>
                      )}
                    </div>
                  </div>
                </div>

                <Separator />

                <div className="space-y-2">
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-muted-foreground">Total Teams</span>
                    <span className="font-semibold">{teams?.length || 20}</span>
                  </div>
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-muted-foreground">Matches Per Round</span>
                    <span className="font-semibold">10</span>
                  </div>
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-muted-foreground">Round Duration</span>
                    <span className="font-semibold">{roundDuration ? formatTime(Number(roundDuration)) : "15m"}</span>
                  </div>
                </div>
              </div>
            )}

            <Separator />

            <Button
              className="w-full"
              size="lg"
              onClick={startSeason}
              disabled={!canStartSeason || isPending || isConfirming}
            >
              {isPending || isConfirming ? (
                <Loader2 className="w-4 h-4 mr-2 animate-spin" />
              ) : (
                <Play className="w-4 h-4 mr-2" />
              )}
              Start New Season
            </Button>

            {!canStartSeason && (""
              // <Alert>
              //   <AlertCircle className="h-4 w-4" />
              //   <AlertDescription className="text-xs">
              //     Current season must be completed before starting a new one
              //   </AlertDescription>
              // </Alert>
            )}
          </CardContent>
        </Card>

        {/* Round Management */}
        <Card className="border-border/40">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Target className="w-5 h-5" />
              Round Management
            </CardTitle>
            <CardDescription>Start rounds and manage match results</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            {round && (
              <div className="space-y-3">
                <div className="grid grid-cols-2 gap-3">
                  <div className="space-y-1">
                    <p className="text-xs text-muted-foreground">Round ID</p>
                    <p className="text-sm font-semibold">{round.roundId?.toString()}</p>
                  </div>
                  <div className="space-y-1">
                    <p className="text-xs text-muted-foreground">Status</p>
                    <div>
                      {isRoundSettled ? (
                        <Badge variant="secondary" className="text-xs">
                          <CheckCircle2 className="w-3 h-3 mr-1" />
                          Settled
                        </Badge>
                      ) : (
                        <Badge variant="default" className="text-xs">
                          <Clock className="w-3 h-3 mr-1" />
                          Active
                        </Badge>
                      )}
                    </div>
                  </div>
                  <div className="space-y-1">
                    <p className="text-xs text-muted-foreground">Started At</p>
                    <p className="text-sm font-semibold">{formatTimestamp(round.startTime)}</p>
                  </div>
                  <div className="space-y-1">
                    <p className="text-xs text-muted-foreground">Time Remaining</p>
                    <p className="text-sm font-semibold">
                      {timeRemaining ? (
                        timeRemaining.remaining > 0 ? (
                          formatTime(timeRemaining.remaining)
                        ) : (
                          <span className="text-green-500">Ready to settle</span>
                        )
                      ) : (
                        "N/A"
                      )}
                    </p>
                  </div>
                </div>

                <Separator />

                <div className="space-y-2">
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-muted-foreground">Total Matches</span>
                    <span className="font-semibold">{matches?.length || 0}</span>
                  </div>
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-muted-foreground">Settled Matches</span>
                    <span className="font-semibold text-green-500">{settledMatches}</span>
                  </div>
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-muted-foreground">Pending Matches</span>
                    <span className="font-semibold text-orange-500">{pendingMatches}</span>
                  </div>
                  {vrfRequestTime && vrfRequestTime > 0n && (
                    <div className="flex items-center justify-between text-sm">
                      <span className="text-muted-foreground">VRF Requested</span>
                      <Badge variant="outline" className="text-xs">
                        <Zap className="w-3 h-3 mr-1" />
                        {formatTimestamp(vrfRequestTime)}
                      </Badge>
                    </div>
                  )}
                </div>
              </div>
            )}

            <Separator />

            <div className="space-y-2">
              <Button
                className="w-full"
                size="lg"
                onClick={startRound}
                disabled={!canStartRound || isPending || isConfirming}
              >
                {isPending || isConfirming ? (
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                ) : (
                  <Play className="w-4 h-4 mr-2" />
                )}
                Start New Round
              </Button>

              <Button
                className="w-full"
                variant="secondary"
                size="lg"
                onClick={requestMatchResults}
                disabled={!canRequestVRF || isPending || isConfirming}
              >
                {isPending || isConfirming ? (
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                ) : (
                  <RefreshCw className="w-4 h-4 mr-2" />
                )}
                Request VRF Settlement
              </Button>

              {!canStartRound && !canRequestVRF && (""
                // <Alert>
                //   <AlertCircle className="h-4 w-4" />
                //   <AlertDescription className="text-xs">
                //     {!season?.active
                //       ? "Season not active"
                //       : !isRoundSettled
                //         ? "Previous round must be settled first"
                //         : timeRemaining && timeRemaining.remaining > 0
                //           ? `Wait ${formatTime(timeRemaining.remaining)} before settling`
                //           : "Ready to start next round"}
                //   </AlertDescription>
                // </Alert>
              )}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Current Matches Overview */}
      {matches && matches.length > 0 && (
        <Card className="border-border/40">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Activity className="w-5 h-5" />
              Current Round Matches
            </CardTitle>
            <CardDescription>Live overview of all matches in the current round</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="grid gap-3 md:grid-cols-2">
              {matches.map((match, idx) => (
                <div
                  key={idx}
                  className="flex items-center justify-between p-3 rounded-lg border border-border/40 bg-card/50"
                >
                  <div className="space-y-1">
                    <p className="text-sm font-medium">
                      Match {idx + 1}: Team {match.homeTeamId.toString()} vs Team {match.awayTeamId.toString()}
                    </p>
                    {match.settled ? (
                      <p className="text-xs text-muted-foreground">
                        Score: {match.homeScore} - {match.awayScore}
                      </p>
                    ) : (
                      <p className="text-xs text-muted-foreground">Pending settlement</p>
                    )}
                  </div>
                  {match.settled ? (
                    <Badge variant="secondary" className="text-xs">
                      <CheckCircle2 className="w-3 h-3 mr-1" />
                      Settled
                    </Badge>
                  ) : (
                    <Badge variant="outline" className="text-xs">
                      <Clock className="w-3 h-3 mr-1" />
                      Pending
                    </Badge>
                  )}
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      {/* Emergency Actions */}
      <Card className="border-destructive/40 bg-destructive/5">
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-destructive">
            <Shield className="w-5 h-5" />
            Emergency Actions
          </CardTitle>
          <CardDescription>Use these actions only in case of VRF failure or critical issues</CardDescription>
        </CardHeader>
        <CardContent>
          {/* <Alert variant="destructive">
            <AlertCircle className="h-4 w-4" />
            <AlertDescription className="text-xs">
              Emergency settlement bypasses VRF and uses pseudo-random seed. Use only if VRF fails after 2 hours.
            </AlertDescription>
          </Alert> */}
          <Button
            variant="destructive"
            className="w-full mt-4"
            onClick={() => {
              if (currentRoundId) {
                const seed = BigInt(Math.floor(Math.random() * 1000000))
                emergencySettleRound(currentRoundId, seed)
              }
            }}
            disabled={!currentRoundId || isRoundSettled || isPending || isConfirming}
          >
            {isPending || isConfirming ? (
              <Loader2 className="w-4 h-4 mr-2 animate-spin" />
            ) : (
              <AlertCircle className="w-4 h-4 mr-2" />
            )}
            Emergency Settle Current Round
          </Button>
        </CardContent>
      </Card>
    </div>
  )
}

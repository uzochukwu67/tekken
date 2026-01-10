"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { TrendingUp, Users, Coins, Trophy, Target, Zap, Shield } from "lucide-react"
import { WalletConnect } from "@/components/wallet-connect-new"
import { BettingInterfaceNew } from "@/components/betting-interface-new"
import { MyBetsNew } from "@/components/my-bets-new"
import { LiquidityPoolNew } from "@/components/liquidity-pool-new"
import { StandingsNew } from "@/components/standings-new"
import { useAccount } from "wagmi"
import { useCurrentRound, useCurrentSeason, useIsCurrentRoundOngoing, useSeasonInfo } from "@/lib/hooks/useGameData"
import { usePoolStats } from "@/lib/hooks/useBettingData"
import { useLiquidityPoolStats } from "@/lib/hooks/useLiquidityData"
import { useBettingPoolEvents } from "@/lib/hooks/useBettingPoolEvents"
import { formatUnits } from "viem"

export default function HomePage() {
  const { isConnected } = useAccount()
  const { currentRoundId } = useCurrentRound()
  const { currentSeasonId } = useCurrentSeason()
  const roundStatus = useIsCurrentRoundOngoing()
  const { isOngoing, remaining } = roundStatus
  const { season } = useSeasonInfo(currentSeasonId as unknown as bigint | undefined)
  const { totalLiquidity } = useLiquidityPoolStats()
  const { seasonPool } = usePoolStats()
  const { betPlacedEvents } = useBettingPoolEvents()

  const [timeRemaining, setTimeRemaining] = useState(15 * 60) // Mock countdown, replace with actual round deadline

  useEffect(() => {
    const interval = setInterval(() => {
      setTimeRemaining((prev) => (prev > 0 ? prev - 1 : 15 * 60))
    }, 1000)

    return () => clearInterval(interval)
  }, [])

  // Update countdown from on-chain remaining when available
  useEffect(() => {
    if (remaining !== undefined) {
      try {
        setTimeRemaining(Number(remaining))
      } catch (e) {
        // ignore conversion errors
      }
    }
  }, [remaining])

  const minutes = Math.floor(timeRemaining / 60)
  const seconds = timeRemaining % 60

  // Helper to format large ETH-like values into human-friendly strings
  const formatEthShort = (value: bigint | undefined | null) => {
    if (!value) return "..."
    const n = Number(formatUnits(value, 18))
    if (Number.isNaN(n)) return "..."
    if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`
    if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`
    return n.toFixed(2)
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-background to-secondary/20">
      {/* Header */}
      <header className="border-b border-border/40 bg-background/80 backdrop-blur-xl sticky top-0 z-50">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <Trophy className="w-8 h-8 text-primary" />
              <div>
                <h1 className="text-2xl font-bold bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent">
                  iVirtualz Sports League
                </h1>
                <p className="text-xs text-muted-foreground">Web3 Prediction Protocol</p>
              </div>
            </div>
            <WalletConnect />
          </div>
        </div>
      </header>

      {/* Hero Section */}
      <section className="border-b border-border/40 bg-gradient-to-r from-primary/5 via-accent/5 to-secondary/5">
        <div className="container mx-auto px-4 py-12 md:py-16">
          <div className="max-w-4xl mx-auto text-center space-y-6">
            <div className="inline-flex items-center gap-2 px-4 py-2 bg-primary/10 border border-primary/20 rounded-full text-sm">
              <Zap className="w-4 h-4 text-primary" />
              <span className="font-medium">Live on Base Sepolia</span>
            </div>
            <h2 className="text-4xl md:text-6xl font-bold tracking-tight">
              Predict. Earn.{" "}
              <span className="bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent">Win Big.</span>
            </h2>
            <p className="text-lg md:text-xl text-muted-foreground max-w-2xl mx-auto">
              The first fully on-chain sports prediction market with dynamic odds, liquidity mining, and
              provably-fair VRF results.
            </p>
          </div>
        </div>
      </section>

      {/* Stats Section */}
      <section className="border-b border-border/40 bg-background/50">
        <div className="container mx-auto px-4 py-8">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <Card className="bg-card/50 backdrop-blur border-border/40">
              <CardContent className="pt-6">
                <div className="text-center space-y-2">
                  <Target className="w-8 h-8 mx-auto text-primary" />
                  <p className="text-2xl font-bold">{currentRoundId?.toString() || "..."}</p>
                  <p className="text-xs text-muted-foreground">Season {season?.seasonId?.toString() || "..."} · Current Round</p>
                </div>
              </CardContent>
            </Card>

            <Card className="bg-card/50 backdrop-blur border-border/40">
              <CardContent className="pt-6">
                <div className="text-center space-y-2">
                  <Coins className="w-8 h-8 mx-auto text-primary" />
                  <p className="text-2xl font-bold">{formatEthShort(totalLiquidity)}</p>
                  <p className="text-xs text-muted-foreground">Total Liquidity</p>
                </div>
              </CardContent>
            </Card>

            <Card className="bg-card/50 backdrop-blur border-border/40">
              <CardContent className="pt-6">
                <div className="text-center space-y-2">
                  <Users className="w-8 h-8 mx-auto text-primary" />
                  <p className="text-2xl font-bold">{betPlacedEvents ? betPlacedEvents.length.toLocaleString() : "..."}</p>
                  <p className="text-xs text-muted-foreground">Total Bets</p>
                </div>
              </CardContent>
            </Card>

            <Card className="bg-card/50 backdrop-blur border-border/40">
              <CardContent className="pt-6">
                <div className="text-center space-y-2">
                  <Trophy className="w-8 h-8 mx-auto text-primary" />
                  <p className="text-2xl font-bold">{formatEthShort(seasonPool)}</p>
                  <p className="text-xs text-muted-foreground">Season Pool</p>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>
      </section>

      {/* Main Content */}
      <section className="py-12">
        <div className="container mx-auto px-4">
          <Tabs defaultValue="bet" className="space-y-8">
            <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
              <TabsList className="grid w-full md:w-auto grid-cols-2 md:grid-cols-4 gap-2">
                <TabsTrigger value="bet">Place Bets</TabsTrigger>
                <TabsTrigger value="mybets">My Bets</TabsTrigger>
                <TabsTrigger value="pool">Liquidity Pool</TabsTrigger>
                <TabsTrigger value="standings">Standings</TabsTrigger>
              </TabsList>

              <div className="flex items-center gap-4">
                <div className="px-4 py-2 bg-card/50 backdrop-blur rounded-lg border border-border/40">
                  <p className="text-xs text-muted-foreground">Next Round</p>
                  <p className="text-2xl font-bold font-mono">
                    {String(minutes).padStart(2, "0")}:{String(seconds).padStart(2, "0")}
                  </p>
                </div>
                {isOngoing ? (
                  <div className="px-3 py-2 bg-green-600 text-white rounded-lg text-sm">Ongoing</div>
                ) : null}
              </div>
            </div>

            <TabsContent value="bet" className="space-y-6">
              <BettingInterfaceNew />
            </TabsContent>

            <TabsContent value="mybets" className="space-y-6">
              <MyBetsNew />
            </TabsContent>

            <TabsContent value="pool" className="space-y-6">
              <LiquidityPoolNew />
            </TabsContent>

            <TabsContent value="standings" className="space-y-6">
              <StandingsNew />
            </TabsContent>
          </Tabs>
        </div>
      </section>

      {/* Features Section */}
      <section className="border-t border-border/40 bg-gradient-to-b from-background to-secondary/10 py-16">
        <div className="container mx-auto px-4">
          <h3 className="text-3xl font-bold text-center mb-12">Why Choose iVirtualz?</h3>
          <div className="grid md:grid-cols-3 gap-8">
            <Card className="bg-card/50 backdrop-blur border-border/40">
              <CardHeader>
                <TrendingUp className="w-12 h-12 mb-4 text-primary" />
                <CardTitle>Dynamic Odds</CardTitle>
                <CardDescription>Real-time odds that adjust based on betting volume and pool liquidity</CardDescription>
              </CardHeader>
            </Card>

            <Card className="bg-card/50 backdrop-blur border-border/40">
              <CardHeader>
                <Coins className="w-12 h-12 mb-4 text-primary" />
                <CardTitle>Liquidity Mining</CardTitle>
                <CardDescription>Earn 25% of losing bets as an LP provider with instant withdrawals</CardDescription>
              </CardHeader>
            </Card>

            <Card className="bg-card/50 backdrop-blur border-border/40">
              <CardHeader>
                <Shield className="w-12 h-12 mb-4 text-primary" />
                <CardTitle>VRF-Powered Results</CardTitle>
                <CardDescription>Chainlink VRF ensures provably-fair and verifiable match outcomes</CardDescription>
              </CardHeader>
            </Card>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-border/40 bg-background/80 backdrop-blur py-8">
        <div className="container mx-auto px-4 text-center text-sm text-muted-foreground">
          <p>&copy; 2025 iVirtualz Sports League. Built with Solidity + Next.js + wagmi on Base.</p>
        </div>
      </footer>
    </div>
  )
}

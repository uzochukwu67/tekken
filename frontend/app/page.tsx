"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { WalletConnect } from "@/components/wallet-connect"
import { BettingInterface } from "@/components/betting-interface"
import { MyBets } from "@/components/my-bets"
import { LiquidityPool } from "@/components/liquidity-pool"
import { Standings } from "@/components/standings"
import { Trophy, TrendingUp, Users, DollarSign } from "lucide-react"

export default function Home() {
  const [isConnected, setIsConnected] = useState(false)
  const [timeRemaining, setTimeRemaining] = useState(15 * 60) // 15 minutes in seconds

  useEffect(() => {
    const timer = setInterval(() => {
      setTimeRemaining((prev) => (prev > 0 ? prev - 1 : 15 * 60))
    }, 1000)
    return () => clearInterval(timer)
  }, [])

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins}:${secs.toString().padStart(2, "0")}`
  }

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b border-border/40 backdrop-blur-sm sticky top-0 z-50 bg-background/80">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-primary to-accent flex items-center justify-center">
                <Trophy className="w-6 h-6 text-primary-foreground" />
              </div>
              <div>
                <h1 className="text-2xl font-bold tracking-tight">iVirtualz</h1>
                <p className="text-xs text-muted-foreground">Sports Betting Protocol</p>
              </div>
            </div>
            <WalletConnect isConnected={isConnected} setIsConnected={setIsConnected} />
          </div>
        </div>
      </header>

      <div className="container mx-auto px-4 py-8">
        {/* Hero Section */}
        <div className="mb-12 text-center space-y-4">
          <h2 className="text-5xl md:text-6xl font-bold tracking-tight text-balance">
            Unlock the Full Potential of{" "}
            <span className="bg-gradient-to-r from-primary via-accent to-primary bg-clip-text text-transparent animate-pulse">
              Web3 Sports Betting
            </span>
          </h2>
          <p className="text-xl text-muted-foreground max-w-3xl mx-auto text-pretty">
            Experience decentralized sports betting with dynamic odds, liquidity pools, and real-time match results
            powered by blockchain technology
          </p>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <Card className="bg-card/50 backdrop-blur border-border/40">
            <CardHeader className="pb-3">
              <CardDescription className="text-xs uppercase tracking-wider">Current Round</CardDescription>
              <CardTitle className="text-3xl font-bold">Round 5</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="flex items-center gap-2">
                <Badge variant="secondary" className="text-xs">
                  {formatTime(timeRemaining)} left
                </Badge>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-card/50 backdrop-blur border-border/40">
            <CardHeader className="pb-3">
              <CardDescription className="text-xs uppercase tracking-wider flex items-center gap-2">
                <DollarSign className="w-4 h-4" />
                Total Liquidity
              </CardDescription>
              <CardTitle className="text-3xl font-bold">2.4M</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-xs text-muted-foreground">LEAGUE tokens locked</p>
            </CardContent>
          </Card>

          <Card className="bg-card/50 backdrop-blur border-border/40">
            <CardHeader className="pb-3">
              <CardDescription className="text-xs uppercase tracking-wider flex items-center gap-2">
                <TrendingUp className="w-4 h-4" />
                Active Bets
              </CardDescription>
              <CardTitle className="text-3xl font-bold">1,247</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-xs text-muted-foreground">This round</p>
            </CardContent>
          </Card>

          <Card className="bg-card/50 backdrop-blur border-border/40">
            <CardHeader className="pb-3">
              <CardDescription className="text-xs uppercase tracking-wider flex items-center gap-2">
                <Users className="w-4 h-4" />
                Season Pool
              </CardDescription>
              <CardTitle className="text-3xl font-bold">567K</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-xs text-muted-foreground">For end rewards</p>
            </CardContent>
          </Card>
        </div>

        {/* Main Content Tabs */}
        <Tabs defaultValue="betting" className="space-y-6">
          <TabsList className="grid w-full grid-cols-4 lg:w-auto lg:inline-grid">
            <TabsTrigger value="betting">Place Bets</TabsTrigger>
            <TabsTrigger value="mybets">My Bets</TabsTrigger>
            <TabsTrigger value="liquidity">Liquidity Pool</TabsTrigger>
            <TabsTrigger value="standings">Standings</TabsTrigger>
          </TabsList>

          <TabsContent value="betting" className="space-y-6">
            <BettingInterface isConnected={isConnected} />
          </TabsContent>

          <TabsContent value="mybets">
            <MyBets isConnected={isConnected} />
          </TabsContent>

          <TabsContent value="liquidity">
            <LiquidityPool isConnected={isConnected} />
          </TabsContent>

          <TabsContent value="standings">
            <Standings />
          </TabsContent>
        </Tabs>

        {/* Features Section */}
        <div className="mt-20 grid md:grid-cols-3 gap-8">
          <Card className="bg-card/50 backdrop-blur border-border/40">
            <CardHeader>
              <CardTitle className="text-lg">Dynamic Odds</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground">
                Live odds that adjust based on betting volume, ensuring fair markets and optimal returns
              </p>
            </CardContent>
          </Card>

          <Card className="bg-card/50 backdrop-blur border-border/40">
            <CardHeader>
              <CardTitle className="text-lg">Liquidity Mining</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground">
                Provide liquidity and earn rewards from protocol fees while supporting the betting ecosystem
              </p>
            </CardContent>
          </Card>

          <Card className="bg-card/50 backdrop-blur border-border/40">
            <CardHeader>
              <CardTitle className="text-lg">VRF-Powered Results</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground">
                Provably fair match outcomes using Chainlink VRF for truly random and transparent results
              </p>
            </CardContent>
          </Card>
        </div>
      </div>

      {/* Footer */}
      <footer className="border-t border-border/40 mt-20 py-8">
        <div className="container mx-auto px-4 text-center text-sm text-muted-foreground">
          <p>© 2025 iVirtualz Protocol. Powered by Web3 technology.</p>
        </div>
      </footer>
    </div>
  )
}

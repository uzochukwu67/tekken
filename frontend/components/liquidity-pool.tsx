"use client"

import { useState } from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { TrendingUp, Droplets, Lock, Unlock } from "lucide-react"
import { Badge } from "@/components/ui/badge"

interface LiquidityPoolProps {
  isConnected: boolean
}

export function LiquidityPool({ isConnected }: LiquidityPoolProps) {
  const [depositAmount, setDepositAmount] = useState("")
  const [withdrawShares, setWithdrawShares] = useState("")

  return (
    <div className="grid lg:grid-cols-3 gap-6">
      {/* Pool Stats */}
      <div className="lg:col-span-2 space-y-6">
        <div>
          <h3 className="text-2xl font-bold mb-2">Liquidity Pool</h3>
          <p className="text-sm text-muted-foreground">Provide liquidity and earn rewards from betting fees</p>
        </div>

        {/* Stats Grid */}
        <div className="grid md:grid-cols-3 gap-4">
          <Card className="bg-card/50 backdrop-blur border-border/40">
            <CardHeader className="pb-3">
              <CardDescription className="text-xs uppercase tracking-wider flex items-center gap-2">
                <Droplets className="w-4 h-4" />
                Total Pool Size
              </CardDescription>
              <CardTitle className="text-3xl font-bold">2.4M</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-xs text-muted-foreground">LEAGUE tokens</p>
            </CardContent>
          </Card>

          <Card className="bg-card/50 backdrop-blur border-border/40">
            <CardHeader className="pb-3">
              <CardDescription className="text-xs uppercase tracking-wider flex items-center gap-2">
                <Lock className="w-4 h-4" />
                Locked Liquidity
              </CardDescription>
              <CardTitle className="text-3xl font-bold">892K</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-xs text-muted-foreground">For active bets</p>
            </CardContent>
          </Card>

          <Card className="bg-card/50 backdrop-blur border-border/40">
            <CardHeader className="pb-3">
              <CardDescription className="text-xs uppercase tracking-wider flex items-center gap-2">
                <TrendingUp className="w-4 h-4" />
                APY
              </CardDescription>
              <CardTitle className="text-3xl font-bold">24.5%</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-xs text-muted-foreground">Current yield</p>
            </CardContent>
          </Card>
        </div>

        {/* Pool Health */}
        <Card className="bg-card/50 backdrop-blur border-border/40">
          <CardHeader>
            <CardTitle>Pool Health</CardTitle>
            <CardDescription>Current utilization and multiplier</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center justify-between">
              <span className="text-sm text-muted-foreground">Utilization Rate</span>
              <span className="text-lg font-bold">37.2%</span>
            </div>
            <div className="h-2 bg-secondary rounded-full overflow-hidden">
              <div className="h-full bg-primary" style={{ width: "37.2%" }} />
            </div>
            <div className="flex items-center justify-between">
              <span className="text-sm text-muted-foreground">Pool Multiplier</span>
              <Badge variant="default">2.0x</Badge>
            </div>
          </CardContent>
        </Card>

        {/* User Position */}
        {isConnected && (
          <Card className="bg-gradient-to-br from-primary/10 to-accent/10 backdrop-blur border-border/40">
            <CardHeader>
              <CardTitle>Your LP Position</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="grid md:grid-cols-3 gap-4">
                <div>
                  <p className="text-xs text-muted-foreground mb-1">LP Shares</p>
                  <p className="text-2xl font-bold">50,000</p>
                </div>
                <div>
                  <p className="text-xs text-muted-foreground mb-1">Share of Pool</p>
                  <p className="text-2xl font-bold">2.08%</p>
                </div>
                <div>
                  <p className="text-xs text-muted-foreground mb-1">Current Value</p>
                  <p className="text-2xl font-bold">52,450 LEAGUE</p>
                </div>
              </div>
            </CardContent>
          </Card>
        )}
      </div>

      {/* Deposit/Withdraw */}
      <div className="lg:sticky lg:top-24 h-fit">
        <Card className="bg-gradient-to-br from-card to-card/50 backdrop-blur border-border/40">
          <CardHeader>
            <CardTitle>Manage Liquidity</CardTitle>
            <CardDescription>Deposit or withdraw LP tokens</CardDescription>
          </CardHeader>
          <CardContent>
            <Tabs defaultValue="deposit" className="space-y-4">
              <TabsList className="grid w-full grid-cols-2">
                <TabsTrigger value="deposit">Deposit</TabsTrigger>
                <TabsTrigger value="withdraw">Withdraw</TabsTrigger>
              </TabsList>

              <TabsContent value="deposit" className="space-y-4">
                <div className="space-y-2">
                  <label className="text-sm font-medium">Amount (LEAGUE)</label>
                  <Input
                    type="number"
                    placeholder="1000.00"
                    value={depositAmount}
                    onChange={(e) => setDepositAmount(e.target.value)}
                    disabled={!isConnected}
                  />
                  <p className="text-xs text-muted-foreground">Minimum first deposit: 1,000 LEAGUE</p>
                </div>

                <div className="space-y-2 p-3 bg-secondary/50 rounded-lg">
                  <div className="flex justify-between text-sm">
                    <span className="text-muted-foreground">LP Shares to Receive:</span>
                    <span className="font-bold">~{depositAmount || "0"}</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-muted-foreground">Share of Pool:</span>
                    <span className="font-bold">~0.04%</span>
                  </div>
                </div>

                <Button className="w-full" size="lg" disabled={!isConnected}>
                  <Droplets className="w-4 h-4 mr-2" />
                  {isConnected ? "Deposit Liquidity" : "Connect Wallet"}
                </Button>
              </TabsContent>

              <TabsContent value="withdraw" className="space-y-4">
                <div className="space-y-2">
                  <label className="text-sm font-medium">LP Shares to Burn</label>
                  <Input
                    type="number"
                    placeholder="0"
                    value={withdrawShares}
                    onChange={(e) => setWithdrawShares(e.target.value)}
                    disabled={!isConnected}
                  />
                  <p className="text-xs text-muted-foreground">15-minute cooldown after deposit</p>
                </div>

                <div className="space-y-2 p-3 bg-secondary/50 rounded-lg">
                  <div className="flex justify-between text-sm">
                    <span className="text-muted-foreground">LEAGUE to Receive:</span>
                    <span className="font-bold">~{withdrawShares || "0"}</span>
                  </div>
                </div>

                <Button className="w-full bg-transparent" size="lg" variant="outline" disabled={!isConnected}>
                  <Unlock className="w-4 h-4 mr-2" />
                  {isConnected ? "Withdraw Liquidity" : "Connect Wallet"}
                </Button>
              </TabsContent>
            </Tabs>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}

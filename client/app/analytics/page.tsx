"use client"

import { Card } from "@/components/ui/card"
import { Header } from "@/components/header"
import { Footer } from "@/components/footer"
import { Container } from "@/components/container"
import { Section } from "@/components/section"
import { useAccount } from "wagmi"
import { Button } from "@/components/ui/button"
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Legend, ResponsiveContainer } from "recharts"
import { ChartContainer, ChartTooltip, ChartTooltipContent } from "@/components/ui/chart"

export default function AnalyticsPage() {
  const { isConnected } = useAccount()

  // Mock analytics data
  const mockStats = {
    totalBets: 24,
    wonBets: 14,
    lostBets: 10,
    totalStaked: 2.5,
    totalWinnings: 6.25,
    roi: 150,
    winRate: 58.3,
  }

  // Chart data for profit/loss over time
  const profitData = [
    { date: "Week 1", profit: 0.5 },
    { date: "Week 2", profit: 1.2 },
    { date: "Week 3", profit: 0.8 },
    { date: "Week 4", profit: 2.3 },
    { date: "Week 5", profit: 1.7 },
    { date: "Week 6", profit: 3.5 },
  ]

  // Bet type distribution
  const betDistribution = [
    { name: "Home Wins", value: 50, color: "var(--color-chart-1)" },
    { name: "Draws", value: 25, color: "var(--color-chart-2)" },
    { name: "Away Wins", value: 25, color: "var(--color-chart-3)" },
  ]

  if (!isConnected) {
    return (
      <div className="min-h-screen bg-white">
        <Header />
        <Section>
          <Container>
            <div className="rounded-lg border border-border bg-yellow-50/30 p-8 text-center">
              <h2 className="mb-3 text-2xl font-bold text-foreground">Connect Your Wallet</h2>
              <p className="mb-6 text-muted-foreground">
                Please connect your Web3 wallet to view your betting analytics.
              </p>
              <Button className="bg-primary text-primary-foreground">Connect Wallet</Button>
            </div>
          </Container>
        </Section>
        <Footer />
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-white">
      <Header />

      <Section className="border-t border-border">
        <Container>
          <div className="mb-12">
            <h1 className="mb-2 text-4xl font-bold text-foreground">Analytics Dashboard</h1>
            <p className="text-lg text-muted-foreground">Track your betting performance and statistics</p>
          </div>

          {/* Key Stats Grid */}
          <div className="mb-12 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <Card className="border border-border p-6">
              <p className="text-sm text-muted-foreground">Total Bets</p>
              <p className="mt-2 text-3xl font-bold text-primary">{mockStats.totalBets}</p>
              <p className="mt-1 text-xs text-muted-foreground">All time</p>
            </Card>

            <Card className="border border-border p-6">
              <p className="text-sm text-muted-foreground">Win Rate</p>
              <p className="mt-2 text-3xl font-bold text-primary">{mockStats.winRate.toFixed(1)}%</p>
              <p className="mt-1 text-xs text-muted-foreground">
                {mockStats.wonBets} wins, {mockStats.lostBets} losses
              </p>
            </Card>

            <Card className="border border-border p-6">
              <p className="text-sm text-muted-foreground">Total Staked</p>
              <p className="mt-2 text-3xl font-bold text-primary">{mockStats.totalStaked} ETH</p>
              <p className="mt-1 text-xs text-muted-foreground">Across all bets</p>
            </Card>

            <Card className="border border-border p-6">
              <p className="text-sm text-muted-foreground">Profit (ROI)</p>
              <p className="mt-2 text-3xl font-bold text-green-600">{mockStats.roi}%</p>
              <p className="mt-1 text-xs text-muted-foreground">Net return on investment</p>
            </Card>
          </div>

          {/* Charts Section */}
          <div className="grid gap-8 mb-8">
            {/* Profit Over Time Chart */}
            <Card className="border border-border p-6">
              <h3 className="mb-6 font-semibold text-foreground">Profit Over Time</h3>
              <ChartContainer
                config={{
                  profit: {
                    label: "Profit (ETH)",
                    color: "hsl(var(--color-chart-1))",
                  },
                }}
                className="h-[300px]"
              >
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={profitData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="date" />
                    <YAxis />
                    <ChartTooltip content={<ChartTooltipContent />} />
                    <Legend />
                    <Line type="monotone" dataKey="profit" stroke="var(--color-profit)" strokeWidth={2} />
                  </LineChart>
                </ResponsiveContainer>
              </ChartContainer>
            </Card>
          </div>

          {/* Performance Charts */}
          <div className="grid gap-8 md:grid-cols-2">
            {/* Winnings Chart */}
            <Card className="border border-border p-6">
              <h3 className="mb-6 font-semibold text-foreground">Profit/Loss Breakdown</h3>
              <div className="space-y-4">
                <div>
                  <div className="mb-2 flex justify-between">
                    <span className="text-sm font-medium text-foreground">Total Winnings</span>
                    <span className="font-bold text-green-600">{mockStats.totalWinnings} ETH</span>
                  </div>
                  <div className="h-2 rounded-full bg-border">
                    <div className="h-full rounded-full bg-green-600 w-3/4"></div>
                  </div>
                </div>
                <div>
                  <div className="mb-2 flex justify-between">
                    <span className="text-sm font-medium text-foreground">Total Staked</span>
                    <span className="font-bold text-primary">{mockStats.totalStaked} ETH</span>
                  </div>
                  <div className="h-2 rounded-full bg-border">
                    <div className="h-full rounded-full bg-primary w-1/2"></div>
                  </div>
                </div>
                <div>
                  <div className="mb-2 flex justify-between">
                    <span className="text-sm font-medium text-foreground">Net Profit</span>
                    <span className="font-bold text-primary">
                      {(mockStats.totalWinnings - mockStats.totalStaked).toFixed(2)} ETH
                    </span>
                  </div>
                </div>
              </div>
            </Card>

            {/* Bet Types Distribution */}
            <Card className="border border-border p-6">
              <h3 className="mb-6 font-semibold text-foreground">Bet Type Distribution</h3>
              <div className="space-y-4">
                {[
                  { type: "Home Wins", count: 12, percentage: 50 },
                  { type: "Draws", count: 6, percentage: 25 },
                  { type: "Away Wins", count: 6, percentage: 25 },
                ].map((bet) => (
                  <div key={bet.type}>
                    <div className="mb-2 flex justify-between">
                      <span className="text-sm font-medium text-foreground">{bet.type}</span>
                      <span className="text-sm text-muted-foreground">{bet.count} bets</span>
                    </div>
                    <div className="h-2 rounded-full bg-border">
                      <div className="h-full rounded-full bg-primary" style={{ width: `${bet.percentage}%` }}></div>
                    </div>
                  </div>
                ))}
              </div>
            </Card>
          </div>

          {/* Recent Bets */}
          <div className="mt-12">
            <h2 className="mb-6 text-2xl font-bold text-foreground">Recent Bets</h2>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border">
                    <th className="px-4 py-3 text-left font-semibold text-foreground">Match</th>
                    <th className="px-4 py-3 text-left font-semibold text-foreground">Prediction</th>
                    <th className="px-4 py-3 text-right font-semibold text-foreground">Odds</th>
                    <th className="px-4 py-3 text-right font-semibold text-foreground">Stake</th>
                    <th className="px-4 py-3 text-right font-semibold text-foreground">Result</th>
                  </tr>
                </thead>
                <tbody>
                  {[
                    {
                      match: "Man United vs Liverpool",
                      prediction: "Home Win",
                      odds: 2.1,
                      stake: 0.5,
                      result: "Won",
                      color: "text-green-600",
                    },
                    {
                      match: "Arsenal vs Chelsea",
                      prediction: "Draw",
                      odds: 3.5,
                      stake: 0.5,
                      result: "Lost",
                      color: "text-red-600",
                    },
                    {
                      match: "Man City vs Tottenham",
                      prediction: "Away Win",
                      odds: 3.8,
                      stake: 0.5,
                      result: "Won",
                      color: "text-green-600",
                    },
                    {
                      match: "Brighton vs Newcastle",
                      prediction: "Home Win",
                      odds: 2.3,
                      stake: 0.5,
                      result: "Pending",
                      color: "text-yellow-600",
                    },
                  ].map((bet, idx) => (
                    <tr key={idx} className="border-b border-border hover:bg-yellow-50/30">
                      <td className="px-4 py-3 font-medium text-foreground">{bet.match}</td>
                      <td className="px-4 py-3 text-foreground">{bet.prediction}</td>
                      <td className="px-4 py-3 text-right font-bold text-primary">{bet.odds.toFixed(2)}</td>
                      <td className="px-4 py-3 text-right font-medium text-foreground">{bet.stake} ETH</td>
                      <td className={`px-4 py-3 text-right font-bold ${bet.color}`}>{bet.result}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </Container>
      </Section>

      <Footer />
    </div>
  )
}

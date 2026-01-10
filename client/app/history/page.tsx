"use client"

import { Card } from "@/components/ui/card"
import { Header } from "@/components/header"
import { Footer } from "@/components/footer"
import { Container } from "@/components/container"
import { Section } from "@/components/section"
import { useAccount } from "wagmi"
import { Button } from "@/components/ui/button"
import { useState } from "react"

export default function HistoryPage() {
  const { isConnected } = useAccount()
  const [filterStatus, setFilterStatus] = useState<"all" | "won" | "lost" | "pending">("all")

  // Mock bet history
  const mockBets = [
    {
      id: 1,
      match: "Man United vs Liverpool",
      prediction: "Home Win",
      odds: 2.1,
      stake: 0.5,
      potential: 1.05,
      result: "won",
      resultMatch: "2-1",
      date: "2024-01-15",
      txHash: "0x123...abc",
    },
    {
      id: 2,
      match: "Arsenal vs Chelsea",
      prediction: "Draw",
      odds: 3.5,
      stake: 0.5,
      potential: 1.75,
      result: "lost",
      resultMatch: "2-1",
      date: "2024-01-14",
      txHash: "0x456...def",
    },
    {
      id: 3,
      match: "Man City vs Tottenham",
      prediction: "Away Win",
      odds: 3.8,
      stake: 0.5,
      potential: 1.9,
      result: "won",
      resultMatch: "1-3",
      date: "2024-01-13",
      txHash: "0x789...ghi",
    },
    {
      id: 4,
      match: "Brighton vs Newcastle",
      prediction: "Home Win",
      odds: 2.3,
      stake: 0.5,
      potential: 1.15,
      result: "pending",
      resultMatch: "-",
      date: "2024-01-12",
      txHash: "0xabc...jkl",
    },
  ]

  const filteredBets = mockBets.filter((bet) => {
    if (filterStatus === "all") return true
    return bet.result === filterStatus
  })

  if (!isConnected) {
    return (
      <div className="min-h-screen bg-white">
        <Header />
        <Section>
          <Container>
            <div className="rounded-lg border border-border bg-yellow-50/30 p-8 text-center">
              <h2 className="mb-3 text-2xl font-bold text-foreground">Connect Your Wallet</h2>
              <p className="mb-6 text-muted-foreground">Please connect your Web3 wallet to view your bet history.</p>
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
          <div className="mb-8">
            <h1 className="mb-2 text-4xl font-bold text-foreground">Bet History</h1>
            <p className="text-lg text-muted-foreground">View all your placed bets and results</p>
          </div>

          {/* Filter Buttons */}
          <div className="mb-8 flex gap-2">
            {(["all", "won", "lost", "pending"] as const).map((filter) => (
              <Button
                key={filter}
                variant={filterStatus === filter ? "default" : "outline"}
                className={filterStatus === filter ? "bg-primary text-primary-foreground" : ""}
                onClick={() => setFilterStatus(filter)}
              >
                {filter.charAt(0).toUpperCase() + filter.slice(1)}
              </Button>
            ))}
          </div>

          {/* Bets List */}
          <div className="space-y-3">
            {filteredBets.length === 0 ? (
              <Card className="border border-border p-8 text-center">
                <p className="text-muted-foreground">No bets found for this filter</p>
              </Card>
            ) : (
              filteredBets.map((bet) => {
                const getResultColor = (result: string) => {
                  if (result === "won") return "text-green-600"
                  if (result === "lost") return "text-red-600"
                  return "text-yellow-600"
                }

                const getResultBg = (result: string) => {
                  if (result === "won") return "bg-green-50 border-green-200"
                  if (result === "lost") return "bg-red-50 border-red-200"
                  return "bg-yellow-50 border-yellow-200"
                }

                return (
                  <Card
                    key={bet.id}
                    className={`border p-6 cursor-pointer hover:shadow-md transition-shadow ${getResultBg(bet.result)}`}
                  >
                    <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
                      {/* Match Info */}
                      <div className="flex-1">
                        <h3 className="font-semibold text-foreground">{bet.match}</h3>
                        <p className="mt-1 text-sm text-muted-foreground">{bet.prediction}</p>
                        <p className="mt-1 text-xs text-muted-foreground">{bet.date}</p>
                      </div>

                      {/* Odds & Stake */}
                      <div className="flex gap-6 md:gap-8">
                        <div>
                          <p className="text-xs text-muted-foreground">Odds</p>
                          <p className="font-bold text-primary text-lg">{bet.odds.toFixed(2)}</p>
                        </div>
                        <div>
                          <p className="text-xs text-muted-foreground">Stake</p>
                          <p className="font-bold text-foreground text-lg">{bet.stake} ETH</p>
                        </div>
                        <div>
                          <p className="text-xs text-muted-foreground">Potential</p>
                          <p className="font-bold text-foreground text-lg">{bet.potential.toFixed(2)} ETH</p>
                        </div>
                      </div>

                      {/* Result */}
                      <div className="text-right">
                        <p className={`text-sm font-bold capitalize ${getResultColor(bet.result)}`}>
                          {bet.result === "won"
                            ? `+${(bet.potential - bet.stake).toFixed(2)} ETH`
                            : bet.result === "lost"
                              ? `-${bet.stake} ETH`
                              : "Pending"}
                        </p>
                        <p className="mt-2 text-xs text-muted-foreground">{bet.resultMatch}</p>
                        <a
                          href={`https://sepolia.etherscan.io/tx/${bet.txHash}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="mt-2 text-xs text-primary hover:underline"
                        >
                          View on Etherscan
                        </a>
                      </div>
                    </div>
                  </Card>
                )
              })
            )}
          </div>
        </Container>
      </Section>

      <Footer />
    </div>
  )
}

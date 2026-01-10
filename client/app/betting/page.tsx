"use client"

import { useState, useMemo } from "react"
import { useAccount } from "wagmi"
import { Header } from "@/components/header"
import { Footer } from "@/components/footer"
import { Container } from "@/components/container"
import { Section } from "@/components/section"
import { MatchCard } from "@/components/match-card"
import { BettingSlip } from "@/components/betting-slip"
import { Button } from "@/components/ui/button"
import { Spinner } from "@/components/ui/spinner"
import { useBettingState } from "@/hooks/use-betting-state"
import { useGetMatches } from "@/hooks/use-contract-interaction"
import { ConnectButton } from "@/components/connect-button"

export default function BettingPage() {
  const { isConnected } = useAccount()
  const { slip, addBet, removeBet, clearSlip } = useBettingState()
  const { matches, isLoading } = useGetMatches()
  const [selectedFilter, setSelectedFilter] = useState<"all" | "upcoming" | "live" | "completed">("upcoming")

  const filteredMatches = useMemo(() => {
    if (selectedFilter === "all") return matches
    return matches.filter((match) => match.status === selectedFilter)
  }, [selectedFilter, matches])

  if (!isConnected) {
    return (
      <div className="min-h-screen bg-white">
        <Header />
        <Section>
          <Container>
            <div className="rounded-lg border border-border bg-yellow-50/30 p-8 text-center">
              <h2 className="mb-3 text-2xl font-bold text-foreground">Connect Your Wallet</h2>
              <p className="mb-6 text-muted-foreground">
                Please connect your Web3 wallet to start placing bets on Premier League matches.
              </p>
              <ConnectButton />
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
            <h1 className="mb-2 text-4xl font-bold text-foreground">Betting Dashboard</h1>
            <p className="text-lg text-muted-foreground">Choose your predictions and build your betting slip</p>
          </div>

          {/* Filter Buttons */}
          <div className="mb-8 flex gap-2 flex-wrap">
            {(["all", "upcoming", "live", "completed"] as const).map((filter) => (
              <Button
                key={filter}
                variant={selectedFilter === filter ? "default" : "outline"}
                className={selectedFilter === filter ? "bg-primary text-primary-foreground" : ""}
                onClick={() => setSelectedFilter(filter)}
              >
                {filter.charAt(0).toUpperCase() + filter.slice(1)}
              </Button>
            ))}
          </div>

          {isLoading ? (
            <div className="flex items-center justify-center py-12">
              <Spinner className="h-8 w-8" />
            </div>
          ) : (
            <div className="grid gap-8 lg:grid-cols-3">
              {/* Matches Grid */}
              <div className="lg:col-span-2">
                {filteredMatches.length === 0 ? (
                  <div className="rounded-lg border border-border p-8 text-center">
                    <p className="text-muted-foreground">No matches found for this filter</p>
                  </div>
                ) : (
                  <div className="grid gap-4 md:grid-cols-2">
                    {filteredMatches.map((match) => (
                      <MatchCard
                        key={match.id}
                        match={match}
                        onSelectBet={(matchId, prediction, odds) => {
                          addBet({
                            id: `${matchId}-${prediction}`,
                            matchId: matchId.toString(),
                            matchName: `${match.homeTeam} vs ${match.awayTeam}`,
                            prediction,
                            predictionLabel:
                              prediction === "home" ? "Home Win" : prediction === "draw" ? "Draw" : "Away Win",
                            odds,
                            amount: slip.totalStake || 0.1,
                            potential: (slip.totalStake || 0.1) * odds,
                            timestamp: Date.now(),
                          })
                        }}
                      />
                    ))}
                  </div>
                )}
              </div>

              {/* Betting Slip Sidebar */}
              <div>
                <BettingSlip slip={slip} onRemoveBet={removeBet} onClear={clearSlip} />
              </div>
            </div>
          )}
        </Container>
      </Section>

      <Footer />
    </div>
  )
}

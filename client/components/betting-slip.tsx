"use client"

import { useState } from "react"
import { Card } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { usePlaceBet } from "@/hooks/use-place-bet"
import type { BettingSlip as BettingSlipType } from "@/hooks/use-betting-state"
import { useAccount } from "wagmi"

interface BettingSlipProps {
  slip: BettingSlipType
  onRemoveBet: (matchId: string) => void
  onClear: () => void
}

export function BettingSlip({ slip, onRemoveBet, onClear }: BettingSlipProps) {
  const [stakeAmount, setStakeAmount] = useState("0.1")
  const { isConnected, chain } = useAccount()
  const { placeBet, isLoading: isPlacing, error } = usePlaceBet()

  const handlePlaceBet = async () => {
    if (slip.bets.length === 0) {
      alert("Please select at least one bet")
      return
    }

    if (!isConnected) {
      alert("Please connect your wallet first")
      return
    }

    console.log("Placing bets with amount:", stakeAmount)
  }

  return (
    <Card className="sticky top-20 border border-border bg-white">
      {/* Header */}
      <div className="border-b border-border bg-primary px-6 py-4">
        <h2 className="font-bold text-primary-foreground">Betting Slip</h2>
      </div>

      {/* Content */}
      <div className="p-6">
        {slip.bets.length === 0 ? (
          <div className="text-center py-8">
            <p className="text-sm text-muted-foreground">No bets selected</p>
            <p className="mt-1 text-xs text-muted-foreground">Select matches and odds to get started</p>
          </div>
        ) : (
          <>
            {/* Bets List */}
            <div className="mb-6 space-y-3 max-h-64 overflow-y-auto">
              {slip.bets.map((bet) => (
                <div
                  key={bet.id}
                  className="flex items-start gap-3 rounded-lg border border-border bg-yellow-50/50 p-3"
                >
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-semibold text-foreground truncate">{bet.matchName}</p>
                    <p className="text-xs text-muted-foreground">{bet.predictionLabel}</p>
                    <p className="mt-1 font-bold text-primary">{bet.odds.toFixed(2)}</p>
                  </div>
                  <button
                    onClick={() => onRemoveBet(bet.id)}
                    className="rounded-full h-7 w-7 flex items-center justify-center text-foreground hover:bg-destructive hover:text-destructive-foreground transition-colors flex-shrink-0"
                  >
                    ×
                  </button>
                </div>
              ))}
            </div>

            {/* Divider */}
            <div className="mb-6 border-t border-border"></div>

            {/* Odds Summary */}
            <div className="mb-6 space-y-2">
              <div className="flex justify-between text-sm">
                <span className="text-muted-foreground">Total Odds:</span>
                <span className="font-semibold text-foreground">{slip.totalOdds.toFixed(2)}</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-muted-foreground">Number of Bets:</span>
                <span className="font-semibold text-foreground">{slip.bets.length}</span>
              </div>
            </div>

            {/* Divider */}
            <div className="mb-6 border-t border-border"></div>

            {/* Stake Input */}
            <div className="mb-6">
              <label className="mb-2 block text-sm font-semibold text-foreground">Stake Amount (ETH)</label>
              <Input
                type="number"
                value={stakeAmount}
                onChange={(e) => setStakeAmount(e.target.value)}
                placeholder="0.1"
                className="border-border"
                step="0.01"
                min="0"
                disabled={isPlacing}
              />
              <p className="mt-2 text-xs text-muted-foreground">Minimum: 0.01 ETH</p>
            </div>

            {/* Potential Win */}
            <div className="mb-6 rounded-lg bg-primary/10 p-4">
              <p className="text-xs text-muted-foreground">Potential Win</p>
              <p className="mt-1 text-2xl font-bold text-primary">
                {(Number.parseFloat(stakeAmount || "0") * slip.totalOdds).toFixed(4)} ETH
              </p>
              <p className="mt-1 text-xs text-muted-foreground">
                Profit:{" "}
                {(
                  Number.parseFloat(stakeAmount || "0") * slip.totalOdds -
                  Number.parseFloat(stakeAmount || "0")
                ).toFixed(4)}{" "}
                ETH
              </p>
            </div>

            {/* Error Message */}
            {error && <div className="mb-4 rounded-lg bg-destructive/10 p-3 text-sm text-destructive">{error}</div>}

            {/* Chain Warning */}
            {isConnected && chain?.id !== 11155111 && (
              <div className="mb-4 rounded-lg bg-yellow-50 p-3 text-sm text-yellow-900 border border-yellow-200">
                Please switch to Sepolia testnet to place bets
              </div>
            )}

            {/* Buttons */}
            <div className="space-y-3">
              <Button
                className="w-full bg-primary text-primary-foreground hover:bg-primary/90 h-10 font-semibold disabled:opacity-50"
                onClick={handlePlaceBet}
                disabled={isPlacing || !isConnected || (isConnected && chain?.id !== 11155111)}
              >
                {isPlacing ? "Placing Bet..." : "Place Bet"}
              </Button>
              <Button variant="outline" className="w-full bg-transparent" onClick={onClear} disabled={isPlacing}>
                Clear Slip
              </Button>
            </div>

            {/* Info */}
            <p className="mt-4 text-xs text-muted-foreground text-center">
              Bets are settled via Chainlink VRF after match completion
            </p>
          </>
        )}
      </div>
    </Card>
  )
}

"use client"

import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import type { Bet } from "@/hooks/use-betting-state"

interface BetConfirmationModalProps {
  bet: Bet | null
  isOpen: boolean
  isLoading: boolean
  onConfirm: () => void
  onCancel: () => void
}

export function BetConfirmationModal({ bet, isOpen, isLoading, onConfirm, onCancel }: BetConfirmationModalProps) {
  if (!bet) return null

  return (
    <Dialog open={isOpen} onOpenChange={onCancel}>
      <DialogContent className="border border-border">
        <DialogHeader>
          <DialogTitle className="text-foreground">Confirm Your Bet</DialogTitle>
          <DialogDescription>Review your bet details before confirming</DialogDescription>
        </DialogHeader>

        <div className="space-y-4 py-4">
          {/* Match Info */}
          <div className="rounded-lg border border-border bg-yellow-50/50 p-4">
            <h3 className="font-semibold text-foreground">{bet.matchName}</h3>
            <p className="mt-1 text-sm text-muted-foreground">Prediction: {bet.predictionLabel}</p>
          </div>

          {/* Bet Details */}
          <div className="space-y-3">
            <div className="flex justify-between">
              <span className="text-sm text-muted-foreground">Odds</span>
              <span className="font-bold text-primary">{bet.odds.toFixed(2)}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-sm text-muted-foreground">Stake</span>
              <span className="font-bold text-foreground">{bet.amount.toFixed(2)} ETH</span>
            </div>
            <div className="flex justify-between border-t border-border pt-3">
              <span className="text-sm font-semibold text-foreground">Potential Win</span>
              <span className="font-bold text-primary">{bet.potential.toFixed(4)} ETH</span>
            </div>
          </div>

          {/* Terms */}
          <div className="rounded-lg bg-blue-50 p-3 text-xs text-blue-900">
            By confirming, you agree that your bet will be settled via Chainlink VRF after the match is completed.
          </div>
        </div>

        {/* Actions */}
        <div className="flex gap-3">
          <Button variant="outline" className="flex-1 bg-transparent" onClick={onCancel} disabled={isLoading}>
            Cancel
          </Button>
          <Button
            className="flex-1 bg-primary text-primary-foreground hover:bg-primary/90"
            onClick={onConfirm}
            disabled={isLoading}
          >
            {isLoading ? "Confirming..." : "Confirm & Pay"}
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  )
}

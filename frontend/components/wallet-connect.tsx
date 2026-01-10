"use client"

import { Button } from "@/components/ui/button"
import { Wallet, LogOut } from "lucide-react"
import { useState } from "react"

interface WalletConnectProps {
  isConnected: boolean
  setIsConnected: (connected: boolean) => void
}

export function WalletConnect({ isConnected, setIsConnected }: WalletConnectProps) {
  const [address] = useState("0x742d...35a4")
  const [balance] = useState("12,450.00")

  const handleConnect = () => {
    // This would integrate with Web3 wallet (MetaMask, WalletConnect, etc.)
    console.log("[v0] Initiating wallet connection...")
    setIsConnected(true)
  }

  const handleDisconnect = () => {
    setIsConnected(false)
  }

  if (isConnected) {
    return (
      <div className="flex items-center gap-3">
        <div className="hidden md:block text-right">
          <p className="text-sm font-medium">{balance} LEAGUE</p>
          <p className="text-xs text-muted-foreground">{address}</p>
        </div>
        <Button variant="outline" size="sm" onClick={handleDisconnect}>
          <LogOut className="w-4 h-4 mr-2" />
          Disconnect
        </Button>
      </div>
    )
  }

  return (
    <Button onClick={handleConnect} size="lg" className="gap-2">
      <Wallet className="w-4 h-4" />
      Connect Wallet
    </Button>
  )
}

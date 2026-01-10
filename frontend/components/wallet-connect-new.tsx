"use client"

import { ConnectButton } from "@rainbow-me/rainbowkit"
import { Button } from "@/components/ui/button"
import { Wallet, LogOut } from "lucide-react"
import { useAccount, useBalance, useDisconnect } from "wagmi"
import { useContracts } from "@/lib/hooks/useContracts"
import { formatUnits } from "viem"

export function WalletConnect() {
  const { address, isConnected } = useAccount()
  const { disconnect } = useDisconnect()
  const { leagueToken } = useContracts()

  // Get LEAGUE token balance
  const { data: leagueBalance } = useBalance({
    address,
    token: leagueToken?.address,
    query: {
      enabled: !!address && !!leagueToken?.address,
      refetchInterval: 10000, // Refetch every 10 seconds
    },
  })

  if (isConnected && address) {
    return (
      <div className="flex items-center gap-3">
        <div className="hidden md:block text-right">
          <p className="text-sm font-medium">
            {leagueBalance ? `${Number(formatUnits(leagueBalance.value, 18)).toFixed(2)} LEAGUE` : "0.00 LEAGUE"}
          </p>
          <p className="text-xs text-muted-foreground">
            {address.slice(0, 6)}...{address.slice(-4)}
          </p>
        </div>
        <Button variant="outline" size="sm" onClick={() => disconnect()}>
          <LogOut className="w-4 h-4 mr-2" />
          Disconnect
        </Button>
      </div>
    )
  }

  return (
    <ConnectButton.Custom>
      {({ account, chain, openAccountModal, openChainModal, openConnectModal, mounted }) => {
        const ready = mounted
        const connected = ready && account && chain

        return (
          <div
            {...(!ready && {
              "aria-hidden": true,
              style: {
                opacity: 0,
                pointerEvents: "none",
                userSelect: "none",
              },
            })}
          >
            {(() => {
              if (!connected) {
                return (
                  <Button onClick={openConnectModal} size="lg" className="gap-2">
                    <Wallet className="w-4 h-4" />
                    Connect Wallet
                  </Button>
                )
              }

              if (chain.unsupported) {
                return (
                  <Button onClick={openChainModal} variant="destructive" size="lg">
                    Wrong network
                  </Button>
                )
              }

              return (
                <div className="flex gap-2">
                  <Button onClick={openChainModal} variant="outline" size="sm">
                    {chain.hasIcon && (
                      <div
                        style={{
                          background: chain.iconBackground,
                          width: 16,
                          height: 16,
                          borderRadius: 999,
                          overflow: "hidden",
                          marginRight: 8,
                        }}
                      >
                        {chain.iconUrl && (
                          <img alt={chain.name ?? "Chain icon"} src={chain.iconUrl} style={{ width: 16, height: 16 }} />
                        )}
                      </div>
                    )}
                    {chain.name}
                  </Button>

                  <Button onClick={openAccountModal} variant="outline" size="sm">
                    {account.displayName}
                  </Button>
                </div>
              )
            })()}
          </div>
        )
      }}
    </ConnectButton.Custom>
  )
}

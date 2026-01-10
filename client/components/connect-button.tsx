"use client"

import { useAccount, useConnect, useDisconnect, Connector, useConnectors } from "wagmi"
import { Button } from "@/components/ui/button"
import { useEffect, useState } from "react"
// import { useWeb3Modal } from "@web3modal/wagmi/react"

export function ConnectButton() {
  const { address, isConnected, chain } = useAccount()
  // const { open } = useWeb3Modal()
  const { connect,  } = useConnect()
  const { disconnect } = useDisconnect()
  const [mounted, setMounted] = useState(false)
    const connectors = useConnectors()
  useEffect(() => {
    setMounted(true)
  }, [])

  if (!mounted) {
    return <Button className="bg-primary text-primary-foreground">Connect Wallet</Button>
  }

  if (isConnected && address) {
    return (
      <div className="flex items-center gap-2">
        <div className="hidden text-sm text-foreground sm:block">
          {chain?.name && <span className="mr-2 text-xs text-muted-foreground">{chain.name}</span>}
          {address.slice(0, 6)}...{address.slice(-4)}
        </div>
        <Button variant="outline" onClick={() => disconnect()}>
          Disconnect
        </Button>
        
      </div>
    )
  }

  return (
    <div>
      <Button className="bg-primary text-primary-foreground" onClick={() => connect({
        connector: connectors[2],
      })}>
        Connect Wallet
      </Button>

       {connectors.map((connector) => (
    <button key={connector.uid} onClick={() => connect({ connector })}>
      {connector.name}
    </button>
  ))}
    </div>
  )
}

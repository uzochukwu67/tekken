"use client"

import type { ReactNode } from "react"
import { useEffect, useState } from "react"
import { WagmiProvider } from "wagmi"
import { QueryClientProvider } from "@tanstack/react-query"
import { QueryClient } from "@tanstack/react-query"
// import { createWeb3Modal } from "@web3modal/wagmi/react"
import { config } from "@/lib/wagmi-config"

const projectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || "test-project-id"

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false,
      staleTime: 1000 * 60 * 5,
    },
  },
})

let web3ModalInitialized = false

// if (typeof window !== "undefined" && !web3ModalInitialized) {
//   web3ModalInitialized = true
//   createWeb3Modal({
//     wagmiConfig: config,
//     projectId,
//     enableAnalytics: true,
//     allowUnsupportedChain: false,
//   })
// }

export function Providers({ children }: { children: ReactNode }) {
  const [mounted, setMounted] = useState(false)

  useEffect(() => {
    setMounted(true)
  }, [])

  if (!mounted) {
    return <>{children}</>
  }

  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
    </WagmiProvider>
  )
}

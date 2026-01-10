"use client"

import { http, createConfig } from "wagmi"
import { connectorsForWallets } from "@rainbow-me/rainbowkit"
import {
  metaMaskWallet,
  coinbaseWallet,
  walletConnectWallet,
  rainbowWallet,
  injectedWallet,

} from "@rainbow-me/rainbowkit/wallets"
import { supportedChains } from "./chains"

const projectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || "YOUR_PROJECT_ID"

// Configure wallet connectors
const connectors = connectorsForWallets(
  [
    {
      groupName: "Recommended",
      wallets: [metaMaskWallet, coinbaseWallet, injectedWallet, walletConnectWallet, rainbowWallet],
    },
  ],
  {
    appName: "iVirtualz Sports League",
    projectId,
  }
)

// Create wagmi config
export const config = createConfig({
  chains: supportedChains,
  connectors,
  transports: Object.fromEntries(supportedChains.map((chain) => [chain.id, http()])),
  ssr: true,
})

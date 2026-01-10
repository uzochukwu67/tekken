"use client"

import { http, createConfig } from "wagmi"
import { connectorsForWallets } from "@rainbow-me/rainbowkit"
import {
  metaMaskWallet,
  coinbaseWallet,
  walletConnectWallet,
  rainbowWallet,
} from "@rainbow-me/rainbowkit/wallets"
import { supportedChains } from "./chains"

const projectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || "YOUR_PROJECT_ID"

// Configure wallet connectors
const connectors = connectorsForWallets(
  [
    {
      groupName: "Recommended",
      wallets: [metaMaskWallet, coinbaseWallet, walletConnectWallet, rainbowWallet],
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
  transports: {
    [supportedChains[0].id]: http(),
    [supportedChains[1].id]: http(),
  },
  ssr: true,
})

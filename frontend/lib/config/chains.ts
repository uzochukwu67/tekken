import { baseSepolia, base, mainnet, sepolia } from "wagmi/chains"
import type { Chain } from "wagmi/chains"

// Custom chain configurations
export const supportedChains = [baseSepolia, base] as const

export type SupportedChainId = (typeof supportedChains)[number]["id"]

// Chain metadata for UI display
export const chainMetadata: Record<
  number,
  {
    name: string
    shortName: string
    icon: string
    blockExplorer: string
    nativeCurrency: {
      name: string
      symbol: string
      decimals: number
    }
  }
> = {
  [baseSepolia.id]: {
    name: "Base Sepolia",
    shortName: "Base Sepolia",
    icon: "⚡",
    blockExplorer: "https://sepolia.basescan.org",
    nativeCurrency: {
      name: "Ethereum",
      symbol: "ETH",
      decimals: 18,
    },
  },
  [base.id]: {
    name: "Base",
    shortName: "Base",
    icon: "🔵",
    blockExplorer: "https://basescan.org",
    nativeCurrency: {
      name: "Ethereum",
      symbol: "ETH",
      decimals: 18,
    },
  },
}

// Default chain for the app
export const defaultChain = baseSepolia

// Helper to check if chain is supported
export function isSupportedChain(chainId: number | undefined): chainId is SupportedChainId {
  if (!chainId) return false
  return supportedChains.some((chain) => chain.id === chainId)
}

// Get chain by ID
export function getChainById(chainId: number): Chain | undefined {
  return supportedChains.find((chain) => chain.id === chainId)
}

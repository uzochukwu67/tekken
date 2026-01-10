import { baseSepolia, base } from "wagmi/chains"
import type { Address } from "viem"

// Contract addresses for each chain
export type ContractAddresses = {
  gameEngine: Address
  bettingPool: Address
  liquidityPool: Address
  leagueToken: Address
}

// TODO: Update these addresses after deployment
export const contractAddresses: Record<number, ContractAddresses> = {
  [baseSepolia.id]: {
    gameEngine: "0x0000000000000000000000000000000000000000", // Deploy and update
    bettingPool: "0x0000000000000000000000000000000000000000", // Deploy and update
    liquidityPool: "0x0000000000000000000000000000000000000000", // Deploy and update
    leagueToken: "0x0000000000000000000000000000000000000000", // Deploy and update
  },
  [base.id]: {
    gameEngine: "0x0000000000000000000000000000000000000000", // Deploy and update
    bettingPool: "0x0000000000000000000000000000000000000000", // Deploy and update
    liquidityPool: "0x0000000000000000000000000000000000000000", // Deploy and update
    leagueToken: "0x0000000000000000000000000000000000000000", // Deploy and update
  },
}

// Helper to get contract addresses for current chain
export function getContractAddresses(chainId: number | undefined): ContractAddresses | null {
  if (!chainId || !contractAddresses[chainId]) {
    return null
  }
  return contractAddresses[chainId]
}

// Validate if addresses are set (not zero address)
export function areAddressesConfigured(chainId: number | undefined): boolean {
  const addresses = getContractAddresses(chainId)
  if (!addresses) return false

  const zeroAddress = "0x0000000000000000000000000000000000000000"
  return (
    addresses.gameEngine !== zeroAddress &&
    addresses.bettingPool !== zeroAddress &&
    addresses.liquidityPool !== zeroAddress &&
    addresses.leagueToken !== zeroAddress
  )
}

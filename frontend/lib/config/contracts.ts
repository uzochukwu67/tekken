import { baseSepolia, base, sepolia } from "wagmi/chains"
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
  [sepolia.id]: {
    gameEngine: "0x45da13240cEce4ca92BEF34B6955c7883e5Ce9E4", // Ethereum Sepolia - Deployed Jan 4, 2026
    bettingPool: "0x02d49e1e3EE1Db09a7a8643Ae1BCc72169180861", // Ethereum Sepolia
    liquidityPool: "0xD8d4485095f3203Df449D51768a78FfD79e4Ff8E", // Ethereum Sepolia
    leagueToken: "0xf99a4F28E9D1cDC481a4b742bc637Af9e60e3FE5", // Ethereum Sepolia
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

import { baseSepolia, base, sepolia } from "wagmi/chains"
import type { Address } from "viem"

export type ContractAddresses = {
  gameEngine: Address
  bettingPool: Address
  liquidityPool: Address
  leagueToken: Address
}

// Replace these with your deployed addresses after deployment.
export const deployedAddresses: Record<number, ContractAddresses> = {
  [baseSepolia.id]: {
    gameEngine: "0x0000000000000000000000000000000000000000",
    bettingPool: "0x0000000000000000000000000000000000000000",
    liquidityPool: "0x0000000000000000000000000000000000000000",
    leagueToken: "0x0000000000000000000000000000000000000000",
  },
  [base.id]: {
    gameEngine: "0x0000000000000000000000000000000000000000",
    bettingPool: "0x0000000000000000000000000000000000000000",
    liquidityPool: "0x0000000000000000000000000000000000000000",
    leagueToken: "0x0000000000000000000000000000000000000000",
  },
  [sepolia.id]: {
    // Ethereum Sepolia - Deployed Jan 4, 2026
    gameEngine: "0x45da13240cEce4ca92BEF34B6955c7883e5Ce9E4",
    bettingPool: "0x02d49e1e3EE1Db09a7a8643Ae1BCc72169180861",
    liquidityPool: "0xD8d4485095f3203Df449D51768a78FfD79e4Ff8E",
    leagueToken: "0xf99a4F28E9D1cDC481a4b742bc637Af9e60e3FE5",
  },
}

export function getDeployedAddresses(chainId: number | undefined): ContractAddresses | null {
  if (!chainId) return null
  return deployedAddresses[chainId] ?? null
}

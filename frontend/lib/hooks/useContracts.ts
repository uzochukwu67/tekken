import { useChainId } from "wagmi"
import { getContractAddresses } from "@/lib/config/contracts"
import { GameEngineABI, BettingPoolABI, LiquidityPoolABI, LeagueTokenABI } from "@/lib/abis"

export function useContracts() {
  const chainId = useChainId()
  const addresses = getContractAddresses(chainId)

  if (!addresses) {
    return {
      gameEngine: null,
      bettingPool: null,
      liquidityPool: null,
      leagueToken: null,
    }
  }

  return {
    gameEngine: {
      address: addresses.gameEngine,
      abi: GameEngineABI,
    },
    bettingPool: {
      address: addresses.bettingPool,
      abi: BettingPoolABI,
    },
    liquidityPool: {
      address: addresses.liquidityPool,
      abi: LiquidityPoolABI,
    },
    leagueToken: {
      address: addresses.leagueToken,
      abi: LeagueTokenABI,
    },
  }
}

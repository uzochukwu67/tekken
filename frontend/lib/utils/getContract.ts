import type { Abi } from "abitype"
import type { Address } from "viem"
import { useMemo } from "react"
import { useChainId, usePublicClient } from "wagmi"
import { getDeployedAddresses } from "../deployedAddresses"

type ContractDescriptor = {
  address: Address
  abi: Abi
}

// Hook to get contract descriptor (address + abi) for a named contract
export function useContractDescriptor(name: "gameEngine" | "bettingPool" | "liquidityPool" | "leagueToken", abi: Abi): ContractDescriptor | null {
  const chainId = useChainId()
  const publicClient = usePublicClient()

  const descriptor = useMemo(() => {
    const addresses = getDeployedAddresses(chainId)
    if (!addresses) return null
    const address = addresses[name]
    if (!address) return null
    return { address, abi } as ContractDescriptor
  }, [chainId, name, abi])

  return descriptor
}

export default useContractDescriptor

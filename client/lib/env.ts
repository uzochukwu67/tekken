export const getEnvConfig = () => {
  const walletConnectProjectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID

  if (!walletConnectProjectId) {
    console.warn(
      "NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID is not set. Web3Modal may not work properly. Get it from https://cloud.walletconnect.com/",
    )
  }

  return {
    walletConnectProjectId: walletConnectProjectId || "test-project-id",
    bettingContractAddress: process.env.NEXT_PUBLIC_BETTING_CONTRACT_ADDRESS || "",
    chainId: 11155111, // Sepolia testnet
  }
}

export const SEPOLIA_CHAIN_ID = 11155111

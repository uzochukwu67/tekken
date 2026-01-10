export function SetupGuide() {
  return (
    <div className="rounded-lg border border-border bg-blue-50 p-6">
      <h3 className="mb-4 font-bold text-foreground">Setup Required</h3>
      <ul className="space-y-2 text-sm text-muted-foreground">
        <li className="flex gap-2">
          <span>1.</span>
          <span>Get WalletConnect Project ID at https://cloud.walletconnect.com/</span>
        </li>
        <li className="flex gap-2">
          <span>2.</span>
          <span>Add NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID to your environment variables</span>
        </li>
        <li className="flex gap-2">
          <span>3.</span>
          <span>Deploy your betting smart contract to Sepolia testnet</span>
        </li>
        <li className="flex gap-2">
          <span>4.</span>
          <span>Add NEXT_PUBLIC_BETTING_CONTRACT_ADDRESS to environment variables</span>
        </li>
      </ul>
    </div>
  )
}

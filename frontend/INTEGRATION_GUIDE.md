# iVirtualz Frontend Integration Guide

## Overview

This frontend is a fully integrated Web3 application using wagmi, RainbowKit, and Next.js 14+ to interact with the iVirtualz smart contracts on Base Sepolia (and other chains).

## Prerequisites

1. **Node.js 18+** installed
2. **WalletConnect Project ID** - Get one from [https://cloud.walletconnect.com/](https://cloud.walletconnect.com/)
3. **Deployed Smart Contracts** - Contract addresses for your target chain

## Installation

```bash
cd frontend
npm install
```

## Configuration

### 1. Environment Variables

Create a `.env.local` file:

```bash
cp .env.example .env.local
```

Edit `.env.local` and add your WalletConnect project ID:

```
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=your_actual_project_id
```

### 2. Contract Addresses

Update `lib/config/contracts.ts` with your deployed contract addresses:

```typescript
export const contractAddresses: Record<number, ContractAddresses> = {
  [baseSepolia.id]: {
    gameEngine: "0xYourGameEngineAddress",
    bettingPool: "0xYourBettingPoolAddress",
    liquidityPool: "0xYourLiquidityPoolAddress",
    leagueToken: "0xYourLeagueTokenAddress",
  },
}
```

### 3. Chain Configuration

To add additional chains, edit `lib/config/chains.ts`:

```typescript
import { baseSepolia, base, arbitrum } from "wagmi/chains"

export const supportedChains = [baseSepolia, base, arbitrum] as const
```

Then add the corresponding contract addresses in `contracts.ts`.

## Running the Application

### Development

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000)

### Production Build

```bash
npm run build
npm start
```

## Architecture

### Key Features

1. **Multichain Support** - Easily add new chains via configuration
2. **Real-time Event Indexing** - Automatically fetches and watches blockchain events
3. **Optimistic UI Updates** - Transaction states managed with loading/success/error feedback
4. **Dynamic Odds** - Refreshes every 5 seconds during active rounds
5. **Comprehensive Error Handling** - User-friendly error messages via toast notifications

### Folder Structure

```
frontend/
├── app/
│   ├── layout.tsx              # Root layout with Web3 providers
│   ├── page.tsx               # Old mock page (DEPRECATED)
│   └── page-new.tsx           # New integrated page
├── components/
│   ├── betting-interface-new.tsx    # Betting UI with contract calls
│   ├── my-bets-new.tsx             # Bet history and claiming
│   ├── liquidity-pool-new.tsx      # LP deposit/withdraw
│   ├── standings-new.tsx           # Season standings
│   └── wallet-connect-new.tsx      # Wallet connection
├── lib/
│   ├── abis/                   # Contract ABIs
│   │   ├── GameEngine.json
│   │   ├── BettingPool.json
│   │   ├── LiquidityPool.json
│   │   └── LeagueToken.json
│   ├── config/
│   │   ├── chains.ts          # Chain configurations
│   │   ├── contracts.ts       # Contract addresses
│   │   └── wagmi.ts           # Wagmi configuration
│   └── hooks/
│       ├── useContracts.ts           # Contract instances
│       ├── useGameData.ts            # Game state reads
│       ├── useBettingData.ts         # Betting pool reads
│       ├── useLiquidityData.ts       # LP pool reads
│       ├── useGameEngineEvents.ts    # Game events
│       └── useBettingPoolEvents.ts   # Betting events
└── providers/
    └── web3-provider.tsx      # Web3 context provider
```

## Contract Interactions

### Reading Data

All contract read operations use wagmi's `useReadContract` and `useReadContracts` hooks:

```typescript
import { useCurrentRound } from "@/lib/hooks/useGameData"

const { currentRoundId, refetch } = useCurrentRound()
```

### Writing Data (Transactions)

Two-step process for ERC20 approvals:

```typescript
import { useWriteContract } from "wagmi"
import { useContracts } from "@/lib/hooks/useContracts"

const { leagueToken, bettingPool } = useContracts()
const { writeContract } = useWriteContract()

// 1. Approve
writeContract({
  address: leagueToken.address,
  abi: leagueToken.abi,
  functionName: "approve",
  args: [bettingPool.address, amount],
})

// 2. Place bet
writeContract({
  address: bettingPool.address,
  abi: bettingPool.abi,
  functionName: "placeBet",
  args: [roundId, amount, predictions],
})
```

### Event Listening

Real-time event watching:

```typescript
import { useBettingPoolEvents } from "@/lib/hooks/useBettingPoolEvents"

const { betPlacedEvents, betSettledEvents, userBets } = useBettingPoolEvents(userAddress)

// Events automatically update in real-time
```

## Key Components

### BettingInterfaceNew

- Fetches 10 matches per round
- Displays live odds (updates every 5s)
- Calculates potential payout with pool bonus
- Handles approve → placeBet flow

### MyBetsNew

- Fetches user's bet history
- Shows match results when settled
- Allows claiming winnings
- Real-time status updates

### LiquidityPoolNew

- Displays pool stats (liquidity, utilization, multiplier)
- Deposit/withdraw functionality
- 15-minute cooldown enforcement
- Share value calculation

### StandingsNew

- Fetches all 20 teams
- Displays sorted standings
- Real-time updates after round settlements

## Data Refresh Intervals

- **Current Round**: 5 seconds
- **Live Odds**: 5 seconds
- **User Balances**: 10 seconds
- **Bet History**: 10 seconds
- **LP Stats**: 10 seconds
- **Standings**: On-demand (refetches after events)

## Transaction Flow Examples

### Placing a Bet

1. User selects predictions (adds to bet slip)
2. User enters bet amount
3. User clicks "Approve LEAGUE"
4. Wallet prompts for approval
5. Approval transaction confirmed
6. "Place Bet" button becomes enabled
7. User clicks "Place Bet"
8. Wallet prompts for bet transaction
9. Bet transaction confirmed
10. BetPlaced event emitted
11. UI updates with new bet in history

### Depositing Liquidity

1. User enters deposit amount
2. User clicks "Approve LEAGUE"
3. Approval transaction confirmed
4. User clicks "Deposit Liquidity"
5. Deposit transaction confirmed
6. LP shares minted
7. 15-minute cooldown starts
8. UI shows updated position

### Claiming Winnings

1. Round settles (VRF results)
2. MatchResult events emitted
3. User sees "WON" badge on bet
4. User clicks "Claim Winnings"
5. settleBet transaction sent
6. Payout transferred
7. Bet status updated to settled

## Error Handling

All errors are displayed via toast notifications:

```typescript
import { toast } from "sonner"

try {
  await writeContract(...)
  toast.success("Transaction sent!")
} catch (error) {
  toast.error(error?.message || "Transaction failed")
}
```

## Testing

### Local Testing (Anvil)

1. Start Anvil: `anvil --fork-url https://sepolia.base.org`
2. Deploy contracts to Anvil
3. Update contract addresses to localhost
4. Add Anvil to supported chains

### Testnet Testing

1. Deploy contracts to Base Sepolia
2. Update contract addresses
3. Get testnet ETH from faucet
4. Mint LEAGUE tokens
5. Test all flows

## Deployment

### Vercel (Recommended)

```bash
npm run build
vercel --prod
```

Set environment variables in Vercel dashboard:
- `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID`

### Other Platforms

The app is a standard Next.js 14 application and can be deployed to:
- Netlify
- Railway
- AWS Amplify
- Self-hosted with Docker

## Common Issues

### "Wrong network" error
- User must switch to Base Sepolia in their wallet
- RainbowKit will prompt them automatically

### "Insufficient allowance" error
- User needs to approve LEAGUE tokens first
- Check approval transaction was confirmed

### Odds not updating
- Check that contract addresses are correct
- Verify chain ID matches deployed contracts
- Check console for RPC errors

### Events not appearing
- Event indexing looks back 10,000 blocks
- Very old events may not appear
- Consider implementing a backend indexer for historical data

## Performance Optimization

### Current Optimizations
- Parallel contract calls with `useReadContracts`
- Stale-while-revalidate caching (30s)
- Event deduplication
- Minimal re-renders with proper dependencies

### Future Improvements
- Implement The Graph for event indexing
- Add pagination for bet history
- Cache computed values (standings sorting)
- Optimize bundle size with dynamic imports

## Security Considerations

1. **Never store private keys in frontend**
2. **Validate all user inputs**
3. **Check transaction status before UI updates**
4. **Warn users before signing transactions**
5. **Display clear transaction details**

## Support

For issues or questions:
- Check smart contract documentation in `/CONTRACTS.md`
- Review test files for usage examples
- Join Discord/Telegram (add links)

## License

MIT

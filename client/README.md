# ivisualz - Premier League Betting dApp

A decentralized sports betting platform for Premier League matches, powered by Chainlink VRF randomness and smart contracts on Sepolia testnet.

## Features

- **Wallet Connection**: Connect via wagmi with multiple wallet options (MetaMask, WalletConnect, Injected)
- **Betting Options**: Predict Home Win, Draw, or Away Win for each match
- **Smart Contracts**: Automated bet placement and settlement via Ethereum smart contracts
- **Chainlink VRF**: Fair and verifiable randomness for match result determination
- **Real-time Odds**: Dynamic odds based on betting pool participation
- **Analytics Dashboard**: Track betting performance, win rate, and ROI
- **Bet History**: Complete history of all placed bets with results
- **Yellow Design System**: Clean, modern UI with white background and yellow accents

## Tech Stack

- **Framework**: Next.js 16 with App Router
- **Web3**: wagmi, Viem, Web3Modal
- **Blockchain**: Ethereum Sepolia Testnet
- **Smart Contracts**: Solidity (Chainlink VRF integration)
- **UI**: shadcn/ui, Tailwind CSS v4
- **State Management**: React Hooks, TanStack Query

## Getting Started

### Prerequisites

- Node.js 18+
- A Web3 wallet (MetaMask recommended)
- Sepolia ETH for testing

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   npm install
   ```

3. Create `.env.local`:
   ```
   NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=your_walletconnect_project_id
   NEXT_PUBLIC_BETTING_CONTRACT_ADDRESS=your_contract_address
   ```

4. Run development server:
   ```bash
   npm run dev
   ```

5. Open [http://localhost:3000](http://localhost:3000)

## Pages

- `/` - Landing page with platform overview
- `/betting` - Main betting dashboard with match cards and slip
- `/analytics` - Detailed betting analytics and statistics
- `/history` - Complete bet history and results

## Smart Contract Integration

The dApp interfaces with a Solidity smart contract that:

1. Accepts bet placements with match ID and prediction
2. Stores bet information on-chain
3. Integrates Chainlink VRF for randomness
4. Automatically settles bets based on match results
5. Transfers winnings to successful bettors

### Contract ABI Reference

Key functions:
- `placeBet(matchId, prediction, amount)` - Place a new bet
- `getMatches()` - Retrieve all available matches
- `getUserBets(address)` - Get user's bet history
- `settleBet(betId, vrfResult)` - Settle bet with VRF result

## Environment Variables

| Variable | Description |
|----------|-------------|
| `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID` | WalletConnect v2 project ID |
| `NEXT_PUBLIC_BETTING_CONTRACT_ADDRESS` | Deployed contract address on Sepolia |

## Building for Production

```bash
npm run build
npm run start
```

## Deployment

Deploy on Vercel:

```bash
vercel --prod
```

## Security Considerations

- All bets are non-custodial - you maintain control of your wallet
- Smart contracts should be audited before production use
- Chainlink VRF provides cryptographically verifiable randomness
- Consider implementing bet limits and cooling-off periods

## Contributing

Contributions welcome! Please follow existing code style and test thoroughly.

## License

MIT

## Support

For issues and questions, please open a GitHub issue or contact the team.

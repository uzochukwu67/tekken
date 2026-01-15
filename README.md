# iVirtualz Sports League

A fully on-chain sports prediction protocol with dynamic odds, liquidity mining, and provably-fair VRF results.

## 🎯 Overview

iVirtualz is a decentralized sports betting platform built on Base (and Base Sepolia testnet) that features:

- **Dynamic Odds System**: Real-time odds that adjust based on betting volume and team statistics
- **Liquidity Mining**: LP providers earn 25% of losing bets with instant withdrawals
- **Pool Bonus**: Bettors receive up to 2.71x bonus (1.1^n) based on prediction count
- **VRF-Powered Results**: Chainlink VRF ensures provably-fair match outcomes
- **Multichain Ready**: Easily deployable to any EVM chain

## 📁 Project Structure

```
web3/
├── src/                          # Smart contracts (Solidity)
│   ├── GameEngine.sol           # Match generation & VRF
│   ├── BettingPool.sol          # Betting logic & odds
│   ├── LiquidityPool.sol        # LP management
│   └── LeagueToken.sol          # ERC20 token
├── test/                         # Comprehensive tests
├── frontend/                     # Next.js Web3 app
│   ├── app/                     # Pages
│   ├── components/              # React components
│   ├── lib/                     # Hooks, config, ABIs
│   └── providers/               # Web3 providers
├── script/                       # Deployment scripts
└── docs/                         # Documentation
```

## 🚀 Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js 18+](https://nodejs.org/)
- [Git](https://git-scm.com/)

### Smart Contracts

```bash
# Install dependencies
forge install

# Run tests
forge test

# Run specific test
forge test --match-test testDynamicOdds -vvv

# Deploy to testnet (after configuring .env)
forge script script/Deploy.s.sol --rpc-url base_sepolia --broadcast
```

### Frontend

```bash
cd frontend

# Install dependencies
npm install

# Configure environment
cp .env.example .env.local
# Edit .env.local with your WalletConnect project ID

# Update contract addresses in lib/config/contracts.ts

# Run development server
npm run dev

# Build for production
npm run build
```

## 📖 Documentation

### Smart Contracts
- **[CONTRACTS.md](CONTRACTS.md)** - Complete contract documentation
- **[game.md](game.md)** - Game mechanics and rules

### Frontend Integration
- **[INTEGRATION_GUIDE.md](frontend/INTEGRATION_GUIDE.md)** - Developer guide
- **[INTEGRATION_COMPLETE.md](INTEGRATION_COMPLETE.md)** - Integration summary

### Deployment
- **[DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)** - Step-by-step deployment

## 🎮 How It Works

### For Bettors

1. **Connect Wallet** - MetaMask, Coinbase, WalletConnect
2. **Select Predictions** - Choose HOME/AWAY/DRAW for matches
3. **Place Bet** - Approve LEAGUE tokens, submit bet
4. **Wait for Settlement** - VRF generates match results
5. **Claim Winnings** - If correct, claim payout with pool bonus

### For Liquidity Providers

1. **Deposit LEAGUE** - Minimum 1,000 tokens for first deposit
2. **Receive LP Shares** - Proportional to pool contribution
3. **Earn Revenue** - 25% of losing bets distributed to LPs
4. **Withdraw Anytime** - After 15-minute cooldown

### Revenue Distribution

When a bettor loses:
- **25%** → LP Pool (distributed to liquidity providers)
- **2%** → Season Pool (winner-takes-all at season end)
- **73%** → Protocol Reserve (covers winning payouts)

## 🔧 Smart Contract Architecture

### GameEngine
- Manages 20 teams with attack/defense ratings
- Creates rounds with 10 matches
- Uses Chainlink VRF for random results
- Tracks season standings

### BettingPool
- Calculates dynamic odds based on volume
- Handles bet placement and settlement
- Manages revenue distribution
- Integrates with LiquidityPool for bonuses

### LiquidityPool
- ERC20 LP shares with deposit/withdraw
- 15-minute withdrawal cooldown
- Pool multiplier calculation
- Reserve management

### LeagueToken
- Standard ERC20 token
- Used for all platform transactions

## 🧪 Testing

Comprehensive test suite covering:

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific category
forge test --match-path test/BettingPool.t.sol

# Gas report
forge test --gas-report
```

### Test Coverage
- ✅ Unit tests for all contracts
- ✅ Integration tests (betting flow)
- ✅ Profitability simulations
- ✅ Security edge cases
- ✅ Dynamic odds calculations
- ✅ VRF mocking

## 🌐 Frontend Stack

- **Framework**: Next.js 14+ (App Router)
- **Web3**: wagmi v2 + viem
- **Wallet**: RainbowKit
- **UI**: shadcn/ui + Tailwind CSS
- **State**: TanStack Query
- **Notifications**: Sonner (toasts)

### Key Features
- Real-time odds updates (5s interval)
- Comprehensive event indexing
- Transaction state management
- Mobile-responsive design
- Dark mode support

## 🔐 Security

### Implemented Protections
- ✅ Reentrancy guards on all state changes
- ✅ Integer overflow protection (Solidity 0.8+)
- ✅ Max bet cap (100,000 LEAGUE)
- ✅ LP withdrawal cooldown (15 minutes)
- ✅ Emergency pause mechanism
- ✅ VRF timeout fallback (2 hours)
- ✅ Reserve validation before payouts

### Security Audit Recommendations
Before mainnet launch:
1. Professional security audit
2. Bug bounty program
3. Multisig for admin functions
4. Time-delayed upgrades
5. Insurance fund for protocol reserve

## 📊 Contract Addresses

### Base Sepolia (Testnet)
```
GameEngine:    0x... (update after deployment)
BettingPool:   0x...
LiquidityPool: 0x...
LeagueToken:   0x...
```

### Base (Mainnet)
```
Coming soon...
```

## 🛠️ Development

### Smart Contract Development

```bash
# Compile
forge build

# Format
forge fmt

# Coverage
forge coverage

# Local testnet
anvil
```

### Frontend Development

```bash
cd frontend

# Type checking
npm run build

# Linting
npm run lint
```

## 🚢 Deployment

See [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) for complete deployment guide.

### Quick Deploy (Testnet)

1. **Deploy Contracts**
```bash
# Configure .env with private key and RPC
forge script script/Deploy.s.sol \
  --rpc-url base_sepolia \
  --broadcast \
  --verify
```

2. **Update Frontend**
```bash
# Edit frontend/lib/config/contracts.ts with addresses
# Edit frontend/.env.local with WalletConnect ID
cd frontend
vercel --prod
```

## 📈 Roadmap

### Phase 1: Testnet Launch ✅
- [x] Core contracts development
- [x] Comprehensive testing
- [x] Frontend integration
- [x] Documentation

### Phase 2: Testnet Beta (Current)
- [ ] Deploy to Base Sepolia
- [ ] Public beta testing
- [ ] Community feedback
- [ ] Bug fixes & optimizations

### Phase 3: Mainnet Preparation
- [ ] Security audit
- [ ] Bug bounty program
- [ ] Marketing campaign
- [ ] Liquidity incentives

### Phase 4: Mainnet Launch
- [ ] Deploy to Base mainnet
- [ ] Liquidity mining rewards
- [ ] Season 1 kickoff
- [ ] Mobile app

### Phase 5: Expansion
- [ ] Additional sports
- [ ] NFT team ownership
- [ ] Governance token
- [ ] DAO formation

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

MIT License - see LICENSE for details

## 🔗 Links

- **Documentation**: [CONTRACTS.md](CONTRACTS.md)
- **Integration Guide**: [INTEGRATION_GUIDE.md](frontend/INTEGRATION_GUIDE.md)
- **Deployment Guide**: [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)
- **Website**: Coming soon
- **Discord**: Coming soon
- **Twitter**: Coming soon

## ⚠️ Disclaimer

This project is experimental software. Use at your own risk. Not audited for production use. Not financial advice.

## 🙏 Acknowledgments

Built with:
- Foundry
- OpenZeppelin
- Chainlink VRF
- Base (Coinbase L2)
- Next.js
- wagmi
- RainbowKit

---

**Status**: 🟢 Integration Complete - Ready for testnet deployment

For support, please open an issue on GitHub or join our Discord community.
"# packy" 

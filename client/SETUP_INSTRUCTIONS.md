# ivisualz Betting dApp - Complete Setup Guide

Welcome to ivisualz, a decentralized Premier League betting platform! This guide will walk you through setting up and deploying the application.

## Quick Start

### 1. Prerequisites

- Node.js 18+ installed
- A Web3 wallet (MetaMask recommended)
- Code editor (VS Code recommended)
- Git for version control

### 2. Installation

```bash
# Clone the repository (or extract the downloaded code)
cd ivisualz

# Install dependencies
npm install

# Create environment variables file
cp .env.example .env.local
```

### 3. Configure Environment

Edit `.env.local` and add your configuration:

```env
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=your_walletconnect_project_id
NEXT_PUBLIC_BETTING_CONTRACT_ADDRESS=0x...your_contract_address
```

#### Getting WalletConnect Project ID

1. Go to https://cloud.walletconnect.com/
2. Sign up or log in
3. Create a new project
4. Copy the Project ID
5. Paste into `.env.local`

### 4. Deploy Smart Contract

Before the dApp can work, you need to deploy a betting smart contract to Sepolia:

```solidity
// Example contract structure (deploy your own version)
pragma solidity ^0.8.0;

contract PremierLeagueBetting {
    // Implements placeBet, getMatches, settle logic
    // Must integrate Chainlink VRF for randomness
}

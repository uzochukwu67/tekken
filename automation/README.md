# iVirtualz Game Automation Bot

Automated game round management for iVirtualz smart contracts on Ethereum Sepolia.

## What It Does

This Node.js bot continuously monitors the GameEngine contract and automatically:

1. **Starts new rounds** when previous round settles
2. **Requests VRF** after round duration (15 minutes)
3. **Waits for settlement** from Chainlink VRF (1-5 minutes)
4. **Repeats for 36 rounds** until season completes
5. **Starts new season** when previous season ends (optional)

## Prerequisites

- Node.js v18+ installed
- Ethereum Sepolia ETH in wallet (for gas)
- GameEngine added as VRF consumer
- VRF subscription funded with LINK

## Quick Start

### 1. Install Dependencies

```bash
cd automation
npm install
```

### 2. Configure Environment

```bash
cp .env.example .env
```

Edit `.env` with your values:

```bash
# RPC Configuration
SEPOLIA_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com

# Wallet (Use dedicated wallet with minimal funds!)
PRIVATE_KEY=0x...

# Contract Addresses (Already set for Sepolia deployment)
GAME_ENGINE_ADDRESS=0x45da13240cEce4ca92BEF34B6955c7883e5Ce9E4
BETTING_POOL_ADDRESS=0x02d49e1e3EE1Db09a7a8643Ae1BCc72169180861
LIQUIDITY_POOL_ADDRESS=0xD8d4485095f3203Df449D51768a78FfD79e4Ff8E
LEAGUE_TOKEN_ADDRESS=0xf99a4F28E9D1cDC481a4b742bc637Af9e60e3FE5

# Bot Configuration
ROUND_DURATION_MINUTES=15
CHECK_INTERVAL_SECONDS=30
AUTO_START_SEASON=true
```

### 3. Test Connection

```bash
npm test
```

### 4. Run Bot

```bash
npm start
```

## Bot Behavior

### Automatic Operations

```
Check every 30 seconds:
  ↓
Is there a season?
  No → Start season (if AUTO_START_SEASON=true)
  Yes ↓
  ↓
Is there a round?
  No → Start round 1
  Yes ↓
  ↓
Is round settled?
  Yes → Start next round (or end season if round 36)
  No ↓
  ↓
Is round duration elapsed (15 min)?
  No → Wait and check again in 30s
  Yes ↓
  ↓
Is VRF requested?
  No → Request VRF
  Yes → Wait for Chainlink to fulfill
```

### Expected Timeline (15-minute rounds)

| Time | Action | Who |
|------|--------|-----|
| 0:00 | Start Round 1 | Bot |
| 15:00 | Request VRF | Bot |
| 16:00 | VRF Fulfilled, Round Settled | Chainlink |
| 16:05 | Start Round 2 | Bot |
| ... | Repeat 36 times | ... |
| 9:36:00 | Round 36 settled | Chainlink |
| 9:36:05 | Season ends automatically | Contract |
| 9:36:10 | Start new season | Bot (if AUTO_START_SEASON=true) |

## Monitoring

### Console Output

Bot logs all actions in real-time:

```
2024-01-04 10:30:00 [info]: 🤖 Starting iVirtualz Game Automation Bot...
2024-01-04 10:30:01 [info]: ✅ Connected to RPC: https://ethereum-sepolia-rpc.publicnode.com
2024-01-04 10:30:02 [info]: ✅ Wallet: 0x05f463129c9ce4Efb331c45b2F1A6a8E095c790D
2024-01-04 10:30:03 [info]: 💰 Balance: 0.05 ETH
2024-01-04 10:30:04 [info]: ✅ Connected to GameEngine: 0x45da13240cEce4ca92BEF34B6955c7883e5Ce9E4
2024-01-04 10:30:05 [info]: 📍 Current Season: 1
2024-01-04 10:30:06 [info]: 📍 Current Round: 3
2024-01-04 10:30:07 [info]: ⏰ Waiting for round duration: 10 min 5 sec remaining
```

### Log Files

All logs are saved to:
- `logs/combined.log` - All events
- `logs/error.log` - Errors only

### Discord Alerts (Optional)

Set up Discord webhook for remote monitoring:

```bash
ENABLE_DISCORD_ALERTS=true
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
```

Bot will send alerts for:
- ✅ Bot started
- 🏁 Round started
- 🎲 VRF requested
- ✅ Round settled
- 🏆 Season completed
- ❌ Errors

## Safety Features

### Error Handling
- Automatically retries on transient errors
- Logs all errors for debugging
- Continues running despite individual failures

### Gas Protection
- Max gas price limit (default: 50 Gwei)
- Configurable gas limits for each operation
- Balance monitoring (warns if < 0.01 ETH)

### State Recovery
- Syncs with contract on startup
- Recovers from bot restarts
- No manual intervention needed

## Stopping the Bot

Press `Ctrl+C` to stop gracefully. Bot will:
1. Finish current operation
2. Log shutdown
3. Send Discord alert (if enabled)
4. Exit cleanly

## Troubleshooting

### Bot doesn't start rounds

**Check:**
1. Wallet has Sepolia ETH (>0.01)
2. Wallet is owner of GameEngine
3. Previous round is settled
4. Season is active and not complete

**Fix:**
```bash
# Check contract state manually
cast call $GAME_ENGINE_ADDRESS "getCurrentRound()" --rpc-url $SEPOLIA_RPC_URL
cast call $GAME_ENGINE_ADDRESS "isRoundSettled(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL
```

### VRF not fulfilling

**Check:**
1. GameEngine added to VRF subscription
2. VRF subscription funded with LINK (10+)
3. Chainlink VRF dashboard: https://vrf.chain.link/sepolia

**Emergency Fix (after 2 hours):**
```bash
cast send $GAME_ENGINE_ADDRESS \
  "emergencySettleRound(uint256,uint256)" \
  $ROUND_ID 12345 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### RPC errors

**Try alternative RPC:**
```bash
# Alchemy (free tier)
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR-API-KEY

# Infura
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR-API-KEY
```

## Advanced Configuration

### Adjust Round Duration

Change in `.env`:
```bash
ROUND_DURATION_MINUTES=60  # 1 hour rounds for production
```

**Note:** Contract default is 15 minutes. This setting tells the bot when to request VRF.

### Disable Auto Season Start

```bash
AUTO_START_SEASON=false
```

Bot will stop after season ends, requiring manual restart.

### Custom Gas Limits

```bash
MAX_GAS_PRICE_GWEI=100          # Higher for faster confirmations
GAS_LIMIT_START_ROUND=300000    # Increase if transactions fail
GAS_LIMIT_REQUEST_VRF=200000
```

## Production Deployment

### Running on VPS

1. **Copy files to VPS:**
   ```bash
   scp -r automation/ user@your-vps:/home/user/
   ```

2. **Install Node.js:**
   ```bash
   curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
   sudo apt-get install -y nodejs
   ```

3. **Install PM2:**
   ```bash
   npm install -g pm2
   ```

4. **Start with PM2:**
   ```bash
   cd automation
   npm install
   pm2 start gameBot.js --name ivirtualz-bot
   pm2 save
   pm2 startup  # Enable auto-restart on reboot
   ```

5. **Monitor:**
   ```bash
   pm2 logs ivirtualz-bot
   pm2 monit
   ```

### Running with Docker

```dockerfile
# Dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
CMD ["node", "gameBot.js"]
```

```bash
# Build and run
docker build -t ivirtualz-bot .
docker run -d --name ivirtualz --restart unless-stopped ivirtualz-bot
```

## Security Best Practices

### Wallet Security
- ✅ Use dedicated wallet (not your main wallet)
- ✅ Only fund with minimal ETH needed (~0.1 ETH)
- ✅ Store private key in environment variable, not code
- ✅ Never commit `.env` to git
- ✅ Use `.gitignore` to exclude sensitive files

### Operational Security
- Monitor bot logs daily
- Set up alerts for errors
- Check wallet balance weekly
- Backup logs monthly
- Update dependencies regularly

## Cost Estimates

### Sepolia Testnet (Free)
- Gas: Free (testnet ETH)
- Total cost: $0

### Ethereum Mainnet (Future)
- startRound(): ~200k gas
- requestMatchResults(): ~100k gas
- Total per round: ~300k gas
- Per day (96 rounds @ 15 min): 28.8M gas
- **Cost @ 20 Gwei:** ~0.576 ETH/day (~$1,150/day)
- **Cost @ 1 hour rounds:** ~0.144 ETH/day (~$288/day)

**Recommendation:** Use 1-hour rounds for mainnet to reduce costs by 75%.

## Support

For issues or questions:
1. Check logs in `logs/` directory
2. Review this README
3. Check smart contract state with `cast`
4. Open issue on GitHub

## License

MIT

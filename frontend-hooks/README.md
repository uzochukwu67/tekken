# Frontend Hooks - Complete Integration Guide

Complete Wagmi v2 hooks for the Betting System smart contracts.

## 📁 Files

- **`betting-hooks.tsx`** - All hooks for reading and writing to contracts
- **`example-components.tsx`** - Example React components showing usage patterns
- **`README.md`** - This file

## 🚀 Quick Start

### 1. Install Dependencies

```bash
npm install wagmi viem @tanstack/react-query
# or
yarn add wagmi viem @tanstack/react-query
```

### 2. Copy Files

Copy `betting-hooks.tsx` and `example-components.tsx` into your project:

```bash
cp frontend-hooks/betting-hooks.tsx src/hooks/
cp frontend-hooks/example-components.tsx src/components/examples/
```

### 3. Update Contract Addresses

Edit `betting-hooks.tsx` and update the `CONTRACTS` constant with your deployed addresses:

```typescript
export const CONTRACTS: Record<AppChainKey, {...}> = {
  sepolia: {
    BettingCore: "0x...", // YOUR DEPLOYED ADDRESS
    LiquidityCore: "0x...", // YOUR DEPLOYED ADDRESS
    GameCore: "0x...", // YOUR DEPLOYED ADDRESS
    USDC: "0x...", // USDC ADDRESS ON SEPOLIA
    USDT: "0x...", // USDT ADDRESS ON SEPOLIA (if applicable)
  },
  // ... other chains
};
```

### 4. Setup Wagmi Config

Create a `wagmi.config.ts` file:

```typescript
import { createConfig, http } from "wagmi";
import { sepolia, mainnet } from "wagmi/chains";
import { injected, walletConnect } from "wagmi/connectors";

export const config = createConfig({
  chains: [sepolia, mainnet],
  connectors: [
    injected(),
    walletConnect({ projectId: "YOUR_WALLETCONNECT_PROJECT_ID" }),
  ],
  transports: {
    [sepolia.id]: http(),
    [mainnet.id]: http(),
  },
});
```

### 5. Wrap App with Providers

In your `_app.tsx` or `layout.tsx`:

```typescript
import { WagmiProvider } from "wagmi";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { config } from "./wagmi.config";

const queryClient = new QueryClient();

function App({ Component, pageProps }: AppProps) {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <Component {...pageProps} />
      </QueryClientProvider>
    </WagmiProvider>
  );
}
```

---

## 📖 Hook Reference

### Betting Hooks

#### Read Hooks

##### `useCurrentRound()`
Get the current active round ID.

```typescript
const { data: roundId, isLoading } = useCurrentRound();
```

**Returns**: `bigint | undefined`

---

##### `useRoundSummary(roundId)`
Get detailed information about a round.

```typescript
const { data: summary } = useRoundSummary(roundId);
```

**Parameters**:
- `roundId: bigint` - The round ID to query

**Returns**:
```typescript
{
  roundId: bigint;
  seeded: boolean;
  settled: boolean;
  roundStartTime: bigint;
  roundEndTime: bigint;
  totalBetVolume: bigint;
  totalBetCount: bigint;
  parlayCount: bigint;
}
```

---

##### `useOdds(roundId, matchIndex, outcome)`
Get odds for a specific match outcome.

```typescript
const { data: odds } = useOdds(roundId, BigInt(0), 1); // Home win for match 0
```

**Parameters**:
- `roundId: bigint` - The round ID
- `matchIndex: bigint` - Match index (0-9)
- `outcome: number` - Outcome (1=Home, 2=Away, 3=Draw)

**Returns**: `bigint` (odds in 1e18 format, e.g., 1.5e18 = 1.5x)

---

##### `useMatchOdds(roundId, matchIndex)`
Get all three odds (home, away, draw) for a match.

```typescript
const { homeOdds, awayOdds, drawOdds, isLoading } = useMatchOdds(roundId, BigInt(0));
```

**Returns**:
```typescript
{
  homeOdds: bigint | undefined;
  awayOdds: bigint | undefined;
  drawOdds: bigint | undefined;
  isLoading: boolean;
  refetch: () => void;
}
```

---

##### `useBet(betId)`
Get detailed information about a specific bet.

```typescript
const { data: bet } = useBet(BigInt(123));
```

**Returns**:
```typescript
{
  betId: bigint;
  bettor: Address;
  token: Address;
  amount: bigint;
  roundId: bigint;
  legCount: number;
  parlayMultiplier: bigint;
  potentialPayout: bigint;
  actualPayout: bigint;
  status: BetStatus; // 0=Active, 1=Won, 2=Lost, 3=Cancelled
  placedAt: bigint;
  predictions: Array<{
    matchIndex: bigint;
    predictedOutcome: number;
    amountInPool: bigint;
  }>;
}
```

---

##### `useUserClaimable(userAddress?)`
Get user's claimable winnings.

```typescript
const { data: claimable } = useUserClaimable();
// or with specific address:
const { data: claimable } = useUserClaimable("0x...");
```

**Returns**: `[totalClaimable: bigint, betIds: bigint[]]`

---

#### Write Hooks

##### `usePlaceBet()`
Place a bet on match(es).

```typescript
const placeBet = usePlaceBet();

await placeBet(
  "0x..." as `0x${string}`, // token address (USDC)
  parseUnits("100", 6),      // amount (100 USDC)
  [0n, 3n, 7n],              // match indices
  [1, 2, 1]                  // predictions (Home, Away, Home)
);
```

**Parameters**:
- `token: Address` - Token to bet with (USDC/USDT)
- `amount: bigint` - Bet amount in wei (for USDC use 6 decimals)
- `matchIndices: bigint[]` - Array of match indices (0-9)
- `predictions: number[]` - Array of outcomes (1-3)

---

##### `useCancelBet()`
Cancel an active bet.

```typescript
const cancelBet = useCancelBet();

await cancelBet(BigInt(123)); // Cancel bet #123
```

---

##### `useClaimWinnings()`
Claim winnings for a single bet.

```typescript
const claimWinnings = useClaimWinnings();

await claimWinnings(BigInt(123)); // Claim bet #123
```

---

##### `useBatchClaim()`
Claim winnings for multiple bets at once.

```typescript
const batchClaim = useBatchClaim();

await batchClaim([123n, 456n, 789n]); // Claim multiple bets
```

---

##### `usePlaceBetWithApproval()`
Place bet with automatic token approval (composite hook).

```typescript
const placeBetWithApproval = usePlaceBetWithApproval();

// Automatically approves USDC if needed, then places bet
await placeBetWithApproval(
  usdcAddress,
  parseUnits("100", 6),
  [0n, 3n],
  [1, 2]
);
```

---

### Liquidity Provider Hooks

#### Read Hooks

##### `useLPPosition(token, userAddress?)`
Get user's LP position for a specific token.

```typescript
const { data: position } = useLPPosition(usdcAddress);
```

**Returns**:
```typescript
{
  shares: bigint;          // LP shares owned
  shareValue: bigint;      // Current value in tokens
  sharePercentage: bigint; // Percentage of pool (basis points)
  totalDeposited: bigint;  // Total ever deposited
  totalWithdrawn: bigint;  // Total ever withdrawn
  profitLoss: bigint;      // Int256 (can be negative)
}
```

---

##### `usePoolUtilization(token)`
Get pool statistics and utilization.

```typescript
const { data: stats } = usePoolUtilization(usdcAddress);
```

**Returns**: `[totalLiquidity, lockedLiquidity, availableLiquidity, utilizationBps]`

---

##### `useLPPreview(token, amount)`
Preview shares you'll receive for a deposit.

```typescript
const { data: preview } = useLPPreview(usdcAddress, parseUnits("1000", 6));
```

**Returns**: `[poolAddress, expectedShares]`

---

##### `useTotalValueLocked()`
Get total value locked across all pools.

```typescript
const { data: tvl } = useTotalValueLocked();
```

**Returns**: `[totalTVL, tokens[], tvlPerToken[]]`

---

#### Write Hooks

##### `useAddLiquidity()`
Add liquidity to pool.

```typescript
const addLiquidity = useAddLiquidity();

await addLiquidity(usdcAddress, parseUnits("1000", 6));
```

---

##### `useRemoveLiquidity()`
Remove liquidity from pool.

```typescript
const removeLiquidity = useRemoveLiquidity();

await removeLiquidity(usdcAddress, parseUnits("500", 6)); // 500 shares
```

---

##### `useAddLiquidityWithApproval()`
Add liquidity with automatic token approval.

```typescript
const addLiquidityWithApproval = useAddLiquidityWithApproval();

await addLiquidityWithApproval(usdcAddress, parseUnits("1000", 6));
```

---

### Utility Hooks

##### `useTokenBalance(token)`
Get user's token balance.

```typescript
const { data: balance } = useTokenBalance(usdcAddress);
```

---

##### `useTokenAllowance(token, spender)`
Check token allowance.

```typescript
const { data: allowance } = useTokenAllowance(usdcAddress, bettingCoreAddress);
```

---

##### `useApproveToken()`
Approve token spending.

```typescript
const approveToken = useApproveToken();

await approveToken(usdcAddress, bettingCoreAddress, parseUnits("100", 6));
```

---

### Event Listener Hooks

##### `useBetPlacedEvents(callback)`
Listen for new bets being placed.

```typescript
useBetPlacedEvents((event) => {
  console.log("New bet placed:", event);
  // Refresh UI, show notification, etc.
});
```

---

##### `useWinningsClaimedEvents(callback)`
Listen for winnings being claimed.

```typescript
useWinningsClaimedEvents((event) => {
  console.log("Winnings claimed:", event);
});
```

---

##### `useRoundSeededEvents(callback)`
Listen for round seeding.

```typescript
useRoundSeededEvents((event) => {
  console.log("Round seeded:", event);
  // Refresh odds display
});
```

---

##### `useLiquidityAddedEvents(callback)`
Listen for liquidity additions.

```typescript
useLiquidityAddedEvents((event) => {
  console.log("Liquidity added:", event);
});
```

---

### Utility Functions

##### `formatOdds(oddsWei: bigint): string`
Format odds from Wei to decimal string.

```typescript
formatOdds(15e17n) // "1.50x"
```

---

##### `getParlayMultiplier(legCount: number): number`
Get parlay bonus multiplier.

```typescript
getParlayMultiplier(3) // 1.10
getParlayMultiplier(10) // 1.25
```

---

##### `calculatePayout(amount, odds[], legCount): bigint`
Calculate potential payout including parlay bonus.

```typescript
const payout = calculatePayout(
  parseUnits("100", 6),
  [13e17n, 15e17n, 14e17n],
  3
);
```

---

##### `getBetStatusLabel(status: BetStatus): string`
Get human-readable bet status.

```typescript
getBetStatusLabel(BetStatus.Won) // "Won"
```

---

##### `getOutcomeLabel(outcome: Outcome): string`
Get human-readable outcome label.

```typescript
getOutcomeLabel(Outcome.HomeWin) // "Home Win"
```

---

## 🎯 Common Patterns

### Pattern 1: Display Current Round Odds

```typescript
function MatchesDisplay() {
  const { data: roundId } = useCurrentRound();
  const { homeOdds, awayOdds, drawOdds } = useMatchOdds(roundId, 0n);

  return (
    <div>
      <div>Home: {homeOdds ? formatOdds(homeOdds) : "..."}</div>
      <div>Away: {awayOdds ? formatOdds(awayOdds) : "..."}</div>
      <div>Draw: {drawOdds ? formatOdds(drawOdds) : "..."}</div>
    </div>
  );
}
```

---

### Pattern 2: Place Bet with Approval

```typescript
function PlaceBetButton() {
  const [isPlacing, setIsPlacing] = useState(false);
  const placeBet = usePlaceBetWithApproval();

  const handleBet = async () => {
    setIsPlacing(true);
    try {
      await placeBet(
        USDC_ADDRESS,
        parseUnits("100", 6),
        [0n, 1n, 2n],
        [1, 2, 1]
      );
      alert("Bet placed!");
    } catch (error) {
      console.error(error);
    } finally {
      setIsPlacing(false);
    }
  };

  return (
    <button onClick={handleBet} disabled={isPlacing}>
      {isPlacing ? "Placing..." : "Place Bet"}
    </button>
  );
}
```

---

### Pattern 3: Show User's Position

```typescript
function LPPosition() {
  const { address } = useAccount();
  const { data: position } = useLPPosition(USDC_ADDRESS, address);

  if (!position) return <div>No position</div>;

  return (
    <div>
      <div>Shares: {formatUnits(position.shares, 6)}</div>
      <div>Value: {formatUnits(position.shareValue, 6)} USDC</div>
      <div>P&L: {formatUnits(position.profitLoss, 6)} USDC</div>
    </div>
  );
}
```

---

### Pattern 4: Claim All Winnings

```typescript
function ClaimAllButton() {
  const { address } = useAccount();
  const { data: claimable } = useUserClaimable(address);
  const batchClaim = useBatchClaim();
  const [isClaiming, setIsClaiming] = useState(false);

  if (!claimable || claimable[1].length === 0) {
    return <div>No winnings to claim</div>;
  }

  const handleClaim = async () => {
    setIsClaiming(true);
    try {
      await batchClaim(claimable[1]);
      alert("Claimed!");
    } catch (error) {
      console.error(error);
    } finally {
      setIsClaiming(false);
    }
  };

  return (
    <button onClick={handleClaim} disabled={isClaiming}>
      Claim {formatUnits(claimable[0], 6)} USDC
    </button>
  );
}
```

---

## 🔧 Error Handling

All write hooks can throw errors. Wrap them in try-catch:

```typescript
try {
  await placeBet(...);
} catch (error: any) {
  if (error.message.includes("InsufficientAllowance")) {
    alert("Please approve USDC first");
  } else if (error.message.includes("BettingClosed")) {
    alert("Betting has closed for this round");
  } else {
    alert(`Error: ${error.message}`);
  }
}
```

---

## 📱 Real-Time Updates

Use event listeners to update UI in real-time:

```typescript
function App() {
  const [betCount, setBetCount] = useState(0);

  useBetPlacedEvents(() => {
    setBetCount(c => c + 1);
  });

  return <div>Bets placed: {betCount}</div>;
}
```

---

## 🎨 Styling

The example components use Tailwind CSS classes. Adapt to your styling system:

```typescript
// Tailwind
<button className="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded">

// CSS Modules
<button className={styles.button}>

// Styled Components
<StyledButton>
```

---

## 📦 TypeScript Support

All hooks are fully typed. Import types:

```typescript
import { BetStatus, Outcome } from "./betting-hooks";

const status: BetStatus = BetStatus.Won;
const outcome: Outcome = Outcome.HomeWin;
```

---

## 🚀 Production Checklist

Before deploying:

- [ ] Update all contract addresses in `CONTRACTS`
- [ ] Add your WalletConnect project ID
- [ ] Configure RPC endpoints (consider Alchemy/Infura)
- [ ] Add error tracking (Sentry, etc.)
- [ ] Add analytics (PostHog, Mixpanel, etc.)
- [ ] Test on testnet thoroughly
- [ ] Add loading states for all async operations
- [ ] Add proper error messages
- [ ] Implement proper wallet connection flow
- [ ] Add transaction confirmation modals
- [ ] Test mobile responsiveness

---

## 📚 Additional Resources

- [Wagmi Documentation](https://wagmi.sh/)
- [Viem Documentation](https://viem.sh/)
- [TanStack Query](https://tanstack.com/query/latest)
- [RainbowKit](https://www.rainbowkit.com/) - For wallet connection UI

---

## 🐛 Troubleshooting

**Hook returns `undefined`**:
- Check that wallet is connected
- Verify contract addresses are correct
- Ensure query is enabled (check `enabled` flag)

**Transaction fails**:
- Check token approval
- Verify sufficient balance
- Check if round is active
- Look at error message in console

**Events not firing**:
- Verify WebSocket connection
- Check that contract address is correct
- Ensure event name matches ABI

---

## 📞 Support

For issues or questions:
1. Check this README
2. Review example components
3. Check contract documentation
4. Contact development team

---

**Last Updated**: 2026-02-02
**Version**: 1.0.0

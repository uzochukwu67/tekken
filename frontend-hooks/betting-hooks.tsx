/**
 * Betting System Hooks - Wagmi v2
 * Complete hooks for BettingCore, LiquidityCore, and GameCore contracts
 */

import {
  useAccount,
  useReadContract,
  useWriteContract,
  useWatchContractEvent,
  useBlockNumber,
  useBalance
} from "wagmi";
import { erc20Abi, parseUnits, formatUnits } from "viem";
import { useState, useEffect } from "react";

// ============================================================================
// TYPES & CONSTANTS
// ============================================================================

export type AppChainKey = "sepolia" | "mainnet" | "polygon" | "arbitrum";

export const CONTRACTS: Record<AppChainKey, {
  BettingCore: `0x${string}`;
  LiquidityCore: `0x${string}`;
  GameCore: `0x${string}`;
  USDC: `0x${string}`;
  USDT: `0x${string}`;
}> = {
  sepolia: {
    BettingCore: "0x...", // UPDATE WITH YOUR DEPLOYED ADDRESSES
    LiquidityCore: "0x...",
    GameCore: "0x...",
    USDC: "0x...",
    USDT: "0x...",
  },
  mainnet: {
    BettingCore: "0x...",
    LiquidityCore: "0x...",
    GameCore: "0x...",
    USDC: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    USDT: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
  },
  polygon: {
    BettingCore: "0x...",
    LiquidityCore: "0x...",
    GameCore: "0x...",
    USDC: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
    USDT: "0xc2132D05D31c914a87C6611C10748AEb04B58e8F",
  },
  arbitrum: {
    BettingCore: "0x...",
    LiquidityCore: "0x...",
    GameCore: "0x...",
    USDC: "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8",
    USDT: "0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9",
  },
};

export const APP_CHAINS = [
  { id: 11155111, name: "Sepolia" },
  { id: 1, name: "Mainnet" },
  { id: 137, name: "Polygon" },
  { id: 42161, name: "Arbitrum" },
] as const;

// BetStatus enum
export enum BetStatus {
  Active = 0,
  Won = 1,
  Lost = 2,
  Cancelled = 3,
}

// Outcome enum
export enum Outcome {
  None = 0,
  HomeWin = 1,
  AwayWin = 2,
  Draw = 3,
}

// ============================================================================
// CONTRACT ABIs
// ============================================================================

const BETTING_CORE_ABI = [
  // Read Functions
  {
    name: "getCurrentRound",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "uint256" }],
  },
  {
    name: "getRoundSummary",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "roundId", type: "uint256" }],
    outputs: [{
      type: "tuple",
      components: [
        { name: "roundId", type: "uint256" },
        { name: "seeded", type: "bool" },
        { name: "settled", type: "bool" },
        { name: "roundStartTime", type: "uint64" },
        { name: "roundEndTime", type: "uint64" },
        { name: "totalBetVolume", type: "uint256" },
        { name: "totalBetCount", type: "uint256" },
        { name: "parlayCount", type: "uint256" },
      ],
    }],
  },
  {
    name: "getOdds",
    type: "function",
    stateMutability: "view",
    inputs: [
      { name: "roundId", type: "uint256" },
      { name: "matchIndex", type: "uint256" },
      { name: "outcome", type: "uint8" },
    ],
    outputs: [{ type: "uint256" }],
  },
  {
    name: "getBet",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "betId", type: "uint256" }],
    outputs: [{
      type: "tuple",
      components: [
        { name: "betId", type: "uint256" },
        { name: "bettor", type: "address" },
        { name: "token", type: "address" },
        { name: "amount", type: "uint256" },
        { name: "roundId", type: "uint256" },
        { name: "legCount", type: "uint8" },
        { name: "parlayMultiplier", type: "uint256" },
        { name: "potentialPayout", type: "uint256" },
        { name: "actualPayout", type: "uint256" },
        { name: "status", type: "uint8" },
        { name: "placedAt", type: "uint256" },
        { name: "predictions", type: "tuple[]", components: [
          { name: "matchIndex", type: "uint256" },
          { name: "predictedOutcome", type: "uint8" },
          { name: "amountInPool", type: "uint256" },
        ]},
      ],
    }],
  },
  {
    name: "getUserClaimable",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "user", type: "address" }],
    outputs: [
      { name: "totalClaimable", type: "uint256" },
      { name: "betIds", type: "uint256[]" },
    ],
  },
  {
    name: "getMatchPoolDebug",
    type: "function",
    stateMutability: "view",
    inputs: [
      { name: "roundId", type: "uint256" },
      { name: "matchIndex", type: "uint256" },
    ],
    outputs: [
      { name: "homePool", type: "uint256" },
      { name: "awayPool", type: "uint256" },
      { name: "drawPool", type: "uint256" },
      { name: "total", type: "uint256" },
    ],
  },

  // Write Functions
  {
    name: "placeBet",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "token", type: "address" },
      { name: "amount", type: "uint256" },
      { name: "matchIndices", type: "uint256[]" },
      { name: "predictions", type: "uint8[]" },
    ],
    outputs: [{ type: "uint256" }],
  },
  {
    name: "cancelBet",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [{ name: "betId", type: "uint256" }],
    outputs: [{ type: "uint256" }],
  },
  {
    name: "claimWinnings",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "betId", type: "uint256" },
      { name: "minPayout", type: "uint256" },
    ],
    outputs: [{ type: "uint256" }],
  },
  {
    name: "batchClaim",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [{ name: "betIds", type: "uint256[]" }],
    outputs: [{ type: "uint256" }],
  },

  // Events
  {
    name: "BetPlaced",
    type: "event",
    inputs: [
      { indexed: true, name: "betId", type: "uint256" },
      { indexed: true, name: "bettor", type: "address" },
      { indexed: false, name: "amount", type: "uint256" },
      { indexed: false, name: "legCount", type: "uint8" },
    ],
  },
  {
    name: "BetCancelled",
    type: "event",
    inputs: [
      { indexed: true, name: "betId", type: "uint256" },
      { indexed: true, name: "bettor", type: "address" },
      { indexed: false, name: "refundAmount", type: "uint256" },
    ],
  },
  {
    name: "WinningsClaimed",
    type: "event",
    inputs: [
      { indexed: true, name: "betId", type: "uint256" },
      { indexed: true, name: "bettor", type: "address" },
      { indexed: false, name: "amount", type: "uint256" },
    ],
  },
  {
    name: "RoundSeeded",
    type: "event",
    inputs: [{ indexed: true, name: "roundId", type: "uint256" }],
  },
] as const;

const LIQUIDITY_CORE_ABI = [
  // Read Functions
  {
    name: "getPosition",
    type: "function",
    stateMutability: "view",
    inputs: [
      { name: "user", type: "address" },
      { name: "token", type: "address" },
    ],
    outputs: [{
      type: "tuple",
      components: [
        { name: "shares", type: "uint256" },
        { name: "shareValue", type: "uint256" },
        { name: "sharePercentage", type: "uint256" },
        { name: "totalDeposited", type: "uint256" },
        { name: "totalWithdrawn", type: "uint256" },
        { name: "profitLoss", type: "int256" },
      ],
    }],
  },
  {
    name: "getPoolUtilization",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "token", type: "address" }],
    outputs: [
      { name: "totalLiquidity", type: "uint256" },
      { name: "lockedLiquidity", type: "uint256" },
      { name: "availableLiquidity", type: "uint256" },
      { name: "utilizationBps", type: "uint256" },
    ],
  },
  {
    name: "getPoolForDeposit",
    type: "function",
    stateMutability: "view",
    inputs: [
      { name: "token", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [
      { name: "pool", type: "address" },
      { name: "expectedShares", type: "uint256" },
    ],
  },
  {
    name: "getTotalValueLocked",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [
      { name: "totalTVL", type: "uint256" },
      { name: "tokens", type: "address[]" },
      { name: "tvlPerToken", type: "uint256[]" },
    ],
  },

  // Write Functions
  {
    name: "addLiquidity",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "token", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [{ type: "uint256" }],
  },
  {
    name: "removeLiquidity",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "token", type: "address" },
      { name: "shares", type: "uint256" },
    ],
    outputs: [{ type: "uint256" }],
  },

  // Events
  {
    name: "LiquidityAdded",
    type: "event",
    inputs: [
      { indexed: true, name: "provider", type: "address" },
      { indexed: true, name: "token", type: "address" },
      { indexed: true, name: "pool", type: "address" },
      { indexed: false, name: "amount", type: "uint256" },
      { indexed: false, name: "shares", type: "uint256" },
    ],
  },
  {
    name: "LiquidityRemoved",
    type: "event",
    inputs: [
      { indexed: true, name: "provider", type: "address" },
      { indexed: true, name: "token", type: "address" },
      { indexed: true, name: "pool", type: "address" },
      { indexed: false, name: "shares", type: "uint256" },
      { indexed: false, name: "amount", type: "uint256" },
    ],
  },
  {
    name: "GlobalRoundStatusChanged",
    type: "event",
    inputs: [{ indexed: false, name: "active", type: "bool" }],
  },
] as const;

const GAME_CORE_ABI = [
  {
    name: "getRound",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "roundId", type: "uint256" }],
    outputs: [{
      type: "tuple",
      components: [
        { name: "roundId", type: "uint256" },
        { name: "seasonId", type: "uint256" },
        { name: "seasonRound", type: "uint256" },
        { name: "started", type: "bool" },
        { name: "settled", type: "bool" },
        { name: "startTime", type: "uint256" },
        { name: "endTime", type: "uint256" },
      ],
    }],
  },
  {
    name: "getMatchResults",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "roundId", type: "uint256" }],
    outputs: [{ name: "results", type: "uint8[]" }],
  },
] as const;

// ============================================================================
// UTILITY HOOKS
// ============================================================================

/**
 * Get contract addresses for current chain
 */
function useContractAddresses() {
  const { chainId } = useAccount();
  const chainName = APP_CHAINS.find(c => c.id === chainId)?.name.toLowerCase() as AppChainKey || "sepolia";
  return CONTRACTS[chainName] || CONTRACTS.sepolia;
}

/**
 * Get user's token balance
 */
export function useTokenBalance(token?: `0x${string}`) {
  const { address } = useAccount();
  return useBalance({
    address: address,
    token: token,
    query: { enabled: !!address && !!token },
  });
}

/**
 * Check token allowance
 */
export function useTokenAllowance(token?: `0x${string}`, spender?: `0x${string}`) {
  const { address } = useAccount();
  return useReadContract({
    address: token,
    abi: erc20Abi,
    functionName: "allowance",
    args: address && spender ? [address, spender] : undefined,
    query: { enabled: !!address && !!token && !!spender },
  });
}

/**
 * Approve token spending
 */
export function useApproveToken() {
  const { writeContractAsync } = useWriteContract();

  return async (token: `0x${string}`, spender: `0x${string}`, amount: bigint) => {
    return writeContractAsync({
      address: token,
      abi: erc20Abi,
      functionName: "approve",
      args: [spender, amount],
    });
  };
}

// ============================================================================
// BETTING CORE - READ HOOKS
// ============================================================================

/**
 * Get current active round ID
 */
export function useCurrentRound() {
  const addresses = useContractAddresses();
  return useReadContract({
    address: addresses.BettingCore,
    abi: BETTING_CORE_ABI,
    functionName: "getCurrentRound",
  });
}

/**
 * Get round summary information
 */
export function useRoundSummary(roundId?: bigint) {
  const addresses = useContractAddresses();
  return useReadContract({
    address: addresses.BettingCore,
    abi: BETTING_CORE_ABI,
    functionName: "getRoundSummary",
    args: roundId !== undefined ? [roundId] : undefined,
    query: { enabled: roundId !== undefined },
  });
}

/**
 * Get odds for a specific match outcome
 */
export function useOdds(roundId?: bigint, matchIndex?: bigint, outcome?: number) {
  const addresses = useContractAddresses();
  return useReadContract({
    address: addresses.BettingCore,
    abi: BETTING_CORE_ABI,
    functionName: "getOdds",
    args: roundId !== undefined && matchIndex !== undefined && outcome !== undefined
      ? [roundId, matchIndex, outcome as any]
      : undefined,
    query: {
      enabled: roundId !== undefined && matchIndex !== undefined && outcome !== undefined,
      refetchInterval: 30000, // Refresh every 30s
    },
  });
}

/**
 * Get odds for all outcomes of a match (home, away, draw)
 */
export function useMatchOdds(roundId?: bigint, matchIndex?: bigint) {
  const addresses = useContractAddresses();

  const homeOdds = useReadContract({
    address: addresses.BettingCore,
    abi: BETTING_CORE_ABI,
    functionName: "getOdds",
    args: roundId !== undefined && matchIndex !== undefined ? [roundId, matchIndex, 1] : undefined,
    query: { enabled: roundId !== undefined && matchIndex !== undefined },
  });

  const awayOdds = useReadContract({
    address: addresses.BettingCore,
    abi: BETTING_CORE_ABI,
    functionName: "getOdds",
    args: roundId !== undefined && matchIndex !== undefined ? [roundId, matchIndex, 2] : undefined,
    query: { enabled: roundId !== undefined && matchIndex !== undefined },
  });

  const drawOdds = useReadContract({
    address: addresses.BettingCore,
    abi: BETTING_CORE_ABI,
    functionName: "getOdds",
    args: roundId !== undefined && matchIndex !== undefined ? [roundId, matchIndex, 3] : undefined,
    query: { enabled: roundId !== undefined && matchIndex !== undefined },
  });

  return {
    homeOdds: homeOdds.data,
    awayOdds: awayOdds.data,
    drawOdds: drawOdds.data,
    isLoading: homeOdds.isLoading || awayOdds.isLoading || drawOdds.isLoading,
    refetch: () => {
      homeOdds.refetch();
      awayOdds.refetch();
      drawOdds.refetch();
    },
  };
}

/**
 * Get bet information
 */
export function useBet(betId?: bigint) {
  const addresses = useContractAddresses();
  return useReadContract({
    address: addresses.BettingCore,
    abi: BETTING_CORE_ABI,
    functionName: "getBet",
    args: betId !== undefined ? [betId] : undefined,
    query: { enabled: betId !== undefined },
  });
}

/**
 * Get user's claimable winnings
 */
export function useUserClaimable(userAddress?: `0x${string}`) {
  const addresses = useContractAddresses();
  const { address } = useAccount();
  const effectiveAddress = userAddress || address;

  return useReadContract({
    address: addresses.BettingCore,
    abi: BETTING_CORE_ABI,
    functionName: "getUserClaimable",
    args: effectiveAddress ? [effectiveAddress] : undefined,
    query: { enabled: !!effectiveAddress },
  });
}

/**
 * Get match pool details (for debugging/stats)
 */
export function useMatchPool(roundId?: bigint, matchIndex?: bigint) {
  const addresses = useContractAddresses();
  return useReadContract({
    address: addresses.BettingCore,
    abi: BETTING_CORE_ABI,
    functionName: "getMatchPoolDebug",
    args: roundId !== undefined && matchIndex !== undefined ? [roundId, matchIndex] : undefined,
    query: { enabled: roundId !== undefined && matchIndex !== undefined },
  });
}

// ============================================================================
// BETTING CORE - WRITE HOOKS
// ============================================================================

/**
 * Place a bet on match(es)
 */
export function usePlaceBet() {
  const addresses = useContractAddresses();
  const { writeContractAsync } = useWriteContract();

  return async (
    token: `0x${string}`,
    amount: bigint,
    matchIndices: bigint[],
    predictions: number[]
  ) => {
    return writeContractAsync({
      address: addresses.BettingCore,
      abi: BETTING_CORE_ABI,
      functionName: "placeBet",
      args: [token, amount, matchIndices, predictions as any],
    });
  };
}

/**
 * Cancel an active bet
 */
export function useCancelBet() {
  const addresses = useContractAddresses();
  const { writeContractAsync } = useWriteContract();

  return async (betId: bigint) => {
    return writeContractAsync({
      address: addresses.BettingCore,
      abi: BETTING_CORE_ABI,
      functionName: "cancelBet",
      args: [betId],
    });
  };
}

/**
 * Claim winnings for a single bet
 */
export function useClaimWinnings() {
  const addresses = useContractAddresses();
  const { writeContractAsync } = useWriteContract();

  return async (betId: bigint, minPayout: bigint = 0n) => {
    return writeContractAsync({
      address: addresses.BettingCore,
      abi: BETTING_CORE_ABI,
      functionName: "claimWinnings",
      args: [betId, minPayout],
    });
  };
}

/**
 * Batch claim winnings for multiple bets
 */
export function useBatchClaim() {
  const addresses = useContractAddresses();
  const { writeContractAsync } = useWriteContract();

  return async (betIds: bigint[]) => {
    return writeContractAsync({
      address: addresses.BettingCore,
      abi: BETTING_CORE_ABI,
      functionName: "batchClaim",
      args: [betIds],
    });
  };
}

// ============================================================================
// LIQUIDITY CORE - READ HOOKS
// ============================================================================

/**
 * Get user's LP position
 */
export function useLPPosition(token?: `0x${string}`, userAddress?: `0x${string}`) {
  const addresses = useContractAddresses();
  const { address } = useAccount();
  const effectiveAddress = userAddress || address;

  return useReadContract({
    address: addresses.LiquidityCore,
    abi: LIQUIDITY_CORE_ABI,
    functionName: "getPosition",
    args: effectiveAddress && token ? [effectiveAddress, token] : undefined,
    query: { enabled: !!effectiveAddress && !!token },
  });
}

/**
 * Get pool utilization statistics
 */
export function usePoolUtilization(token?: `0x${string}`) {
  const addresses = useContractAddresses();
  return useReadContract({
    address: addresses.LiquidityCore,
    abi: LIQUIDITY_CORE_ABI,
    functionName: "getPoolUtilization",
    args: token ? [token] : undefined,
    query: {
      enabled: !!token,
      refetchInterval: 30000, // Refresh every 30s
    },
  });
}

/**
 * Preview shares for a deposit
 */
export function useLPPreview(token?: `0x${string}`, amount?: bigint) {
  const addresses = useContractAddresses();
  return useReadContract({
    address: addresses.LiquidityCore,
    abi: LIQUIDITY_CORE_ABI,
    functionName: "getPoolForDeposit",
    args: token && amount ? [token, amount] : undefined,
    query: { enabled: !!token && !!amount },
  });
}

/**
 * Get total value locked across all pools
 */
export function useTotalValueLocked() {
  const addresses = useContractAddresses();
  return useReadContract({
    address: addresses.LiquidityCore,
    abi: LIQUIDITY_CORE_ABI,
    functionName: "getTotalValueLocked",
  });
}

// ============================================================================
// LIQUIDITY CORE - WRITE HOOKS
// ============================================================================

/**
 * Add liquidity to pool
 */
export function useAddLiquidity() {
  const addresses = useContractAddresses();
  const { writeContractAsync } = useWriteContract();

  return async (token: `0x${string}`, amount: bigint) => {
    return writeContractAsync({
      address: addresses.LiquidityCore,
      abi: LIQUIDITY_CORE_ABI,
      functionName: "addLiquidity",
      args: [token, amount],
    });
  };
}

/**
 * Remove liquidity from pool
 */
export function useRemoveLiquidity() {
  const addresses = useContractAddresses();
  const { writeContractAsync } = useWriteContract();

  return async (token: `0x${string}`, shares: bigint) => {
    return writeContractAsync({
      address: addresses.LiquidityCore,
      abi: LIQUIDITY_CORE_ABI,
      functionName: "removeLiquidity",
      args: [token, shares],
    });
  };
}

// ============================================================================
// GAME CORE - READ HOOKS
// ============================================================================

/**
 * Get round information from GameCore
 */
export function useGameRound(roundId?: bigint) {
  const addresses = useContractAddresses();
  return useReadContract({
    address: addresses.GameCore,
    abi: GAME_CORE_ABI,
    functionName: "getRound",
    args: roundId !== undefined ? [roundId] : undefined,
    query: { enabled: roundId !== undefined },
  });
}

/**
 * Get match results for a settled round
 */
export function useMatchResults(roundId?: bigint) {
  const addresses = useContractAddresses();
  return useReadContract({
    address: addresses.GameCore,
    abi: GAME_CORE_ABI,
    functionName: "getMatchResults",
    args: roundId !== undefined ? [roundId] : undefined,
    query: { enabled: roundId !== undefined },
  });
}

// ============================================================================
// EVENT LISTENERS
// ============================================================================

/**
 * Listen for new bets being placed
 */
export function useBetPlacedEvents(callback?: (event: any) => void) {
  const addresses = useContractAddresses();

  useWatchContractEvent({
    address: addresses.BettingCore,
    abi: BETTING_CORE_ABI,
    eventName: "BetPlaced",
    onLogs(logs) {
      logs.forEach(log => {
        callback?.(log);
      });
    },
  });
}

/**
 * Listen for bets being cancelled
 */
export function useBetCancelledEvents(callback?: (event: any) => void) {
  const addresses = useContractAddresses();

  useWatchContractEvent({
    address: addresses.BettingCore,
    abi: BETTING_CORE_ABI,
    eventName: "BetCancelled",
    onLogs(logs) {
      logs.forEach(log => {
        callback?.(log);
      });
    },
  });
}

/**
 * Listen for winnings being claimed
 */
export function useWinningsClaimedEvents(callback?: (event: any) => void) {
  const addresses = useContractAddresses();

  useWatchContractEvent({
    address: addresses.BettingCore,
    abi: BETTING_CORE_ABI,
    eventName: "WinningsClaimed",
    onLogs(logs) {
      logs.forEach(log => {
        callback?.(log);
      });
    },
  });
}

/**
 * Listen for round seeding
 */
export function useRoundSeededEvents(callback?: (event: any) => void) {
  const addresses = useContractAddresses();

  useWatchContractEvent({
    address: addresses.BettingCore,
    abi: BETTING_CORE_ABI,
    eventName: "RoundSeeded",
    onLogs(logs) {
      logs.forEach(log => {
        callback?.(log);
      });
    },
  });
}

/**
 * Listen for liquidity additions
 */
export function useLiquidityAddedEvents(callback?: (event: any) => void) {
  const addresses = useContractAddresses();

  useWatchContractEvent({
    address: addresses.LiquidityCore,
    abi: LIQUIDITY_CORE_ABI,
    eventName: "LiquidityAdded",
    onLogs(logs) {
      logs.forEach(log => {
        callback?.(log);
      });
    },
  });
}

/**
 * Listen for liquidity removals
 */
export function useLiquidityRemovedEvents(callback?: (event: any) => void) {
  const addresses = useContractAddresses();

  useWatchContractEvent({
    address: addresses.LiquidityCore,
    abi: LIQUIDITY_CORE_ABI,
    eventName: "LiquidityRemoved",
    onLogs(logs) {
      logs.forEach(log => {
        callback?.(log);
      });
    },
  });
}

// ============================================================================
// COMPOSITE HOOKS (Complex operations)
// ============================================================================

/**
 * Complete bet placement flow with approval
 */
export function usePlaceBetWithApproval() {
  const addresses = useContractAddresses();
  const { address } = useAccount();
  const approveToken = useApproveToken();
  const placeBet = usePlaceBet();
  const { data: allowance, refetch: refetchAllowance } = useTokenAllowance();

  return async (
    token: `0x${string}`,
    amount: bigint,
    matchIndices: bigint[],
    predictions: number[]
  ) => {
    if (!address) throw new Error("Wallet not connected");

    // Check allowance
    const currentAllowance = await refetchAllowance();

    // Approve if needed
    if (!currentAllowance.data || currentAllowance.data < amount) {
      await approveToken(token, addresses.BettingCore, amount);
    }

    // Place bet
    return placeBet(token, amount, matchIndices, predictions);
  };
}

/**
 * Complete LP deposit flow with approval
 */
export function useAddLiquidityWithApproval() {
  const addresses = useContractAddresses();
  const { address } = useAccount();
  const approveToken = useApproveToken();
  const addLiquidity = useAddLiquidity();

  return async (token: `0x${string}`, amount: bigint) => {
    if (!address) throw new Error("Wallet not connected");

    // Approve tokens
    await approveToken(token, addresses.LiquidityCore, amount);

    // Add liquidity
    return addLiquidity(token, amount);
  };
}

/**
 * Fetch all match odds for a round (0-9)
 */
export function useAllMatchOdds(roundId?: bigint) {
  const [allOdds, setAllOdds] = useState<Array<{
    matchIndex: number;
    homeOdds: bigint;
    awayOdds: bigint;
    drawOdds: bigint;
  }>>([]);
  const [isLoading, setIsLoading] = useState(true);

  const addresses = useContractAddresses();

  useEffect(() => {
    if (roundId === undefined) return;

    const fetchAllOdds = async () => {
      setIsLoading(true);
      const promises = [];

      for (let i = 0; i < 10; i++) {
        promises.push(
          Promise.all([
            fetch(`rpc-endpoint`, {
              method: "eth_call",
              // Simplified - in reality use proper contract call
            }),
          ])
        );
      }

      // In practice, you'd use multicall or individual reads
      // For now, this is a placeholder
      setIsLoading(false);
    };

    fetchAllOdds();
  }, [roundId]);

  return { allOdds, isLoading };
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * Format odds from Wei (1e18) to decimal string
 */
export function formatOdds(oddsWei: bigint): string {
  const odds = Number(formatUnits(oddsWei, 18));
  return odds.toFixed(2) + "x";
}

/**
 * Calculate parlay multiplier based on leg count
 */
export function getParlayMultiplier(legCount: number): number {
  const multipliers = [1.00, 1.05, 1.10, 1.13, 1.16, 1.19, 1.21, 1.23, 1.24, 1.25];
  return multipliers[Math.min(Math.max(legCount - 1, 0), 9)] || 1.0;
}

/**
 * Calculate potential payout for a bet
 */
export function calculatePayout(
  amount: bigint,
  odds: bigint[],
  legCount: number
): bigint {
  // Multiply all odds
  let combinedOdds = parseUnits("1", 18);
  for (const odd of odds) {
    combinedOdds = (combinedOdds * odd) / parseUnits("1", 18);
  }

  // Apply parlay multiplier
  const parlayMultiplier = getParlayMultiplier(legCount);
  const parlayMultiplierBigInt = parseUnits(parlayMultiplier.toFixed(2), 18);
  combinedOdds = (combinedOdds * parlayMultiplierBigInt) / parseUnits("1", 18);

  // Calculate payout
  return (amount * combinedOdds) / parseUnits("1", 18);
}

/**
 * Get bet status label
 */
export function getBetStatusLabel(status: BetStatus): string {
  return ["Active", "Won", "Lost", "Cancelled"][status] || "Unknown";
}

/**
 * Get outcome label
 */
export function getOutcomeLabel(outcome: Outcome): string {
  return ["None", "Home Win", "Away Win", "Draw"][outcome] || "Unknown";
}

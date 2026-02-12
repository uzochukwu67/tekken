/**
 * LBT Betting System Hooks - Wagmi v2
 * Single-Token System with Compressed Odds [1.25x - 2.05x]
 * Updated: Latest deployment on Sepolia
 */

import {
  useAccount,
  useReadContract,
  useWriteContract,
  useWatchContractEvent,
  useBalance
} from "wagmi";
import { erc20Abi, parseUnits, formatUnits } from "viem";
import type { Address } from "viem";

// ============================================================================
// TYPES & CONSTANTS
// ============================================================================

export type AppChainKey = "sepolia" | "mainnet" | "polygon";

export const CONTRACTS: Record<AppChainKey, {
  BettingCore: Address;
  GameCore: Address;
  LBTToken: Address;
  LBTPool: Address;
  SwapRouter: Address;
  // Tokens for swapping to LBT
  USDC?: Address;
  USDT?: Address;
}> = {
  sepolia: {
    // Core Contracts (Single-Token LBT System with Compressed Odds)
    BettingCore: "0x02DcAA2DEFCA04fA3754Ce05c3BC0689d56b25Eb",
    GameCore: "0x223D4C3A24bC535f4d7d6077DB28264B7D6C4842",
    LBTToken: "0x77A58e143C7A2F6D78319eD6245d0742BCf0b743",
    LBTPool: "0x36700A27cE0d2f00d46D0653aE9c0AbBd4116334",
    SwapRouter: "0x185fe9Ee5693B0610374F61beb5eEBa2CbE6693C",
    // Legacy tokens for swapping to LBT
    USDC: "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238", // Sepolia USDC
    USDT: "0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0", // Sepolia USDT
  },
  mainnet: {
    BettingCore: "0x0000000000000000000000000000000000000000", // TODO: Deploy
    GameCore: "0x0000000000000000000000000000000000000000",
    LBTToken: "0x0000000000000000000000000000000000000000",
    LBTPool: "0x0000000000000000000000000000000000000000",
    SwapRouter: "0x0000000000000000000000000000000000000000",
    USDC: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    USDT: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
  },
  polygon: {
    BettingCore: "0x0000000000000000000000000000000000000000", // TODO: Deploy
    GameCore: "0x0000000000000000000000000000000000000000",
    LBTToken: "0x0000000000000000000000000000000000000000",
    LBTPool: "0x0000000000000000000000000000000000000000",
    SwapRouter: "0x0000000000000000000000000000000000000000",
    USDC: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
    USDT: "0xc2132D05D31c914a87C6611C10748AEb04B58e8F",
  },
};

export const APP_CHAINS = [
  { id: 11155111, name: "Sepolia" },
  { id: 1, name: "Mainnet" },
  { id: 137, name: "Polygon" },
] as const;

// BetStatus enum
export enum BetStatus {
  Active = 0,
  Claimed = 1,
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
// CONTRACT ABIs (Updated for Single-Token LBT System)
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
    name: "getOdds",
    type: "function",
    stateMutability: "view",
    inputs: [
      { name: "roundId", type: "uint256" },
      { name: "matchIndex", type: "uint256" },
      { name: "prediction", type: "uint8" },
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
        { name: "bettor", type: "address" },
        { name: "token", type: "address" },
        { name: "amount", type: "uint128" },
        { name: "allocatedAmount", type: "uint128" },
        { name: "lpBorrowedAmount", type: "uint128" },
        { name: "bonus", type: "uint128" },
        { name: "lockedMultiplier", type: "uint128" },
        { name: "roundId", type: "uint64" },
        { name: "timestamp", type: "uint32" },
        { name: "legCount", type: "uint8" },
        { name: "status", type: "uint8" },
      ],
    }, {
      type: "tuple",
      components: [
        { name: "predictions", type: "tuple[]", components: [
          { name: "matchIndex", type: "uint8" },
          { name: "predictedOutcome", type: "uint8" },
          { name: "amountInPool", type: "uint128" },
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
    name: "getLBTToken",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "address" }],
  },
  {
    name: "getLBTPool",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "address" }],
  },

  // Write Functions (Updated - NO TOKEN PARAMETER!)
  {
    name: "placeBet",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
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

  // Events
  {
    name: "BetPlaced",
    type: "event",
    inputs: [
      { indexed: true, name: "betId", type: "uint256" },
      { indexed: true, name: "bettor", type: "address" },
      { indexed: false, name: "roundId", type: "uint256" },
      { indexed: false, name: "amount", type: "uint256" },
      { indexed: false, name: "parlayMultiplier", type: "uint256" },
      { indexed: false, name: "legCount", type: "uint8" },
    ],
  },
  {
    name: "WinningsClaimed",
    type: "event",
    inputs: [
      { indexed: true, name: "betId", type: "uint256" },
      { indexed: true, name: "winner", type: "address" },
      { indexed: false, name: "payout", type: "uint256" },
    ],
  },
] as const;

const LBT_POOL_ABI = [
  {
    name: "totalLiquidity",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "uint256" }],
  },
  {
    name: "lockedLiquidity",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "uint256" }],
  },
  {
    name: "getAvailableLiquidity",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "uint256" }],
  },
  {
    name: "lpShares",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "user", type: "address" }],
    outputs: [{ type: "uint256" }],
  },
  {
    name: "addLiquidity",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [{ name: "amount", type: "uint256" }],
    outputs: [{ type: "uint256" }],
  },
  {
    name: "removeLiquidity",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [{ name: "shares", type: "uint256" }],
    outputs: [{ type: "uint256" }],
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
 * Get user's LBT balance
 */
export function useLBTBalance(userAddress?: Address) {
  const addresses = useContractAddresses();
  const { address } = useAccount();
  const effectiveAddress = userAddress || address;

  return useBalance({
    address: effectiveAddress,
    token: addresses.LBTToken,
    query: { enabled: !!effectiveAddress },
  });
}

/**
 * Check LBT allowance for BettingCore
 */
export function useLBTAllowance(userAddress?: Address) {
  const addresses = useContractAddresses();
  const { address } = useAccount();
  const effectiveAddress = userAddress || address;

  return useReadContract({
    address: addresses.LBTToken,
    abi: erc20Abi,
    functionName: "allowance",
    args: effectiveAddress ? [effectiveAddress, addresses.BettingCore] : undefined,
    query: { enabled: !!effectiveAddress },
  });
}

/**
 * Approve LBT spending for BettingCore
 */
export function useApproveLBT() {
  const addresses = useContractAddresses();
  const { writeContractAsync } = useWriteContract();

  return async (amount: bigint) => {
    return writeContractAsync({
      address: addresses.LBTToken,
      abi: erc20Abi,
      functionName: "approve",
      args: [addresses.BettingCore, amount],
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
 * Get compressed odds for a match outcome [1.25x - 2.05x range]
 */
export function useOdds(roundId?: bigint, matchIndex?: bigint, prediction?: number) {
  const addresses = useContractAddresses();
  return useReadContract({
    address: addresses.BettingCore,
    abi: BETTING_CORE_ABI,
    functionName: "getOdds",
    args: roundId !== undefined && matchIndex !== undefined && prediction !== undefined
      ? [roundId, matchIndex, prediction as any]
      : undefined,
    query: {
      enabled: roundId !== undefined && matchIndex !== undefined && prediction !== undefined,
      refetchInterval: 30000, // Refresh every 30s
    },
  });
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
export function useUserClaimable(userAddress?: Address) {
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

// ============================================================================
// BETTING CORE - WRITE HOOKS
// ============================================================================

/**
 * Place a bet with LBT (no token parameter needed!)
 */
export function usePlaceBet() {
  const addresses = useContractAddresses();
  const { writeContractAsync } = useWriteContract();

  return async (
    amount: bigint,
    matchIndices: bigint[],
    predictions: number[]
  ) => {
    return writeContractAsync({
      address: addresses.BettingCore,
      abi: BETTING_CORE_ABI,
      functionName: "placeBet",
      args: [amount, matchIndices, predictions as any],
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
 * Claim winnings for a bet
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

// ============================================================================
// LBT POOL HOOKS
// ============================================================================

/**
 * Get pool liquidity stats
 */
export function usePoolLiquidity() {
  const addresses = useContractAddresses();

  const totalLiquidity = useReadContract({
    address: addresses.LBTPool,
    abi: LBT_POOL_ABI,
    functionName: "totalLiquidity",
  });

  const lockedLiquidity = useReadContract({
    address: addresses.LBTPool,
    abi: LBT_POOL_ABI,
    functionName: "lockedLiquidity",
  });

  const availableLiquidity = useReadContract({
    address: addresses.LBTPool,
    abi: LBT_POOL_ABI,
    functionName: "getAvailableLiquidity",
  });

  return {
    totalLiquidity: totalLiquidity.data,
    lockedLiquidity: lockedLiquidity.data,
    availableLiquidity: availableLiquidity.data,
    isLoading: totalLiquidity.isLoading || lockedLiquidity.isLoading || availableLiquidity.isLoading,
  };
}

/**
 * Get user's LP shares
 */
export function useLPShares(userAddress?: Address) {
  const addresses = useContractAddresses();
  const { address } = useAccount();
  const effectiveAddress = userAddress || address;

  return useReadContract({
    address: addresses.LBTPool,
    abi: LBT_POOL_ABI,
    functionName: "lpShares",
    args: effectiveAddress ? [effectiveAddress] : undefined,
    query: { enabled: !!effectiveAddress },
  });
}

/**
 * Add liquidity to LBT pool
 */
export function useAddLiquidity() {
  const addresses = useContractAddresses();
  const { writeContractAsync } = useWriteContract();

  return async (amount: bigint) => {
    return writeContractAsync({
      address: addresses.LBTPool,
      abi: LBT_POOL_ABI,
      functionName: "addLiquidity",
      args: [amount],
    });
  };
}

/**
 * Remove liquidity from LBT pool
 */
export function useRemoveLiquidity() {
  const addresses = useContractAddresses();
  const { writeContractAsync } = useWriteContract();

  return async (shares: bigint) => {
    return writeContractAsync({
      address: addresses.LBTPool,
      abi: LBT_POOL_ABI,
      functionName: "removeLiquidity",
      args: [shares],
    });
  };
}

// ============================================================================
// COMPOSITE HOOKS
// ============================================================================

/**
 * Place bet with automatic LBT approval
 */
export function usePlaceBetWithApproval() {
  const { address } = useAccount();
  const approveLBT = useApproveLBT();
  const placeBet = usePlaceBet();
  const { data: allowance, refetch: refetchAllowance } = useLBTAllowance();

  return async (
    amount: bigint,
    matchIndices: bigint[],
    predictions: number[]
  ) => {
    if (!address) throw new Error("Wallet not connected");

    // Check allowance
    const currentAllowance = await refetchAllowance();

    // Approve if needed
    if (!currentAllowance.data || currentAllowance.data < amount) {
      await approveLBT(amount);
    }

    // Place bet
    return placeBet(amount, matchIndices, predictions);
  };
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
      logs.forEach(log => callback?.(log));
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
      logs.forEach(log => callback?.(log));
    },
  });
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * Format odds from Wei (1e18) to decimal string
 * Odds are compressed to [1.25x - 2.05x] range
 */
export function formatOdds(oddsWei: bigint): string {
  const odds = Number(formatUnits(oddsWei, 18));
  return odds.toFixed(2) + "x";
}

/**
 * Calculate potential payout
 */
export function calculatePayout(
  amount: bigint,
  odds: bigint[]
): bigint {
  // Multiply all odds
  let combinedOdds = parseUnits("1", 18);
  for (const odd of odds) {
    combinedOdds = (combinedOdds * odd) / parseUnits("1", 18);
  }

  // Calculate payout
  return (amount * combinedOdds) / parseUnits("1", 18);
}

/**
 * Get bet status label
 */
export function getBetStatusLabel(status: BetStatus): string {
  return ["Active", "Claimed", "Lost", "Cancelled"][status] || "Unknown";
}

/**
 * Get outcome label
 */
export function getOutcomeLabel(outcome: Outcome): string {
  return ["None", "Home Win", "Away Win", "Draw"][outcome] || "Unknown";
}

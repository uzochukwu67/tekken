/**
 * Web3 Hooks for SeasonPredictor Contract
 * Updated: 2026-02-12 - Matches latest SeasonPredictor.sol
 */

import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { DEPLOYED_ADDRESSES } from '@/contracts/addresses';
import SeasonPredictorABI from '@/abis/SeasonPredictor.json';

// ============ Type Definitions ============

interface UserPrediction {
  teamId: bigint;
  timestamp: bigint;
  claimed: boolean;
}

interface SeasonPool {
  totalPool: bigint;
  winningTeamId: bigint;
  totalWinners: bigint;
  rewardPerWinner: bigint;
  finalized: boolean;
}

interface PredictionStatus {
  canPredict: boolean;
  currentRound: bigint;
  deadline: bigint;
}

interface WinnerStatus {
  isWinner: boolean;
  rewardAmount: bigint;
}

// ============ Read Hooks ============

/**
 * Get user's prediction for a season
 */
export function useUserPrediction(
  seasonId: bigint | undefined,
  address: string | undefined
) {
  return useReadContract({
    address: DEPLOYED_ADDRESSES.seasonPredictor as `0x${string}`,
    abi: SeasonPredictorABI,
    functionName: 'getUserPrediction',
    args: seasonId !== undefined && address ? [seasonId, address] : undefined,
    query: {
      enabled: seasonId !== undefined && !!address,
      select: (data): UserPrediction | undefined => {
        if (!data) return undefined;
        const [teamId, timestamp, claimed] = data as [bigint, bigint, boolean];
        return { teamId, timestamp, claimed };
      },
    },
  });
}

/**
 * Get complete season pool data
 */
export function useSeasonPool(seasonId: bigint | undefined) {
  return useReadContract({
    address: DEPLOYED_ADDRESSES.seasonPredictor as `0x${string}`,
    abi: SeasonPredictorABI,
    functionName: 'getSeasonPool',
    args: seasonId !== undefined ? [seasonId] : undefined,
    query: {
      enabled: seasonId !== undefined,
      refetchInterval: 10000,
      select: (data): SeasonPool | undefined => {
        if (!data) return undefined;
        const [totalPool, winningTeamId, totalWinners, rewardPerWinner, finalized] =
          data as [bigint, bigint, bigint, bigint, boolean];
        return { totalPool, winningTeamId, totalWinners, rewardPerWinner, finalized };
      },
    },
  });
}

/**
 * Get prediction count for a specific team
 */
export function useTeamPredictionCount(
  seasonId: bigint | undefined,
  teamId: number | undefined
) {
  return useReadContract({
    address: DEPLOYED_ADDRESSES.seasonPredictor as `0x${string}`,
    abi: SeasonPredictorABI,
    functionName: 'getTeamPredictionCount',
    args: seasonId !== undefined && teamId !== undefined ? [seasonId, BigInt(teamId)] : undefined,
    query: {
      enabled: seasonId !== undefined && teamId !== undefined && teamId >= 0 && teamId < 20,
    },
  });
}

/**
 * Check if predictions are still open
 */
export function useCanMakePredictions() {
  return useReadContract({
    address: DEPLOYED_ADDRESSES.seasonPredictor as `0x${string}`,
    abi: SeasonPredictorABI,
    functionName: 'canMakePredictions',
    query: {
      refetchInterval: 60000,
      select: (data): PredictionStatus | undefined => {
        if (!data) return undefined;
        const [canPredict, currentRound, deadline] = data as [boolean, bigint, bigint];
        return { canPredict, currentRound, deadline };
      },
    },
  });
}

/**
 * Get all predictors for a team
 */
export function useTeamPredictors(
  seasonId: bigint | undefined,
  teamId: number | undefined
) {
  return useReadContract({
    address: DEPLOYED_ADDRESSES.seasonPredictor as `0x${string}`,
    abi: SeasonPredictorABI,
    functionName: 'getTeamPredictors',
    args: seasonId !== undefined && teamId !== undefined ? [seasonId, BigInt(teamId)] : undefined,
    query: {
      enabled: seasonId !== undefined && teamId !== undefined,
    },
  });
}

/**
 * Check if user is a winner and reward amount
 */
export function useCheckWinner(
  seasonId: bigint | undefined,
  address: string | undefined
) {
  return useReadContract({
    address: DEPLOYED_ADDRESSES.seasonPredictor as `0x${string}`,
    abi: SeasonPredictorABI,
    functionName: 'checkWinner',
    args: seasonId !== undefined && address ? [seasonId, address] : undefined,
    query: {
      enabled: seasonId !== undefined && !!address,
      select: (data): WinnerStatus | undefined => {
        if (!data) return undefined;
        const [isWinner, rewardAmount] = data as [boolean, bigint];
        return { isWinner, rewardAmount };
      },
    },
  });
}

// ============ Write Hooks ============

/**
 * Make a prediction for season winner
 */
export function useMakePrediction() {
  const { writeContract, data: hash, ...rest } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const makePrediction = (seasonId: bigint, teamId: number) => {
    writeContract({
      address: DEPLOYED_ADDRESSES.seasonPredictor as `0x${string}`,
      abi: SeasonPredictorABI,
      functionName: 'makePrediction',
      args: [seasonId, BigInt(teamId)],
    });
  };

  return { makePrediction, hash, isConfirming, isSuccess, ...rest };
}

/**
 * Claim reward for correct prediction
 */
export function useClaimReward() {
  const { writeContract, data: hash, ...rest } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const claimReward = (seasonId: bigint) => {
    writeContract({
      address: DEPLOYED_ADDRESSES.seasonPredictor as `0x${string}`,
      abi: SeasonPredictorABI,
      functionName: 'claimReward',
      args: [seasonId],
    });
  };

  return { claimReward, hash, isConfirming, isSuccess, ...rest };
}

// ============ Composite Hooks ============

/**
 * Get complete season prediction data for user
 */
export function useUserSeasonData(
  seasonId: bigint | undefined,
  address: string | undefined
) {
  const { data: prediction, isLoading: l1 } = useUserPrediction(seasonId, address);
  const { data: pool, isLoading: l2 } = useSeasonPool(seasonId);
  const { data: winner, isLoading: l3 } = useCheckWinner(seasonId, address);
  const { data: predictionStatus, isLoading: l4 } = useCanMakePredictions();

  return {
    prediction,
    hasPredicted: prediction?.timestamp ? prediction.timestamp > 0n : false,
    pool,
    prizePool: pool?.totalPool,
    winningTeam: pool?.winningTeamId,
    isFinalized: pool?.finalized,
    isWinner: winner?.isWinner,
    rewardAmount: winner?.rewardAmount,
    hasClaimed: prediction?.claimed,
    canPredict: predictionStatus?.canPredict,
    currentRound: predictionStatus?.currentRound,
    predictionDeadline: predictionStatus?.deadline,
    isLoading: l1 || l2 || l3 || l4,
  };
}

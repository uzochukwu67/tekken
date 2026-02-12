/**
 * Example Component: Season Prediction Interface
 * Shows how to use the SeasonPredictor hooks
 */

import { useAccount } from 'wagmi';
import {
  useUserSeasonData,
  useMakePrediction,
  useClaimReward,
  useSeasonPool,
} from './useSeasonPredictor';

export function SeasonPredictionCard() {
  const { address } = useAccount();
  const seasonId = 1n; // Current season

  const {
    hasPredicted,
    prediction,
    pool,
    isWinner,
    rewardAmount,
    hasClaimed,
    canPredict,
    currentRound,
    predictionDeadline,
    isLoading,
  } = useUserSeasonData(seasonId, address);

  const { makePrediction, isConfirming: isPredicting } = useMakePrediction();
  const { claimReward, isConfirming: isClaiming } = useClaimReward();

  if (isLoading) {
    return <div className="animate-pulse">Loading season data...</div>;
  }

  return (
    <div className="border rounded-lg p-6 max-w-2xl">
      <h2 className="text-2xl font-bold mb-4">Season {seasonId.toString()} Predictions</h2>

      {/* Season Info */}
      <div className="mb-6 space-y-2">
        <div className="flex justify-between">
          <span className="text-gray-600">Prize Pool:</span>
          <span className="font-bold">
            {pool ? (Number(pool.totalPool) / 1e18).toFixed(2) : '0'} LBT
          </span>
        </div>
        <div className="flex justify-between">
          <span className="text-gray-600">Current Round:</span>
          <span>{currentRound?.toString() || '?'}</span>
        </div>
        <div className="flex justify-between">
          <span className="text-gray-600">Prediction Deadline:</span>
          <span>Round {predictionDeadline?.toString() || '18'}</span>
        </div>
        <div className="flex justify-between">
          <span className="text-gray-600">Status:</span>
          <span
            className={
              canPredict ? 'text-green-600 font-semibold' : 'text-red-600 font-semibold'
            }
          >
            {canPredict ? 'Predictions Open' : 'Deadline Passed'}
          </span>
        </div>
      </div>

      {/* No Prediction Yet - Show Selection */}
      {!hasPredicted && canPredict && (
        <div className="space-y-3">
          <h3 className="font-semibold">Make Your Prediction</h3>
          <p className="text-sm text-gray-600">
            Predict which team will win the season! Free to play, winners split the prize pool.
          </p>
          <select
            className="w-full p-2 border rounded"
            onChange={(e) => {
              const teamId = Number(e.target.value);
              if (teamId >= 0) makePrediction(seasonId, teamId);
            }}
            disabled={isPredicting}
          >
            <option value="-1">Select winning team...</option>
            {Array.from({ length: 20 }, (_, i) => (
              <option key={i} value={i}>
                Team {i} - {getTeamName(i)}
              </option>
            ))}
          </select>
          {isPredicting && (
            <div className="text-sm text-blue-600">Submitting prediction...</div>
          )}
        </div>
      )}

      {/* Deadline Passed - Can't Predict */}
      {!hasPredicted && !canPredict && (
        <div className="bg-yellow-50 border border-yellow-200 rounded p-4">
          <p className="text-yellow-800">
            Prediction deadline has passed. Predictions close at Round 18.
          </p>
        </div>
      )}

      {/* Has Predicted - Show Status */}
      {hasPredicted && (
        <div className="space-y-4">
          <div className="bg-blue-50 border border-blue-200 rounded p-4">
            <div className="flex justify-between items-center">
              <span className="text-blue-800 font-semibold">Your Prediction:</span>
              <span className="text-blue-900 font-bold">
                Team {prediction?.teamId.toString()} - {getTeamName(Number(prediction?.teamId))}
              </span>
            </div>
            <div className="text-sm text-blue-600 mt-1">
              Predicted at round {calculateRoundFromTimestamp(prediction?.timestamp || 0n)}
            </div>
          </div>

          {/* Season Not Finalized */}
          {!pool?.finalized && (
            <div className="text-center text-gray-600 p-4">
              <p>Season in progress... Check back at season end to see if you won!</p>
            </div>
          )}

          {/* Season Finalized - Winner! */}
          {pool?.finalized && isWinner && !hasClaimed && (
            <div className="bg-green-50 border-2 border-green-500 rounded p-6 text-center">
              <div className="text-4xl mb-3">🎉</div>
              <h3 className="text-2xl font-bold text-green-800 mb-2">You Won!</h3>
              <p className="text-green-700 mb-4">
                Congratulations! Your prediction was correct.
              </p>
              <div className="text-3xl font-bold text-green-900 mb-4">
                {rewardAmount ? (Number(rewardAmount) / 1e18).toFixed(2) : '0'} LBT
              </div>
              <button
                onClick={() => claimReward(seasonId)}
                disabled={isClaiming}
                className="bg-green-600 text-white px-6 py-3 rounded-lg font-semibold hover:bg-green-700 disabled:bg-gray-400"
              >
                {isClaiming ? 'Claiming...' : 'Claim Reward'}
              </button>
            </div>
          )}

          {/* Season Finalized - Already Claimed */}
          {pool?.finalized && hasClaimed && (
            <div className="bg-gray-100 border border-gray-300 rounded p-4 text-center">
              <p className="text-gray-700 font-semibold">✅ Reward Claimed!</p>
              <p className="text-sm text-gray-600 mt-1">
                You received {rewardAmount ? (Number(rewardAmount) / 1e18).toFixed(2) : '0'} LBT
              </p>
            </div>
          )}

          {/* Season Finalized - Lost */}
          {pool?.finalized && !isWinner && (
            <div className="bg-red-50 border border-red-200 rounded p-4 text-center">
              <p className="text-red-800">Sorry, your prediction was incorrect.</p>
              <p className="text-sm text-red-600 mt-1">
                Winning team: Team {pool.winningTeamId.toString()}
              </p>
              <p className="text-sm text-gray-600 mt-2">
                Better luck next season!
              </p>
            </div>
          )}
        </div>
      )}

      {/* Prize Pool Info */}
      {pool?.finalized && (
        <div className="mt-6 pt-4 border-t space-y-2 text-sm">
          <div className="flex justify-between">
            <span className="text-gray-600">Total Winners:</span>
            <span>{pool.totalWinners.toString()}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-gray-600">Reward Per Winner:</span>
            <span>{(Number(pool.rewardPerWinner) / 1e18).toFixed(2)} LBT</span>
          </div>
        </div>
      )}
    </div>
  );
}

// Helper function to get team names (replace with your actual team data)
function getTeamName(teamId: number): string {
  const teamNames = [
    'Manchester City', 'Arsenal', 'Liverpool', 'Aston Villa', 'Tottenham',
    'Newcastle', 'Manchester United', 'West Ham', 'Chelsea', 'Brighton',
    'Wolves', 'Fulham', 'Bournemouth', 'Crystal Palace', 'Brentford',
    'Everton', 'Nottingham Forest', 'Luton', 'Burnley', 'Sheffield United'
  ];
  return teamNames[teamId] || `Team ${teamId}`;
}

// Helper function to estimate round from timestamp
function calculateRoundFromTimestamp(timestamp: bigint): number {
  if (timestamp === 0n) return 0;
  // Simplified calculation - adjust based on your round timing
  const ROUND_DURATION = 3 * 60 * 60; // 3 hours
  const seasonStart = 1700000000; // Your season start timestamp
  const elapsed = Number(timestamp) - seasonStart;
  return Math.floor(elapsed / ROUND_DURATION) + 1;
}

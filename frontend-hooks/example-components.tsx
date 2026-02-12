/**
 * Example React Components using Betting Hooks
 * Copy these patterns into your actual components
 */

import { useState, useEffect } from "react";
import { parseUnits, formatUnits } from "viem";
import { useAccount } from "wagmi";
import {
  useCurrentRound,
  useRoundSummary,
  useMatchOdds,
  usePlaceBetWithApproval,
  useBet,
  useUserClaimable,
  useBatchClaim,
  useLPPosition,
  usePoolUtilization,
  useAddLiquidityWithApproval,
  useRemoveLiquidity,
  formatOdds,
  getParlayMultiplier,
  calculatePayout,
  getBetStatusLabel,
  getOutcomeLabel,
  BetStatus,
  Outcome,
  CONTRACTS,
} from "./betting-hooks";

// ============================================================================
// BETTING COMPONENTS
// ============================================================================

/**
 * Display current round information
 */
export function RoundHeader() {
  const { data: currentRoundId, isLoading: isLoadingRound } = useCurrentRound();
  const { data: roundSummary, isLoading: isLoadingSummary } = useRoundSummary(currentRoundId);

  if (isLoadingRound || isLoadingSummary) {
    return <div className="animate-pulse">Loading round...</div>;
  }

  if (!roundSummary) return null;

  const endTime = new Date(Number(roundSummary.roundEndTime) * 1000);
  const isEnded = Date.now() > endTime.getTime();

  return (
    <div className="round-header bg-gradient-to-r from-blue-500 to-purple-600 text-white p-6 rounded-lg">
      <h2 className="text-2xl font-bold mb-2">Round #{currentRoundId?.toString()}</h2>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mt-4">
        <div>
          <p className="text-sm opacity-80">Status</p>
          <p className="font-semibold">
            {roundSummary.settled ? "Settled" : isEnded ? "Ended" : "Active"}
          </p>
        </div>

        <div>
          <p className="text-sm opacity-80">Ends At</p>
          <p className="font-semibold">{endTime.toLocaleString()}</p>
        </div>

        <div>
          <p className="text-sm opacity-80">Total Bets</p>
          <p className="font-semibold">{roundSummary.totalBetCount.toString()}</p>
        </div>

        <div>
          <p className="text-sm opacity-80">Volume</p>
          <p className="font-semibold">
            {formatUnits(roundSummary.totalBetVolume, 6)} USDC
          </p>
        </div>
      </div>

      {!isEnded && <CountdownTimer endTime={endTime} />}
    </div>
  );
}

/**
 * Countdown timer component
 */
function CountdownTimer({ endTime }: { endTime: Date }) {
  const [timeLeft, setTimeLeft] = useState("");

  useEffect(() => {
    const interval = setInterval(() => {
      const now = new Date().getTime();
      const distance = endTime.getTime() - now;

      if (distance < 0) {
        setTimeLeft("Ended");
        clearInterval(interval);
        return;
      }

      const hours = Math.floor((distance % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
      const minutes = Math.floor((distance % (1000 * 60 * 60)) / (1000 * 60));
      const seconds = Math.floor((distance % (1000 * 60)) / 1000);

      setTimeLeft(`${hours}h ${minutes}m ${seconds}s`);
    }, 1000);

    return () => clearInterval(interval);
  }, [endTime]);

  return (
    <div className="mt-4 text-center">
      <p className="text-sm opacity-80">Time Remaining</p>
      <p className="text-2xl font-mono font-bold">{timeLeft}</p>
    </div>
  );
}

/**
 * Display a single match with odds
 */
export function MatchCard({
  matchIndex,
  roundId,
  onSelectOutcome,
}: {
  matchIndex: number;
  roundId: bigint;
  onSelectOutcome: (matchIndex: number, outcome: Outcome, odds: bigint) => void;
}) {
  const { homeOdds, awayOdds, drawOdds, isLoading } = useMatchOdds(roundId, BigInt(matchIndex));

  if (isLoading) {
    return <div className="animate-pulse bg-gray-200 h-24 rounded"></div>;
  }

  return (
    <div className="match-card border rounded-lg p-4 hover:shadow-lg transition-shadow">
      <h3 className="font-semibold mb-3">Match {matchIndex + 1}</h3>

      <div className="grid grid-cols-3 gap-2">
        <button
          onClick={() => homeOdds && onSelectOutcome(matchIndex, Outcome.HomeWin, homeOdds)}
          className="odds-btn bg-green-500 hover:bg-green-600 text-white py-3 px-4 rounded transition-colors"
        >
          <div className="text-xs">Home</div>
          <div className="text-lg font-bold">{homeOdds ? formatOdds(homeOdds) : "..."}</div>
        </button>

        <button
          onClick={() => drawOdds && onSelectOutcome(matchIndex, Outcome.Draw, drawOdds)}
          className="odds-btn bg-yellow-500 hover:bg-yellow-600 text-white py-3 px-4 rounded transition-colors"
        >
          <div className="text-xs">Draw</div>
          <div className="text-lg font-bold">{drawOdds ? formatOdds(drawOdds) : "..."}</div>
        </button>

        <button
          onClick={() => awayOdds && onSelectOutcome(matchIndex, Outcome.AwayWin, awayOdds)}
          className="odds-btn bg-blue-500 hover:bg-blue-600 text-white py-3 px-4 rounded transition-colors"
        >
          <div className="text-xs">Away</div>
          <div className="text-lg font-bold">{awayOdds ? formatOdds(awayOdds) : "..."}</div>
        </button>
      </div>
    </div>
  );
}

/**
 * Matches grid showing all 10 matches
 */
export function MatchesGrid() {
  const { data: currentRoundId } = useCurrentRound();
  const [selections, setSelections] = useState<Array<{
    matchIndex: number;
    outcome: Outcome;
    odds: bigint;
  }>>([]);

  const handleSelectOutcome = (matchIndex: number, outcome: Outcome, odds: bigint) => {
    // Toggle selection
    const existing = selections.findIndex(s => s.matchIndex === matchIndex);
    if (existing >= 0) {
      setSelections(selections.filter((_, i) => i !== existing));
    } else {
      setSelections([...selections, { matchIndex, outcome, odds }]);
    }
  };

  if (!currentRoundId) return <div>Loading...</div>;

  return (
    <div>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {Array.from({ length: 10 }, (_, i) => (
          <MatchCard
            key={i}
            matchIndex={i}
            roundId={currentRoundId}
            onSelectOutcome={handleSelectOutcome}
          />
        ))}
      </div>

      {selections.length > 0 && (
        <BetSlip selections={selections} onClear={() => setSelections([])} />
      )}
    </div>
  );
}

/**
 * Bet slip for placing bets
 */
export function BetSlip({
  selections,
  onClear,
}: {
  selections: Array<{ matchIndex: number; outcome: Outcome; odds: bigint }>;
  onClear: () => void;
}) {
  const [amount, setAmount] = useState("");
  const [isPlacing, setIsPlacing] = useState(false);
  const placeBet = usePlaceBetWithApproval();
  const { chainId } = useAccount();

  const potentialPayout = amount && selections.length > 0
    ? calculatePayout(
        parseUnits(amount, 6),
        selections.map(s => s.odds),
        selections.length
      )
    : 0n;

  const parlayMultiplier = getParlayMultiplier(selections.length);

  const handlePlaceBet = async () => {
    if (!amount || selections.length === 0) return;

    setIsPlacing(true);
    try {
      const token = CONTRACTS[chainId === 11155111 ? "sepolia" : "mainnet"].USDC;
      const matchIndices = selections.map(s => BigInt(s.matchIndex));
      const predictions = selections.map(s => s.outcome);

      await placeBet(token, parseUnits(amount, 6), matchIndices, predictions);

      alert("Bet placed successfully!");
      setAmount("");
      onClear();
    } catch (error: any) {
      alert(`Error: ${error.message}`);
    } finally {
      setIsPlacing(false);
    }
  };

  return (
    <div className="bet-slip fixed bottom-0 right-0 w-full md:w-96 bg-white border-t md:border-l shadow-2xl p-6 max-h-screen overflow-y-auto">
      <div className="flex justify-between items-center mb-4">
        <h2 className="text-xl font-bold">Bet Slip</h2>
        <button onClick={onClear} className="text-red-500 hover:text-red-700">
          Clear All
        </button>
      </div>

      <div className="space-y-2 mb-4">
        {selections.map((sel, i) => (
          <div key={i} className="flex justify-between items-center p-2 bg-gray-100 rounded">
            <div>
              <div className="font-semibold">Match {sel.matchIndex + 1}</div>
              <div className="text-sm text-gray-600">{getOutcomeLabel(sel.outcome)}</div>
            </div>
            <div className="font-bold">{formatOdds(sel.odds)}</div>
          </div>
        ))}
      </div>

      {selections.length > 1 && (
        <div className="bg-blue-50 p-3 rounded mb-4">
          <div className="flex justify-between text-sm">
            <span>Parlay Bonus ({selections.length} legs)</span>
            <span className="font-semibold">{parlayMultiplier.toFixed(2)}x</span>
          </div>
        </div>
      )}

      <div className="mb-4">
        <label className="block text-sm font-medium mb-2">Bet Amount (USDC)</label>
        <input
          type="number"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          placeholder="0.00"
          className="w-full border rounded px-3 py-2 focus:ring-2 focus:ring-blue-500"
        />
      </div>

      {potentialPayout > 0n && (
        <div className="bg-green-50 p-4 rounded mb-4">
          <div className="text-sm text-gray-600">Potential Win</div>
          <div className="text-2xl font-bold text-green-600">
            {formatUnits(potentialPayout, 6)} USDC
          </div>
        </div>
      )}

      <button
        onClick={handlePlaceBet}
        disabled={isPlacing || !amount || selections.length === 0}
        className="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-gray-400 text-white font-semibold py-3 rounded transition-colors"
      >
        {isPlacing ? "Placing Bet..." : "Place Bet"}
      </button>
    </div>
  );
}

/**
 * Display user's bet
 */
export function BetCard({ betId }: { betId: bigint }) {
  const { data: bet, isLoading } = useBet(betId);
  const claimWinnings = useBatchClaim();
  const [isClaiming, setIsClaiming] = useState(false);

  if (isLoading) return <div>Loading bet...</div>;
  if (!bet) return <div>Bet not found</div>;

  const statusColors = {
    [BetStatus.Active]: "bg-blue-100 text-blue-800",
    [BetStatus.Won]: "bg-green-100 text-green-800",
    [BetStatus.Lost]: "bg-red-100 text-red-800",
    [BetStatus.Cancelled]: "bg-gray-100 text-gray-800",
  };

  const handleClaim = async () => {
    setIsClaiming(true);
    try {
      await claimWinnings([betId]);
      alert("Winnings claimed!");
    } catch (error: any) {
      alert(`Error: ${error.message}`);
    } finally {
      setIsClaiming(false);
    }
  };

  return (
    <div className="bet-card border rounded-lg p-4 hover:shadow-md transition-shadow">
      <div className="flex justify-between items-start mb-3">
        <h3 className="font-bold">Bet #{betId.toString()}</h3>
        <span className={`px-2 py-1 rounded text-xs font-semibold ${statusColors[bet.status]}`}>
          {getBetStatusLabel(bet.status)}
        </span>
      </div>

      <div className="space-y-2 text-sm">
        <div className="flex justify-between">
          <span className="text-gray-600">Amount:</span>
          <span className="font-semibold">{formatUnits(bet.amount, 6)} USDC</span>
        </div>

        <div className="flex justify-between">
          <span className="text-gray-600">Potential Win:</span>
          <span className="font-semibold">{formatUnits(bet.potentialPayout, 6)} USDC</span>
        </div>

        <div className="flex justify-between">
          <span className="text-gray-600">Legs:</span>
          <span className="font-semibold">{bet.legCount}</span>
        </div>

        <div className="flex justify-between">
          <span className="text-gray-600">Round:</span>
          <span className="font-semibold">#{bet.roundId.toString()}</span>
        </div>
      </div>

      <div className="mt-3 pt-3 border-t">
        <p className="text-xs text-gray-600 mb-2">Predictions:</p>
        <div className="space-y-1">
          {bet.predictions.map((pred: any, i: number) => (
            <div key={i} className="text-sm flex justify-between">
              <span>Match {pred.matchIndex.toString()}</span>
              <span className="font-medium">{getOutcomeLabel(pred.predictedOutcome)}</span>
            </div>
          ))}
        </div>
      </div>

      {bet.status === BetStatus.Won && bet.actualPayout > 0n && (
        <button
          onClick={handleClaim}
          disabled={isClaiming}
          className="w-full mt-4 bg-green-600 hover:bg-green-700 disabled:bg-gray-400 text-white font-semibold py-2 rounded"
        >
          {isClaiming ? "Claiming..." : `Claim ${formatUnits(bet.actualPayout, 6)} USDC`}
        </button>
      )}
    </div>
  );
}

/**
 * Display user's claimable winnings
 */
export function ClaimableWinnings() {
  const { address } = useAccount();
  const { data: claimable, isLoading } = useUserClaimable(address);
  const batchClaim = useBatchClaim();
  const [isClaiming, setIsClaiming] = useState(false);

  if (isLoading) return <div>Loading...</div>;
  if (!claimable || claimable[1].length === 0) {
    return <div className="text-center text-gray-500 py-8">No winnings to claim</div>;
  }

  const [totalClaimable, betIds] = claimable;

  const handleClaimAll = async () => {
    setIsClaiming(true);
    try {
      await batchClaim(betIds);
      alert("All winnings claimed!");
    } catch (error: any) {
      alert(`Error: ${error.message}`);
    } finally {
      setIsClaiming(false);
    }
  };

  return (
    <div className="claimable-winnings bg-gradient-to-r from-green-400 to-green-600 text-white p-6 rounded-lg">
      <h2 className="text-2xl font-bold mb-2">Claimable Winnings</h2>
      <p className="text-3xl font-bold mb-4">
        {formatUnits(totalClaimable, 6)} USDC
      </p>
      <p className="text-sm opacity-90 mb-4">
        From {betIds.length} winning bet{betIds.length !== 1 ? "s" : ""}
      </p>
      <button
        onClick={handleClaimAll}
        disabled={isClaiming}
        className="bg-white text-green-600 font-semibold px-6 py-3 rounded-lg hover:bg-gray-100 transition-colors disabled:opacity-50"
      >
        {isClaiming ? "Claiming..." : "Claim All"}
      </button>
    </div>
  );
}

// ============================================================================
// LIQUIDITY PROVIDER COMPONENTS
// ============================================================================

/**
 * LP Dashboard showing position
 */
export function LPDashboard() {
  const { address, chainId } = useAccount();
  const token = CONTRACTS[chainId === 11155111 ? "sepolia" : "mainnet"].USDC;
  const { data: position, isLoading } = useLPPosition(token, address);

  if (isLoading) return <div>Loading position...</div>;
  if (!position) return <div>No position</div>;

  const sharePercent = (Number(position.sharePercentage) / 100).toFixed(2);
  const profitLoss = Number(formatUnits(
    position.profitLoss < 0n ? -position.profitLoss : position.profitLoss,
    6
  ));
  const isProfit = position.profitLoss >= 0n;

  return (
    <div className="lp-dashboard bg-white border rounded-lg p-6">
      <h2 className="text-2xl font-bold mb-6">Your LP Position</h2>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="stat">
          <p className="text-sm text-gray-600">Current Value</p>
          <p className="text-2xl font-bold">{formatUnits(position.shareValue, 6)}</p>
          <p className="text-xs text-gray-500">USDC</p>
        </div>

        <div className="stat">
          <p className="text-sm text-gray-600">Share of Pool</p>
          <p className="text-2xl font-bold">{sharePercent}%</p>
        </div>

        <div className="stat">
          <p className="text-sm text-gray-600">Total Deposited</p>
          <p className="text-2xl font-bold">{formatUnits(position.totalDeposited, 6)}</p>
          <p className="text-xs text-gray-500">USDC</p>
        </div>

        <div className={`stat ${isProfit ? "text-green-600" : "text-red-600"}`}>
          <p className="text-sm">P&L</p>
          <p className="text-2xl font-bold">
            {isProfit ? "+" : "-"}{profitLoss.toFixed(2)}
          </p>
          <p className="text-xs">
            {isProfit ? "profit" : "loss"}
          </p>
        </div>
      </div>
    </div>
  );
}

/**
 * Pool statistics display
 */
export function PoolStats() {
  const { chainId } = useAccount();
  const token = CONTRACTS[chainId === 11155111 ? "sepolia" : "mainnet"].USDC;
  const { data: stats, isLoading } = usePoolUtilization(token);

  if (isLoading) return <div>Loading pool stats...</div>;
  if (!stats) return <div>No pool data</div>;

  const [totalLiquidity, lockedLiquidity, availableLiquidity, utilizationBps] = stats;
  const utilizationPercent = Number(utilizationBps) / 100;

  return (
    <div className="pool-stats bg-white border rounded-lg p-6">
      <h3 className="text-xl font-bold mb-4">Pool Statistics</h3>

      <div className="space-y-3">
        <div className="flex justify-between">
          <span className="text-gray-600">Total Liquidity:</span>
          <span className="font-semibold">{formatUnits(totalLiquidity, 6)} USDC</span>
        </div>

        <div className="flex justify-between">
          <span className="text-gray-600">Locked (Active Bets):</span>
          <span className="font-semibold">{formatUnits(lockedLiquidity, 6)} USDC</span>
        </div>

        <div className="flex justify-between">
          <span className="text-gray-600">Available:</span>
          <span className="font-semibold text-green-600">
            {formatUnits(availableLiquidity, 6)} USDC
          </span>
        </div>
      </div>

      <div className="mt-4">
        <div className="flex justify-between text-sm mb-2">
          <span>Utilization</span>
          <span className="font-semibold">{utilizationPercent.toFixed(1)}%</span>
        </div>
        <div className="w-full bg-gray-200 rounded-full h-3 overflow-hidden">
          <div
            className="bg-blue-600 h-full transition-all duration-500"
            style={{ width: `${utilizationPercent}%` }}
          />
        </div>
      </div>
    </div>
  );
}

/**
 * Add liquidity component
 */
export function AddLiquidityForm() {
  const { chainId } = useAccount();
  const [amount, setAmount] = useState("");
  const [isDepositing, setIsDepositing] = useState(false);

  const token = CONTRACTS[chainId === 11155111 ? "sepolia" : "mainnet"].USDC;
  const { data: balance } = useTokenBalance(token);
  const { data: preview } = useLPPreview(
    token,
    amount ? parseUnits(amount, 6) : undefined
  );
  const addLiquidity = useAddLiquidityWithApproval();

  const handleDeposit = async () => {
    if (!amount) return;

    setIsDepositing(true);
    try {
      await addLiquidity(token, parseUnits(amount, 6));
      alert("Liquidity added successfully!");
      setAmount("");
    } catch (error: any) {
      alert(`Error: ${error.message}`);
    } finally {
      setIsDepositing(false);
    }
  };

  return (
    <div className="add-liquidity bg-white border rounded-lg p-6">
      <h3 className="text-xl font-bold mb-4">Add Liquidity</h3>

      <div className="mb-4">
        <label className="block text-sm font-medium mb-2">Amount (USDC)</label>
        <input
          type="number"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          placeholder="0.00"
          className="w-full border rounded px-3 py-2 focus:ring-2 focus:ring-blue-500"
        />
        <p className="text-xs text-gray-500 mt-1">
          Balance: {balance ? formatUnits(balance.value, 6) : "0"} USDC
        </p>
      </div>

      {preview && preview[1] > 0n && (
        <div className="bg-blue-50 p-3 rounded mb-4">
          <div className="text-sm text-gray-600">You will receive</div>
          <div className="text-lg font-bold">{formatUnits(preview[1], 6)} LP Shares</div>
        </div>
      )}

      <button
        onClick={handleDeposit}
        disabled={isDepositing || !amount}
        className="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-gray-400 text-white font-semibold py-3 rounded"
      >
        {isDepositing ? "Depositing..." : "Add Liquidity"}
      </button>
    </div>
  );
}

/**
 * Remove liquidity component
 */
export function RemoveLiquidityForm() {
  const { address, chainId } = useAccount();
  const [shares, setShares] = useState("");
  const [isWithdrawing, setIsWithdrawing] = useState(false);

  const token = CONTRACTS[chainId === 11155111 ? "sepolia" : "mainnet"].USDC;
  const { data: position } = useLPPosition(token, address);
  const removeLiquidity = useRemoveLiquidity();

  const handleWithdraw = async () => {
    if (!shares) return;

    setIsWithdrawing(true);
    try {
      await removeLiquidity(token, parseUnits(shares, 6));
      alert("Liquidity removed successfully!");
      setShares("");
    } catch (error: any) {
      alert(`Error: ${error.message}`);
    } finally {
      setIsWithdrawing(false);
    }
  };

  return (
    <div className="remove-liquidity bg-white border rounded-lg p-6">
      <h3 className="text-xl font-bold mb-4">Remove Liquidity</h3>

      <div className="mb-4">
        <label className="block text-sm font-medium mb-2">LP Shares</label>
        <input
          type="number"
          value={shares}
          onChange={(e) => setShares(e.target.value)}
          placeholder="0.00"
          className="w-full border rounded px-3 py-2 focus:ring-2 focus:ring-blue-500"
        />
        <p className="text-xs text-gray-500 mt-1">
          Your shares: {position ? formatUnits(position.shares, 6) : "0"}
        </p>
      </div>

      <button
        onClick={handleWithdraw}
        disabled={isWithdrawing || !shares}
        className="w-full bg-red-600 hover:bg-red-700 disabled:bg-gray-400 text-white font-semibold py-3 rounded"
      >
        {isWithdrawing ? "Withdrawing..." : "Remove Liquidity"}
      </button>
    </div>
  );
}

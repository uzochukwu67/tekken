"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { TrendingUp, Droplets, Lock, Unlock, Loader2, Clock } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from "wagmi"
import { useContracts } from "@/lib/hooks/useContracts"
import {
  useLiquidityPoolStats,
  useUserLPPosition,
  useCalculateDepositShares,
  useCalculateWithdrawAmount,
} from "@/lib/hooks/useLiquidityData"
import { formatUnits, parseUnits } from "viem"
import { toast } from "sonner"

export function LiquidityPoolNew() {
  const { address, isConnected } = useAccount()
  const { liquidityPool, leagueToken } = useContracts()

  const {
    totalLiquidity,
    availableLiquidity,
    lockedLiquidity,
    utilization,
    poolMultiplier,
    isLoading: statsLoading,
  } = useLiquidityPoolStats()

  const { userShares, sharePercentage, currentValue, canWithdraw, cooldownRemaining, isLoading: positionLoading } =
    useUserLPPosition(address)

  const [depositAmount, setDepositAmount] = useState("")
  const [withdrawShares, setWithdrawShares] = useState("")
  const [needsApproval, setNeedsApproval] = useState(true)

  const depositAmountBigInt = depositAmount ? parseUnits(depositAmount, 18) : 0n
  const withdrawSharesBigInt = withdrawShares ? parseUnits(withdrawShares, 18) : 0n

  const { sharesToReceive, shareOfPool } = useCalculateDepositShares(depositAmountBigInt)
  const { amountToReceive } = useCalculateWithdrawAmount(withdrawSharesBigInt)

  const { writeContract: approve, data: approveHash } = useWriteContract()
  const { writeContract: deposit, data: depositHash } = useWriteContract()
  const { writeContract: withdraw, data: withdrawHash } = useWriteContract()

  const { isLoading: isApproving } = useWaitForTransactionReceipt({ hash: approveHash })
  const { isLoading: isDepositing, isSuccess: depositSuccess } = useWaitForTransactionReceipt({ hash: depositHash })
  const { isLoading: isWithdrawing, isSuccess: withdrawSuccess } = useWaitForTransactionReceipt({ hash: withdrawHash })

  // Reset forms on success
  useEffect(() => {
    if (depositSuccess) {
      setDepositAmount("")
      setNeedsApproval(true)
      toast.success("Liquidity deposited successfully!")
    }
  }, [depositSuccess])

  useEffect(() => {
    if (withdrawSuccess) {
      setWithdrawShares("")
      toast.success("Liquidity withdrawn successfully!")
    }
  }, [withdrawSuccess])

  const handleApprove = async () => {
    if (!leagueToken?.address || !liquidityPool?.address || !depositAmountBigInt) return

    try {
      approve({
        address: leagueToken.address,
        abi: leagueToken.abi,
        functionName: "approve",
        args: [liquidityPool.address, depositAmountBigInt],
      })
      setNeedsApproval(false)
      toast.success("Approval transaction sent")
    } catch (error: any) {
      toast.error(error?.message || "Approval failed")
    }
  }

  const handleDeposit = async () => {
    if (!liquidityPool?.address || !depositAmountBigInt) return

    // Check minimum first deposit (1000 LEAGUE)
    const MIN_INITIAL = parseUnits("1000", 18)
    if (userShares === 0n && depositAmountBigInt < MIN_INITIAL) {
      toast.error("First deposit must be at least 1,000 LEAGUE")
      return
    }

    try {
      deposit({
        address: liquidityPool.address,
        abi: liquidityPool.abi,
        functionName: "deposit",
        args: [depositAmountBigInt],
      })
      toast.success("Depositing liquidity...")
    } catch (error: any) {
      toast.error(error?.message || "Deposit failed")
    }
  }

  const handleWithdraw = async () => {
    if (!liquidityPool?.address || !withdrawSharesBigInt) return

    if (!canWithdraw) {
      toast.error(`Cooldown active. Wait ${cooldownRemaining} seconds`)
      return
    }

    if (withdrawSharesBigInt > userShares) {
      toast.error("Insufficient LP shares")
      return
    }

    try {
      withdraw({
        address: liquidityPool.address,
        abi: liquidityPool.abi,
        functionName: "withdraw",
        args: [withdrawSharesBigInt],
      })
      toast.success("Withdrawing liquidity...")
    } catch (error: any) {
      toast.error(error?.message || "Withdrawal failed")
    }
  }

  const utilizationPercent = utilization ? Number(utilization) / 100 : 0

  return (
    <div className="grid lg:grid-cols-3 gap-6">
      {/* Pool Stats */}
      <div className="lg:col-span-2 space-y-6">
        <div>
          <h3 className="text-2xl font-bold mb-2">Liquidity Pool</h3>
          <p className="text-sm text-muted-foreground">Provide liquidity and earn rewards from betting fees</p>
        </div>

        {/* Stats Grid */}
        <div className="grid md:grid-cols-3 gap-4">
          <Card className="bg-card/50 backdrop-blur border-border/40">
            <CardHeader className="pb-3">
              <CardDescription className="text-xs uppercase tracking-wider flex items-center gap-2">
                <Droplets className="w-4 h-4" />
                Total Pool Size
              </CardDescription>
              <CardTitle className="text-3xl font-bold">
                {statsLoading ? (
                  <Loader2 className="w-8 h-8 animate-spin" />
                ) : (
                  `${(Number(formatUnits(totalLiquidity, 18)) / 1000000).toFixed(1)}M`
                )}
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-xs text-muted-foreground">LEAGUE tokens</p>
            </CardContent>
          </Card>

          <Card className="bg-card/50 backdrop-blur border-border/40">
            <CardHeader className="pb-3">
              <CardDescription className="text-xs uppercase tracking-wider flex items-center gap-2">
                <Lock className="w-4 h-4" />
                Locked Liquidity
              </CardDescription>
              <CardTitle className="text-3xl font-bold">
                {statsLoading ? (
                  <Loader2 className="w-8 h-8 animate-spin" />
                ) : (
                  `${(Number(formatUnits(lockedLiquidity, 18)) / 1000).toFixed(0)}K`
                )}
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-xs text-muted-foreground">For active bets</p>
            </CardContent>
          </Card>

          <Card className="bg-card/50 backdrop-blur border-border/40">
            <CardHeader className="pb-3">
              <CardDescription className="text-xs uppercase tracking-wider flex items-center gap-2">
                <TrendingUp className="w-4 h-4" />
                Pool Multiplier
              </CardDescription>
              <CardTitle className="text-3xl font-bold">
                {statsLoading ? <Loader2 className="w-8 h-8 animate-spin" /> : `${Number(poolMultiplier) / 100}x`}
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-xs text-muted-foreground">Current bonus</p>
            </CardContent>
          </Card>
        </div>

        {/* Pool Health */}
        <Card className="bg-card/50 backdrop-blur border-border/40">
          <CardHeader>
            <CardTitle>Pool Health</CardTitle>
            <CardDescription>Current utilization and multiplier</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center justify-between">
              <span className="text-sm text-muted-foreground">Utilization Rate</span>
              <span className="text-lg font-bold">{utilizationPercent.toFixed(1)}%</span>
            </div>
            <div className="h-2 bg-secondary rounded-full overflow-hidden">
              <div className="h-full bg-primary" style={{ width: `${utilizationPercent}%` }} />
            </div>
          </CardContent>
        </Card>

        {/* User Position */}
        {isConnected && userShares > 0n && (
          <Card className="bg-gradient-to-br from-primary/10 to-accent/10 backdrop-blur border-border/40">
            <CardHeader>
              <CardTitle>Your LP Position</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="grid md:grid-cols-3 gap-4">
                <div>
                  <p className="text-xs text-muted-foreground mb-1">LP Shares</p>
                  <p className="text-2xl font-bold">
                    {positionLoading ? <Loader2 className="w-6 h-6 animate-spin" /> : Number(formatUnits(userShares, 18)).toFixed(0)}
                  </p>
                </div>
                <div>
                  <p className="text-xs text-muted-foreground mb-1">Share of Pool</p>
                  <p className="text-2xl font-bold">{(Number(sharePercentage) / 100).toFixed(2)}%</p>
                </div>
                <div>
                  <p className="text-xs text-muted-foreground mb-1">Current Value</p>
                  <p className="text-2xl font-bold">{Number(formatUnits(currentValue, 18)).toFixed(0)} LEAGUE</p>
                </div>
              </div>
              {!canWithdraw && (
                <div className="mt-4 flex items-center gap-2 text-sm text-muted-foreground">
                  <Clock className="w-4 h-4" />
                  <span>Withdrawal cooldown: {Number(cooldownRemaining)} seconds remaining</span>
                </div>
              )}
            </CardContent>
          </Card>
        )}
      </div>

      {/* Deposit/Withdraw */}
      <div className="lg:sticky lg:top-24 h-fit">
        <Card className="bg-gradient-to-br from-card to-card/50 backdrop-blur border-border/40">
          <CardHeader>
            <CardTitle>Manage Liquidity</CardTitle>
            <CardDescription>Deposit or withdraw LP tokens</CardDescription>
          </CardHeader>
          <CardContent>
            <Tabs defaultValue="deposit" className="space-y-4">
              <TabsList className="grid w-full grid-cols-2">
                <TabsTrigger value="deposit">Deposit</TabsTrigger>
                <TabsTrigger value="withdraw">Withdraw</TabsTrigger>
              </TabsList>

              <TabsContent value="deposit" className="space-y-4">
                <div className="space-y-2">
                  <label className="text-sm font-medium">Amount (LEAGUE)</label>
                  <Input
                    type="number"
                    placeholder="1000.00"
                    value={depositAmount}
                    onChange={(e) => setDepositAmount(e.target.value)}
                    disabled={!isConnected}
                  />
                  <p className="text-xs text-muted-foreground">Minimum first deposit: 1,000 LEAGUE</p>
                </div>

                <div className="space-y-2 p-3 bg-secondary/50 rounded-lg">
                  <div className="flex justify-between text-sm">
                    <span className="text-muted-foreground">LP Shares to Receive:</span>
                    <span className="font-bold">
                      {sharesToReceive ? Number(formatUnits(sharesToReceive, 18)).toFixed(0) : "0"}
                    </span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-muted-foreground">Share of Pool:</span>
                    <span className="font-bold">{shareOfPool ? (Number(shareOfPool) / 100).toFixed(2) : "0"}%</span>
                  </div>
                </div>

                {isConnected ? (
                  <div className="space-y-2">
                    {needsApproval && (
                      <Button
                        className="w-full"
                        size="lg"
                        onClick={handleApprove}
                        disabled={!depositAmount || Number(depositAmount) <= 0 || isApproving}
                      >
                        {isApproving && <Loader2 className="w-4 h-4 mr-2 animate-spin" />}
                        {isApproving ? "Approving..." : "Approve LEAGUE"}
                      </Button>
                    )}
                    <Button
                      className="w-full"
                      size="lg"
                      onClick={handleDeposit}
                      disabled={needsApproval || !depositAmount || Number(depositAmount) <= 0 || isDepositing}
                    >
                      <Droplets className="w-4 h-4 mr-2" />
                      {isDepositing && <Loader2 className="w-4 h-4 mr-2 animate-spin" />}
                      {isDepositing ? "Depositing..." : "Deposit Liquidity"}
                    </Button>
                  </div>
                ) : (
                  <Button className="w-full" size="lg" disabled>
                    Connect Wallet
                  </Button>
                )}
              </TabsContent>

              <TabsContent value="withdraw" className="space-y-4">
                <div className="space-y-2">
                  <label className="text-sm font-medium">LP Shares to Burn</label>
                  <Input
                    type="number"
                    placeholder="0"
                    value={withdrawShares}
                    onChange={(e) => setWithdrawShares(e.target.value)}
                    disabled={!isConnected}
                    max={Number(formatUnits(userShares, 18))}
                  />
                  <p className="text-xs text-muted-foreground">
                    Available: {Number(formatUnits(userShares, 18)).toFixed(0)} shares
                  </p>
                  {!canWithdraw && (
                    <p className="text-xs text-amber-500">⏰ 15-minute cooldown active</p>
                  )}
                </div>

                <div className="space-y-2 p-3 bg-secondary/50 rounded-lg">
                  <div className="flex justify-between text-sm">
                    <span className="text-muted-foreground">LEAGUE to Receive:</span>
                    <span className="font-bold">
                      {amountToReceive ? Number(formatUnits(amountToReceive, 18)).toFixed(2) : "0"}
                    </span>
                  </div>
                </div>

                <Button
                  className="w-full bg-transparent"
                  size="lg"
                  variant="outline"
                  onClick={handleWithdraw}
                  disabled={
                    !isConnected ||
                    !canWithdraw ||
                    !withdrawShares ||
                    Number(withdrawShares) <= 0 ||
                    withdrawSharesBigInt > userShares ||
                    isWithdrawing
                  }
                >
                  <Unlock className="w-4 h-4 mr-2" />
                  {isWithdrawing && <Loader2 className="w-4 h-4 mr-2 animate-spin" />}
                  {isWithdrawing ? "Withdrawing..." : canWithdraw ? "Withdraw Liquidity" : "Cooldown Active"}
                </Button>
              </TabsContent>
            </Tabs>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}

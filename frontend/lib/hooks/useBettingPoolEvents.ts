"use client"

import { useEffect, useState } from "react"
import { usePublicClient, useChainId } from "wagmi"
import { useContracts } from "./useContracts"
import type { Address } from "viem"

export type BetPlacedEvent = {
  betId: bigint
  bettor: Address
  roundId: bigint
  amount: bigint
  potentialPayout: bigint
  blockNumber: bigint
  transactionHash: string
  timestamp?: bigint
}

export type BetSettledEvent = {
  betId: bigint
  bettor: Address
  payout: bigint
  won: boolean
  blockNumber: bigint
  transactionHash: string
}

export type OddsUpdatedEvent = {
  roundId: bigint
  matchIndex: bigint
  outcome: number
  newOdds: bigint
  blockNumber: bigint
}

export function useBettingPoolEvents(userAddress?: Address) {
  const publicClient = usePublicClient()
  const chainId = useChainId()
  const { bettingPool } = useContracts()

  const [betPlacedEvents, setBetPlacedEvents] = useState<BetPlacedEvent[]>([])
  const [betSettledEvents, setBetSettledEvents] = useState<BetSettledEvent[]>([])
  const [oddsUpdatedEvents, setOddsUpdatedEvents] = useState<OddsUpdatedEvent[]>([])
  const [userBets, setUserBets] = useState<BetPlacedEvent[]>([])
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    if (!publicClient || !bettingPool?.address) return

    const fetchEvents = async () => {
      try {
        setIsLoading(true)

        const currentBlock = await publicClient.getBlockNumber()
        const fromBlock = currentBlock - 10000n

        // Fetch BetPlaced events
        const betPlacedLogs = await publicClient.getLogs({
          address: bettingPool.address,
          event: {
            type: "event",
            name: "BetPlaced",
            inputs: [
              { type: "uint256", indexed: true, name: "betId" },
              { type: "address", indexed: true, name: "bettor" },
              { type: "uint256", indexed: false, name: "roundId" },
              { type: "uint256", indexed: false, name: "amount" },
              { type: "uint256", indexed: false, name: "potentialPayout" },
            ],
          },
          fromBlock,
          toBlock: currentBlock,
        })

        const betsPlaced = betPlacedLogs.map((log) => ({
          betId: log.args.betId as bigint,
          bettor: log.args.bettor as Address,
          roundId: log.args.roundId as bigint,
          amount: log.args.amount as bigint,
          potentialPayout: log.args.potentialPayout as bigint,
          blockNumber: log.blockNumber,
          transactionHash: log.transactionHash,
        }))

        // Fetch BetSettled events
        const betSettledLogs = await publicClient.getLogs({
          address: bettingPool.address,
          event: {
            type: "event",
            name: "BetSettled",
            inputs: [
              { type: "uint256", indexed: true, name: "betId" },
              { type: "address", indexed: true, name: "bettor" },
              { type: "uint256", indexed: false, name: "payout" },
              { type: "bool", indexed: false, name: "won" },
            ],
          },
          fromBlock,
          toBlock: currentBlock,
        })

        const betsSettled = betSettledLogs.map((log) => ({
          betId: log.args.betId as bigint,
          bettor: log.args.bettor as Address,
          payout: log.args.payout as bigint,
          won: log.args.won as boolean,
          blockNumber: log.blockNumber,
          transactionHash: log.transactionHash,
        }))

        // Fetch OddsUpdated events
        const oddsUpdatedLogs = await publicClient.getLogs({
          address: bettingPool.address,
          event: {
            type: "event",
            name: "OddsUpdated",
            inputs: [
              { type: "uint256", indexed: true, name: "roundId" },
              { type: "uint256", indexed: true, name: "matchIndex" },
              { type: "uint8", indexed: false, name: "outcome" },
              { type: "uint256", indexed: false, name: "newOdds" },
            ],
          },
          fromBlock,
          toBlock: currentBlock,
        })

        const oddsUpdated = oddsUpdatedLogs.map((log) => ({
          roundId: log.args.roundId as bigint,
          matchIndex: log.args.matchIndex as bigint,
          outcome: log.args.outcome as number,
          newOdds: log.args.newOdds as bigint,
          blockNumber: log.blockNumber,
        }))

        setBetPlacedEvents(betsPlaced)
        setBetSettledEvents(betsSettled)
        setOddsUpdatedEvents(oddsUpdated)

        // Filter user bets if address provided
        if (userAddress) {
          const userSpecificBets = betsPlaced.filter(
            (bet) => bet.bettor.toLowerCase() === userAddress.toLowerCase()
          )
          setUserBets(userSpecificBets)
        }
      } catch (error) {
        console.error("Error fetching BettingPool events:", error)
      } finally {
        setIsLoading(false)
      }
    }

    fetchEvents()

    // Real-time event watchers
    const unwatchBetPlaced = publicClient.watchEvent({
      address: bettingPool.address,
      event: {
        type: "event",
        name: "BetPlaced",
        inputs: [
          { type: "uint256", indexed: true, name: "betId" },
          { type: "address", indexed: true, name: "bettor" },
          { type: "uint256", indexed: false, name: "roundId" },
          { type: "uint256", indexed: false, name: "amount" },
          { type: "uint256", indexed: false, name: "potentialPayout" },
        ],
      },
      onLogs: (logs) => {
        const newBets = logs.map((log) => ({
          betId: log.args.betId as bigint,
          bettor: log.args.bettor as Address,
          roundId: log.args.roundId as bigint,
          amount: log.args.amount as bigint,
          potentialPayout: log.args.potentialPayout as bigint,
          blockNumber: log.blockNumber,
          transactionHash: log.transactionHash,
        }))
        setBetPlacedEvents((prev) => [...prev, ...newBets])

        if (userAddress) {
          const userNewBets = newBets.filter(
            (bet) => bet.bettor.toLowerCase() === userAddress.toLowerCase()
          )
          if (userNewBets.length > 0) {
            setUserBets((prev) => [...prev, ...userNewBets])
          }
        }
      },
    })

    const unwatchBetSettled = publicClient.watchEvent({
      address: bettingPool.address,
      event: {
        type: "event",
        name: "BetSettled",
        inputs: [
          { type: "uint256", indexed: true, name: "betId" },
          { type: "address", indexed: true, name: "bettor" },
          { type: "uint256", indexed: false, name: "payout" },
          { type: "bool", indexed: false, name: "won" },
        ],
      },
      onLogs: (logs) => {
        const newSettlements = logs.map((log) => ({
          betId: log.args.betId as bigint,
          bettor: log.args.bettor as Address,
          payout: log.args.payout as bigint,
          won: log.args.won as boolean,
          blockNumber: log.blockNumber,
          transactionHash: log.transactionHash,
        }))
        setBetSettledEvents((prev) => [...prev, ...newSettlements])
      },
    })

    const unwatchOddsUpdated = publicClient.watchEvent({
      address: bettingPool.address,
      event: {
        type: "event",
        name: "OddsUpdated",
        inputs: [
          { type: "uint256", indexed: true, name: "roundId" },
          { type: "uint256", indexed: true, name: "matchIndex" },
          { type: "uint8", indexed: false, name: "outcome" },
          { type: "uint256", indexed: false, name: "newOdds" },
        ],
      },
      onLogs: (logs) => {
        const newOdds = logs.map((log) => ({
          roundId: log.args.roundId as bigint,
          matchIndex: log.args.matchIndex as bigint,
          outcome: log.args.outcome as number,
          newOdds: log.args.newOdds as bigint,
          blockNumber: log.blockNumber,
        }))
        setOddsUpdatedEvents((prev) => [...prev, ...newOdds])
      },
    })

    return () => {
      unwatchBetPlaced()
      unwatchBetSettled()
      unwatchOddsUpdated()
    }
  }, [publicClient, bettingPool?.address, chainId, userAddress])

  return {
    betPlacedEvents,
    betSettledEvents,
    oddsUpdatedEvents,
    userBets,
    isLoading,
  }
}

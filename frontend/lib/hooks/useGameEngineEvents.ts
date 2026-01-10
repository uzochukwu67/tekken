"use client"

import { useEffect, useState } from "react"
import { usePublicClient, useChainId } from "wagmi"
import { useContracts } from "./useContracts"
import type { Log } from "viem"

export type RoundCreatedEvent = {
  roundId: bigint
  startTime: bigint
  blockNumber: bigint
  transactionHash: string
}

export type RoundSettledEvent = {
  roundId: bigint
  blockNumber: bigint
  transactionHash: string
}

export type MatchResultEvent = {
  roundId: bigint
  matchIndex: bigint
  homeScore: number
  awayScore: number
  outcome: number // 0=HOME, 1=AWAY, 2=DRAW
  blockNumber: bigint
  transactionHash: string
}

export function useGameEngineEvents() {
  const publicClient = usePublicClient()
  const chainId = useChainId()
  const { gameEngine } = useContracts()

  const [roundCreatedEvents, setRoundCreatedEvents] = useState<RoundCreatedEvent[]>([])
  const [roundSettledEvents, setRoundSettledEvents] = useState<RoundSettledEvent[]>([])
  const [matchResultEvents, setMatchResultEvents] = useState<MatchResultEvent[]>([])
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    if (!publicClient || !gameEngine?.address) return

    const fetchEvents = async () => {
      try {
        setIsLoading(true)

        // Get current block
        const currentBlock = await publicClient.getBlockNumber()
        const fromBlock = currentBlock - 10000n // Last ~10k blocks

        // Fetch RoundCreated events
        const roundCreatedLogs = await publicClient.getLogs({
          address: gameEngine.address,
          event: {
            type: "event",
            name: "RoundCreated",
            inputs: [
              { type: "uint256", indexed: true, name: "roundId" },
              { type: "uint256", indexed: false, name: "startTime" },
            ],
          },
          fromBlock,
          toBlock: currentBlock,
        })

        const roundCreated = roundCreatedLogs.map((log) => ({
          roundId: log.args.roundId as bigint,
          startTime: log.args.startTime as bigint,
          blockNumber: log.blockNumber,
          transactionHash: log.transactionHash,
        }))

        // Fetch RoundSettled events
        const roundSettledLogs = await publicClient.getLogs({
          address: gameEngine.address,
          event: {
            type: "event",
            name: "RoundSettled",
            inputs: [{ type: "uint256", indexed: true, name: "roundId" }],
          },
          fromBlock,
          toBlock: currentBlock,
        })

        const roundSettled = roundSettledLogs.map((log) => ({
          roundId: log.args.roundId as bigint,
          blockNumber: log.blockNumber,
          transactionHash: log.transactionHash,
        }))

        // Fetch MatchResult events
        const matchResultLogs = await publicClient.getLogs({
          address: gameEngine.address,
          event: {
            type: "event",
            name: "MatchResult",
            inputs: [
              { type: "uint256", indexed: true, name: "roundId" },
              { type: "uint256", indexed: true, name: "matchIndex" },
              { type: "uint8", indexed: false, name: "homeScore" },
              { type: "uint8", indexed: false, name: "awayScore" },
              { type: "uint8", indexed: false, name: "outcome" },
            ],
          },
          fromBlock,
          toBlock: currentBlock,
        })

        const matchResults = matchResultLogs.map((log) => ({
          roundId: log.args.roundId as bigint,
          matchIndex: log.args.matchIndex as bigint,
          homeScore: log.args.homeScore as number,
          awayScore: log.args.awayScore as number,
          outcome: log.args.outcome as number,
          blockNumber: log.blockNumber,
          transactionHash: log.transactionHash,
        }))

        setRoundCreatedEvents(roundCreated)
        setRoundSettledEvents(roundSettled)
        setMatchResultEvents(matchResults)
      } catch (error) {
        console.error("Error fetching GameEngine events:", error)
      } finally {
        setIsLoading(false)
      }
    }

    fetchEvents()

    // Set up event watchers for real-time updates
    const unwatchRoundCreated = publicClient.watchEvent({
      address: gameEngine.address,
      event: {
        type: "event",
        name: "RoundCreated",
        inputs: [
          { type: "uint256", indexed: true, name: "roundId" },
          { type: "uint256", indexed: false, name: "startTime" },
        ],
      },
      onLogs: (logs) => {
        const newEvents = logs.map((log) => ({
          roundId: log.args.roundId as bigint,
          startTime: log.args.startTime as bigint,
          blockNumber: log.blockNumber,
          transactionHash: log.transactionHash,
        }))
        setRoundCreatedEvents((prev) => [...prev, ...newEvents])
      },
    })

    const unwatchRoundSettled = publicClient.watchEvent({
      address: gameEngine.address,
      event: {
        type: "event",
        name: "RoundSettled",
        inputs: [{ type: "uint256", indexed: true, name: "roundId" }],
      },
      onLogs: (logs) => {
        const newEvents = logs.map((log) => ({
          roundId: log.args.roundId as bigint,
          blockNumber: log.blockNumber,
          transactionHash: log.transactionHash,
        }))
        setRoundSettledEvents((prev) => [...prev, ...newEvents])
      },
    })

    const unwatchMatchResult = publicClient.watchEvent({
      address: gameEngine.address,
      event: {
        type: "event",
        name: "MatchResult",
        inputs: [
          { type: "uint256", indexed: true, name: "roundId" },
          { type: "uint256", indexed: true, name: "matchIndex" },
          { type: "uint8", indexed: false, name: "homeScore" },
          { type: "uint8", indexed: false, name: "awayScore" },
          { type: "uint8", indexed: false, name: "outcome" },
        ],
      },
      onLogs: (logs) => {
        const newEvents = logs.map((log) => ({
          roundId: log.args.roundId as bigint,
          matchIndex: log.args.matchIndex as bigint,
          homeScore: log.args.homeScore as number,
          awayScore: log.args.awayScore as number,
          outcome: log.args.outcome as number,
          blockNumber: log.blockNumber,
          transactionHash: log.transactionHash,
        }))
        setMatchResultEvents((prev) => [...prev, ...newEvents])
      },
    })

    return () => {
      unwatchRoundCreated()
      unwatchRoundSettled()
      unwatchMatchResult()
    }
  }, [publicClient, gameEngine?.address, chainId])

  return {
    roundCreatedEvents,
    roundSettledEvents,
    matchResultEvents,
    isLoading,
  }
}

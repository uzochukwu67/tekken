"use client"

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import { Loader2 } from "lucide-react"
import { useSeasonStandings, useCurrentSeason, useAllTeams } from "@/lib/hooks/useGameData"

export function StandingsNew() {
  const { currentSeasonId } = useCurrentSeason()
  const { teams, isLoading: teamsLoading } = useAllTeams()
  const { standings, isLoading: standingsLoading } = useSeasonStandings(currentSeasonId)

  const isLoading = teamsLoading || standingsLoading

  // Create a map of team IDs to names
  const teamMap = new Map(teams?.map((team) => [Number(team.id), team.name]) || [])

  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-2xl font-bold mb-2">
          Season {currentSeasonId?.toString() || "..."} Standings
        </h3>
        <p className="text-sm text-muted-foreground">Current league table</p>
      </div>

      <Card className="bg-card/50 backdrop-blur border-border/40">
        <CardHeader>
          <CardTitle>League Table</CardTitle>
          <CardDescription>Top 20 teams this season</CardDescription>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="flex items-center justify-center py-12">
              <Loader2 className="w-8 h-8 animate-spin text-muted-foreground" />
            </div>
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="w-12">#</TableHead>
                    <TableHead>Team</TableHead>
                    <TableHead className="text-center">P</TableHead>
                    <TableHead className="text-center">W</TableHead>
                    <TableHead className="text-center">D</TableHead>
                    <TableHead className="text-center">L</TableHead>
                    <TableHead className="text-center">GF</TableHead>
                    <TableHead className="text-center">GA</TableHead>
                    <TableHead className="text-center">GD</TableHead>
                    <TableHead className="text-center font-bold">Pts</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {standings?.map((standing, index) => {
                    const teamName = teamMap.get(Number(standing.teamId)) || `Team ${standing.teamId}`
                    const position = index + 1

                    return (
                      <TableRow key={standing.teamId.toString()}>
                        <TableCell className="font-medium">
                          <Badge variant={position <= 3 ? "default" : "outline"}>{position}</Badge>
                        </TableCell>
                        <TableCell className="font-medium">{teamName}</TableCell>
                        <TableCell className="text-center">{standing.played}</TableCell>
                        <TableCell className="text-center">{standing.wins}</TableCell>
                        <TableCell className="text-center">{standing.draws}</TableCell>
                        <TableCell className="text-center">{standing.losses}</TableCell>
                        <TableCell className="text-center">{standing.goalsFor}</TableCell>
                        <TableCell className="text-center">{standing.goalsAgainst}</TableCell>
                        <TableCell className="text-center">
                          {standing.goalDifference > 0
                            ? `+${standing.goalDifference}`
                            : standing.goalDifference}
                        </TableCell>
                        <TableCell className="text-center font-bold">{standing.points}</TableCell>
                      </TableRow>
                    )
                  })}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}

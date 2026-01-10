"use client"

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"

const TEAMS = [
  { pos: 1, name: "Manchester City", played: 20, wins: 15, draws: 3, losses: 2, gf: 48, ga: 18, gd: 30, points: 48 },
  { pos: 2, name: "Arsenal", played: 20, wins: 14, draws: 4, losses: 2, gf: 45, ga: 20, gd: 25, points: 46 },
  { pos: 3, name: "Liverpool", played: 20, wins: 13, draws: 5, losses: 2, gf: 42, ga: 19, gd: 23, points: 44 },
  { pos: 4, name: "Barcelona", played: 20, wins: 12, draws: 5, losses: 3, gf: 40, ga: 22, gd: 18, points: 41 },
  { pos: 5, name: "Bayern Munich", played: 20, wins: 12, draws: 4, losses: 4, gf: 43, ga: 24, gd: 19, points: 40 },
  { pos: 6, name: "Real Madrid", played: 20, wins: 11, draws: 6, losses: 3, gf: 38, ga: 21, gd: 17, points: 39 },
  { pos: 7, name: "PSG", played: 20, wins: 11, draws: 5, losses: 4, gf: 39, ga: 23, gd: 16, points: 38 },
  { pos: 8, name: "Chelsea", played: 20, wins: 10, draws: 6, losses: 4, gf: 35, ga: 25, gd: 10, points: 36 },
  { pos: 9, name: "Juventus", played: 20, wins: 10, draws: 5, losses: 5, gf: 32, ga: 24, gd: 8, points: 35 },
  { pos: 10, name: "Inter Milan", played: 20, wins: 9, draws: 7, losses: 4, gf: 34, ga: 26, gd: 8, points: 34 },
]

export function Standings() {
  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-2xl font-bold mb-2">Season 1 Standings</h3>
        <p className="text-sm text-muted-foreground">Current league table after 20 rounds</p>
      </div>

      <Card className="bg-card/50 backdrop-blur border-border/40">
        <CardHeader>
          <CardTitle>League Table</CardTitle>
          <CardDescription>Top 10 teams this season</CardDescription>
        </CardHeader>
        <CardContent>
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
                {TEAMS.map((team) => (
                  <TableRow key={team.pos}>
                    <TableCell className="font-medium">
                      <Badge variant={team.pos <= 3 ? "default" : "outline"}>{team.pos}</Badge>
                    </TableCell>
                    <TableCell className="font-medium">{team.name}</TableCell>
                    <TableCell className="text-center">{team.played}</TableCell>
                    <TableCell className="text-center">{team.wins}</TableCell>
                    <TableCell className="text-center">{team.draws}</TableCell>
                    <TableCell className="text-center">{team.losses}</TableCell>
                    <TableCell className="text-center">{team.gf}</TableCell>
                    <TableCell className="text-center">{team.ga}</TableCell>
                    <TableCell className="text-center">{team.gd > 0 ? `+${team.gd}` : team.gd}</TableCell>
                    <TableCell className="text-center font-bold">{team.points}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

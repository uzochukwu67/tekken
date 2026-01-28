// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IGameEngine {
    enum MatchOutcome {
        PENDING,
        HOME_WIN,
        AWAY_WIN,
        DRAW
    }

    struct Match {
        uint256 homeTeamId;
        uint256 awayTeamId;
        uint8 homeScore;
        uint8 awayScore;
        MatchOutcome outcome;
        bool settled;
        // Odds removed - managed by BettingPool
    }

    struct Team {
        string name;
        uint256 wins;
        uint256 draws;
        uint256 losses;
        uint256 points;
        uint256 goalsFor;
        uint256 goalsAgainst;
    }

    struct Season {
        uint256 seasonId;
        uint256 startTime;
        uint256 currentRound;
        bool active;
        bool completed;
        uint256 winningTeamId;
    }

    function getCurrentRound() external view returns (uint256);
    function getCurrentSeason() external view returns (uint256);
    function getMatch(uint256 roundId, uint256 matchIndex) external view returns (Match memory);
    function getRoundMatches(uint256 roundId) external view returns (Match[] memory);
    function isRoundSettled(uint256 roundId) external view returns (bool);
    function getTeamStanding(uint256 seasonId, uint256 teamId) external view returns (Team memory);
    function getSeason(uint256 seasonId) external view returns (Season memory);
}

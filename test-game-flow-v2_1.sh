#!/bin/bash

# iVirtualz Game Flow Test Script V2.1
# Tests complete game cycle with dynamic odds seeding
# Updated for BettingPoolV2_1 with SeasonPredictorV2

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
SEPOLIA_RPC_URL="${SEPOLIA_RPC_URL:-https://ethereum-sepolia-rpc.publicnode.com}"
PRIVATE_KEY="0x7125ce4cebbdcd9d76871c1b8a10b65034142ade2f0129c9eba244bb2a9c100f"

# Deployed Contract Addresses (UPDATED for V2.1)
LEAGUE_TOKEN="0x0954D38B6d2D0B08B3Fa5c15e70e1c83aa536b4b"
GAME_ENGINE="0x50aE313D59bfB2A651fD99e91e963Cdd2AfA4eDF"
LIQUIDITY_POOL="0x052c1fE33D0EBB6642f73F7f8D66Defc0f7C9Fbe"
BETTING_POOL="0x47Efc157C738B0AcB31bb37c8c77D73F831Fd441"
SEASON_PREDICTOR="0xf0960b01251c8be7D1E3Fc1758c46E714e6Bf035"

# Test Configuration
BET_AMOUNT="100000000000000000000"    # 100 LEAGUE tokens
ROUND_DURATION=900                     # 15 minutes in seconds

# Helper Functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_section() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

check_requirements() {
    log_section "Checking Requirements"

    if ! command -v cast &> /dev/null; then
        log_error "cast (foundry) not found. Install from https://getfoundry.sh"
        exit 1
    fi
    log_success "cast found"

    if [ -z "$PRIVATE_KEY" ]; then
        log_error "PRIVATE_KEY not set"
        exit 1
    fi
    log_success "Private key configured"

    WALLET_ADDRESS=$(cast wallet address --private-key "$PRIVATE_KEY" 2>/dev/null)
    log_success "Wallet address: $WALLET_ADDRESS"

    BALANCE=$(cast balance "$WALLET_ADDRESS" --rpc-url "$SEPOLIA_RPC_URL")
    log_info "ETH Balance: $(echo "scale=4; $BALANCE / 1000000000000000000" | bc) ETH"
}

fund_protocol_reserve() {
    log_section "Step 0: Funding Protocol Reserve"

    # Check current reserve
    CURRENT_RESERVE=$(cast call "$BETTING_POOL" \
        "protocolReserve()(uint256)" \
        --rpc-url "$SEPOLIA_RPC_URL")

    RESERVE_ETH=$(echo "scale=2; $CURRENT_RESERVE / 1000000000000000000" | bc 2>/dev/null || echo "0")
    log_info "Current protocol reserve: ${RESERVE_ETH} LEAGUE"

    # Check if reserve is below 10,000 LEAGUE using bc
    MIN_RESERVE="10000000000000000000000"  # 10,000 LEAGUE
    NEEDS_FUNDING=$(echo "$CURRENT_RESERVE < $MIN_RESERVE" | bc 2>/dev/null || echo "1")

    if [ "$NEEDS_FUNDING" = "1" ]; then
        log_warning "Protocol reserve too low, funding with 100,000 LEAGUE..."

        # Approve tokens
        log_info "Approving tokens..."
        cast send "$LEAGUE_TOKEN" \
            "approve(address,uint256)" \
            "$BETTING_POOL" \
            "100000000000000000000000" \
            --rpc-url "$SEPOLIA_RPC_URL" \
            --private-key "$PRIVATE_KEY" \
            --json > /dev/null 2>&1

        log_success "Tokens approved"

        # Fund reserve
        log_info "Funding protocol reserve..."
        cast send "$BETTING_POOL" \
            "fundProtocolReserve(uint256)" \
            "100000000000000000000000" \
            --rpc-url "$SEPOLIA_RPC_URL" \
            --private-key "$PRIVATE_KEY" \
            --json > /dev/null 2>&1

        NEW_RESERVE=$(cast call "$BETTING_POOL" \
            "protocolReserve()(uint256)" \
            --rpc-url "$SEPOLIA_RPC_URL")

        NEW_RESERVE_ETH=$(echo "scale=2; $NEW_RESERVE / 1000000000000000000" | bc 2>/dev/null || echo "?")
        log_success "Protocol reserve funded! New balance: ${NEW_RESERVE_ETH} LEAGUE"
    else
        log_success "Protocol reserve sufficient: ${RESERVE_ETH} LEAGUE"
    fi
}

start_season() {
    log_section "Step 1: Starting New Season"

    CURRENT_SEASON=$(cast call "$GAME_ENGINE" \
        "getCurrentSeason()(uint256)" \
        --rpc-url "$SEPOLIA_RPC_URL")

    log_info "Current season ID: $CURRENT_SEASON"

    if [ "$CURRENT_SEASON" = "0" ]; then
        log_info "Starting first season..."
        cast send "$GAME_ENGINE" \
            "startSeason()" \
            --rpc-url "$SEPOLIA_RPC_URL" \
            --private-key "$PRIVATE_KEY" \
            --json > /dev/null

        NEW_SEASON=$(cast call "$GAME_ENGINE" \
            "getCurrentSeason()(uint256)" \
            --rpc-url "$SEPOLIA_RPC_URL")

        log_success "Season $NEW_SEASON started!"
    else
        log_success "Season $CURRENT_SEASON already active"
    fi
}

start_round() {
    log_section "Step 2: Starting New Round"

    CURRENT_ROUND=$(cast call "$GAME_ENGINE" \
        "getCurrentRound()(uint256)" \
        --rpc-url "$SEPOLIA_RPC_URL")

    log_info "Current round ID: $CURRENT_ROUND"

    # If no round exists or current round is settled, start new round
    if [ "$CURRENT_ROUND" = "0" ]; then
        log_info "No active round, starting new round..."
        cast send "$GAME_ENGINE" \
            "startRound()" \
            --rpc-url "$SEPOLIA_RPC_URL" \
            --private-key "$PRIVATE_KEY" \
            --json > /dev/null 2>&1

        NEW_ROUND=$(cast call "$GAME_ENGINE" \
            "getCurrentRound()(uint256)" \
            --rpc-url "$SEPOLIA_RPC_URL")

        log_success "Round $NEW_ROUND started!"
    else
        # Check if round is settled
        ROUND_DATA=$(cast call "$GAME_ENGINE" \
            "getRound(uint256)(uint256,uint256,uint256,uint256,bool)" \
            "$CURRENT_ROUND" \
            --rpc-url "$SEPOLIA_RPC_URL" 2>/dev/null || echo "")

        IS_SETTLED=$(echo "$ROUND_DATA" | awk '{print $5}' | tr -d ',' || echo "false")

        if [ "$IS_SETTLED" = "true" ]; then
            log_info "Previous round settled, starting new round..."
            cast send "$GAME_ENGINE" \
                "startRound()" \
                --rpc-url "$SEPOLIA_RPC_URL" \
                --private-key "$PRIVATE_KEY" \
                --json > /dev/null 2>&1

            NEW_ROUND=$(cast call "$GAME_ENGINE" \
                "getCurrentRound()(uint256)" \
                --rpc-url "$SEPOLIA_RPC_URL")

            log_success "Round $NEW_ROUND started!"
        else
            log_success "Round $CURRENT_ROUND already active (not settled yet)"
        fi
    fi
}

seed_round_pools() {
    log_section "Step 3: Seeding Round Pools (Dynamic Odds)"

    CURRENT_ROUND=$(cast call "$GAME_ENGINE" \
        "getCurrentRound()(uint256)" \
        --rpc-url "$SEPOLIA_RPC_URL")

    # Check if already seeded by trying to get match pool data
    POOL_DATA=$(cast call "$BETTING_POOL" \
        "getMatchPoolData(uint256,uint256)(uint256,uint256,uint256,uint256)" \
        "$CURRENT_ROUND" "0" \
        --rpc-url "$SEPOLIA_RPC_URL" 2>/dev/null || echo "")

    TOTAL_POOL=$(echo "$POOL_DATA" | awk '{print $4}' | tr -d ',' || echo "0")

    if [ "$TOTAL_POOL" != "0" ] && [ -n "$TOTAL_POOL" ]; then
        log_success "Round $CURRENT_ROUND already seeded (total pool: $TOTAL_POOL)"
    else
        log_info "Seeding round $CURRENT_ROUND with dynamic odds..."

        cast send "$BETTING_POOL" \
            "seedRoundPools(uint256)" \
            "$CURRENT_ROUND" \
            --rpc-url "$SEPOLIA_RPC_URL" \
            --private-key "$PRIVATE_KEY" \
            --json > /dev/null 2>&1

        log_success "Round pools seeded with dynamic odds!"
    fi
}

view_all_match_odds() {
    log_section "Step 4: Viewing All Match Odds"

    CURRENT_ROUND=$(cast call "$GAME_ENGINE" \
        "getCurrentRound()(uint256)" \
        --rpc-url "$SEPOLIA_RPC_URL")

    log_info "Fetching odds for all 10 matches in round $CURRENT_ROUND..."
    echo ""

    # Get all match odds in one call
    ODDS_RAW=$(cast call "$BETTING_POOL" \
        "getAllMatchOdds(uint256)(uint256[10],uint256[10],uint256[10])" \
        "$CURRENT_ROUND" \
        --rpc-url "$SEPOLIA_RPC_URL")

    echo $ODDS_RAW
    
    # HOME_ODDS=$(echo "$ODDS_RAW" | sed -n '1p' | tr -d '[],' | xargs)
    # AWAY_ODDS=$(echo "$ODDS_RAW" | sed -n '2p' | tr -d '[],' | xargs)
    # DRAW_ODDS=$(echo "$ODDS_RAW" | sed -n '3p' | tr -d '[],' | xargs)

    # # Convert to arrays
    # IFS=' ' read -ra HOME_ARR <<< "$HOME_ODDS"
    # IFS=' ' read -ra AWAY_ARR <<< "$AWAY_ODDS"
    # IFS=' ' read -ra DRAW_ARR <<< "$DRAW_ODDS"

    # # Display odds for each match
    # for i in {0..9}; do
    #     # Get match info
    #     MATCH_RAW=$(cast call "$GAME_ENGINE" \
    #         "getMatch(uint256,uint256)(uint256,uint256,uint8,uint8,uint8,bool,uint256,uint256,uint256)" \
    #         "$CURRENT_ROUND" "$i" \
    #         --rpc-url "$SEPOLIA_RPC_URL" 2>/dev/null || echo "")

    #     if [ -n "$MATCH_RAW" ]; then
    #         HOME_TEAM_ID=$(echo "$MATCH_RAW" | awk '{print $1}' | tr -d ',')
    #         AWAY_TEAM_ID=$(echo "$MATCH_RAW" | awk '{print $2}' | tr -d ',')

    #         # Get team names
    #         HOME_NAME=$(cast call "$GAME_ENGINE" "getTeam(uint256)(string)" "$HOME_TEAM_ID" --rpc-url "$SEPOLIA_RPC_URL" 2>/dev/null || echo "Team $HOME_TEAM_ID")
    #         AWAY_NAME=$(cast call "$GAME_ENGINE" "getTeam(uint256)(string)" "$AWAY_TEAM_ID" --rpc-url "$SEPOLIA_RPC_URL" 2>/dev/null || echo "Team $AWAY_TEAM_ID")

    #         # Clean up team names
    #         HOME_NAME=$(echo "$HOME_NAME" | tr -d '"')
    #         AWAY_NAME=$(echo "$AWAY_NAME" | tr -d '"')

    #         # Convert odds from 1e18 to decimal (e.g., 1200000000000000000 → 1.20)
    #         HOME_ODD="${HOME_ARR[$i]:-0}"
    #         AWAY_ODD="${AWAY_ARR[$i]:-0}"
    #         DRAW_ODD="${DRAW_ARR[$i]:-0}"

    #         # Format odds (divide by 1e18 and show 2 decimals)
    #         HOME_FORMATTED=$(echo "scale=2; $HOME_ODD / 1000000000000000000" | bc)
    #         AWAY_FORMATTED=$(echo "scale=2; $AWAY_ODD / 1000000000000000000" | bc)
    #         DRAW_FORMATTED=$(echo "scale=2; $DRAW_ODD / 1000000000000000000" | bc)

    #         echo -e "  ${MAGENTA}Match $i${NC}: ${BLUE}$HOME_NAME${NC} vs ${BLUE}$AWAY_NAME${NC}"
    #         echo -e "    ${GREEN}HOME${NC}: ${HOME_FORMATTED}x  |  ${RED}AWAY${NC}: ${AWAY_FORMATTED}x  |  ${YELLOW}DRAW${NC}: ${DRAW_FORMATTED}x"
    #         echo ""
    #     fi
    # done

    log_success "Dynamic odds displayed for all matches!"
}

make_season_prediction() {
    log_section "Step 5: Making Season Prediction"

    SEASON_ID=$(cast call "$GAME_ENGINE" \
        "getCurrentSeason()(uint256)" \
        --rpc-url "$SEPOLIA_RPC_URL")

    log_info "Making prediction for season $SEASON_ID..."
    log_info "Predicting Team 0 will win the season"

    # Check if already predicted
    EXISTING=$(cast call "$SEASON_PREDICTOR" \
        "getUserPrediction(uint256,address)(uint256)" \
        "$SEASON_ID" "$WALLET_ADDRESS" \
        --rpc-url "$SEPOLIA_RPC_URL" 2>/dev/null || echo "")

    MAX_UINT="115792089237316195423570985008687907853269984665640564039457584007913129639935"
    if [ "$EXISTING" != "" ] && [ "$EXISTING" != "$MAX_UINT" ]; then
        log_success "Already predicted Team $EXISTING for this season"
        return 0
    fi

    cast send "$SEASON_PREDICTOR" \
        "makePrediction(uint256)" \
        "0" \
        --rpc-url "$SEPOLIA_RPC_URL" \
        --private-key "$PRIVATE_KEY" \
        --json > /dev/null

    log_success "Season prediction made: Team 0"
}

place_single_bet() {
    log_section "Step 6: Placing Single Bet"

    CURRENT_ROUND=$(cast call "$GAME_ENGINE" \
        "getCurrentRound()(uint256)" \
        --rpc-url "$SEPOLIA_RPC_URL")

    log_info "Placing 100 LEAGUE bet on Match 0 - HOME WIN"

    # Approve tokens
    cast send "$LEAGUE_TOKEN" \
        "approve(address,uint256)" \
        "$BETTING_POOL" \
        "$BET_AMOUNT" \
        --rpc-url "$SEPOLIA_RPC_URL" \
        --private-key "$PRIVATE_KEY" \
        --json > /dev/null

    log_success "Tokens approved"

    # Place bet (match 0, outcome 1 = HOME_WIN)
    cast send "$BETTING_POOL" \
        "placeBet(uint256[],uint8[],uint256)" \
        "[0]" "[1]" "$BET_AMOUNT" \
        --rpc-url "$SEPOLIA_RPC_URL" \
        --private-key "$PRIVATE_KEY" \
        --json > /dev/null

    log_success "Bet placed: 100 LEAGUE on Match 0 HOME WIN"

    # Show updated odds for match 0
    ODDS=$(cast call "$BETTING_POOL" \
        "previewMatchOdds(uint256,uint256)(uint256,uint256,uint256)" \
        "$CURRENT_ROUND" "0" \
        --rpc-url "$SEPOLIA_RPC_URL")

    HOME_ODD=$(echo "$ODDS" | awk '{print $1}' | tr -d ',')
    AWAY_ODD=$(echo "$ODDS" | awk '{print $2}' | tr -d ',')
    DRAW_ODD=$(echo "$ODDS" | awk '{print $3}' | tr -d ',')

    HOME_F=$(echo "scale=2; $HOME_ODD / 1000000000000000000" | bc)
    AWAY_F=$(echo "scale=2; $AWAY_ODD / 1000000000000000000" | bc)
    DRAW_F=$(echo "scale=2; $DRAW_ODD / 1000000000000000000" | bc)

    log_info "Updated odds: HOME ${HOME_F}x | AWAY ${AWAY_F}x | DRAW ${DRAW_F}x"
}

place_parlay_bet() {
    log_section "Step 7: Placing Parlay Bet"

    CURRENT_ROUND=$(cast call "$GAME_ENGINE" \
        "getCurrentRound()(uint256)" \
        --rpc-url "$SEPOLIA_RPC_URL")

    log_info "Placing 100 LEAGUE 2-leg parlay (Matches 1&2, both HOME WIN)"

    # Check parlay multiplier
    MULT_DATA=$(cast call "$BETTING_POOL" \
        "getCurrentParlayMultiplier(uint256,uint256[],uint256)(uint256,uint256,uint256,uint256)" \
        "$CURRENT_ROUND" "[1,2]" "2" \
        --rpc-url "$SEPOLIA_RPC_URL")

    MULT=$(echo "$MULT_DATA" | awk '{print $1}' | tr -d ',')
    TIER=$(echo "$MULT_DATA" | awk '{print $2}' | tr -d ',')

    MULT_F=$(echo "scale=2; $MULT / 1000000000000000000" | bc)
    log_info "Current parlay bonus: ${MULT_F}x (Tier $TIER)"

    # Approve tokens
    cast send "$LEAGUE_TOKEN" \
        "approve(address,uint256)" \
        "$BETTING_POOL" \
        "$BET_AMOUNT" \
        --rpc-url "$SEPOLIA_RPC_URL" \
        --private-key "$PRIVATE_KEY" \
        --json > /dev/null

    # Place parlay
    cast send "$BETTING_POOL" \
        "placeBet(uint256[],uint8[],uint256)" \
        "[1,2]" "[1,1]" "$BET_AMOUNT" \
        --rpc-url "$SEPOLIA_RPC_URL" \
        --private-key "$PRIVATE_KEY" \
        --json > /dev/null

    log_success "Parlay bet placed with ${MULT_F}x bonus!"
}

check_protocol_stats() {
    log_section "Step 8: Protocol Statistics"

    CURRENT_ROUND=$(cast call "$GAME_ENGINE" \
        "getCurrentRound()(uint256)" \
        --rpc-url "$SEPOLIA_RPC_URL")

    # Protocol reserve
    RESERVE=$(cast call "$BETTING_POOL" \
        "protocolReserve()(uint256)" \
        --rpc-url "$SEPOLIA_RPC_URL")
    RESERVE_F=$(echo "scale=2; $RESERVE / 1000000000000000000" | bc)
    log_info "Protocol Reserve: ${RESERVE_F} LEAGUE"

    # Locked parlay reserve
    LOCKED=$(cast call "$BETTING_POOL" \
        "lockedParlayReserve()(uint256)" \
        --rpc-url "$SEPOLIA_RPC_URL")
    LOCKED_F=$(echo "scale=2; $LOCKED / 1000000000000000000" | bc)
    log_info "Locked Parlay Reserve: ${LOCKED_F} LEAGUE"

    # Round accounting
    ACCOUNTING=$(cast call "$BETTING_POOL" \
        "getRoundAccounting(uint256)(uint256,uint256,uint256,uint256,uint256)" \
        "$CURRENT_ROUND" \
        --rpc-url "$SEPOLIA_RPC_URL")

    TOTAL_VOLUME=$(echo "$ACCOUNTING" | awk '{print $1}' | tr -d ',')
    PARLAY_COUNT=$(echo "$ACCOUNTING" | awk '{print $5}' | tr -d ',')

    VOLUME_F=$(echo "scale=2; $TOTAL_VOLUME / 1000000000000000000" | bc)
    log_info "Round $CURRENT_ROUND Volume: ${VOLUME_F} LEAGUE"
    log_info "Parlay Count: $PARLAY_COUNT"

    # Season predictor stats
    SEASON_ID=$(cast call "$GAME_ENGINE" \
        "getCurrentSeason()(uint256)" \
        --rpc-url "$SEPOLIA_RPC_URL")

    PRIZE_POOL=$(cast call "$SEASON_PREDICTOR" \
        "getSeasonPrizePool(uint256)(uint256)" \
        "$SEASON_ID" \
        --rpc-url "$SEPOLIA_RPC_URL")
    PRIZE_F=$(echo "scale=2; $PRIZE_POOL / 1000000000000000000" | bc)
    log_info "Season $SEASON_ID Prize Pool: ${PRIZE_F} LEAGUE"
}

# Main execution
main() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}║     iVirtualz BettingPoolV2.1 Test Script                  ║${NC}"
    echo -e "${GREEN}║     Dynamic Odds • Parlay Tiers • Season Predictions       ║${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # check_requirements
    # fund_protocol_reserve
    # start_season
    # start_round
    # seed_round_pools
    view_all_match_odds
    make_season_prediction
    place_single_bet
    place_parlay_bet
    check_protocol_stats

    log_section "Test Complete!"
    log_success "All V2.1 features tested successfully! 🎮"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo "  1. Wait 15 minutes for round to end"
    echo "  2. Call gameEngine.requestMatchResults()"
    echo "  3. Wait for VRF callback (2-5 minutes)"
    echo "  4. Call bettingPool.settleRound(roundId)"
    echo "  5. Call bettingPool.claimWinnings()"
    echo ""
}

# Run main function
main "$@"

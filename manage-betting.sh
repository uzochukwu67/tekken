#!/bin/bash

# Betting System Management Script
# Handles: Start Season, Start Round, Place Bet, Check Round Status

set -e

# ============ Configuration ============

# Load environment variables
source .env 2>/dev/null || true

# Deployed Contract Addresses (Updated: 2026-02-12 - Full System Redeployment)
LBT_TOKEN="0x1d08F7A669E18B3B3AEce77a8C20E1Ef7536CEE6"
GAME_CORE="0xEB929B5c0e71a6b785CE89f8A0fd218D92c8fB66"
BETTING_CORE="0xf99a4F28E9D1cDC481a4b742bc637Af9e60e3FE5"
SEASON_PREDICTOR="0x45da13240cEce4ca92BEF34B6955c7883e5Ce9E4"
BETTING_ROUTER="0x02d49e1e3EE1Db09a7a8643Ae1BCc72169180861"
SWAP_ROUTER="0xD8d4485095f3203Df449D51768a78FfD79e4Ff8E"
TOKEN_REGISTRY="0xF152CF478FA4B4220378692D2E85067269525d89"

# RPC URL (default to Sepolia)
RPC_URL="${BNBT_RPC_URL:-https://bsc-testnet.drpc.org}"

# Private key (required for transactions)
PRIVATE_KEY="${PRIVATE_KEY}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============ Helper Functions ============

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

check_requirements() {
    if ! command -v cast &> /dev/null; then
        print_error "Foundry's 'cast' not found. Please install Foundry."
        exit 1
    fi

    if [ -z "$PRIVATE_KEY" ]; then
        print_error "PRIVATE_KEY not set in .env file"
        exit 1
    fi
}

# ============ Season Management ============

initialize_season() {
    print_header "Starting New Season"

    # Check if season already active
    current_season=$(cast call $GAME_CORE "getCurrentSeason()(uint256)" --rpc-url $RPC_URL 2>/dev/null || echo "0")

    if [ "$current_season" != "0" ]; then
        print_info "Season $current_season already active"
        echo "Current Season ID: $current_season"
        return
    fi

    print_info "Calling GameCore.startSeason()..."

    tx_hash=$(cast send $GAME_CORE "startSeason()" \
        --private-key $PRIVATE_KEY \
        --rpc-url $RPC_URL \
        --json | grep -o '"transactionHash":"[^"]*' | cut -d'"' -f4)

    print_success "Season started! Tx: $tx_hash"

    # Get new season ID
    sleep 3
    current_season=$(cast call $GAME_CORE "getCurrentSeason()(uint256)" --rpc-url $RPC_URL)
    echo -e "New Season ID: ${GREEN}$current_season${NC}"
}

get_season_info() {
    print_header "Current Season Information"

    current_season=$(cast call $GAME_CORE "getCurrentSeason()(uint256)" --rpc-url $RPC_URL)
    current_round=$(cast call $GAME_CORE "getCurrentRound()(uint256)" --rpc-url $RPC_URL)

    echo "Season ID: $current_season"
    echo "Current Round: $current_round"
}

# ============ Round Management ============

start_round() {
    print_header "Starting New Round"

    # Get current round before starting
    current_round=$(cast call $GAME_CORE "getCurrentRound()(uint256)" --rpc-url $RPC_URL)
    print_info "Current round: $current_round"

    print_info "Calling GameCore.startRound() - This will:"
    echo "  1. Request VRF randomness for match strengths"
    echo "  2. Seed BettingCore with round data"
    echo "  3. Lock initial odds"
    echo "  4. Open betting"

    tx_hash=$(cast send $GAME_CORE "startRound()" \
        --private-key $PRIVATE_KEY \
        --rpc-url $RPC_URL \
        --json | grep -o '"transactionHash":"[^"]*' | cut -d'"' -f4)

    print_success "Round start initiated! Tx: $tx_hash"

    # Wait for confirmation
    sleep 5

    # Get new round
    new_round=$(cast call $GAME_CORE "getCurrentRound()(uint256)" --rpc-url $RPC_URL)
    echo -e "New Round ID: ${GREEN}$new_round${NC}"

    print_info "Note: VRF fulfillment may take 1-2 minutes"
}

seed_round() {
    local round_id=$1

    if [ -z "$round_id" ]; then
        # Get current round if not specified
        round_id=$(cast call $BETTING_CORE "getCurrentRound()(uint256)" --rpc-url $RPC_URL)
    fi

    print_header "Manually Seeding Round $round_id"

    print_info "This will seed the round with random odds and open betting"

    tx_hash=$(cast send $BETTING_CORE "seedRound(uint256)" $round_id \
        --private-key $PRIVATE_KEY \
        --rpc-url $RPC_URL \
        --json | grep -o '"transactionHash":"[^"]*' | cut -d'"' -f4)

    print_success "Round seeded! Tx: $tx_hash"

    echo ""
    print_info "Round $round_id is now ready for betting"
}

emergency_settle_vrf() {
    local round_id=$1

    if [ -z "$round_id" ]; then
        # Get current round if not specified
        round_id=$(cast call $GAME_CORE "getCurrentRound()(uint256)" --rpc-url $RPC_URL)
    fi

    print_header "Emergency VRF Settlement for Round $round_id"

    print_info "This will manually settle the round if VRF has timed out"
    print_info "VRF Timeout Period: 1 hour from round start"

    # Check round metadata to see if already settled
    round_data=$(cast call $GAME_CORE "rounds(uint256)(uint256,uint256,uint256,bool)" $round_id --rpc-url $RPC_URL 2>/dev/null)

    if [ $? -eq 0 ]; then
        settled=$(echo "$round_data" | sed -n '4p' | awk '{print $1}')
        if [ "$settled" = "true" ]; then
            print_error "Round $round_id is already settled!"
            return 1
        fi
    fi

    # Generate a pseudo-random seed (in production, use a proper random source)
    seed=$(date +%s%N | sha256sum | head -c 64)
    seed_decimal=$((16#${seed:0:16}))

    print_info "Using emergency seed: $seed_decimal"

    echo ""
    read -p "Are you sure you want to emergency settle round $round_id? (y/n): " confirm

    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        print_info "Emergency settlement cancelled"
        return 0
    fi

    tx_hash=$(cast send $GAME_CORE "emergencySettleRound(uint256,uint256)" $round_id $seed_decimal \
        --private-key $PRIVATE_KEY \
        --rpc-url $RPC_URL \
        --json | grep -o '"transactionHash":"[^"]*' | cut -d'"' -f4)

    print_success "Emergency settlement complete! Tx: $tx_hash"

    echo ""
    print_info "Round $round_id has been settled. BettingCore should now be seeded."
    print_info "Note: If BettingCore hasn't auto-seeded, run option 4 to manually seed"
}

check_round_status() {
    local round_id=$1

    if [ -z "$round_id" ]; then
        # Get current round if not specified
        round_id=$(cast call $BETTING_CORE "getCurrentRound()(uint256)" --rpc-url $RPC_URL)
    fi

    print_header "Round $round_id Status"

    # Get round metadata
    echo "=== Round Metadata ==="
    round_data=$(cast call $BETTING_CORE "getRoundMetadata(uint256)(uint64,uint64,bool,bool)" $round_id --rpc-url $RPC_URL)

    # Parse line-by-line output (cast returns each value on a new line)
    start_time=$(echo "$round_data" | sed -n '1p' | awk '{print $1}')
    end_time=$(echo "$round_data" | sed -n '2p' | awk '{print $1}')
    seeded=$(echo "$round_data" | sed -n '3p' | awk '{print $1}')
    settled=$(echo "$round_data" | sed -n '4p' | awk '{print $1}')

    echo "Start Time: $(date -d @${start_time} 2>/dev/null || echo $start_time)"
    echo "End Time: $(date -d @${end_time} 2>/dev/null || echo $end_time)"
    echo "Seeded: $seeded"
    echo "Settled: $settled"

    echo ""
    echo "=== Round Pool Accounting ==="

    # Get round pool
    pool_data=$(cast call $BETTING_CORE "getRoundPool(uint256)(uint256,uint256,uint256,uint256,bool)" $round_id --rpc-url $RPC_URL)

    # Parse line-by-line output
    total_locked=$(echo "$pool_data" | sed -n '1p' | awk '{print $1}')
    total_claimed=$(echo "$pool_data" | sed -n '2p' | awk '{print $1}')
    remaining=$(echo "$pool_data" | sed -n '3p' | awk '{print $1}')
    sweep_deadline=$(echo "$pool_data" | sed -n '4p' | awk '{print $1}')
    swept=$(echo "$pool_data" | sed -n '5p' | awk '{print $1}')

    # Convert from wei to LBT
    total_locked_lbt=$(echo "$total_locked" | awk '{printf "%.2f", $1 / 1000000000000000000}')
    total_claimed_lbt=$(echo "$total_claimed" | awk '{printf "%.2f", $1 / 1000000000000000000}')
    remaining_lbt=$(echo "$remaining" | awk '{printf "%.2f", $1 / 1000000000000000000}')

    echo "Total Locked: ${total_locked_lbt} LBT"
    echo "Total Claimed: ${total_claimed_lbt} LBT"
    echo "Remaining: ${remaining_lbt} LBT"
    echo "Sweep Deadline: $(date -d @${sweep_deadline} 2>/dev/null || echo $sweep_deadline)"
    echo "Swept: $swept"

    echo ""
    echo "=== Round Analytics ==="

    # Get round accounting
    acct_data=$(cast call $BETTING_CORE "getRoundAccounting(uint256)(uint128,uint32,uint32)" $round_id --rpc-url $RPC_URL)

    # Parse line-by-line output
    total_volume=$(echo "$acct_data" | sed -n '1p' | awk '{print $1}')
    parlay_count=$(echo "$acct_data" | sed -n '2p' | awk '{print $1}')
    total_bets=$(echo "$acct_data" | sed -n '3p' | awk '{print $1}')

    volume_lbt=$(echo "$total_volume" | awk '{printf "%.2f", $1 / 1000000000000000000}')

    echo "Total Bet Volume: ${volume_lbt} LBT"
    echo "Total Bets: $total_bets"
    echo "Parlay Bets: $parlay_count"

    echo ""
    echo "=== Protocol Reserves ==="
    protocol_reserves=$(cast call $BETTING_CORE "getProtocolReserves()(uint256)" --rpc-url $RPC_URL)
    reserves_lbt=$(echo "$protocol_reserves" | awk '{printf "%.2f", $1 / 1000000000000000000}')
    echo "Available Reserves: ${reserves_lbt} LBT"
}

check_round_odds() {
    local round_id=$1

    if [ -z "$round_id" ]; then
        # Get current round if not specified
        round_id=$(cast call $BETTING_CORE "getCurrentRound()(uint256)" --rpc-url $RPC_URL)
    fi

    print_header "Round $round_id Odds"

    echo "Match | Home Win | Away Win |   Draw   | Locked"
    echo "------|----------|----------|----------|-------"

    # Check odds for all 10 matches (0-9)
    for match_id in {0..9}; do
        # Get locked odds: (homeOdds, awayOdds, drawOdds, locked)
        odds_data=$(cast call $BETTING_CORE "getLockedOdds(uint256,uint256)(uint256,uint256,uint256,bool)" $round_id $match_id --rpc-url $RPC_URL 2>/dev/null)

        if [ ! -z "$odds_data" ]; then
            # Parse line-by-line output (cast returns each value on a new line)
            home_odds=$(echo "$odds_data" | sed -n '1p' | awk '{print $1}')
            away_odds=$(echo "$odds_data" | sed -n '2p' | awk '{print $1}')
            draw_odds=$(echo "$odds_data" | sed -n '3p' | awk '{print $1}')
            locked=$(echo "$odds_data" | sed -n '4p')

            # Convert from wei to decimal (divide by 1e18)
            home_decimal=$(awk "BEGIN {printf \"%.2f\", $home_odds / 1e18}")
            away_decimal=$(awk "BEGIN {printf \"%.2f\", $away_odds / 1e18}")
            draw_decimal=$(awk "BEGIN {printf \"%.2f\", $draw_odds / 1e18}")

            # Format locked status
            if [ "$locked" == "true" ]; then
                locked_status="✓"
            else
                locked_status="✗"
            fi

            printf "  %d   |  %s  |  %s  |  %s  |   %s\n" \
                $match_id \
                "$home_decimal"x \
                "$away_decimal"x \
                "$draw_decimal"x \
                "$locked_status"
        fi
    done

    echo ""
    echo "Note: Odds are locked at round start and never change"
}

# ============ Betting Operations ============

place_bet() {
    print_header "Placing a Test Bet"

    # Get current round
    current_round=$(cast call $BETTING_CORE "getCurrentRound()(uint256)" --rpc-url $RPC_URL)

    if [ "$current_round" == "0" ]; then
        print_error "No active round. Please start a round first."
        return 1
    fi

    print_info "Current round: $current_round"

    # Example bet: 10 LBT on matches 0 and 1
    local bet_amount="10000000000000000000"  # 10 LBT in wei
    local match_indices="[0,1]"
    local predictions="[1,2]"  # Home win for match 0, Away win for match 1

    echo ""
    echo "Bet Details:"
    echo "  Amount: 10 LBT"
    echo "  Matches: 0, 1 (2-leg parlay)"
    echo "  Predictions: Home Win, Away Win"

    # First, approve LBT spending
    print_info "Approving LBT spending..."

    cast send $LBT_TOKEN "approve(address,uint256)" $BETTING_CORE $bet_amount \
        --private-key $PRIVATE_KEY \
        --rpc-url $RPC_URL \
        > /dev/null

    print_success "LBT approved"

    # Place the bet
    print_info "Placing bet..."

    tx_hash=$(cast send $BETTING_CORE \
        "placeBet(uint256,uint256[],uint8[])" \
        $bet_amount \
        "$match_indices" \
        "$predictions" \
        --private-key $PRIVATE_KEY \
        --rpc-url $RPC_URL \
        --json | grep -o '"transactionHash":"[^"]*' | cut -d'"' -f4)

    print_success "Bet placed! Tx: $tx_hash"

    # Wait for confirmation
    sleep 3

    # Get bet ID from logs
    print_info "Retrieving bet ID..."

    # Get total bets to find our bet ID
    total_bets=$(cast call $BETTING_CORE "getTotalBets()(uint256)" --rpc-url $RPC_URL)

    echo -e "Your Bet ID: ${GREEN}$total_bets${NC}"

    # Show updated round status
    echo ""
    check_round_status $current_round
}

check_user_bets() {
    print_header "Checking Your Bets"

    # Get deployer address from private key
    user_address=$(cast wallet address --private-key $PRIVATE_KEY)

    echo "User Address: $user_address"
    echo ""

    # Get user's bet IDs
    bet_ids=$(cast call $BETTING_CORE "getUserBets(address)(uint256[])" $user_address --rpc-url $RPC_URL)

    echo "Your Bet IDs: $bet_ids"

    # Parse and show each bet
    # Remove brackets and split by comma
    bet_ids_clean=$(echo $bet_ids | tr -d '[]' | tr ',' ' ')

    for bet_id in $bet_ids_clean; do
        if [ ! -z "$bet_id" ]; then
            echo ""
            echo "--- Bet #$bet_id ---"

            # Call getBet - returns raw hex ABI-encoded data
            bet_data=$(cast call $BETTING_CORE "getBet(uint256)" $bet_id --rpc-url $RPC_URL 2>/dev/null)

            if [ ! -z "$bet_data" ]; then
                # Decode the hex data manually (each field is 32 bytes = 64 hex chars)
                # Remove 0x prefix
                hex_data="${bet_data#0x}"

                # Extract fields (each is 64 hex chars, representing 32 bytes)
                bettor="0x${hex_data:24:40}"  # Skip 24 chars padding, take 40 chars (address)
                token="0x${hex_data:88:40}"   # Skip to byte 32, then skip 24 padding

                # Amount is at byte 64 (hex char 128)
                amount_hex="0x${hex_data:128:64}"
                amount=$((16#${hex_data:128:64}))

                # Potential payout is at byte 96 (hex char 192)
                payout_hex="0x${hex_data:192:64}"
                payout=$((16#${hex_data:192:64}))

                # Locked multiplier is at byte 128 (hex char 256)
                multiplier_hex="0x${hex_data:256:64}"
                multiplier=$((16#${hex_data:256:64}))

                # Round ID is at byte 160 (hex char 320) - uint64
                round_id=$((16#${hex_data:320:64}))

                # Timestamp at byte 192 (hex char 384) - uint32
                timestamp=$((16#${hex_data:384:64}))

                # Leg count at byte 224 (hex char 448) - uint8
                leg_count=$((16#${hex_data:448:64}))

                # Status at byte 256 (hex char 512) - uint8
                status=$((16#${hex_data:512:64}))

                # Convert to human readable
                amount_lbt=$(echo "$amount" | awk '{printf "%.2f", $1 / 1000000000000000000}')
                payout_lbt=$(echo "$payout" | awk '{printf "%.2f", $1 / 1000000000000000000}')

                if [ "$multiplier" -gt 0 ]; then
                    multiplier_display=$(echo "$multiplier" | awk '{printf "%.2fx", $1 / 1000000000000000000}')
                else
                    multiplier_display="0.00x"
                fi

                echo "  Amount: ${amount_lbt} LBT"
                echo "  Potential Payout: ${payout_lbt} LBT"
                echo "  Locked Multiplier: ${multiplier_display}"
                echo "  Round: $round_id"
                echo "  Legs: $leg_count"
                echo "  Status: $status (0=Active, 1=Claimed, 2=Lost, 3=Cancelled)"

                # WARNING: If payout is 0, something went wrong during bet placement
                if [ "$payout" -eq 0 ] && [ "$status" -eq 0 ]; then
                    echo ""
                    echo "  ⚠️  WARNING: Potential payout is 0! This bet was placed before odds were locked."
                    echo "      The round may not have been seeded when this bet was placed."
                fi
            else
                echo "  Unable to fetch bet data (getBet call failed)"
            fi
        fi
    done
}

# ============ Admin Operations ============

check_balances() {
    print_header "Token Balances"

    # Get deployer address
    deployer=$(cast wallet address --private-key $PRIVATE_KEY)

    echo "Your Address: $deployer"
    echo ""

    # Check LBT balance
    balance=$(cast call $LBT_TOKEN "balanceOf(address)(uint256)" $deployer --rpc-url $RPC_URL)
    balance_lbt=$(echo "$balance" | awk '{printf "%.2f", $1 / 1000000000000000000}')

    echo "Your LBT Balance: ${balance_lbt} LBT"

    # Check BettingCore balance
    betting_balance=$(cast call $LBT_TOKEN "balanceOf(address)(uint256)" $BETTING_CORE --rpc-url $RPC_URL)
    betting_lbt=$(echo "$betting_balance" | awk '{printf "%.2f", $1 / 1000000000000000000}')

    echo "BettingCore Balance: ${betting_lbt} LBT"

    # Check protocol reserves
    reserves=$(cast call $BETTING_CORE "getProtocolReserves()(uint256)" --rpc-url $RPC_URL)
    reserves_lbt=$(echo "$reserves" | awk '{printf "%.2f", $1 / 1000000000000000000}')

    echo "Protocol Reserves: ${reserves_lbt} LBT"
}

settle_round() {
    local round_id=$1

    if [ -z "$round_id" ]; then
        print_error "Usage: settle_round <round_id>"
        return 1
    fi

    print_header "Settling Round $round_id"

    # Example: All home wins (result = 1 for all 10 matches)
    local results="[1,1,1,1,1,1,1,1,1,1]"

    print_info "Settlement results: All home wins (for testing)"

    tx_hash=$(cast send $BETTING_CORE "settleRound(uint256,uint8[])" $round_id "$results" \
        --private-key $PRIVATE_KEY \
        --rpc-url $RPC_URL \
        --json | grep -o '"transactionHash":"[^"]*' | cut -d'"' -f4)

    print_success "Round settled! Tx: $tx_hash"
}

# ============ Main Menu ============

show_menu() {
    echo ""
    echo "========================================="
    echo "   Betting System Management"
    echo "========================================="
    echo ""
    echo "Season Management:"
    echo "  1) Start Season"
    echo "  2) Get Season Info"
    echo ""
    echo "Round Management:"
    echo "  3) Start New Round"
    echo "  4) Seed Round (Manual - for VRF bypass)"
    echo "  5) Emergency VRF Settlement (if VRF timeout)"
    echo "  6) Check Round Status"
    echo "  7) Check Round Odds"
    echo "  8) Settle Round (Manual)"
    echo ""
    echo "Betting Operations:"
    echo "  9) Place Test Bet"
    echo "  10) Check Your Bets"
    echo ""
    echo "Admin:"
    echo "  11) Check Balances"
    echo "  12) Full Status Report"
    echo ""
    echo "  0) Exit"
    echo ""
}

full_status_report() {
    check_balances
    get_season_info

    current_round=$(cast call $BETTING_CORE "getCurrentRound()(uint256)" --rpc-url $RPC_URL)
    if [ "$current_round" != "0" ]; then
        check_round_status $current_round
    fi

    check_user_bets
}

# ============ Main Script ============

main() {
    print_header "Betting System Management Script"

    check_requirements

    # If arguments provided, run directly
    if [ $# -gt 0 ]; then
        case $1 in
            "start-season")
                initialize_season
                ;;
            "start-round")
                start_round
                ;;
            "seed-round")
                seed_round ${2:-}
                ;;
            "place-bet")
                place_bet
                ;;
            "check-round")
                check_round_status ${2:-}
                ;;
            "check-odds")
                check_round_odds ${2:-}
                ;;
            "settle-round")
                settle_round ${2}
                ;;
            "balances")
                check_balances
                ;;
            "status")
                full_status_report
                ;;
            "my-bets")
                check_user_bets
                ;;
            *)
                echo "Unknown command: $1"
                echo "Available commands: start-season, start-round, seed-round, place-bet, check-round, check-odds, settle-round, balances, status, my-bets"
                exit 1
                ;;
        esac
        exit 0
    fi

    # Interactive menu
    while true; do
        show_menu
        read -p "Select option: " choice

        case $choice in
            1) initialize_season ;;
            2) get_season_info ;;
            3) start_round ;;
            4)
                read -p "Enter round ID (or press Enter for current): " round_id
                seed_round $round_id
                ;;
            5)
                read -p "Enter round ID (or press Enter for current): " round_id
                emergency_settle_vrf $round_id
                ;;
            6)
                read -p "Enter round ID (or press Enter for current): " round_id
                check_round_status $round_id
                ;;
            7)
                read -p "Enter round ID (or press Enter for current): " round_id
                check_round_odds $round_id
                ;;
            8)
                read -p "Enter round ID to settle: " round_id
                settle_round $round_id
                ;;
            9) place_bet ;;
            10) check_user_bets ;;
            11) check_balances ;;
            12) full_status_report ;;
            0)
                print_info "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option"
                ;;
        esac

        read -p "Press Enter to continue..."
    done
}

# Run main function
main "$@"

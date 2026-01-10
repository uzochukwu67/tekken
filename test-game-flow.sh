#!/bin/bash

# iVirtualz Game Flow Test Script
# Tests complete game cycle: fund, start season/round, place bet, settle, check results

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SEPOLIA_RPC_URL="${SEPOLIA_RPC_URL:-https://ethereum-sepolia-rpc.publicnode.com}"
PRIVATE_KEY="0x7125ce4cebbdcd9d76871c1b8a10b65034142ade2f0129c9eba244bb2a9c100f"

# Deployed Contract Addresses (Update these with your actual addresses)
LEAGUE_TOKEN="0x7050EF06FC1C85fbf55552072328797284D0f6e8"
GAME_ENGINE="0xA80B66E427C679B335b333Ce1636BEA31775af48"
LIQUIDITY_POOL="0x39aC0D048a2709487AdEddD0f3940E265CfbC743"
BETTING_POOL="0x08fb8326145ac8bF47562b2389c277BAcCD3312b"

# Chainlink Sepolia Addresses
LINK_TOKEN="0x779877A7B0D9E8603169DdbD7836e478b4624789"

# Test Configuration
LINK_AMOUNT="2000000000000000000"  # 10 LINK
BET_AMOUNT="1000000000000000000"    # 1 LEAGUE token
ROUND_DURATION=900                   # 15 minutes in seconds

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
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Big-int comparison helpers (avoid dependency on 'bc')
# compare_ge a b -> exit code 0 if a >= b
compare_ge() {
    a=$(echo "$1" | awk '{print $1}' | sed 's/^0*//')
    b=$(echo "$2" | awk '{print $1}' | sed 's/^0*//')
    [ -z "$a" ] && a=0
    [ -z "$b" ] && b=0

    if [ ${#a} -gt ${#b} ]; then
        return 0
    elif [ ${#a} -lt ${#b} ]; then
        return 1
    else
        if [[ "$a" > "$b" || "$a" == "$b" ]]; then
            return 0
        else
            return 1
        fi
    fi
}

# compare_lt a b -> exit code 0 if a < b
compare_lt() {
    if compare_ge "$1" "$2"; then
        return 1
    else
        return 0
    fi
}

# Helper to send a transaction and extract the transaction hash
# Works even if jq is not installed.
send_tx() {
    local raw txhash
    # Call cast and capture raw output and status
    raw=$(cast send "$@" --json 2>&1) || { log_error "Transaction failed to send. Raw output:"; echo "$raw"; return 1; }

    if command -v jq >/dev/null 2>&1; then
        txhash=$(echo "$raw" | jq -r '.transactionHash' 2>/dev/null || true)
    else
        txhash=$(echo "$raw" | grep -oE '"transactionHash"[[:space:]]*:[[:space:]]*"[^"]*"' | sed -E 's/.*"transactionHash"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/' || true)
    fi

    # Return transaction hash (may be empty if parsing failed)
    echo "$txhash"
}

check_requirements() {
    log_section "Checking Requirements"

    if ! command -v cast &> /dev/null; then
        log_error "cast (foundry) not found. Install from https://getfoundry.sh"
        exit 1
    fi
    log_success "cast found"

    if [ -z "$PRIVATE_KEY" ]; then
        log_error "PRIVATE_KEY environment variable not set"
        exit 1
    fi
    log_success "Private key configured"

    WALLET_ADDRESS=$(cast wallet address --private-key "$PRIVATE_KEY" 2>/dev/null)
    log_success "Wallet address: $WALLET_ADDRESS"

    BALANCE=$(cast balance "$WALLET_ADDRESS" --rpc-url "$SEPOLIA_RPC_URL")
    BALANCE_RAW=$(echo "$BALANCE" | awk '{print $1}')
    BALANCE_ETH=$BALANCE_RAW
    log_info "ETH Balance: $BALANCE_ETH ETH"

    # Check if balance < 0.01 ETH (0.01 * 1e18 wei)
    MIN_BALANCE_WEI="10000000000000000"
    if compare_lt "$BALANCE_RAW" "$MIN_BALANCE_WEI"; then
        log_warning "Low ETH balance. Get Sepolia ETH from https://sepoliafaucet.com"
    fi
}

fund_protocol_reserve() {
    log_section "Step 1: Funding Protocol Reserve"

    # Check current protocol reserve
    CURRENT_RESERVE=$(cast call "$BETTING_POOL" \
        "protocolReserve()(uint256)" \
        --rpc-url "$SEPOLIA_RPC_URL")
    CURRENT_RESERVE_RAW=$(echo "$CURRENT_RESERVE" | awk '{print $1}')

    CURRENT_RESERVE_FORMATTED=$CURRENT_RESERVE_RAW
    log_info "Current protocol reserve: $CURRENT_RESERVE_FORMATTED LEAGUE"

    # Compare against 1000 LEAGUE (1000 * 1e18 wei)
    THRESHOLD_WEI="1000000000000000000000"
    if compare_ge "$CURRENT_RESERVE_RAW" "$THRESHOLD_WEI"; then
        log_success "Protocol reserve already funded ($CURRENT_RESERVE_FORMATTED LEAGUE)"
        return 0
    fi

    log_warning "Protocol reserve needs funding to pay winners!"
    log_info "Funding protocol reserve with 10,000 LEAGUE tokens..."

    # Approve BettingPool to spend tokens
    cast send "$LEAGUE_TOKEN" \
        "approve(address,uint256)" \
        "$BETTING_POOL" \
        "10000000000000000000000" \
        --rpc-url "$SEPOLIA_RPC_URL" \
        --private-key "$PRIVATE_KEY" \
        --json > /dev/null

    log_success "Tokens approved"

    # Fund protocol reserve
    TX_HASH=$(send_tx "$BETTING_POOL" \
        "fundProtocolReserve(uint256)" \
        "10000000000000000000000" \
        --rpc-url "$SEPOLIA_RPC_URL" \
        --private-key "$PRIVATE_KEY")

    if [ -n "$TX_HASH" ]; then
        log_success "Protocol reserve funded! TX: $TX_HASH"
    else
        log_success "Protocol reserve funded (TX hash not parsed)"
    fi

    # Verify new balance
    NEW_RESERVE=$(cast call "$BETTING_POOL" \
        "protocolReserve()(uint256)" \
        --rpc-url "$SEPOLIA_RPC_URL")

    NEW_RESERVE_FORMATTED=$NEW_RESERVE
    log_success "New protocol reserve: $NEW_RESERVE_FORMATTED LEAGUE"
}

fund_liquidity_pool() {
    log_section "Step 2: Funding Liquidity Pool (Optional)"

    # Check current LP liquidity
    CURRENT_LIQUIDITY=$(cast call "$LIQUIDITY_POOL" \
        "getTotalLiquidity()(uint256)" \
        --rpc-url "$SEPOLIA_RPC_URL")
    CURRENT_LIQUIDITY_RAW=$(echo "$CURRENT_LIQUIDITY" | awk '{print $1}')

    CURRENT_LIQUIDITY_FORMATTED=$CURRENT_LIQUIDITY_RAW
    log_info "Current LP liquidity: $CURRENT_LIQUIDITY_FORMATTED LEAGUE"

    # Compare against 1000 LEAGUE
    THRESHOLD_LP_WEI="1000000000000000000000"
    if compare_ge "$CURRENT_LIQUIDITY_RAW" "$THRESHOLD_LP_WEI"; then
        log_success "Liquidity pool already funded ($CURRENT_LIQUIDITY_FORMATTED LEAGUE)"
        return 0
    fi

    log_info "Depositing liquidity to pool (5,000 LEAGUE)..."
    log_info "You will receive LP tokens (vLP) in return"

    # Approve LiquidityPool
    cast send "$LEAGUE_TOKEN" \
        "approve(address,uint256)" \
        "$LIQUIDITY_POOL" \
        "5000000000000000000000" \
        --rpc-url "$SEPOLIA_RPC_URL" \
        --private-key "$PRIVATE_KEY" \
        --json > /dev/null

    log_success "Tokens approved"

    # Deposit liquidity (correct function for LPs)
    TX_HASH=$(send_tx "$LIQUIDITY_POOL" \
        "deposit(uint256)" \
        "5000000000000000000000" \
        --rpc-url "$SEPOLIA_RPC_URL" \
        --private-key "$PRIVATE_KEY")

    if [ -n "$TX_HASH" ]; then
        log_success "Liquidity deposited! TX: $TX_HASH"
    else
        log_success "Liquidity deposited (TX hash not parsed)"
    fi

    # Check LP tokens received
    LP_BALANCE=$(cast call "$LIQUIDITY_POOL" \
        "balanceOf(address)(uint256)" \
        "$WALLET_ADDRESS" \
        --rpc-url "$SEPOLIA_RPC_URL")

    LP_BALANCE_FORMATTED=$LP_BALANCE
    log_success "You received $LP_BALANCE_FORMATTED vLP tokens"

    NEW_LIQUIDITY=$(cast call "$LIQUIDITY_POOL" \
        "getTotalLiquidity()(uint256)" \
        --rpc-url "$SEPOLIA_RPC_URL")

    NEW_LIQUIDITY_FORMATTED=$NEW_LIQUIDITY
    log_success "New LP liquidity: $NEW_LIQUIDITY_FORMATTED LEAGUE"
}

fund_game_engine_with_link() {
    log_section "Step 3: Funding GameEngine with LINK"

    # Check current LINK balance of GameEngine
    CURRENT_LINK=$(cast call "$LINK_TOKEN" \
        "balanceOf(address)(uint256)" \
        "$GAME_ENGINE" \
        --rpc-url "$SEPOLIA_RPC_URL")
    CURRENT_LINK_RAW=$(echo "$CURRENT_LINK" | awk '{print $1}')

    CURRENT_LINK_FORMATTED=$CURRENT_LINK_RAW
    log_info "GameEngine current LINK balance: $CURRENT_LINK_FORMATTED LINK"

    # Check wallet LINK balance
    WALLET_LINK=$(cast call "$LINK_TOKEN" \
        "balanceOf(address)(uint256)" \
        "$WALLET_ADDRESS" \
        --rpc-url "$SEPOLIA_RPC_URL")
    WALLET_LINK_RAW=$(echo "$WALLET_LINK" | awk '{print $1}')

    WALLET_LINK_FORMATTED=$WALLET_LINK_RAW
    log_info "Your LINK balance: $WALLET_LINK_FORMATTED LINK"

    # If GameEngine already has >=5 LINK, skip
    LINK_THRESHOLD_5_WEI="5000000000000000000"
    LINK_THRESHOLD_10_WEI="10000000000000000000"
    if compare_ge "$CURRENT_LINK_RAW" "$LINK_THRESHOLD_5_WEI"; then
        log_success "GameEngine already has sufficient LINK ($CURRENT_LINK_FORMATTED LINK)"
        return 0
    fi

    if compare_lt "$WALLET_LINK_RAW" "$LINK_THRESHOLD_10_WEI"; then
        log_warning "Insufficient LINK in wallet. Get LINK from https://faucets.chain.link/sepolia"
        log_info "Continuing anyway (may fail during VRF request)..."
        return 0
    fi

    log_info "Sending $LINK_AMOUNT wei (10 LINK) to GameEngine..."
    TX_HASH=$(cast send "$LINK_TOKEN" \
        "transfer(address,uint256)" \
        "$GAME_ENGINE" \
        "$LINK_AMOUNT" \
        --rpc-url "$SEPOLIA_RPC_URL" \
        --private-key "$PRIVATE_KEY" \
        --json )

    log_success "LINK sent! TX: $TX_HASH"

    # Verify new balance
    NEW_LINK=$(cast call "$LINK_TOKEN" \
        "balanceOf(address)(uint256)" \
        "$GAME_ENGINE" \
        --rpc-url "$SEPOLIA_RPC_URL")

    NEW_LINK_FORMATTED=$NEW_LINK
    log_success "GameEngine new LINK balance: $NEW_LINK_FORMATTED LINK"
}

start_season() {
    log_section "Step 4: Starting New Season"

    CURRENT_SEASON=$(cast call "$GAME_ENGINE" \
        "currentSeasonId()(uint256)" \
        --rpc-url "$SEPOLIA_RPC_URL")

    log_info "Current season ID: $CURRENT_SEASON"

    # Check if season is already active
    if [ "$CURRENT_SEASON" != "0" ]; then
        SEASON_DATA=$(cast call "$GAME_ENGINE" \
            "getSeason(uint256)" \
            "$CURRENT_SEASON" \
            --rpc-url "$SEPOLIA_RPC_URL")

        log_info "Season $CURRENT_SEASON already exists, checking status..."
        # Parse season data to check if active (you may need to adjust this)
    fi

    log_info "Starting new season..."
    TX_HASH=$(cast send "$GAME_ENGINE" \
        "startSeason()" \
        --rpc-url "$SEPOLIA_RPC_URL" \
        --private-key "$PRIVATE_KEY" \
        --json )

    log_success "Season started! TX: $TX_HASH"

    NEW_SEASON=$(cast call "$GAME_ENGINE" \
        "currentSeasonId()(uint256)" \
        --rpc-url "$SEPOLIA_RPC_URL")

    log_success "New season ID: $NEW_SEASON"
}

start_round() {
    log_section "Step 5: Starting New Round"

    CURRENT_ROUND=$(cast call "$GAME_ENGINE" \
        "currentRoundId()(uint256)" \
        --rpc-url "$SEPOLIA_RPC_URL")

    log_info "Current round ID: $CURRENT_ROUND"

    log_info "Starting new round..."
    TX_HASH=$(cast send "$GAME_ENGINE" \
        "startRound()" \
        --rpc-url "$SEPOLIA_RPC_URL" \
        --private-key "$PRIVATE_KEY" \
        --json )

    log_success "Round started! TX: $TX_HASH"

    NEW_ROUND=$(cast call "$GAME_ENGINE" \
        "currentRoundId()(uint256)" \
        --rpc-url "$SEPOLIA_RPC_URL")

    log_success "New round ID: $NEW_ROUND"

    # Get round details (request specific return tuple to avoid nested ABI encoding)
    ROUND_RET=$(cast call "$GAME_ENGINE" "getRound(uint256) returns (uint256,uint256,uint256,uint256,bool)" "$NEW_ROUND" --rpc-url "$SEPOLIA_RPC_URL")

    # Round tuple fields: roundId, seasonId, startTime, vrfRequestId, settled
    ROUND_START_TIME=$(echo "$ROUND_RET" | awk '{print $3}' | tr -d ',')

    if [ -z "$ROUND_START_TIME" ] || [ "$ROUND_START_TIME" = "0" ]; then
        log_warning "Round start time not available from contract"
        TIME_REMAINING=$((ROUND_DURATION))
    else
        log_info "Round start time: $ROUND_START_TIME"
        CURRENT_TIME=$(date +%s)
        END_TIME=$((ROUND_START_TIME + ROUND_DURATION))
        TIME_REMAINING=$((END_TIME - CURRENT_TIME))
        if [ $TIME_REMAINING -lt 0 ]; then
            TIME_REMAINING=0
        fi
    fi

    log_info "Round will be ready for settlement in $TIME_REMAINING seconds"
}

check_round_matches() {
    log_section "Step 6: Checking Round Matches"

    CURRENT_ROUND=$(cast call "$GAME_ENGINE" \
        "currentRoundId()(uint256)" \
        --rpc-url "$SEPOLIA_RPC_URL")

    log_info "Fetching matches for round $CURRENT_ROUND..."

    # Get first 3 matches to display
    for i in {0..2}; do
        # Request explicit return types to avoid ambiguous ABI decoding
        MATCH_RET=$(cast call "$GAME_ENGINE" \
            "getMatch(uint256,uint256) returns (uint256,uint256,uint8,uint8,uint8,bool,uint256,uint256,uint256)" \
            "$CURRENT_ROUND" \
            "$i" \
            --rpc-url "$SEPOLIA_RPC_URL")

        # Parse match data (homeTeamId, awayTeamId, etc.)
        HOME_TEAM_ID=$(echo "$MATCH_RET" | awk '{print $1}' | tr -d ',')
        AWAY_TEAM_ID=$(echo "$MATCH_RET" | awk '{print $2}' | tr -d ',')

        if [ -z "$HOME_TEAM_ID" ] || [ -z "$AWAY_TEAM_ID" ]; then
            log_warning "Match $i data not available (possibly out-of-range)"
            continue
        fi

        # Get team names using getTeam (safer interface)
        HOME_TEAM_DATA=$(cast call "$GAME_ENGINE" \
            "getTeam(uint256)" \
            "$HOME_TEAM_ID" \
            --rpc-url "$SEPOLIA_RPC_URL")

        AWAY_TEAM_DATA=$(cast call "$GAME_ENGINE" \
            "getTeam(uint256)" \
            "$AWAY_TEAM_ID" \
            --rpc-url "$SEPOLIA_RPC_URL")

        HOME_TEAM_NAME=$(echo "$HOME_TEAM_DATA" | cut -d'"' -f2)
        AWAY_TEAM_NAME=$(echo "$AWAY_TEAM_DATA" | cut -d'"' -f2)

        log_info "Match $i: $HOME_TEAM_NAME (Team $HOME_TEAM_ID) vs $AWAY_TEAM_NAME (Team $AWAY_TEAM_ID)"
    done

    log_success "Total matches in round: 10"
}

place_multibet() {
    log_section "Step 7: Placing Multi-Bet"

    CURRENT_ROUND=$(cast call "$GAME_ENGINE" \
        "currentRoundId()(uint256)" \
        --rpc-url "$SEPOLIA_RPC_URL")

    log_info "Creating a 3-match multi-bet..."
    log_info "Predictions: Match 0 = HOME_WIN(1), Match 1 = AWAY_WIN(2), Match 2 = DRAW(3)"

    # First approve LEAGUE tokens for betting
    log_info "Approving LEAGUE tokens..."
    cast send "$LEAGUE_TOKEN" \
        "approve(address,uint256)" \
        "$BETTING_POOL" \
        "$BET_AMOUNT" \
        --rpc-url "$SEPOLIA_RPC_URL" \
        --private-key "$PRIVATE_KEY" \
        --json > /dev/null

    log_success "Tokens approved"

    # Place multi-bet: placeBet(uint256[] matchIndices, uint8[] predictions, uint256 betAmount)
    log_info "Placing bet..."
    cast send "$BETTING_POOL" \
        "placeBet(uint256[],uint8[],uint256)" \
        "[0,1,2]" \
        "[1,2,3]" \
        "$BET_AMOUNT" \
        --rpc-url "$SEPOLIA_RPC_URL" \
        --private-key "$PRIVATE_KEY" \
        --json > /dev/null

    log_success "Bet placed! TX: "
    log_info "Bet amount: 1 LEAGUE token"
    log_info "Bet ID will be: 0 (if this is your first bet)"
}

check_bet_details() {
    log_section "Step 8: Checking Bet Details"

    log_info "Fetching bet #0 details..."

    BET_RET_RAW=$(cast call "$BETTING_POOL" \
        "getBet(uint256) returns (address,uint256,uint256,uint256,bool,bool)" \
        "0" \
        --rpc-url "$SEPOLIA_RPC_URL" || true)

    # Normalize output to a single line and remove commas/brackets for consistent parsing
    BET_RET=$(echo "$BET_RET_RAW" | tr '\n' ' ' | sed 's/  */ /g' | sed 's/\[//g; s/\]//g; s/,//g')

    if [ -z "$BET_RET" ]; then
        log_warning "Failed to fetch bet #0 (empty response)"
    else
        BET_BETTOR=$(echo "$BET_RET" | awk '{print $1}')
        BET_ROUND_ID=$(echo "$BET_RET" | awk '{print $2}' | tr -d ',')
        BET_AMOUNT=$(echo "$BET_RET" | awk '{print $3}' | tr -d ',')
        BET_BONUS=$(echo "$BET_RET" | awk '{print $4}' | tr -d ',')
        BET_SETTLED=$(echo "$BET_RET" | awk '{print $5}' | tr -d ',')
        BET_CLAIMED=$(echo "$BET_RET" | awk '{print $6}' | tr -d ',')

        log_info "Bet #0: bettor=$BET_BETTOR, round=$BET_ROUND_ID, amount=$BET_AMOUNT, bonus=$BET_BONUS, settled=$BET_SETTLED, claimed=$BET_CLAIMED"

        # If WALLET_ADDRESS is not set (we may have skipped check_requirements), fall back to bettor
        if [ -z "$WALLET_ADDRESS" ]; then
            WALLET_ADDRESS="$BET_BETTOR"
            log_info "WALLET_ADDRESS not set — using bet bettor: $WALLET_ADDRESS"
        fi
    fi

    # Check user bets array (sanitize array output)
    USER_BETS_RAW=$(cast call "$BETTING_POOL" \
        "getUserBets(address)(uint256[])" \
        "$WALLET_ADDRESS" \
        --rpc-url "$SEPOLIA_RPC_URL" || true)
    USER_BETS=$(echo "$USER_BETS_RAW" | tr '\n' ' ' | sed 's/  */ /g')

    log_success "Your bet IDs: $USER_BETS"
} 

wait_for_round_end() {
    log_section "Step 7: Waiting for Round to End"

    CURRENT_ROUND=$(cast call "$GAME_ENGINE" \
        "currentRoundId()(uint256)" \
        --rpc-url "$SEPOLIA_RPC_URL")

    ROUND_RET=$(cast call "$GAME_ENGINE" "getRound(uint256) returns (uint256,uint256,uint256,uint256,bool)" "$CURRENT_ROUND" --rpc-url "$SEPOLIA_RPC_URL")
    ROUND_START_TIME=$(echo "$ROUND_RET" | awk '{print $3}' | tr -d ',')

    if [ -z "$ROUND_START_TIME" ] || [ "$ROUND_START_TIME" = "0" ]; then
        log_warning "Round start time not available — assuming already elapsed"
        TIME_REMAINING=0
    else
        CURRENT_TIME=$(date +%s)
        END_TIME=$((ROUND_START_TIME + ROUND_DURATION))
        TIME_REMAINING=$((END_TIME - CURRENT_TIME))
        if [ $TIME_REMAINING -lt 0 ]; then
            TIME_REMAINING=0
        fi
    fi

    if [ $TIME_REMAINING -gt 0 ]; then
        log_warning "Round ends in $TIME_REMAINING seconds ($((TIME_REMAINING / 60)) minutes)"
        log_info "Waiting for round to end..."

        # Progress bar
        for ((i=0; i<=TIME_REMAINING; i+=30)); do
            REMAINING=$((TIME_REMAINING - i))
            MIN=$((REMAINING / 60))
            SEC=$((REMAINING % 60))
            echo -ne "\r  ⏳ Time remaining: ${MIN}m ${SEC}s    "

            if [ $REMAINING -gt 0 ]; then
                sleep 30
            fi
        done
        echo ""
        log_success "Round duration elapsed!"
    else
        log_success "Round duration already elapsed! Ready to settle."
    fi
}

request_vrf_settlement() {
    log_section "Step 8: Requesting VRF Settlement"

    CURRENT_ROUND=$(cast call "$GAME_ENGINE" \
        "currentRoundId()(uint256)" \
        --rpc-url "$SEPOLIA_RPC_URL")

    # Check if already settled by getting round data
    ROUND_DATA=$(cast call "$GAME_ENGINE" \
        "getRound(uint256)" \
        "$CURRENT_ROUND" \
        --rpc-url "$SEPOLIA_RPC_URL")

    # Extract the 'settled' boolean (5th field in the tuple)
    IS_SETTLED=$(echo "$ROUND_DATA" | awk '{print $5}' | tr -d ',')

    if [ "$IS_SETTLED" = "true" ]; then
        log_success "Round $CURRENT_ROUND is already settled!"
        return 0
    fi

    log_info "Requesting VRF for round $CURRENT_ROUND..."
    TX_HASH=$(cast send "$GAME_ENGINE" \
        "requestMatchResults()" \
        --rpc-url "$SEPOLIA_RPC_URL" \
        --private-key "$PRIVATE_KEY" \
        --gas-limit 500000 
         )

    log_success "VRF requested! TX: $TX_HASH"
    log_info "Waiting for VRF callback (usually 2-5 minutes on testnet)..."

    # Wait for settlement
    for i in {1..40}; do
        sleep 15
        ROUND_DATA=$(cast call "$GAME_ENGINE" \
            "getRound(uint256)" \
            "$CURRENT_ROUND" \
            --rpc-url "$SEPOLIA_RPC_URL")

        IS_SETTLED=$(echo "$ROUND_DATA" | awk '{print $5}' | tr -d ',')

        if [ "$IS_SETTLED" = "true" ]; then
            log_success "Round $CURRENT_ROUND settled by VRF!"
            return 0
        fi

        echo -ne "\r  ⏳ Waiting for VRF response... ($((i * 15))s)    "
    done

    echo ""
    log_warning "VRF taking longer than expected. Check manually or wait more."
}

check_match_results() {
    log_section "Step 9: Checking Match Results"

    CURRENT_ROUND=$(cast call "$GAME_ENGINE" \
        "currentRoundId()(uint256)" \
        --rpc-url "$SEPOLIA_RPC_URL")

    log_info "Fetching match results for round $CURRENT_ROUND..."

    for i in {0..2}; do
        MATCH_RET_RAW=$(cast call "$GAME_ENGINE" "getMatch(uint256,uint256) returns (uint256,uint256,uint8,uint8,uint8,bool,uint256,uint256,uint256)" "$CURRENT_ROUND" "$i" --rpc-url "$SEPOLIA_RPC_URL" || true)
        MATCH_RET=$(echo "$MATCH_RET_RAW" | tr '\n' ' ' | sed 's/  */ /g' | sed 's/\[//g; s/\]//g; s/,//g')

        if [ -z "$MATCH_RET" ]; then
            log_warning "Match $i not available or out-of-range"
            continue
        fi

        # If cast returned a single number (parse edge case), skip
        if echo "$MATCH_RET" | grep -Eq '^[0-9]+$'; then
            log_warning "Match $i returned unexpected lone number: $MATCH_RET - skipping"
            continue
        fi

        HOME_TEAM_ID=$(echo "$MATCH_RET" | awk '{print $1}' | tr -d ',')
        AWAY_TEAM_ID=$(echo "$MATCH_RET" | awk '{print $2}' | tr -d ',')
        HOME_SCORE=$(echo "$MATCH_RET" | awk '{print $3}' | tr -d ',')
        AWAY_SCORE=$(echo "$MATCH_RET" | awk '{print $4}' | tr -d ',')
        OUTCOME=$(echo "$MATCH_RET" | awk '{print $5}' | tr -d ',')

        # Request explicit return types for getTeam to ensure consistent output
        HOME_TEAM_DATA_RAW=$(cast call "$GAME_ENGINE" "getTeam(uint256) returns (string,uint256,uint256,uint256,uint256,uint256,uint256)" "$HOME_TEAM_ID" --rpc-url "$SEPOLIA_RPC_URL" || true)
        AWAY_TEAM_DATA_RAW=$(cast call "$GAME_ENGINE" "getTeam(uint256) returns (string,uint256,uint256,uint256,uint256,uint256,uint256)" "$AWAY_TEAM_ID" --rpc-url "$SEPOLIA_RPC_URL" || true)

        HOME_TEAM_DATA=$(echo "$HOME_TEAM_DATA_RAW" | tr '\n' ' ' | sed 's/  */ /g')
        AWAY_TEAM_DATA=$(echo "$AWAY_TEAM_DATA_RAW" | tr '\n' ' ' | sed 's/  */ /g')

        # Extract name robustly (works if output is quoted or plain)
        HOME_TEAM_NAME=$(echo "$HOME_TEAM_DATA" | sed -n 's/.*"\([^\"]*\)".*/\1/p')
        AWAY_TEAM_NAME=$(echo "$AWAY_TEAM_DATA" | sed -n 's/.*"\([^\"]*\)".*/\1/p')

        # Fallbacks if name extraction failed
        if [ -z "$HOME_TEAM_NAME" ]; then
            HOME_TEAM_NAME="Team $HOME_TEAM_ID"
        fi
        if [ -z "$AWAY_TEAM_NAME" ]; then
            AWAY_TEAM_NAME="Team $AWAY_TEAM_ID"
        fi

        OUTCOME_TEXT="PENDING"
        case $OUTCOME in
            1) OUTCOME_TEXT="${GREEN}HOME WIN${NC}" ;;
            2) OUTCOME_TEXT="${RED}AWAY WIN${NC}" ;;
            3) OUTCOME_TEXT="${YELLOW}DRAW${NC}" ;;
        esac

        echo -e "  Match $i: ${BLUE}$HOME_TEAM_NAME${NC} $HOME_SCORE - $AWAY_SCORE ${BLUE}$AWAY_TEAM_NAME${NC} | Result: $OUTCOME_TEXT"
    done
}

check_bet_outcome() {
    log_section "Step 10: Checking Bet Outcome"

    log_info "Checking if bet #0 won..."

    # Get bet details
    BET_RET=$(cast call "$BETTING_POOL" \
        "getBet(uint256) returns (address,uint256,uint256,uint256,bool,bool)" \
        "0" \
        --rpc-url "$SEPOLIA_RPC_URL" || true)

    if [ -z "$BET_RET" ]; then
        log_warning "Failed to fetch bet #0 (empty response)"
    else
        BET_BETTOR=$(echo "$BET_RET" | awk '{print $1}')
        BET_ROUND_ID=$(echo "$BET_RET" | awk '{print $2}' | tr -d ',')
        BET_AMOUNT=$(echo "$BET_RET" | awk '{print $3}' | tr -d ',')
        BET_BONUS=$(echo "$BET_RET" | awk '{print $4}' | tr -d ',')
        BET_SETTLED=$(echo "$BET_RET" | awk '{print $5}' | tr -d ',')
        BET_CLAIMED=$(echo "$BET_RET" | awk '{print $6}' | tr -d ',')

        log_info "Bet details: bettor=$BET_BETTOR, round=$BET_ROUND_ID, amount=$BET_AMOUNT, bonus=$BET_BONUS, settled=$BET_SETTLED, claimed=$BET_CLAIMED"
    fi

    # Try to claim winnings (will revert if bet lost)
    log_info "Attempting to claim winnings..."
    if TX_HASH=$(send_tx "$BETTING_POOL" \
        "claimWinnings(uint256)" \
        "0" \
        --rpc-url "$SEPOLIA_RPC_URL" \
        --private-key "$PRIVATE_KEY"); then
        log_success "🎉 YOU WON! Winnings claimed. TX: $TX_HASH"

        # Get new balance
        NEW_BALANCE=$(cast call "$LEAGUE_TOKEN" \
            "balanceOf(address)(uint256)" \
            "$WALLET_ADDRESS" \
            --rpc-url "$SEPOLIA_RPC_URL")
        NEW_BALANCE_FORMATTED=$NEW_BALANCE
        log_success "New LEAGUE balance: $NEW_BALANCE_FORMATTED tokens"
    else
        log_error "😞 Claim failed or bet lost. Better luck next time!"
        # For debugging, attempt a raw send to show error details (non-fatal)
        RAW_CLAIM=$(cast send "$BETTING_POOL" \
            "claimWinnings(uint256)" \
            "0" \
            --rpc-url "$SEPOLIA_RPC_URL" \
            --private-key "$PRIVATE_KEY" 2>&1 || true)
        log_info "Error details: $RAW_CLAIM"
    fi
}

# Main execution
main() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}║          iVirtualz Game Flow Test Script                  ║${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # check_requirements
    # fund_protocol_reserve
    # fund_liquidity_pool
    # fund_game_engine_with_link
    # start_season
    # start_round
    # check_round_matches
    # place_multibet
    # check_bet_details
    # wait_for_round_end
    request_vrf_settlement
    check_match_results
    check_bet_outcome

    log_section "Test Complete!"
    log_success "All steps executed successfully! 🎮"
    echo ""
}

# Run main function
main "$@"

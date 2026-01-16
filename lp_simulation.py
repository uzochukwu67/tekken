"""
LP Risk Analysis for BettingPoolV2_1
Simulates the current implementation to determine LP profitability
"""

import random
import statistics

# Current Implementation Constants
WINNER_SHARE = 0.55  # 55% of losing pool goes to winners
PROTOCOL_CUT = 0.45  # 45% of losing pool to protocol/LP/season
SEASON_POOL_SHARE = 0.02  # 2% of net revenue
LP_SHARE_OF_PROTOCOL = 0.53  # 53% of net revenue (from line 745 comment)
PROTOCOL_SHARE_OF_REVENUE = 0.45  # 45% of net revenue

# Parlay multipliers (linear 1.15x - 1.5x)
PARLAY_MULTIPLIERS = {
    1: 1.0,
    2: 1.15,
    3: 1.194,
    4: 1.238,
    5: 1.281,
    6: 1.325,
    7: 1.369,
    8: 1.413,
    9: 1.456,
    10: 1.5
}

def simulate_single_bet(num_legs, stake=100):
    """
    Simulate a single parlay bet
    Returns: (user_won, base_payout, parlay_payout, protocol_loss)
    """
    # For VRF simulation, each match has 33.33% win chance per outcome
    win_probability = (1/3) ** num_legs

    # Determine if user wins
    user_wins = random.random() < win_probability

    if not user_wins:
        # User loses, stake goes to pool
        return False, 0, 0, 0

    # User wins - calculate payout
    # Base payout from pool mechanics (simplified)
    # Assume average pool odds of ~2.0x per leg after 55% distribution
    base_multiplier = 2.0 ** num_legs  # Approximate base odds
    base_payout = stake * base_multiplier

    # Apply parlay multiplier
    parlay_multiplier = PARLAY_MULTIPLIERS.get(num_legs, 1.5)
    final_payout = base_payout * parlay_multiplier

    # Protocol must cover the parlay bonus from reserve
    parlay_bonus = base_payout * (parlay_multiplier - 1.0)

    return True, base_payout, final_payout, parlay_bonus


def run_simulation(num_rounds=100000, avg_parlay_legs=3):
    """
    Run full economic simulation
    """
    print(f"\n{'='*60}")
    print(f"BETTING POOL V2.1 - LP RISK ANALYSIS")
    print(f"{'='*60}\n")

    print(f"Simulation Parameters:")
    print(f"  - Rounds: {num_rounds:,}")
    print(f"  - Average parlay legs: {avg_parlay_legs}")
    print(f"  - Stake per bet: 100 LEAGUE")
    print(f"  - Parlay multipliers: 1.15x (2 legs) to 1.5x (10 legs)")
    print(f"  - Revenue split: 45% Protocol, 53% LP, 2% Season\n")

    total_user_stakes = 0
    total_user_payouts = 0
    total_protocol_bonus_paid = 0  # Parlay bonuses from reserve
    total_pool_revenue = 0  # Net from losing bets

    user_wins = 0

    for _ in range(num_rounds):
        # Vary parlay legs (weighted toward smaller parlays)
        weights = [5, 15, 20, 18, 15, 10, 8, 5, 3, 1]  # More smaller parlays
        num_legs = random.choices(range(1, 11), weights=weights)[0]

        stake = 100
        total_user_stakes += stake

        won, base_payout, final_payout, protocol_bonus = simulate_single_bet(num_legs, stake)

        if won:
            user_wins += 1
            total_user_payouts += final_payout
            total_protocol_bonus_paid += protocol_bonus
        else:
            # Losing bet goes to pool (becomes revenue to split)
            total_pool_revenue += stake

    # Calculate outcomes
    user_pnl = total_user_payouts - total_user_stakes

    # Net revenue = losing bets - what we paid to winners (base payouts)
    # This is simplified - in reality it's more complex with pool mechanics
    net_revenue = total_pool_revenue - (total_user_payouts - total_protocol_bonus_paid)

    # Split net revenue
    protocol_revenue_share = net_revenue * PROTOCOL_SHARE_OF_REVENUE
    lp_revenue_share = net_revenue * LP_SHARE_OF_PROTOCOL
    season_revenue_share = net_revenue * SEASON_POOL_SHARE

    # LP P&L = revenue share - any shortfalls (if protocol reserve is insufficient)
    # In current implementation, protocol reserve covers parlay bonuses
    lp_pnl = lp_revenue_share
    protocol_pnl = protocol_revenue_share - total_protocol_bonus_paid

    # Results
    print(f"\n{'='*60}")
    print(f"SIMULATION RESULTS")
    print(f"{'='*60}\n")

    print(f"User Statistics:")
    print(f"  - Total staked: {total_user_stakes:,.0f} LEAGUE")
    print(f"  - Total paid out: {total_user_payouts:,.0f} LEAGUE")
    print(f"  - User P&L: {user_pnl:,.0f} LEAGUE ({user_pnl/total_user_stakes*100:.2f}%)")
    print(f"  - Win rate: {user_wins}/{num_rounds} ({user_wins/num_rounds*100:.2f}%)")
    print(f"  - Average payout when winning: {total_user_payouts/max(user_wins,1):,.0f} LEAGUE\n")

    print(f"Protocol Statistics:")
    print(f"  - Net revenue (before bonus): {total_pool_revenue:,.0f} LEAGUE")
    print(f"  - Parlay bonuses paid: {total_protocol_bonus_paid:,.0f} LEAGUE")
    print(f"  - Protocol share: {protocol_revenue_share:,.0f} LEAGUE")
    print(f"  - Protocol P&L: {protocol_pnl:,.0f} LEAGUE\n")

    print(f"LP Statistics:")
    print(f"  - Revenue share: {lp_revenue_share:,.0f} LEAGUE")
    print(f"  - LP P&L: {lp_pnl:,.0f} LEAGUE")
    print(f"  - LP ROI: {lp_pnl/total_user_stakes*100:.2f}% of total volume\n")

    print(f"Season Pool:")
    print(f"  - Season share: {season_revenue_share:,.0f} LEAGUE\n")

    # Risk analysis
    print(f"{'='*60}")
    print(f"RISK ANALYSIS")
    print(f"{'='*60}\n")

    if protocol_pnl < 0:
        print(f"WARNING: Protocol reserve is depleting!")
        print(f"    Reserve loss: {-protocol_pnl:,.0f} LEAGUE")
        print(f"    This is unsustainable long-term.\n")
    else:
        print(f"[OK] Protocol reserve is growing: +{protocol_pnl:,.0f} LEAGUE\n")

    if lp_pnl < 0:
        print(f"[CRITICAL] LPs are losing money!")
        print(f"    LP loss: {lp_pnl:,.0f} LEAGUE")
        print(f"    LPs will withdraw liquidity.\n")
    else:
        print(f"[OK] LPs are profitable: +{lp_pnl:,.0f} LEAGUE\n")

    # Check if protocol reserve can cover worst case
    max_single_bet = 10000  # Assume max bet
    max_parlay = max_single_bet * (2.0 ** 10) * 1.5  # 10-leg max parlay
    reserve_needed = max_parlay * 0.5  # 50% buffer

    print(f"Reserve Requirements:")
    print(f"  - Max theoretical payout: {max_parlay:,.0f} LEAGUE")
    print(f"  - Recommended reserve: {reserve_needed:,.0f} LEAGUE")
    print(f"  - Current circuit breaker: 9,000 LEAGUE (may be too low)\n")

    return {
        'user_pnl': user_pnl,
        'protocol_pnl': protocol_pnl,
        'lp_pnl': lp_pnl,
        'total_protocol_bonus': total_protocol_bonus_paid,
        'user_win_rate': user_wins/num_rounds
    }


if __name__ == "__main__":
    # Run simulation
    results = run_simulation(num_rounds=100000, avg_parlay_legs=3)

    print(f"\n{'='*60}")
    print(f"RECOMMENDATIONS")
    print(f"{'='*60}\n")

    if results['protocol_pnl'] < 0:
        print("1. [CRITICAL] ADD PAYOUT CAPS IMMEDIATELY")
        print("   - Current system has NO maximum payout limit")
        print("   - Protocol reserve will deplete on lucky streaks")
        print("   - Recommend: Cap max payout at 10,000x stake\n")

    if results['lp_pnl'] < results['user_pnl'] * 0.1:  # LPs should earn at least 10% of user losses
        print("2. [WARNING] INCREASE LP SHARE")
        print("   - LPs are not being compensated enough for risk")
        print("   - Consider increasing LP revenue share\n")

    print("3. [RECOMMENDED] IMPLEMENT MAX BET LIMITS")
    print("   - Prevent whale exploitation")
    print("   - Recommended: 10,000 LEAGUE max per bet\n")

    print("4. [RECOMMENDED] ADD PER-ROUND LP LOSS CAP")
    print("   - Cap LP exposure per round")
    print("   - Recommended: LP max loss = 15% of round pool\n")

    print("5. [RECOMMENDED] DYNAMIC MULTIPLIER REDUCTION")
    print("   - Reduce parlay multipliers when reserve is low")
    print("   - Already have circuit breaker at 9,000 LEAGUE\n")

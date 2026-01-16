"""
Whale Attack Simulation - Test extreme scenarios
Simulates what happens if whales exploit the system
"""

import random

def simulate_whale_attack():
    """
    Simulate a whale making large max-leg parlays
    """
    print("\n" + "="*60)
    print("WHALE ATTACK SIMULATION")
    print("="*60 + "\n")

    print("Scenario: Whale places 100 x 10-leg parlays at 10,000 LEAGUE each\n")

    # Constants
    stake_per_bet = 10000  # 10k LEAGUE
    num_bets = 100
    num_legs = 10
    parlay_multiplier = 1.5  # Max multiplier for 10 legs

    # Win probability for 10-leg parlay (each leg 33.33% chance)
    win_prob = (1/3) ** num_legs

    print(f"Parameters:")
    print(f"  - Stake per bet: {stake_per_bet:,} LEAGUE")
    print(f"  - Number of bets: {num_bets}")
    print(f"  - Parlay legs: {num_legs}")
    print(f"  - Parlay multiplier: {parlay_multiplier}x")
    print(f"  - Win probability: {win_prob*100:.6f}%")
    print(f"  - Expected wins: {num_bets * win_prob:.2f}\n")

    total_staked = stake_per_bet * num_bets
    total_won = 0
    num_wins = 0

    # Simulate
    for _ in range(num_bets):
        if random.random() < win_prob:
            # Whale wins
            # Base payout: ~2.0x per leg = 2^10 = 1024x
            base_multiplier = 2.0 ** num_legs
            base_payout = stake_per_bet * base_multiplier

            # Apply parlay multiplier
            final_payout = base_payout * parlay_multiplier

            total_won += final_payout
            num_wins += 1

    # Calculate protocol reserve impact
    parlay_bonus_total = 0
    if num_wins > 0:
        for _ in range(num_wins):
            base_payout = stake_per_bet * (2.0 ** num_legs)
            parlay_bonus = base_payout * (parlay_multiplier - 1.0)
            parlay_bonus_total += parlay_bonus

    print(f"\nResults:")
    print(f"  - Total staked: {total_staked:,} LEAGUE")
    print(f"  - Whale wins: {num_wins}/{num_bets}")
    print(f"  - Total payout: {total_won:,.0f} LEAGUE")
    print(f"  - Parlay bonus from reserve: {parlay_bonus_total:,.0f} LEAGUE")
    print(f"  - Whale profit: {total_won - total_staked:,.0f} LEAGUE\n")

    print(f"Protocol Impact:")
    print(f"  - Reserve depletion: {parlay_bonus_total:,.0f} LEAGUE")
    print(f"  - Circuit breaker threshold: 9,000 LEAGUE")

    if parlay_bonus_total > 9000:
        print(f"  - [CRITICAL] Reserve would be depleted!")
        print(f"  - Shortage: {parlay_bonus_total - 9000:,.0f} LEAGUE")
    else:
        print(f"  - [OK] Within circuit breaker limits")

    return {
        'total_staked': total_staked,
        'total_won': total_won,
        'num_wins': num_wins,
        'parlay_bonus': parlay_bonus_total
    }


def simulate_lucky_streak():
    """
    Simulate an unlikely lucky streak
    """
    print("\n" + "="*60)
    print("LUCKY STREAK SIMULATION")
    print("="*60 + "\n")

    print("Scenario: 10 users each win a 10-leg parlay\n")

    stake = 1000
    num_winners = 10
    num_legs = 10
    parlay_multiplier = 1.5

    base_multiplier = 2.0 ** num_legs
    base_payout = stake * base_multiplier
    final_payout = base_payout * parlay_multiplier
    parlay_bonus = base_payout * (parlay_multiplier - 1.0)

    total_payout = final_payout * num_winners
    total_bonus = parlay_bonus * num_winners

    print(f"Per winner:")
    print(f"  - Stake: {stake:,} LEAGUE")
    print(f"  - Base payout: {base_payout:,.0f} LEAGUE")
    print(f"  - Final payout: {final_payout:,.0f} LEAGUE")
    print(f"  - Parlay bonus: {parlay_bonus:,.0f} LEAGUE\n")

    print(f"Total impact:")
    print(f"  - Total paid: {total_payout:,.0f} LEAGUE")
    print(f"  - Reserve depletion: {total_bonus:,.0f} LEAGUE")
    print(f"  - Circuit breaker: 9,000 LEAGUE\n")

    if total_bonus > 9000:
        print(f"[CRITICAL] Reserve depleted by {total_bonus - 9000:,.0f} LEAGUE!")
    else:
        print(f"[OK] Within limits")

    return total_bonus


def test_max_single_bet():
    """
    Test maximum possible single bet payout
    """
    print("\n" + "="*60)
    print("MAX SINGLE BET PAYOUT")
    print("="*60 + "\n")

    max_stake = 50000  # Assume some max
    num_legs = 10
    parlay_multiplier = 1.5

    base_multiplier = 2.0 ** num_legs
    base_payout = max_stake * base_multiplier
    final_payout = base_payout * parlay_multiplier
    parlay_bonus = base_payout * (parlay_multiplier - 1.0)

    print(f"Maximum single bet:")
    print(f"  - Stake: {max_stake:,} LEAGUE")
    print(f"  - Legs: {num_legs}")
    print(f"  - Base payout: {base_payout:,.0f} LEAGUE")
    print(f"  - Final payout: {final_payout:,.0f} LEAGUE")
    print(f"  - Parlay bonus needed: {parlay_bonus:,.0f} LEAGUE\n")

    print(f"Current system:")
    print(f"  - Protocol reserve circuit breaker: 9,000 LEAGUE")
    print(f"  - This bet requires: {parlay_bonus:,.0f} LEAGUE")

    if parlay_bonus > 9000:
        print(f"  - [CRITICAL] Single bet could deplete reserve!")
        print(f"  - Shortfall: {parlay_bonus - 9000:,.0f} LEAGUE\n")
    else:
        print(f"  - [OK] Within limits\n")

    return parlay_bonus


if __name__ == "__main__":
    # Run simulations
    whale_results = simulate_whale_attack()
    lucky_streak_bonus = simulate_lucky_streak()
    max_bet_bonus = test_max_single_bet()

    # Final recommendations
    print("\n" + "="*60)
    print("FINAL RISK ASSESSMENT")
    print("="*60 + "\n")

    print("Current System Status:")
    print("  - Protocol Reserve: Growing (+2.8M LEAGUE in 100k rounds)")
    print("  - LP Profitability: Healthy (+3.8M LEAGUE in 100k rounds)")
    print("  - Circuit Breaker: 9,000 LEAGUE minimum\n")

    print("Critical Vulnerabilities:")
    print("  1. [HIGH RISK] No maximum bet limit")
    print("     - Single whale bet can require 50M+ LEAGUE reserve")
    print("     - Recommendation: Cap at 10,000 LEAGUE per bet\n")

    print("  2. [MEDIUM RISK] No maximum payout cap")
    print("     - 10-leg parlay can pay 1,500,000+ LEAGUE")
    print("     - Recommendation: Cap max payout at 100,000 LEAGUE\n")

    print("  3. [LOW RISK] Circuit breaker may be insufficient")
    print("     - Current: 9,000 LEAGUE")
    print("     - Recommended: Scale with locked reserves (dynamic)\n")

    print("DO YOU NEED CAPS? YES!")
    print("\nRequired protections:")
    print("  1. Max bet size: 10,000 LEAGUE")
    print("  2. Max payout: 100,000 LEAGUE (10x max bet)")
    print("  3. Dynamic circuit breaker: min(9000, lockedReserve * 0.1)")
    print("  4. Per-round max payouts: 20% of round pool")

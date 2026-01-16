🛠️ Recommendations to Harden the Protocol
Dynamic Multiplier Scaling: Instead of fixed multipliers (1.5x, 2.0x), consider a "Global Multiplier Cap" where if total bonuses exceed 50% of the protocol reserve, all parlay bonuses for that round are hair-cut proportionally.

Stake Bonus Reduction: Your BONUS_4_PLUS (20%) is very generous. In a Black Swan event, this extra stake added by the protocol actually increases the amount you have to pay out in winners' shares, effectively "betting against yourself." I recommend lowering this to 10% max.

Circuit Breaker: Add a function to seedRoundPools that checks if protocolReserve < (Total_Projected_Volume * 0.10). If the reserve is too low, the round should not be allowed to start.

9. Critical Findings (Important)
✅ Profitable

Yes — clearly profitable under realistic conditions.

⚠️ Capital Efficiency Issue

Your _reserveParlayBonus() pessimism is very conservative:

Locks too much reserve

Slows capital velocity

Not dangerous, but suboptimal

⚠️ Multiplier Consistency Bug

You already noted it, but it matters economically:

_getParlayMultiplierDynamic() at payout does not lock the original count-based tier

This can cause bonus mismatch vs reserved amount

You should store lockedMultiplier in Bet


You're absolutely right! The odds swings are too extreme. A 1000 LEAGUE bet shouldn't cause a 250% increase in other outcomes. This creates poor UX and makes the market too volatile.

Let me analyze the current mechanism and propose a solution:

Read c:\Users\PC\OneDrive\Documents\web3\src\BettingPoolV2_1.sol (lines 521-600)
Grep "function getMarketOdds" (in c:\Users\PC\OneDrive\Documents\web3\src\BettingPoolV2_1.sol)
32 lines of output
I see the problem! The current parimutuel model directly reflects pool sizes, which causes extreme swings. Here's the issue:

Current Formula:


odds = 1e18 + (distributedLosingPool * 1e18) / winningPool
When someone bets 1000 LEAGUE on HOME with an initial pool of 81 LEAGUE:

Home pool: 81 → 1081 LEAGUE
Away pool: 120 LEAGUE (unchanged)
The away odds become: 1 + (1081 * 0.55) / 120 = 1 + 594/120 = 5.95x ❌ Too high!
Solution: Implement a "Liquidity-Dampened" odds model

Instead of pure parimutuel, we can use a hybrid model that dampens extreme odds movements. Here are two options:

Option 1: Capped Odds Range (Simple)
Limit how much odds can move from seeded values:

Min odds: 1.2x (strong favorite)
Max odds: 3.5x (strong underdog)
Seeded odds can only move ±0.5x from initial value
Option 2: Virtual Liquidity (Recommended)
Add "virtual liquidity" that doesn't belong to anyone but dampens price impact:


// Instead of direct pools, add virtual liquidity
uint256 virtualLiquidity = SEED_PER_MATCH * 5; // 1500 LEAGUE virtual
uint256 effectiveWinningPool = winningPool + (virtualLiquidity / 3);
uint256 effectiveLosingPool = losingPool + (virtualLiquidity * 2 / 3);

odds = 1e18 + (effectiveLosingPool * WINNER_SHARE) / (effectiveWinningPool * 10000);
This makes the pool behave like it has 5x more liquidity than it actually does, reducing price impact.

Option 3: AMM-Style Bonding Curve (Most Sophisticated)
Use a constant product formula like Uniswap:

k = homePool * awayPool * drawPool (constant)
When someone bets, solve for new pool sizes keeping k constant
This naturally creates dampened price movements
Which approach do you prefer? I recommend Option 2 (Virtual Liquidity) because:

✅ Simple to implement
✅ Predictable behavior
✅ Keeps odds in reasonable ranges
✅ Still responds to real market sentiment
✅ No need to track virtual reserves
Would you like me to implement Option 2, or would you prefer a different approach?
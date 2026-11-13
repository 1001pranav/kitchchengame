# 06 — Economy and Balance

The numbers in docs 02 and 04 are **starting values chosen by estimate, not by play**.
This document says what the economy is supposed to feel like, gives the estimates behind
the numbers, and defines how to tune them with an automated bot before any human plays.

---

## 1. Scale of money

| Thing | Typical size (coins) |
|---|---|
| Ingredient unit | 0.2 – 3.6 |
| Dish price | 2 (drink) – 28 (premium main); typical main 14–20 |
| Spend per person | ~23 |
| Spend per group (avg 2.4 people) | ~55 |
| Daily wage per staff member | 80 – 260 |
| Weekly rent | 1,800 – 5,200 |
| Equipment unit | 800 – 6,000 |
| Restaurant purchase | 30,000 – 300,000 |

## 2. Target cost structure (healthy restaurant, % of revenue)

| Line | Target |
|---|---|
| Ingredients (incl. waste) | 30–35% |
| Wages | 28–32% |
| Rent | 10–14% |
| Utilities | 4–6% |
| Maintenance, repairs, marketing, licences | 3–5% |
| **Operating profit** | **12–20%** |

This is deliberately 3–4× real-world margins (see the realism stance in doc 01).

## 3. Estimated unit economics by tier (Normal difficulty, week 1, no player action)

| | Excellent | Best | Good | Bad | Worst |
|---|---|---|---|---|---|
| Groups / day | ~117 | ~81 | ~56 | ~35 | ~19 |
| Revenue / week | ~45,000 | ~31,000 | ~21,500 | ~13,500 | ~7,300 |
| Ingredients | 14,500 | 10,000 | 7,000 | 4,700 | 2,900 |
| Wages | 12,000 | 8,700 | 6,000 | 4,300 | 3,000 |
| Rent | 5,200 | 3,800 | 2,800 | 2,000 | 2,200 |
| Utilities + other | 3,300 | 2,400 | 1,800 | 1,400 | 1,100 |
| Operating profit / week | ~10,000 | ~6,100 | ~3,900 | ~1,100 | ~−1,900 |
| Loan instalment (first week) | ~5,100 | ~3,250 | ~1,630 | 0 | 0 |
| **Net cash / week** | **~+4,900** | **~+2,850** | **~+2,270** | **~+1,100** | **~−1,900** |

Groups/day = BASE_FOOTFALL × repFactor (other factors ≈ 1 on average).
These are estimates; the first job of Phase 0 is to measure them (§6) and correct either
the table or the constants.

### Intended feel per tier

| Tier | First 4 weeks | Main threat |
|---|---|---|
| Excellent | Profitable from day 1; almost no cash buffer | One bad week (inspection closure, chef quits) → missed instalment |
| Best | Profitable; first equipment replacement by week 6 | Loan + a 5,000 repair bill arriving together |
| Good | Slightly profitable; two hidden problems bite in weeks 2–4 | Death by several small problems |
| Bad | Break-even at best; staff churn | Low reputation keeps demand low; must invest cash to climb |
| Worst | Loses ~2,000/week before hidden problems; 70,000 cash looks like a lot and is not | Supplier debt (week 2–4) + dead equipment + reputation 1.5; must restructure fast |

## 4. Balance targets (acceptance bands)

Measured by the balance bot over **200 seeds × 26 weeks** per tier on Normal.

| Metric | Excellent | Best | Good | Bad | Worst |
|---|---|---|---|---|---|
| Survival to week 26, *passive* bot | 85–95% | 75–90% | 60–80% | 25–45% | 0–10% |
| Survival to week 26, *competent* bot | ≥ 98% | ≥ 95% | ≥ 92% | 70–85% | 40–60% |
| Median week reaching Stage 2, competent bot | 5–7 | 6–9 | 8–12 | 14–20 | 20–26+ |
| Median week reaching Stage 3 thresholds | 16–24 | 20–28 | 24–34 | 36–50 | 45–60 |

General targets (all tiers, competent bot):

| Metric | Target |
|---|---|
| Food cost % | 28–36% |
| Waste as % of ingredient spend | 3–8% |
| Walk-out rate | 3–10% of groups on a normal day; 15–30% when one key role is absent and the owner does not cover |
| Owner covering the absent role cuts that walk-out rate by | at least half |
| Incidents per week | 3–6 |
| Staff turnover | 1 leaver per 6–10 weeks at morale ≈ 55 |
| Equipment breakdowns | 1 per 3–5 weeks at condition ≈ 55 with no maintenance; < 1 per 12 weeks with weekly maintenance |
| Days where cash decision matters (cash < 1 week of costs) | 20–40% of days in the first 8 weeks for Good tier |

Difficulty: Easy should lift every survival figure by roughly 10 points, Hard lower by 10–15.

## 5. Tuning levers (in order of preference)

Change as few constants as possible, in this order:

1. `BASE_FOOTFALL` and rent per location class — moves revenue and fixed costs.
2. Tier parameters (price, loan, cash left, hidden problem count).
3. `FOOD_COST_TARGET` per course — moves margin directly.
4. Wages table.
5. Patience and task durations — moves walk-outs and the value of staff/owner work.
6. `REP_UP` / `REP_DOWN` — speed of recovery and collapse.
7. Incident weights and costs.
8. Loan rate and term.

Never tune by adding special cases in code. If a formula must change, change doc 02 first.

## 6. The balance bot (Phase 0 deliverable)

A command-line tool: `dart run tool/balance.dart --tier good --seeds 200 --weeks 26 --bot competent`.
It runs the real simulation headlessly with a scripted player and prints a CSV plus a
summary table of the §4 metrics with PASS/FAIL per band.

### 6.1 Bot policies

**Passive bot** — the "player who does nothing clever":
- Rota: default. Orders: each close, top up every menu ingredient to 1.5 × yesterday's use from `sup_standard`.
- Incidents: always the default option. Never maintains, hires, trains or changes prices.
- Owner: no floor work.

**Competent bot** — a sensible but not optimal player:
- Orders: par = 1.3 × trailing-7-day average use (chilled), 3 × (dry/frozen); cheapest supplier with reliability ≥ 0.9.
- Maintenance: any unit with condition < 65, once a week. Repairs: proper repair if cash > 4 weeks of costs, else cheap.
- Staff: replaces leavers from applicants (highest skill per wage); gives a 5% raise when morale < 45; rests anyone with fatigue > 75.
- Menu: 86 any dish with food cost > 45%; sets all prices to 105% of base.
- Incidents: picks the option with the best expected value using a simple fixed scoring
  (cash + 20,000 × reputation delta + 50 × morale delta summed), never spending below 1 week of costs.
- Owner: covers the role with the longest task queue whenever energy > 30.
- Loans: takes a loan only via lifeline.

### 6.2 Output per run

Per week: revenue, each cost line, operating profit, cash, reputation, hygiene, groups,
walk-out %, waste %, incidents, leavers, breakdowns, owner ticks worked. Per seed:
survived?, week of bankruptcy, weeks to each stage.

### 6.3 Tuning loop

1. Run bot for all tiers. 2. Compare with §4 bands. 3. Change **one** lever in
`balance.json`. 4. Re-run. 5. Record the change and before/after figures in
`docs/balance-log.md` (date, constant, old → new, reason, effect). 6. Repeat until all
bands pass, then update the tables in §3.

## 7. Known weak spots to check first

- **Kitchen throughput at peak.** `COOK_PARALLEL`, station slots and `prepTicks` together
  decide whether Friday dinner is "tense" or "impossible". Check walk-out rate by hour.
- **Storage capacity vs daily use.** A Good-tier restaurant uses roughly 500–600 chilled
  units per day against 1,000 capacity; daily ordering is intended. If the bot is forced
  to over-order to meet supplier minimums, lower minimums.
- **Worst tier runway.** 70,000 cash must not allow 30 weeks of passive survival; if it
  does, raise inherited debt, not weekly losses.
- **Owner floor work value.** If covering a role barely changes walk-outs, the feature is
  pointless; if it fixes everything, hiring is pointless. Target is in §4.
- **Snowballing.** Reputation → demand → revenue → reputation. Confirm the competent bot's
  reputation plateaus around 4.2–4.6 rather than hitting 5.0, and that a drop to 2.0 is recoverable in 8–12 weeks.

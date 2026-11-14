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
**Status of this table:** hand estimates, not yet corrected. A first prototype run
(§3a) measured Good-tier revenue about 10% below the figure here at the original
footfall, because the estimate ignored walk-outs and fading buzz. Average-location
footfall was raised 50 → 55 to restore the intended ~4,000 a week, and 55 → 58 when
incidents and hidden problems were added (balance-log entry 9: they cost a competent
owner about 0.9k a week at 55); the other tiers have not been measured. "Operating profit" excludes all loan money (doc 02 §14.2).

These are estimates; the first job of Phase 0 is to measure them (§6) and correct either
the table or the constants.

### Intended feel per tier

| Tier | First 4 weeks | Main threat |
|---|---|---|
| Excellent | Profitable from day 1; almost no cash buffer | One bad week (inspection closure, chef quits) → missed instalment |
| Best | Profitable; first equipment replacement by week 6 | Loan + a 5,000 repair bill arriving together |
| Good | Slightly profitable (measured +2.2k a week in weeks 1–4, +3.5–3.8k after: the handover month, doc 02 §15.9); two hidden problems bite in weeks 2–4 | Death by several small problems |
| Bad | Break-even at best; staff churn | Low reputation keeps demand low; must invest cash to climb |
| Worst | Loses ~2,000/week before hidden problems; 70,000 cash looks like a lot and is not | Supplier debt (week 2–4) + dead equipment + reputation 1.5; must restructure fast |

## 3a. First measurements (economy-loop prototype)

A throwaway day-resolution prototype (`prototype/economy_loop/`) was run for 200 seeds ×
26 weeks on a Good-tier outlet in an average location. It replaces the per-tick service
with stand-in aggregates, so treat these as **first evidence, to be re-measured by the
real balance bot (task 0.21)**. Full output: `prototype/economy_loop/results.txt`.
History of changes: `docs/balance-log.md`.

Average weekly **net profit** (after the manager's wage and loan interest), by who runs
the outlet:

| Run by | Owner never markets or visits | Owner markets, never visits | Owner markets + visits weekly |
|---|---|---|---|
| Owner, no manager | −3.4k (passive) · +0.8k (chores) | — | +3.6k (weeks 1–4: +2.2k) |
| Trainee | −3.9k | −2.4k | −1.1k |
| Junior | −2.9k | −1.3k | −0.3k |
| Capable | −1.9k | −0.3k | +0.6k |
| Senior | −1.3k | +0.5k | +1.3k |
| Veteran | −0.9k | +1.2k | +1.7k |

(Balance-log entry 10: with incidents, hidden problems and the handover month, footfall 58. "Passive" is doc
06 §6.1's bot, which also stops maintaining, repairing and covering; "chores" works the
floor but never answers a card or markets — see §6.1. Inherited supplier debt is cash,
not profit, so it is not in these figures.)

Senior, markets-but-never-visits, over time: −0.4k (weeks 1–4, the handover month),
+0.4k (weeks 9–12). Veteran: +0.1k, +1.3k.

What this confirms: grade and owner attention both matter; an experienced manager keeps
a sound outlet out of loss for months; a cheap one loses money unless the owner is
there; nobody survives an owner who does nothing.

The test outlet carries the 70,000 starting loan (about 280 a week in interest at the
start). A second outlet bought from company cash would show slightly better figures.

## 4. Balance targets (acceptance bands)

Measured by the balance bot over **200 seeds × 26 weeks** per tier on Normal.

| Metric | Excellent | Best | Good | Bad | Worst |
|---|---|---|---|---|---|
| Survival to week 26, *chores* bot (works the floor, never manages)¹ | 85–95% | 75–90% | 60–80% | 25–45% | 0–10% |
| Survival to week 26, *passive* bot (doc 06 §6.1: does nothing at all)¹ | to measure | to measure | 0–10% | 0% | 0% |
| Survival to week 26, *competent* bot | ≥ 98% | ≥ 95% | ≥ 92% | 70–85% | 40–60% |
| Median week reaching Stage 2, competent bot | 5–7 | 6–9 | 8–12 | 14–20 | 20–26+ |
| Median week reaching Stage 3 thresholds | 16–24 | 20–28 | 24–34 | 36–50 | 45–60 |

¹ **Restated in balance-log entry 9.** The band used to sit on the passive bot. The
prototype's 100% for it was an artefact: being at the outlet silently gave it
maintenance, proper repairs and absence cover, three things §6.1 says it never does.
With §6.1 applied and no incidents at all, a passive Good outlet survives 0% of runs
(nothing it breaks is ever repaired; with incidents it is bankrupt by week 7). So the band was
moved to the player it was written for — one who turns up and does the chores but
never manages — and the passive bot became a floor check. Measured (prototype, Good,
incidents, hidden problems and the handover month on, entry 10): chores **65%**,
passive **0%**, competent **100%**. What decides a chores run is which hidden problems
it inherited: 73–87% survive the mild ones, 50% a supplier debt, 45% an early health
violation, 0% inherited pests (never treated).

General targets (all tiers, competent bot):

| Metric | Target |
|---|---|
| Food cost % | 28–36% |
| Waste as % of ingredient spend | 3–8% |
| Walk-out rate | 3–10% of groups on a normal day; 15–30% when one key role is absent and the owner does not cover |
| Owner covering the absent role cuts that walk-out rate by | at least half |
| Incidents per week | 3–6 (prototype: 2.1–2.3, but it models only prep/close incidents and none of the per-tick service ones; passive bot 3.8) |
| Campaign outcomes over many runs | flop 10–18%, big hit 5–14%, average multiplier 0.95–1.2 (measured: flop 9–13%, lowest for owners who keep the menu fresh — the fresh-menu bonus only started working after the seed fix, see balance-log entry 9; big hit 9–13%) |
| Cost of ad uncertainty to a steady advertiser | under 5% of weekly profit on average (measured ≈ −0.1k) |
| Average return on spend of a campaign (extra profit ÷ spend) | ×1.5 to ×3; a weak response should roughly break even (measured ×2.2 local ad, ×2.8 flyers; weak ×1.1 / ×1.3 — balance-log entry 9) |
| Marketing as a share of revenue, competent bot | 2–4% (measured 3.6–4.0%) |
| Gain from switching channel after a bad ad, versus repeating the same ad | +0.1k to +0.4k a week (measured +0.1k to +0.3k in entry 9; Trainee is just under) |
| Staff turnover | 1 leaver per 6–10 weeks at outlet happiness ≈ 55 (8-staff outlet) |
| Share of leavers who go without notice (competent bot) | Easy 5–10%, Normal 15–25%, Hard 30–45% |
| Outlet happiness, competent bot, steady state | 55–70; passive bot drifts to 35–45 by week 12 |
| Equipment breakdowns | 1 per 3–5 weeks at condition ≈ 55 with no maintenance; < 1 per 12 weeks with weekly maintenance |
| Cash squeeze, Good tier, competent bot: runs whose cash falls below 1 week of costs at some point in weeks 1–8 | 10–30% of runs (measured 14%; chores bot 41%, passive 100%). **Restated in balance-log entry 10** from "20–40% of days": cash refills within days of any profit and the bot never spends below one week of costs, so a daily share above ~9% was only reachable by also breaking the ≥ 92% and 60–80% survival bands. The band was set around the measured value: the intent is "some good runs feel the squeeze, most don't" |

Manager targets (Phase 2; a Good-tier outlet in an average location, owner never visits, default standing orders):

| Metric | Target |
|---|---|
| Manager sub-skills all 80: weeks with negative operating profit | ≤ 1 in 8 over weeks 5–12 (the handover month, doc 02 §15.9, is not the manager's); ≤ 1 in 3 over weeks 13–26. **Measured 13.9% (just fails) and 20.0%**, Veteran grade, prototype, balance-log entry 10. History: entry 6 split the old single "≤ 1 in 8 over 26 weeks" because of the seed bug; incidents keep the split necessary (entry 9). |
| Manager sub-skills all 80: still profitable on average after 12 weeks unvisited | yes |
| Manager sub-skills all 35: first 4-week period with negative total profit | within weeks 3–8 |
| Weekly profit gap between the two (after their wage difference) | 1,000 – 2,500 in favour of the experienced manager (the outlet's whole profit is ~4,000, so the earlier 1,500–4,000 band was impossible) |
| Share of that gap visible in "Manager's decisions" report lines | ≥ 70% |
| Day-to-day swing of an outlet's profit (std. dev. / mean) | 40–80%; at least 1 losing day per week even when the week is profitable |
| Excellent manager in a poor location with overpriced rent | still loses money (structural) |
| Each grade step up (Trainee → Junior → Capable → Senior → Veteran), weekly profit gain after the extra wage | +200 to +1,000 per step; never negative (measured +825, +882, +659, +419; owner never visits: **+1,031, +1,004** (just over), +816, +674 — balance-log entry 10) |
| Same-grade managers, matching vs mismatched profile for the outlet's main problem | 300–900 per week difference |
| Trainee with potential ≥ 75, coached weekly | reaches Capable in 20–30 weeks |

Opening-route targets (Phase 2; competent bot, average location, medium size):

| Metric | Buy running (Good tier) | From scratch (standard fit-out, new equipment) | From scratch (basic, second-hand/leased) |
|---|---|---|---|
| Cash needed up front | ~60,000 (doc 02 §15.9 later-market price) | 45,000–60,000 | 20,000–30,000 |
| Weeks to first profitable week | 1–3 | 6–10 | 8–14 |
| Weeks to pay back the investment | 30–45 (was 35–50; restated in balance-log entry 8) | 30–45 | 25–45, with wider spread |
| Chance the outlet is in crisis within 26 weeks | 10–20% | 15–25% | 25–40% |

Neither route should dominate: buying is safer and faster, scratch is cheaper and slower.
"Dominate" is judged on four numbers together, not payback alone (payback flatters
leasing, whose fee is a running cost): weeks to first profit, most company cash tied up
(up front + the deepest dip in running profit), net position at week 52 and at week 104.

Measured (prototype, `bots` "Opening routes" table, balance-log entry 10; company cash,
no loan, owner visits weekly and fixes a weak head chef and unserviceable kit on day one
— the `refit` bot; incidents, two hidden problems per takeover and the handover month
modelled, due diligence is not):

| Senior manager | Up front | Most cash tied up | First profit wk | Payback wk | Crisis by wk 26 | Net wk 52 | Net wk 104 |
|---|---|---|---|---|---|---|---|
| Buy running (60,000) | 60.0k | 73.3k | 2 | 35 | 8% | +55.3k | +181k |
| Standard + new | 58.5k | 77.1k | 8 | 35 | 0.5% | +57.6k | +208k |
| Basic + second-hand | 36.9k | 56.5k | 7 | 30 | 1% | +68.9k | +182k |
| Basic + leased | 22.2k | 44.2k | 7 | 30 | 1% | +65.4k | +189k |

Veteran payback 31 / 31 / 25 / 23.

Status: **buying is the fast, risky route.** It earns six weeks sooner and is within
2–14k of the others at week 52, level with basic + second-hand at week 104 and 27k
behind standard + new. It is now the riskiest route (crisis 8% vs 0.5–1%), the
opposite of "buying is safer": hidden problems and the handover month land in the same
weeks. At × 0.5 it was behind everywhere (+40.3k / +166k). If buying should also be the
safer route, the lever is due diligence (not modelled), not the price.

Other gaps against the bands: up-front cash for basic + second-hand is 36.9k (25.7k
without the deposit) against 20–30k, so the band only holds if it excludes the 4-week
deposit (11.2k). Crisis for the scratch routes (0–1% with refit; up to 9.5%, or 22.5% for
basic + leased with a Capable manager, without) is mostly below 15–40%; those bands were guesses and need the real bot with incidents.

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

**Passive bot** — the player who does nothing at all (a floor check, not a target player):
- Rota: default. Orders: each close, top up every menu ingredient to 1.5 × yesterday's use from `sup_standard`.
- Incidents: always the default option (so a breakdown stays broken, doc 05 #21). Never maintains, hires, trains or changes prices.
- Owner: no floor work.

**Chores bot** — the "player who does nothing clever": turns up and keeps the lights on,
never manages (added in balance-log entry 9; carries the §4 survival band):
- As passive, except: maintains any unit below the threshold each week, pays for the
  cheap repair when something breaks, covers one absent role on the floor, and replaces
  leavers.
- Every other incident card: default. Never markets, reworks the menu, replaces ageing
  equipment or trains.

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

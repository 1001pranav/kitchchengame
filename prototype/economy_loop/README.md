# Economy loop prototype (throwaway)

A headless, pure-Dart test of the core money loop **before** any of Phase 0 is built:
one Good-tier outlet, one manager whose grade drives their daily decisions, daily
variable income against weekly/monthly fixed costs, and demand that fades unless the
owner markets and refreshes the menu.

This is **not** `packages/sim_core`. It breaks doc 09's order on purpose (managers are
Phase 2, and Phase 0 has a tuning gate before any play). Delete it once 0.21's balance
bot exists; keep the findings.

## Run it

Needs Dart ≥ 3.5 (no Flutter).

```
dart pub get
dart run bin/play.dart --seed 7                                     # spec numbers
dart run bin/play.dart --seed 7 --balance data/balance-proposal.json # proposed tuning
dart run bin/bots.dart --seeds 200 --weeks 26                       # scripted owners × every grade
dart run bin/bots.dart --set BUZZ_DECAY=0.01 --set BASE_FOOTFALL=55  # try a lever
dart test
```

In `play`, press Enter to play a day, `week` to play to Sunday, `help` for owner commands
(price, flyers, ad, promo, rework, visit, replace, managers/hire, repay).

## What is modelled, and from where

| Thing | Source |
|---|---|
| Groups/day: footfall × rep × price × weekday × season × marketing × buzz × freshness × competition × noise | doc 02 §5.1, doc 11 §A.1–A.5 |
| Reputation update, satisfaction weights, value score | doc 02 §6.8 |
| Crew wages, reliability, absences, happiness target, quitting | doc 02 §7, doc 04 §6 |
| Equipment wear, breakdown, maintenance, cheap/proper repair, ageing max condition | doc 02 §10, doc 04 §3, doc 11 §A.3 |
| Hygiene and inspections | doc 02 §12 |
| Campaigns, buzz, menu rework | doc 02 §13, doc 11 §A.1–A.2 |
| Rent, payroll, loan instalment, utilities, tax, licence, bankruptcy | doc 02 §14 (no lifeline, no new loans) |
| Manager sub-skills, grade, profile, wage curve, potential, learning, coaching, neglect slack, rota errors, absence cover, ordering error, maintenance skipping, cheap repairs, early warnings, attribution | doc 02 §15.5, §15.12, §15.14, doc 11 Part B |
| Break-even line | doc 02 §15.13 |

### Stand-ins (`PROTO_*` in balance.json)

There is no per-tick service, so these replace it. Each is a guess, flagged in code.

| Key | Value | Replaces |
|---|---|---|
| `PROTO_SPEND_PER_GROUP` | 55 | menu + group size (doc 06 §1) |
| `PROTO_FOOD_COST` / `PROTO_BASE_WASTE` | 0.325 / 0.05 | per-dish recipe cost (doc 06 §2) |
| `PROTO_TABLE_TURNS` | 6 | tables × patience at peak |
| `PROTO_WALKOUT_BASE` / `_PER_GAP` | 0.05 / 0.15 | doc 06 §4 walk-out targets (3–10% normal, 15–30% one role missing) |
| `PROTO_FOOD_BASE`, `PROTO_WAIT_*` | | food and wait scores in doc 02 §6.8 |
| `PROTO_MENU_LOSS_*` | | sold-out / 86'd dishes |
| `PROTO_OWNER_VISITS_PER_WEEK` | 2 | the cost of the owner's time (there is only one outlet to be at) |

A role with two people (servers) counts half a gap when one is missing.
Calibration check: with the owner running the outlet every day and no manager
("OWNER-RUN" rows), survival is 70% passive / 100% competent, against doc 06 §4's
Good-tier bands of 60–80% / ≥ 92%. So the stand-ins don't push results one way.

## Results (200 seeds × 26 weeks, Good tier, average location)

Full tables: `results-spec.txt`, `results-proposal.txt`. "competent" owner = doc 11 §A.6:
local ad every 4 weeks, menu rework every 8, prices 105%, one visit a week, replaces
equipment the manager flags. "passive" owner does nothing and never visits.

**With the spec's numbers, every managed outlet goes bankrupt**, at every grade, with
either owner (0% survival; week 5–13). Weekly operating profit, weeks 1–4, competent owner:

| Trainee | Junior | Capable | Senior | Veteran | Owner-run, no manager |
|---|---|---|---|---|---|
| −1.9k | −1.5k | −1.1k | −0.7k | −0.3k | +2.8k |

**With `balance-proposal.json`** (three levers, below), competent owner, survival to week 26:

| Trainee | Junior | Capable | Senior | Veteran | Owner-run |
|---|---|---|---|---|---|
| 5% | 26% | 68% | 97% | 100% | 100% (+4.3k/wk, close to doc 06's 3.9k) |

A passive owner still loses every managed outlet by week 8–12. To my eye that curve is
the interesting game: the grade you hire and whether you show up both decide whether you survive.

## Design problems found in the docs

Ordered by how much they matter. Numbers are from the runs above.

1. **A Good-tier outlet can't pay for a manager.** Doc 06 §3 estimates operating profit
   at ~3,900/week. A manager costs 1,330 (Trainee) to 2,600 (Veteran) a week on top of a
   full crew (§15.14 curve). That's 35–65% of the profit before the manager makes a single
   mistake. Meanwhile doc 06's manager targets ask for a 1,500–4,000/week gap between a
   skill-80 and a skill-35 manager, and that gap is the outlet's whole profit. The two
   docs can't both be true. Either outlets need much fatter margins once you have
   managers, or the manager takes a crew slot (e.g. covers the cashier) rather than
   adding a wage.
2. **Doc 06 §3 overstates revenue by about 10%.** It ignores walk-outs and the fact
   that buzz starts at 0.5 and hits 0 by about day 25, which costs −8% of demand.
   Measured owner-run Good tier: ~19k/week, not 21.5k. At these margins (operating
   leverage of about 3×), 10% of revenue is 40–60% of profit.
3. **Doc 11 §A.6's own claim fails.** "One local ad per 4 weeks + a rework per 8
   holds demand within ±5%." Buzz decays 0.56 per 28 days, and an ad gives +0.25,
   so buzz sits near 0. Measured: −10% vs neutral (passive −14%, in band). Either
   `BUZZ_DECAY` is 0.01 or the bot needs about 2 ads a month (~3,000, which is 15%
   of revenue, way over the 2–4% target).
4. **Absence rate is way too high for single-holder roles.** Reliability is tier morale ±20
   (doc 04 §6), so Good-tier staff are absent `(100−55)/400 ≈ 11%` of days. With 8 staff
   that's 0.9 absences a day, and each uncovered one costs 15–30% walk-outs (doc 06 target).
   In Phase 1 the owner covers it with floor work. Under a manager it's the biggest
   single cost line. Real-world ~3–5% suggests a divisor of ~1,000.
5. **The default rota leaves roles empty.** Doc 04 §6: "everyone works 6 days, day off
   round-robin Mon–Thu". With one head chef / cook / dishwasher / cashier / cleaner,
   some role is empty every Mon–Thu by design. Phase 1 hides it (the owner covers);
   doc 02 §15.2 has the manager do the rota with no relief staff. Needs a rule: a
   relief/part-time pool, or doubled roles at Good tier and above. (This prototype
   averages it out with a 6/7 wage bill.)
6. **Neglect makes unvisited outlets fail regardless of grade.** `slack` reaches its 0.30
   cap about 3 weeks after the grace period, and `absence + slack/5` then adds +6
   points of absence per person per day. Doc 02 §15.14 promises "Senior: reliably
   profitable 8–12 weeks unvisited" and "Veteran: profitable until buzz fades". Measured
   (proposal tuning, passive): Senior +0.5k in weeks 1–4, then −2.8k by weeks 9–12. Neglect
   and buzz both punish absence, and they pile up on each other.
7. **Grade steps are too flat to be a decision.** Target is +400 to +1,200/week net per grade.
   Measured with the proposal: +300 to +450. The wage curve eats most of the skill gain.
8. **Smaller ones.**
   - Doc 02 §14.2 counts interest inside operating profit; doc 06 §3 puts the whole
     instalment below it. I followed doc 02.
   - Doc 02 §15.12 adds a daily morale modifier from manager *people* on top of the
     happiness Boss factor from the same skill, so it's counted twice (kept, marked
     `SPEC-GAP`).
   - Hygiene sits at 100 with one average cleaner (+12 vs −8.4 a day), so inspections
     are never a threat at Good tier.
   - A turned-away group scores satisfaction 10 (doc 02 §6.8), so an ad that pushes
     demand past capacity *lowers* reputation. Maybe intended, but it will feel like a bug to players.
   - Senior/Veteran applicant weights at reputation 3.5 are 10/0, so a Good-tier
     owner can never be offered a Veteran.

## Proposed tuning (`data/balance-proposal.json`)

Following doc 06 §5's lever order, three changes:

| Constant | Spec → proposal | Why |
|---|---|---|
| `BASE_FOOTFALL` (average) | 50 → 55 | Owner-run Good tier then earns ~4.3k/week, matching doc 06 §3's intent |
| `BUZZ_DECAY` | 0.02 → 0.01 | Makes doc 11 §A.6 true (competent owner holds demand at −3%) |
| absence divisor (doc 02 §7.4) | 400 → 1,000 | ~4.5% absence/day, real-world range |

Problems 1, 5, 6 and 7 still need design decisions, not constants.

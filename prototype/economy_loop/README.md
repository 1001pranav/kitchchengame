# Economy loop prototype (throwaway)

A headless, pure-Dart test of the core money loop **before** any of Phase 0 is built:
one Good-tier outlet, one manager whose grade drives their daily decisions, daily
variable income against weekly and monthly fixed costs, and demand that fades unless the
owner markets and refreshes the menu.

This is **not** `packages/sim_core`. It breaks doc 09's order on purpose (managers are
Phase 2, and Phase 0 has a tuning gate before any play). Delete it once task 0.21's
balance bot exists; keep the findings, which live in `docs/balance-log.md` and doc 06 §3a.

## Run it

Needs Dart ≥ 3.5 (no Flutter).

```
dart pub get
dart run bin/play.dart --seed 7                                        # current spec values
dart run bin/play.dart --seed 7 --balance data/balance-original.json   # the numbers before the fixes
dart run bin/bots.dart --seeds 200 --weeks 26                          # scripted owners × every grade
dart run bin/bots.dart --set BUZZ_DECAY=0.02 --set BASE_FOOTFALL=50    # try a lever
dart test
```

In `play`, press Enter to play a day, `week` to play to Sunday, `help` for owner commands
(price, flyers, ad, promo, rework, visit, replace, managers/hire, repay).

## Files

| File | What |
|---|---|
| `data/balance.json` | Current spec values (docs after balance-log entry 4) |
| `data/balance-original.json` | The docs' numbers before any fix, for comparison |
| `results.txt`, `results-original.txt` | Bot output for each |

## Scripted owners

| Name | Does |
|---|---|
| passive | Nothing. Never markets, visits, reworks the menu or replaces equipment |
| remote | Markets (local ad every 4 weeks, menu rework every 8, prices 105%) and replaces flagged equipment, but never visits |
| competent | As remote, plus one visit a week |

"OWNER-RUN" rows are the Phase-1 reference: the owner is there every day, there is no
manager and the crew includes a cashier.

## What is modelled, and from where

| Thing | Source |
|---|---|
| Groups per day: footfall × rep × price × weekday × season × marketing × buzz × freshness × competition × noise | doc 02 §5.1, doc 11 §A.1–A.5 |
| Reputation, satisfaction weights, value score, never-seated walk-outs | doc 02 §6.8 |
| Crew wages, reliability, absences, happiness target, quitting | doc 02 §7, doc 04 §6 |
| Equipment wear, breakdown, maintenance, repairs, ageing | doc 02 §10, doc 04 §3, doc 11 §A.3 |
| Hygiene (proportional cleaning) and inspections | doc 02 §12 |
| Campaigns with rolled outcomes (flop to big hit), buzz, menu rework | doc 02 §13, §13.1, doc 11 §A.1–A.2 |
| Rent, payroll, loan instalment, utilities, tax, licence, bankruptcy; operating vs net profit | doc 02 §14 (no lifeline, no new loans) |
| Manager sub-skills, grade, profile, wage curve, potential, learning, coaching, rota errors, absence cover, ordering error, maintenance skipping, cheap repairs, early warnings, attribution | doc 02 §15.12, §15.14, doc 11 Part B |
| Neglect: grace = skill² / 70 | doc 02 §15.5 |
| Working manager: no cashier in a managed crew; manager fills one gap a day | doc 02 §15.15 |
| Mastery above skill 65: supplier negotiation, preventive care, crew development, retention | doc 02 §15.16 (weekly deals, supplier relations and deputies are not modelled) |
| Break-even line | doc 02 §15.13 |

### Stand-ins (`PROTO_*` and a few others in balance.json)

There is no per-tick service, so these replace it. Each is a guess.

| Key | Value | Replaces |
|---|---|---|
| `PROTO_SPEND_PER_GROUP` | 55 | menu and group size (doc 06 §1) |
| `PROTO_FOOD_COST` / `PROTO_BASE_WASTE` | 0.325 / 0.05 | per-dish recipe cost (doc 06 §2) |
| `PROTO_TABLE_TURNS` | 6 | tables × patience at peak |
| `PROTO_WALKOUT_BASE` / `_PER_GAP` | 0.05 / 0.15 | doc 06 §4 walk-out targets |
| `PROTO_FOOD_BASE`, `PROTO_WAIT_*` | | food and wait scores in doc 02 §6.8 |
| `PROTO_MENU_LOSS_*` | | sold-out and 86'd dishes |
| `PROTO_OWNER_VISITS_PER_WEEK` | 2 | the cost of the owner's time |
| `PROTO_CREW_WORK_DAYS` | 6 | the rota: wages are averaged over a 6-day week and scheduled days off cost nothing |
| `MANAGER_STEP_IN_GAP` | 0.5 | how much of a gap remains when the manager fills in |
| `MANAGER_TILL_SKILL_REF` | 60 | the manager's speed on the till: a flat gap of (60 − mean skill)/100 below 60 |

A role with two people counts half a gap when one is missing.

## Results (200 seeds × 26 weeks, Good tier, average location)

Average weekly net profit after the manager's wage:

| Run by | passive | remote | competent |
|---|---|---|---|
| Owner, no manager | +2.1k | — | +3.8k |
| Trainee | −2.2k | −1.4k | −0.2k |
| Junior | −1.5k | −0.7k | +0.3k |
| Capable | −0.8k | ≈ 0 | +0.9k |
| Senior | −0.4k | +0.8k | +1.5k |
| Veteran | ≈ 0 | +1.4k | +2.0k |

With the original numbers every managed row was negative under every owner and no run
survived (see `results-original.txt`).

"Survive" in the tables means a one-outlet company with the 70,000 starting loan *and* a
manager's wage reaching week 26. The real game never has that combination — managers
arrive with the second outlet — so read the profit columns, not survival.

## What changed since the first version of this prototype

The first run found eight problems in the docs. How each was resolved:

| # | Problem | Resolution |
|---|---|---|
| 1 | A Good-tier outlet cannot pay for a manager | Manager works the floor and replaces the cashier (doc 02 §15.15) |
| 2 | Doc 06 §3 overstated revenue ~10% | Average footfall 50 → 55; doc 06 §3 flagged as unmeasured for other tiers |
| 3 | One ad a month could not hold demand | `BUZZ_DECAY` 0.02 → 0.01 (measured −3%) |
| 4 | 11% daily absence | Divisor 400 → 1,000 |
| 5 | Default rota leaves roles empty Mon–Thu | Stand-in roles added to doc 02 §6.2 — **not modelled here** |
| 6 | Unvisited outlets failed at every grade | Neglect grace = skill² / 70; absence adder removed |
| 7 | Grade steps too flat | Mastery effects for skilled managers (doc 02 §15.16): steps now about +500 to +600 a week |
| 8 | Interest in operating profit | Operating vs net profit defined (doc 02 §14.2) |
| 8 | Manager people skill counted twice in morale | Daily modifier removed |
| 8 | Hygiene pinned at 100 | Proportional cleaning rule (doc 02 §12) |
| 8 | Turned-away groups score 10 | 30 at half weight (doc 02 §6.8) |
| 8 | No Veteran applicants below rating 4.0 | Left as designed |

## Known limits

- Everything about minute-by-minute service is a stand-in; the real balance bot must re-measure.
- Per-person days off (doc 02 §7.7) and stand-in roles are not modelled (problem 5); wages are averaged over a six-day week.
- One tier, one location class, one outlet.
- The manager's till work is a flat penalty, not task durations.

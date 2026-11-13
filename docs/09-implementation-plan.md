# 09 — Implementation Plan

Ordered tasks sized for one working session of an implementing model. Do them **in
order**; each lists the documents to read, what to build, and how to know it is done.
"Done" always also means: the CI commands in doc 08 §7 pass, and no rule was invented
(see doc 10 §1).

Legend: **Read** = sections needed for the task. **AC** = acceptance criteria.

---

## Phase 0 — Simulation core (no UI)

| # | Task | Read | AC |
|---|---|---|---|
| 0.1 | Repo skeleton: `packages/sim_core` and `app` per doc 08 §2; lints; CI script; README with pinned Flutter version | 08 §2, §7 | `dart test` and `flutter test` run (with one trivial test each) |
| 0.2 | `SimRng` | 08 §5 | Seed 1 → 270369; float in [0,1) over 10⁵ draws; `nextInt` inclusive bounds; state save/restore continues the same sequence |
| 0.3 | Content classes, `ContentLoader`, `balance.json` with every constant from doc 02, typed `Balance` accessors | 03 §1, 02 (all constants) | Missing key → error naming the key; test lists every key used |
| 0.4 | `ingredients.json`, `dishes.json` (Italian only), `equipment.json`, `suppliers.json`, `traits.json`, `themes.json` (Italian), `tiers.json`, `locations.json`, `strings_en.json`; `ContentValidator`; `tool/validate_content.dart` | 04, 03 §1 | Validator passes; deliberately broken fixture files fail with file/id/field; derived price for each Italian dish asserted in a test |
| 0.5 | State model classes with `fromJson`/`toJson`; `SaveFile` envelope; migrations scaffold | 03 §2 | Round-trip equality test on a hand-built state |
| 0.6 | Generators: restaurant offer per tier (staff, equipment, tables, stock, menu, rota, hidden problems as data only) | 01 §4.3, 04 §3, §5, §6, 02 §4 | Same seed → same offers; rosters match doc 04 §6; stat ranges respected over 500 seeds |
| 0.7 | `Sim` facade, command dispatch, error codes; `NewGame`, `BuyDueDiligence`, `BuyRestaurant`; calendar | 08 §3, 03 §3, 02 §2 | After buying Good tier: cash 20,000, loan 70,000, phase prep, day 0 Monday |
| 0.8 | Demand: groups per day, arrivals, sizes, segments; `forecast` | 02 §4–5 | Unit tests for each factor; mean groups over 1,000 seeded days within 3% of formula |
| 0.9 | Service loop part 1: group state machine, tables, front-of-house tasks, assignment, durations, patience, walk-outs (kitchen stubbed: food ready after fixed ticks) | 02 §3.2, §6.1–6.4 | Scenario: no servers → all groups walk out at waitOrder; invariants hold every tick |
| 0.10 | Kitchen: ordering, tickets, station slots, `COOK_PARALLEL`, stock consumption, auto-86, dishes backlog, food quality | 02 §6.4–6.7, §10.2 | Scenarios: no cook → no food; station broken → its dishes 86'd; plates full blocks cooking |
| 0.11 | Satisfaction, payment, tips, reputation update, `DayStats` | 02 §6.8 | Hand-computed satisfaction cases; reputation falls twice as fast as it rises |
| 0.12 | Inventory: batches, FIFO, capacity, expiry, price index, orders, deliveries and delivery problems, payables, relationship | 02 §9 | Scenarios: over-order → waste recorded; unreliable supplier produces late/short/bad at expected rates |
| 0.13 | Staff: wages, fatigue, morale, absence, lateness, quitting with notice, applicants, hire/fire/raise/train, stat reveal, traits | 02 §7, 04 §5 | Each formula unit-tested; each trait modifier has a test |
| 0.14 | Owner: queue, cover roles, walking, energy, mistakes, rest day, forced rest | 02 §8 | Scenario: server absent + owner covers Server → walk-outs at least halve vs not covering (fixed seed set) |
| 0.15 | Equipment: wear, breakdown, maintenance, repair options, replace, sell; storage capacity effects | 02 §10, §9.1 | Breakdown frequency at condition 30 vs 80 matches formula over 10⁴ rolls |
| 0.16 | Finance: daily flows, weekly payroll/rent/instalments, monthly utilities/tax, loans, credit score, valuation, bankruptcy counters; hygiene and inspections | 02 §12, §14 | Scenario: 3 missed instalments → game over; valuation formula test |
| 0.17 | Incident engine: condition evaluator, effect applier, rolls, cooldowns, forced, follow-ups, countdown/default, subject binding | 05 §2, 02 §11 | Every condition key and effect type has a unit test; unknown key → validator error |
| 0.18 | `incidents.json`: all 40 MVP incidents + hidden problems wiring | 05 §3–4 | Generic test resolves every option of every incident on a standard state without error; hidden problems fire on their due days |
| 0.19 | `beginDay`/`endDay` orchestration in exact doc order; stages 1–2 and objectives; marketing; par-level auto-order | 02 §3, §13, §9.4; 01 §3.3; 04 §8 | Determinism test (28 days, save/load mid-service) passes |
| 0.20 | `explain` for demand, reputation change, day profit, satisfaction, dish margin | 08 §4 | Sum of factors equals the value the sim used, in a test for each target |
| 0.21 | Balance bot (passive + competent), CSV + band report | 06 §6 | Runs 200 seeds × 26 weeks for one tier in < 2 min; output has all §6.2 columns |
| 0.22 | **Tuning pass**: adjust `balance.json` until doc 06 §4 bands pass; log changes; update doc 06 §3 | 06 | All bands PASS or each remaining FAIL has a written note in `balance-log.md` |

**Gate:** do not start Phase 1 until 0.22 is done. A UI on an untuned economy wastes effort.

## Phase 1 — Playable MVP (one restaurant, Italian, stages 1–2)

| # | Task | Read | AC |
|---|---|---|---|
| 1.1 | App shell: theme, `AssetCatalog` with placeholders, localisation lookup, content loading, `GameController`, save service | 08 §6, 07 §2, §6 | App starts, loads content, creates a game, autosaves and restores after kill |
| 1.2 | Title, New Game (difficulty, theme), Takeover Market, Offer Detail | 07 §4.2 | Can buy any tier; due diligence reveals issues; widget tests at both sizes |
| 1.3 | Main shell: top bar, bottom tabs, "Why?" sheet | 07 §3, §4.1, §4.10 | Cash and reputation open explanations from `sim.explain` |
| 1.4 | Prep board | 07 §4.3 | Attention items computed and deep-link; cover-role selection; Rest today; Open doors |
| 1.5 | Service view (Flame) part 1: room, tables, figures, groups moving through states from events; clock and speed controls | 07 §4.4, 08 §6.2–6.3 | Runs a full service at 1×/2× at 60 fps on a mid device; pausing works |
| 1.6 | Service view part 2: task markers, patience rings, owner queue and cover bar, kitchen strip, dish meter, popovers, auto-run | 07 §4.4 | Tapping a marker queues it; queue max 3; staff-taken markers dimmed |
| 1.7 | Incident card overlay + result line + deferred countdown | 07 §4.9, 05 §1 | All 40 incidents render with correct chips; disabled options explain why |
| 1.8 | Close report (3 pages) + weekly and monthly statements; ranked causes from day events | 07 §4.5 | "What went wrong" lists the true top causes in three scripted scenarios |
| 1.9 | Staff tab: list, detail, actions, Rota, Hire | 07 §4.6 | Every staff command reachable; coverage warnings correct |
| 1.10 | Stock tab: list, Order flow, Suppliers, par levels (stage 2) | 07 §4.7 | Minimum order enforced with message; "Order usual" works |
| 1.11 | Kitchen tab: Menu, Equipment | 07 §4.8 | Price stepper bounds 60–180%; maintain/repair/replace/sell flows |
| 1.12 | Money tab: chart, bills, loans, valuation, Marketing (stage 2) | 07 §4.8 | Loan limits and errors shown; upcoming bills match sim |
| 1.13 | Stage-up, objectives list, game over with timeline, lifelines | 07 §4.10, 01 §3.4 | Bankruptcy path playable end to end |
| 1.14 | Tutorial coach marks (days 1–3), settings, pause menu, save slots | 07 §4.10 | Tutorial skippable and resettable |
| 1.14b | Term help: plain names everywhere, tappable term cards, first-appearance auto-open, Handbook | 07 §5 | Every row of the 07 §5 table has its three strings; a test fails if a screen shows an internal name from that table |
| 1.15 | Sound, haptics, motion polish, reduced-motion setting | 07 §6 | No audio/vibration when disabled |
| 1.16 | Accessibility and layout pass | 07 §2, §8 | No overflow at 360×640 with text scale 1.3; labels present |
| 1.17 | Device test pass + performance budget check + release build without INTERNET permission | 08 §6.6, §8 | Checklist recorded in `docs/release-checklist.md` |

**Gate:** playtest with real people (at least five, 30 minutes each). Record where they
were confused, bored or surprised. Fix those before Phase 2. If floor work dominates
or bores (doc 00 risks), adjust owner energy / staffing balance here.

## Phase 2 — Multiple locations (stages 3–4)

Write `11-phase2-spec.md` first (location market, manager role and applicants, policies,
unattended runner details, location switcher UI, company screen, chain systems), then:

2.1 Lockstep ticking of all locations, `OwnerTravel`, location strip (doc 02 §15.1, §15.3; 07 §4.11) ·
2.2 Location market + buy/build · 2.3 Managers + policies at prep, incidents by phone and
manager decisions (doc 02 §15.2, §15.4) · 2.3b Neglect, skimming, audit, location crisis and
closure, with `explain` lines for each (doc 02 §15.5–15.7) · 2.4 Company tab and
per-location reports that name causes · 2.5 Stage 3–4 objectives and incidents · 2.6 Central kitchen,
bulk contracts, brand reputation · 2.8 Balance bot for multi-location + tuning.

## Phase 3 — Group (stage 5)

Write `12-phase3-spec.md` first. Second brand, acquisitions, franchising, ending.

## Phase 4 — Content and polish

4.1 Chinese, Mexican, Indian packs (data + stations + art) · 4.2 Mixed theme rules ·
4.3 Theme-specific incidents (3 per theme) · 4.4 Scenario/challenge mode ·
4.5 Additional languages · 4.6 Save export/import · 4.7 Final art and audio swap ·
4.8 Store builds.

---

## How to hand a task to an implementing model

Give it: `docs/10-glossary-and-conventions.md` (always), the task row, and the documents
in its **Read** column. Ask for: the code, the tests, and a short note listing any place
where the spec was ambiguous or contradictory. Review that note before the next task —
spec gaps are fixed **in the docs**, not just in code.

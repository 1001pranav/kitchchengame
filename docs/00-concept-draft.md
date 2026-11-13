# Restaurant Chain Tycoon — Concept Draft (v0.2)

> **Changes in v0.2 (owner decisions):** mobile platform; five-minute sessions (one
> session = one game day); owner is hands-on and can do floor work (§3); player picks a
> cuisine theme, currency is generic (§5.1); takeover tiers use honest pricing plus a
> separate difficulty modifier (§5); realism goal restated (§2).

> **Status:** DRAFT for discussion. Nothing here is final. Numbers are placeholders
> to make the design concrete, not balanced values.
> **Working title:** *Kitchen Chain* (placeholder).
> **Purpose of this file:** agree on features and scope before writing the detailed
> specs that implementation models will build from (see §14 for the planned document set).

---

## 1. One-paragraph pitch

You take over an existing, already-running restaurant using limited starting capital
and a loan. You inherit its staff, its equipment, its lease, its reputation — and its
problems. You are a **hands-on owner**: you hire, schedule, buy, price, repair and
borrow — and when the restaurant is short-handed you take orders, carry plates and work
the till yourself. Survive, become profitable,
open a second location, turn it into a chain, and eventually run several restaurant
brands as a holding company. Fully offline, single-player.

## 2. Design pillars

Every feature must serve at least one of these. If it serves none, it is cut.

1. **You inherit a mess, not a blank slate.** The game starts with a takeover, so
   the first hours are diagnosis: who is good, what is broken, what is bleeding money.
2. **Problems are the content.** Staff, ingredients and machines fail in believable,
   connected ways. A fridge failure is also a spoilage problem, a menu problem and a
   cash problem.
3. **Every problem has more than one answer, and each answer costs something.**
   No "click to fix". Cheap/fast/good — pick two.
4. **Your job changes as you grow.** One restaurant: you are on the floor covering
   gaps. Three: you manage managers. A brand: you set policy and allocate capital.
   Getting *off* the floor is itself a goal the player works towards.
5. **Readable simulation.** The player must always be able to find out *why*
   something happened (why profit fell, why the chef quit). An opaque sim feels random.

### Realism stance (important)

**Goal: the player should finish a week of play understanding why running a restaurant
is hard.** We get there through the realism of **problems and trade-offs**, not the
realism of **proportions**. Real restaurants run 3–5% net margins and most fail within
a few years; copying those numbers produces a depressing spreadsheet. We keep real
*causes and effects* (a no-show cook really does wreck a Friday) and take liberties with
time, margins and feedback speed so decisions feel consequential within one session.

## 3. Player role and what the player actually does

The owner is a character in the restaurant with two kinds of work.

### 3.1 Management decisions

| Frequency | Decisions |
|---|---|
| Daily | Order ingredients, set today's rota, respond to incidents, 86 (disable) menu items |
| Weekly | Hire/fire, adjust menu and prices, pay wages, pick suppliers, schedule maintenance, marketing |
| Monthly | Rent, loan instalment, taxes, review P&L, renegotiate, plan upgrades |
| Rarely | Renovate, buy equipment, open/acquire a location, appoint a manager, launch a brand |

### 3.2 Floor work (hands-on)

During service the owner can personally do any front-of-house or back-office job:
**take orders, deliver food, take payment at the till, clear tables, receive and count
deliveries, do a stock check.** (Cooking is an open question — see D9.)

Rules that make this a decision rather than a reflex test:

- **The owner is one body.** Floor tasks appear as markers in the restaurant view
  (table 4 wants to order, order 12 is ready, table 2 wants the bill). Tapping one
  queues it for the owner, who walks there and spends time doing it. No timing or
  accuracy skill is tested — the skill is *choosing which fire to put out*.
- **Staff do the same tasks automatically.** The owner is the wildcard who covers
  whatever the rota cannot. A fully staffed, well-run shift needs no owner taps at all.
- **Floor time costs management time.** While the owner is carrying plates, incident
  cards wait (with a timer) and nobody is watching the till or the back door. Some
  problems (theft, sloppy portioning) are only noticed when the owner is *not* busy.
- **Owner energy.** Floor work drains an energy bar. Run it to zero several days in a
  row and the owner makes mistakes (wrong change, dropped order) and eventually loses a
  day to exhaustion. This is the game's honest answer to "just do it all yourself".
- **It does not scale.** The owner can be in only one restaurant per day. From the
  second location on, every other outlet runs on its staff and manager (§6.9).

This models the real arc of a small-business owner: at first you are the cheapest and
most reliable employee you have; success means making yourself unnecessary.

## 4. Game structure: continuous, with stages

**Recommendation: one continuous simulation, gated by milestone "stages" — not
discrete levels.** Levels reset progress, which contradicts the fantasy of *building*
something. But a pure sandbox with no goals loses players after the first profit. Stages
give direction without resets.

| Stage | Name | Entry condition (draft) | What unlocks | Player's job |
|---|---|---|---|---|
| 1 | Takeover | Game start | Core ops: staff, stock, equipment, menu | Stop the bleeding |
| 2 | Stable | 4 profitable weeks in a row | Marketing, training, renovation, supplier contracts | Optimise |
| 3 | Second location | Cash + reputation threshold | Location scouting, branch managers | Learn to delegate |
| 4 | Chain | 3+ locations | Central kitchen, bulk purchasing, standard operating policies, regional manager | Build systems |
| 5 | Group | Chain valuation threshold | New brands/cuisines, acquisitions of rival restaurants, franchising | Allocate capital |

Each stage also has 3–5 optional objectives (e.g. "pass a health inspection with an A",
"reach 4.5★") that award cash, reputation or unlocks. A scenario/challenge mode can be
added later on top of the same simulation.

**Time model:** day-based, built around a **five-minute mobile session = one game
day**. A day can be stopped and resumed at any point (autosave on every phase change
and on app backgrounding). Each day has three phases:

1. **Prep (~1 min, untimed):** deliveries arrive, check stock, set rota, handle
   overnight events. Sensible defaults ("same as yesterday") so it can be done in three taps.
2. **Service (~3 min, simulation runs):** customers arrive, orders flow through
   stations, the owner covers gaps on the floor (§3.2), incidents demand decisions.
   Pause any time; 2× speed; **auto-run** option once staffing covers every role.
3. **Close (~1 min, untimed):** day P&L, waste, complaints, staff notes, tomorrow's warnings.

Weekly and monthly decisions (payroll, menu, rent, loan) surface inside Prep or Close of
the relevant day, so no session ever needs more than about five minutes.

**Fail state:** bankruptcy — cash below zero with no credit left for N consecutive days,
or defaulting on the loan. Before game over the player gets escalating lifelines with real
costs (emergency loan at punishing interest, sell equipment, sell a location, take an
investor who claims a share of profits).

**Win state:** none hard-coded; Stage 5 completion + a company valuation score. Sandbox continues.

## 5. Starting choice: the takeover

The player starts with fixed capital (draft: 100,000 coins) and chooses one of five
restaurants for sale. **Pricing is honest: you get what you pay for.** Anything above
your capital is financed by a loan.

| Tier | Price | Loan needed | Cash left | Staff | Equipment | Reputation | Location / rent | Hidden problems | Where the pressure comes from |
|---|---|---|---|---|---|---|---|---|---|
| Excellent | 300k | 220k | 20k | Skilled, loyal, well paid | ~90% | 4.5★ | Prime, high rent | 0 | Big loan instalment and rent; little room for a bad month |
| Best | 220k | 140k | 20k | Good, one weak link | ~75% | 4.0★ | Good, above-average rent | 1 | Loan plus first equipment replacements |
| Good | 150k | 70k | 20k | Mixed | ~60% | 3.5★ | Average | 2 | A bit of everything |
| Bad | 80k | 0 | 20k | Low skill or low morale | ~40% | 2.5★ | Weak, or good with a bad lease | 3 | Weak sales, repairs, staff turnover |
| Worst | 30k | 0 | 70k | Unskilled, demoralised, one troublemaker | ~25%, one machine dead | 1.5★ | Poor, overpriced locked-in lease | 4–5, incl. inherited supplier debt | Loses money daily; cash runs out before reputation recovers |

Balance target: for a first-time player the order from most to least forgiving is still
Excellent → Worst, because good staff and reputation absorb mistakes and debt does not
punish you until you miss a payment.

A separate **difficulty modifier** (Easy / Normal / Hard) scales interest rates,
incident frequency, customer patience and price volatility independently of the tier.

**Hidden problems** are what make the takeover feel real: they are revealed over the
first weeks, not on the purchase screen. Examples: unpaid supplier bills, a pending
health violation, the head chef already planning to leave, a pest issue, a walk-in
fridge near failure, a staff member skimming the till, a lease clause that raises rent
in month 3. A paid "due diligence" option before purchase reveals some of them.

Restaurants within a tier are procedurally generated from a seed (names, staff roster,
which hidden problems) so replays differ.

### 5.1 Cuisine theme and currency

Before the takeover screen the player picks a **cuisine theme**: one country-specific
cuisine (launch with a small set, e.g. 3–4) or **Mixed / multi-cuisine**.

- A theme is a **content pack**: dishes, ingredients, staff and restaurant name pools,
  seasonal events/festivals, a few theme-specific incidents and the visual skin.
- Themes **do not change rules or balance formulas**. Every pack must fill the same
  slots (e.g. N starters, N mains, same spread of cost, prep time and station use) so
  one balance pass covers all of them.
- *Mixed* draws dishes from all packs: wider customer appeal, but more distinct
  ingredients to stock and more skills needed in the kitchen — a real trade-off.
- Currency is a generic in-game unit (**coins**), the same in every theme. No real
  currencies, no real-world price claims.
- Stage 5 "new brand" (§6.9) reuses this: a second brand is a second theme.

## 6. Core systems

### 6.1 Staff

- **Roles:** head chef, line cook, prep cook, dishwasher, server, host/cashier,
  cleaner, later: branch manager, purchaser, regional manager.
- **Attributes:** skill (per role), speed, reliability, morale, loyalty, wage,
  honesty, stamina/fatigue, plus 1–2 traits (e.g. *mentor*, *hot-headed*, *often late*,
  *perfectionist*, *ambitious*).
- **Mechanics:** hiring (applicants with partially hidden stats, revealed over time),
  rota/shifts, overtime, training, raises, promotions, warnings, firing (severance,
  morale hit on friends).
- **Problems:** no-shows, lateness, sickness, quitting (with or without notice),
  poaching by rivals, wage demands, conflicts between two staff, theft, burnout from
  overwork, injuries, a skilled-but-toxic employee, festival-season leave requests,
  a key person holding the kitchen hostage because nobody else can do their job.

### 6.2 Ingredients and inventory

- Ingredients have category, unit cost, **shelf life**, storage type (dry / chilled /
  frozen) and quality grade.
- **Suppliers** differ on price, quality, reliability, minimum order, delivery days
  and credit terms. Relationship level improves terms.
- **Problems:** late or short deliveries, bad batch, price spikes and seasonal
  shortages, spoilage from over-ordering, stockouts from under-ordering (dishes get
  86'd mid-service), storage capacity limits, fridge failure spoiling stock, portioning
  waste from unskilled cooks, pilferage, a supplier going bust or demanding cash upfront.

### 6.3 Equipment and premises

- Stations: stove/range, oven, fryer, grill, refrigerator, freezer, dishwasher,
  exhaust/hood, POS/billing, AC, generator, water supply, furniture.
- Each has condition (0–100), capacity, running cost and a breakdown chance that
  rises as condition falls.
- **Decisions:** preventive maintenance (cheap, scheduled downtime) vs run-to-failure
  (free until it isn't); repair (cheap/fast/unreliable technician vs expensive/slow/good)
  vs replace; new vs second-hand; upgrade for capacity.
- **Problems:** breakdown mid-service, power cut, gas running out, water outage,
  plumbing leak, pests, AC failure in summer, POS crash, landlord issues.

### 6.4 Menu and kitchen flow

- A dish = recipe (ingredients + quantities), required station(s), prep time, required
  skill, price. Food-cost % and margin are shown per dish.
- Kitchen is a simple **queueing model**: orders → stations with capacity → staff with
  speed/skill. Bottlenecks create wait times; wait times hurt satisfaction.
- Menu size is a trade-off: bigger menu = more appeal, more stock, more waste, slower kitchen.
- Dish quality = f(ingredient quality, cook skill, equipment condition, rush load).

### 6.5 Customers, demand and reputation

- Daily demand = location footfall × reputation × price perception × day-of-week ×
  season/weather × marketing × competition.
- Customer segments (office lunch, families, students, tourists, food critics) with
  different price sensitivity and patience.
- Satisfaction per visit from wait time, food quality, service, cleanliness, price,
  availability → rolls up into **reputation (★ rating)** with inertia: slow to build, fast to lose.
- **Problems:** bad reviews, a viral complaint, food-poisoning incident, a critic
  visiting on your worst day, a no-show large booking, rowdy customers, a new competitor
  opening next door, price war.

### 6.6 Finance

- Cash, daily P&L, weekly/monthly statements, per-dish and per-location profitability.
- Costs: wages, ingredients, rent, utilities, maintenance, loan instalments, marketing,
  licences, taxes.
- **Loans:** principal, interest, instalment schedule, late penalties, credit rating
  that affects future borrowing. Later: investors and equity.
- Cash flow matters more than profit: you can be profitable and still miss payroll.

### 6.7 Compliance

- Hygiene score driven by cleaning staff, equipment, pests, storage discipline.
- Health inspections (random + complaint-triggered): pass, fine, or temporary closure.
- Licences to renew, fire safety, labour rules (max hours, minimum wage).

### 6.8 Incidents (the event system)

The heart of the "real owner" feeling. An incident is a card with a situation, 2–4
responses, each with costs, success odds influenced by game state, and follow-up
consequences that may arrive days later.

> *Example — "The fryer died at 7:40 pm."*
> (a) Pull fried items off the menu tonight — lose sales, some unhappy customers.
> (b) Call the emergency technician — expensive, 60% fixed within the hour.
> (c) Let the line cook try — free, 30% works, 15% chance of injury.
> Follow-up: if not properly repaired, breakdown odds stay elevated for two weeks.

Incidents are **triggered by simulation state**, not pure dice: neglected maintenance
makes breakdowns likelier; overworked staff make quitting likelier. Pure randomness is
kept below roughly 30% of incidents so outcomes feel earned.

### 6.9 Expansion (Stages 3–5)

- **New locations:** scout sites (rent, footfall, demographics, competition), build
  new or take over another failing restaurant (reusing the §5 system).
- **Branch managers:** each non-active location is run by a manager whose skill and
  honesty determine how well it follows your policies. The player sets **policies**
  (ordering rules, wage bands, price levels, maintenance schedule) instead of daily clicks.
- **Chain systems:** central kitchen, bulk supplier contracts, brand reputation shared
  across outlets (one outlet's scandal hurts all), standardised menu vs local menu.
- **Group level:** second brand in a different cuisine/price segment, acquire rivals,
  franchise (fees in, less control, reputation risk).

## 7. Engagement loops

- **Minute:** watch service, respond to an incident.
- **Day:** plan → serve → read the report → fix one thing.
- **Week:** payroll and reviews land; did the change you made pay off?
- **Month:** rent and loan due; afford the next upgrade?
- **Stage:** unlock a new layer of the business and a new kind of problem.

Hooks: named staff with history (the dishwasher you trained into a head chef),
long-tail consequences of earlier choices, visible restaurant improvement, valuation score.

## 8. Offline requirement

- No server, account, ads SDK or network call anywhere in the game.
- All content (dishes, ingredients, staff names, incidents, locations) ships as local data files.
- Saves stored locally; autosave at end of each day; multiple slots; export/import save file.
- **Deterministic simulation with a seeded RNG** — same seed + same inputs = same
  outcome. Required for testing and for reproducing bugs.

## 9. Presentation (draft)

- **Mobile, portrait, one-thumb.** Large tap targets, no hover, no dense tables; every
  list has a summary line and a drill-down.
- **Restaurant view is core** (it is where floor tasks are tapped): a simple 2D
  top-down room with tables, pass, till, back door, staff and owner as small figures,
  task markers above them. Management screens are cards and sheets over this view.
- Art scope must stay small: one room layout per size class re-skinned per theme,
  icons, staff portraits from a parts-based generator. Each cuisine theme adds art cost —
  this is the main reason to launch with few themes.
- Text-heavy content means localisation should be planned from the start (all strings in data files).

## 10. Technical direction (proposal, not decided)

- **Target:** Android and iOS phones, fully offline.
- **Recommended stack (D3, still open):** TypeScript; simulation core as a plain
  library; a 2D canvas renderer (e.g. Phaser or PixiJS) for the restaurant view and
  HTML/CSS for management screens; packaged as native apps with Capacitor. Alternative:
  Godot, which gives a stronger game toolchain but is harder to unit-test headlessly
  and harder for weaker models to edit reliably (scene files).
- **Architecture rule:** the simulation core is pure logic with no UI or platform
  dependencies — `state + player actions + seed → new state`. UI only renders state and
  sends actions. This is what makes the game unit-testable and what lets weaker models
  implement one system at a time against a spec.
- **Data-driven:** all balance values and content in JSON validated by schemas; no
  magic numbers in code.

## 11. Scope and phasing

"Chain of restaurants with multiple chains" is three games stacked on each other.
Build in vertical slices; each phase is playable on its own.

| Phase | Contents | Proves |
|---|---|---|
| P0 Prototype | Headless sim: one restaurant, demand, kitchen queue, stock, wages, cash. Text output only | The economy is tunable |
| P1 MVP | Stage 1–2 complete: takeover choice, **one cuisine theme**, owner floor work, staff, inventory, equipment, menu, finance, ~40 incidents, save/load, mobile UI | One restaurant is fun for 5+ hours in five-minute sessions |
| P2 | Stage 3–4: multiple locations, managers, policies, central purchasing | Delegation is fun, not busywork |
| P3 | Stage 5: brands, acquisitions, franchising | Endgame |
| P4 | Scenarios, more cuisines, polish, localisation | Replayability |

**If P1 is not fun, nothing after it matters.** Do not design P2+ in detail until P1 is playable.

## 12. Known risks

| Risk | Why it matters | Mitigation |
|---|---|---|
| Spreadsheet syndrome | Sim is correct but joyless | Incidents with characters and consequences; strong daily report; visible change |
| Micromanagement explosion at 3+ locations | Daily clicks × N restaurants kills the game | Policies and managers replace manual actions; player "visits" one location at a time |
| Floor work becomes the whole game | Tapping tables is easier to enjoy than reading a P&L; players never learn the management layer and hit a wall at location two | Owner energy, incidents that only management can solve, stage goals that require hiring |
| Floor work becomes a chore | By day 30 tapping tables is repetitive | Staff make it unnecessary; auto-run service; it returns only in crises |
| Theme packs multiply content and art cost | Each cuisine needs dishes, names, art, testing | Fixed slot template per pack; one pack in MVP |
| Too much UI for a phone | Sim games drown small screens | Card-based drill-down, defaults for every daily decision |
| Random-feeling failures | Player blames dice, quits | State-driven incidents, warnings before failures, "why" explanations everywhere |
| Balance complexity | Many interacting systems | Headless sim + automated balance runs over thousands of seeded days |
| Scope creep | Never ships | Phase gates in §11 |
| Spec gaps for implementing models | Weaker models guess, guesses diverge | Exact formulas, data schemas, state definitions, acceptance tests per system |

## 13. Open decisions (need owner input)

| # | Decision | Options | Draft recommendation |
|---|---|---|---|
| D1 | Takeover tiers | — | **Assumed decided:** honest pricing + difficulty modifier (§5). Confirm |
| D2 | Platform | — | **Decided:** mobile |
| D3 | Tech stack | TypeScript + Capacitor / Godot / Unity | TypeScript + Capacitor |
| D4 | Setting | — | **Decided:** player-chosen cuisine theme or mixed; generic coins (§5.1) |
| D5 | Service phase | — | **Decided by D8:** ~3 min real-time with pause, 2×, auto-run |
| D6 | Tone | Serious sim / light and humorous | Grounded with dry humour in incident writing |
| D7 | Monetisation | Premium / free | Affects nothing in design as long as there are no ads or IAP (offline) |
| D8 | Session length | — | **Decided:** five minutes = one game day |
| D9 | Can the owner cook? | Yes, any dish / yes, at low skill / no | Yes at low fixed skill: slow and mediocre, a last resort when the cook is absent |
| D10 | Floor work style | Tap-to-queue (choice) / timing and swipes (dexterity) | Tap-to-queue; no dexterity |
| D11 | Launch cuisine themes | Which and how many | One in MVP, 3–4 + Mixed at launch; owner to name them |
| D12 | Orientation | Portrait / landscape | Portrait |

## 14. Planned document set (after this draft is agreed)

Each document is written so an implementing model can work from it without needing the others open.

| File | Contents |
|---|---|
| `01-game-design-document.md` | Final version of this draft: full feature list, rules, progression |
| `02-simulation-spec.md` | Exact formulas, tick order, state machine for a day, RNG rules |
| `03-data-schemas.md` | JSON schemas for every entity + save-file format |
| `04-content-catalogue.md` | Dishes, ingredients, equipment, staff traits, suppliers, locations |
| `05-incident-catalogue.md` | Every incident: triggers, options, outcomes, follow-ups |
| `06-economy-and-balance.md` | Starting values, target curves, tuning method |
| `07-ui-ux-spec.md` | Screen list, flows, wireframes, copy rules |
| `08-technical-architecture.md` | Modules, folder layout, state management, persistence, testing |
| `09-implementation-plan.md` | Ordered, small, independently verifiable tasks with acceptance criteria |
| `10-glossary-and-conventions.md` | Shared vocabulary, naming, coding rules for implementing models |

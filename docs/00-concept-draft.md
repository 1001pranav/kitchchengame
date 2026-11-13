# Restaurant Chain Tycoon — Concept Draft (v0.1)

> **Status:** DRAFT for discussion. Nothing here is final. Numbers are placeholders
> to make the design concrete, not balanced values.
> **Working title:** *Kitchen Chain* (placeholder).
> **Purpose of this file:** agree on features and scope before writing the detailed
> specs that implementation models will build from (see §14 for the planned document set).

---

## 1. One-paragraph pitch

You take over an existing, already-running restaurant using limited starting capital
and a loan. You inherit its staff, its equipment, its lease, its reputation — and its
problems. You are the **owner, not the cook**: you hire, schedule, buy, price, repair,
borrow and react to the things that go wrong every day. Survive, become profitable,
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
4. **Your job changes as you grow.** One restaurant: hands-on operator. Three: you
   manage managers. A brand: you set policy and allocate capital.
5. **Readable simulation.** The player must always be able to find out *why*
   something happened (why profit fell, why the chef quit). An opaque sim feels random.

### Realism stance (important)

Target the realism of **problems and trade-offs**, not the realism of **proportions**.
Real restaurants run 3–5% net margins and most fail within a few years; a faithful
simulation of that is a depressing spreadsheet. We keep real *causes and effects* and
compress time, widen margins and shorten feedback loops so decisions feel consequential
within minutes.

## 3. Player role and what the player actually does

The player never performs dexterity tasks (no cooking mini-games, no dragging plates).
All play is **decisions under constraints**:

| Frequency | Decisions |
|---|---|
| Daily | Order ingredients, set today's rota, respond to incidents, 86 (disable) menu items |
| Weekly | Hire/fire, adjust menu and prices, pay wages, pick suppliers, schedule maintenance, marketing |
| Monthly | Rent, loan instalment, taxes, review P&L, renegotiate, plan upgrades |
| Rarely | Renovate, buy equipment, open/acquire a location, appoint a manager, launch a brand |

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

**Time model:** day-based. One game day ≈ 2–4 minutes of real time at 1× speed, with
pause and 2×/4× speed. Each day has three phases:

1. **Prep (paused planning):** deliveries arrive, check stock, set rota, handle overnight events.
2. **Service (simulation runs):** customers arrive, orders flow through stations,
   incidents pop up and demand a decision. The player watches the bottlenecks, not individual plates.
3. **Close (report):** day P&L, waste, complaints, staff notes, tomorrow's warnings.

**Fail state:** bankruptcy — cash below zero with no credit left for N consecutive days,
or defaulting on the loan. Before game over the player gets escalating lifelines with real
costs (emergency loan at punishing interest, sell equipment, sell a location, take an
investor who claims a share of profits).

**Win state:** none hard-coded; Stage 5 completion + a company valuation score. Sandbox continues.

## 5. Starting choice: the takeover

The player starts with fixed capital (draft: 100,000) and chooses one of five
restaurants for sale. This choice doubles as the difficulty setting.

| Tier | Difficulty | Staff | Equipment | Reputation | Location / footfall | Rent | Loan burden | Hidden problems |
|---|---|---|---|---|---|---|---|---|
| Excellent | Easy | Skilled, loyal, well paid | ~90% condition | 4.5★ | Prime | High (justified by footfall) | Small, low interest | 0 |
| Best | Normal- | Good, one weak link | ~75% | 4.0★ | Good | Above average | Moderate | 1 |
| Good | Normal | Mixed | ~60% | 3.5★ | Average | Average | Moderate | 2 |
| Bad | Hard | Low skill or low morale | ~40% | 2.5★ | Weak, or good with bad lease | Slightly high for what it is | Large | 3 |
| Worst | Very hard | Unskilled, demoralised, one troublemaker | ~25%, one machine dead | 1.5★ | Poor | Overpriced lease, locked in | Large, high interest, plus inherited supplier debt | 4–5 |

**Hidden problems** are what make the takeover feel real: they are revealed over the
first weeks, not on the purchase screen. Examples: unpaid supplier bills, a pending
health violation, the head chef already planning to leave, a pest issue, a walk-in
fridge near failure, a staff member skimming the till, a lease clause that raises rent
in month 3. A paid "due diligence" option before purchase reveals some of them.

**Design tension to resolve (see §13, D1):** in reality an excellent restaurant costs
*more* to buy, so it should need a *bigger* loan. The table above follows the brief
(excellent = easy = less loan), which works as a difficulty preset but is not how
acquisition pricing works. Alternative: honest pricing — excellent is expensive and
leaves you heavily indebted but with strong cash flow; worst is nearly free but drains
cash on repairs and wages before it earns. That version makes all five tiers a genuine
strategic choice rather than a difficulty slider.

Restaurants within a tier are procedurally generated from a seed (names, staff roster,
cuisine, which hidden problems) so replays differ.

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

- Management UI first: dashboard, lists, cards, charts. A simple 2D top-down view of the
  restaurant during service is a *nice to have*, not core.
- Art scope must stay small: icons, portraits from a parts-based generator, a few backgrounds.
- Text-heavy content means localisation should be planned from the start (all strings in data files).

## 10. Technical direction (proposal, not decided)

- **Recommended stack:** TypeScript, web-based, installable offline as a PWA; wrap with
  Capacitor/Tauri for mobile/desktop stores later.
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
| P1 MVP | Stage 1–2 complete: takeover choice, staff, inventory, equipment, menu, finance, ~40 incidents, save/load, UI | One restaurant is fun for 5+ hours |
| P2 | Stage 3–4: multiple locations, managers, policies, central purchasing | Delegation is fun, not busywork |
| P3 | Stage 5: brands, acquisitions, franchising | Endgame |
| P4 | Scenarios, more cuisines, polish, localisation | Replayability |

**If P1 is not fun, nothing after it matters.** Do not design P2+ in detail until P1 is playable.

## 12. Known risks

| Risk | Why it matters | Mitigation |
|---|---|---|
| Spreadsheet syndrome | Sim is correct but joyless | Incidents with characters and consequences; strong daily report; visible change |
| Micromanagement explosion at 3+ locations | Daily clicks × N restaurants kills the game | Policies and managers replace manual actions; player "visits" one location at a time |
| Random-feeling failures | Player blames dice, quits | State-driven incidents, warnings before failures, "why" explanations everywhere |
| Balance complexity | Many interacting systems | Headless sim + automated balance runs over thousands of seeded days |
| Scope creep | Never ships | Phase gates in §11 |
| Spec gaps for implementing models | Weaker models guess, guesses diverge | Exact formulas, data schemas, state definitions, acceptance tests per system |

## 13. Open decisions (need owner input)

| # | Decision | Options | Draft recommendation |
|---|---|---|---|
| D1 | Takeover tiers | (a) difficulty preset as in §5 (b) honest pricing where every tier is a trade-off | (b), with a separate Easy/Normal/Hard modifier |
| D2 | Platform | Mobile / desktop / web | Web-first PWA, mobile-friendly layout |
| D3 | Tech stack | TypeScript web / Godot / Unity | TypeScript (most testable, best fit for a UI-heavy sim) |
| D4 | Setting | Generic city / specific country, cuisine, currency | Pick one concrete setting; it drives dishes, wages, festivals, incidents |
| D5 | Service phase | Watchable real-time sim / instant day resolution | Real-time with pause and speed, skippable |
| D6 | Tone | Serious sim / light and humorous | Grounded with dry humour in incident writing |
| D7 | Monetisation | Premium / free | Affects nothing in design as long as there are no ads or IAP (offline) |
| D8 | Session length target | 5-minute mobile sessions / 1-hour desktop sessions | Drives day length and UI density |

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

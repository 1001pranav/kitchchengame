# 01 — Game Design Document

**Working title:** Kitchen Chain · **Platform:** Android + iOS phones, portrait, fully offline ·
**Engine:** Flutter + Flame · **Session:** 5 minutes = 1 game day

This document says **what the game is and what the rules are**. Exact formulas are in
`02-simulation-spec.md`; data shapes in `03-data-schemas.md`. If this document and 02
disagree on a number, **02 wins**. All numbers anywhere are starting values for tuning
(see `06-economy-and-balance.md`).

---

## 1. Pitch

You buy an existing, already-running restaurant with limited capital and a loan. You
inherit its staff, equipment, lease, reputation and hidden problems. You are a hands-on
owner: you hire, schedule, buy, price, repair and borrow, and when the place is
short-handed you take orders, carry plates, work the till and even cook. Survive, become
profitable, open more locations, turn them into a chain, then run several brands.

## 2. Pillars

1. **You inherit a mess, not a blank slate.**
2. **Problems are the content.** Staff, ingredients and machines fail in connected ways.
3. **Every problem has more than one answer, and each costs something.**
4. **Your job changes as you grow.** Getting off the floor is a goal in itself.
5. **Readable simulation.** The player can always find out *why* something happened.

**Realism goal:** the player should come away understanding why running a restaurant is
hard. Causes and effects are realistic; time, margins and feedback speed are compressed.

## 3. Game flow

```
New game → pick difficulty → pick cuisine theme → takeover market (5 offers)
  → optional due diligence → buy → Day 1
Day loop:  PREP → SERVICE → CLOSE → (next day)
```

### 3.1 Calendar

- 7 days per week (Mon–Sun), 4 weeks per month (28 days), 12 months per year (336 days).
- Seasons: months 1–3 spring, 4–6 summer, 7–9 autumn, 10–12 winter.
- Weekly events fall on **Sunday close**: payroll, rent, loan instalment, weekly report.
- Monthly events fall on **day 28 close**: utilities bill, tax, licence checks, monthly report.

### 3.2 Day phases

| Phase | Real time | Timed? | What happens |
|---|---|---|---|
| Prep | ~1 min | No | Deliveries arrive, absences revealed, overnight incidents, rota, orders for tomorrow, 86 dishes |
| Service | 3 min at 1× | Yes, pausable, 2×, auto-run | 360 ticks, 11:00–23:00. Customers, kitchen, floor tasks, incidents |
| Close | ~1 min | No | Spoilage, wear, morale, reputation, day report, weekly/monthly bills |

The player may quit at any moment; the game resumes at the same phase and tick.

### 3.3 Stages

| Stage | Name | Enter when | Unlocks |
|---|---|---|---|
| 1 | Takeover | Game start | Core operations |
| 2 | Stable | 4 consecutive profitable weeks AND reputation ≥ 3.5 | Marketing, training, renovation, supplier contracts, auto-order policy |
| 3 | Second location | Cash ≥ 60,000 AND reputation ≥ 4.0 AND no missed loan payment in last 8 weeks | Location market, branch managers, policies |
| 4 | Chain | 3 locations, each profitable for 4 consecutive weeks | Central kitchen, bulk contracts, regional manager, brand reputation |
| 5 | Group | Company valuation ≥ 2,000,000 | Second brand (new cuisine theme), acquisitions, franchising |

Each stage has 3–5 optional objectives with rewards (listed in `04-content-catalogue.md`).

### 3.4 Losing and winning

- **Bankruptcy:** cash < 0 at close for 3 consecutive days with no lifeline taken, or 3
  missed loan instalments in a row → game over screen with a "what went wrong" timeline.
- **Lifelines** (each usable when cash < 0): emergency loan (triple interest), sell
  equipment (50% of resale value, immediately), sell a location, investor (cash now for a
  permanent 20% of weekly profit; once per game).
- **Winning:** completing Stage 5 objectives shows an ending and a final valuation
  score; sandbox play continues.

## 4. Starting choices

### 4.1 Difficulty modifier

| | Easy | Normal | Hard |
|---|---|---|---|
| Loan interest | ×0.75 | ×1.0 | ×1.3 |
| Incident frequency | ×0.75 | ×1.0 | ×1.25 |
| Customer patience | ×1.15 | ×1.0 | ×0.9 |
| Ingredient price volatility | ×0.5 | ×1.0 | ×1.5 |

### 4.2 Cuisine theme

Italian, Chinese, Mexican, Indian, or **Mixed**. A theme is a content pack (dishes,
required kitchen stations, name pools, festivals, a few incidents, visual skin). Themes
never change rules. Every pack fills the same 12-dish template so balance is shared.
*Mixed* lets the menu draw from all packs — wider appeal (+10% demand) but more
ingredients to stock, more station types to own, and cooks work 10% slower.
**MVP ships Italian only**; the others are added in Phase 4 using the same template.

### 4.3 Takeover tiers (honest pricing)

Starting capital: 100,000 coins. Price above that is financed by the starting loan.

| Tier | Price | Loan | Cash left | Staff | Equipment | Reputation | Location | Hidden problems |
|---|---|---|---|---|---|---|---|---|
| Excellent | 300,000 | 220,000 | 20,000 | 12, skill 65–85, morale 75 | 85–95 | 4.5 | Prime | 0 |
| Best | 220,000 | 140,000 | 20,000 | 10, skill 55–75, morale 65 | 70–80 | 4.0 | Good | 1 |
| Good | 150,000 | 70,000 | 20,000 | 8, skill 40–65, morale 55 | 55–65 | 3.5 | Average | 2 |
| Bad | 80,000 | 0 | 20,000 | 7, skill 25–50, morale 40 | 35–45 | 2.5 | Weak | 3 |
| Worst | 30,000 | 0 | 70,000 | 6, skill 15–40, morale 25 | 15–35, one broken | 1.5 | Poor, overpriced lease | 4–5 |

Each new game generates one offer per tier from the seed. **Due diligence** costs 2,000
coins per offer and reveals half of its hidden problems (rounded up).

**Hidden problems pool:** unpaid supplier debt; pending health violation; head chef
planning to quit; pest infestation starting; fridge about to fail; cashier skimming;
lease rent increase in week 12; overdue licence; staff feud; fake reviews about to be
removed (reputation drops 0.5). Details in `05-incident-catalogue.md`.

## 5. The owner

The owner is a character on the floor during service. The owner is in **one place at a
time** but can travel between locations during the day (§5.4).

### 5.1 Floor work

The owner can do any task: seat guests, take orders, deliver food, take payment, clear
tables, wash dishes, cook. Two ways to direct the owner:

- **Tap a task marker** → it joins the owner's queue (max 3 queued). The owner walks
  there and does it.
- **Cover a role** → tap a role button (Server / Till / Kitchen / Dishes); the owner
  automatically takes the oldest waiting task of that role until told otherwise.

No timing or accuracy is tested. Owner skills are fixed: service 60, till 60,
cleaning 50, **cooking 35** (slow and mediocre — a last resort when a cook is absent or
the kitchen is swamped).

### 5.2 Costs of floor work

- **Energy** (0–100). Working drains it; resting overnight restores it. Low energy
  causes mistakes; repeated exhaustion forces a rest day.
- **Attention.** While the owner has a task in progress, new incident cards wait with a
  countdown, and "observation" incidents (catching theft, spotting sloppy portioning)
  cannot trigger.
- **One place at a time.** Other locations run without the owner while the owner is
  elsewhere or on the road.

### 5.3 Auto-run

When every role has at least one working staff member, the player may toggle **auto-run**:
service plays at 4× without owner tasks and pauses only for incidents.

### 5.4 Running several restaurants (Stage 3+)

All locations open at the same time and their services run **simultaneously, tick for
tick**. The player watches whichever location the owner is at and can look at the others
through a live summary strip.

- **Travel.** At any moment the owner can leave for another location. Travel takes
  time (the owner is nowhere for a while and can do nothing) and costs energy. A typical
  day allows two, at most three, locations — exactly like a real owner driving between outlets.
- **Phone.** Incidents at other locations reach the owner as a call. The owner can decide
  by phone, but options that need the owner physically there are unavailable, and
  outcomes are a little worse than in person. Unanswered calls are decided by the manager.
- **Standards slip without you.** A location the owner has not visited for a while
  gradually gets slower, dirtier, more wasteful and easier to steal from. A good manager
  delays this; nothing prevents it forever. A proper visit resets it.
- **Any restaurant can fail on its own.** A location that keeps losing money enters
  *crisis*; left alone it loses staff and reputation until it must be closed, and the
  losses can drag the whole company into bankruptcy.
- **The game must teach why.** Every location report names its top causes in plain
  words ("Not visited for 12 days: service 10% slower", "Manager approved cheap repairs
  three times: oven failed again"). The player should always be able to answer "why is
  that branch failing?" from the report alone.

The lesson is the real one: you cannot be everywhere, so you must hire well, set
clear policies, and choose where your presence matters most today.

## 6. Systems

### 6.1 Staff

- **Roles:** head chef, line cook, prep cook, dishwasher, server, cashier, cleaner;
  from Stage 3: manager.
- **Attributes (0–100):** skill, reliability, morale, loyalty, honesty, fatigue. Plus
  daily wage and 0–2 traits.
- **Hidden information:** on hire, skill is shown as a range (±15) and reliability /
  honesty are hidden; they are revealed after 7 worked days (14 for honesty).
- **Actions:** hire (from 3–5 weekly applicants), fire (severance = 7 days' wage;
  morale hit to others), raise, train (cost + days; skill +5–10), set weekly rota,
  give day off, warn, promote (line cook → head chef, server → manager).
- **Dynamics:** absence, lateness, quitting, wage demands, fatigue from too many
  consecutive days, morale from pay, workload, tips, and how the owner handles incidents.
- **Traits:** see `04-content-catalogue.md`.

### 6.2 Inventory and suppliers

- Ingredients have storage type (dry / chilled / frozen), shelf life in days and base cost.
- Stock is held in **batches** with days-left and quality; used oldest first; expires at close.
- Storage capacity per type comes from equipment (shelves, fridge, freezer).
- Orders placed today arrive at tomorrow's prep. Suppliers differ in price, quality,
  reliability, minimum order and credit terms. Six suppliers: three generalists
  (budget / standard / premium), two specialists, and a pricey same-day cash-and-carry.
- Prices drift daily within a band and spike with season and incidents.
- From Stage 2: **par-level auto-order** (top each ingredient up to a chosen level).

### 6.3 Equipment and premises

- Cooking stations (theme-dependent): stove, oven, fryer, grill, wok, tandoor.
- Support: fridge, freezer, dry shelves, dish machine, exhaust hood, POS, AC, generator.
- Each has condition 0–100. Condition wears daily; low condition raises breakdown chance
  and lowers food quality. A broken unit provides nothing until repaired.
- Maintenance (cheap, restores some condition), repair (after breakdown; choice of
  technician), replace (new or second-hand).

### 6.4 Menu

- The theme pack offers 12 dishes; the restaurant's menu is any subset of 6–12 (Mixed:
  6–16 from all packs). Each dish has a station, prep time, skill requirement and recipe.
- The player sets each price between 60% and 180% of base price.
- Per-dish stats shown: food cost %, margin, units sold, times unavailable.
- A dish can be **86'd** (disabled) at any time.

### 6.5 Customers and reputation

- Customers arrive in groups of 1–6 belonging to a segment (office, family, student,
  tourist) with different patience, spend and price sensitivity.
- Each group moves through: wait for table → order → wait for food → eat → pay → leave.
  Exceeding patience at any wait makes them walk out.
- Each group produces a satisfaction score (food, waiting, value, cleanliness) → star
  rating. Reputation moves toward the day's average; it falls twice as fast as it rises.

### 6.6 Finance

- One company cash balance. Daily P&L per location; weekly and monthly statements.
- Costs: ingredients, wages (weekly), rent (weekly), utilities (monthly), maintenance
  and repairs, marketing, loan instalments (weekly), tax (monthly, 10% of positive
  monthly profit), licences.
- **Loans:** up to 3 at a time. Credit limit depends on valuation and payment history.
- **Valuation** drives Stage 5 and the end score.

### 6.7 Hygiene and compliance

- Hygiene 0–100 per location: falls with customers served, missing cleaner/dishwasher,
  pests, broken hood; rises with cleaning.
- Health inspection: random (about once per 8 weeks) or triggered by complaints.
  Outcome by hygiene: ≥ 80 pass (+reputation), 50–79 warning + fine, < 50 closed 2 days + fine.

### 6.8 Marketing (Stage 2)

Flyers (cheap, small, short), local ads (medium), promotion day (discount, large
demand spike, low margin), food blogger (expensive, reputation gain if the visit goes well).

### 6.9 Incidents

Cards with a situation and 2–4 options. Triggered mostly by state, partly by chance.
During service they have a countdown; ignoring one applies its default (usually worst)
option. Full list and rules in `05-incident-catalogue.md`.

### 6.10 Expansion (Stages 3–5)

- **New location:** choose from a market of sites (new build) or failing restaurants
  (takeover, same generator as game start).
- **Manager:** required for every location the owner is not at. A manager runs prep
  using the location's **policies** and resolves incidents automatically with quality
  depending on manager skill; a dishonest manager skims.
- **Unattended locations** run the same service simulation at the same time as the one
  being watched (§5.4); the owner can travel to them or decide their incidents by phone.
- **Closing a location:** sell equipment, pay severance and a lease-break fee of 4 weeks' rent.

#### How the chain grows and what the owner still does

**Money.** There is one company bank balance. Every outlet's takings go into it and
every outlet's bills come out of it, so profitable outlets automatically fund weak ones
and pay for the next opening. The player never taps to "collect" — but the flow is
always visible: each outlet shows what it **contributed** to (or **drew** from) the
company each week, what was invested in it in total, and how much of that it has paid back.

**Opening the next outlet** costs a lump sum (purchase or fit-out, equipment, lease
deposit) plus an opening reserve, and a new outlet usually loses money for its first
weeks. Expanding too early on the back of one good outlet is the classic way to lose both.

**Investing in existing outlets.** From anywhere, the owner can train and promote staff,
give raises, replace or add equipment, add tables (renovation) and run marketing at any
outlet. The owner can also **transfer staff** between outlets — sending a trained head
chef or a promoted server-turned-manager to open the new place is the strongest way to
start it well, and it leaves a hole in the old one.

**Managers run the day, the owner runs the business.** A manager handles rota, ordering,
routine maintenance and small situations within a spending limit. Everything bigger
comes to the owner as a **request**. The owner alone decides:

| Owner only | Manager (within standing orders) |
|---|---|
| Open, buy or close an outlet | Daily schedule |
| Hire, fire, pay and bonus of managers and head chefs | Ordering stock up to keep-in-stock levels |
| Menu and price level | Routine servicing of equipment |
| Spending above the manager's limit (repairs, replacements, hiring, raises) | Small situations below the spending limit |
| Loans and marketing budgets | Hiring/raises only if the owner allows it in standing orders |
| Staff transfers and promotions | |
| Standing orders themselves | |

**The owner's day at chain size** (still about five minutes):
1. *Owner's desk* in Prep — a short inbox of requests from all outlets (approve / deny /
   "do it cheaper"), yesterday's one-line result per outlet, and warnings.
2. Choose where to be today (and whether to travel mid-day).
3. Service — work or simply be present at the chosen outlet; take calls from the others.
4. Close — company result, worst outlet first, with reasons.

Being present is never wasted: a visit stops standards slipping, lets the owner catch
theft and sloppiness, and **coaches the manager** (their skill grows a little per
visit). An owner who only reads reports gets weaker managers and worse outlets over time.
- **Policies** per location: par levels, price level, maintenance threshold, wage band,
  overtime allowed, incident stance (frugal / balanced / quality-first).
- **Stage 4:** central kitchen (prep done centrally: −prep time, +fixed cost), bulk
  contracts (−ingredient cost for committed volume), brand reputation (average of
  locations; a scandal anywhere hits all).
- **Stage 5:** second brand = new theme pack with separate brand reputation;
  acquisitions; franchising (weekly fee income, no control, reputation risk).

## 7. What is deliberately NOT in the game

No network features, accounts, ads or in-app purchases. No dexterity mini-games. No
real currencies or real brand names. No decorating/interior design mode in MVP. No
individually simulated seats, plates or cutlery. No alcohol licensing system.

## 8. Phases of delivery

| Phase | Contents |
|---|---|
| P0 | Simulation core only, run from the command line; balance bot |
| P1 (MVP) | Stages 1–2, Italian theme, one restaurant, all §5–§6.9 systems, mobile UI, save/load |
| P2 | Stage 3–4: multiple locations, managers, policies, chain systems |
| P3 | Stage 5: brands, acquisitions, franchising |
| P4 | Chinese, Mexican, Indian, Mixed themes; scenarios; localisation; polish |

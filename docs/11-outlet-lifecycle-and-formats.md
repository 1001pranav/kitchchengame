# 11 — Outlet Lifecycle and Outlet Formats

Two problems this document solves:

1. **A finished outlet must not stay finished.** If a well-run outlet earned the same
   forever, the player would have nothing to do there and nothing to learn.
2. **A new outlet must not be the first outlet again.** Each one has to bring something
   new *and* leave the earlier ones needing attention.

It also fixes the division of labour: **the manager keeps an outlet running; only the
owner can make it grow.**

Part A applies from the first restaurant (Phase 1). Parts B–D are Phase 2+.
Formulas follow the conventions of `02-simulation-spec.md`; constants go in `balance.json`.

---

## A. Why a good outlet slowly gets worse (Phase 1)

Five slow forces act on every outlet. None is random; each is shown to the player with
its current effect and what would reverse it. A manager never reverses any of them.

### A.1 Buzz — people forget you

`buzz` ∈ [0, 1] per outlet. Takeover starts at 0.5, new build at 0.8 (opening hype).

```
at close:  buzz = max(0, buzz − BUZZ_DECAY (0.01))
buzzFactor = 0.90 + 0.20 × buzz            (multiplies demand, doc 02 §5.1)
```

| Action | Buzz gained |
|---|---|
| Flyers | +0.10 |
| Local ad | +0.25 |
| Promotion day | +0.15 |
| Food blogger visit that goes well | +0.30 |
| Menu rework (A.2) | +0.10 |
| Renovation | +0.30 |
| Award or gold badge (Part D) | +0.40 |

Capped at 1. Gains from flyers, local ads and promotion days are multiplied by the
campaign's rolled outcome (doc 02 §13.1): a flop adds no buzz at all, a big hit can fill
the gauge in one go. The short-term demand boosts in doc 02 §13 are unchanged and add on top.
With no promotion at all, buzz reaches 0 in 50–80 days and demand settles 10% below neutral.
(Decay was 0.02; at that rate one local ad a month could not keep up — measured −10% demand
for the competent bot — so it was halved.)

### A.2 Menu freshness — regulars get bored

`freshness` ∈ [0, 1] per outlet, starts at 0.6.

```
at close:  freshness = max(0, freshness − FRESHNESS_DECAY (0.01))
freshnessFactor = 0.94 + 0.10 × freshness   (multiplies demand)
```

- **Rotate a dish:** enabling a dish that has been off the menu ≥ 14 days: +0.25, at
  most once per 7 days.
- **Menu rework:** 800 coins, head chef unavailable 1 day, requires head chef skill ≥ 50:
  freshness = 1.
- **Specials (Phase 4 content):** each theme gains 6 extra dishes the head chef can
  develop (1,500 coins, 3 days, chef skill ≥ dish requirement); adding one: +0.4.

### A.3 Equipment ages

Each unit has `ageDays`. `maxCondition = max(60, 95 − 5 × floor(ageDays / 168))`.
Servicing can never raise condition above `maxCondition`, so old machines break down
more however well they are looked after. Starting age: Excellent 0–1 years, Best 1–2,
Good 2–3, Bad 3–5, Worst 5–7 (in 336-day years).

### A.4 Costs creep up

On day 1 of each year: every staff member's expected wage ×1.03 (morale then falls
until wages follow, per doc 02 §7.3), ingredient base costs ×1.02. Rent rises through
the landlord incident. Customers tolerate price rises of about 3% a year: the reference
price for `priceIndex` and `valueScore` also rises ×1.03 yearly, so standing still on
price slowly loses margin and raising in step costs no goodwill.

### A.5 Success attracts rivals

`competition` ∈ [0, 0.5] per outlet, starts at 0.

```
weekly:  +0.01 if reputation ≥ 4.0 and the week was profitable;  −0.005 otherwise (floor 0)
competitionFactor = 1 − 0.30 × competition
```
Renovation or a gold badge: competition −0.10. The `inc_competitor_opens` incident adds
+0.10 on top of its temporary effect.

### A.6 What this does to the numbers

All three demand factors are neutral (≈ 1.0) at buzz 0.5, freshness 0.6, competition 0.
A neglected but well-operated outlet drifts to about **−12% demand in two months and
−15% by week nine** (measured: −12% in weeks 5–8), and
further as rivals arrive — enough to turn a Good-tier profit into a small loss. Add to
doc 06 targets: the *passive* bot must show this decline; the *competent* bot (now also
buying one local ad per 4 weeks and a menu rework per 8 weeks) must hold demand within
±5% of neutral at a marketing cost of 2–4% of revenue (measured: −3% demand at 3.4% of
revenue with the prices in doc 02 §13).

### A.7 Showing it

Each outlet has a **Health** card with five gauges (Buzz, Menu freshness, Equipment age,
Cost pressure, Competition), each with a trend arrow, its effect in percent, and one
suggested action. The weekly report says, for example, "Demand −9% vs two months ago:
buzz faded (−6%), menu stale (−3%)."

## B. Manager keeps it running, owner makes it grow (Phase 2)

| Keeps the outlet running — manager | Makes it profitable — owner only |
|---|---|
| Schedule, absences, staff mood | Marketing and promotions |
| Ordering stock | Menu, menu rework, specials, prices |
| Servicing and repairs within limit | Replacing ageing equipment, renovation, more tables |
| Small situations | New sales channels and formats (Part C) |
| Raising requests | Staff development: training plans, promotions, transfers |
| | Answering rivals; rent negotiations |

A manager may **suggest** an owner action as a request ("Buzz is low — run a local ad?"),
raised with the probability rule of doc 02 §15.12 using their mean skill. They never do it
themselves. So an outlet with an excellent manager and an absent owner **holds, then
slowly declines** under Part A; with a cheap manager it declines fast for operational
reasons as well.

Consequence for pacing: mature outlets generate a few *strategic* decisions a month
each, not daily chores. With five outlets the owner's desk should carry roughly 2–4
growth decisions a week in total.

## C. Outlet formats — every new outlet adds something (Phase 2+)

When the player expands, the market offers **2–3 sites of different formats**. Each
format has a signature difficulty and introduces **one new system**. Once the player
has run an outlet with that system, it can be switched on at earlier outlets too where
it fits — so opening something new also gives the old outlets something new.

| # | Format | What is different there | New system it introduces | Then usable at other outlets? |
|---|---|---|---|---|
| 1 | Neighbourhood (the first restaurant) | Baseline | Core game | — |
| 2 | High street | High rent, strong weekends, rivals arrive faster (A.5 ×2) | Managers, standing orders, owner travel | n/a |
| 3 | Office district | 60% of trade in a 2-hour lunch; dead evenings and weekends | **Takeaway and delivery** | Yes |
| 4 | Mall food court | Tiny kitchen (max 6 dishes, 2 stations), rent is a share of sales, huge footfall, no table service | **Central kitchen** (prep made elsewhere and trucked in) | Yes — supplies all outlets |
| 5 | Tourist / seaside | Summer demand ×2, winter ×0.4; reviews count double | **Seasonal staff and seasonal menus** | Yes |
| 6 | Fine dining | Few tables, high prices, high skill requirements, slow turns | **Reservations, critics and awards** | Reservations: yes |
| 7 | Transport hub (station / highway) | Open two shifts a day; customers in a hurry | **Shifts** (two rotas per day) | Yes — late opening |
| 8 | Events kitchen | No dining room at all | **Catering contracts** (large pre-booked orders with deadlines) | Yes |

Order is the player's choice among what the market offers; formats 3–5 appear from
Stage 3, 6–8 from Stage 4. Stage 5's second brand (a new cuisine) can be opened in any format.

### C.1 Rules sketch per new system

These are design rules. **Before a format is implemented, its exact formulas are added
to doc 02 in the same style, with tests** — do not implement from this sketch alone.

**Takeaway and delivery (format 3).** A second stream of orders with no table: order at
the till or via a delivery platform → cook → *pack* (new task: cashier/server, 1 tick)
→ hand over. Packaging costs 0.5 coins per dish. Delivery-platform orders pay 20%
commission and add about 25% to dine-in demand; their satisfaction counts food and
waiting only. The kitchen is shared, so delivery can starve the dining room at peak —
the player sets a cap or pauses delivery during rushes.

**Central kitchen (format 4).** A separate production site (no customers) with its own
cooks and equipment. Outlets supplied by it get `prepTicks − 30%` and need lower cook
skill (−15), and pay a transfer cost per dish. It is a fixed cost that only pays off
with enough outlets, and a failure there (breakdown, late truck) hits every outlet at once.

**Seasonal staff and menus (format 5).** Temporary staff on fixed 12-week contracts
(cheaper to end, lower loyalty, hidden skill). Seasonal menu sets that give a large
freshness bonus in their season. The outlet must earn its year in one season; the
decision is whether to close in winter (no wages, rent still due, buzz lost).

**Reservations, critics and awards (format 6).** Bookings fix part of tomorrow's demand
in advance (better forecasting, but no-shows and held tables). Critics visit more often.
An annual award check (rating, food quality, consistency) grants a large buzz and price
tolerance bonus to the outlet and a small one to the brand; losing it hurts.

**Shifts (format 7).** Two services per day with separate rotas; staff fatigue and wage
bills double unless a second team is hired. The session stays five minutes: the player
plays one shift and the other auto-runs under the manager.

**Catering contracts (format 8).** Offers arrive with size, price, deadline and penalty.
Production competes for kitchen time and stock with normal service. High margin, lumpy
cash flow, reputation damage for missed deadlines.

## D. Feeling that something was achieved (Phase 2)

### D.1 Outlet badges

| Badge | Condition | Reward |
|---|---|---|
| Bronze | Outlet has paid back 50% of what was invested in it | Buzz +0.2 |
| Silver | Paid back 100% and rating ≥ 4.0 | Staff loyalty +5 at that outlet |
| Gold | 8 profitable weeks in a row with the owner present ≤ 1 day a week, rating ≥ 4.3 | Buzz +0.4, competition −0.1, and a **chain perk** |

Gold is deliberately "it runs well without me" — the real measure of a finished outlet.
A gold outlet that later has 4 losing weeks in a row drops to silver (perk kept, badge shown as lost).

### D.2 Chain perks (one per format, earned by its first gold badge)

| Format | Perk |
|---|---|
| Neighbourhood | Managers trained here start with +5 people skill |
| High street | Marketing costs −15% chain-wide |
| Office district | Delivery commission 20% → 16% |
| Mall food court | Central kitchen transfer cost −10% |
| Tourist | Seasonal staff skill revealed at hire |
| Fine dining | Head chefs chain-wide +3 skill; specials develop one day faster |
| Transport hub | Second-shift fatigue −20% |
| Events kitchen | Catering offers +1 per month at every outlet |

### D.3 Visible history

Each outlet keeps a one-screen story: bought/opened date, investment, key events,
badges with dates, staff who started there and where they are now. The Company screen
shows a map-like board of outlets with their badges.

## E. Scope warning and phasing

Part C is large: takeaway, central kitchen, seasons, reservations, shifts and catering
are each a system of roughly the size of "inventory". Build order:

| Phase | From this document |
|---|---|
| 1 (MVP) | Part A complete (buzz, freshness without specials, equipment age, cost creep, competition), Health card |
| 2a | Part B, format 2 (High street), badges D.1, history D.3 |
| 2b | Format 3 (takeaway/delivery) + its perk; playtest whether "new outlet = new system" works before building more |
| 2c | Formats 4 and 5 |
| 3 | Formats 6–8 alongside brands |
| 4 | Specials content for all themes |

Do not build formats 4–8 until 2b has been played by real people. If one new system per
outlet proves too much to learn, the fallback is three formats, not eight.

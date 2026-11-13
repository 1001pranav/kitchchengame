# 02 — Simulation Specification

Exact rules for the simulation core. Implement these literally. Every named constant
(UPPER_CASE) lives in `data/balance.json` (see `03-data-schemas.md`) — never hard-code.
Values shown are the initial values.

Conventions: `clamp(x, lo, hi)`; `rng.float()` uniform in [0,1); `rng.int(a,b)` inclusive;
`rng.chance(p)` = `rng.float() < p`; money is integer coins, round half up with `round()`
at the moment money moves; all other quantities are doubles unless stated.

---

## 1. Determinism

- One seeded RNG per save (`SimRng`, see `08-technical-architecture.md`); its state is saved.
- All iteration over collections is in a defined order (by id ascending, or insertion order).
- The simulation never reads the clock, the platform, or anything outside its state and
  the command given.
- Same save + same sequence of commands = identical resulting state. This is tested.

## 2. Time

| Constant | Value | Meaning |
|---|---|---|
| SERVICE_TICKS | 360 | Ticks in one service (11:00–23:00) |
| TICKS_PER_HOUR | 30 | 1 tick = 2 game minutes |
| LAST_SEATING_TICK | 330 | No new groups arrive after this |
| OVERTIME_TICKS_MAX | 30 | After tick 360, sim continues until all groups left or this many extra ticks |
| TICKS_PER_SECOND_1X | 2 | Presentation speed (UI only) |

Day phase state machine: `prep → service → close → prep (next day)`.

## 3. Order of operations

### 3.1 Start of PREP (`beginDay`)

1. Advance date. Compute today's season, day of week, active festival.
2. **Deliveries:** for each pending order due today, per §9.3.
3. **Absences:** for each staff member on today's rota, roll absence (§7.4).
4. **Ingredient prices:** update per §9.2.
5. **Overnight incidents:** evaluate triggers with timing `prep` (see doc 05), max 2.
6. **Forecast:** compute expected groups (§5.1 without the random term) for display.
7. Wait for player commands; `StartService` command moves to service.

### 3.2 Each service tick `t` (0-based)

1. Spawn customer groups whose arrival tick = t (§5).
2. Update waiting groups: increment wait counters; walk-outs (§6.3).
3. Complete tasks that finish this tick; apply their results (§6.2).
4. Generate new tasks from state changes.
5. Assign idle workers to waiting tasks (§6.4), staff first, then owner per §8.
6. Dish machine/dishwasher processing (§6.6).
7. Roll service incidents (§11) — at most one new incident per 30 ticks.
8. Tick down open incident countdowns; apply default option on expiry.
9. If t ≥ 360 and no groups remain (or t = 390): end service; groups remaining at 390
   are treated as walk-outs after eating if food was delivered (they pay), else unpaid walk-outs.

### 3.3 CLOSE (`endDay`), in this order

1. Sum the day's revenue, costs, tips. Tips are split equally among staff who worked (morale, §7.3).
2. Stock: decrement `daysLeft` on every batch; remove batches at 0 → waste cost recorded.
3. Equipment wear and breakdown rolls for tomorrow (§10).
4. Hygiene update (§12).
5. Staff: fatigue, morale, quit rolls, reveal hidden stats (§7).
6. Owner energy recovery (§8.3).
7. Reputation update (§6.8).
8. Marketing effects decay (§13).
9. If Sunday: payroll, rent, loan instalments (§14), new applicants, weekly report, stage checks.
10. If day 28: utilities, tax, monthly report, inspection scheduling.
11. Bankruptcy check (§14.5). Autosave.

## 4. Locations

| Class | BASE_FOOTFALL (groups/day) | Weekly rent | Segment mix office/family/student/tourist |
|---|---|---|---|
| poor | 30 | 1,800 | 20/40/35/5 |
| weak | 40 | 2,000 | 25/40/25/10 |
| average | 50 | 2,800 | 30/35/20/15 |
| good | 65 | 3,800 | 35/30/15/20 |
| prime | 85 | 5,200 | 35/25/10/30 |

Worst-tier leases override rent to 2,200 (overpriced). Tables by tier: Excellent 24,
Best 20, Good 14, Bad 12, Worst 10. Table sizes are assigned 40% two-seat, 45% four-seat,
15% six-seat (round, at least one six-seat).

## 5. Demand

### 5.1 Groups per day

```
groups = round( BASE_FOOTFALL
              × repFactor × priceFactor × dowFactor × seasonFactor
              × marketingFactor × themeFactor × eventFactor
              × (0.9 + 0.2 × rng.float()) )

repFactor      = clamp(0.25 + 0.25 × reputation, 0.4, 1.5)
priceFactor    = clamp(1.5 − 0.5 × priceIndex, 0.5, 1.3)
priceIndex     = mean over menu dishes of (price / basePrice)
dowFactor      = Mon 0.80, Tue 0.85, Wed 0.90, Thu 1.00, Fri 1.25, Sat 1.40, Sun 1.20
seasonFactor   = spring 1.00, summer 0.95, autumn 1.00, winter 1.10
marketingFactor= 1 + sum of active campaign boosts (§13)
themeFactor    = 1.10 if Mixed else 1.00
eventFactor    = product of active modifiers from incidents/festivals (default 1)
```

### 5.2 Arrival times

Hourly weights (hour 0 = 11:00): `[0.4, 1.4, 1.6, 0.8, 0.3, 0.3, 0.5, 1.0, 1.6, 1.8, 1.4, 0.5]`.
For each group: pick an hour by weighted choice, then `tick = hour × 30 + rng.int(0, 29)`;
if tick > LAST_SEATING_TICK, set to LAST_SEATING_TICK. All arrivals are generated at
`StartService` and stored sorted by tick.

### 5.3 Group properties

- Size: 1 → 15%, 2 → 40%, 3 → 15%, 4 → 20%, 5 → 6%, 6 → 4%.
- Segment: weighted by location mix; office weight ×2 for hours 1–2, ×0.5 after hour 6.

| Segment | patienceMult | spendMult (extra-course chance) | priceSensitivity |
|---|---|---|---|
| office | 0.8 | 0.8 | 1.0 |
| family | 1.0 | 1.1 | 1.0 |
| student | 1.1 | 0.7 | 1.5 |
| tourist | 1.0 | 1.3 | 0.6 |

## 6. Service flow

### 6.1 Group states

```
arriving → waitTable → waitOrder → waitFood → eating → waitBill → paying → left
                 ↘ any wait state can go to → walkedOut
```

Table states: `free → occupied → dirty → free`.

### 6.2 Tasks

| Task | Created when | Roles (in priority order) | Base ticks | On completion |
|---|---|---|---|---|
| seat | group in waitTable AND a fitting table is free | cashier, server | 1 | table occupied; group → waitOrder |
| takeOrder | group enters waitOrder | server | 2 | create order (§6.5); kitchen tickets; group → waitFood |
| cook | ticket created | headChef, lineCook | dish.prepTicks | ticket ready → deliver task (one per group when all its tickets are ready) |
| deliver | all tickets of a group ready | server | 1 | group → eating for EAT_TICKS |
| bill | group finishes eating (→ waitBill) | cashier, server (×1.5 time) | 2 | payment; satisfaction computed; group → left; table → dirty |
| clear | table dirty | server, cleaner | 2 | table free; dirtyDishes += group size × 2 |
| wash | — (continuous, §6.6) | dishwasher | — | — |

`EAT_TICKS = 12 + 3 × groupSize` (max 30). A fitting table is the smallest free table
with seats ≥ group size; groups of 1 use two-seat tables.

### 6.3 Patience

| Wait state | PATIENCE base ticks |
|---|---|
| waitTable | 10 |
| waitOrder | 8 |
| waitFood | 25 |
| waitBill | 8 |

`limit = base × segment.patienceMult × difficulty.patience × envMult` where
`envMult = 0.8` if AC is broken in summer, else 1. When a group's counter for its
current wait state exceeds the limit: → walkedOut. Walk-out before food is delivered:
no payment, tickets cancelled (ingredients already used are lost). Walk-out in
waitBill: **they leave money on the table — payment is taken** but satisfaction is as
computed with wait score 0. The waitTable counter only runs while no fitting table is free
or no seat task has been completed.

### 6.4 Task assignment and duration

Each tick, for each task type in the order `bill, deliver, takeOrder, seat, cook, clear`:
assign waiting tasks (oldest first) to idle workers whose role is listed for the task,
preferring the first-listed role, then highest skill, then lowest id.

```
duration = max(1, round( baseTicks × roleMult × (1.5 − skill/100) × fatigueMult × envMult ))
roleMult    = 1.5 when a fallback role does the task where marked, else 1
fatigueMult = 1 + max(0, fatigue − 60) / 100
```

Cook tasks additionally require a **free slot on the dish's station** (§10.2). A cook
task occupies one station slot for its duration. A cook is **not** exclusive to one
ticket: each head chef / line cook can run up to `COOK_PARALLEL = 3` cook tasks at once
(the owner: 1). A cook is "idle" for assignment while below that limit; choose the cook
with the fewest active tasks first. Cook-specific multipliers:
`× (1 − PREP_BONUS × min(2, prepCooksWorking))` with PREP_BONUS = 0.15;
`× 1.2` if the exhaust hood is broken; `× 1.1` if theme is Mixed. A worker may cook a
dish whose `skillReq` exceeds their skill, but quality suffers (§6.7). Head chef present
gives all line cooks `+5` effective skill.

### 6.5 Ordering

For each person in the group: one **main**. Then independently: starter with p = 0.40,
side with p = 0.30, dessert/drink with p = 0.35, each × segment.spendMult (clamp ≤ 0.95).
Dish choice within a course: weighted by `dish.popularity × priceAppeal` among dishes on
the menu, not 86'd and with enough stock **right now** for one portion.
`priceAppeal = clamp(1.6 − 0.6 × (price/basePrice) × segment.priceSensitivity, 0.2, 1.4)`.
If no main is available for a person: that person orders nothing and the group gets
`unavailableCount += 1`. Unavailable optional courses are silently skipped.

Ingredients are **consumed when the cook task starts** (FIFO by batch). If stock is
insufficient at that moment: ticket cancelled, `unavailableCount += 1`, the dish is
auto-86'd for the rest of the day and an event is emitted.

### 6.6 Dishes (washing-up)

`dirtyDishes` accumulates from clear tasks. Each tick:
`dirtyDishes −= WASH_RATE × workingDishwashers × (2 if dish machine working else 1) × skillFactor`
with WASH_RATE = 0.8, `skillFactor = 0.5 + skill/100`, floor at 0. The owner covering
"Dishes" counts as a dishwasher with skill 50. If `dirtyDishes > PLATE_CAPACITY`
(= 6 × table count), **no new cook task may start** (no clean plates) and a warning event fires.

### 6.7 Food quality (per ticket, 0–100)

```
quality = 0.40 × ingredientQuality      (weighted mean quality of batches used)
        + 0.40 × effectiveCookSkill     (skill, −15 if skill < dish.skillReq)
        + 0.20 × stationCondition
        − 10 if kitchen backlog (waiting cook tasks) > 2 × working cooks when started
        − 15 if any batch used has daysLeft ≤ 1 and storage was over capacity or fridge broken today
```
Clamp 0–100. A ticket with quality < 20 has a `FOOD_POISON_CHANCE` = 2% of flagging the
group as "ill" (feeds incident `inc_food_poisoning`).

### 6.8 Satisfaction, payment, reputation

Computed when the group leaves (0–100):

```
foodScore  = mean ticket quality (0 if no food delivered)
waitScore  = 100 × (1 − totalWaitTicks / totalPatienceLimitTicks), clamp 0–100
valueScore = clamp(75 − 100 × (billPriceIndex − 1) × segment.priceSensitivity, 0, 100)
cleanScore = hygiene
satisfaction = 0.40 food + 0.30 wait + 0.15 value + 0.15 clean − 10 × unavailableCount
walk-out before food: satisfaction = 10
stars = clamp(satisfaction / 20, 0, 5)
```

Payment = sum of delivered dish prices. Tip = `round(payment × max(0, satisfaction − 60) / 400)`.
If the POS is broken, bill tasks take ×2 ticks. If the cashier is dishonest see `inc_skimming`.

Daily reputation update at close, with `n` = groups that left today and `avg` = mean stars:
```
weight = min(1, n / 20)
k = REP_UP (0.05) if avg > reputation else REP_DOWN (0.10)
reputation += (avg − reputation) × k × weight        clamp 0–5
```

## 7. Staff

### 7.1 Wages

Base daily wage at skill 50: headChef 220, lineCook 140, prepCook 100, dishwasher 80,
server 100, cashier 100, cleaner 80, manager 260.
`expectedWage = round(base × (0.6 + 0.8 × skill/100))`. Staff are paid only for days
worked; overtime (6th and 7th consecutive day) is paid ×1.5.

### 7.2 Fatigue (at close)

Worked today: `+12`; `+6` more if the day was a rush (waiting tasks for their role
exceeded 5 at any tick); day off: `−30`. Clamp 0–100.

### 7.3 Morale (at close, each staff member)

```
Δ = 0
Δ += clamp((wage − expectedWage) / expectedWage × 20, −4, +2)
Δ −= 2 if fatigue > 70
Δ −= 1 if worked a rush day
Δ += min(3, tipShare / 20)
Δ += (60 − morale) × 0.02          (drift toward 60)
Δ += incident and trait modifiers
morale = clamp(morale + Δ, 0, 100)
```
Firing someone: all others −5 morale (−10 if the fired person had morale > 60; +5 if they
carried the `toxic` trait).

### 7.4 Absence and lateness (at prep, rostered staff)

`pAbsent = (100 − reliability)/400 + (0.05 if fatigue > 80) + (0.05 if morale < 30)`.
If not absent: `pLate = (100 − reliability)/300`; late staff start work at tick `rng.int(15, 60)`.

### 7.5 Quitting (at close)

`pQuit = max(0, 30 − morale)/300 × (1 − loyalty/200)`. A quitting staff member gives
notice (works `rng.int(0, 7)` more days; 0 = walks out). Emits incident `inc_resignation`
which may allow a counter-offer.

### 7.6 Hiring and training

- Each Sunday: 3–5 applicants generated; skill from a triangular distribution centred on
  `20 + 10 × reputation`; asking wage = expectedWage × `rng` 0.9–1.2. Applicants expire next Sunday.
- Training: cost `10 × current skill` coins, staff unavailable 2 days, skill `+rng.int(5,10)`,
  cap 95, morale +5. Wage expectation rises accordingly (may trigger a wage demand).
- Hidden stats reveal: skill exact + reliability after 7 worked days; honesty after 14.

## 8. Owner

### 8.1 Skills and movement
Skills: service 60, till 60, cleaning 50, cooking 35. The owner takes
`OWNER_WALK_TICKS = 1` tick to start any task (walking), then the normal duration.
The owner follows role priority rules as "any role", with `roleMult = 1`.

### 8.2 Task selection
If the manual queue (max 3) is non-empty: take its head. Else if a cover role is set:
take the oldest waiting task for that role (Server: takeOrder/deliver/seat/clear;
Till: bill/seat; Kitchen: cook; Dishes: acts as dishwasher, §6.6). Else idle. Staff are
assigned first each tick; the owner only gets tasks no staff took, except manually
queued tasks which are reserved for the owner as soon as queued.

### 8.3 Energy
- Drain: `OWNER_ENERGY_PER_TICK = 0.4` per tick working or walking (cooking ×1.5;
  covering Dishes counts as working every tick).
- Overnight recovery `+70`; a rest day (owner absent) sets energy to 100.
- Energy < 20: each completed owner task has a 15% mistake chance → bill: payment −10%;
  deliver/takeOrder: group `unavailableCount += 1`; cook: ticket quality −30.
- If energy is 0 at close on 3 consecutive days → next day is a forced rest day.

### 8.4 Attention
Incident cards that arrive while the owner is working show a countdown of
`INCIDENT_COUNTDOWN = 40` ticks (paused while the card is open, since opening pauses the
sim). Incidents tagged `observation` can only trigger when the owner has been idle for ≥ 10 ticks.

## 9. Inventory

### 9.1 Batches and capacity
Batch = `{ingredientId, qty, quality, daysLeft}`. Capacity per storage type = sum of
working storage equipment capacity. At delivery, if a type is over capacity, the excess
is still accepted but **all batches of that type lose 1 extra day at close** that day.
A broken fridge/freezer: its capacity counts as 0 and chilled/frozen batches lose
2 extra days per close while over capacity.

### 9.2 Prices
Each ingredient has a `priceIndex` (start 1.0). Daily:
`priceIndex += (1 − priceIndex) × 0.1 + (rng.float() − 0.5) × 0.06 × difficulty.volatility`,
clamp 0.6–2.0. Unit price from a supplier = `round2(baseCost × priceIndex × supplier.priceMult)`
(ingredient prices keep two decimals; the order total is rounded to whole coins).

### 9.3 Orders and delivery
Order placed in prep or close → due after `supplier.leadDays` (1 = next day's prep;
0 = arrives immediately, allowed in prep only). Order total must meet `supplier.minOrder`.
At delivery: `rng.chance(1 − supplier.reliability)` → problem: 50% late by one day, 30%
short (deliver 50–80% of each line, charge only delivered), 20% bad batch (quality −30).
Batch quality = `supplier.quality ± 5`. Payment on delivery, or after
`supplier.creditDays` if relationship ≥ 50. Relationship (0–100) +1 per on-time-paid
order, −10 per late payment.

### 9.4 Par-level auto-order (Stage 2 / managers)
At close, for each ingredient with a par level:
`qty = max(0, par − onHand − onOrder)`; order from the preferred supplier; lines below the
supplier minimum are combined, and if the total is still below minimum nothing is ordered.

## 10. Equipment

### 10.1 Wear and breakdown (at close)
`condition −= wearPerDay × (1.5 if groups today > 1.2 × forecast else 1)`.
`pBreak = BREAK_BASE (0.002) + max(0, 60 − condition) / 400`. On breakdown: `broken = true`
from tomorrow's prep and incident `inc_breakdown_<type>` is raised. During service a
breakdown can also happen via service incidents (same probability ÷ 3, rolled once at
`StartService` to pick a tick).

### 10.2 Stations
Each cooking unit provides `slots` concurrent cook tasks at its station type. The
`cold` station always has 3 slots and needs no equipment. A broken unit provides 0
slots; dishes whose station has 0 slots are auto-86'd.

### 10.3 Maintenance, repair, replacement
- Maintenance: cost 2% of new price, `condition = min(95, condition + 15)`, once per unit
  per week, unit unavailable for the next service unless done on a closed day (it is
  available if `condition` before maintenance was ≥ 50 — quick service).
- Repair options (see `inc_breakdown`): cheap (10% of price, ready tomorrow, condition 40,
  25% chance it fails again within 7 days), proper (25% of price, ready in 2 days,
  condition 70), emergency during service (40% of price, 60% chance fixed in 30 ticks, condition 50).
- Replace: new = full price, condition 100, arrives in 2 days; second-hand = 50% price,
  condition 55, arrives tomorrow. Selling a unit returns `price × condition/100 × 0.4`.

## 11. Incidents (engine rules)

Defined in doc 05. Engine rules:
- Each incident has a trigger condition, a base weight, a timing (`prep`, `service`,
  `close`) and a cooldown in days.
- Per timing point, eligible incidents (condition true, off cooldown) are collected. Total
  chance that one fires = `min(0.9, sum(weights) × difficulty.incidentFreq)`; if it fires,
  one is picked by weight. `prep` repeats the roll up to 2 times; `service` rolls every
  30 ticks with weights ÷ 12.
- Incidents marked `forced` fire when their condition becomes true, ignoring rolls.
- Each option lists effects from the effect vocabulary in doc 05; effects with a
  `chance` roll the RNG at resolution; `followUp` schedules another incident after N days.

## 12. Hygiene (at close)

```
hygiene −= groupsServed × 0.15
hygiene += 12 × workingCleaners × (0.5 + skill/100)      (owner cannot substitute at close)
hygiene −= 5 if no dishwasher worked;  −5 if hood broken;  −8 if pests flag active
clamp 0–100
```
Inspection: when scheduled or triggered, outcome by hygiene: ≥ 80 pass (reputation +0.1);
50–79 warning, fine 1,500, re-inspection in 7 days; < 50 closure for 2 days, fine 5,000,
reputation −0.5.

## 13. Marketing (Stage 2)

| Campaign | Cost | Boost | Duration |
|---|---|---|---|
| flyers | 400 | +0.08 | 3 days |
| localAd | 1,500 | +0.15 | 7 days |
| promoDay | 0 (all prices −25% that day) | +0.50 | 1 day |
| blogger | 3,000 | visit within 3 days; if that group's stars ≥ 4: reputation +0.3, else −0.2 | — |

Boosts add up, capped at +0.6 total.

## 14. Finance

### 14.1 Daily
Revenue (payments) in; ingredient deliveries, repairs, marketing and incident costs out
as they occur. `utilitiesAccrued += UTILITIES_BASE (80) + 1.2 × groupsServed + 15 × workingEquipmentUnits`.

### 14.2 Weekly (Sunday close), in this order
1. Wages for days worked (incl. overtime, severance).
2. Rent.
3. Loan instalments: `payment = round(principal0 / termWeeks + outstanding × weeklyRate)`.
   Base `weeklyRate = 0.004 × difficulty.interest`; default `termWeeks = 52`.
   If cash is insufficient for an instalment: it is missed → penalty 5% of the payment
   added to outstanding, `missedPayments += 1`, credit score −15. Wages and rent are
   always paid (cash may go negative).
4. Operating profit of the week = revenue − all costs except loan principal.

### 14.3 Monthly (day 28 close)
Utilities accrued are paid; tax = 10% of the month's positive profit; licence fee 500.

### 14.4 Credit and valuation
```
creditScore: start 60; +1 per on-time instalment; −15 per miss; clamp 0–100
creditLimit = max(0, valuation × 0.4 × creditScore/100 − totalOutstanding)
valuation   = cash + Σ equipment resale + 40 × avgWeeklyOperatingProfit(last 8 weeks, floor 0)
            + 20,000 × Σ location reputation − totalOutstanding
```
New loans: any amount ≤ creditLimit, term 26/52/104 weeks, rate
`0.004 × difficulty.interest × (1.6 − creditScore/100)`.

### 14.5 Bankruptcy
`negativeDays` counts consecutive closes with cash < 0. At 1: lifeline offer incident
(forced). At 3: game over. Also game over when `missedPayments` reaches 3 in a row
(reset to 0 by an on-time payment).

## 15. Unattended locations (Phase 2)

For each location without the owner, in id order, `beginDay` → manager applies policies
(rota = all available staff respecting max 6 consecutive days; auto-order; maintenance
when condition < policy threshold) → service runs all ticks with no owner → `endDay`.
Incidents are auto-resolved: option chosen by the policy stance; outcome chances are
shifted by `(managerSkill − 50)/200`. Manager skimming: if honesty < 40, daily
`rng.chance((40 − honesty)/100)` → 3% of the day's revenue disappears (shows as
"unexplained variance" in the weekly report; an audit action reveals it).

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
8. Marketing effects decay (§13). Buzz, menu freshness, equipment age, competition and
   yearly cost creep update (doc 11 Part A).
9. If Sunday: payroll, rent, loan instalments (§14), new applicants, weekly report, stage checks.
10. If day 28: utilities, tax, monthly report, inspection scheduling.
11. Bankruptcy check (§14.5). Autosave.

## 4. Locations

| Class | BASE_FOOTFALL (groups/day) | Weekly rent | Segment mix office/family/student/tourist |
|---|---|---|---|
| poor | 30 | 1,800 | 20/40/35/5 |
| weak | 40 | 2,000 | 25/40/25/10 |
| average | 55 | 2,800 | 30/35/20/15 |
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
              × buzzFactor × freshnessFactor × competitionFactor     (doc 11 Part A)
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

**Stand-in roles.** With one person per role and a six-day week, some role is unstaffed
on most weekdays. When a role has nobody working, its tasks may be taken by a stand-in
at ×1.5 time and skill −15: wash ← cleaner, prepCook; clean (hygiene at close, at half
effect) ← dishwasher; cook ← prepCook; bill/seat ← server; takeOrder/deliver/clear ←
cashier. A stand-in only takes such a task when none of their own role's tasks is
waiting. The owner (or a working manager, §15.15) covering the role takes priority over
stand-ins.

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
moraleMult  = 1 + (50 − morale) / 500          (staff only; multiply into duration, §7.3)
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
walk-out after being seated, before food: satisfaction = 10
turned away / gave up waiting for a table (never seated): satisfaction = 30, and the group
  counts as half a group in the day's star average and in `n` below
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
worked; working on their own day off (§7.7) is overtime, paid ×1.5.

### 7.2 Fatigue (at close)

Worked today: `+12`; `+6` more if the day was a rush (waiting tasks for their role
exceeded 5 at any tick); day off: `−30`. Clamp 0–100.

### 7.3 Happiness index (stored as `morale`, 0–100)

Each staff member has a happiness index. Internally the field is `morale`; players see
"Happiness". It is **not** a running total of small bumps: each day a **target** is
computed from the factors below and happiness moves part of the way toward it, so the
player can always see what is pulling someone up or down.

```
target  = clamp(50 + Σ factor scores, 0, 100)
morale += (target − morale) × HAPPINESS_SPEED (0.15)      at close, every day
morale += one-off shocks from incident effects (type `morale`), then clamp 0–100
```

| # | Factor | Score |
|---|---|---|
| 1 | **Pay** | `clamp((wage − expectedWage) / expectedWage × 100, −20, +10)` |
| 2 | **Tiredness** | `−0.3 × (fatigue − 50)` if fatigue > 50 (down to −15); `+3` if fatigue < 30 |
| 3 | **Rest** | `+3` while their day off is their preferred weekday; `−5` in any week they worked their day off; `−5` for 14 days after a refused day-off or leave request |
| 4 | **Short-staffed shifts** | `−10 ×` (share of their last 7 worked days that were rush days) |
| 5 | **Team** | `+3` if a `mentor` works in their role; `−5` if a `toxic` colleague works at the outlet; `−5` for 14 days after a colleague was fired (`+5` instead if that colleague was toxic); `−4` while a role at the outlet has been vacant > 14 days |
| 6 | **Boss** | Outlet run by a manager: `(manager people skill − 50) / 5` (−10…+10). `+3` in any week the owner was present at the outlet (doc 02 §15.3; always true in a single-restaurant game unless the owner rested all week) |
| 7 | **Growth** | `+5` for 28 days after training, promotion or raise; `−5` if skill > 60 and none of those in the last 112 days (`ambitious`: 56 days, `−10`) |
| 8 | **Job security** | `−10` while the outlet is in crisis; `−8` while it is listed for sale; `−6` for 14 days after an inspection closure |
| 9 | **Working conditions** | `−4` AC broken (`−8` in summer); `−4` hood broken (kitchen roles only); `−3` if any station they use has condition < 40; `−3` if hygiene < 50 |
| 10 | **Recognition** | `+min(5, average daily tip share over last 7 days / 20)`; `+5` for 14 days after a bonus or the star-employee incident |
| 11 | **Personal** | `loyal` trait `+3`; `ambitious` and `toxic` act through factors 7 and 5 |

Timed entries ("for 14 days after…") are stored on the staff member as
`moodModifiers: [{key, score, untilDayIndex}]`. `explain(staffHappiness)` returns every
non-zero factor with its score; the same function computes the target.

**Outlet happiness index** = mean `morale` of the outlet's staff. **Company happiness
index** = mean over all staff. Both are shown with a trend arrow.

**What happiness does**
- Work speed: every task duration × `moraleMult = 1 + (50 − morale) / 500`
  (happy staff up to 10% faster, miserable staff up to 10% slower), applied in §6.4.
- Absence: `+0.05` when morale < 30 (§7.4).
- Quitting and leaving without notice (§7.5).
- Tips: a group's tip × `(0.8 + outlet happiness index / 250)`.
- Hiring: applicants' asking wage × `(1.15 − outlet happiness index / 400)` — unhappy
  workplaces have to pay more to attract people.

### 7.4 Absence and lateness (at prep, rostered staff)

`pAbsent = (100 − reliability)/ABSENCE_DIVISOR (1,000) + (0.05 if fatigue > 80) + (0.05 if morale < 30)`
(about 4.5% of days for a Good-tier staff member; was /400 ≈ 11%, which the prototype
showed to be the largest single cost at a managed outlet).
If not absent: `pLate = (100 − reliability)/300`; late staff start work at tick `rng.int(15, 60)`.

### 7.5 Quitting, with or without notice (at close)

`pQuit = max(0, 30 − morale)/300 × (1 − loyalty/200) × quitMult(trait)`.

When a staff member decides to quit, roll whether they **leave without notice**:

```
pNoNotice = clamp( NO_NOTICE_BASE[difficulty]
                 + (40 − morale) / 100
                 + (50 − loyalty) / 200
                 + 0.10 if they have been denied a raise or leave in the last 14 days,
                 0.02, 0.90 )
NO_NOTICE_BASE = easy 0.05, normal 0.15, hard 0.30
```

- **Without notice:** the person is removed immediately. At next prep the player sees
  "{staff} did not come in and is not answering" — no counter-offer, no severance, their
  rota slot is empty today, colleagues get the factor-5 vacancy effect if the role stays
  unfilled. Event `staffWalkedOut` with the top three negative happiness factors, so the
  report can say why.
- **With notice:** status `notice` for `rng.int(3, 7)` more days and incident
  `inc_resignation` is raised (counter-offer possible).

Fairness rule: nobody quits from a happiness the player could not see. Staff with
morale < 40 show a visible "unhappy" marker in every staff list and on their figure in
the restaurant view; morale < 30 shows "may leave". On Hard the base chance is higher,
but the warning signs are identical.

### 7.6 Hiring and training

- Each Sunday: 3–5 applicants generated; skill from a triangular distribution centred on
  `20 + 10 × reputation`; asking wage = expectedWage × `rng` 0.9–1.2. Applicants expire next Sunday.
- Training: cost `10 × current skill` coins, staff unavailable 2 days, skill `+rng.int(5,10)`,
  cap 95, morale +5. Wage expectation rises accordingly (may trigger a wage demand).
- Hidden stats reveal: skill exact + reliability after 7 worked days; honesty after 14.

### 7.7 Days off

The restaurant is **open seven days a week** — weekends are the busiest days and are
never closed. There is no shared weekly holiday. Instead **every staff member has one
day off a week, on their own weekday**, so the team rests in turns.

- Each staff member has `dayOff` (0–6) and a hidden-until-asked `preferredDayOff`.
  Preference is generated 25% Saturday, 25% Sunday, 50% uniform over Monday–Friday —
  people want the days the restaurant can least spare.
- Who decides the day:
  - **The owner** sets it with `SetDayOff(staffId, weekday)`; it applies from the next
    Monday so nobody loses or gains a day mid-week.
  - **The manager** sets it at outlets the owner is not running (§15.12 People).
  - **The staff member** can ask: incident `inc_day_off_request` ("Can I have Saturdays
    instead?" or a one-off "Can I swap to Friday this week?"). Granting gives the Rest
    bonus or a 14-day `+3`; refusing gives the 14-day `−5`.
- Default assignment at takeover: days off spread over Monday–Thursday, two staff of the
  same role never on the same day, single-holder roles on different days from each other.
- On someone's day off their role is covered by a second holder of the role, a stand-in
  role (§6.2), the working manager (§15.15) or the owner. The Days-off screen shows, per
  weekday, which roles have no primary holder.
- **Asking someone to work their day off:** `WorkDayOff(staffId)` for the coming day —
  paid ×1.5, fatigue as a normal working day (no −30 rest), Rest factor `−5` that week.
  They refuse if fatigue > 70 or happiness < 35. Nobody can be asked two weeks running.
- Fatigue (§7.2) is unchanged: a day off gives `−30`. `consecutiveDays` only grows past 6
  when a day off is worked.
- The seven-day rota grid is gone: `rota` is derived as "everyone works except on their
  `dayOff`", plus per-date overrides for swaps, worked days off and training.

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
- Maintenance: cost 2% of new price, `condition = min(maxCondition, condition + 15)`
  (`maxCondition` falls with age, doc 11 §A.3), once per unit
  per week, unit unavailable for the next service unless done on a closed day (it is
  available if `condition` before maintenance was ≥ 50 — quick service).
- Repair options (see `inc_breakdown`): cheap (10% of price, ready tomorrow, condition 40,
  25% chance it fails again within 7 days), proper (25% of price, ready in 2 days,
  condition 70), emergency during service (40% of price, 60% chance fixed in 30 ticks, condition 50).
- Replace: new = full price, condition 100, arrives in 2 days; second-hand = 50% price,
  condition 55, age 3 years, arrives tomorrow (hidden-fault rule in §15.9 step 3 from Stage 3). Selling a unit returns `price × condition/100 × 0.4`.

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
hygiene += HYGIENE_CLEAN_PCT (0.40) × (100 − hygiene) × Σ over working cleaners of (0.5 + skill/100)
                                                       (owner cannot substitute at close)
hygiene −= 5 if no dishwasher worked;  −5 if hood broken;  −8 if pests flag active
clamp 0–100
```
Cleaning recovers a share of the dirt present, so hygiene settles at a level set by
customer numbers and cleaner skill — about 79 for a Good-tier outlet with one average
cleaner, just under the pass mark — instead of pinning at 100 (the earlier flat `+12`
rule) or collapsing (a flat `+8`). Both were measured; see `docs/balance-log.md`.

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
4. **Operating profit** of the week = revenue − all running costs (ingredients, wages,
   rent, utilities, upkeep, marketing, fines). It contains **no loan money at all**.
   **Net profit** = operating profit − loan interest paid that week (principal repaid is
   not a cost). A "profitable week" in stage conditions, badges and `lossWeeks` means
   net profit > 0; the bank's affordability check and valuation use operating profit.

### 14.3 Monthly (day 28 close)
Utilities accrued are paid; tax = 10% of the month's positive profit; licence fee 500.

### 14.4 Credit and valuation
```
creditScore: start 60; +1 per on-time instalment; −15 per miss; clamp 0–100
creditLimit = max(0, valuation × 0.4 × creditScore/100 − totalOutstanding)
valuation   = cash + Σ equipment resale + 40 × avgWeeklyOperatingProfit(last 8 weeks, floor 0)
            + 20,000 × Σ location reputation − totalOutstanding
```
New loans: applied for per §14.6, term 26/52/104 weeks, base rate
`0.004 × difficulty.interest × (1.6 − creditScore/100)`.

### 14.5 Bankruptcy
`negativeDays` counts consecutive closes with cash < 0. At 1: lifeline offer incident
(forced). At 3: game over. Also game over when `missedPayments` reaches 3 in a row
(reset to 0 by an on-time payment).

### 14.6 Applying for a loan (bank decision)

`ApplyLoan(amount, termWeeks, securedLocationId?)`. The decision is **deterministic**
(no dice) so the player can learn what a bank looks at. Checks run in this order; the
first failure is the answer, returned with its reason key:

| # | Check | Result on failure |
|---|---|---|
| 1 | Fewer than 3 open loans | Rejected: `tooManyLoans` |
| 2 | No missed instalment in the last 4 weeks | Rejected: `recentMissedPayment` |
| 3 | `creditScore ≥ 30` | Rejected: `lowTrust` |
| 4 | Affordability: `(current weekly instalments + new first instalment) ≤ AFFORD_RATIO × avgWeeklyOperatingProfit(last 8 weeks)`; AFFORD_RATIO = 0.5 unsecured, 0.7 secured | Rejected: `cannotAfford` (the UI shows the largest amount that would pass) |
| 5 | `amount ≤ creditLimit` (§14.4); if secured also `amount ≤ 0.6 × saleEstimate(location)` (§14.7) | **Counter-offer** at the highest passing amount if that is ≥ 1,000, else rejected: `overLimit` |

- A **secured** loan is tied to one outlet: rate × 0.8; that outlet cannot be closed or
  sold without the loan being settled from the proceeds (§14.7). One secured loan per outlet.
  The starting takeover loan is secured on the first restaurant.
- Approved: cash is credited immediately; first instalment the following Sunday.
- After a rejection the bank will not consider another application for 7 days.
- With fewer than 8 weeks of history, the average uses the weeks available; with none
  (game start) check 4 is skipped for the starting loan only.
- **Private lender** (always available, also used by the emergency-loan lifeline): up to
  20,000, no checks, rate × 3, term 26 weeks, one at a time; a missed instalment costs
  10% penalty instead of 5% and −25 credit score.
- Early repayment (`RepayLoan`) is always allowed, no fee; fully repaying a loan gives credit score +3.

### 14.7 Selling an outlet (Phase 2)

```
saleEstimate = Σ equipment resale
             + SALE_PROFIT_MULT (20) × avgWeeklyOperatingProfit(outlet, last 8 weeks, floor 0)
             + 10,000 × outlet reputation
saleEstimate ×= 1 + badgeBonus      (bronze 0.05, silver 0.10, gold 0.20)
saleEstimate ×= 0.6 if the outlet is in crisis (distress sale)
```
Two ways to sell:
- **List it:** `ListOutlet(locationId)`. After 7–21 days (seeded) 1–3 offers arrive, each
  `saleEstimate × uniform(0.80, 1.10)` evaluated on the day it arrives (so a listed
  outlet that deteriorates gets lower offers). Offers expire after 7 days. The outlet
  keeps trading meanwhile; staff morale −1 per day while listed (they know).
- **Quick sale:** `QuickSale(locationId)` — immediate, at `0.70 × saleEstimate`. This is
  the "sell a location" lifeline.

On completion, in order: proceeds credited; the outlet's secured loan (if any) is repaid
from proceeds automatically — if proceeds are smaller, the remainder stays as an
unsecured loan at rate × 1.25; pending supplier payables of that outlet are paid;
staff transfer with the outlet (no severance; the player may transfer out up to 2 staff
before completion); the outlet is removed; chain perks already earned are kept.

Restrictions: the company's only outlet cannot be sold; an outlet under a lease lock-in
(`inc_landlord_rent` option c) cannot be sold or listed; an outlet cannot be listed
while closed by an inspection.

Selling versus closing (§15.7): closing is always possible, pays nothing for the
business and costs severance and a lease-break fee; selling pays for the business but
needs a buyer or a 30% discount.

## 15. Multiple locations (Phase 2)

### 15.1 Lockstep
All locations share one day and one tick counter. `beginDay`, each `tick()` and
`endDay` process every location in id order. `StartService` opens all of them.
Every location needs a manager except the one the owner starts the day at; a location
with neither does not open that day.

### 15.2 Managers at prep
For each location the owner is not at during prep, the manager applies its policies:
days off assigned per §7.7 and §15.12; par-level auto-order;
maintenance when condition < policy threshold. The player may still open any location's
screens and issue commands remotely (rota, orders, prices) — only floor work and
"in person" incident options need presence.

### 15.3 Owner travel
`OwnerTravel(toLocationId)` — valid in prep or service.
- In prep: instant, free (the owner chooses where to start the day).
- In service: the owner's queue is cleared, `owner.locationId = null` for
  `TRAVEL_TICKS = 20` ticks, energy `−TRAVEL_ENERGY = 6`; then the owner arrives.
  While travelling the owner does no tasks and cannot travel again.
- The owner is **present** at a location on a day if they spent ≥ `VISIT_MIN_TICKS = 60`
  service ticks there. Presence sets `location.lastOwnerVisitDayIndex = today`.

### 15.4 Incidents away from the owner
An incident at a location where the owner is not present is raised as a **call**:
- Countdown `INCIDENT_COUNTDOWN` applies. Options tagged `inPerson` are disabled.
- If the player answers: chance-based effects are shifted by `PHONE_PENALTY = −0.10`
  on their success chance.
- If the countdown expires (or the owner is travelling and the player does not answer):
  the manager decides — option chosen by the policy stance (frugal → cheapest cash
  cost; quality-first → best expected reputation/morale; balanced → middle), success
  chances shifted by `(managerSkill − 50)/200`.
- `observation` incidents never trigger at a location without the owner.

### 15.5 Neglect (standards slip)
```
graceDays = managerSkill² / NEGLECT_GRACE_SQ_DIV (70)
            (Trainee 27 → 10 days, Junior 42 → 25, Capable 57 → 46, Senior 72 → 74, Veteran 86 → 106)
neglect   = max(0, (today − lastOwnerVisitDayIndex) − graceDays)
slack     = min(NEGLECT_MAX (0.20), neglect × NEGLECT_PER_DAY (0.01))
```
The grace period grows steeply with manager skill so that the grade table in §15.14
holds: a weak manager needs the owner within days, a Senior can be left for about ten
weeks. (The earlier linear rule let every outlet hit the cap in three to four weeks
whatever the grade.)
Effects at that location while `slack > 0`:
- all staff task durations × `(1 + slack)`
- hygiene gained from cleaners × `(1 − slack)`
- ingredient consumption per cook task: each recipe line has chance `slack` of using +1 unit (over-portioning)
- skimming chance `+ slack` (below)

A visit (§15.3) resets `neglect` to 0 from the next day. `slack` and its inputs are
exposed through `explain` and listed in the location's daily report.

### 15.6 Skimming
At close, for the manager if honesty < 40, and for each cashier with honesty < 40:
`rng.chance((40 − honesty)/100 + slack)` → 3% of the day's revenue disappears. It shows
as "cash does not match sales" in the weekly report. An **audit** command (cost 500,
owner must be present that day) reveals who.

### 15.7 Location crisis and closure
- `lossWeeks` counts consecutive weeks with negative operating profit at a location.
- `lossWeeks ≥ 4` → state `crisis`: staff happiness factor 8 (job security) applies; the weekly report
  leads with the three largest negative factors versus the location's best 4-week period
  (demand, wages, waste, repairs, walk-outs, neglect, skimming).
- `lossWeeks ≥ 8` → forced incident `inc_location_failing`: (a) rescue plan — owner must
  be present 4 of the next 7 days, else (c) applies; (b) close the location;
  (c) do nothing — reputation −0.3 per week, 20% of staff give notice each week.
- Closing: equipment sold at resale value, severance for all staff, lease-break fee
  4 × weekly rent, brand reputation −0.1 (Stage 4+).
- A profitable week resets `lossWeeks` to 0 and ends crisis.

### 15.8 Company cash and outlet contribution
There is a single `company.cash`. Each location keeps a ledger:
```
weekContribution = location operating profit for the week (may be negative)
invested        += purchase/fit-out, equipment bought, renovation, training, opening losses funded
returned        += max(0, weekContribution)
paybackPct       = returned / invested
```
`invested` starts at the acquisition or opening cost. These are reporting values only;
no cash moves between accounts. They feed `explain` and the Company screen.

### 15.9 Opening an outlet

Two routes. Both end with the outlet in `locations`; a manager must be appointed before
the first day the owner is not there.

**Route A — Buy a running restaurant.** Same generator, tiers and pricing as the start
of the game (doc 01 §4.3), including hidden problems and due diligence. Offers refresh
every 28 days. Trading starts the next day.

**Route B — Start from scratch.** The player assembles the outlet in five steps; nothing
is inherited, so there are no hidden problems, no staff, no customers and no reputation.

*Step 1 — Site and lease.* Choose a site (location class and format, doc 11 Part C), a
size and a lease term.

| Size | Tables | Rent | Fit-out cost |
|---|---|---|---|
| Small | 10 | × 0.8 | × 0.7 |
| Medium | 14 | × 1.0 | × 1.0 |
| Large | 20 | × 1.3 | × 1.4 |

| Lease term | Rent | Break fee if closed early | Rent reviews |
|---|---|---|---|
| 1 year | × 1.10 | 2 weeks' rent | Yearly, +8% typical |
| 3 years | × 1.00 | 4 weeks' rent | Fixed for the term |
| 5 years | × 0.92 | 12 weeks' rent | Fixed for the term |

Deposit: 4 weeks' rent, returned on normal end of lease, lost on early closure.
**Rent is payable from the day the lease is signed**, including the fit-out period.
(Lease terms and break fees also replace the flat 4-week fee in §15.7 for outlets
opened this way; taken-over outlets have a 3-year lease with a random 26–130 weeks left.)

*Step 2 — Fit-out.*

| Level | Base cost | Build time | Starting buzz | Customer patience |
|---|---|---|---|---|
| Basic | 8,000 | 7 days | 0.6 | × 0.95 |
| Standard | 15,000 | 14 days | 0.8 | × 1.00 |
| Premium | 30,000 | 21 days | 1.0 | × 1.10 |

*Step 3 — Equipment.* For each unit the player chooses how to get it. The theme's
required stations, one fridge, one freezer, shelving and a till are mandatory; hood,
dish machine, AC and generator are optional (with the usual consequences of lacking them).

| Way | Cost | Condition / age | Arrives | Notes |
|---|---|---|---|---|
| Buy new | 100% of price | 100 / 0 | 2 days | Full resale value |
| Buy second-hand | 50% of price | 55 / 3 years | 1 day | `SECOND_HAND_FAULT (0.10)` chance of a hidden fault: true condition 35, revealed at first breakdown or after 7 days |
| Lease | `EQUIP_LEASE_WEEKLY (2.5%)` of price per week | kept ≥ 70 | 2 days | Servicing free; breakdowns fixed free by next day; no resale value; cancel by paying 2 weeks' fee |

Leasing and the second-hand fault rule apply to equipment at **every** outlet from
Stage 3 (commands `LeaseEquipment`, `ReturnLeasedEquipment`); §10.3's second-hand option
uses the same rule.

*Step 4 — People.* During the build period the outlet has its own applicant pool
(refreshes every 7 days; skill centred on `20 + 10 × brand or company average reputation`).
The player hires and/or transfers staff (§15.11). Hired staff are paid from the opening
day, not before. Minimum to open: one cook (head chef or line cook), one server, and a
manager if the owner will not be there. Missing roles are the owner's to fill in.

*Step 5 — Licence, menu, launch.* Opening licence 1,000 coins (granted within the build
period). Menu and prices chosen as usual. Optional launch campaign 2,000 coins: demand
× 1.3 for the first 7 days.

*Opening.* The outlet opens on `leaseSignedDay + buildDays`. Reputation starts at 3.0
(Stage 4+: brand reputation − 0.5, minimum 2.5), hygiene 95, freshness 1.0. For the first
28 trading days `REP_UP` and `REP_DOWN` are doubled — a new place has few reviews, so
each early customer counts twice. Opening may be postponed (rent keeps running).

**Reserve check (both routes).** The purchase or lease is refused if cash afterwards
would be below `OPENING_RESERVE_WEEKS (2)` × the outlet's estimated weekly fixed costs
(rent + wages + equipment leases); the UI recommends 4 weeks and shows the estimated
weeks until break-even.

**How the two routes compare**

| | Buy a running restaurant | Start from scratch |
|---|---|---|
| Money up front | High (pays for goodwill) | Lower, and adjustable (basic fit-out, second-hand or leased equipment) |
| Income from | Day 1 | After 1–3 weeks of rent with no sales, then a slow ramp |
| Staff | Inherited, unknown quality | Chosen by you; nobody knows the place |
| Customers and rating | Inherited (good or bad) | None; starts at 3.0 and moves fast |
| Equipment | Inherited age and wear | Your choice of new, second-hand or leased |
| Surprises | Hidden problems | Second-hand faults; slow start |
| Lease | Whatever is left on it | Your choice of term |

### 15.10 Manager authority and requests
Policy fields: `spendingLimit` (default 500), `mayHire` (default false), `mayGiveRaises`
(default false), plus those in doc 01 §6.10.
- A manager acts alone on: rota, par-level orders, maintenance, and any incident option
  or purchase whose cash cost ≤ `spendingLimit`.
- Anything else becomes a **request** `{locationId, kind, subjectId?, cost, reason}` with
  kind ∈ `hire, raise, repair, replace, training, marketing, extraStaffDay`. Managers
  raise requests from the same conditions the competent bot uses (doc 06 §6.1): a role
  uncovered ≥ 2 days in the coming week → hire; morale < 45 with wage below expected →
  raise; broken equipment above limit → repair/replace; skill below the outlet's dish
  requirements → training.
- At most `REQUESTS_PER_DAY_MAX (5)` requests are shown per day across all outlets,
  ranked by estimated weekly cash impact; the rest wait.
- Owner answers: **approve**, **deny**, or **cheaper** (where a cheaper variant exists:
  second-hand, cheap repair, half raise). A request unanswered for 3 days: the problem
  persists and the manager's morale −2 per further day.
- Manager quality: see §15.12.
- Manager bonus (owner sets 0–10% of the outlet's positive weekly operating profit):
  each 1% gives manager loyalty +1 and honesty +1 (effective, not permanent), paid weekly.

### 15.11 Coaching, transfers, upgrades
- **Coaching:** each day the owner is present (§15.3) at an outlet, its manager gains
  `+1` skill, at most once per 7 days, cap 90.
- **Transfer:** `TransferStaff(staffId, toLocationId)` in prep or close. The staff member
  is unavailable the next day, morale −5 (or +10 if transferred together with a
  promotion), loses `sameRole` familiarity: skill −5 for 7 days at the new outlet.
- **Promotion to manager:** a server, cashier or head chef with skill ≥ 60 can be
  promoted; manager skill starts at `0.6 × current skill + 10`; wage becomes the manager
  expected wage; loyalty +15.
- **Renovation:** add 2 tables for `RENOVATION_COST_PER_TABLE (1,500)` each, outlet closed
  1 day per 4 tables, up to +50% of original tables.
- All upgrade commands (train, raise, buy equipment, renovate, marketing) can be issued
  for any outlet from anywhere.

### 15.12 Manager competence

An outlet's income varies every day (§5.1) while rent, wages, loan payments and
utilities do not stop. Whether an unattended outlet stays in profit depends largely on
how well its manager handles the avoidable problems. A manager has three sub-skills
(0–100): **people**, **upkeep**, **stock**. `managerSkill` used elsewhere in this
document = their mean. Grades, profiles, wages and hiring are in §15.14.

Applied only at locations where the owner is **not** present at the relevant moment
(when the owner is there in prep, the owner's own commands are used instead).

**Stock**
- Par-level orders: per ingredient per day, ordered quantity is multiplied by
  `1 + u × (100 − stock)/200`, `u` uniform in [−1, 1]. (stock 90 → ±5%; stock 30 → ±35%:
  regular waste and sold-out dishes.)
- Bad delivery handling: with probability `stock/100` the manager rejects a bad batch
  and tops up from Cash & Carry; otherwise uses it.
- Supplier problems: if the standing supplier was late/short twice in 14 days, a manager
  with stock ≥ 60 raises a "switch supplier" request; below 60 does nothing.

**Upkeep**
- Each maintenance that is due under the policy threshold is actually done with
  probability `clamp(0.3 + upkeep/100, 0, 1)` (upkeep 70+ → always; 30 → 60%).
- Cleaning effectiveness × `(0.8 + upkeep/250)`.
- Breakdown response within spending limit: upkeep ≥ 60 chooses proper repair when cash
  allows, else cheap repair; below 60 always cheap repair (25% repeat failure, §10.3).
- Early warning: with probability `upkeep/100` a unit at condition < 45 produces a
  replace request before it breaks; otherwise the owner hears about it when it fails.

**People**
- Days off (§7.7): each Sunday the manager may reassign days off. With people ≥ 60 they
  place days off on the quietest weekdays, keep single-holder roles apart, and grant a
  staff member's preferred day whenever the role stays covered. Below 60 they leave the
  defaults and grant requests without checking coverage.
- Rota mistakes: every day, with probability `(100 − people)/300`, one staff member who
  should be working is wrongly left off (random role) — a self-inflicted short shift.
- Absence cover: when someone is absent, with probability `people/100` the manager calls
  in an off-duty staff member of the same role (paid overtime, fatigue +6).
- Fatigue care: people ≥ 60 gives a day off to anyone with fatigue > 75 if the role
  stays covered; below 60 never does (burnout and quitting follow).
- Staff happiness: through the Boss factor of §7.3 only (no separate daily modifier).
- Wage demands and resignations within authority: handled with success chance shifted
  by `(people − 50)/200`.

**Requests and incidents**
- A needed request (§15.10) is raised with probability `clamp(0.4 + relevantSkill/100, 0, 1)`
  each day the condition holds; so weak managers raise problems late or never.
- Incidents decided by the manager use the sub-skill matching the incident category
  (staff → people; equipment/premises/compliance → upkeep; ingredients/suppliers →
  stock; customers/money → mean) for the `(skill − 50)/200` shift.

**Learning and limits**
- Sub-skills are shown as ranges (±15) at hire and become exact after 28 days in post.
- A manager gains +1 in their lowest sub-skill per 28 days in post (cap 85), in addition
  to owner coaching (§15.11), which adds +1 to the sub-skill of the owner's choice.
- A manager **cannot fix structural problems**: a poor location, rent too high for the
  footfall, prices set wrong by the owner, denied requests, or missing equipment. An
  excellent manager makes an outlet lose *less* in a bad situation; only the owner can
  change the situation.

**Attribution.** Every manager action above that costs money emits an event with a
plain reason (`managerOverOrdered`, `managerSkippedMaintenance`, `managerRotaError`,
`managerCheapRepairFailed`, `managerMissedRequest`, and the positive counterparts
`managerCoveredAbsence`, `managerCaughtWearEarly`, `managerRejectedBadBatch`). The
weekly report totals their estimated cost/saving per outlet as "Manager's decisions:
−1,240 / +860".

### 15.13 Break-even
For each outlet and day the sim computes and exposes through `explain`:
```
fixedPerDay   = (weeklyRent + rostered wages for the week + loan share + UTILITIES_BASE × 7) / 7
marginPerGroup = average payment per group − average ingredient cost per group  (trailing 7 days)
breakEvenGroups = ceil(fixedPerDay / marginPerGroup)
```
`loan share` = the outlet's `ledger.invested` proportion of total weekly instalments.
The daily report shows "Served 48 parties · needed 41 to break even".

### 15.14 Manager grades, profiles and hiring

Manager skill is continuous (0–100), but managers are presented in **five grades** so
the player can read the market at a glance. Grade is derived from the mean of the three
sub-skills and updates as the manager improves.

| Grade | Mean skill | Typical daily wage | Will only join if | Expects profit bonus |
|---|---|---|---|---|
| Trainee | 20–34 | ~190 | — | — |
| Junior | 35–49 | ~235 | — | — |
| Capable | 50–64 | ~280 | — | ≥ 1% |
| Senior | 65–79 | ~330 | company average rating ≥ 3.5 | ≥ 3% |
| Veteran | 80–92 | ~370 | company average rating ≥ 4.0 | ≥ 5% |

Manager wage curve (replaces §7.1's general formula for the manager role):
`expectedWage = round(260 × (0.4 + 1.2 × meanSkill / 100))`. A Veteran costs about twice
a Trainee. If the profit bonus (§15.10) is below what the grade expects, the Boss/Pay
happiness factors treat the manager as underpaid by 10%.

**Profiles** — how the three sub-skills sit around the mean. Two managers of the same
grade can be good at different things, so the right hire depends on the outlet's problem.

| Profile | People | Upkeep | Stock | Suits |
|---|---|---|---|---|
| All-rounder | ±5 | ±5 | ±5 | Any outlet |
| People person | +15 | −5 | −10 | High turnover, unhappy team |
| Tight ship | −10 | +15 | −5 | Old equipment, hygiene trouble |
| Numbers | −5 | −10 | +15 | High waste, thin margins |

(Offsets are applied to the mean, then each sub-skill gets ±5 noise and is clamped 5–95.)

**Manager traits** (0–1 per manager, doc 04 §5): *by the book* — never exceeds the
spending limit and raises every request, even trivial ones; *cuts corners* — always the
cheapest option within authority; *ambitious* — wants a bigger job: leaves after 336
days unless promoted to a larger outlet or regional manager; *settled* — refuses
transfers but `quitMult 0.5`; *honest to a fault* — honesty ≥ 85 and reports colleagues'
skimming; *slippery* — honesty ≤ 35.

**Potential.** Each manager has a hidden `potential` (their maximum mean skill):
`current mean + rng.int(5, 35)`, cap 95. Learning (§15.12) and coaching stop at
potential. It is revealed as 1–5 stars after 56 days in post. A cheap Trainee with high
potential, coached well, becomes a Senior on a Junior's wage history — the best
long-term deal in the game and a reason for the owner to visit.

**Where managers come from**
- *Market applicants:* 3 manager applicants every 14 days. Grade is rolled from weights
  that shift with company average rating `r`:
  Trainee `30`, Junior `30`, Capable `25`, Senior `max(0, 10 + 10 × (r − 3.5))`,
  Veteran `max(0, 5 + 10 × (r − 4.0))`. Sub-skills shown as ranges (±15); profile and
  trait are hinted by one line of reference text ("previous team spoke highly of her"),
  not stated.
- *Internal promotion* (§15.11): starts at Trainee or Junior grade depending on skill,
  with `potential` +10 and loyalty +15 — they already know the business.
- *Poaching* (Stage 4+): pay a 5,000-coin signing fee to pick the grade and profile;
  loyalty starts at 30.

**What each grade means in play** (derived from §15.12, for balance checks and UI copy)

| Grade | Unvisited outlet in a sound location | Owner attention it needs |
|---|---|---|
| Trainee | Loses money from the first weeks | Even weekly visits leave a small loss; visit more or coach hard |
| Junior | Small profit for a month, then slides into loss | Weekly visit keeps it modestly profitable |
| Capable | Profitable for the first month, then roughly break-even | Visit every 1–2 weeks |
| Senior | Reliably profitable for about 12 weeks, fading after | Monthly visit; growth decisions only |
| Veteran | Profitable for about half a year if the owner still markets, fading to break-even | Growth decisions only |

Prototype measurements behind this table are in doc 06 §3a.

### 15.15 The manager works the floor

A restaurant of this size cannot carry a manager as a pure overhead: the prototype
showed a manager's wage (1,300–2,600 a week) eating a third to two thirds of a Good-tier
outlet's profit before a single mistake. So, as in real small restaurants, **the manager
is a working member of the crew**.

- The manager holds the **cashier** position (till and seating tasks) at skill = the
  mean of their three sub-skills. A managed outlet therefore needs **no cashier**; an
  outlet taken over with one can transfer, retrain (as server) or let them go.
- When another role is uncovered (absence the manager could not call cover for, a day
  off, a vacancy), the manager **fills in** like the owner on "cover": they take the
  oldest waiting task of the uncovered role at skill 50, and the till falls back to
  servers (×1.5 time, §6.2). One role at a time.
- While filling in on the floor the manager still performs prep-time duties (rota,
  orders, maintenance) — those happen before service.
- Large outlets (20+ tables, doc 02 §15.9) may hire a cashier as well; the manager then
  only fills gaps.
- The owner pays one manager wage per outlet and saves one cashier wage, so the net cost
  of a manager is roughly 600 (Trainee) to 1,900 (Veteran) a week.

### 15.16 Mastery — what the best managers add

Below Senior level a manager's skill only decides how many mistakes they make. From
skill 65 upward each sub-skill also **adds** something the outlet would not otherwise
have. This is what a Veteran's wage buys.

```
mastery(skill) = clamp((skill − MASTERY_FROM (65)) / (MASTERY_FULL (90) − 65), 0, 1)
```

| Sub-skill | Mastery effect | At full mastery |
|---|---|---|
| **Stock** — supplier negotiation | Unit prices from every supplier × `(1 − 0.08 × mastery)` at that outlet. The manager also finds deals: each Sunday with probability `mastery × 0.25`, one ingredient category is offered at a further −15% for the coming week (auto-used by par-level orders; shown to the owner as "Deal found"). | −8% ingredient cost, a weekly deal one week in four |
| **Stock** — supplier relations | Relationship with each supplier used at that outlet `+mastery` per week on top of the normal gain; credit terms arrive sooner. | +1 a week |
| **Upkeep** — preventive care | Equipment wear × `(1 − 0.30 × mastery)`. | Machines last ~40% longer |
| **People** — staff development | Every 28 days, with probability `mastery`, every staff member at the outlet with skill < 80 gains +1 skill. | Crew improves about a point a month |
| **People** — retention | `pQuit × (1 − 0.5 × mastery)`; a quitting staff member's `pNoNotice − 0.10 × mastery`. | Half the resignations |
| **People** — deputy | After 84 days in post at people mastery ≥ 0.6, the manager names a **deputy**: one staff member with skill ≥ 55 becomes promotable to manager at Junior grade with `potential + 10` (instead of Trainee). One deputy per manager per year. | A home-grown manager for the next outlet |

Mastery effects apply whether or not the owner is present (the deals and habits are the
manager's) and stop the day that manager leaves; negotiated prices lapse after 14 days.
Each effect emits an attribution event (`managerNegotiatedPrices`, `managerFoundDeal`,
`managerDevelopedStaff`, `managerNamedDeputy`) so the weekly "Manager's decisions" line
shows what the manager **earned**, not only what they cost.

Owner-run outlets get none of this: the owner's advantage is being there, not expertise.
The owner can obtain the negotiation effect only through supplier contracts
(`inc_supplier_deal`) and relationship levels.

# 05 — Incident Catalogue

Incidents are the game's main source of drama. This file defines the grammar used in
`incidents.json` and lists the 41 MVP incidents. Engine rules (rolls, cooldowns,
countdowns) are in `02-simulation-spec.md` §11.

---

## 1. Writing rules

- Title ≤ 40 characters. Body ≤ 220 characters, second person, present tense, concrete.
- 2–4 options. Option label ≤ 30 characters and starts with a verb.
- Every option shows its **known** costs before choosing (cash, time). Chances are shown
  as words: "likely" (≥ 70%), "even odds" (40–69%), "risky" (< 40%).
- No option is strictly best in all situations. The default (ignored) option is never the best.
- Tone: grounded, dry humour allowed, never mocking staff for who they are.
- After resolution, a one-line result is shown and logged to the day's events.

## 2. Grammar

### 2.1 Condition

A condition is a JSON object; all keys must hold (logical AND). Supported keys:

| Key | Meaning |
|---|---|
| `stageMin`, `stageMax` | Game stage bounds |
| `dayMin` | `dayIndex` ≥ value |
| `weekday` | list of weekday numbers (0 = Monday) |
| `season` | list of seasons |
| `cashBelow`, `cashAbove` | Company cash |
| `reputationBelow`, `reputationAbove` | Location reputation |
| `hygieneBelow`, `hygieneAbove` | Location hygiene |
| `flag`, `notFlag` | A `state.flags` key is set / not set |
| `hasStaff` | `{role?, trait?, moraleBelow?, moraleAbove?, fatigueAbove?, honestyBelow?, skillAbove?, count?}` — at least `count` (default 1) staff match |
| `hasEquipment` | `{type?, kind?, conditionBelow?, broken?}` |
| `noEquipmentWorking` | equipment type with no working unit |
| `ownerIdleTicks` | owner idle for at least N ticks (service only) |
| `ownerEnergyBelow` | owner energy |
| `stat` | `{name, below?, above?}` over today's DayStats or last week's summary (`walkouts`, `wastePct`, `groupsServed`, `profitWeek`) |
| `supplierUsed` | supplier id ordered from in last 7 days |
| `any` | list of conditions, at least one true |

When an incident has a `subject`, the matching staff member / equipment unit / supplier
(first match by `subjectFilter`, ties broken by RNG) is bound and referenced in text as
`{staff}`, `{equipment}`, `{supplier}`.

### 2.2 Effect

An effect is `{type, ...args, chance?}`. With `chance` (0–1) the effect applies only if
the roll succeeds; `else` may hold alternative effects.

| Type | Args | Result |
|---|---|---|
| `cash` | `amount` (negative = cost) or `pctOfDayRevenue` | Change cash |
| `reputation` | `delta` | Location reputation |
| `hygiene` | `delta` | Location hygiene |
| `morale` | `target: subject\|all\|role:<role>`, `delta` | One-off shock to happiness (it then drifts back toward its target) |
| `mood` | `target`, `key`, `score`, `days` | Timed happiness factor (`moodModifiers`), e.g. refused leave, bonus |
| `staffStat` | `stat`, `delta` | Change a stat of the subject |
| `staffStatus` | `status`, `days` | absent / training / notice |
| `staffLeaves` | — | Subject removed (no severance) |
| `staffFired` | — | Subject removed with severance and firing morale rule |
| `setWage` | `mult` | Subject wage × mult |
| `equipment` | `condition?`, `broken?`, `availableInDays?`, `shakyDays?` | Change subject equipment |
| `stock` | `storage?` or `ingredientId?`, `losePct` or `qualityDelta` | Change matching batches |
| `demand` | `mult`, `days` | Adds an `eventFactor` modifier |
| `patience` | `mult`, `ticks` | Temporary service modifier |
| `closeLocation` | `days` | No service for N days (wages for rostered staff still due) |
| `flag` | `key`, `value`, `days?` | Set a flag (optionally expiring) |
| `followUp` | `incidentId`, `days`, `chance?` | Schedule another incident |
| `inspection` | `days` | Schedule a health inspection |
| `ownerEnergy` | `delta` | Owner energy |
| `payable` | `amount`, `days` | Add a debt due later |
| `reveal` | `what` | Reveal hidden stat / hidden problem |
| `log` | `key` | Extra result line |

`amount` may be a number or an expression string from this fixed set:
`"dayWage"`, `"weekWage"`, `"eqPrice*<k>"`, `"dayRevenue*<k>"`, `"rent*<k>"`.

### 2.3 Full example (JSON)

```json
{
  "id": "inc_fryer_dies_service",
  "title": "inc_fryer_dies_service.title",
  "text": "inc_fryer_dies_service.text",
  "timing": "service",
  "trigger": { "hasEquipment": { "kind": "station", "conditionBelow": 60 } },
  "weight": 0.5, "cooldownDays": 5,
  "subject": "equipment",
  "subjectFilter": { "hasEquipment": { "kind": "station", "conditionBelow": 60 } },
  "options": [
    { "id": "pull", "label": "inc_fryer_dies_service.pull",
      "effects": [ { "type": "equipment", "broken": true } ] },
    { "id": "emergency", "label": "inc_fryer_dies_service.emergency",
      "effects": [ { "type": "cash", "amount": "eqPrice*-0.4" },
                   { "type": "equipment", "condition": 50, "chance": 0.6,
                     "else": [ { "type": "equipment", "broken": true } ] } ] },
    { "id": "diy", "label": "inc_fryer_dies_service.diy",
      "requires": { "hasStaff": { "role": "lineCook" } },
      "effects": [ { "type": "equipment", "condition": 35, "shakyDays": 14, "chance": 0.3,
                     "else": [ { "type": "equipment", "broken": true },
                               { "type": "staffStatus", "status": "absent", "days": 3, "chance": 0.15 } ] } ] }
  ],
  "defaultOption": "pull"
}
```

## 3. Catalogue (MVP: 41 incidents)

**How often things happen.** Under doc 02 §11 the chance that a prep roll fires is
`min(0.9, Σ eligible weights)` and the incident is then picked by weight, so a weight is
roughly that incident's chance per roll, and there are up to two prep rolls a day. Any
eligible prep incident with a weight of 0.1 or more therefore fires within days of its
cooldown ending: **for those the cooldown, not the weight, sets the frequency.** Choose
cooldowns as "about how often should this happen", e.g. 42 days ≈ four times a year.
(Balance-log entry 9: at 14 and 28 days, the price spike and the leak fired about 11 and
5 times in 26 weeks.)

**Defaults are what an ignored card does.** The passive bot (doc 06 §6.1) takes every
default, including "leave it broken" (#21), "ignore" the pests (#26) and "bucket" (#25).
Several defaults persist until someone acts, so for a player who never answers they are
fatal (balance-log entry 9: inherited pests → 7% survival for an owner who works the
floor but never answers a card). That is intended; a default must never be the best
option, and an owner who reads the card can always do better.

Format per incident — **id** · timing · trigger · weight / cooldown days, then options
`(letter) label — effects`. `*` marks the default option. "S" = the bound subject.
Percentages after an effect are chances. Amounts are coins.

### 3.1 Staff (12)

1. **inc_no_show_excuse** · prep · S = staff absent today with reliability < 50 · 0.3 / 7
   (a) Let it go — S morale +3. (b)* Formal warning — S morale −8, S reliability +5.
   (c) Dock a day's pay — cash +dayWage, S morale −12, all morale −2.
2. **inc_wage_demand** · close · S: wage < expectedWage × 0.9 or just trained · 0.3 / 14
   (a) Agree — S wage ×1.15, morale +10. (b) Offer half — wage ×1.07; 50%: morale +3, else −8.
   (c)* Refuse — S morale −15, followUp inc_resignation in 7 days (40%).
3. **inc_resignation** · close · forced when a staff member quits **with notice** (doc 02 §7.5; walk-outs without notice raise no incident) · — / 0
   (a) Counter-offer — S wage ×1.2; 60%: stays, morale = 55; else leaves after notice.
   (b)* Accept — S status notice. (c) Ask them to leave today — S leaves; all morale −3.
4. **inc_staff_conflict** · service · two staff with morale < 50, or one hot-headed · 0.25 / 10
   (a) Mediate now — owner busy 15 ticks; both morale +5. (b)* Ignore — both morale −8, their role
   durations ×1.2 for the rest of service. (c) Send S home — S absent today, S morale −10.
5. **inc_poaching** · close · S: skill > 65 and reputation of location ≥ 3.5 · 0.15 / 21
   (a) Match the offer — S wage ×1.25, loyalty +10. (b) Promise promotion — flag; if not promoted
   in 28 days S leaves. (c)* Wish them well — 70% S gives notice.
6. **inc_skimming** · service · tags observation · S: cashier/server honesty < 40 · 0.4 / 14
   (a) Fire on the spot — S fired, all morale −2, reveal honesty. (b) Quiet warning — 50%: S honesty +25;
   else continues (flag). (c)* Not sure enough — nothing; daily loss 3% revenue continues while flag set.
   *While an undetected dishonest cashier works, 3% of the day's revenue is lost at close.*
7. **inc_burnout** · prep · S: fatigue > 85 · 0.4 / 7
   (a) Give two days off, paid — cash −2×dayWage, S fatigue −60, morale +10.
   (b)* Push through — 30%: S absent 5 days (sick). (c) Day off unpaid — S fatigue −30, morale −5.
8. **inc_injury_kitchen** · service · any cook fatigue > 70 or trait clumsy · 0.15 / 14
   (a) Send to clinic, pay — cash −300, S absent 2 days, all morale +2. (b)* Bandage and carry on —
   S skill −15 today; 25%: absent 5 days and all morale −5.
9. **inc_training_request** · close · S: trait ambitious or morale > 70, stage ≥ 2 · 0.2 / 21
   (a) Pay for the course — cost and effect of Train, morale +5 extra. (b)* Not now — S morale −5.
10. **inc_festival_leave** · prep · 3 days before a festival · forced / —
    (a) Approve all — 30% of staff absent during festival, all morale +8. (b) Approve half — 15%
    absent, morale +2. (c)* Refuse — all morale −10; absence chance ×2 during festival.
    (d) Pay double to work — wages ×2 for festival days, morale +4.
11. **inc_star_employee** · close · S: skill > 75 and morale > 75 · 0.1 / 28
    (a) Bonus — cash −weekWage×0.5, S loyalty +15, all morale +2. (b)* Say thanks — S morale +2.
12b. **inc_day_off_request** · prep · S: any staff whose `dayOff` ≠ `preferredDayOff`, or a one-off swap · 0.25 / 10
    "{staff} asks to have {weekday} off." (a) Agree — permanent: `dayOff` changes from next Monday,
    Rest bonus applies; one-off: swap this week, mood +3 for 14 days. (b) Agree if they cover a
    busy day in return — 60%: accepted (as a, plus they work one extra peak shift at normal pay);
    else as (c). (c)* Refuse — mood −5 for 14 days; reveals their preferred day.
12. **inc_toxic_complaint** · close · hasStaff trait toxic · 0.3 / 14
    (a) Fire S — S fired (others morale +5). (b) Talk to S — 30%: trait removed; else all morale −3.
    (c)* Do nothing — all morale −6; followUp inc_resignation for a random other staff (30%).

### 3.2 Ingredients and suppliers (8)

13. **inc_delivery_late** · prep · forced when a delivery rolls "late" · — / 0
    (a) Buy from Cash & Carry — opens order screen (prices ×1.15). (b)* Run a short menu —
    affected dishes 86'd automatically. (c) Call and complain — 40%: 10% refund; relationship −5.
14. **inc_bad_batch** · prep · forced when a delivery rolls "bad batch" · — / 0
    (a) Reject it — batch removed, no charge, relationship −5. (b)* Use it anyway — keep (quality −30).
    (c) Use for staff meals only — batch removed, all morale +2, pay half.
15. **inc_price_spike** · prep · random ingredient category · 0.2 / 42
    Category price index ×1.5 for 7 days. (a)* Absorb it. (b) Raise affected dish prices 10%
    — applied automatically. (c) 86 the costliest dishes for a week.
16. **inc_fridge_warm** · prep · fridge condition < 50 · 0.4 / 7
    (a) Emergency service — cash −eqPrice×0.1, condition +20. (b)* Hope — 35%: fridge broken, chilled stock
    loses 60%. (c) Move stock to ice boxes — cash −150, chilled daysLeft −1, then maintenance tomorrow.
17. **inc_supplier_cash_only** · prep · payable overdue or relationship < 20 · forced / 14
    (a) Pay what we owe — clears payables to S. (b) Switch supplier — relationship set 0, S unavailable 28 days.
    (c)* Accept cash on delivery — creditDays 0 for S for 56 days.
18. **inc_pilferage** · close · tags observation-at-close: stock variance; any staff honesty < 35 · 0.2 / 14
    (a) Lock the store room — cash −200, flag reduces future weight. (b) Stock audit — owner energy −15;
    70%: culprit revealed. (c)* Write it off — lose 5% of dry stock.
19. **inc_supplier_deal** · prep · relationship ≥ 60 with S, stage ≥ 2 · 0.15 / 28
    (a) Sign 8-week contract — S priceMult −0.08, must order ≥ minOrder×3 weekly or pay penalty 500.
    (b)* Decline.
20. **inc_shortage_seasonal** · prep · season change day · forced / —
    One produce ingredient unavailable 7 days from all but sup_premium.
    (a)* Acknowledge. (b) Pre-order from Premium — opens order screen.

### 3.3 Equipment and premises (8)

21. **inc_breakdown** · prep · forced when equipment rolls breakdown · — / 0
    (a) Cheap repair — per doc 02 §10.3. (b) Proper repair. (c) Replace new. (d) Replace second-hand.
    (e)* Leave it broken.
22. **inc_fryer_dies_service** · service · station condition < 60 · 0.5 / 5 — see §2.3.
23. **inc_power_cut** · service · any · 0.1 / 14 (summer ×2)
    If working generator: auto-resolved, cash −100 fuel. Else: (a) Candles and cold menu — only `cold`
    station for 40 ticks; patience ×0.9. (b)* Close for the hour — no seating for 40 ticks, waiting
    groups walk out. (c) Rent a generator now — cash −800, 20-tick outage.
24. **inc_gas_out** · service · flag gas_low (set randomly, 5%/day) · forced / 10
    (a) Rush delivery — cash −400, stove/wok/tandoor/grill off 20 ticks. (b)* Wait — off 80 ticks.
25. **inc_plumbing_leak** · prep · any · 0.08 / 84
    (a) Plumber now — cash −600. (b)* Bucket — hygiene −10/day until fixed; 20%/day floods: close 1 day,
    and the flood forces an emergency plumber (cash −900), which ends the leak.
26. **inc_pests** · prep · hygiene < 55 · 0.3 / 21
    (a) Professional treatment — cash −1,200, close 1 day, hygiene +20. (b) DIY traps — cash −150;
    50%: solved; else flag pests. (c)* Ignore — flag pests; inspection in 7 days (50%).
27. **inc_pos_crash** · service · POS condition < 50 · 0.3 / 7
    (a) Pen and paper — bill tasks ×2 for rest of service; 2% revenue lost. (b) Reboot — no bills for
    10 ticks; 70% fixed. (c)* Keep fighting it — bill tasks ×3 for 30 ticks.
28. **inc_landlord_rent** · close · dayIndex ≥ 84, every 168 days · forced / —
    Rent +8%. (a)* Accept. (b) Negotiate — reputation ≥ 4: 60% → +3%; else 30% → +3%, else +10%.
    (c) Sign 2-year lock-in — +4%, cannot sell the location for 2 years.

### 3.4 Customers and reputation (7)

29. **inc_complaint_table** · service · group waitFood > 70% of patience · 0.6 / 1
    (a) Go and apologise — owner task 3 ticks; group patience +10. (b) Free dessert — cash −15, satisfaction
    +10. (c)* Leave it to the server — nothing.
30. **inc_food_poisoning** · prep · forced the day after a group flagged ill · — / 0
    (a) Apologise, refund, pay clinic — cash −500; reputation −0.1. (b)* Deny — 50%: goes public,
    reputation −0.6, inspection in 2 days; else nothing. (c) Refund quietly — cash −150; 25% goes public.
31. **inc_critic_visit** · service · reputation ≥ 3.5, stage ≥ 2 · 0.05 / 56
    The next group is a critic (flag). Their stars count ×10 in today's reputation update.
    (a) Owner serves them personally — owner queued on all their tasks. (b)* Treat like anyone.
32. **inc_big_booking** · prep · tables ≥ 12 · 0.15 / 10
    Party of 12 at a fixed tick. (a) Accept — guaranteed group (seats 3 tables), 15% no-show.
    (b) Accept with deposit — cash +200 now; 30% they decline. (c)* Decline.
33. **inc_bad_review_viral** · close · today's walkouts > 20% of groups · 0.3 / 14
    (a) Public apology + offer — cash −300, demand ×1.05 3 days. (b) Argue online — 30%: reputation +0.1;
    else −0.3. (c)* Ignore — reputation −0.15.
34. **inc_rowdy_table** · service · Fri/Sat after tick 240 · 0.2 / 7
    (a) Owner steps in — owner 5 ticks; 80% calm. (b) Ask them to leave — lose their bill; other groups
    satisfaction +5. (c)* Let it ride — all eating groups satisfaction −8.
35. **inc_competitor_opens** · prep · dayIndex ≥ 56, once per 112 days · 0.1 / 112
    Demand ×0.85 for 28 days. (a)* Hold steady. (b) Price promotion — prices −10% for 14 days
    (applied automatically), demand ×1.0. (c) Marketing push — cash −1,500, demand ×0.95.

### 3.5 Money and compliance (5)

36. **inc_inspection** · prep · forced when scheduled; else 1/56 per day · — / 28
    Outcome per doc 02 §12. If owner has ≥ 1 day notice (random 50%): (a) Deep clean — cash −400,
    owner energy −30, hygiene +15. (b)* Carry on.
37. **inc_lifeline** · close · forced when cash < 0 · — / 0
    (a) Emergency loan — amount = deficit + 5,000; rate ×3. (b) Sell equipment — choose a unit; 50% of resale.
    (c) Investor — cash +30,000; 20% of weekly profit forever (once). (d)* Do nothing — negativeDays continues.
38. **inc_tax_audit** · close · day 28, 10% · — / 168
    (a) Hire accountant — cash −800. (b)* Handle yourself — owner rest day lost; 30%: fine 2,000.
39. **inc_licence_overdue** · prep · hidden problem or 2%/month · — / 168
    (a) Pay now with late fee — cash −1,000. (b)* Delay — 25%/week: fine 3,000 + close 1 day.
40. **inc_unexpected_windfall** · prep · any · 0.05 / 28
    A film crew wants the dining room for a morning. (a) Accept — cash +1,200, service starts at tick 60.
    (b)* Decline.

## 4. Hidden problems (takeover)

Each hidden problem is a scheduled incident (or state change) created at takeover with a
due day; due diligence reveals it early (the player then sees it in the "Known issues"
list and may act first).

| Hidden problem | Implementation |
|---|---|
| Supplier debt | `payable` of 8,000–20,000 due day 14–28; then inc_supplier_cash_only. Booked as an inherited cost: it leaves cash but is not operating profit (part of what the outlet cost, not of how it is run) |
| Pending health violation | inc_inspection scheduled day 7–14; starting hygiene −20 |
| Head chef leaving | Head chef loyalty 10, morale 30; inc_resignation scheduled day 10–20 (cancelled if morale ≥ 60 by then) |
| Pests starting | flag pests from day 5 |
| Fridge about to fail | Fridge condition 30 |
| Cashier skimming | Cashier honesty 15 + trait light_fingered |
| Lease increase | inc_landlord_rent forced on day 84 at +15% |
| Overdue licence | inc_licence_overdue day 7 |
| Staff feud | Two staff morale −20; inc_staff_conflict weight ×3 for 28 days |
| Fake reviews | Reputation −0.5 on day 14–21 |

## 5. Adding incidents later

Phase 2 marks options that need the owner physically there with `inPerson: true`
(e.g. "Mediate now", "Go and apologise", "Owner steps in", "Owner serves them
personally", "Stock audit", "Deep clean") and adds `inc_location_failing` (doc 02 §15.7).

Phase 2+ adds manager, multi-location and brand incidents. Every new incident must:
use only the grammar in §2 (extend §2 first if needed), have a default option, pass the
catalogue validator, and be covered by the generic incident test (each option resolves
without error against a standard test state).

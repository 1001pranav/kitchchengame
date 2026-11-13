# 07 — UI / UX Specification

Mobile phones, **portrait only**, one-thumb use, 5-minute sessions. Flutter widgets for
all screens; a Flame `GameWidget` for the restaurant view.

---

## 1. Principles

1. **Three taps to get through Prep** when nothing is wrong ("same as yesterday" defaults).
2. **Problems come to the player.** Anything needing attention shows as a badge on the
   relevant tab and as a line in the "Needs attention" list. The player never hunts.
3. **Every number explains itself.** Tapping any figure opens a breakdown sheet
   ("Why?") listing the factors that produced it.
4. **Summary first, detail on demand.** Lists show one line per item; tap for a detail sheet.
5. **Thumb zone.** Primary actions sit in the bottom 40% of the screen. Nothing
   important in the top corners.
6. **No dead ends.** A blocked action says why and offers the screen that fixes it
   ("Not enough cash — open Finance").

## 2. Layout rules

- Design size 390 × 844 logical px; must work from 360 × 640 to tablets (content max width 600, centred).
- Respect safe areas (notch, gesture bar).
- Minimum tap target 48 × 48; minimum body text 14; numbers use tabular figures.
- Money: thousands separator, coin icon, no decimals. Negative values red with a minus sign.
- Colour is never the only signal (pair with icon or text).
- Text scale up to 1.3× must not break layouts. All strings from the localisation table.

## 3. Navigation map

```
Title ─ New Game ─ Difficulty ─ Theme ─ Takeover Market ─ Offer Detail ─ (buy)
      └ Continue / Load ─────────────────────────────────────────────┐
                                                                     ▼
                    ┌──────────────── Main shell (bottom tabs) ────────────────┐
                    │  Today │ Staff │ Stock │ Kitchen │ Money                 │
                    └───────────────────────────────────────────────────────────┘
Today tab changes with phase:  Prep board → Service view → Close report
Global overlays: Incident card · "Why?" sheet · Pause menu · Stage-up screen · Game over
Stage 3+: a location strip appears above the view (§4.11); a Company tab replaces Money.
```

## 4. Screens

### 4.1 Top bar (always visible in the shell)

`Day 12 · Fri · Spring` | cash | reputation ★ | owner energy bar | pause/menu button.
Tapping cash / reputation opens the "Why?" sheet for that value.

### 4.2 Takeover Market

Five cards, one per tier, vertically scrollable. Each card: restaurant name, tier
ribbon, price, loan needed, cash left after purchase, reputation, staff count, equipment
average condition bar, location class, weekly rent, "Known issues: ?" count.
Buttons: **Inspect (2,000)** (due diligence) and **View**. Offer Detail shows staff list
(skills as ranges), equipment list, last-4-weeks P&L sketch, known issues, and **Buy**.

### 4.3 Prep board (Today tab, phase = prep)

```
┌──────────────────────────────────────┐
│ Day 12 · Fri · Spring   ◎18,420 ★3.6 │
├──────────────────────────────────────┤
│ FORECAST   ~64 groups  (busy)        │
│ NEEDS ATTENTION (3)                  │
│  ! Marco is absent today        →    │
│  ! Fish runs out by ~19:00      →    │
│  ! Oven condition 41            →    │
│ DELIVERIES  City Foodservice ✓       │
│ TODAY'S TEAM  7 of 8   Kitchen 3     │
│   Floor 3  Till 1  Dishes 0 ⚠        │
│ I WILL COVER: [Server][Till][Kitchen]│
│               [Dishes][Nothing]      │
│                                      │
│ [ Rest today ]      [ OPEN DOORS ▶ ] │
└──────────────────────────────────────┘
```

Each attention line opens the screen that fixes it. "Fish runs out" is computed from
forecast × dish popularity vs stock.

### 4.4 Service view (Today tab, phase = service)

```
┌──────────────────────────────────────┐
│ 19:24  ▮▮▮▮▮▮▯▯▯  ◎+2,310  ⏸ 1× 2× ⏩│
├──────────────────────────────────────┤
│                                      │
│        RESTAURANT VIEW (Flame)       │
│  kitchen strip: stations + tickets   │
│  pass: ready orders                  │
│  dining room: tables, guests, staff  │
│  door: queue        till             │
│  task markers float over things      │
│                                      │
├──────────────────────────────────────┤
│ Queue: [Table 4 order][Bill T2][ — ] │
│ Cover: (Server) Till Kitchen Dishes  │
│ Waiting: order 3 · food 5 · bill 1   │
└──────────────────────────────────────┘
```

- **Task markers** (icon bubbles, min 48 px): seat, take order, deliver, bill, clear,
  cook. Colour ring shows remaining patience (green → amber → red, plus a shrinking arc).
  Tapping one adds it to the owner queue; markers already taken by staff are dimmed.
- **Owner** is a distinct figure; a dotted line shows the current destination.
- **Kitchen strip:** one column per station with slot pips (filled = in use) and a count
  of waiting tickets; red when a station has no working unit. Dirty-dish meter beside it.
- **Speed:** pause, 1×, 2×; ⏩ = auto-run (enabled only when every role is covered).
- **Incident:** sim pauses, card slides up (§4.9).
- Tapping a table/staff member/station opens a small info popover (who, what, how long).

### 4.5 Close report (Today tab, phase = close)

Page 1 — **The day in one line** ("Busy Friday. Lost 9 tables waiting for food."), then:
revenue, costs, profit (large), groups served / walked out, average stars, tips.
Page 2 — **What went wrong / right:** up to 5 ranked causes generated from the day's
events ("Fryer down 80 min → 14 dishes unavailable"), each with a fix button.
Page 3 — **Tomorrow:** forecast, staff off, stock warnings, expiring batches, order
button ("Order usual" / "Edit order").
Sunday adds the weekly statement; day 28 adds the monthly one. Button: **Next day ▶**.

### 4.6 Staff tab

Header: outlet **happiness index** with trend arrow (tap for the average of each factor).
List grouped by role: portrait, name, skill bar (or range if unknown), happiness face
(with an "unhappy" / "may leave" marker below 40 / 30),
fatigue dot, wage, today's status. Detail sheet: all stats, traits, **happiness breakdown** (each factor with its score,
worst first, and a one-tap remedy where one exists: Raise, Day off, Train), history lines,
actions (Raise, Train, Day off, Warn, Promote, Fire). Sub-tabs: **Days off** (one row per staff member with a weekday picker and a ♥ on
their preferred day once known; "Ask to work" button on their day off; below, a
seven-column coverage strip showing for each weekday which roles have no primary holder
and who would stand in) and **Hire**
(this week's applicants with asking wage).

### 4.7 Stock tab

List by storage type with capacity bars. Per ingredient: on hand, days of cover,
earliest expiry (red if ≤ 1 day), on order. Sub-tabs: **Order** (pick supplier → lines
with suggested quantities → total vs minimum order → confirm) and **Suppliers**
(price level, quality, reliability stars, relationship, credit terms).
Stage 2: par-level editor.

### 4.8 Kitchen tab and Money tab

**Health card** (on the Today tab in Close, and the outlet screen): five gauges — Buzz,
Menu freshness, Equipment age, Cost pressure, Rivals — each with trend arrow, effect in
percent and one suggested action.
**Kitchen:** sub-tabs *Menu* (dish rows: price stepper, food cost %, margin, sold
yesterday, on/off switch; warning if its station is down) and *Equipment* (condition
bars, status, Maintain / Repair / Replace / Sell; Buy new).
**Money:** cash chart (last 28 days), this week so far (P&L lines), upcoming bills
(wages, rent, loan, utilities with dates), loans, valuation, credit score.
*Loan application:* amount slider, term, optional "secure on outlet", live preview of the
weekly payment and a checklist of the bank's five checks with pass/fail **before**
applying; result screen states approved / bank's offer / rejected with the reason and
"what would change the answer". *Sell outlet* (Stage 3+): estimate with its breakdown,
List / Quick sale, incoming offers with expiry.
Stage 2 adds *Marketing* here.

### 4.9 Incident card (overlay)

Illustration strip, title, body, then 2–4 option buttons stacked. Each button: label,
cost chips (coins, time, energy), odds word. Disabled options show why. During service a
thin countdown bar shows if the card was deferred. After choosing: a result line with
the actual effects, then **OK**.

### 4.10 Other

- **"Why?" sheet:** title, the value, a list of factors with signed contributions,
  optional "How to improve" link.
- **Pause menu:** Resume, Save, Settings (sound, music, haptics, text size, speed
  default, reset tutorial), Quit to title.
- **Stage-up screen:** what you achieved, what unlocks, new objectives.
- **Game over:** timeline of the key events that led to bankruptcy, final stats, Retry
  with same seed / New game.
- **Tutorial:** contextual coach marks during the first 3 days (one concept per day:
  day 1 service and floor work, day 2 stock and ordering, day 3 staff and rota). Skippable.

### 4.11 Several locations (Stage 3+)

- **Location strip** above the restaurant view: one chip per location with name, a
  status dot (fine / struggling / crisis), live queue count, and an owner icon on the
  chip where the owner is (or a moving icon while travelling).
- Tapping another chip shows that location's live view **read-only** with two buttons:
  **Go there** (shows travel time and energy cost) and **Back**.
- **Calls:** an incident elsewhere appears as a phone card naming the location; options
  needing presence are greyed with "Only in person". A small "Manager will decide in
  0:12" countdown shows what happens if ignored.
- **Location report** (Close, one page per location, worst first): profit, then
  "Why" lines in plain words, always including days since the owner's last visit and
  its effect when non-zero.
- **Owner's desk** (top of Prep once there are 2+ locations): yesterday's result per
  outlet in one line each (profit, trend arrow, status dot); then the **requests inbox**
  — cards like "Branch 2 · Manager Li asks: replace fryer · 3,000 · 'broke twice this
  month'" with **Approve / Cheaper (1,500) / Deny**; then "Where will you be today?"
  with a suggestion ("Branch 3 — not visited for 9 days").
- **Outlet ledger** (in Company tab, per outlet): invested, paid back so far (bar),
  contribution per week (bar chart, negative weeks red), and a sentence such as
  "Branch 1 paid for 64% of Branch 3's opening."
- **Open a new outlet** flow: first screen compares the two routes side by side (doc 02
  §15.9 table). *Buy running* → the takeover market as at game start. *Start from
  scratch* → five steps (Site and lease · Fit-out · Equipment · People · Launch) with a
  **running budget bar** always visible: spent so far, weekly cost once open, cash
  left, weeks of reserve, estimated weeks to break even. Equipment step lists each unit
  with three buttons (New / Second-hand / Lease) and their trade-offs → "After
  this you will have X coins, about N weeks of running costs" (red below 4 weeks) →
  choose opening team (transfer staff / hire) → appoint manager.
- **Manager card** (hire screen and outlet screen): grade badge (Trainee / Junior /
  Capable / Senior / Veteran), three skill bars (ranges until known), wage, expected
  profit share, reference line, potential stars once known, traits, and — once in post — "This month: decisions cost 1,240, saved
  860" with the list of events behind it. Coaching choice on visit: pick which skill to coach.
- **Break-even line** on each outlet's daily bar chart of parties served.
- **Company tab:** table of locations (profit this week, trend arrow, reputation, days
  since visit, manager), crisis banner with the rescue/close choice.

## 5. Plain language and term help

The game is meant to teach how a restaurant works, so **no screen may use a trade term
without explaining it**.

- Player-facing text uses the plain names below, not the internal ones.
- Any term from the list is shown with a dotted underline wherever it appears; tapping
  it opens a small card: one-sentence meaning, one-sentence "why it matters", and a
  link to the full **Handbook** (a searchable list of all terms, in the pause menu).
- The first time a term appears in play, its card opens by itself once.
- Term texts live in `strings_<locale>.json` under `term.<id>.name / .meaning / .why`.

| Internal name | Shown to player as | Meaning shown | Why it matters shown |
|---|---|---|---|
| reputation | Rating | What customers think of you, from 0 to 5 stars | Higher rating brings more customers every day |
| group | Party | A set of customers who arrive and sit together | Each party needs a table, a server and a bill |
| walk-out | Walk-out | A party that left because they waited too long | You lose the sale and your rating drops |
| patience | Patience | How long a party will wait before leaving | Slow service empties your tables |
| 86 | Sold out / Off the menu | A dish you cannot or will not serve today | Customers who wanted it are disappointed |
| rota | Days off | Each person's weekly day off; the restaurant itself never closes | Put days off on quiet days and keep key roles apart |
| stand-in | Stand-in | Someone doing another role's work on that person's day off | Slower and less skilled than the real thing |
| negotiation | Negotiated prices | Lower supplier prices won by a skilled manager | Cuts your biggest cost; lost if that manager leaves |
| deputy | Deputy | A staff member your manager has trained to run a branch | A ready-made manager for your next outlet |
| cover a role | Fill in | You do the work of a missing staff member | It saves the shift but tires you out |
| owner energy | Your energy | How tired you are | Exhausted owners make mistakes and lose a day |
| morale | Happiness | How happy a staff member is at work, from 0 to 100 | Unhappy staff are slower, call in sick and may quit without warning |
| notice | Notice | Days a leaving staff member still works | Without notice you are short-handed tomorrow |
| fatigue | Tiredness | How worn out a staff member is | Tired staff are slow and get hurt |
| reliability | Reliability | How often they turn up on time | Unreliable staff leave you short |
| batch / daysLeft | Use-by | How many days until this stock goes bad | Expired stock is thrown away — money in the bin |
| waste | Waste | Food bought but never sold | Waste comes straight out of profit |
| par level | Keep-in-stock level | The amount you always want on the shelf | The game reorders up to this level for you |
| food cost % | Food cost | Share of a dish's price spent on ingredients | Above about 35% the dish earns too little |
| margin | Profit per dish | What is left from the price after ingredients | Popular dishes with thin profit can still lose money |
| station / slot | Cooking station | A place where one kind of dish is cooked | A broken station removes its dishes from the menu |
| condition | Condition | How worn a machine is, 0 to 100 | Worn machines break down at the worst time |
| maintenance | Servicing | A small paid check-up of a machine | Much cheaper than a breakdown |
| hygiene | Cleanliness | How clean the restaurant is, 0 to 100 | Low cleanliness fails inspections and sickens guests |
| operating profit | Profit | Money in minus the cost of running the place | This is what pays back your loan |
| cash flow | Cash in hand | Money you can spend right now | You can be profitable and still unable to pay wages |
| instalment | Loan payment | The weekly amount you repay the bank | Missing three in a row ends the game |
| credit score | Bank trust | How much the bank trusts you | Decides how much you can borrow and at what cost |
| valuation | Company value | What your whole business is worth | Unlocks the final stage and is your score |
| due diligence | Inspect before buying | Paying to look for hidden problems | Shows trouble before it becomes yours |
| hidden problem | Inherited problem | Trouble the last owner left behind | Shows up in your first weeks |
| incident | Situation | Something has happened and needs your decision | Ignoring it lets the worst option happen |
| request | Request | Your manager asking permission for something beyond their limit | Ignored requests leave problems unsolved |
| contribution | Contribution | What a branch added to or took from company money this week | Shows which branches carry the others |
| payback | Paid back | How much of what you spent on a branch it has earned back | Tells you whether opening it was worth it |
| transfer | Transfer | Moving a staff member to another branch | Strengthens one branch and weakens another |
| break-even | Break-even | The number of parties you must serve in a day to cover that day's costs | Below it the day loses money even if the room looked busy |
| fixed costs | Costs that never stop | Rent, wages and loan payments you owe whether customers come or not | A slow week still costs the same |
| manager grade | Grade | A manager's overall level, from Trainee to Veteran | Higher grades need less of your time and cost more |
| potential | Potential | How good a manager can become with experience and coaching | A cheap manager with high potential is worth investing in |
| manager skills | People / Upkeep / Stock | How well a manager handles staff, equipment and ordering | Weak skills show up as waste, breakdowns and resignations |
| buzz | Buzz | How much people are talking about your restaurant | It fades unless you advertise or do something new |
| freshness | Menu freshness | How new your menu feels to regulars | A menu that never changes slowly loses customers |
| competition | Rivals | Other restaurants competing for your customers | Success attracts them; staying the same lets them win |
| equipment age | Age | How old a machine is | Old machines break more even when serviced |
| badge | Badge | Proof that an outlet has paid for itself and runs without you | Gold badges unlock a bonus for the whole chain |
| format | Type of outlet | The kind of place it is: office, mall, tourist spot… | Each type has its own challenge and adds something new |
| secured loan | Loan against an outlet | A cheaper loan the bank can recover by taking the outlet's sale money | If you sell that outlet the loan is paid off first |
| affordability | Can you afford it | The bank compares your weekly repayments with your weekly profit | Low profit means the bank says no, however much you need it |
| counter-offer | Bank's offer | A smaller loan than you asked for | Take it, or improve your numbers and ask again |
| private lender | Private lender | Someone who lends without questions at very high interest | A last resort that can sink you |
| sale estimate | What it would sell for | The likely price for an outlet today | It falls when profit and rating fall |
| lease | Lease | Your contract to rent the premises for a set number of years | Longer is cheaper but costly to leave early |
| break fee | Leaving fee | What you pay to end a lease early | Makes closing a bad outlet expensive |
| fit-out | Fit-out | Building work to turn empty premises into a restaurant | Rent is due while it is being done |
| equipment lease | Rented equipment | A machine you pay for weekly and never own | No big payment and free repairs, but it costs more over time |
| second-hand | Second-hand | Used equipment at half price | Cheaper, older, and sometimes faulty |
| goodwill | Goodwill | What you pay for a running restaurant's customers and name | Why buying costs more than building |
| policy | Standing orders | Rules your manager follows when you are away | Good orders keep a branch running without you |
| neglect / slack | Standards slipping | What happens when you do not visit a branch | Service slows, waste and theft rise |
| skimming | Missing cash | Sales and cash in the till do not match | Someone may be stealing |
| crisis | In trouble | A branch that has lost money four weeks running | Fix it or close it before it sinks the company |
| auto-run | Fast-forward | The shift runs without you | Possible only when every job is filled |

Adding a new player-facing concept requires adding a row here and its three strings.

## 6. Visual direction

- **Style:** clean, flat-shaded 2D with soft shadows and rounded shapes; top-down ¾
  view for the restaurant; warm, appetising palette; one accent colour per theme
  (Italian green, Chinese red, Mexican orange, Indian saffron).
- **UI:** Material 3 as a base with a custom theme; cards with 16 px radius; generous
  spacing; one display typeface for headings, one highly legible face for numbers and body
  (both bundled, open-licence fonts).
- **Motion:** 150–250 ms eased transitions; coins fly to the cash counter on payment;
  markers pop in; numbers count up in reports. All motion can be reduced in Settings.
- **Feedback:** light haptic on taps that queue a task; distinct sounds for payment,
  walk-out, incident, breakdown.
- **Dark mode:** not in MVP; keep colours in a theme object so it can be added.

Quality of graphics depends on the art assets, which coding models cannot draw. The
build uses **placeholder art** (coloured shapes and icon-font glyphs) behind a single
`AssetCatalog` so real art can be dropped in without code changes.

## 7. Art and audio asset list (MVP)

| Group | Items | Spec |
|---|---|---|
| Room | Floor, walls, door, till, pass, kitchen strip background (Italian skin) | PNG, 3× resolution for 390-wide layout |
| Furniture | Table for 2 / 4 / 6 (free, occupied, dirty states) | 96–192 px sprites |
| Stations | Range, oven, cold counter (+ broken state each); later theme stations | 128 px |
| Characters | Owner, 7 staff roles, 4 customer segments; walk (4 frames × 2 directions), idle, work | 64 px sprite sheets, palette-swappable |
| Markers | seat, order, deliver, bill, clear, cook, warning | 64 px icons |
| Portraits | Parts-based: 6 face shapes, 8 hair, 6 accessories, 5 skin tones, role uniforms | 128 px layers |
| Icons | ~45 ingredients, 12 dishes per theme, 14 equipment types, UI glyphs | 64 px |
| Incident art | 8 category illustrations (staff, supplier, equipment, premises, customer, money, inspection, good news) | 780 × 300 |
| Audio | ~20 SFX; 2 music loops (prep/close calm, service upbeat) | OGG, licensed for redistribution |

Each added cuisine theme needs: room skin, its station sprites, 12 dish icons, name pools.

## 8. Accessibility

Screen-reader labels on all controls; contrast ≥ 4.5:1 for text; patience shown by
shape as well as colour; no information conveyed by sound alone; pausable at any time;
no timed input outside the pausable service phase.

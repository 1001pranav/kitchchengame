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
Stage 3+: a location switcher appears in the top bar; a Company tab replaces Money.
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

List grouped by role: portrait, name, skill bar (or range if unknown), morale face,
fatigue dot, wage, today's status. Detail sheet: all stats, traits, history lines,
actions (Raise, Train, Day off, Warn, Promote, Fire). Sub-tabs: **Rota** (7-column grid,
tap to toggle; per-day role coverage row at the bottom with warnings) and **Hire**
(this week's applicants with asking wage).

### 4.7 Stock tab

List by storage type with capacity bars. Per ingredient: on hand, days of cover,
earliest expiry (red if ≤ 1 day), on order. Sub-tabs: **Order** (pick supplier → lines
with suggested quantities → total vs minimum order → confirm) and **Suppliers**
(price level, quality, reliability stars, relationship, credit terms).
Stage 2: par-level editor.

### 4.8 Kitchen tab and Money tab

**Kitchen:** sub-tabs *Menu* (dish rows: price stepper, food cost %, margin, sold
yesterday, on/off switch; warning if its station is down) and *Equipment* (condition
bars, status, Maintain / Repair / Replace / Sell; Buy new).
**Money:** cash chart (last 28 days), this week so far (P&L lines), upcoming bills
(wages, rent, loan, utilities with dates), loans (take / repay), valuation, credit score.
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

## 5. Visual direction

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

## 6. Art and audio asset list (MVP)

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

## 7. Accessibility

Screen-reader labels on all controls; contrast ≥ 4.5:1 for text; patience shown by
shape as well as colour; no information conveyed by sound alone; pausable at any time;
no timed input outside the pausable service phase.

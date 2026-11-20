# 12 — Implementation Notes (Phase 0 + Phase 1 build)

The hand-off note doc 10 §1 asks for: where the build departs from the documents, where
the documents were silent and what was chosen, and what is not done. Review this before
starting Phase 2; spec gaps should be closed **in the docs**, not only in code.

---

## 1. Decisions that depart from doc 08

| Doc says | Built | Why |
|---|---|---|
| Flame `GameWidget` for the restaurant view | Plain Flutter widgets: a `Stack` of table tiles with `AnimatedPositioned` staff and owner figures (`app/lib/ui/screens/service_view.dart`) | The view is a grid of ~10–24 tables and a handful of figures; Flame added a dependency, a second render loop and untestable UI. Widgets are covered by widget tests and keep 60 fps easily. Revisit if real sprite art with walk cycles arrives |
| Riverpod `Notifier` | `ChangeNotifier` + `InheritedNotifier` (`GameScope`) | One controller, no extra package; same data flow (`send(Command)` → `sim.apply` → notify) |
| `strings_<locale>.json` for all text | English text inline in widgets and in content JSON (`name`, incident `title`/`text`/`label`); term cards in `data/terms_en.json` | Localisation is Phase 4 (task 4.5). Moving text to keys is mechanical once a second language is wanted |
| — | Web build keeps saves in memory | Only used for previews; phones use files with atomic rename |
| — | `deprecated_member_use` silenced in `app/analysis_options.yaml` | Flutter 3.50 deprecates `package:flutter/material.dart` in favour of the separate `material_ui` package; migrating is a small follow-up, not worth a new dependency mid-phase |
| Sound effects | Setting exists; no audio files yet; light haptics on queue / rush / treat | Doc 07 §7 assets are not drawn or recorded yet |

## 2. Spec gaps (`SPEC-GAP` in code) and what was chosen

| Where | Gap | Chosen |
|---|---|---|
| 02 §7.2 fatigue | +12 per worked day and −30 per day off nets +42 a week; everyone hit 100 in two weeks (40% slower, constant burnout) | Overnight recovery `FATIGUE_OVERNIGHT = 8`; doc 02 §7.2 updated; balance-log entry 13 |
| 02 §6.8 wait score | Whether the door wait counts toward `totalPatienceLimitTicks` | It does: a party's limit for `waitTable` is added on arrival (otherwise every door wait cost twice) |
| 02 §6.5 | A party for whom nothing on the menu can be cooked | They leave as a walk-out "waiting for food" |
| 02 §8.2d | Is a bill walk-out "lost"? | No — they paid (§6.3); lost = never seated + left before food |
| 04 §6 starting hygiene | Not given per tier | Excellent 90, Best 85, Good 75, Bad 62, Worst 52 (`START_HYGIENE`) |
| Staff limit | Not given | `MAX_STAFF = 16` |
| Objective rewards | Booked where? | Outside operating profit (like inherited debt), so a reward never hides a cost |
| Gas running low (05 #24) | "Set randomly, 5%/day" | `GAS_LOW_CHANCE = 0.05` rolled at prep |
| Skimming (05 #6) | Chance vs certainty | Certain: 3% of the day's sales while an undetected cashier with honesty < 40 works (doc 05 wording) |

## 3. Simplified incident options

All 41 catalogue incidents exist (plus two follow-ups, `inc_flood` and
`inc_licence_fine`). Some options are modelled more simply than the catalogue reads:

- `inc_competitor_opens` (b) price promotion: demand stays at ×1.0 and the discount is
  charged as half a day's sales, instead of a real −10% on prices for 14 days.
- `inc_poaching` (b) promise promotion: a 50% resignation follow-up after 28 days.
- `inc_day_off_request` (b): the extra busy shift in return is not scheduled.
- `inc_supplier_deal` (a): no penalty for missing the weekly minimum.
- `inc_licence_overdue` (b): one 50% fine after 7 days instead of 25% every week.
- `inc_tax_audit` (b): "lose your rest day" is −40 energy.
- `inc_critic_visit` (a): the owner is busy for a few ticks; their tasks are not auto-queued.
- `inc_rowdy_table` (b): the lost bill is a flat 40 coins.
- `inc_delivery_late` (a) and `inc_shortage_seasonal` (b) tell the player to open the
  order screen rather than opening it.

## 4. Balance (doc 06 §4)

Measured with `packages/sim_core/tool/balance.dart`; numbers and the bots' exact
behaviour are in `docs/balance-log.md` entry 13. Good tier, competent bot, is inside its
bands, and so are Excellent and Best. Bad and Worst were unwinnable at first and were
tuned in balance-log entry 14 (78% and 40% survival now). The *chores* band (60–80% survival) also fails: a bot that never hires or answers
cards loses staff it never replaces, and the per-tick service shows how fast that
empties a restaurant. Whether the band or the rules should move is a design decision
for the next tuning pass (task 0.22 continues).

## 5. Not done from the Phase 1 task list (doc 09)

- 1.15 sound; motion is reduced-motion aware but there are no audio files.
- 0.20 `explain` covers demand, rating, satisfaction, day profit, cash, staff happiness,
  cleanliness, energy, a dish's margin and company value. The "sum of factors equals
  the value" test exists implicitly for demand (the same function computes both) but not
  as a separate test per target.
- 0.21 the bot report prints survival, stage-2 week, walk-outs, profit and incident rate;
  no CSV yet.
- 1.17 device test pass and release-build checklist (`docs/release-checklist.md`) need a
  real phone. The release Android manifest has no INTERNET permission (debug/profile
  keep it for hot reload, as Flutter generates them).
- Playtest gate after Phase 1: not run. It is the next step, before Phase 2.

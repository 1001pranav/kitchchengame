# 08 — Technical Architecture

**Stack:** Flutter (latest stable 3.x at project start — pin the exact version in
`.fvmrc` or the README and do not upgrade mid-phase), Dart 3, Flame for the restaurant
view. Targets: Android and iOS phones. No backend, no network permission.

---

## 1. The one rule

**The simulation is a pure Dart package with no Flutter, Flame, `dart:io` or
`dart:ui` imports.** It takes state + commands and produces new state + events. The app
renders state and sends commands. Nothing in the app computes game rules.

Consequences: the whole game can be tested and balanced from the command line; UI work
cannot break rules; rules work needs no device.

## 2. Repository layout

```
/docs                         these documents
/packages/sim_core            pure Dart
  pubspec.yaml                deps: none at runtime; dev: test, lints
  /lib
    sim_core.dart             public exports only
    /src
      /model                  state classes (doc 03 §2) with fromJson/toJson
      /content                content classes (doc 03 §1), ContentLoader, ContentValidator
      /commands               one file per command group + CommandResult
      /systems                one file per system (see §4)
      /incidents              condition evaluator, effect applier, incident engine
      /gen                    restaurant/staff/applicant generators
      sim.dart                Sim facade (§3)
      rng.dart                SimRng (§5)
      balance.dart            typed accessors over balance.json
      events.dart             SimEvent types
  /data                       *.json content (doc 04, 05) + strings_en.json
  /test                       unit + scenario + determinism tests
  /tool
    balance.dart              balance bot runner (doc 06 §6)
    validate_content.dart     runs ContentValidator on /data
/app                          Flutter application
  pubspec.yaml                deps: sim_core (path), flutter_riverpod, flame, flame_audio, path_provider
  /lib
    main.dart
    /state                    GameController (Riverpod), save service, settings
    /ui
      /shell                  bottom tabs, top bar
      /screens/<name>         one folder per screen in doc 07 §4
      /widgets                shared widgets (StatBar, MoneyText, WhySheet, IncidentCard …)
      /theme                  colours, text styles, AssetCatalog
    /game                     Flame: RestaurantGame, components (table, figure, marker, station)
    /l10n                     string lookup over strings_<locale>.json
  /assets                     art, audio, fonts; sim data is copied/linked from sim_core/data
  /test                       widget tests
```

Keep runtime dependencies to the list above. Adding a package requires a note in the PR
description saying why the standard library was not enough.

## 3. `Sim` facade (the only API the app uses)

```dart
class Sim {
  Sim.newGame({required Content content, required int seed,
               required Difficulty difficulty, required String themeId});
  Sim.fromSave(Content content, Map<String, dynamic> saveJson);

  GameState get state;                 // treat as read-only outside sim_core
  CommandResult apply(Command c);      // validates, mutates, returns ok/error + events
  List<SimEvent> tick();               // advance one service tick; only valid in phase service
  List<SimEvent> beginDay();           // called automatically by EndDay; exposed for tests
  Map<String, dynamic> toSave();
  Explanation explain(ExplainTarget t);// data for the "Why?" sheets (demand, reputation, profit …)
  Forecast forecast(String locationId);
}
```

`CommandResult { bool ok; SimError? error; List<SimEvent> events; }`. `apply` never
throws for invalid player input; it throws only on programmer errors (broken invariants).

State is **mutable inside `sim_core`** for speed and simplicity; the app must not mutate
it. Collections exposed on state are wrapped as unmodifiable views in the public getters.

## 4. Systems

Each system is a file of top-level functions or a small class operating on `GameState`,
called by `Sim` in the order defined in doc 02 §3. No system calls the UI, reads time
or creates its own RNG.

| File | Responsibility | Doc 02 § |
|---|---|---|
| `calendar.dart` | Dates, weekday, season, festivals | 2 |
| `demand.dart` | Groups per day, arrivals, group properties | 5 |
| `service.dart` | Tick loop, group state machine, tasks, assignment | 3.2, 6 |
| `kitchen.dart` | Tickets, station slots, quality, dishes backlog | 6.4–6.7 |
| `satisfaction.dart` | Satisfaction, tips, reputation | 6.8 |
| `staff.dart` | Wages, fatigue, morale, absence, quitting, hiring, training | 7 |
| `owner.dart` | Owner queue, cover, energy, mistakes | 8 |
| `inventory.dart` | Batches, capacity, prices, orders, deliveries, par levels | 9 |
| `equipment.dart` | Wear, breakdown, maintenance, repair, replace | 10 |
| `hygiene.dart` | Hygiene, inspections | 12 |
| `marketing.dart` | Campaigns | 13 |
| `finance.dart` | Daily/weekly/monthly money, loans, credit, valuation, bankruptcy | 14 |
| `progression.dart` | Stages, objectives | doc 01 §3.3 |
| `incident_engine.dart` | Rolls, cooldowns, resolution | 11, doc 05 |
| `explain.dart` | Builds factor breakdowns from the same functions the sim uses | — |

`explain.dart` must **call the same formula functions** as the systems (formulas return a
breakdown object from which the total is derived) so explanations can never drift from behaviour.

## 5. Randomness

`SimRng` is xorshift32, implemented in the package (do not use `dart:math Random`: its
state cannot be saved):

```dart
int _s;                       // 1 .. 0xFFFFFFFF, never 0; seed 0 is replaced by 0x9E3779B9
int nextU32() {
  var x = _s;
  x ^= (x << 13) & 0xFFFFFFFF;
  x ^= (x >> 17);
  x ^= (x << 5) & 0xFFFFFFFF;
  return _s = x & 0xFFFFFFFF;
}
double nextFloat() => (nextU32() >> 8) / 16777216.0;      // [0, 1)
int nextInt(int a, int b) => a + (nextFloat() * (b - a + 1)).floor();   // inclusive
```

Test vector: seed 1 → first `nextU32()` is **270369**. `rngState` in the save is `_s`.
Helpers: `chance(p)`, `pick(list)`, `weighted(items, weights)`, `shuffle(list)` — all
consume a fixed, documented number of draws. UI-only randomness (particle jitter,
idle animations) must use a separate `dart:math Random`, never `SimRng`.

## 6. App architecture

### 6.1 State flow

```
user input → GameController.send(Command) → sim.apply → events → notify listeners → widgets rebuild
service clock (Ticker) → GameController.step() → sim.tick() × n → events → Flame + widgets
```

- `GameController` (a Riverpod `Notifier`) owns the `Sim`, the service clock, speed
  setting and autosave. It exposes a `revision` counter that increments after every
  mutation; providers select from `sim.state` and depend on `revision`.
- Widgets read through small selector providers (`cashProvider`, `staffListProvider`, …)
  so a tick does not rebuild the whole tree.
- Events are published on a broadcast stream consumed by the Flame game (animation),
  the sound service and toast/log UI.

### 6.2 Service clock

At 1× the controller runs `TICKS_PER_SECOND_1X` ticks per second using elapsed time from
a `Ticker`; at most 8 ticks per frame (auto-run) to keep frames smooth. Opening an incident card,
the pause menu, or the app going to background pauses the clock. Rendering interpolates
figure positions between ticks; the sim itself has no positions — the Flame layer maps
tasks to screen locations (table n, pass, till, station s).

### 6.3 Flame layer

`RestaurantGame extends FlameGame` builds components from `Location` (tables, stations)
on load and keeps a map id → component. Each frame it reconciles components with
`ServiceState` (groups, tasks) and plays event animations. Taps on marker components call
`GameController.send(OwnerQueueTask(id))`. No game rule lives here.

### 6.4 Persistence

- Saves are JSON files in the app documents directory: `save_<slot>.json` (3 slots) plus
  `autosave.json`. Write to a temp file then rename (atomic).
- Autosave: on every phase change, every 60 service ticks, and when the app is paused
  (`AppLifecycleState.paused`).
- `saveVersion` migrations live in `sim_core/src/model/migrations.dart`: a list of
  functions `Map → Map` applied in order. A save newer than the app is refused with a message.
- Settings (sound, speed, text size) are stored separately in `settings.json`.
- Export/import: share sheet for the JSON file (Phase 4).

### 6.5 Content loading

At start the app reads the JSON assets, builds `Content` via `ContentLoader`, runs
`ContentValidator` in debug builds (CI runs it always), and passes `Content` to `Sim`.
JSON numbers: read ints with `(json['x'] as num).toInt()` and doubles with
`(json['x'] as num).toDouble()` — never cast directly to `int`/`double`.

### 6.6 Platform setup

Portrait lock; no INTERNET permission in the Android manifest for release builds; app
size target < 80 MB; min Android API 24, min iOS 13 (confirm against the pinned Flutter
version); 60 fps target on a 4-year-old mid-range phone.

## 7. Testing

| Level | Where | What |
|---|---|---|
| Unit | `sim_core/test/systems/*` | Every formula in doc 02 with hand-computed cases |
| Content | `sim_core/test/content_test.dart` | Validator passes; each dish's derived price in sane range; every incident option resolves on a standard state |
| Scenario | `sim_core/test/scenarios/*` | Scripted days: "no cook → mains walk out", "fridge broken → spoilage", "missed instalment → credit drop" |
| Determinism | `sim_core/test/determinism_test.dart` | Same seed + same bot = identical save JSON after 28 days; save/load mid-service then continue = identical to uninterrupted run |
| Round-trip | `sim_core/test/save_test.dart` | `fromSave(toSave())` equals original for generated states |
| Invariants | run inside scenario/bot tests | cash is int; no negative stock; no task assigned to two workers; every group in exactly one state; station slots never exceeded |
| Balance | `tool/balance.dart` | Bands in doc 06 §4 (reported, not a CI gate until tuned) |
| Widget | `app/test` | Each screen builds from a fixture save at 360×640 and 390×844 without overflow; key flows (prep → open doors, resolve incident, place order) |

CI commands (must all pass before a task is considered done):
```
cd packages/sim_core && dart format --set-exit-if-changed . && dart analyze --fatal-infos && dart test
cd packages/sim_core && dart run tool/validate_content.dart
cd app && flutter analyze && flutter test
```

## 8. Performance budget

- One service tick for one location: < 0.2 ms on a mid-range phone (≤ 60 groups, ≤ 200 tasks).
- A full unattended location-day: < 100 ms. With > 5 unattended locations, run their
  days in a background isolate at `beginDay` (Phase 2).
- Save file: < 500 KB per location-year; `History` is capped (doc 03 §2.9).

## 9. Phase 2+ notes (do not build early)

Multi-location only needs: `locations` already being a list, `ownerLocationId`, the
unattended runner (doc 02 §15) and policy commands. Do **not** add abstractions for
brands, franchising or central kitchens before Phase 2/3 specs exist.

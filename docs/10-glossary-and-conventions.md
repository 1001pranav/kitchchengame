# 10 — Glossary and Conventions

Read this before any task. It applies to every contributor, human or model.

---

## 1. Working rules

1. **The docs are the source of truth.** Implement what they say. Do not add features,
   rules, constants or content that are not in the docs.
2. **If the spec is silent, ambiguous or contradictory: stop guessing.** Choose the
   simplest behaviour consistent with the rest, mark it in code with
   `// SPEC-GAP: <what was unclear, what was chosen>`, and list it in your hand-off note.
3. **Precedence when documents disagree:** 02 (formulas) > 03 (data shapes) > 05
   (incidents) > 04 (content) > 01 (design prose) > 07 (UI). Doc 00 is historical only.
4. **No magic numbers.** Every tunable value comes from `balance.json` or a content file.
   Structural constants (array sizes implied by the calendar, enum counts) are fine in code.
5. **Rules live only in `sim_core`.** If you are writing an `if` about game outcomes inside
   `/app`, it is in the wrong place.
6. **Every rule has a test.** A formula without a hand-computed test case is not done.
7. **Small changes.** One task per change. Do not refactor unrelated code.
8. **Never weaken a test to make it pass.** If a test contradicts the spec, report it.
9. **Offline is absolute.** No network calls, analytics, crash reporters, remote config,
   ads or web views. No package that needs the INTERNET permission.
10. **Changing a formula or constant's meaning** requires editing doc 02 in the same change.
    Changing a constant's *value* requires an entry in `docs/balance-log.md`.

## 2. Dart conventions

- `dart format` defaults; `flutter_lints` / `lints` recommended set with
  `--fatal-infos`. No `dynamic` except at JSON boundaries. No `!` on values from JSON
  without a preceding check. Prefer `final`. No global mutable state.
- Files `snake_case.dart`; classes `UpperCamelCase`; members `lowerCamelCase`; JSON
  fields `lowerCamelCase`; ids `lower_snake_case` with prefix (doc 03).
- Enums serialise by `name`. Unknown enum value in a save → load error, not a default.
- Money is `int` coins everywhere. Convert with `round()` only where doc 02 says money moves.
- Probabilities are `double` 0–1; percentages appear only in UI text.
- Iterate maps in sorted-key order inside the sim (determinism). Never iterate a `Set`
  or `Map` in the sim without sorting unless it is a `List`-backed, insertion-ordered
  structure created deterministically.
- No `DateTime.now()`, `Random()`, `Stopwatch`, `dart:io`, or Flutter imports in `sim_core/lib`.
- Public sim API is documented with `///` comments. Internal comments explain *why*, not *what*.
- Errors: invalid player input → `CommandResult` with a `SimError`; broken invariants → `StateError` (a bug).

## 3. Flutter conventions

- One screen per folder: `<name>_screen.dart`, private widgets alongside. Widgets stay
  under ~150 lines; extract otherwise.
- Widgets get data from Riverpod selector providers and send `Command`s through
  `GameController`. Widgets never hold game data in their own state — only transient UI
  state (scroll position, open sheet, text field).
- All text via the localisation lookup. All colours, text styles, spacing and asset
  paths via the theme / `AssetCatalog`. No hard-coded strings, colours or asset paths in widgets.
- Every screen has a widget test that builds it from a fixture save at 360×640 and 390×844.
- Use `SafeArea`. Use `const` constructors where possible.

## 4. Git conventions

- Commit message: imperative subject ≤ 72 chars, prefixed with the task number
  (`0.9 Add group state machine and FOH tasks`), body listing spec gaps if any.
- Never commit generated build output, secrets or large binaries outside `/app/assets`.

## 5. Glossary

These are **internal** terms for specs and code. Text shown to players uses the plain
names in doc 07 §5.

| Term | Meaning |
|---|---|
| **86 / 86'd** | A dish taken off today's menu (disabled), manually or automatically |
| **Auto-run** | Service plays at high speed without owner floor work; allowed when all roles are covered |
| **Balance bot** | Scripted player used to measure the economy headlessly |
| **Batch** | A quantity of one ingredient with its own quality and days-left |
| **Close** | Third phase of a day: settlement and report |
| **Coins** | The only currency; integers |
| **Command** | A player action sent to the sim; the only way the player changes state |
| **Content** | Read-only shipped data (dishes, incidents, constants …) |
| **Cover (a role)** | Owner automatically takes waiting tasks of one role |
| **Covers** | Not used in this project (restaurant jargon for guests); say "people" or "groups" |
| **Due diligence** | Paid inspection of a takeover offer revealing some hidden problems |
| **Effect** | One state change produced by an incident option (doc 05 §2.2) |
| **Event (SimEvent)** | A notification from the sim to the UI about something that happened |
| **Floor work** | Owner personally doing service or kitchen tasks |
| **FOH / BOH** | Front of house (dining room, till) / back of house (kitchen, dishes, store) |
| **Forecast** | Expected groups today, without the random term |
| **Group** | A party of 1–6 customers; the unit the sim tracks |
| **Hidden problem** | A pre-existing issue in a bought restaurant, revealed over time |
| **Hygiene** | 0–100 cleanliness score per location |
| **Incident** | A decision card raised by the sim (doc 05) |
| **Lifeline** | Emergency option offered when cash is negative |
| **Location** | One restaurant |
| **Neglect / slack** | Gradual decline of a location the owner has not visited (doc 02 §15.5) |
| **Par level** | Stock quantity that auto-ordering tops up to |
| **Patience** | Ticks a group will wait in a given state before walking out |
| **Policy** | Standing instructions a manager follows at an unattended location |
| **Prep** | First phase of a day: planning before doors open |
| **Reputation** | 0–5 star rating per location; drives demand |
| **Rota** | Which staff work on which weekday |
| **Rush** | A period where waiting tasks for a role exceed 5 |
| **Service** | Second phase of a day: 360 ticks of simulated opening hours |
| **Slot** | Capacity for one concurrent cook task on a station |
| **Stage** | One of five progression steps (doc 01 §3.3) |
| **Station** | A type of cooking position (stove, oven, fryer, grill, wok, tandoor, cold) |
| **Subject** | The staff member / equipment / supplier an incident is about |
| **Task** | A unit of service work (seat, takeOrder, cook, deliver, bill, clear) |
| **Theme** | Cuisine content pack |
| **Ticket** | One dish ordered by a group, to be cooked |
| **Tick** | Smallest unit of service time; 2 game minutes |
| **Tier** | One of five quality/price levels of takeover offer |
| **Travel** | Owner moving between locations during service; takes ticks and energy |
| **Unattended location** | A location the owner is not at right now; run by its manager |
| **Visit** | Owner present at a location for at least `VISIT_MIN_TICKS` in a day |
| **Valuation** | Company worth per doc 02 §14.4 |
| **Walk-out** | A group leaving because patience ran out |

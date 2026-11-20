# Kitchen Chain (working title)

An offline, single-player restaurant management game for mobile. You buy a running
restaurant — staff, debts and problems included — work the floor yourself until you can
afford not to, and grow it into a chain.

**Stack:** Flutter 3.50.1 (Dart 3.14) · **Platforms:** Android, iOS (portrait); a web
build is used for previews · **Status:** Phase 1 (MVP) playable — one Italian restaurant,
stages 1–2 and the stage 3 threshold as the win condition of this version.

## Play it

```bash
cd app && flutter pub get && flutter run
```

A browser preview (no install needed): `flutter build web --no-web-resources-cdn` then
serve `app/build/web` with any static server. Saves are kept in memory on the web
build only; on phones they are files in the app's documents folder.

## What is in the game

| Area | In this version |
|---|---|
| Start | Difficulty (Easy / Normal / Hard), Italian theme, five takeover offers (Excellent → Worst) with honest pricing, inspection before buying, the starting loan |
| Day loop | Prep board (forecast, needs-attention list that links to the fix, team cover, shift target, where you start) → live service → three-page close report → next day |
| Service | 360 ticks, 11:00–23:00; parties arrive in waves, wait for a table, order, wait for food, eat, pay. You stand at Door & till, Tables, Pass or Dishes; spend favours to **rush** a table's food or **treat** waiting guests; **bring the bill**; move floor staff between jobs; tap any job to do it yourself. Kitchen strip with station slots, dirty-plate meter, pass. Pause, 1×, 2×, fast-forward when every job is covered; quiet spells speed up by themselves |
| Staff | Hire (weekly applicants, skill shown as a range until known), fire, raise, train, warn, promote, day off; everyone has one weekday off and a coverage strip shows the gaps; happiness built from 11 visible factors with the reason for every point; absence, lateness, burnout, quitting with or without notice |
| Stock | Batches with use-by days, FIFO, storage capacity, six suppliers that differ in price, quality, reliability, minimum order and credit; late, short and bad deliveries; price drift and spikes; keep-in-stock levels (stage 2) |
| Kitchen | Menu prices 60–180%, food cost and profit per dish, dishes on/off, menu rework; equipment wear, age, breakdowns, servicing, cheap/proper repairs, replace, sell, buy new |
| Money | Daily P&L, Sunday wages/rent/loan, monthly utilities/tax/licence, cash chart, bank loans with the five checks shown before you apply, counter-offers, private lender, early repayment, bank trust, company value, bankruptcy and lifelines (emergency loan, sell equipment, investor) |
| Growth | Stage 2 unlocks marketing (flyers, local ad, promotion day, food blogger — each a gamble with a reported outcome and return on spend) and automatic re-ordering; the "health" of the outlet (buzz, menu freshness, equipment age, cost creep, rivals) |
| Drama | 43 situations (doc 05's 41 plus two follow-ups) driven by data, ten inherited hidden problems |
| Teaching | Every number opens a "Why?" sheet; trade words are underlined and open a card; a searchable Handbook of all 70 terms; tips on days 1–3; the game-over screen shows the timeline that led there |

Not in this version (Phase 2+ in doc 09): more locations, managers, the other cuisines,
sound files and final art. Placeholder art is drawn with Material icons behind
`AssetCatalog` so real art can be dropped in later.

## Repository layout

```
docs/                    design documents (source of truth)
packages/sim_core/       pure Dart simulation: no Flutter, no dart:io in lib/
  data/                  balance.json + content JSON (bundled into the app as-is)
  lib/src/systems/       one file per system (service, staff, inventory, finance, …)
  test/                  unit, scenario, determinism and save tests
  tool/                  balance bot (tool/balance.dart) and diagnostics
app/                     Flutter app (renders state, sends commands; no game rules)
prototype/               earlier throwaway prototypes (economy loop, service feel)
tool/ci.sh               every check that must pass
```

## Checks

```bash
./tool/ci.sh
```

runs `dart format`, `dart analyze --fatal-infos` and `dart test` on the simulation,
`flutter analyze` and `flutter test` on the app (widget tests at 360×640 and 390×844,
and 360×640 with text at 130%).

Balance bot: `cd packages/sim_core && dart run tool/balance.dart good competent 30 26`
(tier, policy = passive | chores | competent, seeds, weeks).

## Documents

Start with 10, then 01. Implementation follows 09 task by task.

| Doc | Purpose |
|---|---|
| [10 Glossary and conventions](docs/10-glossary-and-conventions.md) | Rules every contributor follows; vocabulary |
| [01 Game design document](docs/01-game-design-document.md) | What the game is; all rules in prose |
| [02 Simulation spec](docs/02-simulation-spec.md) | Exact formulas and order of operations |
| [03 Data schemas](docs/03-data-schemas.md) | Content files, save format, commands, events |
| [04 Content catalogue](docs/04-content-catalogue.md) | Ingredients, dishes, equipment, suppliers, traits, objectives |
| [05 Incident catalogue](docs/05-incident-catalogue.md) | Incident grammar and the 41 MVP incidents |
| [06 Economy and balance](docs/06-economy-and-balance.md) | Targets, estimates, balance bot, tuning method |
| [07 UI / UX spec](docs/07-ui-ux-spec.md) | Screens, wireframes, visual direction, asset list |
| [08 Technical architecture](docs/08-technical-architecture.md) | Code structure, sim API, persistence, testing |
| [09 Implementation plan](docs/09-implementation-plan.md) | Ordered tasks with acceptance criteria |
| [11 Outlet lifecycle and formats](docs/11-outlet-lifecycle-and-formats.md) | Why outlets decline, manager vs owner roles, outlet formats, badges |
| [12 Implementation notes](docs/12-implementation-notes.md) | Where the build departs from the docs, spec gaps, what is left |
| [00 Concept draft](docs/00-concept-draft.md) | Historical: the discussion draft and its risk list |

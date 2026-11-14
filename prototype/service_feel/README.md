# Service feel test (throwaway)

One question: **is working the floor as the owner fun for three minutes on a phone?**
No scripted player can answer that, so this is a tappable page for real people.

Open `index.html` in a phone browser (it is a single file with no build step). It is
**not** the game and not `sim_core`; it is plain HTML and JavaScript so it can be put in
front of someone in seconds. Delete it once the real service screen (tasks 1.5–1.6) exists.

## What it contains

A slice of doc 02 §6 and §8 for one Good-tier Italian outlet: 14 tables, arrivals by the
hourly curve, the group state machine (seat → order → cook → serve → eat → bill → clear),
patience and walk-outs, station slots and `COOK_PARALLEL`, dirty dishes, staff taking
tasks by role, and the owner: a three-job queue, "fill in" for a role, a one-tick walk,
fixed skills, energy and mistakes when exhausted. Two situations can interrupt: a restless
table and a dead oven.

Four shifts: quiet Tuesday with a full team; Friday with a server off; Saturday with no
cashier and no dishwasher; Friday with a cook off and an oven that fails.

Not included: stock, prices, staff happiness, food quality detail, anything outside service.

## Deviations from the spec, and why

These were needed to make the test meaningful. Each is a **finding against doc 02**,
recorded in `docs/balance-log.md` (entry 11) and not yet applied to the spec.

| In doc 02 | Here | Reason |
|---|---|---|
| Italian Good tier: one oven (3 slots) | 6 oven slots (two ovens) | About 60% of mains need the oven. With 3 slots the oven is saturated at lunch on a *quiet* day with a full team: 4.5% of parties walked out waiting for food |
| Patience waiting for a table: 10 ticks (20 minutes) | 18 ticks | With 10, a fully staffed Friday lost 12.5% of parties at the door and Saturday 17%, whatever the owner did |
| Stand-in roles (§6.2) | Only cleaner → dishes | With no dishwasher and no stand-in, clean plates ran out and 65% of parties left without food |

## Headless measurements (200 runs per row)

`lost` = parties that walked out or were never seated.

| Shift | Owner does nothing | Owner fills in for the missing role |
|---|---|---|
| Quiet Tuesday, full team | 1.9% lost | 1.8% |
| Friday, a server off | 24.0% | 9.7% (owner working 42% of the shift, 36 energy left) |
| Saturday, no cashier, no dishwasher | 44.7% | 18.5% |
| Friday, a cook off, oven fails | 29.8% | 23.2% |
| Friday, full team (not offered in the page) | 8.0% | — |
| Saturday, full team (not offered) | 11.7% | — |

Doc 06 targets: 3–10% on a normal day, 15–30% with one key role absent, and the owner
filling in should at least halve it. With the deviations above, the server-off shift meets
all three. Without them none do.

Other things the runs showed:
- **The bottleneck moves.** Filling in as a server removes losses at "waiting to order"
  (20% → under 1%) and pushes some to the door instead (2.7% → 5.7% never seated): more
  parties get through, tables stay full longer.
- **Average rating of served parties is about 3.2 stars** even on the quiet, fully staffed
  day, against a starting reputation of 3.5. If that holds in the real simulation, a
  well-run Good-tier outlet's reputation drifts down. Needs checking in task 0.11.
- **Kitchen cover by the owner barely helps** (cooking skill 35, one dish at a time):
  29.8% → 23.2% while using all the owner's energy.

## What to ask a tester

Play the quiet shift once, then two of the others. Then:
1. Was it fun, dull, stressful or confusing?
2. Did you tap single jobs, use "fill in", or both? Which felt better?
3. Did you understand why parties walked out?
4. Was three minutes too long, too short, about right?
5. Would you want to do this every in-game day?

The end screen has a results box to copy back.

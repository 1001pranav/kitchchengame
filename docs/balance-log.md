# Balance log

Every change to a constant's value, with the evidence. Newest first. See doc 06 §6.3.

## Entry 3 — manager mastery

Source: `prototype/economy_loop/results.txt` (200 seeds × 26 weeks).

New rule, doc 02 §15.16: from sub-skill 65 upward (full at 90) a manager adds supplier
negotiation (up to −8% ingredient cost), preventive care (up to −30% wear), staff
development (+1 crew skill a month) and retention (up to half the resignations).

| Owner markets + visits weekly | Trainee | Junior | Capable | Senior | Veteran |
|---|---|---|---|---|---|
| Before (entry 2) | −0.2k | +0.3k | +0.9k | +1.3k | +1.5k |
| After | −0.2k | +0.3k | +1.0k | +1.6k | +2.1k |

Senior → Veteran step: about +200 → about +500 a week. Lower grades unchanged, as intended.
Also tried: negotiation up to −10% starting at skill 70 — no better (Veteran +2.2k), kept −8% from 65.

Not modelled in the prototype: weekly deals, supplier relationship gain, deputies, and
the per-person day-off rules of doc 02 §7.7 (wages are still averaged over a six-day week).

## Entry 2 — prototype reworked to the corrected specs

Source: `prototype/economy_loop/results.txt` (200 seeds × 26 weeks).

| Change | Old → new | Reason | Measured effect |
|---|---|---|---|
| Hygiene rule (doc 02 §12) | flat `+12` per cleaner → `0.40 × (100 − hygiene)` per cleaner | Hygiene pinned at 100, inspections never mattered; flat `+8` collapsed | Settles near the pass mark; owner-run profit 4.1k → 3.9k (occasional warnings); strengths 0.30 / 0.40 / 0.50 tried, 0.30 cost owner-run 0.6k and was too harsh |
| Prototype crew | lineCook + prepCook → lineCook × 2 | Match doc 04 §6 Good-tier roster | About −200 a week |
| Never-seated walk-outs | implemented in the prototype | Doc 02 §6.8 as changed in entry 1 | Small |
| Profit reported | operating incl. interest → net profit | Doc 02 §14.2 as changed in entry 1 | Labels only |

Result (average weekly net profit, owner markets and visits weekly):
Trainee −0.2k, Junior +0.3k, Capable +0.9k, Senior +1.3k, Veteran +1.5k; owner with no manager +3.9k.
Owner markets but never visits: −1.4k, −0.6k, ≈ 0, +0.6k, +1.0k.

Still open: the Senior → Veteran step is only about +200 a week.

## Entry 1 — after the economy-loop prototype

Source: `prototype/economy_loop` (200 seeds × 26 weeks, Good tier, average location).
The pre-change numbers are kept as `data/balance-original.json` / `results-original.txt`.

### Constants

| Constant | Old → new | Reason | Measured effect |
|---|---|---|---|
| `BASE_FOOTFALL` (average location) | 50 → 55 | Owner-run Good tier earned ~2.8k/week operating, not the ~3.9k intended | Owner-run, competent: 4.3k/week |
| `BUZZ_DECAY` | 0.02 → 0.01 | One ad per 4 weeks could not hold demand (−10%) | Competent owner holds −3% |
| `ABSENCE_DIVISOR` (doc 02 §7.4) | 400 → 1,000 | 11% daily absence per person | ~4.5% |
| `NEGLECT_PER_DAY` | 0.02 → 0.01 | With the new grace rule below | — |
| `NEGLECT_MAX` | 0.30 → 0.20 | Same | — |

### Rule changes (doc 02 edited in the same change)

| Rule | Change | Reason |
|---|---|---|
| Manager works the floor (§15.15) | Manager holds the cashier position and fills gaps; no cashier needed | A manager's wage was 35–65% of the outlet's profit; every managed outlet went bankrupt |
| Neglect grace (§15.5) | `2 + skill/10` → `skill² / 70` | Slack capped out in 3–4 weeks at every grade, contradicting the grade table |
| Neglect absence adder (§15.5) | Removed | Double punishment with buzz decay |
| Manager daily morale modifier (§15.12) | Removed | Counted twice with the Boss happiness factor |
| Operating profit (§14.2) | Excludes loan interest; net profit defined | Docs 02 and 06 disagreed |
| Never-seated walk-outs (§6.8) | Satisfaction 30 at half weight (was 10 at full) | Advertising past capacity lowered reputation sharply |
| Stand-in roles (§6.2) | New | Default rota left single-holder roles empty Mon–Thu |

### Result (average weekly net profit, owner markets and visits weekly)

Before: Trainee −2.4k, Junior −2.0k, Capable −1.7k, Senior −1.4k, Veteran −1.1k; 0% survive.
After entry 1: Trainee ≈ 0, Junior +0.6k, Capable +1.3k, Senior +1.7k, Veteran +1.9k.
(Superseded by entry 2.)

### Tried and rejected

- `HYGIENE_PER_CLEANER` 12 → 8: hygiene fell without limit, owner-run survival dropped
  from 100% to 92% and profit halved. Replaced by the proportional rule in entry 2.
- Flatter manager wage curve (0.5 + 1.0 × skill) with a harsher till-skill reference:
  no better grade spread. Kept 0.4 + 1.2.

### Not tested by this prototype (needs the per-tick simulation)

Stand-in roles and the default rota's empty weekday roles (a day-resolution model can only
guess their cost); anything about other tiers, other
location classes, or more than one outlet. The prototype also models the manager's
till work as a flat penalty below skill 60 rather than as real task durations.

### Left as designed

Veteran managers never appear as applicants below rating 4.0 — intended gating.

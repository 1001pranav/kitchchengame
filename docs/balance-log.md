# Balance log

Every change to a constant's value, with the evidence. Newest first. See doc 06 §6.3.

## Entry 1 — after the economy-loop prototype

Source: `prototype/economy_loop` on branch `claude/economy-loop-prototype` (200 seeds ×
26 weeks, Good tier, average location), re-run with the patch in
`docs/balance-evidence/economy-loop-v2.patch` and `balance-v2.json`. Full output:
`docs/balance-evidence/results-v2.txt`.

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

### Result (average weekly operating profit, owner markets and visits weekly)

Before, spec numbers: Trainee −2.4k, Junior −2.0k, Capable −1.7k, Senior −1.4k, Veteran −1.1k; 0% survive.
After: Trainee ≈ 0, Junior +0.6k, Capable +1.3k, Senior +1.7k, Veteran +1.9k.

### Tried and rejected

- `HYGIENE_PER_CLEANER` 12 → 8 (to make inspections a threat at Good tier): hygiene fell
  without limit, owner-run survival dropped from 100% to 92% and profit halved. Left at 12.
  Open: hygiene still sits near 100 with one average cleaner.
- Flatter manager wage curve (0.5 + 1.0 × skill) with a harsher till-skill reference:
  no better grade spread. Kept 0.4 + 1.2.

### Not tested by this prototype (needs the per-tick simulation)

Stand-in roles; the never-seated walk-out rule; anything about other tiers, other
location classes, or more than one outlet. The prototype also models the manager's
till work as a flat penalty below skill 60 rather than as real task durations.

### Left as designed

Veteran managers never appear as applicants below rating 4.0 — intended gating.

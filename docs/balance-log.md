# Balance log

Every change to a constant's value, with the evidence. Newest first. See doc 06 §6.3.

## Entry 7 — building from scratch measured; as written it beat buying on every count

Source: `prototype/economy_loop/results.txt`, new **Opening routes** table (200 seeds × 104
weeks, competent owner who visits weekly unless stated). The prototype now models doc 02
§15.9 route B: medium size, 3-year lease, rent from signing, fit-out and build days, new /
second-hand / leased equipment, crew hired at skill 45–65 (company rating 3.5), manager
and crew paid from opening day, rating 3.0 moving twice as fast for 28 days, the 2,000
launch campaign. Both routes are paid from company cash. Payback counts from the decision
day, so the build weeks are included; the lease deposit is in "up front" but not in
payback, because it comes back.

### Finding 1 — the spec has no slow start, so scratch dominated

Doc 02 §15.9 promises "a slow ramp" but no rule produces one: footfall belongs to the
location, so a new outlet at rating 3.0 with buzz 0.8, fresh menu 1.0 and the launch
boost gets almost the same customers as a takeover from its first day.

| Senior, spec as written | Up front | First profitable week | Payback | Net at wk 52 | Net at wk 104 |
|---|---|---|---|---|---|
| Buy running (75,000) | 75.0k | 1 | 45 | +21.0k | +156k |
| Standard fit-out, new kit | 58.5k | 3 | 34 | +57.7k | +247k |
| Basic, second-hand kit | 36.9k | 2 | 38 | +33.4k | +175k |
| Basic, leased kit | 22.2k | 2 | 11 | +63.8k | +224k |

Same picture for Capable and Veteran and for an owner who never visits. Standard + new
kit was cheaper, paid back sooner, earned more per week and was no riskier. Buying won
nothing but the first two weeks.

### Finding 2 — the steady-state gap is not about the price

Even once trading normally, a scratch outlet earns about 0.6k a week more than a bought
one (Senior, weeks 27–52: 2.8k vs 2.2k). Adding the scratch advantages one at a time to a
takeover (Senior, weeks 27–52, takeover 2.19k):

| Change | Weeks 27–52 a week |
|---|---|
| Crew skill 45–65 instead of 40–65 | +0.43k (most of it: a head chef below 50 cannot rework the menu, doc 02 §13, so 38% of takeovers can never refresh it; the bot never replaces the chef) |
| New equipment | +0.16k (upkeep 430 → 190 a week) |
| Buzz 0.8, freshness 1.0 | +0.08k |
| Hygiene 95, rating 3.0 | ≈ 0 (both converge within weeks) |

So a lower takeover price cannot close it: at 60,000 (× 0.4) buying still trails
standard + new by 43k at week 104. Recorded, not tuned (see "Still open").

### Finding 3 — a 3-year-old machine cannot be serviced

`maxCondition = 95 − 5 × floor(age / 168)` (doc 11 §A.3) is 65 at three years, which is
exactly `MAINTENANCE_THRESHOLD`. Servicing then cannot lift a unit out of the band where
it breaks down, so the bot keeps buying new replacements. This made second-hand kit
(spec: 3 years old) a dead option, worse than leasing at every grade, and it also drags
on takeovers (their kit is 1–3 years old).

### Constants and rules (doc 02 edited in the same change)

| Change | Old → new | Reason |
|---|---|---|
| `awareness` (new, doc 02 §15.9): demand × awareness; a takeover is 1 | — | Gives route B the slow start the spec describes |
| `SCRATCH_START_AWARENESS` | — → 0.45 | Standard + new: first profitable week 9, payback 45 (Senior) |
| `AWARENESS_GAIN` per trading day, × (0.5 + buzz) × min(1.5, rating / 3.5) | — → 0.01 | Full awareness in about 7–10 weeks; ads and a good rating speed it up |
| Opening period (doc 02 §15.7): a new outlet's losing weeks do not count toward `lossWeeks` until its first profitable week or `OPENING_GRACE_WEEKS` | — → 12 | Without it every scratch outlet entered crisis and drew `inc_location_failing` during its ramp |
| Second-hand equipment age (doc 02 §15.9 step 3) | 3 years → 2 years (max condition 75) | Finding 3; at 3 years second-hand lost to leasing on every measure |

Swept: start awareness 0.4 / 0.45 / 0.5 / 0.6 × gain 0.005 / 0.01. Gain 0.005 stretches
the first profitable week to 12–22 (outside every band). With gain 0.01: 0.4 puts Senior
standard + new payback at 46, just outside 30–45; 0.5 gives payback 42 and first profit
week 8; 0.6 is nearly no ramp (first profit week 3). 0.45 is the slowest start that keeps
payback inside the band.
Second-hand price 0.5 → 0.4 and condition 55 → 65 at 3 years were tried and changed
almost nothing; the age is the lever.

### Result (competent owner, visits weekly)

| Senior | Up front | Most cash tied up | First profit wk | Payback | Paid back by wk 52 | Crisis by wk 26 | Net wk 52 | Net wk 104 |
|---|---|---|---|---|---|---|---|---|
| Buy running | 75.0k | 75.0k | 1 | 45 | 68% | 6.5% | +21.0k | +156k |
| Standard + new | 58.5k | 79.2k | 9 | 45 | 83% | 4.5% | +26.4k | +214k |
| Basic + second-hand | 36.9k | 60.0k | 9 | 41 | 87% | 8.5% | +32.9k | +179k |
| Basic + leased | 22.2k | 50.4k | 10 | 43 | 77% | 30.5% | +26.9k | +188k |

Veteran: payback 38 / 38 / 35 / 37. Capable: 79 / 65 / 61 / 71. The ramp turns the
"cheaper" scratch routes into about the same peak cash as buying once the losses are
counted (79k for standard + new against 75k), which is the honest version of
"buying is faster, scratch is cheaper".

Against doc 06 §4: first profitable week passes for both scratch routes (9 in 6–10,
9–10 in 8–14); payback passes for Senior and Veteran on every route; crisis for basic +
leased (30.5%) and basic + second-hand (8.5%) bracket the 25–40% band; buying with a
Capable manager is at 28.5%, above its 10–20%.

### Still open

- **Buying still loses on money by week 52 for Senior and Veteran** (net at week 52:
  buy 21.0k vs 26–33k for scratch). The gap is the inherited crew and kit (finding 2),
  which a player would fix and the bot cannot. Two follow-ups before touching the price:
  let the competent bot replace a head chef below 50 and the oldest kit, and decide
  whether servicing should work relative to `maxCondition` (finding 3) for all outlets —
  that second change moves every earlier table, so it needs its own entry.
- **Leasing flatters payback.** The lease fee (2.5% a week, 130% a year) is a running
  cost, so "payback" on basic + leased looks fine while it ends 26k behind standard +
  new at week 104. Doc 06 now judges routes on net position and peak cash too.
- Hidden problems (route A) are still not modelled; they will make buying worse, not
  better.

### On the 150,000 start price vs the 75,000 later price (opinion, nothing changed)

The start price cannot simply drop: doc 01 §4.3 sets the loan as price − 80,000, so a
75,000 Good start would have no loan and change the whole Phase 1 opening. But the
current defence ("priced for an owner who works the floor") reads as a special case.
It is really one rule: both prices are about 45 weeks of what the buyer will earn
(owner-run Good ≈ 3.4k a week → 150k; Senior-run, first year ≈ 1.75k → 75k). Proposal:
write that rule into doc 02 §15.9 and show it on every offer ("asking ≈ 45 weeks of its
profit after a manager's wage"), so players see a rule, not a discount. It does not
cover Bad and Worst offers, which lose money; those keep fixed prices. Entry 7 also shows
the price is not the lever for route balance (finding 2), so it should not be moved
again to fix that.

## Entry 6 — dearer advertising, cheaper later takeovers, two targets restated

Source: `prototype/economy_loop/results.txt` (200 seeds × 26 weeks; the new "Second
outlet" table runs 104 weeks).

### Constants

| Constant | Old → new | Reason | Measured effect |
|---|---|---|---|
| flyers cost (doc 02 §13) | 400 → 900 | Entry 5: return ×5.9, weak response ×2.6 | Return ×2.6, weak ×1.15 |
| localAd cost (doc 02 §13) | 1,500 → 3,000 | Entry 5: return ×4.3, weak response ×2.0 | Return ×2.2, weak ×1.0 (breaks even) |
| `TAKEOVER_MARKET_PRICE_FACTOR` (new, doc 02 §15.9) | 1.0 → 0.5 | A bought Good outlet with a manager paid back in 63–80 weeks against 35–50 | Senior 45, Veteran 38 weeks |

Marketing is now 3.4% of revenue for the competent owner (target 2–4%). Every owner who
markets earns about 0.3–0.4k a week less:

| Owner markets + visits weekly | Owner-run | Trainee | Junior | Capable | Senior | Veteran |
|---|---|---|---|---|---|---|
| Before | +3.8k | −0.2k | +0.3k | +0.9k | +1.5k | +2.0k |
| After | +3.4k | −0.5k | ≈ 0 | +0.6k | +1.2k | +1.6k |

### Second outlet payback (new bot table)

The bot now buys a running Good outlet from company cash (so no loan and no bankruptcy)
and counts the weeks until its operating profit covers the price. Hidden problems are not
modelled.

| Price | Capable, weekly visit | Senior, weekly visit | Veteran, weekly visit | Veteran, never visits |
|---|---|---|---|---|
| 150,000 (start price) | > 104 | 80 | 63 | 98 |
| 90,000 (× 0.6) | 89 | 50 | 43 | 71 |
| **75,000 (× 0.5)** | 79 | 45 | 38 | 59 |

× 0.6 puts Senior exactly on the 50-week edge before hidden problems, so × 0.5 was chosen.
Managed outlets earn more in their second half-year than their first (Senior +1.3k →
+2.2k a week as the manager learns), which is why payback beats a straight division.

**Cost of this choice.** The same Good outlet costs 150,000 at game start and 75,000
later. That is defended in doc 02 §15.9 (the start offer is priced for an owner who works
the floor), but players will notice it. The alternative, cutting start prices, would
remove the Good tier's starting loan and change the whole Phase 1 opening, so it was not
taken.

### Targets restated (doc 06 §4), not tuned

- **Skill-80 manager, unvisited, weeks with negative operating profit ≤ 1 in 8.** Measured
  21% over 26 weeks (7% in weeks 1–12, 33% in weeks 13–26). The grade table (doc 02
  §15.14) asks the same manager to fade to break-even, and an outlet near break-even loses
  about every other week, so the two targets contradicted each other. Restated as ≤ 1 in 8
  over weeks 1–12 and ≤ 1 in 3 over weeks 13–26.
- **Passive owner-run Good survival 60–80%.** Measured 100%; the passive owner's cash never
  drops below its starting 20,000. The prototype has no incidents or hidden problems, so
  this cannot be settled here. It is flagged in doc 06 §4 as at risk rather than forced.

### Still open

- Capable, owner never visits, now drifts to about −0.5k a week by weeks 9–26. The grade
  table says "roughly break-even", so this is borderline.
- From-scratch payback (doc 06 §4) is not modelled.

## Entry 5 — return on spend measured; advertising is too cheap (decided in entry 6)

Source: `prototype/economy_loop/results.txt`, "Ad returns" table (campaigns at least 8
weeks old, about 13,000 of them). New rule doc 02 §13.2 tracks, per campaign, the extra
customers and extra profit it brought. No constant was changed in this entry.

| Campaign | Spend | Extra groups | Extra profit | Return | Flop | Weak | Expected | Good | Big hit |
|---|---|---|---|---|---|---|---|---|---|
| Local ad | 1,500 | 186 | 6,500 | ×4.3 | ×0 | ×2.0 | ×4.3 | ×6.6 | ×11.4 |
| Flyers | 400 | 68 | 2,400 | ×5.9 | ×0 | ×2.6 | ×5.5 | ×8.6 | ×21.7 |

Finding: about two thirds of an ad's value comes from the buzz it leaves, not the week
it runs. At these prices advertising is not a gamble — even a weak response doubles the
money, and only an outright flop loses. Marketing is 1.8% of revenue against a 2–4% target.

Option tested, **not applied**: local ad 1,500 → 3,000, flyers 400 → 900.

| | Return (local ad / flyers) | Weak response | Marketing % of revenue | Owner-run | Trainee | Junior | Capable | Senior | Veteran |
|---|---|---|---|---|---|---|---|---|---|
| Current prices | ×4.3 / ×5.9 | ×2.0 | 1.8% | +3.8k | −0.2k | +0.3k | +0.9k | +1.5k | +2.0k |
| Doubled prices | ×2.2 / ×2.6 | ×1.0 (breaks even) | 3.4% | +3.4k | −0.5k | ≈ 0 | +0.6k | +1.2k | +1.6k |

Doubling makes each ad a real risk and puts marketing inside its target share, at a cost
of 0.3–0.4k a week everywhere; a Junior-run outlet then only breaks even. Decision needed
from the owner of the design before changing the constants.

## Entry 4 — variable advertising outcomes

Source: `prototype/economy_loop/results.txt` (200 seeds × 26 weeks).

New rule, doc 02 §13.1: each campaign rolls flop ×0 / weak ×0.5 / expected ×1 / good ×1.5 /
big hit ×3.5 (15 / 25 / 35 / 18 / 7% before modifiers; mean 0.99), shifted by audience
fit, menu freshness, rating and repeating the same campaign within 21 days.

| Owner markets + visits weekly | Owner-run | Trainee | Junior | Capable | Senior | Veteran |
|---|---|---|---|---|---|---|
| Before (entry 3) | +3.9k | −0.2k | +0.3k | +1.0k | +1.6k | +2.1k |
| After | +3.8k | −0.2k | +0.3k | +0.9k | +1.5k | +2.0k |

Average profit falls about 0.1k (a big hit is partly wasted because buzz caps at 1; a
flop is a full loss). Demand still holds at −3%. Risk rises: for the one-outlet-with-loan
test company, Capable survival went 97% → 70%. That is the intended effect — same
average, less certainty.

**Reacting to a bad ad, measured.** A fourth scripted owner ("adaptive") does the same
as the competent one but, when a local ad flops or draws a weak response, runs flyers
the next day (a different channel, so no repeat penalty).

| Owner markets + visits weekly | Owner-run | Trainee | Junior | Capable | Senior | Veteran |
|---|---|---|---|---|---|---|
| Same ad every 4 weeks | +3.8k | −0.2k | +0.3k | +0.9k | +1.5k | +2.0k |
| Switches channel after a bad ad | +4.0k | −0.2k | +0.4k | +1.1k | +1.7k | +2.3k |

Worth about +0.1k to +0.3k a week, and it removes most of the added risk: Capable
survival 70% → 89%. It costs about 2.7 extra campaigns per 26 weeks.

Observed outcome rates over all campaigns: flop 12–14%, big hit 8–11% (targets in doc 06 §4).
The bot report now prints campaigns per run, flop %, big-hit % and marketing as a share of revenue.

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

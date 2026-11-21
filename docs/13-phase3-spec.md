# 13 — Phase 3: the Group (Stage 5)

Doc 09 asks for this spec before Phase 3 is built. It is deliberately small: the group
stage is the game's ending, not a second game.

## 1. Entering Stage 5

Stage 4 (Chain) → Stage 5 (Group) when **company value ≥ `STAGE5_VALUATION` (2,000,000)**
(doc 02 §14.4, summed over every trading outlet; franchises add `FRANCHISE_VALUE`
(30,000) each).

## 2. A second brand

- From Stage 5 the Expand page offers a **brand** choice: any cuisine theme (doc 04 §2).
- An outlet bought or built with another cuisine gets that cuisine's menu and kitchen
  stations (its old stations are replaced; storage and support equipment stay).
- `GameState.brands` lists the cuisines the company runs, first = the original brand.
- Each brand's rating is the average of its outlets' ratings (shown per outlet; no
  separate brand number is stored).

## 3. Franchising

- `StartFranchise`: needs Stage 5 and at least one outlet with a **gold** badge (doc 11
  §D.1 — "runs well without me" is what a franchisee pays for).
- Pays `FRANCHISE_SIGNING_FEE` (25,000) now and `FRANCHISE_WEEKLY_FEE` (600) every Sunday.
- No control: each Sunday, with chance `FRANCHISE_SCANDAL_CHANCE` (0.02) × franchises,
  a franchisee embarrasses the brand: every outlet's rating −0.1.

## 4. Acquisitions

The outlet market (doc 02 §15.9 route A) is the acquisition channel; at Stage 5 it can
buy into another cuisine (§2).

## 5. Ending

- Goal `obj_5_second_brand`: three trading outlets of a second brand.
- Completing it shows the ending: the story in one line, the final company value as the
  score. `EndGame` marks the game as ended; play continues as a sandbox.

## 6. Not in this phase

Regional managers, brand-level marketing and franchise contracts with terms are left out
until a playtest shows the group stage needs more to do.

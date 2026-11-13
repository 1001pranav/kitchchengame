# 03 — Data Schemas

Two kinds of data:

- **Content** — read-only JSON shipped in `packages/sim_core/data/` (also bundled as
  Flutter assets). Never modified at runtime.
- **State** — the save game. One JSON document per save slot.

Shapes are written in a compact notation: `field: type`, `?` = optional, `[]` = list,
`{K: V}` = map. Implement each as a Dart class with hand-written `fromJson` / `toJson`
(no code generation). Ids are lower_snake_case strings with a type prefix
(`ing_`, `dish_`, `eq_`, `sup_`, `inc_`, `trait_`, `loc_`, `staff_`, `obj_`).
Runtime-created ids are `<prefix><counter>` using `state.nextId` (e.g. `staff_17`).

**Rule:** every content file is validated on load (`ContentValidator`); a validation
failure is a thrown error listing file, id and field. Validation rules are listed per file.

---

## 1. Content files

### 1.1 `balance.json`
Flat map `{CONSTANT_NAME: number | number[] | map}` holding every UPPER_CASE constant and
table from `02-simulation-spec.md` (dow factors, arrival weights, patience, wages,
difficulty table, tier table, location classes, marketing table, etc.).
Validation: all keys referenced by code exist (a single `BalanceKeys` list in code).

### 1.2 `ingredients.json` — `Ingredient[]`
```
id: string            name: string (localisation key)
category: "dry" | "produce" | "dairy" | "meat_fish" | "frozen"
storage: "dry" | "chilled" | "frozen"
shelfLifeDays: int    baseCost: double (coins per unit, 2 decimals)
```

### 1.3 `dishes.json` — `Dish[]`
```
id: string            name: string        theme: "italian"|"chinese"|"mexican"|"indian"
course: "starter" | "main" | "side" | "dessert" | "drink"
station: "stove"|"oven"|"fryer"|"grill"|"wok"|"tandoor"|"cold"
prepTicks: int (1–10) skillReq: int (0–100)   popularity: double (default 1.0)
recipe: [{ingredientId: string, qty: int}]
```
`basePrice` is **derived at load**, not stored:
`round(Σ(qty × baseCost) / FOOD_COST_TARGET[course])` with targets starter 0.30,
main 0.32, side 0.28, dessert 0.25, drink 0.20.
Validation: every ingredient exists; each theme has exactly 3 starters, 5 mains, 2 sides
and 2 dessert/drink; station is in the theme's station list.

### 1.4 `themes.json` — `Theme[]`
```
id: string   name: string   stations: string[]   startingEquipment: [{type, count}]
namePools: {restaurant: string[], staffFirst: string[], staffLast: string[]}
festivals: [{id, name, month: int, day: int, durationDays: int, demandMult: double}]
skin: string (asset folder name)
```

### 1.5 `equipment.json` — `EquipmentType[]`
```
type: string   name: string   kind: "station" | "storage" | "support"
station?: string   slots?: int                 (kind = station)
storage?: "dry"|"chilled"|"frozen"   capacity?: int   (kind = storage)
price: int   wearPerDay: double
```

### 1.6 `suppliers.json` — `Supplier[]`
```
id: string   name: string   categories: string[]
priceMult: double   quality: int (0–100)   reliability: double (0–1)
minOrder: int   leadDays: int (0 or 1)   creditDays: int
```

### 1.7 `traits.json` — `Trait[]`
```
id: string   name: string   description: string   roles?: string[] (if restricted)
modifiers: {key: number}     (keys from the fixed list in doc 04 §5)
```

### 1.8 `incidents.json` — `IncidentDef[]`
```
id: string   title: string   text: string         (keys; may contain {staff}, {equipment}, {amount})
timing: "prep" | "service" | "close"
trigger: Condition          weight: double     cooldownDays: int
forced?: bool   tags?: string[]   ("observation", "hidden_problem", theme id …)
subject?: "staff" | "equipment" | "supplier" | "none"   subjectFilter?: Condition
options: [{
  id: string   label: string
  requires?: Condition       (option hidden/disabled when false)
  inPerson?: bool            (Phase 2: unavailable when the owner is not at the location)
  effects: Effect[]
}]
defaultOption: string        (applied when ignored)
```
`Condition` and `Effect` grammars are defined in `05-incident-catalogue.md` §2.

### 1.9 `tiers.json`, `locations.json`, `objectives.json`
```
Tier:      id, price, loan, staffRoles: string[], skillRange: [int,int], morale: int,
           equipmentCondition: [int,int], reputation: double, locationClass: string,
           tables: int, hiddenProblems: [int,int], rentOverride?: int
LocationClass: id, baseFootfall: int, weeklyRent: int, segmentMix: {segment: double}
Objective: id, stage: int, text: string, condition: Condition, reward: Effect[]
```

### 1.10 Text
All player-visible strings are keys resolved through `strings_<locale>.json`
(`{key: text}`). MVP ships `strings_en.json` only. Content files contain keys, never prose.

## 2. State (save file)

### 2.1 Envelope
```
SaveFile:
  saveVersion: int          (start at 1; bump on any breaking change + write a migration)
  contentVersion: string
  createdAt, savedAt: string (ISO-8601; written by the app layer, never read by the sim)
  state: GameState
```

### 2.2 `GameState`
```
seed: int                 rngState: int            nextId: int
difficulty: "easy"|"normal"|"hard"
date: {year: int, month: int, day: int, dayIndex: int}     (dayIndex counts from 0; weekday = dayIndex % 7, 0 = Monday)
phase: "prep" | "service" | "close" | "gameOver"
stage: int (1–5)
company: Company
locations: Location[]
ownerLocationId: string
owner: Owner
pendingIncidents: IncidentInstance[]
scheduledIncidents: [{incidentId, dueDayIndex, context}]
incidentCooldowns: {incidentId: int (dayIndex when available again)}
flags: {string: number}       (free-form sim flags, e.g. "pests_loc_1": 1)
objectivesDone: string[]
history: History
```

### 2.3 `Company`
```
cash: int
loans: [{id, principal0: int, outstanding: int, weeklyRate: double, termWeeks: int,
         weeksPaid: int, missedInRow: int,
         securedLocationId?: string, lender: "bank"|"private"}]
bankRefusesUntilDayIndex: int
creditScore: int      negativeDays: int     investorShare: double (0 or 0.2)
supplierRelations: {supplierId: int}
payables: [{supplierId, amount: int, dueDayIndex: int}]
ingredientPriceIndex: {ingredientId: double}
```

### 2.4 `Location`
```
id, name: string      themeId: string ("mixed" allowed)     locationClass: string
tierId?: string       weeklyRent: int      reputation: double     hygiene: double
tables: [{id: int, seats: int, state: "free"|"occupied"|"dirty"}]
staff: Staff[]        equipment: Equipment[]
stock: Batch[]        pendingOrders: Order[]
menu: [{dishId, price: int, enabled: bool}]
rotaOverrides: [{staffId, dayIndex: int, works: bool, reason: "swap"|"workedDayOff"|"training"}]
                                  (base rota = everyone works except on their own `dayOff`, doc 02 §7.7)
negotiatedUntilDayIndex?: int   weeklyDeal?: {category: string, untilDayIndex: int}
campaigns: [{id: int, type, startDayIndex: int, daysLeft: int, cost: int, boost: double, outcome: string,
            mult: double, revealed: bool, buzzLeft: double, extraGroups: double, extraProfit: double,
            discountGiven: double, settled: bool}]      (kept after they end, last 30 per outlet)
campaignTotals: {type: {count: int, spend: int, extraProfit: int}}     (settled campaigns only)
lastCampaignDayIndex: {type: int}
buzz: double   freshness: double   competition: double   lastDishRotationDayIndex: int
format: string ("neighbourhood" in Phase 1)   badge: "none"|"bronze"|"silver"|"gold"
policies?: Policies   managerId?: string
lastOwnerVisitDayIndex: int   lossWeeks: int   crisis: bool
lease: {termWeeks: int, endDayIndex: int, breakFeeWeeks: int, deposit: int, rentFixed: bool}
fitOut?: "basic"|"standard"|"premium"   patienceMult: double   opensDayIndex: int
applicants: Applicant[]   launchCampaignUntilDayIndex?: int
ledger: {invested: int, returned: int, weekContribution: int, contributions: int[] (last 52 weeks)}
lastCoachingDayIndex: int   managerBonusPct: double
listing?: {listedDayIndex: int, offersDueDayIndex: int, offers: [{id: int, amount: int, expiresDayIndex: int}]}
utilitiesAccrued: int
hiddenProblems: [{incidentId, revealed: bool, dueDayIndex: int}]
today: DayStats       service?: ServiceState      (service present only during phase "service")
```

### 2.5 `Staff`
```
id, name: string   role: string   skill: int   reliability: int   morale: double
loyalty: int   honesty: int   fatigue: double   wage: int   traits: string[]
daysWorked: int   consecutiveDays: int   hiredDayIndex: int
managerSkills?: {people: int, upkeep: int, stock: int}   (role = manager only; `skill` = their mean)
managerSinceDayIndex?: int   managerProfile?: "allRounder"|"people"|"tightShip"|"numbers"
managerPotential?: int   (grade is derived from the mean of managerSkills, never stored)
dayOff: int (0–6)   preferredDayOff: int   preferenceKnown: bool   lastWorkedDayOffWeek: int
isDeputy: bool
moodModifiers: [{key: string, score: double, untilDayIndex: int}]
lastGrowthDayIndex: int   lastRefusalDayIndex?: int   rushDaysLast7: int
status: "active" | "absent" | "late" | "training" | "notice"
statusUntilDayIndex?: int   lateUntilTick?: int
```

### 2.6 `Equipment`, `Batch`, `Order`
```
Equipment: id, type: string, condition: double, ageDays: int, broken: bool, availableFromDayIndex: int,
           leased: bool, leaseFeeWeekly: int, hiddenFaultUntilDayIndex?: int,
           lastMaintenanceDayIndex: int, shakyUntilDayIndex?: int
Batch:     ingredientId, qty: int, quality: double, daysLeft: int
Order:     id, supplierId, lines: [{ingredientId, qty: int, unitPrice: double}],
           dueDayIndex: int, total: int
```

### 2.7 `Owner`
```
locationId?: string (null while travelling)   travelToLocationId?: string   arrivesTick?: int
ticksAtLocationToday: {locationId: int}
energy: double   exhaustedDays: int   restingToday: bool
coverRole?: "server" | "till" | "kitchen" | "dishes"
queue: int[] (task ids, max 3)   currentTaskId?: int   busyUntilTick?: int   idleTicks: int
```

### 2.8 `ServiceState` (only while a service is running)
```
tick: int
arrivals: [{tick: int, size: int, segment: string}]      (remaining, sorted)
groups: [{id: int, size, segment, state, tableId?: int, waitTicks: {state: int},
          patienceTotal: double, unavailableCount: int, tickets: int[], bill: int, ill: bool}]
tickets: [{id: int, groupId: int, dishId: string, state: "waiting"|"cooking"|"ready"|"cancelled",
           quality?: double}]
tasks: [{id: int, type: string, groupId?: int, ticketId?: int, tableId?: int,
         state: "waiting"|"active"|"done", workerId?: string ("owner" allowed),
         createdTick: int, endsTick?: int}]
dirtyDishes: double
eightySixed: string[]       nextLocalId: int
lastIncidentRollTick: int
```

### 2.9 `DayStats` and `History`
```
DayStats: groupsArrived, groupsServed, walkouts: int; revenue, tips, ingredientCost,
          wasteCost, otherCosts: int; starsSum: double; dishesSold: {dishId: int};
          dishesUnavailable: {dishId: int}; events: SimEventRecord[] (max 200)
History:  days: DayStats-summary[] (last 56), weeks: WeekSummary[] (last 52),
          timeline: [{dayIndex, key: string, args: map}]   (major events for the game-over recap)
```

### 2.10 `IncidentInstance`
```
instanceId: int   incidentId: string   context: {staffId?, equipmentId?, supplierId?, amount?}
raisedDayIndex: int   raisedTick?: int   expiresTick?: int
```

## 3. Commands (player → sim)

Every player action is a command object `{type, ...args}`; the sim validates and either
applies it or returns an error code. Commands are the **only** way state changes besides
`tick()`, `beginDay()` and `endDay()`.

| Command | Args | Valid in |
|---|---|---|
| NewGame | seed, difficulty, themeId | — |
| BuyDueDiligence | offerIndex | market |
| BuyRestaurant | offerIndex | market |
| SetDayOff | staffId, weekday | prep, close (applies from next Monday) |
| WorkDayOff | staffId | prep, close (for the coming day; may be refused) |
| PlaceOrder | locationId, supplierId, lines | prep, close |
| CancelOrder | orderId | same phase as placed |
| SetPrice | locationId, dishId, price | prep, close |
| SetDishEnabled | locationId, dishId, enabled | any |
| Hire | locationId, applicantId, wage | prep, close |
| Fire | staffId | prep, close |
| SetWage | staffId, wage | prep, close |
| Train | staffId | prep, close |
| Maintain | equipmentId | prep, close |
| BuyEquipment | locationId, type, secondHand | prep, close |
| SellEquipment | equipmentId | prep, close |
| ApplyLoan | amount, termWeeks, securedLocationId?, lender | prep, close — result is approved / counterOffer(amount) / rejected(reason) |
| AcceptCounterOffer | — | same phase as the application |
| RepayLoan | loanId, amount | prep, close |
| StartCampaign | locationId, type | prep, close (stage ≥ 2) |
| ReworkMenu | locationId | prep, close |
| SetParLevel | locationId, ingredientId, par, supplierId | prep, close (stage ≥ 2) |
| StartService | — | prep |
| OwnerQueueTask | taskId | service |
| OwnerSetCover | role or null | prep, service |
| OwnerRest | — | prep |
| ResolveIncident | instanceId, optionId | any |
| EndDay | — | close |
| (Phase 2) OwnerTravel | toLocationId | prep, service |
| (Phase 2) SetPolicies, AppointManager, BuyLocation, BuildLocation, CloseLocation, Audit, TransferStaff, Promote, Renovate, SetManagerBonus | | prep, close |
| (Phase 2) ListOutlet, UnlistOutlet, AcceptSaleOffer(offerId), QuickSale | locationId | prep, close |
| (Phase 2) SignLease(siteId, size, termYears, fitOut), LeaseEquipment(locationId, type), ReturnLeasedEquipment(equipmentId), BuyLaunchCampaign(locationId), PostponeOpening(locationId, days) | | prep, close |
| (Phase 2) AnswerRequest | requestId, answer: approve/deny/cheaper | prep, close |

`GameState.requests: [{id, locationId, kind, subjectId?, cost: int, cheaperCost?: int, reasonKey, raisedDayIndex}]`
holds open manager requests. `Policies` = `{parLevels, priceLevel, maintenanceThreshold,
wageBand, overtimeAllowed, incidentStance, spendingLimit, mayHire, mayGiveRaises}`.

`GameState.ownerLocationId` is the location the owner **starts the day at**;
`owner.locationId` is where the owner is right now. All commands that take a
`locationId` may be issued for any location regardless of where the owner is, except
`OwnerQueueTask`, `OwnerSetCover` and `Audit`, which need the owner there.

Error codes are an enum (`notEnoughCash`, `wrongPhase`, `unknownId`, `belowMinimumOrder`,
`limitReached`, `locked`, `invalidValue`). The UI shows a localised message per code.

## 4. Events (sim → UI)

`tick()` and commands return a list of `SimEvent {type, args}` for the UI to animate and
log (e.g. `groupArrived`, `groupWalkedOut`, `taskCompleted`, `dishUnavailable`,
`platesFull`, `incidentRaised`, `cashChanged`, `staffAbsent`, `equipmentBroke`,
`deliveryArrived`, `batchExpired`, `stageReached`). Events carry everything the UI needs;
the UI never diffs state to discover what happened. Important events are also appended
to `DayStats.events` so the Close report can explain the day.

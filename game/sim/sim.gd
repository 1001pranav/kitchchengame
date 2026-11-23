class_name Sim
extends RefCounted
## The simulation (port of sim_core's Sim). GENERATED from sim/parts/*.gd by
## tools/build_sim.py — edit the parts, not this file.
## Names follow the original Dart so the two can be compared line by line.

const M = preload("res://sim/model.gd")

const SimError := {
	"notEnoughCash": "notEnoughCash", "wrongPhase": "wrongPhase", "unknownId": "unknownId",
	"belowMinimumOrder": "belowMinimumOrder", "limitReached": "limitReached", "locked": "locked",
	"invalidValue": "invalidValue", "refused": "refused",
}

class CommandResult:
	var ok: bool
	var error = null
	var message = null
	var events: Array = []
	var value = null
	func _init(o: bool, e = null, m = null, ev: Array = [], v = null) -> void:
		ok = o; error = e; message = m; events = ev; value = v
	static func fail(e: String, m = null) -> CommandResult:
		return CommandResult.new(false, e, m)
	static func good(v = null, m = null) -> CommandResult:
		return CommandResult.new(true, null, m, [], v)

## One line of a "Why?" breakdown.
class Factor:
	var label: String; var value: float; var display: String
	func _init(l: String, v: float, d: String) -> void:
		label = l; value = v; display = d

class Explanation:
	var title: String; var valueText: String; var kind: String
	var factors: Array; var howToImprove = null
	func _init(t: String, vt: String, k: String, f: Array, how = null) -> void:
		title = t; valueText = vt; kind = k; factors = f; howToImprove = how

class Forecast:
	var groups: int; var label: String; var factors: Dictionary
	func _init(g: int, l: String, f: Dictionary) -> void:
		groups = g; label = l; factors = f

var content: Content
var state: M.GameState
var _rng: SimRng
var _events: Array = []

var b: Content.Balance:
	get: return content.balance
var rng: SimRng:
	get: return _rng

func _init(c: Content, s: M.GameState, r: SimRng) -> void:
	content = c; state = s; _rng = r

static func new_game(c: Content, seed: int, difficulty: String, theme_id := "italian") -> Sim:
	var r := SimRng.new(seed)
	var st := M.GameState.new()
	st.seed = seed; st.rngState = r.state; st.difficulty = difficulty; st.themeId = theme_id
	st.cash = c.balance.i("START_CAPITAL")
	var sim := Sim.new(c, st, r)
	sim._generateOffers()
	sim._syncRng()
	return sim

static func from_save(c: Content, save: Dictionary) -> Sim:
	var migrated := migrateSave(save)
	var st: M.GameState = M.GameState.new().from_json(migrated.state)
	return Sim.new(c, st, SimRng.from_state(st.rngState))

const currentSaveVersion := 1

static func migrateSave(save: Dictionary) -> Dictionary:
	var v := int(save.get("saveVersion", 1))
	assert(v <= currentSaveVersion, "This save was made by a newer version of the game.")
	return save

func toSave() -> Dictionary:
	_syncRng()
	return {"saveVersion": currentSaveVersion, "state": state.to_json()}

func _syncRng() -> void:
	state.rngState = _rng.state

# ------------------------------------------------------------ helpers

var _ctx: M.Location = null
var loc: M.Location:
	get: return _ctx if _ctx != null else state.viewLoc

## Runs [f] with [l] as the current location.
func at(l: M.Location, f: Callable) -> Variant:
	var prev := _ctx
	_ctx = l
	var r = f.call()
	_ctx = prev
	return r

## Location-scoped flags (pests, leak, bookings …).
func lf(k: String) -> bool:
	return state.flag("%d:%s" % [loc.id, k])

var themeOfLoc: Content.CuisineTheme:
	get: return content.themes.get(loc.themeId, theme)
var theme: Content.CuisineTheme:
	get: return content.themes[state.themeId]
func diff(key: String) -> float:
	return b.by_difficulty(key, state.difficulty)
func emit(type: String, args := {}) -> void:
	_events.append({"type": type, "args": args})
func _drain() -> Array:
	_syncRng()
	var out := _events.duplicate()
	_events.clear()
	return out

func _note(kind: String, text: String, value := 0) -> void:
	loc.today.add(kind, text, value)
func _timeline(text: String) -> void:
	state.timeline.append(M.TimelineEntry.mk(state.dayIndex, text))
	if state.timeline.size() > 60:
		state.timeline.remove_at(0)

## Every coin movement goes through here so the day's P&L stays complete.
func spend(amount: int, bucket: String) -> void:
	state.cash -= amount
	var t := loc.today
	match bucket:
		"ingredients": t.ingredientSpend += amount
		"wages": t.wages += amount
		"rent": t.rent += amount
		"utilities": t.utilities += amount
		"upkeep": t.upkeep += amount
		"marketing": t.marketing += amount
		"interest": t.interest += amount
		"financing": pass
		_: t.other += amount
	emit("cashChanged", {"delta": -amount})

func earn(amount: int, bucket: String) -> void:
	state.cash += amount
	if bucket == "revenue":
		loc.today.revenue += amount
	elif bucket == "other":
		loc.today.other -= amount
	emit("cashChanged", {"delta": amount})

func money(v) -> String:
	var n := roundi(v)
	var s := str(absi(n))
	var buf := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			buf += ","
		buf += s[i]
	return ("−" if n < 0 else "") + buf

func dateLabel(day = null) -> String:
	var d: int = state.dayIndex if day == null else day
	return "Day %d · %s" % [d + 1, M.weekdays[posmod(d, 7)]]

# ------------------------------------------------------------ public API

func apply(c: Dictionary) -> CommandResult:
	var r: CommandResult = _handle(c)
	var ev := _drain()
	return CommandResult.new(r.ok, r.error, r.message, ev, r.value)

## Advance one service tick. Only valid during service.
func tick() -> Array:
	if state.phase != "service":
		return []
	_serviceTickAll()
	return _drain()

func beginDay() -> Array:
	_beginDay()
	return _drain()

func forecast() -> Forecast:
	return _forecast()
func formatInfo(l: M.Location) -> Dictionary:
	return _format(l)
func explain(target: String, id = null) -> Explanation:
	return _explain(target, id)

# ------------------------------------------------------------ Dart helpers

## Dart's num.clamp keeps the type of the receiver for in-range values.
static func clampd(v: float, lo: float, hi: float) -> float:
	return clampf(v, lo, hi)

## Sort like Dart's List.sort with a compare function.
static func dsort(a: Array, cmp: Callable) -> void:
	DSort.sort(a, cmp)

static func cmpn(x, y) -> int:
	return -1 if x < y else (1 if x > y else 0)

## Dart String.compareTo (code-unit order).
static func cmps(x: String, y: String) -> int:
	return -1 if x < y else (1 if x > y else 0)

static func first_or_null(a: Array, f: Callable) -> Variant:
	for e in a:
		if f.call(e):
			return e
	return null

static func any(a: Array, f: Callable) -> bool:
	for e in a:
		if f.call(e):
			return true
	return false

static func count(a: Array, f: Callable) -> int:
	var n := 0
	for e in a:
		if f.call(e):
			n += 1
	return n

static func remove_where(a: Array, f: Callable) -> void:
	var i := 0
	while i < a.size():
		if f.call(a[i]):
			a.remove_at(i)
		else:
			i += 1

static func every(a: Array, f: Callable) -> bool:
	for e in a:
		if not f.call(e):
			return false
	return true

# ================================================================ gen.dart
# Generators: restaurant offers, staff, applicants (doc 01 §4.3, doc 04 §3, §5, §6).

const hiddenProblemKinds := ["supplier_debt", "health_violation", "chef_leaving", "pests",
	"fridge_failing", "cashier_skimming", "lease_increase", "overdue_licence", "staff_feud", "fake_reviews"]

const hiddenProblemText := {
	"supplier_debt": "Unpaid bill to a supplier",
	"health_violation": "A health violation is about to be reported",
	"chef_leaving": "The head chef is planning to quit",
	"pests": "Pests are moving in",
	"fridge_failing": "The fridge is about to fail",
	"cashier_skimming": "The cashier takes money from the till",
	"lease_increase": "The landlord will raise the rent",
	"overdue_licence": "The trading licence is overdue",
	"staff_feud": "Two staff members are feuding",
	"fake_reviews": "Fake good reviews are about to be removed",
}

func _expectedWage(role: String, skill: float) -> int:
	if role == "manager":
		return _expectedManagerWage(skill)
	var base: float = b.dmap("BASE_WAGE")[role]
	return roundi(base * (0.6 + 0.8 * skill / 100))

func _rollTraits(role: String, forceBadApple := false) -> Array:
	var traits: Array = content.traits.values().filter(func(t): return t.roles == null or t.roles.has(role))
	var r := _rng.next_float()
	var n := 0 if r < 0.5 else (1 if r < 0.9 else 2)
	var out: Array = []
	if forceBadApple:
		out.append("trait_toxic" if _rng.chance(0.5) else "trait_hot_headed")
	for i in n:
		var t: String = _rng.pick(traits).id
		if out.has(t):
			continue
		if (t == "trait_toxic" and out.has("trait_mentor")) or (t == "trait_mentor" and out.has("trait_toxic")):
			continue
		out.append(t)
	return out

func _preferredDayOff() -> int:
	var r := _rng.next_float()
	if r < 0.25: return 5
	if r < 0.5: return 6
	return _rng.next_int(0, 4)

func _personName(used: Dictionary) -> String:
	for i in 20:
		var first: String = _rng.pick(theme.firstNames)
		var last: String = _rng.pick(theme.lastNames)
		var n := "%s %s." % [first, last[0]]
		if not used.has(n):
			used[n] = true
			return n
	return "%s %d" % [_rng.pick(theme.firstNames), state.nextId]

func _makeStaff(role: String, skill: float, morale: float, wageMult: float, usedNames: Dictionary, badApple := false) -> M.Staff:
	var rel := clampf(morale + _rng.range_f(-20, 20), 5, 98)
	var loy := clampf(morale + _rng.range_f(-20, 20), 5, 98)
	var traits := _rollTraits(role, badApple)
	var honesty := _rng.range_f(30, 95)
	if traits.has("trait_light_fingered"):
		honesty = minf(honesty, 30)
	var s := M.Staff.new()
	s.id = state.allocId()
	s.name = _personName(usedNames)
	s.role = role
	s.skill = round(skill)
	s.reliability = round(rel)
	s.loyalty = round(loy)
	s.honesty = round(honesty)
	s.morale = round(clampf(morale, 0, 100))
	s.fatigue = 20
	s.wage = roundi(_expectedWage(role, skill) * wageMult)
	s.traits = traits
	s.dayOff = 0
	s.preferredDayOff = _preferredDayOff()
	return s

## Days off across Mon–Thu; same-role holders on different days (doc 02 §7.7).
func _assignDaysOff(staff: Array) -> void:
	var used := {}
	var cursor := 0
	for s in staff:
		if not used.has(s.role):
			used[s.role] = {}
		var taken: Dictionary = used[s.role]
		var d := cursor % 4
		var k := 0
		while k < 4 and taken.has(d):
			d = (d + 1) % 4
			k += 1
		s.dayOff = d
		taken[d] = true
		cursor += 1

func _generateOffers() -> void:
	state.offers.clear()
	var names: Array = theme.restaurantNames.duplicate()
	_rng.shuffle(names)
	var ni := 0
	for tier in content.tiers:
		var location := _generateLocation(tier, names[ni % names.size()])
		ni += 1
		state.offers.append(M.Offer.mk(tier.id, tier.price, tier.loan, location))

func _generateLocation(tier: Content.Tier, name: String) -> M.Location:
	var cls: Content.LocationClass = content.locationClasses[tier.locationClass]
	# Tables: 40% two-seat, 45% four-seat, 15% six-seat, at least one six.
	var n := tier.tables
	var six := maxi(1, roundi(n * 0.15))
	var four := roundi(n * 0.45)
	var two := n - six - four
	var seats: Array = []
	for i in two: seats.append(2)
	for i in four: seats.append(4)
	for i in six: seats.append(6)
	var hyg: float = b.dmap("START_HYGIENE")[tier.id]
	var l := M.Location.new()
	l.id = 1
	l.name = name
	l.tierId = tier.id
	l.classId = cls.id
	l.rentWeekly = tier.rentOverride if tier.rentOverride != null else cls.weeklyRent
	l.tableSeats = seats
	l.reputation = tier.reputation
	l.hygiene = hyg
	l.buzz = b.d("BUZZ_START")
	l.freshness = b.d("FRESHNESS_START")
	l.awareness = b.d("TAKEOVER_START_AWARENESS")
	l.themeId = theme.id
	# Staff.
	var usedNames := {}
	var badIndex := _rng.next_int(0, tier.staffRoles.size() - 1) if tier.badApple else -1
	for i in tier.staffRoles.size():
		var role: String = tier.staffRoles[i]
		var skill := float(_rng.next_int(tier.skillRange[0], tier.skillRange[1]))
		var morale := tier.morale + _rng.range_f(-5, 5)
		l.staff.append(_makeStaff(role, skill, morale, tier.wageMult, usedNames, i == badIndex))
	_assignDaysOff(l.staff)
	# Equipment.
	var addEq := func(type: String, cnt: int) -> void:
		for i in cnt:
			var c := float(_rng.next_int(tier.equipmentCondition[0], tier.equipmentCondition[1]))
			var age := _rng.next_int(tier.equipmentAgeYears[0] * 336, tier.equipmentAgeYears[1] * 336)
			var e := M.Equipment.new()
			e.id = state.allocId(); e.type = type; e.condition = c; e.ageDays = age
			e.condition = minf(e.condition, _maxCondition(e))
			l.equipment.append(e)
	var set_id := "base" if (tier.stationSet == "excellent" or tier.stationSet == "best") else tier.stationSet
	for e in theme.startingEquipment[set_id]:
		addEq.call(e[0], e[1])
	if tier.stationSet == "excellent":
		for e in theme.startingEquipment["excellentAdds"]:
			addEq.call(e[0], e[1])
	elif tier.stationSet == "best":
		var first = theme.startingEquipment["excellentAdds"][0]
		addEq.call(first[0], 1)
	addEq.call("eq_fridge", 2 if tier.extraFridge else 1)
	addEq.call("eq_freezer", 1)
	addEq.call("eq_shelving", 1)
	addEq.call("eq_dish_machine", 1)
	addEq.call("eq_hood", 1)
	addEq.call("eq_pos", 1)
	if tier.hasAc: addEq.call("eq_ac", 1)
	if tier.hasGenerator: addEq.call("eq_generator", 1)
	if tier.oneBroken:
		var stations: Array = l.equipment.filter(func(e): return content.equipment[e.type].kind == "station")
		_rng.pick(stations).broken = true
	# Menu: every theme dish at base price.
	var start = theme.startingMenu
	for d in content.dishes_for(theme.id):
		var mi := M.MenuItem.new()
		mi.dishId = d.id; mi.price = d.basePrice; mi.enabled = start == null or start.has(d.id)
		l.menu[d.id] = mi
	for ing in content.ingredients.values():
		l.priceIndex[ing.id] = 1.0
	for s in content.suppliers.values():
		l.supplierRel[s.id] = 50
	# Starting stock.
	var use := _expectedDailyUse(l)
	for ingId in use:
		var perDay: float = use[ingId]
		var ing: Content.Ingredient = content.ingredients[ingId]
		var qty := ceili(perDay * tier.stockDays)
		if qty <= 0:
			continue
		var days := _rng.next_int(1, ing.shelfLifeDays)
		if tier.id == "worst" and ing.storage == "chilled" and _rng.chance(0.3):
			days = 1
		l.stock.append(M.Batch.mk(ingId, qty, 65, days))
	# Hidden problems.
	var cnt := _rng.next_int(tier.hiddenProblems[0], tier.hiddenProblems[1])
	var kinds: Array = hiddenProblemKinds.duplicate()
	_rng.shuffle(kinds)
	for i in cnt:
		var k: String = kinds[i]
		var hp := M.HiddenProblem.mk(k)
		match k:
			"supplier_debt":
				hp.amount = _rng.next_int(8, 20) * 1000
				hp.dueDay = _rng.next_int(14, 28)
			"health_violation":
				hp.dueDay = _rng.next_int(7, 14)
				l.hygiene = maxf(0, l.hygiene - 20)
			"chef_leaving":
				hp.dueDay = _rng.next_int(10, 20)
				for s in l.staff:
					if s.role == "headChef":
						s.loyalty = 10
						s.morale = 30
			"pests":
				hp.dueDay = 5
			"fridge_failing":
				for e in l.equipment:
					if e.type == "eq_fridge":
						e.condition = 30
						break
			"cashier_skimming":
				for s in l.staff:
					if s.role == "cashier":
						s.honesty = 15
						if not s.traits.has("trait_light_fingered"):
							s.traits.append("trait_light_fingered")
			"lease_increase":
				hp.dueDay = 84
			"overdue_licence":
				hp.dueDay = 7
			"staff_feud":
				var a := _rng.next_int(0, l.staff.size() - 1)
				var c := _rng.next_int(0, l.staff.size() - 1)
				if c == a:
					c = (a + 1) % l.staff.size()
				l.staff[a].morale = maxf(0, l.staff[a].morale - 20)
				l.staff[c].morale = maxf(0, l.staff[c].morale - 20)
			"fake_reviews":
				hp.dueDay = _rng.next_int(14, 21)
		l.hidden.append(hp)
	return l

## Wire hidden problems into the running game at purchase (doc 05 §4).
func _activateHiddenProblems(l: M.Location) -> void:
	for hp in l.hidden:
		match hp.kind:
			"supplier_debt":
				l.payables.append(M.Payable.mk(state.allocId(), "sup_standard", hp.amount, hp.dueDay,
					"Old bill from City Foodservice (left by the last owner)", true))
			"health_violation":
				state.scheduled.append(M.Scheduled.mk("inc_inspection", hp.dueDay, null, null, l.id))
			"chef_leaving":
				var chef = first_or_null(l.staff, func(s): return s.role == "headChef")
				if chef != null:
					state.scheduled.append(M.Scheduled.mk("inc_resignation", hp.dueDay, chef.id, null, l.id))
			"pests":
				state.scheduled.append(M.Scheduled.mk("@flag:pests", hp.dueDay, null, null, l.id))
			"lease_increase":
				state.scheduled.append(M.Scheduled.mk("inc_landlord_rent", hp.dueDay, null, "hidden", l.id))
			"overdue_licence":
				state.scheduled.append(M.Scheduled.mk("inc_licence_overdue", hp.dueDay, null, null, l.id))
			"staff_feud":
				state.flags["%d:feud" % l.id] = 28
			"fake_reviews":
				state.scheduled.append(M.Scheduled.mk("@fake_reviews", hp.dueDay, null, null, l.id))

func _generateApplicants() -> void:
	state.applicants.clear()
	var n := _rng.next_int(3, 5)
	var centre := 20 + 10 * loc.reputation
	var hap := _outletHappiness()
	var usedNames := {}
	for s in loc.staff:
		usedNames[s.name] = true
	# Bias toward roles the outlet is short of.
	var counts := {}
	for r in M.roles:
		counts[r] = count(loc.staff, func(s): return s.role == r)
	for i in n:
		var weights: Array = []
		for r in M.roles:
			weights.append(4.0 if counts[r] == 0 else (2.0 if (r == "server" or r == "lineCook") else 1.0))
		var role: String = _rng.weighted(M.roles, weights)
		var skill := round(_rng.triangular(5, 95, clampf(centre, 10, 90)))
		var s := _makeStaff(role, skill, 60, 1, usedNames)
		s.hiredDay = state.dayIndex
		s.askingWage = roundi(_expectedWage(role, skill) * _rng.range_f(0.9, 1.2) * (1.15 - hap / 400))
		s.wage = s.askingWage
		state.applicants.append(s)

# ================================================================ demand.dart
# Calendar and demand (doc 02 §2, §5; doc 11 §A).

func _festivalOn(day: int) -> Content.Festival:
	var month := posmod(day / 28, 12) + 1
	var dom := posmod(day, 28) + 1
	for f in theme.festivals:
		if f.month == month and dom >= f.day and dom < f.day + f.durationDays:
			return f
	return null

func _priceIndexOf(l: M.Location) -> float:
	var sum := 0.0
	var n := 0
	var ref := _referencePriceMult()
	for m in l.menu.values():
		if not m.enabled:
			continue
		sum += m.price / (content.dishes[m.dishId].basePrice * ref)
		n += 1
	var pi := 1.0 if n == 0 else sum / n
	if _promoActive(l):
		pi *= 0.75
	return pi

## Customers' reference price rises ×1.03 a year (doc 11 §A.4).
func _referencePriceMult() -> float:
	return pow(b.d("YEARLY_COST_CREEP_WAGE"), state.dayIndex / 336)

func _promoActive(l: M.Location) -> bool:
	return any(l.campaigns, func(c): return c.type == "promoDay" and c.startDay == state.dayIndex)

func _marketingBoost(l: M.Location, day: int) -> float:
	var sum := 0.0
	for c in l.campaigns:
		if c.type == "blogger":
			continue
		if day >= c.startDay and day <= c.endDay:
			sum += c.boost
	return minf(sum, b.d("CAMPAIGN_BOOST_CAP"))

## Demand factors in order. The forecast leaves out the random term.
func _demandFactors(l: M.Location, day: int) -> Dictionary:
	var cls: Content.LocationClass = content.locationClasses[l.classId]
	var f := {}
	f["Base footfall"] = float(cls.baseFootfall)
	f["Rating"] = clampf(0.25 + 0.25 * l.reputation, 0.4, 1.5)
	f["Prices"] = clampf(1.5 - 0.5 * _priceIndexOf(l), 0.5, 1.3)
	f["Day of week"] = b.list("DOW_FACTOR")[posmod(day, 7)]
	f["Season"] = b.list("SEASON_FACTOR")[posmod(day / 28, 12) / 3]
	f["Advertising"] = 1 + _marketingBoost(l, day)
	var ev := 1.0
	var fest := _festivalOn(day)
	if fest != null:
		ev *= fest.demandMult
	for m in l.demandMods:
		if day <= m.untilDay:
			ev *= m.mult
	f["Events"] = ev
	f["Buzz"] = 0.90 + 0.20 * l.buzz
	f["Menu freshness"] = 0.94 + 0.10 * l.freshness
	f["Rivals"] = 1 - 0.30 * l.competition
	f["Awareness"] = l.awareness
	if l.format != "neighbourhood":
		var fm := _format(l)
		f["Type of outlet"] = fm["footfallMult"] * (fm["weekendMult"] if posmod(day, 7) >= 5 else 1.0)
	var th = content.themes.get(l.themeId)
	if th != null and th.isMixed:
		f["Wide menu"] = b.d("MIXED_DEMAND_MULT")
	return f

func _expectedGroups(l: M.Location, day: int) -> float:
	var g := 1.0
	var f := _demandFactors(l, day)
	for k in f:
		g *= f[k]
	return g

func _forecast() -> Forecast:
	var f := _demandFactors(loc, state.dayIndex)
	var g := roundi(_expectedGroups(loc, state.dayIndex))
	var base: int = content.locationClasses[loc.classId].baseFootfall
	var ratio := float(g) / base
	var label := "quiet" if ratio < 0.8 else ("normal" if ratio < 1.05 else ("busy" if ratio < 1.3 else "very busy"))
	return Forecast.new(g, label, f)

## Expected ingredient use for one day at forecast demand (stock, warnings, "Order usual").
func _expectedDailyUse(l: M.Location, day = null) -> Dictionary:
	var groups := _expectedGroups(l, state.dayIndex if day == null else day)
	var people := groups * b.d("AVG_GROUP_SIZE")
	var out := {}
	var enabled: Array = []
	for m in l.menu.values():
		if m.enabled:
			enabled.append(content.dishes[m.dishId])
	var courseChance := b.dmap("COURSE_CHANCE")
	for course in ["main", "starter", "side", "sweet"]:
		var inCourse: Array = enabled.filter(func(d): return d.courseGroup == course)
		if inCourse.is_empty():
			continue
		var perPerson: float = 1.0 if course == "main" else courseChance[course]
		var totalPop := 0.0
		for d in inCourse:
			totalPop += d.popularity
		for d in inCourse:
			var portions = people * perPerson * d.popularity / totalPop
			for r in d.recipe:
				out[r.ingredientId] = out.get(r.ingredientId, 0.0) + portions * r.qty
	return out

## Arrivals for today's service (doc 02 §5.2–5.3).
func _rollArrivals(l: M.Location, groups: int) -> Array:
	var fm := _format(l)
	var hw := b.list("HOUR_WEIGHTS")
	var hours: Array = []
	for h in hw.size():
		hours.append(hw[h] * (fm["lunchMult"] if (h == 1 or h == 2) else (fm["eveningMult"] if h >= 6 else 1.0)))
	var cls: Content.LocationClass = content.locationClasses[l.classId]
	var sizeW := b.list("GROUP_SIZE_WEIGHTS")
	var idx: Array = []
	for i in hours.size():
		idx.append(i)
	var out: Array = []
	for i in groups:
		var h: int = _rng.weighted(idx, hours)
		var tick := h * b.i("TICKS_PER_HOUR") + _rng.next_int(0, b.i("TICKS_PER_HOUR") - 1)
		if tick > b.i("LAST_SEATING_TICK"):
			tick = b.i("LAST_SEATING_TICK")
		var size: int = _rng.weighted([1, 2, 3, 4, 5, 6], sizeW)
		var w: Array = []
		for s in M.segments:
			w.append(cls.segmentMix[s] * ((2.0 if (h == 1 or h == 2) else (0.5 if h > 6 else 1.0)) if s == "office" else 1.0))
		out.append(M.Arrival.mk(tick, size, _rng.weighted(M.segments, w)))
	dsort(out, func(a, c): return cmpn(a.tick, c.tick))
	return out

# ================================================================ inventory.dart
# Inventory: batches, FIFO, capacity, prices, orders, deliveries, payables (doc 02 §9).

## FIFO (oldest = fewest days left first). Returns the cost of what was used.
func _consumeRecipe(dish: Content.Dish, onBatch: Callable) -> int:
	var cost := 0.0
	for r in dish.recipe:
		var need: int = r.qty
		var batches: Array = loc.stock.filter(func(x): return x.ingredientId == r.ingredientId)
		dsort(batches, func(a, c): return cmpn(a.daysLeft, c.daysLeft))
		for bt in batches:
			if need <= 0:
				break
			var take := mini(need, bt.qty)
			bt.qty -= take
			need -= take
			onBatch.call(bt.quality, bt.daysLeft)
		cost += r.qty * content.ingredients[r.ingredientId].baseCost * loc.priceIndex.get(r.ingredientId, 1.0)
	remove_where(loc.stock, func(x): return x.qty <= 0)
	return roundi(cost)

func _capacity(storage: String) -> int:
	var n := 0
	for e in loc.equipment:
		var t: Content.EquipmentType = content.equipment[e.type]
		if t.storage == storage and not e.broken:
			n += t.capacity
	return n

func _stored(storage: String) -> int:
	var n := 0
	for bt in loc.stock:
		if content.ingredients[bt.ingredientId].storage == storage:
			n += bt.qty
	return n

func _effectivePriceIndex(ingredientId: String) -> float:
	var pi: float = loc.priceIndex.get(ingredientId, 1.0)
	var cat: String = content.ingredients[ingredientId].category
	if loc.categorySpikeUntil.get(cat, -1) >= state.dayIndex:
		pi *= b.d("PRICE_SPIKE_MULT")
	return pi

## Unit price with two decimals (doc 02 §9.2).
func _unitPrice(supplierId: String, ingredientId: String) -> float:
	var sup: Content.Supplier = content.suppliers[supplierId]
	var ing: Content.Ingredient = content.ingredients[ingredientId]
	var creep := pow(b.d("YEARLY_COST_CREEP_INGREDIENT"), state.dayIndex / 336)
	var mult: float = sup.priceMult - loc.supplierDeal.get(supplierId, 0.0)
	# A skilled manager negotiates (doc 02 §15.16); a bulk contract cuts every price.
	var m := loc.manager
	if m != null:
		mult *= 1 - 0.08 * _mastery(m.stockSkill)
	if state.bulkContractUntil > state.dayIndex:
		mult *= 1 - b.d("BULK_CONTRACT_DISCOUNT")
	if state.perks.has("perk_bulk3"):
		mult *= 0.97
	return roundi((ing.baseCost * creep * _effectivePriceIndex(ingredientId) * mult) * 100) / 100.0

func _supplierSells(supplierId: String, ingredientId: String) -> bool:
	var sup: Content.Supplier = content.suppliers[supplierId]
	var ing: Content.Ingredient = content.ingredients[ingredientId]
	if not sup.categories.has(ing.category):
		return false
	if loc.shortageIngredient == ingredientId and loc.shortageUntil >= state.dayIndex and supplierId != "sup_premium":
		return false
	return true

func _orderTotal(supplierId: String, lines: Dictionary) -> int:
	var t := 0.0
	for ing in lines:
		t += lines[ing] * _unitPrice(supplierId, ing)
	return roundi(t)

func _placeOrder(supplierId: String, lines: Dictionary, auto := false) -> CommandResult:
	if state.phase != "prep" and state.phase != "close":
		return CommandResult.fail(SimError.wrongPhase)
	var sup: Content.Supplier = content.suppliers.get(supplierId)
	if sup == null:
		return CommandResult.fail(SimError.unknownId)
	if loc.supplierBlockedUntil.get(supplierId, -1) >= state.dayIndex:
		return CommandResult.fail(SimError.locked, "%s will not deliver to you for now." % sup.name)
	var clean := {}
	for k in lines:
		if lines[k] > 0:
			clean[k] = int(lines[k])
	if clean.is_empty():
		return CommandResult.fail(SimError.invalidValue, "The order is empty.")
	for ing in clean:
		if not _supplierSells(supplierId, ing):
			var nm = content.ingredients[ing].name if content.ingredients.has(ing) else ing
			return CommandResult.fail(SimError.invalidValue, "%s cannot supply %s right now." % [sup.name, nm])
	if sup.leadDays == 0 and state.phase != "prep":
		return CommandResult.fail(SimError.wrongPhase, "Cash & Carry is a same-day trip: only during prep.")
	var total := _orderTotal(supplierId, clean)
	if total < sup.minOrder:
		return CommandResult.fail(SimError.belowMinimumOrder,
			"%s needs an order of at least %s (this one is %s)." % [sup.name, money(sup.minOrder), money(total)])
	var payNow := sup.leadDays == 0
	if payNow and state.cash < total:
		return CommandResult.fail(SimError.notEnoughCash, "Cash & Carry wants cash: you need %s." % money(total))
	var order := M.StockOrder.new()
	order.id = state.allocId()
	order.supplierId = supplierId
	order.lines = clean
	order.dueDay = state.dayIndex + (1 if state.phase == "close" else sup.leadDays)
	order.total = total
	order.placedDay = state.dayIndex
	if sup.leadDays == 0:
		_deliver(order, true)
	else:
		loc.orders.append(order)
	emit("orderPlaced", {"supplierId": supplierId, "total": total})
	return CommandResult.good(order.id)

## At prep: deliveries due today (doc 02 §9.3).
func _processDeliveries() -> void:
	var due: Array = loc.orders.filter(func(o): return o.dueDay <= state.dayIndex)
	for o in due:
		loc.orders.erase(o)
		var sup: Content.Supplier = content.suppliers[o.supplierId]
		if not o.late and _rng.chance(1 - sup.reliability):
			var r := _rng.next_float()
			if r < 0.5:
				o.late = true
				o.dueDay = state.dayIndex + 1
				loc.orders.append(o)
				_note("deliveryLate", "%s delivery is a day late" % sup.name, o.total)
				_raiseIncident("inc_delivery_late", null, o.supplierId, true, {"orderId": o.id})
				continue
			elif r < 0.8:
				var share := _rng.range_f(0.5, 0.8)
				for k in o.lines:
					o.lines[k] = floori(o.lines[k] * share)
				o.total = _orderTotal(o.supplierId, o.lines)
				_note("deliveryShort", "%s delivered only part of the order" % sup.name, 0)
				state.pendingNotices.append("%s delivered only about %d%% of your order. You were charged only for what came." % [sup.name, roundi(share * 100)])
				_deliver(o)
			else:
				_deliver(o, false, true)
			continue
		_deliver(o)

func _deliver(o: M.StockOrder, immediate := false, badBatch := false) -> void:
	var sup: Content.Supplier = content.suppliers[o.supplierId]
	for ing in o.lines:
		var q: int = o.lines[ing]
		if q <= 0:
			continue
		var shelf: int = content.ingredients[ing].shelfLifeDays
		var quality := clampi(sup.quality + _rng.next_int(-5, 5) - (30 if badBatch else 0), 5, 100)
		loc.stock.append(M.Batch.mk(ing, q, quality, shelf))
	# Payment: on delivery, or on credit if the relationship allows it.
	var cashOnly: bool = loc.supplierCashOnlyUntil.get(o.supplierId, -1) >= state.dayIndex
	if sup.creditDays > 0 and loc.supplierRel.get(o.supplierId, 50) >= 50 and not cashOnly:
		loc.payables.append(M.Payable.mk(state.allocId(), o.supplierId, o.total,
			state.dayIndex + sup.creditDays, "%s invoice" % sup.name, false))
		loc.today.ingredientSpend += o.total # booked as a cost when received
	else:
		spend(o.total, "ingredients")
		loc.supplierRel[o.supplierId] = mini(100, loc.supplierRel.get(o.supplierId, 50) + 1)
	if badBatch:
		_note("badBatch", "A bad batch arrived from %s" % sup.name, 0)
		_raiseIncident("inc_bad_batch", null, o.supplierId, true, {"orderId": o.id, "total": o.total})
	if not immediate:
		emit("deliveryArrived", {"supplierId": o.supplierId})

## Payables due today are paid; late ones hurt the relationship.
func _payPayables() -> void:
	var due: Array = loc.payables.filter(func(p): return p.dueDay <= state.dayIndex)
	for p in due:
		if state.cash >= p.amount:
			loc.payables.erase(p)
			state.cash -= p.amount # already booked as a cost at delivery
			emit("cashChanged", {"delta": -p.amount})
			if p.inherited:
				_note("inheritedDebt", "Paid the last owner's old supplier bill (%s)" % money(p.amount), p.amount)
			if p.supplierId != null:
				loc.supplierRel[p.supplierId] = mini(100, loc.supplierRel.get(p.supplierId, 50) + 1)
		elif p.dueDay < state.dayIndex - 6:
			# Very overdue: the supplier insists.
			if p.supplierId != null:
				loc.supplierRel[p.supplierId] = maxi(0, loc.supplierRel.get(p.supplierId, 50) - 10)
				_raiseIncident("inc_supplier_cash_only", null, p.supplierId, true)
			p.dueDay = state.dayIndex + 7

func _payPayable(id: int) -> CommandResult:
	var p = first_or_null(loc.payables, func(x): return x.id == id)
	if p == null:
		return CommandResult.fail(SimError.unknownId)
	if state.cash < p.amount:
		return CommandResult.fail(SimError.notEnoughCash, "You need %s." % money(p.amount))
	loc.payables.erase(p)
	state.cash -= p.amount
	if p.inherited:
		_note("inheritedDebt", "Paid off the old supplier bill early", p.amount)
	emit("cashChanged", {"delta": -p.amount})
	return CommandResult.good()

## Daily price drift (doc 02 §9.2).
func _updatePrices() -> void:
	var vol := diff("DIFF_VOLATILITY")
	for id in content.ingredients.keys():
		var pi: float = loc.priceIndex.get(id, 1.0)
		pi += (1 - pi) * 0.1 + (_rng.next_float() - 0.5) * 0.06 * vol
		loc.priceIndex[id] = clampf(pi, 0.6, 2.0)

## At close: use-by countdown, expiry → waste; storage over capacity spoils faster.
func _ageStock() -> void:
	var over := {}
	for st in ["dry", "chilled", "frozen"]:
		over[st] = _stored(st) > _capacity(st)
	var fridgeDown := not any(loc.equipment, func(e): return e.type == "eq_fridge" and not e.broken)
	var waste := 0.0
	var wasted := {}
	for bt in loc.stock:
		var storage: String = content.ingredients[bt.ingredientId].storage
		var dec := 1
		if over[storage]:
			dec += 2 if (storage != "dry" and (fridgeDown or _capacity(storage) == 0)) else 1
		bt.daysLeft -= dec
		if bt.daysLeft <= 0:
			var c: float = bt.qty * content.ingredients[bt.ingredientId].baseCost * loc.priceIndex.get(bt.ingredientId, 1.0)
			waste += c
			wasted[bt.ingredientId] = wasted.get(bt.ingredientId, 0) + bt.qty
			emit("batchExpired", {"ingredientId": bt.ingredientId, "qty": bt.qty})
	remove_where(loc.stock, func(x): return x.daysLeft <= 0)
	loc.today.wasteCost = roundi(waste)
	if waste >= 1:
		var names: Array = []
		for k in wasted:
			names.append([k, wasted[k]])
		dsort(names, func(a, c): return cmpn(c[1], a[1]))
		var parts: Array = []
		for e in names.slice(0, 3):
			parts.append("%s ×%d" % [content.ingredients[e[0]].name, e[1]])
		_note("waste", "Threw away food worth %s (%s)" % [money(waste), ", ".join(parts)], roundi(waste))

## Par-level auto-order at close (doc 02 §9.4, stage 2).
func _autoOrder() -> void:
	if loc.parLevels.is_empty():
		return
	var bySup := {}
	for ing in loc.parLevels:
		var par: M.ParLevel = loc.parLevels[ing]
		var onOrder := 0
		for o in loc.orders:
			onOrder += o.lines.get(ing, 0)
		var qty := par.par - loc.stockOf(ing) - onOrder
		if qty <= 0:
			continue
		var sup := par.supplierId
		if not _supplierSells(sup, ing) or content.suppliers[sup].leadDays == 0:
			sup = "sup_standard"
		if not bySup.has(sup):
			bySup[sup] = {}
		bySup[sup][ing] = qty
	for sup in bySup:
		var lines: Dictionary = bySup[sup]
		var total := _orderTotal(sup, lines)
		if total >= content.suppliers[sup].minOrder:
			var r := _placeOrder(sup, lines, true)
			if r.ok:
				_note("autoOrder", "Auto-ordered stock from %s (%s)" % [content.suppliers[sup].name, money(total)], 0)

## Suggested order for one supplier: tomorrow's use + a day's buffer, minus stock and orders.
func _suggestedOrder(supplierId: String, days := 2.0) -> Dictionary:
	var use := _expectedDailyUse(loc, state.dayIndex + 1)
	var out := {}
	for ing in use:
		var perDay: float = use[ing]
		if not _supplierSells(supplierId, ing):
			continue
		var onOrder := 0
		for o in loc.orders:
			onOrder += o.lines.get(ing, 0)
		var shelf: int = content.ingredients[ing].shelfLifeDays
		var want := ceili(perDay * minf(days, float(shelf)))
		var q := want - loc.stockOf(ing) - onOrder
		if q > 0:
			out[ing] = q
	return out

# ================================================================ staff.dart
# Staff: rota, absence, happiness, fatigue, quitting, hiring, training (doc 02 §7).

func _rosteredToday(s: M.Staff) -> bool:
	if s.trainingUntil > state.dayIndex: return false
	if s.workDayOffDay == state.dayIndex: return true
	return s.dayOff != state.weekday

func _outletHappiness() -> float:
	if loc.staff.is_empty():
		return 50.0
	var a := 0.0
	for s in loc.staff:
		a += s.morale
	return a / loc.staff.size()

## Rolls absence and lateness at prep (doc 02 §7.4).
func _rollAttendance() -> void:
	for s in loc.staff:
		s.workingToday = false
		s.absentToday = false
		s.lateTick = 0
		s.rushToday = false
		s.tipsToday = 0
		if not _rosteredToday(s):
			continue
		if s.absentUntil > state.dayIndex:
			s.absentToday = true
			continue
		var p: float = (100 - s.reliability) / b.d("ABSENCE_DIVISOR")
		if s.fatigue > 80: p += 0.05
		if s.morale < 30: p += 0.05
		if lf("festival_refused") and _festivalOn(state.dayIndex) != null:
			p *= 2
		if lf("festival_absence") and _festivalOn(state.dayIndex) != null:
			p += state.flags.get("%d:festival_absence_pct" % loc.id, 0) / 100.0
		# Everyone turns up for opening night (the roll still happens, so the
		# random stream is the same as any other day).
		if _rng.chance(p) and state.dayIndex > 0:
			s.absentToday = true
			state.pendingNotices.append("%s (%s) is absent today." % [s.name, roleName(s.role)])
			_note("absent", "%s (%s) did not come in" % [s.name, roleName(s.role)], 1)
			emit("staffAbsent", {"staffId": s.id})
			continue
		s.workingToday = true
		var pLate: float = (100 - s.reliability) / 300.0
		if s.hasTrait("trait_often_late"): pLate *= 2
		if _rng.chance(pLate) and state.dayIndex > 0:
			s.lateTick = _rng.next_int(15, 60)
			_note("late", "%s arrived late (%s)" % [s.name, _clock(s.lateTick)], 0)

## Every happiness factor for one person (doc 02 §7.3). The same function sets the target.
func _happinessFactors(s: M.Staff) -> Dictionary:
	var f := {}
	var exp: float = _expectedWage(s.role, s.skill) * pow(b.d("YEARLY_COST_CREEP_WAGE"), state.dayIndex / 336)
	f["Pay"] = clampf((s.wage - exp) / exp * 100, -20, 10)
	if s.fatigue > 50:
		f["Tiredness"] = maxf(-15, -0.3 * (s.fatigue - 50))
	elif s.fatigue < 30:
		f["Tiredness"] = 3.0
	var rest := 0.0
	if s.dayOff == s.preferredDayOff: rest += 3
	if s.workedDayOffWeek == state.weekIndex: rest -= 5
	f["Rest"] = rest
	if not s.recentRush.is_empty():
		f["Short-staffed shifts"] = -10.0 * count(s.recentRush, func(x): return x == 1) / s.recentRush.size()
	var team := 0.0
	if any(loc.staff, func(o): return o.id != s.id and o.role == s.role and o.hasTrait("trait_mentor")):
		team += 3
	if any(loc.staff, func(o): return o.id != s.id and o.hasTrait("trait_toxic")):
		team -= 5
	f["Team"] = team
	var mgr := loc.manager
	if mgr != null and mgr != s and state.ownerLocationId != loc.id:
		f["Boss"] = clampf((mgr.people - 50) / 5, -10, 10)
	else:
		f["Boss"] = 0.0 if state.owner.restDaysThisWeek >= 7 else 3.0
	var growth := 0.0
	var since := state.dayIndex - s.lastGrowthDay
	if since < 28: growth += 5
	var limit := 56 if s.hasTrait("trait_ambitious") else 112
	if s.skill > 60 and since > limit and state.dayIndex - s.hiredDay > limit:
		growth -= 10 if s.hasTrait("trait_ambitious") else 5
	f["Growth"] = growth
	var cond := 0.0
	if not _hasWorking("eq_ac") and loc.tierId != "bad" and loc.tierId != "worst":
		cond -= 8 if state.season == "summer" else 4
	elif not _hasWorking("eq_ac") and state.season == "summer":
		cond -= 4
	if s.isKitchen and not _hasWorking("eq_hood"): cond -= 4
	if s.isCook and any(loc.equipment, func(e): return content.equipment[e.type].kind == "station" and e.condition < 40 and not e.broken):
		cond -= 3
	if loc.hygiene < 50: cond -= 3
	f["Working conditions"] = cond
	var rec := 0.0
	if not s.recentTips.is_empty():
		var tot := 0
		for x in s.recentTips: tot += x
		rec += minf(5, float(tot) / s.recentTips.size() / 20)
	f["Recognition"] = rec
	if s.hasTrait("trait_loyal"): f["Personal"] = 3.0
	for m in s.moodMods:
		if m.untilDay >= state.dayIndex:
			f[m.key] = f.get(m.key, 0.0) + m.score
	for k in f.keys():
		if f[k] == 0:
			f.erase(k)
	return f

func _happinessTarget(s: M.Staff) -> float:
	var a := 0.0
	var f := _happinessFactors(s)
	for k in f:
		a += f[k]
	return clampf(50 + a, 0, 100)

func _staffClose() -> void:
	var today := loc.today
	# Tips split among those who worked.
	var worked: Array = loc.staff.filter(func(s): return s.workingToday)
	if not worked.is_empty() and today.tips > 0:
		var each := today.tips / worked.size()
		for s in worked:
			s.tipsToday = each
	var rush: Dictionary = loc.service.rushRoles if loc.service != null else {}
	var metTarget: bool = loc.service != null and loc.service.lost <= loc.service.target
	for s in loc.staff.duplicate():
		# Wages accrue for days worked; paid on Sunday.
		if s.workingToday:
			var overtime: bool = s.dayOff == state.weekday and s.workDayOffDay == state.dayIndex
			var festivalPay := 2 if (lf("festival_double_pay") and _festivalOn(state.dayIndex) != null) else 1
			var pay := roundi(s.wage * (b.d("OVERTIME_MULT") if overtime else 1.0) * festivalPay)
			loc.today.wages += pay
			state.wagesOwed += pay # paid in cash on Sunday
			s.daysWorked += 1
			s.consecutiveDays += 1
			var wasRush := rush.has(s.role)
			var gain := b.d("FATIGUE_WORK") + (b.d("FATIGUE_RUSH") if wasRush else 0.0)
			if not s.isManager:
				s.fatigue += gain * (0.7 if s.hasTrait("trait_hard_worker") else 1.0) - b.d("FATIGUE_OVERNIGHT")
			s.recentRush.append(1 if wasRush else 0)
			if s.recentRush.size() > 7: s.recentRush.remove_at(0)
			s.recentTips.append(s.tipsToday)
			if s.recentTips.size() > 7: s.recentTips.remove_at(0)
			if metTarget: s.morale += b.d("TARGET_MET_MORALE")
			if s.daysWorked == 7:
				state.pendingNotices.append("You now know %s's true skill (%d) and reliability." % [s.name, roundi(s.skill)])
		elif not _rosteredToday(s) or s.trainingUntil > state.dayIndex:
			s.fatigue -= b.d("FATIGUE_REST") + b.d("FATIGUE_OVERNIGHT")
			s.consecutiveDays = 0
		else:
			s.fatigue -= b.d("FATIGUE_REST") + b.d("FATIGUE_OVERNIGHT") # absent: they rested
		s.fatigue = clampf(s.fatigue, 0, 100)
		var target := _happinessTarget(s)
		s.morale += (target - s.morale) * b.d("HAPPINESS_SPEED")
		s.morale = clampf(s.morale, 0, 100)
		remove_where(s.moodMods, func(m): return m.untilDay < state.dayIndex)
		if s.hasTrait("trait_light_fingered"):
			s.honesty = minf(s.honesty, 30)
		# Training finished.
		if s.trainingUntil == state.dayIndex + 1:
			state.pendingNotices.append("%s is back from training." % s.name)
		# Notice period.
		if s.status == "notice":
			s.noticeLeft -= 1
			if s.noticeLeft <= 0:
				_removeStaff(s, "%s worked their last day and left" % s.name)
				continue
		# Quitting (doc 02 §7.5).
		if s.status == "active":
			var quitMult := 0.5 if s.hasTrait("trait_loyal") else 1.0
			var pQuit: float = maxf(0, 30 - s.morale) / 300 * (1 - s.loyalty / 200) * quitMult \
				* (1 - 0.5 * (0.0 if loc.manager == null else _mastery(loc.manager.people)))
			if pQuit > 0 and _rng.chance(pQuit):
				var pNo: float = diff("NO_NOTICE_BASE") + (40 - s.morale) / 100 + (50 - s.loyalty) / 200
				if s.deniedUntil >= state.dayIndex: pNo += 0.10
				pNo = clampf(pNo, 0.02, 0.90)
				if _rng.chance(pNo):
					var hf := _happinessFactors(s)
					var neg: Array = []
					for k in hf:
						if hf[k] < 0: neg.append([k, hf[k]])
					dsort(neg, func(a, c): return cmpn(a[1], c[1]))
					var rs: Array = []
					for e in neg.slice(0, 3): rs.append(e[0].to_lower())
					var reasons := ", ".join(rs)
					state.pendingNotices.append("%s did not come in and is not answering. They have quit without notice. (Unhappy about: %s.)" % [s.name, "many things" if reasons.is_empty() else reasons])
					_removeStaff(s, "%s (%s) quit without notice" % [s.name, roleName(s.role)])
					emit("staffWalkedOut", {"name": s.name})
				else:
					_raiseIncident("inc_resignation", s.id, null, true)

func _removeStaff(s: M.Staff, why: String) -> void:
	loc.staff.erase(s)
	_note("staffLeft", why, 1)
	_timeline(why)

const ROLE_NAMES := {"headChef": "Head chef", "lineCook": "Line cook", "prepCook": "Prep cook",
	"dishwasher": "Dishwasher", "server": "Server", "cashier": "Cashier", "cleaner": "Cleaner", "manager": "Manager"}

func roleName(role: String) -> String:
	return ROLE_NAMES.get(role, role)

# ------------------------------------------------------------ commands

func _hire(applicantId: int) -> CommandResult:
	var a = first_or_null(state.applicants, func(x): return x.id == applicantId)
	if a == null:
		return CommandResult.fail(SimError.unknownId, "That applicant has gone.")
	if loc.staff.size() >= b.i("MAX_STAFF"):
		return CommandResult.fail(SimError.limitReached, "The kitchen and floor cannot fit more people.")
	state.applicants.erase(a)
	a.hiredDay = state.dayIndex
	a.wage = a.askingWage
	a.morale = 60
	# Day off: the weekday with the fewest people off, Mon–Thu first.
	var offCount := [0, 0, 0, 0, 0, 0, 0]
	for s in loc.staff:
		if s.dayOff < 7: offCount[s.dayOff] += 1
	var best := 0
	for d in 7:
		var sameRole := any(loc.staff, func(s): return s.role == a.role and s.dayOff == d)
		var score: int = offCount[d] + (10 if sameRole else 0) + (5 if d >= 4 else 0)
		var bestScore: int = offCount[best] + (10 if any(loc.staff, func(s): return s.role == a.role and s.dayOff == best) else 0) + (5 if best >= 4 else 0)
		if score < bestScore: best = d
	a.dayOff = best
	loc.staff.append(a)
	_timeline("Hired %s as %s" % [a.name, roleName(a.role).to_lower()])
	emit("staffHired", {"staffId": a.id})
	return CommandResult.good()

func _fire(staffId: int) -> CommandResult:
	var s := loc.staffById(staffId)
	if s == null: return CommandResult.fail(SimError.unknownId)
	var severance := s.wage * b.i("SEVERANCE_DAYS")
	spend(severance, "wages")
	var toxic := s.hasTrait("trait_toxic")
	loc.staff.erase(s)
	for o in loc.staff:
		o.moodMods.append(M.MoodMod.mk("Team", 5.0 if toxic else -5.0, state.dayIndex + 14))
	_note("fired", "Fired %s (severance %s)" % [s.name, money(severance)], severance)
	_timeline("Fired %s" % s.name)
	return CommandResult.good()

func _setWage(staffId: int, wage: int) -> CommandResult:
	var s := loc.staffById(staffId)
	if s == null: return CommandResult.fail(SimError.unknownId)
	if wage <= 0 or wage > 2000:
		return CommandResult.fail(SimError.invalidValue)
	if wage > s.wage:
		s.lastGrowthDay = state.dayIndex
		s.moodMods.append(M.MoodMod.mk("Recognition", 3, state.dayIndex + 14))
	elif wage < s.wage:
		s.morale = maxf(0, s.morale - 15)
		s.deniedUntil = state.dayIndex + 14
	s.wage = wage
	return CommandResult.good()

func _train(staffId: int) -> CommandResult:
	var s := loc.staffById(staffId)
	if s == null: return CommandResult.fail(SimError.unknownId)
	if s.trainingUntil > state.dayIndex:
		return CommandResult.fail(SimError.limitReached, "Already training.")
	if s.skill >= 95:
		return CommandResult.fail(SimError.limitReached, "%s is as good as training can make them." % s.name)
	var cost := roundi(b.d("TRAIN_COST_PER_SKILL") * s.skill)
	if state.cash < cost:
		return CommandResult.fail(SimError.notEnoughCash, "Training costs %s." % money(cost))
	spend(cost, "other")
	var start := state.dayIndex + 1 if state.phase == "close" else state.dayIndex
	s.trainingUntil = start + b.i("TRAIN_DAYS")
	var gain := float(_rng.next_int(5, 10))
	if s.hasTrait("trait_fast_learner"): gain *= 1.5
	s.skill = round(minf(95, s.skill + gain))
	s.morale = minf(100, s.morale + 5)
	s.lastGrowthDay = state.dayIndex
	s.trainedByOwner = true
	if state.phase == "prep": s.workingToday = false
	_note("training", "Sent %s on a course (%s)" % [s.name, money(cost)], cost)
	return CommandResult.good(roundi(gain))

func _setDayOff(staffId: int, weekday: int) -> CommandResult:
	var s := loc.staffById(staffId)
	if s == null: return CommandResult.fail(SimError.unknownId)
	if weekday < 0 or weekday > 6:
		return CommandResult.fail(SimError.invalidValue)
	s.dayOff = weekday
	return CommandResult.good()

func _workDayOff(staffId: int) -> CommandResult:
	var s := loc.staffById(staffId)
	if s == null: return CommandResult.fail(SimError.unknownId)
	var day := state.dayIndex + 1 if state.phase == "close" else state.dayIndex
	if s.dayOff != day % 7:
		return CommandResult.fail(SimError.invalidValue, "That is not %s's day off." % s.name)
	if s.fatigue > 70 or s.morale < 35:
		return CommandResult.fail(SimError.refused, "%s says no: too tired or too unhappy." % s.name)
	if s.lastWorkDayOffWeek >= day / 7 - 1:
		return CommandResult.fail(SimError.refused, "Nobody can be asked two weeks running.")
	s.workDayOffDay = day
	s.lastWorkDayOffWeek = day / 7
	s.workedDayOffWeek = day / 7
	if state.phase == "prep" and s.absentUntil <= state.dayIndex:
		s.workingToday = true
	return CommandResult.good()

func _giveDayOff(staffId: int) -> CommandResult:
	var s := loc.staffById(staffId)
	if s == null: return CommandResult.fail(SimError.unknownId)
	if state.phase != "prep":
		return CommandResult.fail(SimError.wrongPhase, "Give a day off during prep.")
	if not s.workingToday:
		return CommandResult.fail(SimError.invalidValue, "%s is not working today anyway." % s.name)
	s.workingToday = false
	s.fatigue = maxf(0, s.fatigue - 30)
	s.moodMods.append(M.MoodMod.mk("Rest", 3, state.dayIndex + 7))
	return CommandResult.good()

func _warn(staffId: int) -> CommandResult:
	var s := loc.staffById(staffId)
	if s == null: return CommandResult.fail(SimError.unknownId)
	s.warnings += 1
	s.morale = maxf(0, s.morale - 8)
	s.reliability = minf(100, s.reliability + 5)
	return CommandResult.good()

func _promote(staffId: int) -> CommandResult:
	var s := loc.staffById(staffId)
	if s == null: return CommandResult.fail(SimError.unknownId)
	if s.role != "lineCook":
		return CommandResult.fail(SimError.invalidValue, "Only a line cook can be promoted to head chef (managers come with more outlets).")
	if any(loc.staff, func(o): return o.role == "headChef"):
		return CommandResult.fail(SimError.limitReached, "You already have a head chef.")
	s.role = "headChef"
	s.wage = maxi(s.wage, _expectedWage("headChef", s.skill))
	s.lastGrowthDay = state.dayIndex
	s.morale = minf(100, s.morale + 10)
	if s.trainedByOwner and not state.objectivesDone.has("obj_2_train_chef"):
		state.flags["promoted_trained_chef"] = 1 << 30
	_timeline("Promoted %s to head chef" % s.name)
	return CommandResult.good()

# ================================================================ day.dart
# Day orchestration: prep (beginDay) and close (endDay) in the exact order of doc 02 §3.

func _beginDay() -> void:
	state.phase = "prep"
	state.travelTo = -1
	if state.weekday == 0:
		state.owner.restDaysThisWeek = 0
	# Yearly cost creep notice (doc 11 §A.4).
	if state.dayIndex > 0 and state.dayIndex % 336 == 0:
		state.pendingNotices.append("A new year: wages people expect and ingredient prices have gone up about 3%. Customers will accept prices about 3% higher too.")
	# Owner rest.
	state.owner.restingToday = state.owner.forcedRestDay == state.dayIndex
	if state.owner.restingToday:
		state.pendingNotices.append("You are exhausted and must rest today. The team runs the shift without you.")
	for k in state.flags.keys():
		if state.flags[k] < state.dayIndex:
			state.flags.erase(k)
	_chainMorning()
	for l in state.openLocations:
		at(l, _beginLocationDay)
	emit("dayStarted", {"day": state.dayIndex})

func _beginLocationDay() -> void:
	var l := loc
	l.today = M.DayStats.mk(state.dayIndex)
	l.service = null
	l.ownerTicksToday = 0
	if state.weekday == 0:
		l.ownerDaysThisWeek = 0
	if l.openDay == state.dayIndex and state.dayIndex > 0:
		state.pendingNotices.append("%s opens its doors today." % l.name)
		_story("Opened for business")
	for m in l.menu.values():
		m.soldYesterday = m.soldToday
		m.soldToday = 0
		m.unavailableToday = 0
	remove_where(l.demandMods, func(m): return m.untilDay < state.dayIndex)
	# Campaign outcomes are revealed the next morning (doc 02 §13.1).
	for c in l.campaigns:
		if not c.revealed and c.startDay < state.dayIndex and c.type != "blogger":
			c.revealed = true
			state.pendingNotices.append(c.reason)
	# 2. Deliveries and bills due.
	_processDeliveries()
	_payPayables()
	# 3. Absences.
	_rollAttendance()
	# 4. Prices.
	_updatePrices()
	# Scheduled state changes from hidden problems.
	for sc in state.scheduled.duplicate():
		if sc.day > state.dayIndex or sc.locationId != l.id:
			continue
		if sc.incidentId == "@flag:pests":
			state.scheduled.erase(sc)
			state.flags["%d:pests" % loc.id] = 1 << 30
		elif sc.incidentId == "@fake_reviews":
			state.scheduled.erase(sc)
			l.reputation = maxf(0, l.reputation - 0.5)
			state.pendingNotices.append("A review site removed dozens of fake 5-star reviews the last owner had bought. Your rating fell by 0.5.")
			_note("fakeReviews", "Fake reviews removed: rating −0.5", 50)
			_timeline("Fake reviews removed: rating −0.5")
			_markHidden("fake_reviews")
	if _rng.chance(b.d("GAS_LOW_CHANCE")):
		state.flags["%d:gas_low" % loc.id] = state.dayIndex
	# 5. Overnight incidents: forced/scheduled first, then up to two rolls.
	_incidentsAtPrep()
	if lf("ill_guest"):
		state.flags.erase("%d:ill_guest" % loc.id)
		_raiseIncident("inc_food_poisoning", null, null, true)
	# A manager runs prep wherever the owner is not (doc 02 §15.2).
	if state.ownerLocationId != l.id and l.manager != null and l.openDay <= state.dayIndex:
		_managerPrep()
	# 6. Forecast.
	loc.today.forecast = _forecast().groups

# ---------------------------------------------------------- close

## Close every outlet, then the company's daily, weekly and monthly business.
func _closeAll() -> void:
	for l in state.openLocations:
		at(l, _closeDay)
	_ownerClose()
	_chainEvening()
	if state.weekday == 6:
		_weekly()
	if state.dayOfMonth == 28:
		_monthly()
	for l in state.openLocations:
		at(l, _checkObjectives)
	_bankruptcyCheck()
	state.cashHistory.append(state.cash)
	if state.cashHistory.size() > 56:
		state.cashHistory.remove_at(0)
	emit("dayClosed", {})

func _closeDay() -> void:
	var l := loc
	var t := loc.today
	var closedToday := l.closedUntil > state.dayIndex
	# Fixed costs accrue every day (paid in cash weekly / monthly).
	var d := state.weekday
	t.rent = roundi(l.rentWeekly * (d + 1) / 7.0) - roundi(l.rentWeekly * d / 7.0)
	var working := count(l.equipment, _isWorking)
	var util := b.d("UTILITIES_BASE") + b.d("UTILITIES_PER_GROUP") * t.groupsServed + b.d("UTILITIES_PER_UNIT") * working
	t.utilities = roundi(util)
	state.monthUtilities += t.utilities
	# Skimming by a dishonest cashier nobody caught.
	var skimmer = first_or_null(l.staff, func(s): return s.workingToday and s.role == "cashier" and s.honesty < 40)
	if skimmer != null and t.revenue > 0:
		var lost := roundi(t.revenue * b.d("SKIM_PCT"))
		state.cash -= lost
		t.other += lost
		_note("skim", "Cash in the till was %s short of sales" % money(lost), lost)
	_ageStock()
	_equipmentClose()
	_hygieneClose(closedToday)
	_staffClose()
	_reputationClose()
	_lifecycleClose()
	_rollIncidents("close")
	_autoOrder()
	_managerClose()

func _maxCondition(e: M.Equipment) -> float:
	return maxf(b.d("MAX_CONDITION_FLOOR"), b.d("MAX_CONDITION_START") - 5 * (e.ageDays / 168))

func _breakChance(e: M.Equipment) -> float:
	var p := b.d("BREAK_BASE") + maxf(0, 60 - e.condition) / b.d("BREAK_COND_DIVISOR")
	if e.fragileUntil >= state.dayIndex:
		p += b.d("CHEAP_REPAIR_FAIL_PER_DAY")
	return p

func _equipmentClose() -> void:
	var l := loc
	var busy: bool = loc.today.groupsArrived > 1.2 * maxi(1, loc.today.forecast)
	for e in l.equipment:
		e.ageDays += 1
		if e.broken:
			continue
		var t: Content.EquipmentType = content.equipment[e.type]
		var wokHei := 2 if (e.type == "eq_wok" and lf("wok_hei")) else 1
		e.condition = maxf(0, e.condition - t.wearPerDay * (1.5 if busy else 1.0) * wokHei)
		if _rng.chance(_breakChance(e)):
			e.broken = true
			_note("breakdown", "%s broke down" % t.name, t.price / 10)
			_timeline("%s broke down" % t.name)
			emit("equipmentBroke", {"equipmentId": e.id})
			state.scheduled.append(M.Scheduled.mk("inc_breakdown", state.dayIndex + 1, e.id, null, loc.id))

func _hygieneClose(closed: bool) -> void:
	var l := loc
	var h := l.hygiene
	h -= loc.today.groupsServed * b.d("HYGIENE_PER_GROUP")
	var cleaners: Array = l.staff.filter(func(s): return s.workingToday and s.role == "cleaner")
	var sum := 0.0
	for c in cleaners:
		sum += 0.5 + c.skill / 100
	if cleaners.is_empty():
		# Stand-in: the dishwasher cleans at half effect.
		for w in l.staff.filter(func(s): return s.workingToday and s.role == "dishwasher"):
			sum += 0.5 * (0.5 + (w.skill - 15) / 100)
	h += b.d("HYGIENE_CLEAN_PCT") * (100 - h) * sum
	if not closed and not any(l.staff, func(s): return s.workingToday and s.role == "dishwasher"):
		h -= 5
	if not _hasWorking("eq_hood"): h -= 5
	if lf("pests"): h -= 8
	if lf("leak"): h -= 10
	l.hygiene = clampf(h, 0, 100)

func _ownerClose() -> void:
	var o := state.owner
	if o.restingToday:
		o.energy = 100
		o.zeroEnergyDays = 0
		o.restDaysThisWeek += 1
		return
	if o.energy <= 0.5:
		o.zeroEnergyDays += 1
	else:
		o.zeroEnergyDays = 0
	if o.zeroEnergyDays >= 3:
		o.forcedRestDay = state.dayIndex + 1
		o.zeroEnergyDays = 0
		_note("ownerExhausted", "You worked yourself to exhaustion: tomorrow is a forced rest day", 0)
	o.energy = minf(100, o.energy + b.d("OWNER_RECOVERY"))

func _reputationClose() -> void:
	var l := loc
	var t := loc.today
	if t.starsN <= 0:
		return
	var avg := t.starsSum / t.starsN
	var weight := minf(1.0, t.starsN / 20)
	var k := b.d("REP_UP") if avg > l.reputation else b.d("REP_DOWN")
	l.reputation = clampf(l.reputation + (avg - l.reputation) * k * weight, 0, 5)

func _lifecycleClose() -> void:
	var l := loc
	# Buzz decay, keeping each campaign's share in proportion.
	var b0 := l.buzz
	l.buzz = maxf(0, l.buzz - b.d("BUZZ_DECAY"))
	for c in l.campaigns:
		c.buzzLeft = 0.0 if b0 <= 0 else c.buzzLeft * l.buzz / b0
	l.freshness = maxf(0, l.freshness - b.d("FRESHNESS_DECAY"))
	var aw := b.d("AWARENESS_GAIN") * (0.5 + l.buzz) * minf(1.5, l.reputation / 3.5)
	l.awareness = minf(1, l.awareness + aw)
	_campaignAccounting()

# ---------------------------------------------------------- objectives and stages

func _markHidden(kind: String) -> void:
	for hp in loc.hidden:
		if hp.kind == kind:
			hp.done = true

func _updateHiddenProblems() -> void:
	var l := loc
	for hp in l.hidden:
		if hp.done:
			continue
		match hp.kind:
			"supplier_debt":
				if not any(l.payables, func(p): return p.inherited): hp.done = true
			"chef_leaving":
				var chef = first_or_null(l.staff, func(s): return s.role == "headChef")
				if chef == null or chef.morale >= 60 or state.dayIndex > hp.dueDay + 7:
					hp.done = true
			"pests":
				if state.dayIndex > hp.dueDay and not lf("pests"): hp.done = true
			"fridge_failing":
				if every(l.equipment.filter(func(e): return e.type == "eq_fridge"), func(e): return e.condition >= 50 and not e.broken):
					hp.done = true
			"cashier_skimming":
				if not any(l.staff, func(s): return s.role == "cashier" and s.honesty < 40): hp.done = true
			"staff_feud":
				if not lf("feud"): hp.done = true

func _completeObjective(id: String) -> void:
	if state.objectivesDone.has(id):
		return
	var obj = first_or_null(content.objectives, func(o): return o.id == id)
	if obj == null or obj.stage > state.stage:
		return
	state.objectivesDone[id] = true
	for r in obj.reward:
		match r["type"]:
			"cash": earn(int(r["amount"]), "none")
			"reputation": loc.reputation = minf(5, loc.reputation + float(r["delta"]))
			"loyalty":
				for s in loc.staff:
					s.loyalty = minf(100, s.loyalty + float(r["delta"]))
			"flag": state.flags[r["key"]] = 1 << 30
			"flagPerk": state.perks[r["key"]] = true
			"credit": state.creditScore = minf(100, state.creditScore + float(r["delta"]))
	state.pendingNotices.append("Goal complete: %s. Reward: %s." % [obj.text, obj.rewardText])
	_timeline("Goal complete: %s" % obj.text)
	emit("objectiveDone", {"id": id})

func _checkObjectives() -> void:
	var l := loc
	var t := loc.today
	_updateHiddenProblems()
	if t.profit > 0 and not t.closed:
		_completeObjective("obj_1_first_profit")
	var s = l.service
	if s != null and not state.owner.restingToday:
		var covered := func(rs: Array) -> bool:
			return any(l.staff, func(x): return x.workingToday and rs.has(x.role))
		var allCovered: bool = covered.call(["headChef", "lineCook"]) and covered.call(["server"]) and covered.call(["cashier"]) \
			and covered.call(["dishwasher"]) and covered.call(["cleaner"])
		var served = (1 - t.ownerTasks * 2.0 / s.tick) if s.tick > 0 else 0.0
		if allCovered and served >= 0.5 and t.groupsServed > 0:
			_completeObjective("obj_1_full_rota")
	if not l.hidden.is_empty() and every(l.hidden, func(h): return h.done) and state.dayIndex > 0:
		_completeObjective("obj_1_clear_problems")
	if l.reputation >= 4.0:
		_completeObjective("obj_2_four_star")
	if state.flag("promoted_trained_chef"):
		_completeObjective("obj_2_train_chef")
	# Stage 3–5 goals.
	if state.stage >= 3 and l.id != state.locations[0].id and l.weeks.size() >= 4 \
			and every(l.weeks.slice(l.weeks.size() - 4), func(w): return w.operatingProfit > 0):
		_completeObjective("obj_3_second_profit")
	if state.stage >= 3 and state.weekday == 6 and state.openLocations.size() > 1 \
			and every(state.openLocations, func(x): return every(x.days.filter(func(dd): return dd.dayIndex > state.dayIndex - 7), func(dd): return dd.ownerTasks == 0) and x.today.ownerTasks == 0):
		_completeObjective("obj_3_hands_off")
	if state.stage >= 4 and _companyRating() >= 4.5:
		_completeObjective("obj_4_brand_45")
	if state.stage >= 5:
		var second := count(state.openLocations, func(x): return x.themeId != state.themeId)
		if second >= 3:
			_completeObjective("obj_5_second_brand")

func _checkStage() -> void:
	var hq: M.Location = state.openLocations[0]
	if state.stage == 1 and state.profitableWeeksInRow >= b.i("STAGE2_PROFIT_WEEKS") and hq.reputation >= b.d("STAGE2_REP"):
		_stageUp(2, "Reached Stage 2: Stable")
	elif state.stage == 2 and state.cash >= b.i("STAGE3_CASH") and _companyRating() >= b.d("STAGE3_REP") and state.dayIndex - state.lastMissDay > 56:
		_stageUp(3, "Stage 3: ready to open a second location")
	elif state.stage == 3:
		# Stage 4 (Chain): 3 outlets, each profitable 4 weeks running (doc 01 §3.3).
		var n := b.i("STAGE4_PROFIT_WEEKS")
		var good := count(state.openLocations, func(l): return l.weeks.size() >= n and every(l.weeks.slice(l.weeks.size() - n), func(w): return w.operatingProfit > 0))
		if good >= b.i("STAGE4_OUTLETS"):
			_stageUp(4, "Stage 4: a chain")
	elif state.stage == 4 and _valuation() >= b.i("STAGE5_VALUATION"):
		_stageUp(5, "Stage 5: a restaurant group")

func _stageUp(n: int, text: String) -> void:
	state.stage = n
	state.pendingNotices.append("@stage%d" % n)
	_timeline(text)
	emit("stageReached", {"stage": n})

# ================================================================ finance.dart
# Finance (doc 02 §14), marketing (§13) and the menu rework (doc 11 §A.2).

const campaignNames := {"flyers": "Flyers", "localAd": "Local ad", "promoDay": "Promotion day", "blogger": "Food blogger"}
const campaignAudience := {"flyers": ["family", "student"], "localAd": ["office", "family"], "promoDay": ["student", "family"]}
const segmentNames := {"office": "office workers", "family": "families", "student": "students", "tourist": "tourists"}

# ---------------------------------------------------------- weekly and monthly

func _weekRecordFor(l: M.Location) -> M.WeekRecord:
	var days: Array = l.days.filter(func(d): return d.dayIndex > state.dayIndex - 7)
	days.append(l.today)
	var w := M.WeekRecord.new()
	w.week = state.weekIndex
	var starsSum := 0.0
	var starsN := 0.0
	for d in days:
		w.revenue += d.revenue
		w.costs += d.costs
		w.interest += d.interest
		w.wasteCost += d.wasteCost
		w.groupsServed += d.groupsServed
		w.walkouts += d.walkouts
		w.ingredientSpend += d.ingredientSpend
		w.wages += d.wages
		w.rent += d.rent
		w.marketing += d.marketing
		w.upkeep += d.upkeep
		w.other += d.other
		w.utilities += d.utilities
		starsSum += d.starsSum
		starsN += d.starsN
	w.operatingProfit = w.revenue - w.costs
	w.avgStars = 0.0 if starsN == 0 else starsSum / starsN
	return w

func _weekly() -> void:
	var hq: M.Location = state.openLocations[0]
	# 1. Wages (accrued daily at each outlet).
	state.cash -= state.wagesOwed
	emit("cashChanged", {"delta": -state.wagesOwed})
	state.wagesOwed = 0
	# 2. Rent at every outlet, open or still being fitted out.
	for l in state.openLocations:
		state.cash -= l.rentWeekly
	# 3. Loan instalments (interest is booked against the first restaurant).
	var missedThisWeek := false
	var anyDue := false
	for loan in state.loans.duplicate():
		if loan.startDay > state.dayIndex - 1:
			continue # first instalment next Sunday
		var pay: int = loan.instalment
		var interest: int = loan.interestDue
		if pay <= 0:
			continue
		anyDue = true
		if state.cash >= pay:
			state.cash -= pay
			hq.today.interest += interest
			loan.outstanding -= pay - interest
			loan.missedInRow = 0
			state.creditScore = minf(100, state.creditScore + 1)
			if loan.outstanding <= 0:
				state.loans.erase(loan)
				state.creditScore = minf(100, state.creditScore + 3)
				state.pendingNotices.append("A loan is fully repaid. The bank trusts you a little more.")
				_timeline("Loan fully repaid")
		else:
			var private_: bool = loan.lender == "private"
			loan.outstanding += roundi(pay * (0.10 if private_ else 0.05))
			loan.missedInRow += 1
			missedThisWeek = true
			state.lastMissDay = state.dayIndex
			state.creditScore = maxf(0, state.creditScore - (25 if private_ else 15))
			at(hq, func(): _note("missedPayment", "Missed a loan payment of %s: penalty added, bank trust down" % money(pay), pay))
			_timeline("Missed a loan payment (%d weeks running)" % (state.missedInRow + 1))
			emit("loanMissed", {"loanId": loan.id})
	if missedThisWeek:
		state.missedInRow += 1
	elif anyDue:
		state.missedInRow = 0
	# 4. Weekly records: each outlet, then the company.
	var company := M.WeekRecord.new()
	company.week = state.weekIndex
	var starsSum := 0.0
	var starsN := 0.0
	for l in state.openLocations:
		var w := _weekRecordFor(l)
		l.weeks.append(w)
		if l.weeks.size() > 104: l.weeks.remove_at(0)
		company.revenue += w.revenue
		company.costs += w.costs
		company.interest += w.interest
		company.wasteCost += w.wasteCost
		company.groupsServed += w.groupsServed
		company.walkouts += w.walkouts
		company.ingredientSpend += w.ingredientSpend
		company.wages += w.wages
		company.rent += w.rent
		company.marketing += w.marketing
		company.upkeep += w.upkeep
		company.other += w.other
		company.utilities += w.utilities
		starsSum += w.avgStars * w.groupsServed
		starsN += w.groupsServed
		at(l, func():
			# Competition (doc 11 §A.5); high streets attract rivals twice as fast.
			if l.reputation >= 4.0 and w.operatingProfit > 0:
				var up := b.d("COMPETITION_UP") * (2 if l.format == "highStreet" else 1)
				l.competition = minf(b.d("COMPETITION_MAX"), l.competition + up)
			else:
				l.competition = maxf(0, l.competition - b.d("COMPETITION_DOWN"))
			_weeklyOutlet(w))
	company.operatingProfit = company.revenue - company.costs
	company.avgStars = 0.0 if starsN == 0 else starsSum / starsN
	state.weeks.append(company)
	if state.weeks.size() > 104: state.weeks.remove_at(0)
	if company.netProfit > 0:
		state.profitableWeeksInRow += 1
	else:
		state.profitableWeeksInRow = 0
	if state.investorTaken and company.operatingProfit > 0:
		var share := roundi(company.operatingProfit * state.investorShare)
		state.cash -= share
		at(hq, func(): _note("investor", "Your investor took their %d%% share: %s" % [roundi(state.investorShare * 100), money(share)], share))
	if state.owner.restDaysThisWeek >= 2 and company.netProfit > 0:
		_completeObjective("obj_2_week_off")
	if company.revenue > 0 and company.wasteCost < 0.03 * company.revenue:
		_completeObjective("obj_1_no_waste")
	at(hq, _generateApplicants)
	_weeklyChain()
	_checkStage()
	state.pendingNotices.append("@weekly")

func _monthly() -> void:
	state.cash -= state.monthUtilities
	state.monthUtilities = 0
	# Tax on the company's profit over the last 28 days.
	var profit := 0
	for l in state.openLocations:
		for d in l.days:
			if d.dayIndex > state.dayIndex - 28:
				profit += d.profit
		profit += l.today.profit
	var hq: M.Location = state.openLocations[0]
	if profit > 0:
		var tax := roundi(profit * b.d("TAX_RATE"))
		at(hq, func():
			spend(tax, "other")
			_note("tax", "Paid %s tax on this month's profit" % money(tax), 0))
	for l in state.openLocations:
		at(l, func():
			spend(b.i("LICENCE_FEE"), "other")
			# Random inspection scheduling (about once per 8 weeks).
			if l.inspectionDay < state.dayIndex and _rng.chance(28 / b.d("INSPECTION_EVERY_DAYS")):
				var day := state.dayIndex + _rng.next_int(1, 28)
				state.scheduled.append(M.Scheduled.mk("inc_inspection", day, null, null, l.id))
				l.inspectionDay = day
			# The landlord reviews rent every 168 days after the first 84.
			var since = state.dayIndex - l.openDay
			if since >= 83 and not any(state.scheduled, func(s): return s.incidentId == "inc_landlord_rent" and s.locationId == l.id):
				var next: int = state.flags.get("%d:next_rent_review" % l.id, l.openDay + 84)
				if state.dayIndex + 28 >= next:
					state.scheduled.append(M.Scheduled.mk("inc_landlord_rent", maxi(next, state.dayIndex + 1), null, null, l.id))
					state.flags["%d:next_rent_review" % l.id] = next + 168)
	at(hq, func():
		if _rng.chance(0.10) and state.cooldowns.get("%d:inc_tax_audit" % hq.id, -1) < state.dayIndex:
			_raiseIncident("inc_tax_audit", null, null, true))
	state.pendingNotices.append("@monthly")

func _bankruptcyCheck() -> void:
	if state.cash < 0:
		state.negativeDays += 1
		_timeline("Closed the day with negative cash (%s)" % money(state.cash))
		if state.negativeDays == 1 or not any(state.openIncidents, func(i): return i.incidentId == "inc_lifeline"):
			_raiseIncident("inc_lifeline", null, null, true)
		if state.negativeDays >= b.i("BANKRUPT_NEGATIVE_DAYS"):
			_gameOver("Your cash stayed below zero for %d days in a row. The bank closed your account." % b.i("BANKRUPT_NEGATIVE_DAYS"))
	else:
		state.negativeDays = 0
	if state.missedInRow >= b.i("BANKRUPT_MISSED_PAYMENTS"):
		_gameOver("You missed %d loan payments in a row. The bank took the restaurant." % b.i("BANKRUPT_MISSED_PAYMENTS"))

func _gameOver(reason: String) -> void:
	if state.phase == "gameOver":
		return
	state.gameOverReason = reason
	_timeline(reason)
	state.phase = "gameOver"
	emit("gameOver", {"reason": reason})

# ---------------------------------------------------------- credit and loans

func _equipmentResale(e: M.Equipment) -> int:
	return roundi(content.equipment[e.type].price * e.condition / 100 * b.d("RESALE_FACTOR"))

func _avgWeeklyOpProfit(weeks := 8) -> int:
	var ws: Array = state.weeks if state.weeks.size() <= weeks else state.weeks.slice(state.weeks.size() - weeks)
	if ws.is_empty():
		return 0
	var a := 0
	for w in ws:
		a += w.operatingProfit
	return roundi(float(a) / ws.size())

func _valuation() -> int:
	var resale := 0
	var stars := 0.0
	for l in state.openLocations:
		for e in l.equipment:
			resale += _equipmentResale(e)
		stars += l.reputation
	var profitPower: int = (45 if state.perks.has("perk_brand45") else b.i("VALUATION_PROFIT_MULT")) * maxi(0, _avgWeeklyOpProfit())
	return state.cash + resale + profitPower + roundi(b.d("VALUATION_PER_STAR") * stars) \
		+ state.franchises * b.i("FRANCHISE_VALUE") - state.totalOutstanding

func _creditLimit() -> int:
	return maxi(0, roundi(_valuation() * 0.4 * state.creditScore / 100 - state.totalOutstanding))

func _loanRate(secured := false, private_ := false) -> float:
	var r := b.d("LOAN_WEEKLY_RATE") * diff("DIFF_INTEREST") * (1.6 - state.creditScore / 100)
	if secured: r *= 0.8
	if private_: r = b.d("LOAN_WEEKLY_RATE") * diff("DIFF_INTEREST") * 3
	return r

func _currentInstalments() -> int:
	var a := 0
	for l in state.loans:
		a += l.instalment
	return a

## The bank's five checks, in order, with pass/fail — shown before applying (doc 07 §4.8).
## Each entry is [label, passed].
func _bankChecks(amount: int, term: int, secured: bool) -> Array:
	var open := state.loans.size()
	var firstPay := roundi(float(amount) / term + amount * _loanRate(secured))
	var afford := (0.7 if secured else 0.5) * _avgWeeklyOpProfit()
	var limit := _creditLimit()
	return [
		["Fewer than 3 loans open (%d now)" % open, open < 3],
		["No missed payment in the last 4 weeks", state.dayIndex - state.lastMissDay > 28],
		["Bank trust at least 30 (now %d)" % roundi(state.creditScore), state.creditScore >= 30],
		["Repayments %s/week within %d%% of weekly profit (%s)" % [money(_currentInstalments() + firstPay), 70 if secured else 50, money(afford)], _currentInstalments() + firstPay <= afford],
		["Amount within your credit limit (%s)" % money(limit), amount <= limit],
	]

func _applyLoan(amount: int, term: int, secured: bool, lender: String) -> CommandResult:
	if amount < 1000:
		return CommandResult.fail(SimError.invalidValue, "Borrow at least 1,000.")
	if not [26, 52, 104].has(term):
		return CommandResult.fail(SimError.invalidValue)
	if lender == "private":
		if any(state.loans, func(l): return l.lender == "private"):
			return CommandResult.fail(SimError.limitReached, "The private lender allows only one loan at a time.")
		if amount > b.i("PRIVATE_LENDER_MAX"):
			return CommandResult.fail(SimError.invalidValue, "The private lender lends up to %s." % money(b.i("PRIVATE_LENDER_MAX")))
		_addLoan(amount, 26, "private", false)
		return CommandResult.good("approved")
	if state.bankBlockedUntil > state.dayIndex:
		return CommandResult.fail(SimError.locked, "After a rejection the bank waits 7 days. Try again on day %d." % (state.bankBlockedUntil + 1))
	if secured and any(state.loans, func(l): return l.secured):
		return CommandResult.fail(SimError.limitReached, "This restaurant already secures a loan.")
	var checks := _bankChecks(amount, term, secured)
	var reasons := ["tooManyLoans", "recentMissedPayment", "lowTrust", "cannotAfford"]
	for i in 4:
		if not checks[i][1]:
			state.bankBlockedUntil = state.dayIndex + 7
			return CommandResult.new(false, SimError.refused, "Rejected: %s." % checks[i][0], [], reasons[i])
	if not checks[4][1]:
		var limit := _creditLimit()
		if limit >= 1000:
			state.counterOffer = limit
			state.counterOfferTerm = term
			return CommandResult.new(true, null, "The bank offers %s instead." % money(limit), [], "counterOffer")
		state.bankBlockedUntil = state.dayIndex + 7
		return CommandResult.new(false, SimError.refused, "Rejected: over your credit limit.", [], "overLimit")
	_addLoan(amount, term, "bank", secured)
	return CommandResult.good("approved")

func _addLoan(amount: int, term: int, lender: String, secured: bool) -> void:
	var rate := _loanRate(false, true) if lender == "private" else _loanRate(secured)
	var l := M.Loan.new()
	l.id = state.allocId(); l.lender = lender; l.principal0 = amount; l.outstanding = amount
	l.weeklyRate = rate; l.termWeeks = term; l.secured = secured; l.startDay = state.dayIndex
	state.loans.append(l)
	state.cash += amount
	emit("cashChanged", {"delta": amount})
	_timeline("Borrowed %s (%s)" % [money(amount), "private lender" if lender == "private" else "bank"])

func _repayLoan(loanId: int, amount: int) -> CommandResult:
	var loan = first_or_null(state.loans, func(l): return l.id == loanId)
	if loan == null: return CommandResult.fail(SimError.unknownId)
	var pay := mini(amount, loan.outstanding)
	if pay <= 0: return CommandResult.fail(SimError.invalidValue)
	if state.cash < pay: return CommandResult.fail(SimError.notEnoughCash)
	state.cash -= pay
	loan.outstanding -= pay
	if loan.outstanding <= 0:
		state.loans.erase(loan)
		state.creditScore = minf(100, state.creditScore + 3)
		_timeline("Paid off a loan early")
	return CommandResult.good()

func _lifeline(kind: String, equipmentId) -> CommandResult:
	match kind:
		"emergencyLoan":
			var amount := maxi(0, -state.cash) + b.i("EMERGENCY_LOAN_EXTRA")
			_addLoan(amount, 26, "private", false)
			state.loans[state.loans.size() - 1].weeklyRate = _loanRate() * 3
		"sellEquipment":
			var e := loc.equipmentById(equipmentId)
			if e == null: return CommandResult.fail(SimError.unknownId)
			var v := roundi(_equipmentResale(e) * 0.5)
			loc.equipment.erase(e)
			earn(v, "none")
			_timeline("Sold %s in a hurry for %s" % [content.equipment[e.type].name, money(v)])
		"investor":
			if state.investorTaken:
				return CommandResult.fail(SimError.limitReached, "Only one investor per game.")
			state.investorTaken = true
			state.investorShare = b.d("INVESTOR_SHARE")
			earn(b.i("INVESTOR_CASH"), "none")
			_timeline("Took an investor: %s for 20%% of weekly profit forever" % money(b.i("INVESTOR_CASH")))
		_:
			return CommandResult.fail(SimError.invalidValue)
	return CommandResult.good()

# ---------------------------------------------------------- marketing

func _campaignFit(type: String) -> float:
	var mix: Dictionary = content.locationClasses[loc.classId].segmentMix
	var aud = campaignAudience.get(type)
	if aud == null:
		return 0.5
	var a := 0.0
	for s in aud:
		a += mix.get(s, 0.0)
	return a

func _fitWord(fit: float) -> String:
	return "poor" if fit < 0.45 else ("fair" if fit < 0.6 else "good")

func _lastCampaignDay(type: String) -> Variant:
	var last = null
	for c in loc.campaigns:
		if c.type == type and (last == null or c.startDay > last):
			last = c.startDay
	return last

func _startCampaign(type: String) -> CommandResult:
	if state.stage < 2:
		return CommandResult.fail(SimError.locked, "Marketing unlocks at Stage 2 (Stable).")
	var def = b.map("CAMPAIGNS").get(type)
	if def == null: return CommandResult.fail(SimError.unknownId)
	var cost := roundi(float(def["cost"]) * (0.85 if state.perks.has("perk_highStreet") else 1.0))
	if state.cash < cost:
		return CommandResult.fail(SimError.notEnoughCash, "This campaign costs %s." % money(cost))
	var start := state.dayIndex + 1 if state.phase == "close" else state.dayIndex
	if any(loc.campaigns, func(c): return c.type == type and c.endDay >= start):
		return CommandResult.fail(SimError.limitReached, "That campaign is already running.")
	if type == "blogger":
		spend(cost, "marketing")
		state.flags["%d:blogger_pending" % loc.id] = start + 3
		state.flags.erase("%d:blogger_done" % loc.id)
		var cb := M.Campaign.new()
		cb.id = state.allocId(); cb.type = type; cb.startDay = start; cb.endDay = start + 3; cb.cost = cost
		cb.boost = 0; cb.mult = 1; cb.outcome = "pending"; cb.reason = "A food blogger will visit within 3 days."; cb.revealed = true
		loc.campaigns.append(cb)
		return CommandResult.good()
	var fit := _campaignFit(type)
	var last = _lastCampaignDay(type)
	var repeat: bool = last != null and start - last < 21
	var fresh := loc.freshness >= 0.8
	var luck := _rng.next_float() + b.d("CAMPAIGN_FIT_WEIGHT") * (fit - 0.5) \
		+ (b.d("CAMPAIGN_FRESH_BONUS") if fresh else 0.0) - (b.d("CAMPAIGN_REPEAT_PENALTY") if repeat else 0.0) \
		+ b.d("CAMPAIGN_REP_WEIGHT") * (loc.reputation - 3.5)
	var table := [[0.15, 0.0, "Flopped"], [0.40, 0.5, "Weak response"], [0.75, 1.0, "As expected"],
		[0.93, 1.5, "Worked well"], [99.0, 3.5, "Big hit"]]
	var mult := 0.0
	var outcome := ""
	for row in table:
		if luck < row[0]:
			mult = row[1]
			outcome = row[2]
			break
	var name: String = campaignNames[type]
	var audl: Array = []
	for s in campaignAudience[type]:
		audl.append(segmentNames[s])
	var aud := " and ".join(audl)
	var reason: String
	if mult == 0:
		if repeat:
			reason = "The %s flopped. People had seen the same thing only days ago." % name
		elif fit < 0.45:
			reason = "The %s flopped. Few %s around here." % [name, aud]
		else:
			reason = "The %s flopped. Bad luck: it happens to every ad sometimes." % name
	elif mult < 1:
		reason = "The %s got a weak response%s." % [name, " — it was too soon after the last one" if repeat else ""]
	elif mult == 1:
		reason = "The %s did about what was expected." % name
	else:
		reason = "The %s %s%s." % [name, "was a big hit" if mult > 2 else "worked well", " — a fresh menu gave people a reason to come" if fresh else ""]
	spend(cost, "marketing")
	var days := int(def["days"])
	var boost := float(def["boost"]) * mult
	var buzzGain := float(def["buzz"]) * mult
	var before := loc.buzz
	loc.buzz = minf(1, loc.buzz + buzzGain)
	var c := M.Campaign.new()
	c.id = state.allocId(); c.type = type; c.startDay = start; c.endDay = start + days - 1; c.cost = cost
	c.boost = boost; c.mult = mult; c.outcome = outcome; c.reason = reason; c.buzzLeft = loc.buzz - before
	loc.campaigns.append(c)
	_note("campaign", "Started a %s (%s)" % [name, money(cost)], cost)
	return CommandResult.good()

func _bloggerVisit(stars: float) -> void:
	state.flags["%d:blogger_done" % loc.id] = 1 << 30
	state.flags.erase("%d:blogger_pending" % loc.id)
	var c = null
	for x in loc.campaigns:
		if x.type == "blogger":
			c = x
	if stars >= 4:
		loc.reputation = minf(5, loc.reputation + 0.3)
		loc.buzz = minf(1, loc.buzz + 0.3)
		if c != null:
			c.outcome = "Big hit"
			c.reason = "The food blogger loved it (%.1f stars): rating +0.3." % stars
	else:
		loc.reputation = maxf(0, loc.reputation - 0.2)
		if c != null:
			c.outcome = "Flopped"
			c.reason = "The food blogger was not impressed (%.1f stars): rating −0.2." % stars
	if c != null:
		state.pendingNotices.append(c.reason)

## Return on spend per campaign (doc 02 §13.2).
func _campaignAccounting() -> void:
	var l := loc
	var t := loc.today
	var active: Array = l.campaigns.filter(func(c): return c.type != "blogger" and not c.settled)
	if active.is_empty():
		return
	var boosts: Array = l.campaigns.filter(func(c): return c.type != "blogger" and state.dayIndex >= c.startDay and state.dayIndex <= c.endDay)
	var sumBoost := 0.0
	for c in boosts: sumBoost += c.boost
	var boostEff := minf(sumBoost, b.d("CAMPAIGN_BOOST_CAP"))
	var sumBuzzLeft := 0.0
	for c in active: sumBuzzLeft += c.buzzLeft
	var bf := 0.90 + 0.20 * l.buzz
	var bfWithout := 0.90 + 0.20 * maxf(0, l.buzz - sumBuzzLeft)
	var lift := (1 + boostEff) * bf / bfWithout
	var groups := t.groupsArrived
	var seated := t.groupsSeated
	if groups > 0 and lift > 1.0001:
		var baseGroups := groups / lift
		var extraSeated := maxf(0.0, seated - minf(baseGroups, float(seated)))
		var weights: Array = []
		for c in active:
			var w := 0.0
			if boosts.has(c) and sumBoost > 0:
				w += boostEff * c.boost / sumBoost
			w += 0.20 * c.buzzLeft / bfWithout
			if w > 0:
				weights.append([c, w])
		var totalW := 0.0
		for e in weights: totalW += e[1]
		var perGroup := 0.0 if seated == 0 else float(t.revenue - t.ingredientsUsedCost) / seated
		for e in weights:
			var c: M.Campaign = e[0]
			var share: float = extraSeated * e[1] / totalW
			c.extraGroups += share
			c.extraProfit += share * perGroup
			if c.type == "promoDay" and c.startDay == state.dayIndex:
				var avgBill := 0.0 if seated == 0 else float(t.revenue) / seated
				c.discountGiven += roundi(baseGroups * avgBill * (1 / 0.75 - 1))
	for c in active:
		if state.dayIndex > c.endDay and c.buzzLeft < 0.0005:
			c.settled = true

func _reworkMenu() -> CommandResult:
	var chef = first_or_null(loc.staff, func(s): return s.role == "headChef")
	if chef == null:
		return CommandResult.fail(SimError.locked, "You need a head chef to rework the menu.")
	if chef.skill < b.d("MENU_REWORK_SKILL"):
		return CommandResult.fail(SimError.locked, "%s needs skill %d to rework the menu (now %d)." % [chef.name, b.i("MENU_REWORK_SKILL"), roundi(chef.skill)])
	var cost := b.i("MENU_REWORK_COST")
	if state.cash < cost:
		return CommandResult.fail(SimError.notEnoughCash, "A menu rework costs %s." % money(cost))
	spend(cost, "marketing")
	loc.freshness = 1
	loc.buzz = minf(1, loc.buzz + b.d("MENU_REWORK_BUZZ"))
	loc.lastReworkDay = state.dayIndex
	var day := state.dayIndex + 1 if state.phase == "close" else state.dayIndex
	chef.trainingUntil = maxi(chef.trainingUntil, day + 1)
	if state.phase == "prep": chef.workingToday = false
	_note("rework", "Reworked the menu: it feels new again", cost)
	_timeline("Reworked the menu")
	return CommandResult.good()

# ================================================================ handlers.dart
# Command dispatch and the remaining command handlers.
# A command is a Dictionary: {"type": "BuyRestaurant", "offerIndex": 2}, with the
# field names of the original Dart command classes.

func _inPhase(phases: Array) -> bool:
	return phases.has(state.phase)

func _handle(c: Dictionary) -> CommandResult:
	if state.phase == "gameOver":
		return CommandResult.fail(SimError.wrongPhase, "The game is over.")
	var prepClose := ["prep", "close"]
	var t: String = c.type
	match t:
		"BuyDueDiligence":
			if not _inPhase(["market"]): return CommandResult.fail(SimError.wrongPhase)
			return _dueDiligence(c.offerIndex)
		"BuyRestaurant":
			if not _inPhase(["market"]): return CommandResult.fail(SimError.wrongPhase)
			return _buy(c.offerIndex)
		"ResolveIncident":
			var inst = first_or_null(state.incidents, func(i): return i.id == c.instanceId and not i.resolved)
			if inst == null: return CommandResult.fail(SimError.unknownId)
			var def: Content.IncidentDef = content.incidents[inst.incidentId]
			var opt = first_or_null(def.options, func(o): return o.id == c.optionId)
			if opt == null: return CommandResult.fail(SimError.unknownId)
			var why = _optionBlocked(opt, inst)
			if why != null: return CommandResult.fail(SimError.locked, why)
			_resolveIncident(inst, c.optionId)
			return CommandResult.good(inst.result)
	match t:
		"AckNotices":
			state.pendingNotices.clear()
			return CommandResult.good()
		"SelectLocation":
			var l := state.locationById(c.locationId)
			if l == null or l.closedForGood: return CommandResult.fail(SimError.unknownId)
			state.viewLocationId = l.id
			return CommandResult.good()
		"OwnerTravel":
			if not state.hasLocation: return CommandResult.fail(SimError.wrongPhase)
			return _ownerTravel(c.locationId)
		"EndGame":
			state.ended = true
			return CommandResult.good()
	if not state.hasLocation:
		return CommandResult.fail(SimError.wrongPhase, "Buy a restaurant first.")
	match t:
		"StartService":
			if not _inPhase(["prep"]): return CommandResult.fail(SimError.wrongPhase)
			_applyPendingDefaults("prep")
			if state.phase == "gameOver": return CommandResult.good()
			_startServiceAll()
			return CommandResult.good()
		"EndService":
			# Skip to the end: run the remaining ticks at once.
			if not _inPhase(["service"]): return CommandResult.fail(SimError.wrongPhase)
			var guard := 0
			while state.phase == "service" and guard < 1000:
				guard += 1
				for inc in state.openIncidents:
					if inc.countdown > 0:
						inc.countdown = 1
				_serviceTickAll()
			return CommandResult.good()
		"EndDay":
			if not _inPhase(["close"]): return CommandResult.fail(SimError.wrongPhase)
			_applyPendingDefaults("close")
			if state.phase == "gameOver": return CommandResult.good()
			for l in state.openLocations:
				l.days.append(l.today)
				if l.days.size() > 56: l.days.remove_at(0)
			state.dayIndex += 1
			_beginDay()
			return CommandResult.good()
		"OwnerQueueTask":
			if not _inPhase(["service"]): return CommandResult.fail(SimError.wrongPhase)
			return _ownerQueue(c.taskId)
		"OwnerStand":
			var area = c.get("area")
			if area != null and not areaTasks.has(area):
				return CommandResult.fail(SimError.invalidValue)
			if state.phase == "service":
				if not _ownerPresent:
					return CommandResult.fail(SimError.locked, "You are not at this restaurant.")
				ss.ownerArea = area
			elif state.phase == "prep":
				state.owner.startArea = area
			else:
				return CommandResult.fail(SimError.wrongPhase)
			return CommandResult.good()
		"OwnerRush":
			if not _inPhase(["service"]): return CommandResult.fail(SimError.wrongPhase)
			return _rush(c.groupId)
		"OwnerTreat":
			if not _inPhase(["service"]): return CommandResult.fail(SimError.wrongPhase)
			return _treat(c.groupId)
		"OwnerBringBill":
			if not _inPhase(["service"]): return CommandResult.fail(SimError.wrongPhase)
			return _bringBill(c.groupId)
		"MoveStaff":
			if not _inPhase(["service"]): return CommandResult.fail(SimError.wrongPhase)
			return _moveStaff(c.staffId, c.role)
		"OwnerRest":
			if not _inPhase(["prep"]): return CommandResult.fail(SimError.wrongPhase)
			state.owner.restingToday = c.rest
			return CommandResult.good()
		"SetDishEnabled":
			var m: M.MenuItem = loc.menu.get(c.dishId)
			if m == null: return CommandResult.fail(SimError.unknownId)
			var enabled: bool = c.enabled
			var onMenu := count(loc.menu.values(), func(x): return x.enabled)
			if not enabled and onMenu <= b.i("MENU_MIN"):
				return CommandResult.fail(SimError.limitReached, "A menu needs at least %d dishes." % b.i("MENU_MIN"))
			var maxMenu := b.i("MENU_MAX_MIXED" if themeOfLoc.isMixed else "MENU_MAX")
			if enabled and not m.enabled and onMenu >= maxMenu:
				return CommandResult.fail(SimError.limitReached, "A menu can have at most %d dishes." % maxMenu)
			if enabled and not m.enabled:
				if state.dayIndex - m.offSinceDay >= 14 and state.dayIndex - loc.lastRotateDay >= 7:
					loc.freshness = minf(1, loc.freshness + b.d("ROTATE_FRESHNESS"))
					loc.lastRotateDay = state.dayIndex
					emit("menuRotated")
			elif not enabled and m.enabled:
				m.offSinceDay = state.dayIndex
			m.enabled = enabled
			return CommandResult.good()
	if not _inPhase(prepClose):
		return CommandResult.fail(SimError.wrongPhase, "Do that before or after service.")
	match t:
		"SetDayOff": return _setDayOff(c.staffId, c.weekday)
		"WorkDayOff": return _workDayOff(c.staffId)
		"PlaceOrder": return _placeOrder(c.supplierId, c.lines)
		"CancelOrder":
			var o = first_or_null(loc.orders, func(x): return x.id == c.orderId)
			if o == null: return CommandResult.fail(SimError.unknownId)
			if o.placedDay != state.dayIndex: return CommandResult.fail(SimError.locked, "Too late to cancel.")
			loc.orders.erase(o)
			return CommandResult.good()
		"SetPrice":
			var m: M.MenuItem = loc.menu.get(c.dishId)
			if m == null: return CommandResult.fail(SimError.unknownId)
			var base: int = content.dishes[c.dishId].basePrice
			var lo := ceili(base * b.d("PRICE_MIN_MULT"))
			var hi := floori(base * b.d("PRICE_MAX_MULT"))
			if c.price < lo or c.price > hi:
				return CommandResult.fail(SimError.invalidValue, "Price must be between %d and %d." % [lo, hi])
			m.price = c.price
			return CommandResult.good()
		"Hire": return _hire(c.applicantId)
		"Fire": return _fire(c.staffId)
		"SetWage": return _setWage(c.staffId, c.wage)
		"Train": return _train(c.staffId)
		"GiveDayOff": return _giveDayOff(c.staffId)
		"Warn": return _warn(c.staffId)
		"Promote": return _promote(c.staffId)
		"Maintain": return _maintain(c.equipmentId)
		"Repair":
			var e := loc.equipmentById(c.equipmentId)
			if e == null or not e.broken:
				return CommandResult.fail(SimError.invalidValue, "Nothing to repair.")
			var cost := roundi(content.equipment[e.type].price * float(b.map("REPAIR")[c.mode]["cost"]))
			if state.cash < cost:
				return CommandResult.fail(SimError.notEnoughCash, "The repair costs %s." % money(cost))
			var inst := M.IncidentInstance.new()
			inst.id = 0; inst.incidentId = "manual"; inst.subjectId = e.id; inst.createdDay = state.dayIndex
			_applyEffect({"type": "repair", "mode": c.mode}, inst, [])
			return CommandResult.good()
		"BuyEquipment": return _buyEquipment(c.type_, c.get("secondHand", false), c.get("replaceId"))
		"SellEquipment":
			var e := loc.equipmentById(c.equipmentId)
			if e == null: return CommandResult.fail(SimError.unknownId)
			var v := _equipmentResale(e)
			loc.equipment.erase(e)
			earn(v, "none")
			_note("sold", "Sold %s for %s" % [content.equipment[e.type].name, money(v)], 0)
			return CommandResult.good(v)
		"ApplyLoan": return _applyLoan(c.amount, c.termWeeks, c.get("secured", false), c.get("lender", "bank"))
		"AcceptCounterOffer":
			var amt = state.counterOffer
			if amt == null: return CommandResult.fail(SimError.invalidValue)
			state.counterOffer = null
			_addLoan(amt, state.counterOfferTerm, "bank", false)
			return CommandResult.good()
		"RepayLoan": return _repayLoan(c.loanId, c.amount)
		"StartCampaign": return _startCampaign(c.type_)
		"ReworkMenu": return _reworkMenu()
		"SetParLevel":
			if state.stage < 2:
				return CommandResult.fail(SimError.locked, "Keep-in-stock levels unlock at Stage 2.")
			if c.par <= 0:
				loc.parLevels.erase(c.ingredientId)
			else:
				loc.parLevels[c.ingredientId] = M.ParLevel.mk(c.par, c.supplierId)
			return CommandResult.good()
		"PayPayable": return _payPayable(c.payableId)
		"TakeLifeline": return _lifeline(c.kind, c.get("equipmentId"))
		"BuyOutlet": return _buyOutlet(c.offerIndex, c.get("themeId"))
		"InspectOutlet": return _inspectOutlet(c.offerIndex)
		"BuildOutlet": return _buildOutlet(c.siteId, c.size, c.fitOut, c.get("themeId"))
		"HireManager": return _hireManager(c.applicantId)
		"PromoteToManager": return _promoteToManager(c.staffId)
		"TransferStaff": return _transfer(c.staffId, c.toLocationId)
		"Renovate": return _renovate(c.tables)
		"SetPolicies":
			var p := loc.policies
			if c.get("spendingLimit") != null: p.spendingLimit = clampi(c.spendingLimit, 0, 20000)
			if c.get("maintenanceThreshold") != null: p.maintenanceThreshold = clampi(c.maintenanceThreshold, 20, 90)
			if c.get("stance") != null and ["frugal", "balanced", "quality"].has(c.stance): p.stance = c.stance
			if c.get("mayHire") != null: p.mayHire = c.mayHire
			if c.get("mayGiveRaises") != null: p.mayGiveRaises = c.mayGiveRaises
			if c.get("autoOrder") != null: p.autoOrder = c.autoOrder
			return CommandResult.good()
		"SetManagerBonus":
			var mg := loc.manager
			if mg == null: return CommandResult.fail(SimError.unknownId, "No manager here.")
			mg.bonusPct = clampi(c.pct, 0, 10)
			return CommandResult.good()
		"AnswerRequest": return _answerRequest(c.requestId, c.answer)
		"Audit": return _audit()
		"ListOutlet":
			if c.list:
				var chk := _sellCheck()
				if not chk.ok: return chk
				loc.listedDay = state.dayIndex
				for s in loc.staff:
					s.moodMods.append(M.MoodMod.mk("Job security", -8, state.dayIndex + 28))
			else:
				loc.listedDay = -1
				loc.saleOffers.clear()
			return CommandResult.good()
		"AcceptSaleOffer":
			if c.index < 0 or c.index >= loc.saleOffers.size(): return CommandResult.fail(SimError.unknownId)
			var chk := _sellCheck()
			if not chk.ok: return chk
			_completeSale(loc.saleOffers[c.index].amount)
			return CommandResult.good()
		"QuickSale": return _quickSale()
		"CloseOutlet": return _closeOutlet()
		"SetDelivery":
			loc.deliveryOn = c.on
			return CommandResult.good()
		"BuildCentralKitchen": return _buildCentralKitchen()
		"SignBulkContract": return _signBulk()
		"StartFranchise": return _startFranchise()
	return CommandResult.fail(SimError.invalidValue)

## Unanswered cards of the phase being left take their default option.
func _applyPendingDefaults(phase: String) -> void:
	for inst in state.openIncidents:
		var def: Content.IncidentDef = content.incidents[inst.incidentId]
		if def.timing == phase or phase == "close" or inst.countdown < 0:
			_resolveIncident(inst, _ignoredChoice(inst), true)
	# Keep the list short: drop old resolved cards.
	remove_where(state.incidents, func(i): return i.resolved and i.createdDay < state.dayIndex - 1)
	if phase == "close":
		_bankruptcyCheckAfterDefaults()

func _bankruptcyCheckAfterDefaults() -> void:
	if state.negativeDays >= b.i("BANKRUPT_NEGATIVE_DAYS") and state.cash < 0:
		_gameOver("Your cash stayed below zero for %d days in a row." % b.i("BANKRUPT_NEGATIVE_DAYS"))

func _dueDiligence(i: int) -> CommandResult:
	if i < 0 or i >= state.offers.size(): return CommandResult.fail(SimError.unknownId)
	var o: M.Offer = state.offers[i]
	if o.inspected: return CommandResult.fail(SimError.limitReached, "Already inspected.")
	var cost := b.i("DUE_DILIGENCE_COST")
	if state.cash < cost: return CommandResult.fail(SimError.notEnoughCash)
	state.cash -= cost
	o.inspected = true
	var hidden: Array = o.location.hidden.duplicate()
	_rng.shuffle(hidden)
	var reveal := ceili(hidden.size() / 2.0)
	for k in reveal:
		hidden[k].revealed = true
	return CommandResult.good(reveal)

func _buy(i: int) -> CommandResult:
	if i < 0 or i >= state.offers.size(): return CommandResult.fail(SimError.unknownId)
	var o: M.Offer = state.offers[i]
	var need := o.price - o.loan
	if state.cash < need: return CommandResult.fail(SimError.notEnoughCash)
	state.cash -= need
	o.location.id = 1
	o.location.themeId = state.themeId
	o.location.invested = o.price
	o.location.originalTables = o.location.tableSeats.size()
	state.locations = [o.location]
	state.nextLocId = 2
	state.viewLocationId = 1
	state.ownerLocationId = 1
	state.brands = [state.themeId]
	state.offers.clear()
	if o.loan > 0:
		var ln := M.Loan.new()
		ln.id = state.allocId(); ln.lender = "start"; ln.principal0 = o.loan; ln.outstanding = o.loan
		ln.weeklyRate = b.d("LOAN_WEEKLY_RATE") * diff("DIFF_INTEREST"); ln.termWeeks = 52; ln.secured = true; ln.startDay = 0
		state.loans.append(ln)
	_activateHiddenProblems(o.location)
	_generateApplicants()
	state.dayIndex = 0
	_timeline("Bought %s for %s%s" % [o.location.name, money(o.price), (" with a %s loan" % money(o.loan)) if o.loan > 0 else ""])
	state.pendingNotices.append("@welcome")
	_beginDay()
	return CommandResult.good()

func _maintain(id: int) -> CommandResult:
	var e := loc.equipmentById(id)
	if e == null: return CommandResult.fail(SimError.unknownId)
	if e.broken: return CommandResult.fail(SimError.invalidValue, "It is broken: it needs a repair, not servicing.")
	if state.dayIndex - e.lastMaintDay < 7: return CommandResult.fail(SimError.limitReached, "Serviced this week already.")
	var t: Content.EquipmentType = content.equipment[e.type]
	var cost := roundi(t.price * b.d("MAINTENANCE_PCT"))
	if state.cash < cost: return CommandResult.fail(SimError.notEnoughCash)
	if e.condition >= _maxCondition(e) - 0.5:
		return CommandResult.fail(SimError.limitReached, "Already as good as its age allows (%d)." % roundi(_maxCondition(e)))
	spend(cost, "upkeep")
	var quick := e.condition >= 50
	e.condition = minf(_maxCondition(e), e.condition + b.d("MAINTENANCE_GAIN"))
	e.lastMaintDay = state.dayIndex
	if not quick:
		var day := state.dayIndex + 1 if state.phase == "close" else state.dayIndex
		e.unavailableUntil = maxi(e.unavailableUntil, day + 1)
	_markFridge(e)
	return CommandResult.good("quick" if quick else "slow")

func _buyEquipment(type: String, secondHand := false, replaceId = null) -> CommandResult:
	var t: Content.EquipmentType = content.equipment.get(type)
	if t == null: return CommandResult.fail(SimError.unknownId)
	var price := roundi(t.price * (0.5 if secondHand else 1.0))
	var old := null if replaceId == null else loc.equipmentById(replaceId)
	var trade := 0 if old == null else _equipmentResale(old)
	if state.cash + trade < price:
		return CommandResult.fail(SimError.notEnoughCash, "You need %s." % money(price - trade))
	if old != null:
		loc.equipment.erase(old)
		if trade > 0: earn(trade, "none")
	spend(price, "upkeep")
	var arrive := state.dayIndex + (1 if state.phase == "close" else 0) + (1 if secondHand else 2)
	var e := M.Equipment.new()
	e.id = state.allocId(); e.type = type; e.condition = 55 if secondHand else 100
	e.ageDays = 3 * 336 if secondHand else 0; e.unavailableUntil = arrive
	e.condition = minf(e.condition, _maxCondition(e))
	loc.equipment.append(e)
	_markFridge(e)
	_timeline("Bought a %s %s (%s)" % ["second-hand" if secondHand else "new", t.name.to_lower(), money(price)])
	return CommandResult.good(e.id)

# ================================================================ queries.dart
# Read-only helpers for the UI. They call the same functions the rules use.

var service: M.ServiceState:
	get: return loc.service if state.hasLocation else null
var ownerPresent: bool:
	get: return state.hasLocation and not state.owner.restingToday and not state.travelling and state.ownerLocationId == loc.id

func clock(t: int) -> String: return _clock(t)
func role(r: String) -> String: return roleName(r)
func expectedWage(r: String, skill: float) -> int: return _expectedWage(r, skill)
func happinessTarget(s: M.Staff) -> float: return _happinessTarget(s)
func happinessFactors(s: M.Staff) -> Dictionary: return _happinessFactors(s)
func outletHappiness() -> float: return _outletHappiness()
func rosteredOn(s: M.Staff, weekday: int) -> bool: return s.dayOff != weekday
func equipmentWorking(e: M.Equipment) -> bool: return _isWorking(e)
func maxCondition(e: M.Equipment) -> float: return _maxCondition(e)
func breakChance(e: M.Equipment) -> float: return _breakChance(e)
func equipmentResale(e: M.Equipment) -> int: return _equipmentResale(e)
func capacity(storage: String) -> int: return _capacity(storage)
func stored(storage: String) -> int: return _stored(storage)
func unitPrice(sup: String, ing: String) -> float: return _unitPrice(sup, ing)
func supplierSells(sup: String, ing: String) -> bool: return _supplierSells(sup, ing)
func orderTotal(sup: String, lines: Dictionary) -> int: return _orderTotal(sup, lines)
func suggestedOrder(sup: String) -> Dictionary: return _suggestedOrder(sup)
func expectedDailyUse(day = null) -> Dictionary: return _expectedDailyUse(loc, day)
func valuation() -> int: return _valuation()
func creditLimit() -> int: return _creditLimit()
func avgWeeklyProfit() -> int: return _avgWeeklyOpProfit()
func weeklyInstalments() -> int: return _currentInstalments()
func loanRate(secured := false, private_ := false) -> float: return _loanRate(secured, private_)
func bankChecks(amount: int, term: int, secured: bool) -> Array: return _bankChecks(amount, term, secured)
func campaignFit(type: String) -> float: return _campaignFit(type)
func fitWord(fit: float) -> String: return _fitWord(fit)
func lastCampaignDay(type: String) -> Variant: return _lastCampaignDay(type)
func priceIndex() -> float: return _priceIndexOf(loc)
func festivalOn(day: int) -> Content.Festival: return _festivalOn(day)
func stationDown(station: String) -> bool: return _stationDown(station)
func stationCapacity(station: String) -> int: return _stationCapacity(station)
func patienceLimit(g: M.Group) -> int: return _patienceLimit(g)
func dishOrderable(dishId: String) -> bool: return _dishOrderable(dishId)
func hasWorking(type: String) -> bool: return _hasWorking(type)
func eatTicks(size: int) -> int: return _eatTicks(size)
func rosteredToday(s: M.Staff) -> bool: return _rosteredToday(s)

## Text with {staff}, {equipment} … filled in.
func incidentText(inst: M.IncidentInstance, text: String) -> String: return _fill(text, inst)

## Why an option is unavailable, or null.
func optionBlocked(inst: M.IncidentInstance, o: Content.IncidentOption) -> Variant: return _optionBlocked(o, inst)

## Odds word for an option: likely / even odds / risky, from its first chance effect.
func optionOdds(o: Content.IncidentOption) -> Variant:
	for e in o.effects:
		var c = e.get("chance")
		if c is float or c is int:
			return "likely" if c >= 0.7 else ("even odds" if c >= 0.4 else "risky")
	return null

## Known cash cost of an option (negative = cost), for the cost chip.
func optionCash(inst: M.IncidentInstance, o: Content.IncidentOption) -> int:
	var sum := 0
	for e in o.effects:
		if e.get("chance") != null:
			continue
		if e.get("type") == "cash" and e.get("amount") != null:
			sum += _amount(e["amount"], inst)
		if e.get("type") == "repair":
			var eq := loc.equipmentById(inst.subjectId)
			if eq != null:
				sum -= roundi(content.equipment[eq.type].price * float(b.map("REPAIR")[e["mode"]]["cost"]))
		if e.get("type") == "replace":
			var eq := loc.equipmentById(inst.subjectId)
			if eq != null:
				sum -= roundi(content.equipment[eq.type].price * (0.5 if e.get("secondHand") == true else 1.0))
	return sum

## Ingredient that will run out today (for the prep board): id → share of the day covered.
func runOutRisks() -> Dictionary:
	var day := state.dayIndex if state.phase == "prep" else state.dayIndex + 1
	var use := _expectedDailyUse(loc, day)
	var out := {}
	for ing in use:
		var perDay: float = use[ing]
		if perDay < 1:
			continue
		var have := loc.stockOf(ing)
		for o in loc.orders:
			if o.dueDay <= day:
				have += o.lines.get(ing, 0)
		var cover := have / perDay
		if cover < 1:
			out[ing] = cover
	return out

## Roles with nobody working today.
func uncoveredRoles() -> Array:
	var out: Array = []
	var working := func(rs: Array) -> bool: return any(loc.staff, func(s): return s.workingToday and rs.has(s.role))
	if not working.call(["headChef", "lineCook"]): out.append("cook")
	for r in ["server", "cashier", "dishwasher", "cleaner"]:
		if not working.call([r]): out.append(r)
	return out

## Roles with no primary holder on a given weekday (rota coverage strip).
func uncoveredOn(weekday: int) -> Array:
	var out: Array = []
	var on := func(rs: Array) -> bool: return any(loc.staff, func(s): return rs.has(s.role) and s.dayOff != weekday)
	if not on.call(["headChef", "lineCook"]): out.append("cook")
	for r in ["server", "cashier", "dishwasher", "cleaner"]:
		if any(loc.staff, func(s): return s.role == r) and not on.call([r]): out.append(r)
	return out

var canAutoRun: bool:
	get: return uncoveredRoles().is_empty()

func saleEstimate() -> int: return _saleEstimate()
func buildCost(site: M.Site, size: String, fitOut: String, themeId: String) -> Dictionary: return _buildCost(site, size, fitOut, themeId)
func companyRating() -> float: return _companyRating()
func slack() -> float: return _slack()
var ownerAtView: bool:
	get: return not state.travelling and state.ownerLocationId == loc.id

## The shift target the doors will open with (doc 02 §8.2d).
func targetPreview() -> int:
	var fc := _forecast().groups
	var absent := count(loc.staff, func(s): return _rosteredToday(s) and not s.workingToday)
	return maxi(1, roundi(fc * (b.d("TARGET_BASE") + b.d("TARGET_PER_ABSENT") * absent)))

## The day's top causes, worst first (close report page 2).
func topCauses(t: M.DayStats, mx := 5) -> Array:
	var out: Array = []
	if t.walkTable > 0:
		out.append(M.DayEvent.mk("walkTable", "%d parties gave up waiting for a table or to be seated" % t.walkTable, t.walkTable * 60))
	if t.walkOrder > 0:
		out.append(M.DayEvent.mk("walkOrder", "%d parties left before anyone took their order" % t.walkOrder, t.walkOrder * 60))
	if t.walkFood > 0:
		out.append(M.DayEvent.mk("walkFood", "%d parties left waiting for food" % t.walkFood, t.walkFood * 70))
	if t.walkBill > 0:
		out.append(M.DayEvent.mk("walkBill", "%d parties got tired of waiting for the bill" % t.walkBill, t.walkBill * 20))
	var seen := {}
	for e in t.events:
		if e.value <= 0: continue
		if e.kind == "incident" or e.kind == "incidentResult": continue
		if e.kind == "soldOut":
			if seen.has("soldOut"): continue
			seen["soldOut"] = true
		out.append(e)
	dsort(out, func(a, c): return cmpn(c.value, a.value))
	return out.slice(0, mx)

const DAY_NAMES := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

## Short sentence for the close report.
func dayInOneLine(t: M.DayStats) -> String:
	if t.closed: return "The doors stayed shut today."
	var busy := "A"
	if t.forecast != 0:
		busy = "A busier than expected" if t.groupsArrived > t.forecast * 1.15 else ("A quiet" if t.groupsArrived < t.forecast * 0.85 else "A normal")
	var day: String = DAY_NAMES[t.dayIndex % 7]
	var lost := t.walkouts
	if lost == 0: return "%s %s. Nobody walked out." % [busy, day]
	var worst := [["waiting for a table", t.walkTable], ["waiting to order", t.walkOrder], ["waiting for food", t.walkFood], ["waiting for the bill", t.walkBill]]
	dsort(worst, func(a, c): return cmpn(c[1], a[1]))
	return "%s %s. Lost %d %s, most %s." % [busy, day, lost, "party" if lost == 1 else "parties", worst[0][0]]

## Health card gauges (doc 11 §A.7): [name, effect multiplier, value text, suggestion].
func healthGauges() -> Array:
	var l := loc
	var avgAge := 0.0
	if not l.equipment.is_empty():
		var a := 0
		for e in l.equipment: a += e.ageDays
		avgAge = float(a) / l.equipment.size()
	var creep := pow(b.d("YEARLY_COST_CREEP_WAGE"), state.dayIndex / 336)
	return [
		["Buzz", 0.90 + 0.20 * l.buzz, "%d%%" % roundi(l.buzz * 100), "Advertise, or rework the menu"],
		["Menu freshness", 0.94 + 0.10 * l.freshness, "%d%%" % roundi(l.freshness * 100), "Rework the menu or bring back a dish"],
		["Equipment age", 1.0, "%.1f yrs" % (avgAge / 336), "Replace the oldest machines"],
		["Cost pressure", 1 / creep, "×%.2f" % creep, "Raise prices about 3% a year"],
		["Rivals", 1 - 0.30 * l.competition, "%d%%" % roundi(l.competition * 100), "Stay fresh; rivals arrive when you do well"],
	]

# ================================================================ explain.dart
# "Why?" breakdowns built from the same functions the sim uses (doc 08 §4).

func _pct(m: float) -> String:
	var p := roundi((m - 1) * 100)
	return "±0%" if p == 0 else ("+%d%%" % p if p > 0 else "−%d%%" % -p)

func _signed(v: float, digits := 0) -> String:
	var s := ("%." + str(digits) + "f") % absf(v)
	return "+" + s if v >= 0 else "−" + s

func _explain(target: String, id = null) -> Explanation:
	var l := loc
	match target:
		"demand":
			var f := _demandFactors(l, state.dayIndex)
			var total := roundi(_expectedGroups(l, state.dayIndex))
			var fs: Array = []
			for k in f:
				fs.append(Factor.new(k, f[k], ("%d parties" % roundi(f[k])) if k == "Base footfall" else _pct(f[k])))
			return Explanation.new("Expected parties today", "~%d" % total, "multiply", fs,
				"A better rating, fair prices, a fresh menu and advertising bring more parties.")
		"reputation":
			var t: M.DayStats = null if l.days.is_empty() else l.days[l.days.size() - 1]
			var factors: Array = []
			if t != null and t.starsN > 0:
				factors.append(Factor.new("Yesterday's average review", t.avgStars, "%.2f stars" % t.avgStars))
				factors.append(Factor.new("Reviews counted", t.starsN, "%.0f" % t.starsN))
				factors.append(Factor.new("Walk-outs yesterday", t.walkouts, str(t.walkouts)))
			factors.append(Factor.new("Rating moves toward reviews", 0, "falls 2× faster than it rises"))
			return Explanation.new("Rating", "%.2f stars" % l.reputation, "add", factors,
				"Good food, short waits, fair prices and a clean room earn better reviews.")
		"satisfaction":
			var t: M.DayStats = l.today if l.today.starsN > 0 else (l.today if l.days.is_empty() else l.days[l.days.size() - 1])
			var q := 0.0 if t.foodTickets == 0 else t.foodQualitySum / t.foodTickets
			return Explanation.new("What customers thought", "%.1f stars" % t.avgStars, "add", [
				Factor.new("Food quality (40%)", q, "%.0f" % q),
				Factor.new("Waiting (30%)", 0, "%d walk-outs" % t.walkouts),
				Factor.new("Value for money (15%)", _priceIndexOf(l), "prices %s vs normal" % _pct(_priceIndexOf(l))),
				Factor.new("Cleanliness (15%)", l.hygiene, "%.0f" % l.hygiene),
				Factor.new("Dishes not available", t.unavailable, "−10 per missing dish (%d)" % t.unavailable),
			])
		"profit":
			var t: M.DayStats = l.days[l.days.size() - 1] if (state.phase == "prep" and not l.days.is_empty()) else l.today
			var fs: Array = [
				Factor.new("Sales", t.revenue, "+" + money(t.revenue)),
				Factor.new("Ingredients bought", -t.ingredientSpend, "−" + money(t.ingredientSpend)),
				Factor.new("Wages (paid Sundays)", -t.wages, "−" + money(t.wages)),
				Factor.new("Rent (paid Sundays)", -t.rent, "−" + money(t.rent)),
				Factor.new("Utilities (paid monthly)", -t.utilities, "−" + money(t.utilities)),
			]
			if t.upkeep > 0: fs.append(Factor.new("Repairs and equipment", -t.upkeep, "−" + money(t.upkeep)))
			if t.marketing > 0: fs.append(Factor.new("Marketing", -t.marketing, "−" + money(t.marketing)))
			if t.other != 0: fs.append(Factor.new("Other (situations, fines, tax)", -t.other, _signed(-t.other)))
			return Explanation.new("Profit for %s" % dateLabel(t.dayIndex), money(t.profit), "coins", fs)
		"cash":
			var owed := state.wagesOwed
			var bills := 0
			for p in l.payables: bills += p.amount
			return Explanation.new("Cash in hand", money(state.cash), "coins", [
				Factor.new("Cash now", state.cash, money(state.cash)),
				Factor.new("Wages owed on Sunday", -owed, "−" + money(owed)),
				Factor.new("Rent due on Sunday", -l.rentWeekly, "−" + money(l.rentWeekly)),
				Factor.new("Loan payments on Sunday", -_currentInstalments(), "−" + money(_currentInstalments())),
				Factor.new("Supplier bills unpaid", -bills, "−" + money(bills)),
				Factor.new("Utilities this month so far", -state.monthUtilities, "−" + money(state.monthUtilities)),
			], "Profit is not cash: wages, rent and loan payments all leave on Sunday.")
		"staffHappiness":
			var s := l.staffById(id)
			if s == null: return Explanation.new("Happiness", "-", "add", [])
			var hf := _happinessFactors(s)
			var f: Array = []
			for k in hf: f.append([k, hf[k]])
			dsort(f, func(a, c): return cmpn(a[1], c[1]))
			var fs: Array = [Factor.new("Starting point", 50, "50")]
			for e in f: fs.append(Factor.new(e[0], e[1], _signed(e[1])))
			fs.append(Factor.new("Heading toward", _happinessTarget(s), str(roundi(_happinessTarget(s)))))
			return Explanation.new("%s's happiness" % s.name, str(roundi(s.morale)), "add", fs)
		"hygiene":
			var cleaners := count(l.staff, func(s): return s.role == "cleaner")
			var fs: Array = [
				Factor.new("Dirt from customers", -0.15, "−0.15 per party served"),
				Factor.new("Cleaners", cleaners, "none — the dishwasher cleans at half effect" if cleaners == 0 else "%d cleaning each night" % cleaners),
			]
			if not _hasWorking("eq_hood"): fs.append(Factor.new("Exhaust hood broken", -5, "−5 a day"))
			if lf("pests"): fs.append(Factor.new("Pests", -8, "−8 a day"))
			if lf("leak"): fs.append(Factor.new("Leak", -10, "−10 a day"))
			fs.append(Factor.new("Inspection", 80, "pass at 80+, fine at 50–79, closure below 50"))
			return Explanation.new("Cleanliness", str(roundi(l.hygiene)), "add", fs)
		"energy":
			return Explanation.new("Your energy", str(roundi(state.owner.energy)), "add", [
				Factor.new("Working a job", -b.d("OWNER_ENERGY_PER_TICK"), "−%s per tick" % str(b.d("OWNER_ENERGY_PER_TICK"))),
				Factor.new("Standing at Dishes", 0, "counts as working every tick"),
				Factor.new("Overnight sleep", b.d("OWNER_RECOVERY"), "+%d" % roundi(b.d("OWNER_RECOVERY"))),
				Factor.new("Below 20", 0, "mistakes: wrong orders, short bills"),
				Factor.new("At 0 three nights running", 0, "a forced day off"),
			])
		"dish":
			var dishId: String = l.menu.keys()[0 if id == null else id]
			var d: Content.Dish = content.dishes[dishId]
			var m: M.MenuItem = l.menu[dishId]
			var cost := 0.0
			for r in d.recipe: cost += r.qty * _unitPrice("sup_standard", r.ingredientId)
			var fs: Array = []
			for r in d.recipe:
				var c: float = r.qty * _unitPrice("sup_standard", r.ingredientId)
				fs.append(Factor.new("%s ×%d" % [content.ingredients[r.ingredientId].name, r.qty], -c, "−%.2f" % c))
			fs.append(Factor.new("Profit per dish", m.price - cost, "%.2f" % (m.price - cost)))
			fs.append(Factor.new("Food cost", cost / m.price, "%d%%" % roundi(cost / m.price * 100)))
			return Explanation.new(d.name, money(m.price), "coins", fs)
		"valuation":
			var resale := 0
			for e in l.equipment: resale += _equipmentResale(e)
			return Explanation.new("Company value", money(_valuation()), "coins", [
				Factor.new("Cash", state.cash, money(state.cash)),
				Factor.new("Equipment if sold", resale, money(resale)),
				Factor.new("Profit power (40 weeks of avg profit)", 40.0 * maxi(0, _avgWeeklyOpProfit()), money(b.i("VALUATION_PROFIT_MULT") * maxi(0, _avgWeeklyOpProfit()))),
				Factor.new("Name and rating", b.d("VALUATION_PER_STAR") * l.reputation, money(b.d("VALUATION_PER_STAR") * l.reputation)),
				Factor.new("Debts", -state.totalOutstanding, "−" + money(state.totalOutstanding)),
			])
	return Explanation.new(target, "-", "add", [])

# ================================================================ service.dart
# Service: tick loop, group state machine, tasks, kitchen, owner (doc 02 §3.2, §6, §8).

const taskRoles := {
	"pack": ["cashier", "server"], "seat": ["cashier", "server"], "takeOrder": ["server"],
	"cook": ["headChef", "lineCook"], "deliver": ["server"], "bill": ["cashier", "server"], "clear": ["server", "cleaner"],
}
const standInRoles := {
	"pack": ["server"], "seat": ["server"], "bill": ["server"], "takeOrder": ["cashier"],
	"deliver": ["cashier"], "clear": ["cashier"], "cook": ["prepCook"],
}
const assignOrder := ["bill", "deliver", "pack", "takeOrder", "seat", "cook", "clear"]
const areaTasks := {"door": ["seat", "bill"], "tables": ["takeOrder", "clear"], "pass": ["deliver"], "dishes": []}
const areaNames := {"door": "Door & till", "tables": "Tables", "pass": "Pass", "dishes": "Dishes"}

class Worker:
	var s: M.Staff
	var role: String
	func _init(st: M.Staff, r: String) -> void:
		s = st; role = r

var ss: M.ServiceState:
	get: return loc.service

func _ssid() -> int:
	var s = loc.service
	s.nextId += 1
	return s.nextId - 1

# ---------------------------------------------------------- start

func _startService() -> void:
	var l := loc
	var fc := _forecast()
	var mult := b.d("DEMAND_NOISE_MIN") + b.d("DEMAND_NOISE_SPAN") * _rng.next_float()
	var groups := roundi(_expectedGroups(l, state.dayIndex) * mult)
	var service := M.ServiceState.new()
	for i in l.tableSeats.size():
		service.tables.append(M.TableRt.mk(i + 1, l.tableSeats[i]))
	service.favours = b.i("FAVOURS_MAX")
	service.ownerArea = state.owner.startArea if _ownerPresent else null
	service.forecast = fc.groups
	l.service = service
	var film := lf("film_crew_today")
	if film:
		service.seatingStartTick = b.i("FILM_CREW_TICKS")
	service.arrivals = _rollArrivals(l, groups)
	# Takeaway and delivery orders (doc 11 §C.1, format 3).
	if l.deliveryOn:
		var n := roundi(groups * b.d("DELIVERY_SHARE"))
		var orders := _rollArrivals(l, n)
		for a in orders:
			a.delivery = true
			a.size = 2 if a.size > 2 else a.size
		service.arrivals.append_array(orders)
		dsort(service.arrivals, func(a, c): return cmpn(a.tick, c.tick))
	if film:
		for a in service.arrivals:
			if a.tick < service.seatingStartTick:
				a.tick = service.seatingStartTick + _rng.next_int(0, 20)
		dsort(service.arrivals, func(a, c): return cmpn(a.tick, c.tick))
	if lf("big_booking_today"):
		var bt := 8 * b.i("TICKS_PER_HOUR")
		for i in 3:
			service.arrivals.append(M.Arrival.mk(bt, 4, "family"))
		dsort(service.arrivals, func(a, c): return cmpn(a.tick, c.tick))
		state.flags.erase("%d:big_booking_today" % loc.id)
	if lf("critic_next"):
		var later: Array = service.arrivals.filter(func(a): return a.tick > 60)
		if not later.is_empty():
			_rng.pick(later).critic = true
		state.flags.erase("%d:critic_next" % loc.id)
	# Shift target (doc 02 §8.2d).
	var rostered := count(l.staff, func(s): return _rosteredToday(s))
	var absent := count(l.staff, func(s): return _rosteredToday(s) and not s.workingToday)
	service.target = maxi(1, roundi(fc.groups * (b.d("TARGET_BASE") + b.d("TARGET_PER_ABSENT") * absent)))
	if rostered == 0:
		service.target = fc.groups
	loc.today.forecast = fc.groups
	loc.today.target = service.target
	# A breakdown during service (doc 02 §10.1), rolled once.
	var stations: Array = l.equipment.filter(func(e): return _isWorking(e) and content.equipment[e.type].kind == "station")
	for e in stations:
		if _rng.chance(_breakChance(e) / 3):
			service.breakdownTick = _rng.next_int(60, 300)
			service.breakdownEqId = e.id
			break
	emit("serviceStarted", {"groups": groups, "target": service.target, "locationId": l.id})

## Opens every outlet at once (doc 02 §15.1).
func _startServiceAll() -> void:
	state.phase = "service"
	for l in state.openLocations:
		at(l, func():
			var noBoss: bool = state.ownerLocationId != l.id and l.manager == null
			var building: bool = l.openDay > state.dayIndex
			if l.closedUntil > state.dayIndex or building or noBoss:
				l.today.closed = true
				if building:
					l.today.add("building", "Still being fitted out: opens on day %d" % (l.openDay + 1), 0)
				elif noBoss:
					l.today.add("closed", "Nobody to run it today: it needs you or a manager", 500)
				else:
					l.today.add("closed", "The restaurant was closed today", 500)
				var sv := M.ServiceState.new()
				sv.done = true
				sv.forecast = 0
				l.service = sv
			else:
				_startService())
	_maybeCloseAll()

## One tick at every outlet, in id order (lockstep).
func _serviceTickAll() -> void:
	_travelTick()
	for l in state.openLocations:
		var s: M.ServiceState = l.service
		if s == null or s.done:
			continue
		at(l, func():
			if _ownerPresent:
				l.ownerTicksToday += 1
			_serviceTick())
		if state.phase == "gameOver":
			return
	_maybeCloseAll()

func _maybeCloseAll() -> void:
	if state.phase != "service":
		return
	if every(state.openLocations, func(l): return l.service == null or l.service.done):
		state.phase = "close"
		emit("serviceEnded")
		_closeAll()

# ---------------------------------------------------------- helpers

func _isWorking(e: M.Equipment) -> bool:
	return not e.broken and e.unavailableUntil <= state.dayIndex

func _hasWorking(type: String) -> bool:
	return any(loc.equipment, func(e): return e.type == type and _isWorking(e))

func _workers() -> Array:
	var out: Array = []
	var t: int = loc.service.tick if loc.service != null else 0
	var boss: Worker = null
	for s in loc.staff:
		if not s.workingToday: continue
		if s.lateTick > t: continue
		var mv = loc.service.moves.get(str(s.id)) if loc.service != null else null
		var w := Worker.new(s, mv if mv != null else ("cashier" if s.isManager else s.role))
		if s.isManager and mv == null:
			boss = w
		out.append(w)
	# The manager fills in for one uncovered role; the till falls back to the servers (doc 02 §15.15).
	if boss != null:
		for need in [["lineCook", "headChef"], ["server"], ["dishwasher"]]:
			var covered := any(out, func(w): return w != boss and need.has(w.role))
			if not covered and (need[0] != "dishwasher" or any(loc.staff, func(s): return s.role == "dishwasher")):
				out[out.find(boss)] = Worker.new(boss.s, need[0])
				break
	return out

## The owner's boost in full; a manager's scaled by their skill.
func _zoneBoost(full: float) -> float:
	if _ownerPresent: return full
	var m := loc.manager
	if m == null or not m.workingToday: return 1.0
	return 1 - (1 - full) * b.d("MANAGER_ZONE_SHARE") * m.managerSkill / 100

## The manager moves to wherever most jobs are waiting.
func _managerStands() -> void:
	var m := loc.manager
	if m == null or not m.workingToday:
		ss.ownerArea = null
		return
	var counts := {"door": 0, "tables": 0, "pass": 0}
	for k in ss.tasks:
		if k.started: continue
		for a in counts.keys():
			if areaTasks[a].has(k.type): counts[a] += 1
		if k.type == "cook": counts["pass"] += 1
	var best_k := "door"
	var best_v := -1
	for a in counts:
		if best_v < 0 or counts[a] > best_v:
			best_k = a
			best_v = counts[a]
	ss.ownerArea = "door" if best_v == 0 else best_k

## A central kitchen does the prep: cooking is faster at every outlet (doc 11 §C.1).
var _ckMult: float:
	get: return b.d("CENTRAL_KITCHEN_PREP_MULT") if state.centralKitchen else 1.0

func _stationOff(station: String) -> bool:
	var s = loc.service
	return s != null and s.stationOffUntil.get(station, -1) > s.tick

func _stationCapacity(station: String) -> int:
	if _stationOff(station): return 0
	if station == "cold": return b.i("COLD_SLOTS")
	var n := 0
	for e in loc.equipment:
		var t: Content.EquipmentType = content.equipment[e.type]
		if t.station == station and _isWorking(e): n += t.slots
	return n

func _stationDown(station: String) -> bool:
	if _stationOff(station): return true
	if station == "cold": return false
	var n := 0
	for e in loc.equipment:
		var t: Content.EquipmentType = content.equipment[e.type]
		if t.station == station and _isWorking(e): n += t.slots
	return n == 0

## Dishes a customer can order right now.
func _dishOrderable(dishId: String) -> bool:
	var m: M.MenuItem = loc.menu.get(dishId)
	if m == null or not m.enabled: return false
	if loc.service != null and loc.service.eightySix.has(dishId): return false
	var d: Content.Dish = content.dishes[dishId]
	if _stationDown(d.station): return false
	for r in d.recipe:
		if loc.stockOf(r.ingredientId) < r.qty: return false
	return true

func _patienceLimit(g: M.Group) -> int:
	var base: float = b.dmap("PATIENCE").get(g.state, 10.0)
	var env := 1.0
	if state.season == "summer" and not _hasWorking("eq_ac"):
		env *= b.d("AC_BROKEN_PATIENCE")
	if ss.patienceUntil > ss.tick:
		env *= ss.patienceMult
	var seg: Dictionary = b.map("SEGMENTS")[g.segment]
	var limit := base * float(seg["patienceMult"]) * diff("DIFF_PATIENCE") * env + (b.i("TREAT_PATIENCE") if g.treated else 0)
	return roundi(limit)

func _hasTask(type: String, groupId = null, tableId = null, ticketId = null) -> bool:
	for t in ss.tasks:
		if t.type != type: continue
		if groupId != null and t.groupId != groupId: continue
		if tableId != null and t.tableId != tableId: continue
		if ticketId != null and t.ticketId != ticketId: continue
		return true
	return false

func _newTask(type: String, groupId = null, tableId = null, ticketId = null) -> M.Task:
	var t := M.Task.new()
	t.id = _ssid(); t.type = type; t.groupId = groupId; t.tableId = tableId; t.ticketId = ticketId; t.created = ss.tick
	ss.tasks.append(t)
	return t

func _fittingTable(size: int) -> M.TableRt:
	var best: M.TableRt = null
	for t in ss.tables:
		if t.state != "free" or t.reserved: continue
		if t.seats < maxi(2, size): continue
		if best == null or t.seats < best.seats: best = t
	return best

func _eatTicks(size: int) -> int:
	return mini(b.i("EAT_TICKS_MAX"), b.i("EAT_TICKS_BASE") + b.i("EAT_TICKS_PER_PERSON") * size)

func _effectiveSkill(w: Worker, taskType: String, standIn := false) -> float:
	var sk := w.s.skill
	if w.s.isManager:
		# At the till they work at their own level; filling in, at 50 (doc 02 §15.15).
		sk = w.s.managerSkill if w.role == "cashier" else 50.0
	elif w.role != w.s.role:
		sk -= b.d("OFF_ROLE_PENALTY")
	if standIn: sk -= b.d("STAND_IN_SKILL_PENALTY")
	# Mentor in the same role.
	for o in loc.staff:
		if o.id != w.s.id and o.workingToday and o.role == w.s.role and o.hasTrait("trait_mentor"):
			sk += 3
			break
	if taskType == "cook" and w.s.role == "lineCook" and any(loc.staff, func(o): return o.role == "headChef" and o.workingToday):
		sk += b.d("HEAD_CHEF_LINE_BONUS")
	return clampf(sk, 0, 100)

func _duration(type: String, base: float, skill: float, fatigue := 0.0, morale := 50.0, standIn := false, fallback := false, who: M.Staff = null) -> int:
	var d := base * (b.d("STAND_IN_TIME_MULT") if (standIn or fallback) else 1.0) * (1.5 - skill / 100)
	d *= 1 + maxf(0, fatigue - 60) / 100
	if who != null:
		d *= 1 + (50 - morale) / 500
		d *= 1 + _slack()
		if who.hasTrait("trait_perfectionist"): d *= 1.1
		d *= ss.roleSlow.get(who.role, 1.0)
	var area = ss.ownerArea
	if area != null and areaTasks.has(area) and areaTasks[area].has(type) and who != null:
		d *= _zoneBoost(b.d("ZONE_BOOST"))
	if type == "cook":
		var prep := count(loc.staff, func(s): return s.role == "prepCook" and s.workingToday)
		d *= 1 - b.d("PREP_BONUS") * mini(2, prep)
		if themeOfLoc.isMixed: d *= b.d("MIXED_COOK_MULT")
		if not _hasWorking("eq_hood"): d *= b.d("HOOD_BROKEN_COOK_MULT")
		if area == "pass" and who != null:
			d *= _zoneBoost(b.d("PASS_COOK_BOOST"))
	if type == "bill":
		if not _hasWorking("eq_pos"): d *= 2
		if ss.billMultUntil > ss.tick: d *= ss.billMult
	return maxi(1, roundi(d))

# ---------------------------------------------------------- tick

func _serviceTick() -> void:
	var l := loc
	var s := ss
	if s.done: return
	var t := s.tick
	var today := loc.today
	# 1. Arrivals.
	while not s.arrivals.is_empty() and s.arrivals[0].tick <= t:
		var a: M.Arrival = s.arrivals.pop_front()
		var g := M.Group.new()
		g.id = _ssid(); g.size = a.size; g.segment = a.segment; g.arriveTick = t; g.critic = a.critic
		s.groups.append(g)
		if a.delivery:
			# A delivery order goes straight to the kitchen; no table, no waiter.
			g.delivery = true
			g.state = "waitFood"
			g.totalLimit = _patienceLimit(g)
			_takeOrder(g)
			continue
		g.totalLimit = _patienceLimit(g)
		today.groupsArrived += 1
		if s.noSeatUntil > t:
			_walkOut(g, "closed")
			continue
		emit("groupArrived", {"groupId": g.id, "size": g.size})
	# 2. Waiting and walk-outs.
	for g in s.groups:
		if not g.waiting: continue
		if g.state == "waitTable":
			if g.seatTaskOpen: continue
			if _fittingTable(g.size) != null and s.noSeatUntil <= t: continue
		g.counter += 1
		g.totalWait += 1
		if g.counter > _patienceLimit(g):
			_walkOut(g, g.state)
	# 3. Complete tasks.
	var finishing: Array = s.tasks.filter(func(k): return k.started and k.endTick <= t)
	for k in finishing:
		s.tasks.erase(k)
		_completeTask(k)
	# Eating → waiting for the bill.
	for g in s.groups:
		if g.state == "eating" and t >= g.eatUntil:
			g.state = "waitBill"
			g.counter = 0
			g.totalLimit += _patienceLimit(g)
	# A scheduled breakdown.
	if t == s.breakdownTick:
		var e := l.equipmentById(s.breakdownEqId)
		if e != null and _isWorking(e):
			_raiseIncident("inc_fryer_dies_service", e.id, null, true)
	# A manager leads the floor where the owner is not (doc 02 §15.15, balance-log 17).
	if not _ownerPresent and t % 15 == 0:
		_managerStands()
	_generateTasks()
	_assign()
	_wash()
	_ownerUpkeep()
	# 7. Service incidents every 30 ticks.
	if t > 0 and t % b.i("SERVICE_INCIDENT_EVERY") == 0:
		_rollIncidents("service")
	# 8. Incident countdowns.
	for inc in state.openIncidents:
		if inc.locationId != l.id: continue
		if inc.countdown > 0:
			inc.countdown -= 1
			if inc.countdown == 0:
				_resolveIncident(inc, _ignoredChoice(inc), true)
	# Rush tracking for fatigue (doc 02 §7.2).
	var waitingByRole := {}
	for k in s.tasks:
		if k.started: continue
		for r in taskRoles.get(k.type, []):
			waitingByRole[r] = waitingByRole.get(r, 0) + 1
	for r in waitingByRole:
		if waitingByRole[r] > 5:
			s.rushRoles[r] = true
	# 9. End of service.
	var present := any(s.groups, func(g): return not g.gone)
	if (t >= b.i("SERVICE_TICKS") and not present and s.arrivals.is_empty()) or t >= b.i("SERVICE_TICKS") + b.i("OVERTIME_TICKS_MAX"):
		_finishService()
		return
	s.tick += 1

func _generateTasks() -> void:
	var s := ss
	var t := s.tick
	# Seat, in arrival order.
	if s.noSeatUntil <= t and t >= s.seatingStartTick:
		for g in s.groups:
			if g.state != "waitTable" or g.seatTaskOpen: continue
			var table := _fittingTable(g.size)
			if table == null: continue
			table.reserved = true
			g.seatTaskOpen = true
			g.tableId = table.id
			_newTask("seat", g.id, table.id)
	for g in s.groups:
		match g.state:
			"waitOrder":
				if not _hasTask("takeOrder", g.id):
					_newTask("takeOrder", g.id, g.tableId)
			"waitFood":
				var live: Array = []
				for id in g.ticketIds:
					var k := s.ticket(id)
					if k != null and k.state != "cancel": live.append(k)
				if live.is_empty():
					# Everything they ordered became unavailable.
					_walkOut(g, "waitFood")
					continue
				var handOff := "pack" if g.delivery else "deliver"
				if every(live, func(k): return k.state == "ready") and not _hasTask(handOff, g.id):
					_newTask(handOff, g.id, g.tableId)
				for k in live:
					if k.state == "wait" and not _hasTask("cook", null, null, k.id):
						_newTask("cook", g.id, null, k.id)
			"waitBill":
				if not _hasTask("bill", g.id):
					_newTask("bill", g.id, g.tableId)
	for tb in s.tables:
		if tb.state == "dirty" and not _hasTask("clear", null, tb.id):
			_newTask("clear", null, tb.id)

func _ownerBusy() -> bool:
	var s := ss
	if s.ownerBusyUntil > s.tick: return true
	return any(s.tasks, func(k): return k.assignee == "owner")

var _ownerPresent: bool:
	get: return not state.owner.restingToday and not state.travelling and state.ownerLocationId == loc.id

func _assign() -> void:
	var s := ss
	var workers := _workers()
	var busy := {} # staff id → active task count
	for k in s.tasks:
		if k.assignee != null and k.assignee != "owner":
			var id := int(k.assignee)
			busy[id] = busy.get(id, 0) + 1
	var cookParallel := b.i("COOK_PARALLEL")
	var idle := func(w: Worker) -> bool:
		var n: int = busy.get(w.s.id, 0)
		if w.role == "headChef" or w.role == "lineCook": return n < cookParallel
		return n == 0
	var stationUse := {}
	for k in s.tasks:
		if k.type == "cook" and k.started:
			var st: String = content.dishes[s.ticket(k.ticketId).dishId].station
			stationUse[st] = stationUse.get(st, 0) + 1
	var platesFull: bool = s.dirtyDishes > b.i("PLATES_PER_TABLE") * s.tables.size()
	if platesFull:
		s.platesFullTicks += 1
		if s.platesFullTicks == 1:
			emit("platesFull")
			_note("platesFull", "Ran out of clean plates: the kitchen had to stop", 0)
	var kitchenBacklog := count(s.tasks, func(k): return k.type == "cook" and not k.started)
	var cooksWorking := count(workers, func(w): return w.role == "headChef" or w.role == "lineCook")
	var waiting := func(type: String) -> Array:
		var list: Array = s.tasks.filter(func(k): return k.type == type and not k.started and not k.reserved)
		if type == "cook":
			dsort(list, func(a, c):
				var pa: int = s.ticket(a.ticketId).priority
				var pc: int = s.ticket(c.ticketId).priority
				if pa != pc: return cmpn(pa, pc)
				return cmpn(a.id, c.id))
		return list
	var cookAllowed := func(k: M.Task) -> bool:
		if platesFull: return false
		var st: String = content.dishes[s.ticket(k.ticketId).dishId].station
		return stationUse.get(st, 0) < _stationCapacity(st)
	var start := func(k: M.Task, assignee: String, dur: int) -> void:
		k.assignee = assignee
		k.startTick = s.tick
		k.endTick = s.tick + dur
		if k.type == "cook":
			var st: String = content.dishes[s.ticket(k.ticketId).dishId].station
			stationUse[st] = stationUse.get(st, 0) + 1
	var startStaff := func(k: M.Task, w: Worker, standIn := false, fallback := false) -> bool:
		if k.type == "cook":
			if not cookAllowed.call(k): return false
			if not _beginCook(k, _effectiveSkill(w, "cook", standIn), kitchenBacklog > 2 * maxi(1, cooksWorking), w.s):
				return true # ticket cancelled; task consumed
		var base: float = (content.dishes[s.ticket(k.ticketId).dishId].prepTicks * _ckMult) if k.type == "cook" else b.dmap("TASK_TICKS")[k.type]
		var sk := _effectiveSkill(w, k.type, standIn)
		var dur := _duration(k.type, base, sk, w.s.fatigue, w.s.morale, standIn, fallback, w.s)
		if w.s.hasTrait("trait_clumsy") and _rng.chance(0.01): dur += 3
		start.call(k, str(w.s.id), dur)
		busy[w.s.id] = busy.get(w.s.id, 0) + 1
		return true
	# Primary roles.
	for type in assignOrder:
		var roleList: Array = taskRoles[type]
		for k in waiting.call(type):
			if type == "cook" and not cookAllowed.call(k): continue
			var pick: Worker = null
			var fallback := false
			var ri := 0
			while ri < roleList.size() and pick == null:
				var cands: Array = workers.filter(func(w): return w.role == roleList[ri] and idle.call(w))
				if cands.is_empty():
					ri += 1
					continue
				dsort(cands, func(a, c):
					if type == "cook":
						var na: int = busy.get(a.s.id, 0)
						var nc: int = busy.get(c.s.id, 0)
						if na != nc: return cmpn(na, nc)
					var sk := cmpn(c.s.skill, a.s.skill)
					return sk if sk != 0 else cmpn(a.s.id, c.s.id))
				pick = cands[0]
				fallback = type == "bill" and roleList[ri] == "server"
				ri += 1
			if pick == null: continue
			startStaff.call(k, pick, false, fallback)
	# Owner: reserved queue first, then their area's jobs.
	if _ownerPresent and not _ownerBusy():
		var next: M.Task = null
		while not s.ownerQueue.is_empty() and next == null:
			var cand := s.task(s.ownerQueue[0])
			if cand == null or cand.started:
				s.ownerQueue.remove_at(0)
				continue
			if cand.type == "cook" and not cookAllowed.call(cand): break
			next = cand
			s.ownerQueue.remove_at(0)
		if next == null and s.ownerArea != null:
			var types: Array = areaTasks[s.ownerArea].duplicate()
			if s.ownerArea == "pass" and cooksWorking == 0: types.append("cook")
			var oldest: M.Task = null
			for k in s.tasks:
				if k.started or k.reserved or not types.has(k.type): continue
				if k.type == "cook" and not cookAllowed.call(k): continue
				if oldest == null or k.id < oldest.id: oldest = k
			next = oldest
		if next != null:
			var ownerSkill: float = b.dmap("OWNER_SKILL").get(next.type, 60.0)
			if next.type == "cook":
				if _beginCook(next, ownerSkill, false, null):
					var base := float(content.dishes[s.ticket(next.ticketId).dishId].prepTicks)
					start.call(next, "owner", _duration("cook", base, ownerSkill) + b.i("OWNER_WALK_TICKS"))
			else:
				var base: float = b.dmap("TASK_TICKS")[next.type]
				start.call(next, "owner", _duration(next.type, base, ownerSkill) + b.i("OWNER_WALK_TICKS"))
			next.reserved = false
	# Stand-ins: only for roles with nobody working, and only when idle in their own job.
	for type in assignOrder:
		var primary: Array = taskRoles[type]
		if any(workers, func(w): return primary.has(w.role) and not (type == "bill" and w.role == "server")):
			continue
		var standIns: Array = standInRoles[type]
		for k in waiting.call(type):
			if type == "cook" and not cookAllowed.call(k): continue
			var cands: Array = workers.filter(func(w):
				if not (standIns.has(w.role) and idle.call(w)): return false
				# Their own tasks come first.
				for ot in assignOrder:
					if taskRoles[ot].has(w.role) and any(s.tasks, func(x): return x.type == ot and not x.started):
						return false
				return true)
			if cands.is_empty(): break
			dsort(cands, func(a, c): return cmpn(c.s.skill, a.s.skill))
			startStaff.call(k, cands[0], true)

## Consumes ingredients and sets quality. Returns false if the ticket had to be cancelled.
func _beginCook(k: M.Task, skill: float, backlog: bool, who: M.Staff) -> bool:
	var s := ss
	var ticket := s.ticket(k.ticketId)
	var dish: Content.Dish = content.dishes[ticket.dishId]
	for r in dish.recipe:
		if loc.stockOf(r.ingredientId) < r.qty:
			ticket.state = "cancel"
			s.tasks.erase(k)
			var g := s.group(ticket.groupId)
			if g != null: g.unavailable += 1
			loc.today.unavailable += 1
			if loc.menu.has(dish.id): loc.menu[dish.id].unavailableToday += 1
			if not s.eightySix.has(dish.id):
				s.eightySix[dish.id] = true
				emit("dishUnavailable", {"dishId": dish.id})
				_note("soldOut", "%s sold out at %s" % [dish.name, _clock(s.tick)], 1)
			return false
	var acc := [0.0, 0, false] # quality sum, count, stale
	var cost := _consumeRecipe(dish, func(q, daysLeft):
		acc[0] += q
		acc[1] += 1
		if daysLeft <= 1: acc[2] = true)
	loc.today.ingredientsUsedCost += cost
	var ingQ: float = 60.0 if acc[1] == 0 else acc[0] / acc[1]
	var req := dish.skillReq - (b.i("CENTRAL_KITCHEN_SKILL") if state.centralKitchen else 0)
	var effSkill := skill - 15 if skill < req else skill
	var stationCond := 100.0
	if dish.station != "cold":
		var first := true
		for e in loc.equipment:
			if content.equipment[e.type].station == dish.station and _isWorking(e):
				stationCond = e.condition if first else maxf(stationCond, e.condition)
				first = false
	var q := 0.40 * ingQ + 0.40 * effSkill + 0.20 * stationCond
	if backlog: q -= 10
	if acc[2] and not _hasWorking("eq_fridge"): q -= 15
	if who != null and who.hasTrait("trait_perfectionist"): q += 5
	ticket.quality = clampf(q, 0, 100)
	ticket.state = "cook"
	if ticket.quality < 20 and _rng.chance(b.d("FOOD_POISON_CHANCE")):
		var g := s.group(ticket.groupId)
		if g != null: g.ill = true
	return true

func _completeTask(k: M.Task) -> void:
	var s := ss
	var g := s.group(k.groupId)
	var byOwner: bool = k.assignee == "owner"
	var mistake := false
	if byOwner:
		loc.today.ownerTasks += 1
		if state.owner.energy < b.d("OWNER_LOW_ENERGY") and _rng.chance(b.d("OWNER_MISTAKE_CHANCE")):
			mistake = true
	match k.type:
		"seat":
			var table := s.table(k.tableId)
			table.reserved = false
			if g == null or g.state != "waitTable": return
			table.state = "occupied"
			table.groupId = g.id
			g.seatTaskOpen = false
			g.state = "waitOrder"
			g.counter = 0
			g.totalLimit += _patienceLimit(g)
			loc.today.groupsSeated += 1
			emit("groupSeated", {"groupId": g.id, "tableId": table.id})
		"takeOrder":
			if g == null or g.state != "waitOrder": return
			_takeOrder(g)
			if mistake: g.unavailable += 1
			g.state = "waitFood"
			g.counter = 0
			g.totalLimit += _patienceLimit(g)
		"cook":
			var ticket := s.ticket(k.ticketId)
			if ticket.state == "cook":
				ticket.state = "ready"
				if mistake: ticket.quality = maxf(0, ticket.quality - 30)
				emit("dishReady", {"ticketId": ticket.id})
		"deliver":
			if g == null or g.state != "waitFood": return
			if mistake: g.unavailable += 1
			g.state = "eating"
			g.foodDelivered = true
			g.eatUntil = s.tick + _eatTicks(g.size)
			emit("foodDelivered", {"groupId": g.id})
		"bill":
			if g == null or g.state != "waitBill": return
			_pay(g, false, mistake)
		"pack":
			if g == null or g.state != "waitFood": return
			g.foodDelivered = true
			_pay(g, false, mistake)
		"clear":
			var table := s.table(k.tableId)
			table.state = "free"
			var last: M.Group = null
			for x in s.groups:
				if x.tableId == table.id: last = x
			s.dirtyDishes += (last.size if last != null else 2) * 2
			table.groupId = null

func _takeOrder(g: M.Group) -> void:
	var s := ss
	var seg: Dictionary = b.map("SEGMENTS")[g.segment]
	var spend_m := float(seg["spendMult"])
	var sens := float(seg["priceSensitivity"])
	var chance := b.dmap("COURSE_CHANCE")
	var choose := func(course: String) -> Variant:
		var cands: Array = []
		var w: Array = []
		for m in loc.menu.values():
			var d: Content.Dish = content.dishes[m.dishId]
			if d.courseGroup != course or not _dishOrderable(d.id): continue
			var price := float(m.price)
			if _promoActive(loc): price *= 0.75
			var appeal := clampf(1.6 - 0.6 * (price / (d.basePrice * _referencePriceMult())) * sens, 0.2, 1.4)
			cands.append(d)
			w.append(d.popularity * appeal)
		if cands.is_empty(): return null
		return _rng.weighted(cands, w).id
	var ordered: Array = []
	for p in g.size:
		var main = choose.call("main")
		if main == null:
			g.unavailable += 1
			loc.today.unavailable += 1
		else:
			ordered.append(main)
		for c in ["starter", "side", "sweet"]:
			if _rng.chance(minf(0.95, chance[c] * spend_m)):
				var d = choose.call(c)
				if d != null: ordered.append(d)
	for d in ordered:
		var tk := M.Ticket.mk(_ssid(), g.id, d)
		s.tickets.append(tk)
		g.ticketIds.append(tk.id)

func _satisfaction(g: M.Group, waitZero: bool) -> float:
	var s := ss
	var delivered: Array = []
	for id in g.ticketIds:
		var k := s.ticket(id)
		if k != null and k.state == "ready": delivered.append(k)
	var food := 0.0
	if not delivered.is_empty():
		var a := 0.0
		for k in delivered: a += k.quality
		food = a / delivered.size()
	var wait := 0.0 if (waitZero or g.totalLimit == 0) else clampf(100 * (1 - float(g.totalWait) / g.totalLimit), 0, 100)
	var seg: Dictionary = b.map("SEGMENTS")[g.segment]
	var sens := float(seg["priceSensitivity"])
	var pi := 1.0
	if not delivered.is_empty():
		var sum := 0.0
		for k in delivered:
			var d: Content.Dish = content.dishes[k.dishId]
			sum += loc.menu[d.id].price / (d.basePrice * _referencePriceMult())
		pi = sum / delivered.size()
		if _promoActive(loc): pi *= 0.75
	var value := clampf(75 - 100 * (pi - 1) * sens, 0, 100)
	var clean := loc.hygiene
	var sat := 0.40 * food + 0.30 * wait + 0.15 * value + 0.15 * clean - 10 * g.unavailable + g.satAdj
	if g.broughtBill: sat -= b.d("BRING_BILL_SAT")
	return clampf(sat, 0, 100)

func _pay(g: M.Group, waitScoreZero: bool, mistake := false) -> void:
	if g.delivery:
		_payDelivery(g)
		return
	var s := ss
	var payment := 0
	for id in g.ticketIds:
		var k := s.ticket(id)
		if k == null or k.state != "ready": continue
		var p := float(loc.menu[k.dishId].price)
		if _promoActive(loc): p *= 0.75
		payment += roundi(p)
		loc.menu[k.dishId].soldToday += 1
		loc.today.foodQualitySum += k.quality
		loc.today.foodTickets += 1
	if mistake: payment = roundi(payment * 0.9)
	var sat := _satisfaction(g, waitScoreZero)
	g.stars = clampf(sat / 20, 0, 5)
	g.payment = payment
	earn(payment, "revenue")
	# Tips (staff, not the till).
	var hap := _outletHappiness()
	var tip := roundi(payment * maxf(0, sat - 60) / 400 * (0.8 + hap / 250))
	if any(loc.staff, func(x): return x.workingToday and (x.role == "server" or x.role == "cashier") and x.hasTrait("trait_charming")):
		tip = roundi(tip * 1.25)
	loc.today.tips += tip
	var weight := b.d("CRITIC_WEIGHT") if g.critic else 1.0
	loc.today.starsSum += g.stars * weight
	loc.today.starsN += weight
	loc.today.groupsServed += 1
	if g.critic:
		_note("critic", "A food critic gave you %.1f stars" % g.stars, roundi(g.stars * 100))
	if g.ill:
		state.flags["%d:ill_guest" % loc.id] = state.dayIndex + 1
	if lf("blogger_pending") and not lf("blogger_done") and g.size <= 2:
		_bloggerVisit(g.stars)
	g.state = "left"
	var table := s.table(g.tableId)
	if table != null:
		table.state = "dirty"
	emit("groupPaid", {"groupId": g.id, "amount": payment, "stars": g.stars, "tableId": g.tableId})

## Delivery platforms take a commission; packaging costs per dish; no tips, no table.
func _payDelivery(g: M.Group) -> void:
	var s := ss
	var payment := 0
	var dishes := 0
	var qSum := 0.0
	for id in g.ticketIds:
		var k := s.ticket(id)
		if k == null or k.state != "ready": continue
		payment += loc.menu[k.dishId].price
		loc.menu[k.dishId].soldToday += 1
		qSum += k.quality
		dishes += 1
	var commission := 0.16 if state.perks.has("perk_officeDistrict") else b.d("DELIVERY_COMMISSION")
	var net := roundi(payment * (1 - commission))
	earn(net, "revenue")
	spend(roundi(dishes * b.d("PACKAGING_PER_DISH")), "ingredients")
	var food := 0.0 if dishes == 0 else qSum / dishes
	var wait := 0.0 if g.totalLimit == 0 else clampf(100 * (1 - float(g.totalWait) / g.totalLimit), 0, 100)
	g.stars = clampf((0.6 * food + 0.4 * wait) / 20, 0, 5)
	g.payment = net
	loc.today.starsSum += g.stars * 0.5
	loc.today.starsN += 0.5
	loc.today.deliveries += 1
	g.state = "left"
	emit("deliverySent", {"groupId": g.id, "amount": net})

func _walkOut(g: M.Group, from: String) -> void:
	var s := ss
	var today := loc.today
	if g.delivery:
		for id in g.ticketIds:
			var k := s.ticket(id)
			if k != null and k.state == "wait": k.state = "cancel"
		remove_where(s.tasks, func(k): return k.groupId == g.id and not k.started)
		g.state = "walkedOut"
		today.deliveriesCancelled += 1
		return
	if from == "waitBill":
		# They leave money on the table (doc 02 §6.3).
		today.walkBill += 1
		_pay(g, true)
		g.state = "walkedOut"
		return
	var seated := from != "waitTable" and from != "closed"
	for id in g.ticketIds:
		var k := s.ticket(id)
		if k != null and k.state == "wait": k.state = "cancel"
	remove_where(s.tasks, func(k): return k.groupId == g.id and not k.started and k.type != "clear")
	remove_where(s.ownerQueue, func(id): return s.task(id) == null)
	if seated:
		var table := s.table(g.tableId)
		if table != null: table.state = "dirty"
		today.starsSum += 10.0 / 20
		today.starsN += 1
		if from == "waitOrder": today.walkOrder += 1
		if from == "waitFood": today.walkFood += 1
	else:
		if g.seatTaskOpen:
			var tb := s.table(g.tableId)
			if tb != null: tb.reserved = false
			remove_where(s.tasks, func(k): return k.type == "seat" and k.groupId == g.id)
		today.starsSum += 0.5 * (30.0 / 20)
		today.starsN += 0.5
		today.walkTable += 1
	s.lost += 1
	today.lost = s.lost
	g.state = "walkedOut"
	emit("groupWalkedOut", {"groupId": g.id, "from": from, "tableId": g.tableId})

func _wash() -> void:
	var s := ss
	var workers := _workers()
	var machine := 2.0 if _hasWorking("eq_dish_machine") else 1.0
	var ownerHere: bool = _ownerPresent and s.ownerArea == "dishes"
	var rate := 0.0
	var washers: Array = workers.filter(func(w): return w.role == "dishwasher")
	for w in washers:
		var r := b.d("WASH_RATE") * machine * (0.5 + _effectiveSkill(w, "wash") / 100)
		if ownerHere: r /= b.d("ZONE_BOOST")
		rate += r
	if ownerHere: rate += b.d("WASH_RATE") * machine * (0.5 + 50.0 / 100)
	if washers.is_empty() and not ownerHere and s.dirtyDishes > 0:
		# Stand-ins: an idle cleaner or prep cook (doc 02 §6.2).
		var busyIds := {}
		for k in s.tasks:
			if k.assignee != null: busyIds[k.assignee] = true
		for w in workers:
			if (w.role == "cleaner" or w.role == "prepCook") and not busyIds.has(str(w.s.id)):
				rate += b.d("WASH_RATE") * machine * (0.5 + (w.s.skill - 15) / 100) / b.d("STAND_IN_TIME_MULT")
	s.dirtyDishes = maxf(0, s.dirtyDishes - rate)

func _ownerUpkeep() -> void:
	var s := ss
	if not _ownerPresent: return
	var working: bool = any(s.tasks, func(k): return k.assignee == "owner") or s.ownerBusyUntil > s.tick
	var drain := 0.0
	if working:
		var cooking := any(s.tasks, func(k): return k.assignee == "owner" and k.type == "cook")
		drain = b.d("OWNER_ENERGY_PER_TICK") * (1.5 if cooking else 1.0)
		s.ownerIdleTicks = 0
	else:
		s.ownerIdleTicks += 1
	if s.ownerArea == "dishes":
		drain = maxf(drain, b.d("OWNER_ENERGY_PER_TICK"))
	state.owner.energy = maxf(0, state.owner.energy - drain)
	s.favourClock += 1
	if s.favourClock >= b.i("FAVOUR_EVERY"):
		s.favourClock = 0
		if s.favours < b.i("FAVOURS_MAX"): s.favours += 1

func _finishService() -> void:
	var s := ss
	for g in s.groups:
		if g.gone: continue
		if g.foodDelivered:
			_pay(g, false)
		else:
			_walkOut(g, "waitTable" if g.state == "waitTable" else "waitFood")
	s.done = true
	s.tasks.clear()
	emit("locationServiceEnded", {"locationId": loc.id})

func _clock(tick: int) -> String:
	var minutes := 11 * 60 + tick * 2
	var h := (minutes / 60) % 24
	var m := minutes % 60
	return "%02d:%02d" % [h, m]

# ---------------------------------------------------------- owner commands

func _ownerQueue(taskId: int) -> CommandResult:
	var s := ss
	var k := s.task(taskId)
	if k == null or k.started:
		return CommandResult.fail(SimError.unknownId, "That job has already been taken.")
	if not _ownerPresent:
		return CommandResult.fail(SimError.locked, "You are resting today.")
	if s.ownerQueue.has(taskId):
		s.ownerQueue.erase(taskId)
		k.reserved = false
		return CommandResult.good()
	if s.ownerQueue.size() >= b.i("OWNER_QUEUE_MAX"):
		return CommandResult.fail(SimError.limitReached, "You already have 3 jobs lined up.")
	if k.type == "cook" and any(_workers(), func(w): return w.role == "headChef" or w.role == "lineCook"):
		return CommandResult.fail(SimError.locked, "Your cooks are on it. You cook only when no cook is in.")
	s.ownerQueue.append(taskId)
	k.reserved = true
	emit("ownerQueued", {"taskId": taskId})
	return CommandResult.good()

func _rush(groupId: int) -> CommandResult:
	var s := ss
	var g := s.group(groupId)
	if g == null or g.state != "waitFood":
		return CommandResult.fail(SimError.invalidValue, "Only a table waiting for food can be rushed.")
	if g.rushed: return CommandResult.fail(SimError.limitReached, "Already rushed.")
	if s.favours <= 0:
		return CommandResult.fail(SimError.limitReached, "No favours left. One comes back every %d ticks." % b.i("FAVOUR_EVERY"))
	var tickets: Array = []
	for id in g.ticketIds:
		var k := s.ticket(id)
		if k != null and k.state != "cancel": tickets.append(k)
	if every(tickets, func(k): return k.state == "ready"):
		return CommandResult.fail(SimError.invalidValue, "Their food is already at the pass.")
	for k in tickets:
		if k.state == "wait": k.priority = -1
		if k.state == "cook":
			for task in s.tasks:
				if task.ticketId == k.id and task.started:
					var left: int = task.endTick - s.tick
					task.endTick = s.tick + maxi(1, ceili(left / 2.0))
	g.rushed = true
	s.favours -= 1
	emit("favourUsed", {"kind": "rush", "groupId": groupId})
	return CommandResult.good()

func _treat(groupId: int) -> CommandResult:
	var s := ss
	var g := s.group(groupId)
	if g == null or not g.waiting:
		return CommandResult.fail(SimError.invalidValue, "Only waiting customers can be treated.")
	if g.treated: return CommandResult.fail(SimError.limitReached, "Already treated.")
	if s.favours <= 0: return CommandResult.fail(SimError.limitReached, "No favours left.")
	g.treated = true
	g.totalLimit += b.i("TREAT_PATIENCE")
	s.favours -= 1
	spend(b.i("TREAT_COST"), "other")
	emit("favourUsed", {"kind": "treat", "groupId": groupId})
	return CommandResult.good()

func _bringBill(groupId: int) -> CommandResult:
	var s := ss
	var g := s.group(groupId)
	if g == null or g.state != "eating":
		return CommandResult.fail(SimError.invalidValue, "Only a table that is eating.")
	if g.broughtBill: return CommandResult.fail(SimError.limitReached, "Already done.")
	if g.eatUntil - s.tick <= 3:
		return CommandResult.fail(SimError.invalidValue, "They are nearly finished anyway.")
	g.eatUntil = s.tick + 2
	g.broughtBill = true
	emit("billBrought", {"groupId": groupId})
	return CommandResult.good()

func _moveStaff(staffId: int, role_: String) -> CommandResult:
	var st := loc.staffById(staffId)
	if st == null or not st.workingToday: return CommandResult.fail(SimError.unknownId)
	if not M.floorRoles.has(st.role) or not M.floorRoles.has(role_):
		return CommandResult.fail(SimError.locked, "Only floor staff can be moved, and nobody can be moved into the kitchen.")
	if role_ == st.role:
		ss.moves.erase(str(staffId))
	else:
		ss.moves[str(staffId)] = role_
	emit("staffMoved", {"staffId": staffId, "role": role_})
	return CommandResult.good()

# ================================================================ incidents.dart
# Incident engine: conditions, effects, rolls, cooldowns, forced, follow-ups (doc 02 §11, doc 05 §2).

## Dart prints an int-valued JSON number without ".0"; JSON here arrives as floats.
static func _dnum(v) -> String:
	if v is float and v == floorf(v) and absf(v) < 1e15:
		return str(int(v))
	return str(v)

static func _dstr(v) -> String:
	return "null" if v == null else str(v)

## List.contains for JSON lists, which hold floats where Dart had ints.
static func _hasv(list: Array, x) -> bool:
	for e in list:
		if (e is float or e is int) and (x is float or x is int):
			if e == x: return true
		elif typeof(e) == typeof(x) and e == x:
			return true
	return false

# ---------------------------------------------------------- conditions

func _staffMatches(s: M.Staff, f: Dictionary) -> bool:
	if f.get("role") != null:
		var r = f["role"]
		if r is Array:
			if not r.has(s.role): return false
		elif s.role != r:
			return false
	if f.get("trait") != null and not s.hasTrait(f["trait"]): return false
	if f.get("moraleBelow") != null and s.morale >= f["moraleBelow"]: return false
	if f.get("moraleAbove") != null and s.morale <= f["moraleAbove"]: return false
	if f.get("fatigueAbove") != null and s.fatigue <= f["fatigueAbove"]: return false
	if f.get("honestyBelow") != null and s.honesty >= f["honestyBelow"]: return false
	if f.get("skillAbove") != null and s.skill <= f["skillAbove"]: return false
	if f.get("reliabilityBelow") != null and s.reliability >= f["reliabilityBelow"]: return false
	if f.get("absentToday") == true and not s.absentToday: return false
	if f.get("working") == true and not s.workingToday: return false
	if f.get("underpaid") == true and s.wage >= _expectedWage(s.role, s.skill) * 0.9: return false
	if f.get("wrongDayOff") == true and s.dayOff == s.preferredDayOff: return false
	if f.get("statusActive") == true and s.status != "active": return false
	return true

func _equipmentMatches(e: M.Equipment, f: Dictionary) -> bool:
	var t: Content.EquipmentType = content.equipment[e.type]
	if f.get("type") != null and e.type != f["type"]: return false
	if f.get("kind") != null and t.kind != f["kind"]: return false
	if f.get("conditionBelow") != null and e.condition >= f["conditionBelow"]: return false
	if f.get("broken") != null and e.broken != f["broken"]: return false
	if f.get("working") == true and not _isWorking(e): return false
	return true

func _cond(c: Dictionary) -> bool:
	var l := loc
	for key in c:
		var v = c[key]
		match key:
			"stageMin":
				if state.stage < v: return false
			"stageMax":
				if state.stage > v: return false
			"dayMin":
				if state.dayIndex < v: return false
			"weekday":
				if not _hasv(v, state.weekday): return false
			"season":
				if not v.has(state.season): return false
			"cashBelow":
				if state.cash >= v: return false
			"cashAbove":
				if state.cash <= v: return false
			"reputationBelow":
				if l.reputation >= v: return false
			"reputationAbove":
				if l.reputation <= v: return false
			"hygieneBelow":
				if l.hygiene >= v: return false
			"hygieneAbove":
				if l.hygiene <= v: return false
			"flag":
				if not lf(v): return false
			"notFlag":
				if lf(v): return false
			"hasStaff":
				var f: Dictionary = v
				var n := count(l.staff, func(s): return _staffMatches(s, f))
				if n < (f["count"] if f.get("count") != null else 1): return false
			"hasEquipment":
				var f: Dictionary = v
				if not any(l.equipment, func(e): return _equipmentMatches(e, f)): return false
			"noEquipmentWorking":
				if _hasWorking(v): return false
			"hasGenerator":
				if not _hasWorking("eq_generator"): return false
			"noGenerator":
				if _hasWorking("eq_generator"): return false
			"ownerIdleTicks":
				if l.service == null or l.service.ownerIdleTicks < v: return false
			"ownerEnergyBelow":
				if state.owner.energy >= v: return false
			"tablesAtLeast":
				if l.tableSeats.size() < v: return false
			"tickAfter":
				if l.service == null or l.service.tick < v: return false
			"groupWaitFoodShare":
				var s = l.service
				if s == null: return false
				if not any(s.groups, func(g): return g.state == "waitFood" and g.counter > _patienceLimit(g) * v): return false
			"festivalInDays":
				var f := _festivalOn(state.dayIndex + int(v))
				if f == null or _festivalOn(state.dayIndex + int(v) - 1) != null: return false
			"seasonChangeDay":
				if state.dayIndex == 0 or state.dayIndex % 84 != 0: return false
			"payableOverdue":
				if not any(l.payables, func(p): return p.dueDay < state.dayIndex): return false
			"theme":
				if not v.has(state.themeId): return false
			"stat":
				var m: Dictionary = v
				var x := _stat(m["name"])
				if m.get("below") != null and x >= m["below"]: return false
				if m.get("above") != null and x <= m["above"]: return false
			"any":
				if not any(v, func(x): return _cond(x)): return false
			_:
				assert(false, "Unknown condition key " + key)
	return true

func _stat(name: String) -> float:
	var t := loc.today
	match name:
		"walkoutShare": return 0.0 if t.groupsArrived == 0 else float(t.walkouts) / t.groupsArrived
		"walkouts": return float(t.walkouts)
		"groupsServed": return float(t.groupsServed)
		"wastePct": return 0.0 if t.revenue == 0 else float(t.wasteCost) / t.revenue
		"profitWeek": return 0.0 if state.weeks.is_empty() else float(state.weeks[state.weeks.size() - 1].netProfit)
		"supplierRelMin":
			var m := 100
			for v in loc.supplierRel.values(): m = mini(m, v)
			return float(m)
	return 0.0

# ---------------------------------------------------------- raising

## Binds a subject and creates an instance. Returns null if no subject fits.
func _raiseIncident(id: String, subjectId = null, subjectKey = null, forced := false, vars = null) -> M.IncidentInstance:
	var def: Content.IncidentDef = content.incidents.get(id)
	if def == null: return null
	if state.phase == "gameOver": return null
	# One open card per incident type.
	if any(state.openIncidents, func(i): return i.incidentId == id and i.subjectId == subjectId and i.locationId == loc.id):
		return null
	var inst := M.IncidentInstance.new()
	inst.id = state.allocId(); inst.locationId = loc.id; inst.incidentId = id; inst.createdDay = state.dayIndex
	inst.vars = {} if vars == null else vars
	if def.subject == "staff":
		var s := loc.staffById(subjectId)
		if s == null:
			var flt: Dictionary = {}
			if def.subjectFilter != null and def.subjectFilter.get("hasStaff") != null:
				flt = def.subjectFilter["hasStaff"]
			var cands: Array = loc.staff.filter(func(x): return _staffMatches(x, flt))
			if cands.is_empty(): return null
			s = _rng.pick(cands)
		inst.subjectId = s.id
		inst.subjectName = s.name
	elif def.subject == "equipment":
		var e := loc.equipmentById(subjectId)
		if e == null:
			var flt: Dictionary = {}
			if def.subjectFilter != null and def.subjectFilter.get("hasEquipment") != null:
				flt = def.subjectFilter["hasEquipment"]
			var cands: Array = loc.equipment.filter(func(x): return _equipmentMatches(x, flt))
			if cands.is_empty(): return null
			e = _rng.pick(cands)
		inst.subjectId = e.id
		inst.subjectName = content.equipment[e.type].name
	elif def.subject == "supplier":
		var sid: String = "sup_standard" if subjectKey == null else subjectKey
		inst.subjectKey = sid
		inst.subjectName = content.suppliers[sid].name if content.suppliers.has(sid) else sid
	elif def.subject == "ingredient":
		var cats: Array = content.ingredients.values().filter(func(i): return i.category == "produce")
		var ing: Content.Ingredient = content.ingredients[subjectKey] if subjectKey != null else _rng.pick(cats)
		inst.subjectKey = ing.id
		inst.subjectName = ing.name
	elif def.subject == "category":
		var cats := ["produce", "dairy", "meat_fish", "dry"]
		var cat: String = subjectKey if subjectKey != null else _rng.pick(cats)
		inst.subjectKey = cat
		inst.subjectName = {"produce": "vegetables", "dairy": "dairy", "meat_fish": "meat and fish", "dry": "dry goods"}[cat]
	elif subjectKey != null:
		inst.subjectKey = subjectKey
	if def.id == "inc_festival_leave":
		var f := _festivalOn(state.dayIndex + 3)
		inst.subjectName = f.name if f != null else "the festival"
	if def.id == "inc_day_off_request":
		var s := loc.staffById(inst.subjectId)
		inst.vars["weekday"] = s.preferredDayOff
	# Service incidents get a countdown; the UI pauses and shows the card.
	if state.phase == "service":
		inst.countdown = b.i("INCIDENT_COUNTDOWN")
	state.incidents.append(inst)
	state.cooldowns["%d:%s" % [loc.id, id]] = state.dayIndex + def.cooldownDays
	_note("incident", _fill(def.title, inst), 0)
	emit("incidentRaised", {"instanceId": inst.id, "incidentId": id})
	# Auto-resolution: a working generator handles a power cut on its own.
	if id == "inc_power_cut" and _hasWorking("eq_generator"):
		_resolveIncident(inst, "generator")
	return inst

func _incidentsAtPrep() -> void:
	# Scheduled (hidden problems, follow-ups, breakdowns, inspections).
	for sc in state.scheduled.duplicate():
		if sc.day > state.dayIndex or sc.incidentId.begins_with("@") or sc.locationId != loc.id:
			continue
		state.scheduled.erase(sc)
		if sc.incidentId == "inc_resignation":
			var s := loc.staffById(sc.subjectId)
			if s == null or s.status != "active" or (sc.subjectKey != "force" and s.morale >= 60):
				continue
			_raiseIncident("inc_resignation", s.id, null, true)
			continue
		if sc.incidentId == "inc_breakdown":
			var e := loc.equipmentById(sc.subjectId)
			if e == null or not e.broken: continue
		_raiseIncident(sc.incidentId, sc.subjectId, sc.subjectKey, true)
	# Forced-by-condition incidents.
	for def in content.incidents.values():
		if not def.forced or def.timing != "prep" or def.trigger.is_empty(): continue
		if state.cooldowns.get("%d:%s" % [loc.id, def.id], -1) >= state.dayIndex: continue
		if _cond(def.trigger): _raiseIncident(def.id, null, null, true)
	# Random inspection chance (about once per 8 weeks).
	if _rng.chance(1 / b.d("INSPECTION_EVERY_DAYS")) and state.cooldowns.get("%d:inc_inspection" % loc.id, -1) < state.dayIndex:
		_raiseIncident("inc_inspection", null, null, true)
	for i in 2:
		_rollIncidents("prep")

func _rollIncidents(timing: String) -> void:
	var eligible: Array = []
	var weights: Array = []
	var idle: int = loc.service.ownerIdleTicks if loc.service != null else 999
	for def in content.incidents.values():
		if def.timing != timing or def.forced or def.weight <= 0: continue
		if state.cooldowns.get("%d:%s" % [loc.id, def.id], -1) >= state.dayIndex: continue
		if def.tags.has("observation") and idle < 10: continue
		if any(state.openIncidents, func(i): return i.incidentId == def.id and i.locationId == loc.id): continue
		if not _cond(def.trigger): continue
		var w: float = def.weight
		if def.id == "inc_staff_conflict" and lf("feud"): w *= 3
		if def.id == "inc_power_cut" and state.season == "summer": w *= 2
		if timing == "service": w /= 12
		eligible.append(def)
		weights.append(w)
	if eligible.is_empty(): return
	var total := 0.0
	for w in weights: total += w
	if not _rng.chance(minf(0.9, total * diff("DIFF_INCIDENTS"))): return
	var def: Content.IncidentDef = _rng.weighted(eligible, weights)
	_raiseIncident(def.id)

# ---------------------------------------------------------- resolving

func _fill(text: String, inst: M.IncidentInstance) -> String:
	var t := text.replace("{staff}", inst.subjectName).replace("{equipment}", inst.subjectName) \
		.replace("{supplier}", inst.subjectName).replace("{ingredient}", inst.subjectName) \
		.replace("{category}", inst.subjectName).replace("{festival}", inst.subjectName).replace("{outlet}", loc.name)
	if inst.vars.get("weekday") != null:
		t = t.replace("{weekday}", _weekdayName(inst.vars["weekday"]))
	var s := loc.staffById(inst.subjectId)
	if s != null:
		t = t.replace("{role}", roleName(s.role).to_lower())
		t = t.replace("{dayWage}", money(s.wage))
	var e := loc.equipmentById(inst.subjectId)
	if e != null:
		var p: int = content.equipment[e.type].price
		t = t.replace("{cheap}", money(p * 0.10)).replace("{proper}", money(p * 0.25)).replace("{new}", money(p)) \
			.replace("{used}", money(p * 0.5)).replace("{emergency}", money(p * 0.4)).replace("{service}", money(p * 0.1))
	t = t.replace("{deficit}", money(maxi(0, -state.cash) + b.i("EMERGENCY_LOAN_EXTRA")))
	return t

func _weekdayName(d: int) -> String:
	return ["Mondays", "Tuesdays", "Wednesdays", "Thursdays", "Fridays", "Saturdays", "Sundays"][d]

## Why an option cannot be chosen right now, or null.
func _optionBlocked(o: Content.IncidentOption, inst: M.IncidentInstance) -> Variant:
	if o.requires != null and not _cond(o.requires):
		return o.hint if o.hint != null else "Not possible right now"
	for e in o.effects:
		if e.get("type") == "cash" and e.get("chance") == null and e.get("amount") != null:
			var amt := _amount(e["amount"], inst)
			if amt < 0 and state.cash + amt < 0 and not (e.get("allowDebt") == true):
				return "Not enough cash"
		if e.get("type") == "lifeline" and e.get("kind") == "investor" and state.investorTaken:
			return "Only once per game"
		if e.get("type") == "lifeline" and e.get("kind") == "sellEquipment" and loc.equipment.is_empty():
			return "Nothing to sell"
		if e.get("type") == "repair" or e.get("type") == "replace":
			var eq := loc.equipmentById(inst.subjectId)
			if eq == null: return "Already gone"
			var p: int = content.equipment[eq.type].price
			var k: float
			if e["type"] == "replace":
				k = 0.5 if e.get("secondHand") == true else 1.0
			else:
				k = float(b.map("REPAIR")[e["mode"]]["cost"])
			if state.cash < p * k: return "Not enough cash"
	return null

func _amount(a, inst: M.IncidentInstance) -> int:
	if a is float or a is int: return roundi(a)
	var s: String = a
	var k := 1.0
	var key := s
	if s.contains("*"):
		var parts := s.split("*")
		key = parts[0]
		k = float(parts[1])
	var staff := loc.staffById(inst.subjectId)
	var eq := loc.equipmentById(inst.subjectId)
	match key:
		"dayWage": return roundi((staff.wage if staff != null else 100) * k)
		"weekWage": return roundi((staff.wage if staff != null else 100) * 7 * k)
		"eqPrice": return roundi((3000 if eq == null else content.equipment[eq.type].price) * k)
		"dayRevenue": return roundi(maxi(loc.today.revenue, 1000 if loc.days.is_empty() else loc.days[loc.days.size() - 1].revenue) * k)
		"rent": return roundi(loc.rentWeekly * k)
		"orderTotal": return roundi(inst.vars.get("total", 0) * k)
	assert(false, "Unknown amount expression " + s)
	return 0

func _resolveIncident(inst: M.IncidentInstance, optionId: String, ignored := false) -> void:
	var l := state.locationById(inst.locationId)
	if l != null and l != loc:
		at(l, func(): _resolveIncident(inst, optionId, ignored))
		return
	if inst.resolved: return
	var def: Content.IncidentDef = content.incidents[inst.incidentId]
	var opt = first_or_null(def.options, func(o): return o.id == optionId)
	if opt == null: opt = def.option(def.defaultOption)
	if _optionBlocked(opt, inst) != null and opt.id != def.defaultOption:
		opt = def.option(def.defaultOption)
	inst.resolved = true
	inst.chosen = opt.id
	var lines: Array = []
	_applyEffects(opt.effects, inst, lines)
	inst.result = "Done." if lines.is_empty() else " ".join(lines)
	if ignored:
		inst.result = "Nobody decided in time: \"%s\". %s" % [_fill(opt.label, inst), inst.result]
	_note("incidentResult", "%s: %s" % [_fill(def.title, inst), inst.result], 0)
	emit("incidentResolved", {"instanceId": inst.id, "result": inst.result})

func _applyEffects(effects: Array, inst: M.IncidentInstance, out: Array) -> void:
	for e in effects:
		var chance = e.get("chance")
		if chance != null and not _rng.chance(float(chance)):
			var alt = e.get("else")
			if alt != null: _applyEffects(alt, inst, out)
			if e.get("failText") != null: out.append(_fill(e["failText"], inst))
			continue
		_applyEffect(e, inst, out)
		if e.get("text") != null: out.append(_fill(e["text"], inst))

func _targets(target, inst: M.IncidentInstance) -> Array:
	var t: String = "subject" if target == null else target
	if t == "subject":
		var s := loc.staffById(inst.subjectId)
		return [] if s == null else [s]
	if t == "all": return loc.staff.duplicate()
	if t == "others": return loc.staff.filter(func(s): return s.id != inst.subjectId)
	if t.begins_with("role:"): return loc.staff.filter(func(s): return s.role == t.substr(5))
	return []

func _applyEffect(e: Dictionary, inst: M.IncidentInstance, out: Array) -> void:
	var l := loc
	var eq := l.equipmentById(inst.subjectId)
	var st := l.staffById(inst.subjectId)
	var sv = l.service
	var n := func(k: String, d = 0) -> Variant: return e[k] if e.get(k) != null else d
	match e["type"]:
		"none", "log":
			pass
		"cash":
			var a: int = roundi(loc.today.revenue * e["pctOfDayRevenue"]) if e.get("pctOfDayRevenue") != null else _amount(e.get("amount"), inst)
			if a < 0:
				spend(-a, e["bucket"] if e.get("bucket") != null else "other")
			else:
				earn(a, "other")
			if e.get("text") == null and a != 0:
				out.append("Paid %s." % money(-a) if a < 0 else "Received %s." % money(a))
		"reputation":
			l.reputation = clampf(l.reputation + n.call("delta"), 0, 5)
			if e.get("text") == null:
				out.append("Rating %s%s." % ["+" if n.call("delta") > 0 else "", _dnum(n.call("delta"))])
		"hygiene":
			l.hygiene = clampf(l.hygiene + n.call("delta"), 0, 100)
		"morale":
			for s in _targets(e.get("target"), inst):
				s.morale = clampf(s.morale + n.call("delta"), 0, 100)
		"mood":
			for s in _targets(e.get("target"), inst):
				s.moodMods.append(M.MoodMod.mk(e["key"], float(n.call("score")), state.dayIndex + int(n.call("days"))))
		"staffStat":
			if st != null:
				var stat: String = e["stat"]
				var d := float(n.call("delta"))
				match stat:
					"skill": st.skill = clampf(st.skill + d, 0, 100)
					"reliability": st.reliability = clampf(st.reliability + d, 0, 100)
					"loyalty": st.loyalty = clampf(st.loyalty + d, 0, 100)
					"honesty": st.honesty = clampf(st.honesty + d, 0, 100)
					"fatigue": st.fatigue = clampf(st.fatigue + d, 0, 100)
					"morale": st.morale = clampf(st.morale + d, 0, 100)
				if e.get("set") != null and stat == "morale":
					st.morale = float(n.call("set"))
		"staffStatus":
			if st != null:
				var status: String = e["status"]
				var days := int(n.call("days", 1))
				if status == "absent":
					var from := state.dayIndex + 1 if state.phase == "close" else state.dayIndex
					st.absentUntil = maxi(st.absentUntil, from + days)
					if state.phase != "close": st.workingToday = false
					if e.get("text") == null:
						out.append("%s is off for %d day%s." % [st.name, days, "" if days == 1 else "s"])
				elif status == "notice":
					st.status = "notice"
					st.noticeLeft = _rng.next_int(3, 7)
					if e.get("text") == null:
						out.append("%s will work %d more days, then leave." % [st.name, st.noticeLeft])
		"noticeLeave":
			if st != null:
				st.status = "notice"
				st.noticeLeft = _rng.next_int(3, 7)
		"staffLeaves":
			if st != null:
				_removeStaff(st, "%s left" % st.name)
				if state.phase == "service" and sv != null: sv.moves.erase(str(st.id))
		"staffFired":
			if st != null: _fire(st.id)
		"setWage":
			if st != null:
				st.wage = roundi(st.wage * n.call("mult", 1))
				st.lastGrowthDay = state.dayIndex
		"cancelResignation":
			if st != null:
				st.status = "active"
				st.noticeLeft = 0
		"equipment":
			if eq != null:
				if e.get("condition") != null:
					eq.condition = minf(_maxCondition(eq), float(n.call("condition")))
				if e.get("conditionDelta") != null:
					eq.condition = clampf(eq.condition + n.call("conditionDelta"), 0, _maxCondition(eq))
				if e.get("broken") != null:
					eq.broken = e["broken"]
					if eq.broken:
						if e.get("text") == null:
							out.append("The %s is out of action until repaired." % content.equipment[eq.type].name.to_lower())
						_timeline("%s broke down" % content.equipment[eq.type].name)
				if e.get("shakyDays") != null:
					eq.fragileUntil = state.dayIndex + int(n.call("shakyDays"))
		"repair":
			if eq != null:
				var cfg: Dictionary = b.map("REPAIR")[e["mode"]]
				var price: int = content.equipment[eq.type].price
				var cost := roundi(price * float(cfg["cost"]))
				spend(cost, "upkeep")
				eq.broken = false
				eq.condition = minf(_maxCondition(eq), float(cfg["condition"]))
				var days := int(cfg["days"])
				eq.unavailableUntil = state.dayIndex + (1 if state.phase == "close" else 0) + days
				if e["mode"] == "cheap": eq.fragileUntil = state.dayIndex + 7
				out.append("Repair booked for %s; back in use %s." % [money(cost), "today" if days <= 0 else ("tomorrow" if days == 1 else "in %d days" % days)])
				_markFridge(eq)
		"replace":
			if eq != null:
				var secondHand: bool = e.get("secondHand") == true
				_buyEquipment(eq.type, secondHand, eq.id)
				out.append("A second-hand unit arrives tomorrow." if secondHand else "A new unit arrives in 2 days.")
		"stock":
			var pct := float(n.call("losePct"))
			var qd := int(n.call("qualityDelta"))
			var dl := int(n.call("daysLeftDelta"))
			for bt in l.stock:
				var ing: Content.Ingredient = content.ingredients[bt.ingredientId]
				if e.get("storage") != null and ing.storage != e["storage"]: continue
				if e.get("ingredientId") != null and bt.ingredientId != e["ingredientId"]: continue
				if pct > 0: bt.qty = floori(bt.qty * (1 - pct))
				if qd != 0: bt.quality = clampi(bt.quality + qd, 0, 100)
				if dl != 0: bt.daysLeft = maxi(1, bt.daysLeft + dl)
			remove_where(l.stock, func(bt): return bt.qty <= 0)
		"demand":
			l.demandMods.append(M.Mod.mk(inst.incidentId, float(n.call("mult", 1)), state.dayIndex + int(n.call("days", 1)) - 1))
		"competition":
			l.competition = clampf(l.competition + n.call("delta"), 0, b.d("COMPETITION_MAX"))
		"patience":
			if sv != null:
				sv.patienceMult = float(n.call("mult", 1))
				sv.patienceUntil = sv.tick + int(n.call("ticks", 30))
		"stationOff":
			if sv != null:
				var ticks := int(n.call("ticks", 20))
				for station in e["stations"]:
					sv.stationOffUntil[station] = sv.tick + ticks
		"noSeating":
			if sv != null:
				sv.noSeatUntil = sv.tick + int(n.call("ticks", 40))
				if e.get("walkWaiting") == true:
					for g in sv.groups.filter(func(g): return g.state == "waitTable"):
						_walkOut(g, "waitTable")
		"billSlow":
			if sv != null:
				sv.billMult = float(n.call("mult", 2))
				sv.billMultUntil = sv.tick + int(n.call("ticks", 999))
		"roleSlow":
			if sv != null:
				for s in _targets(e.get("target"), inst):
					sv.roleSlow[s.role] = float(n.call("mult", 1.2))
		"ownerBusy":
			if sv != null: sv.ownerBusyUntil = sv.tick + int(n.call("ticks", 5))
			state.owner.energy = maxf(0, state.owner.energy - n.call("ticks", 5) * b.d("OWNER_ENERGY_PER_TICK"))
		"groupSatisfaction":
			if sv != null:
				var scope: String = e["scope"] if e.get("scope") != null else "eating"
				for g in sv.groups:
					if scope == "eating" and g.state != "eating": continue
					if scope == "waitFood" and g.state != "waitFood": continue
					g.satAdj += n.call("delta")
					if e.get("patience") != null: g.totalLimit += int(n.call("patience"))
					if e.get("patience") != null and g.waiting:
						g.counter = maxi(0, g.counter - int(n.call("patience")))
		"closeLocation":
			var from := state.dayIndex + 1 if state.phase == "close" else state.dayIndex
			l.closedUntil = maxi(l.closedUntil, from + int(n.call("days", 1)))
			out.append("The restaurant is closed %s. Wages are still due." % ("for a day" if n.call("days", 1) == 1 else "for %s days" % _dnum(n.call("days"))))
			_timeline("Closed for %s day(s)" % _dnum(n.call("days", 1)))
		"flag":
			var days: int = (1 << 30) if e.get("days") == null else state.dayIndex + int(n.call("days"))
			state.flags["%d:%s" % [loc.id, e["key"]]] = days
		"clearFlag":
			state.flags.erase("%d:%s" % [loc.id, e["key"]])
		"followUp":
			var same: bool = e.get("sameSubject") == true
			state.scheduled.append(M.Scheduled.mk(e["incidentId"], state.dayIndex + int(n.call("days", 1)),
				inst.subjectId if same else null, "force" if same else null, loc.id))
		"inspection", "scheduleInspection":
			var day := state.dayIndex + int(n.call("days", 7))
			state.scheduled.append(M.Scheduled.mk("inc_inspection", day, null, null, loc.id))
			l.inspectionDay = day
		"inspect":
			_inspect(out)
		"ownerEnergy":
			state.owner.energy = clampf(state.owner.energy + n.call("delta"), 0, 100)
		"payable":
			l.payables.append(M.Payable.mk(state.allocId(), null, _amount(e.get("amount"), inst),
				state.dayIndex + int(n.call("days", 7)), e["label"] if e.get("label") != null else "Bill", false))
		"reveal":
			if st != null:
				st.daysWorked = maxi(st.daysWorked, 14)
				out.append("%s's honesty: %d." % [st.name, roundi(st.honesty)])
		"lifeline":
			_lifeline(e["kind"], _mostValuableSpare() if e["kind"] == "sellEquipment" else null)
		"priceSpike":
			l.categorySpikeUntil["produce" if inst.subjectKey == null else inst.subjectKey] = state.dayIndex + int(n.call("days", 7)) - 1
		"raisePrices":
			var cat = inst.subjectKey
			for m in l.menu.values():
				var d: Content.Dish = content.dishes[m.dishId]
				if any(d.recipe, func(r): return content.ingredients[r.ingredientId].category == cat):
					m.price = mini(floori(d.basePrice * 1.8), roundi(m.price * (1 + n.call("pct", 0.1))))
		"eightySixCostliest":
			var cat = inst.subjectKey
			var hit: Array = l.menu.values().filter(func(m): return any(content.dishes[m.dishId].recipe, func(r): return content.ingredients[r.ingredientId].category == cat))
			dsort(hit, func(a, c): return cmpn(c.price, a.price))
			var names: Array = []
			for m in hit.slice(0, 2):
				m.enabled = false
				m.offSinceDay = state.dayIndex
				names.append(content.dishes[m.dishId].name)
			out.append("Took %s off the menu." % " and ".join(names))
		"rejectBatch":
			remove_where(l.stock, func(bt): return bt.quality < 50)
			var refund: int = inst.vars.get("total", 0)
			if refund > 0:
				var p = null
				for x in l.payables:
					if x.supplierId == inst.subjectKey and x.dueDay > state.dayIndex: p = x
				if p != null:
					l.payables.erase(p)
					loc.today.ingredientSpend -= p.amount
				else:
					earn(refund, "none")
					loc.today.ingredientSpend -= refund
		"refundOrder":
			var r := roundi(inst.vars.get("total", 300) * n.call("pct", 0.1))
			earn(r, "none")
		"supplierRel":
			var sid: String = "sup_standard" if inst.subjectKey == null else inst.subjectKey
			l.supplierRel[sid] = int(clampf(l.supplierRel.get(sid, 50) + n.call("delta"), 0, 100))
			if e.get("set") != null: l.supplierRel[sid] = int(n.call("set"))
		"supplierBlock":
			l.supplierBlockedUntil["sup_standard" if inst.subjectKey == null else inst.subjectKey] = state.dayIndex + int(n.call("days", 28))
		"supplierCashOnly":
			l.supplierCashOnlyUntil["sup_standard" if inst.subjectKey == null else inst.subjectKey] = state.dayIndex + int(n.call("days", 56))
		"payPayables":
			var sid = inst.subjectKey
			for p in l.payables.filter(func(p): return p.supplierId == sid):
				if state.cash < p.amount: break
				l.payables.erase(p)
				state.cash -= p.amount
				out.append("Paid %s to %s." % [money(p.amount), inst.subjectName])
		"supplierDeal":
			l.supplierDeal["sup_standard" if inst.subjectKey == null else inst.subjectKey] = float(n.call("discount", 0.08))
			state.flags["deal_%s" % _dstr(inst.subjectKey)] = state.dayIndex + 56
		"rent":
			var pct := float(n.call("pct"))
			l.rentWeekly = roundi(l.rentWeekly * (1 + pct))
			out.append("Rent is now %s a week (%s%d%%)." % [money(l.rentWeekly), "+" if pct >= 0 else "", roundi(pct * 100)])
			_timeline("Rent changed to %s/week" % money(l.rentWeekly))
			if inst.subjectKey == "hidden": _markHidden("lease_increase")
		"leaseLock":
			l.leaseLockUntil = state.dayIndex + 672
		"shortage":
			l.shortageIngredient = inst.subjectKey
			l.shortageUntil = state.dayIndex + int(n.call("days", 7)) - 1
		"dayOffChange":
			if st != null:
				st.dayOff = st.preferredDayOff
				st.preferredKnown = true
				out.append("%s now has %s off." % [st.name, _weekdayName(st.dayOff)])
		"removeTrait":
			if st != null: st.traits.erase(e.get("trait"))
		"critic":
			state.flags["%d:critic_next" % loc.id] = state.dayIndex
		"bigBooking":
			state.flags["%d:big_booking_today" % loc.id] = state.dayIndex
		"filmCrew":
			state.flags["%d:film_crew_today" % loc.id] = state.dayIndex
		"festivalLeave":
			state.flags["%d:festival_absence" % loc.id] = state.dayIndex + 6
			state.flags["%d:festival_absence_pct" % loc.id] = roundi(n.call("pct") * 100)
		"festivalPay":
			state.flags["%d:festival_double_pay" % loc.id] = state.dayIndex + 6
		"train":
			if st != null: _train(st.id)
		"markHidden":
			_markHidden(e["kind"])
		"closeOutletNow":
			var r := _closeOutlet()
			out.append("The outlet is closed for good." if r.ok else (r.message if r.message != null else "It could not be closed."))
		_:
			assert(false, "Unknown effect %s" % e["type"])

func _markFridge(e: M.Equipment) -> void:
	if e.type == "eq_fridge": _updateHiddenProblems()

func _mostValuableSpare() -> Variant:
	var best: M.Equipment = null
	for e in loc.equipment:
		var t: Content.EquipmentType = content.equipment[e.type]
		if t.kind == "storage" and count(loc.equipment, func(x): return x.type == e.type) < 2: continue
		if best == null or _equipmentResale(e) > _equipmentResale(best): best = e
	return best.id if best != null else null

## Health inspection outcome (doc 02 §12).
func _inspect(out: Array) -> void:
	var l := loc
	var h := l.hygiene
	_markHidden("health_violation")
	if h >= b.d("INSPECTION_PASS"):
		l.reputation = minf(5, l.reputation + 0.1)
		out.append("The inspector passed you (cleanliness %d). Rating +0.1." % roundi(h))
		_timeline("Passed a health inspection (%d)" % roundi(h))
		if h >= 90: _completeObjective("obj_2_inspection_a")
	elif h >= b.d("INSPECTION_WARN"):
		spend(b.i("INSPECTION_FINE_WARN"), "other")
		state.scheduled.append(M.Scheduled.mk("inc_inspection", state.dayIndex + 7, null, null, loc.id))
		out.append("Warning and a %s fine (cleanliness %d). They will be back in 7 days." % [money(b.i("INSPECTION_FINE_WARN")), roundi(h)])
		_timeline("Health inspection warning (%d)" % roundi(h))
	else:
		spend(b.i("INSPECTION_FINE_CLOSE"), "other")
		l.reputation = maxf(0, l.reputation - 0.5)
		var from := state.dayIndex + 1 if state.phase == "close" else state.dayIndex
		l.closedUntil = maxi(l.closedUntil, from + 2)
		for s in l.staff:
			s.moodMods.append(M.MoodMod.mk("Job security", -6, state.dayIndex + 14))
		out.append("Closed for 2 days, fined %s, rating −0.5 (cleanliness %d)." % [money(b.i("INSPECTION_FINE_CLOSE")), roundi(h)])
		_timeline("Closed by the health inspector (%d)" % roundi(h))
	_note("inspection", out[out.size() - 1], 0)

# ================================================================ chain.dart
# Several outlets (doc 02 §15, doc 11 Parts B–D): travel, managers, requests, neglect,
# skimming, the outlet market and building, selling and closing, badges, chain perks,
# central kitchen, bulk contract and franchising (doc 13).

const managerProfiles := {
	"allRounder": [0.0, 0.0, 0.0], "peoplePerson": [15.0, -5.0, -10.0],
	"tightShip": [-10.0, 15.0, -5.0], "numbers": [-5.0, -10.0, 15.0],
}
const profileNames := {"allRounder": "All-rounder", "peoplePerson": "People person", "tightShip": "Tight ship", "numbers": "Numbers"}
const formatNames := {"neighbourhood": "Neighbourhood", "highStreet": "High street", "officeDistrict": "Office district"}
const perkText := {
	"perk_neighbourhood": "staff you promote to manager start with +5 people skill",
	"perk_highStreet": "marketing costs 15% less everywhere",
	"perk_officeDistrict": "delivery platforms take 16% instead of 20%",
}

# ---------------------------------------------------------- basics

func _format(l: M.Location) -> Dictionary:
	var f = b.map("FORMATS").get(l.format)
	if f == null: f = b.map("FORMATS")["neighbourhood"]
	var out := {}
	for k in f: out[k] = float(f[k])
	return out

var _unattended: bool:
	get: return state.ownerLocationId != loc.id or state.owner.restingToday

## Average rating over all trading outlets.
func _companyRating() -> float:
	var ls: Array = state.openLocations.filter(func(l): return l.openDay <= state.dayIndex)
	if ls.is_empty(): return state.loc.reputation
	var a := 0.0
	for l in ls: a += l.reputation
	return a / ls.size()

func _story(text: String) -> void:
	loc.story.append(M.TimelineEntry.mk(state.dayIndex, text))
	if loc.story.size() > 40: loc.story.remove_at(0)

func _managerNote(text: String, cost: int) -> void:
	if cost >= 0:
		loc.managerCostWeek += cost
	else:
		loc.managerSaveWeek -= cost
	loc.managerNotes.append(text)
	if loc.managerNotes.size() > 12: loc.managerNotes.remove_at(0)

func _expectedManagerWage(meanSkill: float) -> int:
	return roundi(b.dmap("BASE_WAGE")["manager"] * (0.4 + 1.2 * meanSkill / 100))

func _mastery(skill: float) -> float:
	return clampf((skill - b.d("MASTERY_FROM")) / (b.d("MASTERY_FULL") - b.d("MASTERY_FROM")), 0, 1)

## Standards slipping at an outlet the owner has not visited (doc 02 §15.5).
func _slack() -> float:
	if state.locations.size() < 2: return 0.0
	var m := loc.manager
	if m == null or not _unattended: return 0.0
	var grace := m.managerSkill * m.managerSkill / b.d("NEGLECT_GRACE_SQ_DIV")
	var neglect := maxf(0, (state.dayIndex - loc.lastVisitDay) - grace)
	return minf(b.d("NEGLECT_MAX"), neglect * b.d("NEGLECT_PER_DAY"))

# ---------------------------------------------------------- morning and evening

func _chainMorning() -> void:
	var ol := state.locationById(state.ownerLocationId)
	if ol == null or ol.closedForGood:
		state.ownerLocationId = state.openLocations[0].id
	var vl := state.locationById(state.viewLocationId)
	if vl == null or vl.closedForGood:
		state.viewLocationId = state.ownerLocationId
	if state.stage >= 3:
		if state.marketRefreshDay < 0 or state.dayIndex >= state.marketRefreshDay:
			_refreshOutletMarket()
			state.marketRefreshDay = state.dayIndex + 28
		if state.managerApplicants.is_empty() or state.dayIndex % 14 == 0:
			_generateManagerApplicants()
	# Offers for listed outlets (doc 02 §14.7).
	for l in state.openLocations:
		remove_where(l.saleOffers, func(o): return o.expiresDay < state.dayIndex)
		if l.listedDay >= 0:
			var waited: int = state.dayIndex - l.listedDay
			if waited >= 7 and l.saleOffers.size() < 3 and _rng.chance(1.0 / 7):
				var est: int = at(l, _saleEstimate)
				l.saleOffers.append(M.SaleOffer.mk(roundi(est * _rng.range_f(0.8, 1.1)), state.dayIndex + 7))
				state.pendingNotices.append("A buyer has made an offer for %s: %s (valid 7 days)." % [l.name, money(l.saleOffers[l.saleOffers.size() - 1].amount)])
	# Old requests: unanswered for 3 days, the manager is fed up.
	for r in state.requests:
		if state.dayIndex - r.raisedDay > 3:
			var rl := state.locationById(r.locationId)
			var m: M.Staff = rl.manager if rl != null else null
			if m != null: m.morale = maxf(0, m.morale - 2)
	remove_where(state.requests, func(r): return state.dayIndex - r.raisedDay > 14 or state.locationById(r.locationId) == null)

func _chainEvening() -> void:
	for l in state.openLocations:
		at(l, func():
			# A visit: at least VISIT_MIN_TICKS of service with the owner there (doc 02 §15.3).
			var present: bool = l.ownerTicksToday >= b.i("VISIT_MIN_TICKS") or \
				(l.service != null and l.service.done == true and l.today.closed and state.ownerLocationId == l.id)
			if present:
				l.lastVisitDay = state.dayIndex
				l.ownerDaysThisWeek += 1
				var mm: M.Staff = l.manager
				if mm != null and state.dayIndex - mm.lastCoachDay >= 7:
					_growManager(mm, 1)
					mm.lastCoachDay = state.dayIndex
			var m: M.Staff = l.manager
			if m == null: return
			# Learning on the job: +1 to the weakest sub-skill per 28 days in post.
			if state.dayIndex - m.lastLearnDay >= 28:
				m.lastLearnDay = state.dayIndex
				_growManager(m, 1)
			# A dishonest manager skims (doc 02 §15.6).
			if m.honesty < 40 and l.today.revenue > 0 and _rng.chance((40 - m.honesty) / 100 + _slack()):
				var lost := roundi(l.today.revenue * b.d("SKIM_PCT"))
				state.cash -= lost
				l.today.other += lost
				_note("skim", "Cash in the till was %s short of sales" % money(lost), lost)
			# People mastery: the crew improves (doc 02 §15.16).
			var pm := _mastery(m.people)
			if pm > 0 and posmod(state.dayIndex - m.hiredDay, 28) == 27 and _rng.chance(pm):
				for s in l.staff:
					if not s.isManager and s.skill < 80: s.skill += 1
				_managerNote("%s developed the crew (+1 skill each)" % m.name, -300))

func _growManager(m: M.Staff, n: int) -> void:
	for i in n:
		if m.managerSkill >= m.potential: return
		if m.people <= m.upkeep and m.people <= m.stockSkill:
			m.people = minf(90, m.people + 1)
		elif m.upkeep <= m.stockSkill:
			m.upkeep = minf(90, m.upkeep + 1)
		else:
			m.stockSkill = minf(90, m.stockSkill + 1)
	m.skill = round(m.managerSkill)

# ---------------------------------------------------------- the manager runs prep

func _managerPrep() -> void:
	var l := loc
	var m := l.manager
	var p := l.policies
	# People: rota mistakes, absence cover, fatigue care.
	if _rng.chance((100 - m.people) / 300):
		var working: Array = l.staff.filter(func(s): return s.workingToday and not s.isManager)
		if not working.is_empty():
			var s: M.Staff = _rng.pick(working)
			s.workingToday = false
			_managerNote("%s left %s off the rota by mistake" % [m.name, s.name], 150)
			_note("managerRota", "%s left %s off the rota by mistake" % [m.name, s.name], 150)
	for s in l.staff.filter(func(s): return s.absentToday):
		if _rng.chance(m.people / 100):
			var cover = first_or_null(l.staff, func(x): return (x.role == s.role or (x.isCook and s.isCook)) and not x.workingToday \
				and not x.absentToday and x.absentUntil <= state.dayIndex and x.trainingUntil <= state.dayIndex)
			if cover != null:
				cover.workingToday = true
				cover.workDayOffDay = state.dayIndex
				cover.fatigue = minf(100, cover.fatigue + 6)
				_managerNote("%s called in %s to cover %s" % [m.name, cover.name, s.name], -200)
	if m.people >= 60:
		for s in l.staff.filter(func(s): return s.workingToday and s.fatigue > 75 and not s.isManager):
			var others := count(l.staff, func(x): return x != s and x.role == s.role and x.workingToday)
			if others > 0:
				s.workingToday = false
				s.fatigue = maxf(0, s.fatigue - 30)
	# Stock: order to cover today and tomorrow, with errors that shrink with skill.
	if p.autoOrder:
		var u := _rng.range_f(-1, 1)
		var mult := 1 + u * (100 - m.stockSkill) / 200
		# A good stock manager buys fresh food and meat from the specialists.
		var plan := ["sup_farm", "sup_butcher", "sup_standard"] if m.stockSkill >= 60 else ["sup_standard"]
		var ordered := {}
		for sup in plan:
			var so := _suggestedOrder(sup)
			var lines := {}
			for k in so:
				lines[k] = roundi(so[k] * mult)
			for k in lines.keys():
				if lines[k] <= 0 or ordered.has(k): lines.erase(k)
			if not lines.is_empty() and _orderTotal(sup, lines) >= content.suppliers[sup].minOrder:
				for k in lines: ordered[k] = true
			if not lines.is_empty() and _orderTotal(sup, lines) >= content.suppliers[sup].minOrder:
				_placeOrder(sup, lines)
				if mult > 1.15:
					_managerNote("%s over-ordered stock" % m.name, roundi((mult - 1) * _orderTotal(sup, lines)))
				if mult < 0.85:
					_managerNote("%s under-ordered: dishes may sell out" % m.name, 200)
		# Same-day top-up if something runs out today.
		var short := {}
		var use := _expectedDailyUse(l)
		for ing in use:
			var need: int = ceili(use[ing]) - l.stockOf(ing)
			if need > 0 and m.stockSkill >= 50: short[ing] = need
		if not short.is_empty() and state.cash > 2000:
			_placeOrder("sup_cash_carry", short)
	# People: a good manager develops the weakest cook when the course fits the limit.
	if state.weekday == 1:
		var cooks: Array = l.staff.filter(func(s): return s.isCook and s.skill < 70 and s.trainingUntil < state.dayIndex)
		dsort(cooks, func(a, c): return cmpn(a.skill, c.skill))
		if not cooks.is_empty():
			var c: M.Staff = cooks[0]
			var cost := roundi(b.d("TRAIN_COST_PER_SKILL") * c.skill)
			if cost <= p.spendingLimit:
				if m.people >= 60 and state.cash > 5000:
					_train(c.id)
					_managerNote("%s sent %s on a course" % [m.name, c.name], -200)
			else:
				# Beyond their authority: ask (doc 02 §15.10, kind "training").
				_request("training", cost, null, c.id, null,
					"%s (cook, skill %d) needs a cooking course. Pay %s?" % [c.name, roundi(c.skill), money(cost)], m.people)
	# No head chef: ask to promote the best line cook. A promotion means a raise, so it is a request.
	if not any(l.staff, func(s): return s.role == "headChef"):
		var lc: Array = l.staff.filter(func(s): return s.role == "lineCook")
		dsort(lc, func(a, c): return cmpn(c.skill, a.skill))
		if not lc.is_empty() and lc[0].skill >= 50:
			var c: M.Staff = lc[0]
			var raise := maxi(0, _expectedWage("headChef", c.skill) - c.wage) * 7
			_request("promote", raise, null, c.id, null,
				"There is no head chef. Promote %s (skill %d)? Their pay rises by %s a week." % [c.name, roundi(c.skill), money(raise)], m.people)
	# Upkeep: servicing, repairs within the spending limit, early warnings.
	for e in l.equipment.duplicate():
		var t: Content.EquipmentType = content.equipment[e.type]
		if e.broken:
			var mode := "proper" if m.upkeep >= 60 else "cheap"
			var cost := roundi(t.price * float(b.map("REPAIR")[mode]["cost"]))
			if cost <= p.spendingLimit and state.cash >= cost:
				var inst := M.IncidentInstance.new()
				inst.id = 0; inst.incidentId = "manager"; inst.subjectId = e.id; inst.createdDay = state.dayIndex
				_applyEffect({"type": "repair", "mode": mode}, inst, [])
				if mode == "cheap":
					_managerNote("%s chose a cheap repair on the %s" % [m.name, t.name.to_lower()], roundi(t.price * 0.05))
			else:
				_request("repair", roundi(t.price * 0.25), roundi(t.price * 0.10), e.id, null,
					"The %s is broken. Repair it properly?" % t.name.to_lower(), m.upkeep)
			continue
		if e.condition < p.maintenanceThreshold and state.dayIndex - e.lastMaintDay >= 7 and e.condition < _maxCondition(e) - 5:
			if _rng.chance(clampf(0.3 + m.upkeep / 100, 0, 1)):
				if e.condition >= 50 or state.weekday == 0: _maintain(e.id)
			else:
				_managerNote("%s skipped servicing the %s" % [m.name, t.name.to_lower()], 100)
		if e.condition < 45 and _rng.chance(m.upkeep / 100) and _rng.chance(0.2):
			_request("replace", t.price, roundi(t.price * 0.5), e.id, null,
				"The %s is worn out (condition %d). Replace it?" % [t.name.to_lower(), roundi(e.condition)], m.upkeep)
	# Requests for things beyond their authority (doc 02 §15.10).
	for role_ in ["lineCook", "server", "dishwasher", "cleaner"]:
		var have := count(l.staff, func(s): return s.role == role_ or (role_ == "lineCook" and s.role == "headChef"))
		var need := 3 if role_ == "lineCook" else (2 if role_ == "server" else 1)
		if have < need:
			var wage := _expectedWage(role_, 50) * 7
			if p.mayHire:
				var a = first_or_null(state.applicants, func(x): return x.role == role_)
				if a != null:
					_hire(a.id)
					continue
			_request("hire", wage, null, null, role_, "We are short of a %s. Hire one?" % roleName(role_).to_lower(), m.people)
	for s in l.staff.filter(func(s): return not s.isManager and s.morale < 45 and s.wage < _expectedWage(s.role, s.skill)):
		var exp := _expectedWage(s.role, s.skill)
		if p.mayGiveRaises:
			_setWage(s.id, exp)
		else:
			_request("raise", (exp - s.wage) * 7, roundi((exp - s.wage) * 3.5), s.id, null,
				"%s is unhappy and underpaid. Raise to %s a day?" % [s.name, money(exp)], m.people)
	# Buzz recovers slowly after an ad: ask again only once the last one is three weeks gone.
	var lastAd := -999
	for c in l.campaigns: lastAd = maxi(lastAd, c.endDay)
	if l.buzz < 0.25 and state.stage >= 2 and state.dayIndex - lastAd > 21:
		_request("marketing", 3000, null, null, "localAd", "Buzz is low. Run a local ad?", m.managerSkill)

func _request(kind: String, cost: int, cheaper, subjectId, subjectKey, text: String, skill: float) -> void:
	if any(state.requests, func(r): return r.locationId == loc.id and r.kind == kind and r.subjectId == subjectId and r.subjectKey == subjectKey):
		return
	if not _rng.chance(clampf(0.4 + skill / 100, 0, 1)):
		var mn: String = loc.manager.name if loc.manager != null else "The manager"
		_managerNote("%s did not raise: %s" % [mn, text.split(".")[0].to_lower()], 100)
		return
	var r := M.Request.new()
	r.id = state.allocId(); r.locationId = loc.id; r.kind = kind; r.subjectId = subjectId; r.subjectKey = subjectKey
	r.cost = cost; r.cheaperCost = cheaper; r.text = text; r.raisedDay = state.dayIndex
	state.requests.append(r)

func _managerClose() -> void:
	# Upkeep mastery slows wear (doc 02 §15.16): give some condition back.
	var m := loc.manager
	if m == null: return
	var um := _mastery(m.upkeep)
	if um > 0:
		for e in loc.equipment:
			if not e.broken:
				e.condition = minf(_maxCondition(e), e.condition + content.equipment[e.type].wearPerDay * 0.3 * um)

## What happens to a card nobody answers: the manager decides by the stance, else the default.
func _ignoredChoice(inst: M.IncidentInstance) -> String:
	var def: Content.IncidentDef = content.incidents[inst.incidentId]
	var l := state.locationById(inst.locationId)
	if l == null or l.manager == null or state.ownerLocationId == l.id:
		return def.defaultOption
	return at(l, func():
		var opts: Array = def.options.filter(func(o): return _optionBlocked(o, inst) == null)
		if opts.is_empty(): return def.defaultOption
		var scored: Array = []
		for o in opts: scored.append([o, _optionCashForManager(inst, o)])
		dsort(scored, func(a, c): return cmpn(c[1], a[1]))
		var within: Array = scored.filter(func(e): return -e[1] <= l.policies.spendingLimit)
		var pool: Array = [scored[0]] if within.is_empty() else within
		match l.policies.stance:
			"frugal": return pool[0][0].id
			"quality": return pool[pool.size() - 1][0].id
		return pool[pool.size() / 2][0].id)

func _optionCashForManager(inst: M.IncidentInstance, o: Content.IncidentOption) -> int:
	var sum := 0
	for e in o.effects:
		if e.get("type") == "cash" and e.get("amount") != null and e.get("chance") == null:
			sum += _amount(e["amount"], inst)
		if e.get("type") == "repair" or e.get("type") == "replace":
			var eq := loc.equipmentById(inst.subjectId)
			if eq != null:
				sum -= roundi(content.equipment[eq.type].price * (1.0 if e["type"] == "replace" else 0.25))
	return sum

# ---------------------------------------------------------- weekly per outlet

func _weeklyOutlet(w: M.WeekRecord) -> void:
	var l := loc
	# Ledger (doc 02 §15.8).
	if w.operatingProfit > 0: l.returned += w.operatingProfit
	# Losing weeks and crisis (doc 02 §15.7), with an opening grace for new builds.
	var inGrace: bool = l.openDay > 0 and state.dayIndex - l.openDay < 7 * b.i("OPENING_GRACE_WEEKS") \
		and not any(l.weeks, func(x): return x.operatingProfit > 0)
	if w.operatingProfit >= 0:
		if l.crisis:
			state.pendingNotices.append("%s is out of trouble." % l.name)
			_story("Out of trouble")
		l.lossWeeks = 0
		l.crisis = false
	elif not inGrace:
		l.lossWeeks += 1
		if l.lossWeeks >= 4 and not l.crisis and state.locations.size() > 1:
			l.crisis = true
			state.pendingNotices.append("%s has lost money four weeks running: it is in trouble. Staff are worried about their jobs." % l.name)
			_story("In trouble after four losing weeks")
			for s in l.staff:
				s.moodMods.append(M.MoodMod.mk("Job security", -10, state.dayIndex + 28))
		if l.lossWeeks >= 8 and state.locations.size() > 1:
			_raiseIncident("inc_location_failing", null, null, true)
	# Manager's profit bonus.
	var m := l.manager
	if m != null and m.bonusPct > 0 and w.operatingProfit > 0:
		var bonus := roundi(w.operatingProfit * m.bonusPct / 100.0)
		spend(bonus, "wages")
	# Badges (doc 11 §D.1).
	var wasGold := l.badge == "gold"
	if w.operatingProfit > 0 and l.ownerDaysThisWeek <= 1:
		l.goldWeeks += 1
	else:
		l.goldWeeks = 0
	var badge := l.badge
	if l.invested > 0 and l.returned >= l.invested * 0.5 and badge == "":
		badge = "bronze"
		l.buzz = minf(1, l.buzz + 0.2)
	if l.invested > 0 and l.returned >= l.invested and l.reputation >= 4.0 and (badge == "bronze" or badge == ""):
		badge = "silver"
		for s in l.staff:
			s.loyalty = minf(100, s.loyalty + 5)
	if l.goldWeeks >= 8 and l.reputation >= 4.3 and badge != "gold":
		badge = "gold"
		l.buzz = minf(1, l.buzz + 0.4)
		l.competition = maxf(0, l.competition - 0.1)
		var perk := "perk_%s" % l.format
		if not state.perks.has(perk):
			state.perks[perk] = true
			state.pendingNotices.append("Chain perk earned: %s." % perkText.get(perk, perk))
	if wasGold and l.lossWeeks >= 4: badge = "silver"
	if badge != l.badge:
		var name := "" if badge.is_empty() else badge[0].to_upper() + badge.substr(1)
		if not badge.is_empty():
			state.pendingNotices.append("%s earned a %s badge." % [l.name, name])
			_story("%s badge" % name)
			_timeline("%s: %s badge" % [l.name, name])
		l.badge = badge
	l.managerCostWeek = 0
	l.managerSaveWeek = 0

func _weeklyChain() -> void:
	# Central kitchen running cost.
	if state.centralKitchen:
		at(state.openLocations[0], func(): spend(b.i("CENTRAL_KITCHEN_WEEKLY"), "other"))
	# Franchises pay their fees and sometimes embarrass the brand (doc 13).
	if state.franchises > 0:
		var fee := state.franchises * b.i("FRANCHISE_WEEKLY_FEE")
		state.cash += fee
		at(state.openLocations[0], func():
			loc.today.other -= fee
			_note("franchise", "Franchise fees: %s" % money(fee), 0))
		if _rng.chance(b.d("FRANCHISE_SCANDAL_CHANCE") * state.franchises):
			for l in state.openLocations:
				l.reputation = maxf(0, l.reputation - 0.1)
			state.pendingNotices.append("A franchisee served something awful and it went viral. Every outlet's rating fell by 0.1.")
			_timeline("Franchise scandal: every rating −0.1")

# ---------------------------------------------------------- travel

var _globalTick: int:
	get:
		var t := 0
		for l in state.openLocations:
			var s: M.ServiceState = l.service
			if s != null and s.tick > t: t = s.tick
		return t

func _travelTick() -> void:
	if not state.travelling: return
	if _globalTick >= state.travelUntilTick:
		state.ownerLocationId = state.travelTo
		state.viewLocationId = state.travelTo
		state.travelTo = -1
		var dest := state.locationById(state.ownerLocationId)
		if dest != null and dest.service != null:
			dest.service.ownerArea = state.owner.startArea if state.owner.startArea != null else "door"
		emit("ownerArrived", {"locationId": state.ownerLocationId})

func _ownerTravel(toId: int) -> CommandResult:
	var to := state.locationById(toId)
	if to == null or to.closedForGood: return CommandResult.fail(SimError.unknownId)
	if toId == state.ownerLocationId and not state.travelling: return CommandResult.good()
	if state.phase == "prep":
		state.ownerLocationId = toId
		state.viewLocationId = toId
		return CommandResult.good()
	if state.phase != "service": return CommandResult.fail(SimError.wrongPhase)
	if state.travelling: return CommandResult.fail(SimError.limitReached, "You are already on the road.")
	if state.owner.restingToday: return CommandResult.fail(SimError.locked, "You are resting today.")
	var from := state.locationById(state.ownerLocationId)
	if from != null and from.service != null:
		at(from, func():
			for id in ss.ownerQueue:
				var tk := ss.task(id)
				if tk != null: tk.reserved = false
			ss.ownerQueue.clear()
			ss.ownerArea = null)
	state.travelTo = toId
	state.travelUntilTick = _globalTick + b.i("TRAVEL_TICKS")
	state.owner.energy = maxf(0, state.owner.energy - b.d("TRAVEL_ENERGY"))
	emit("ownerTravelling", {"to": toId})
	return CommandResult.good()

# ---------------------------------------------------------- managers

func _generateManagerApplicants() -> void:
	state.managerApplicants.clear()
	var r := _companyRating()
	var grades := ["Trainee", "Junior", "Capable", "Senior", "Veteran"]
	var w := [30.0, 30.0, 25.0, maxf(0.0, 10 + 10 * (r - 3.5)), maxf(0.0, 5 + 10 * (r - 4.0))]
	var ranges := {"Trainee": [20, 34], "Junior": [35, 49], "Capable": [50, 64], "Senior": [65, 79], "Veteran": [80, 92]}
	var used := {}
	for l in state.locations:
		for s in l.staff: used[s.name] = true
	for i in 3:
		var g: String = _rng.weighted(grades, w)
		var mean := float(_rng.next_int(ranges[g][0], ranges[g][1]))
		var m := _makeManager(mean, used)
		state.managerApplicants.append(m)

func _makeManager(mean: float, used: Dictionary, profile = null) -> M.Staff:
	var prof: String = profile if profile != null else _rng.pick(managerProfiles.keys())
	var off: Array = managerProfiles[prof]
	var sub := func(i: int) -> float: return round(clampf(mean + off[i] + _rng.range_f(-5, 5), 5, 95))
	var m := _makeStaff("manager", mean, 60, 1, used)
	m.people = sub.call(0)
	m.upkeep = sub.call(1)
	m.stockSkill = sub.call(2)
	m.profile = prof
	m.potential = minf(95, m.managerSkill + _rng.next_int(5, 35))
	m.skill = round(m.managerSkill)
	m.wage = _expectedManagerWage(m.managerSkill)
	m.askingWage = m.wage
	m.dayOff = 7 # managers work every day the outlet is open (SPEC-GAP, doc 12)
	m.traits = []
	m.hiredDay = state.dayIndex
	m.lastLearnDay = state.dayIndex
	match m.grade:
		"Veteran": m.bonusPct = 5
		"Senior": m.bonusPct = 3
		"Capable": m.bonusPct = 1
		_: m.bonusPct = 0
	return m

func _hireManager(id: int) -> CommandResult:
	var a = first_or_null(state.managerApplicants, func(x): return x.id == id)
	if a == null: return CommandResult.fail(SimError.unknownId)
	if loc.manager != null: return CommandResult.fail(SimError.limitReached, "%s already has a manager." % loc.name)
	var r := _companyRating()
	if (a.grade == "Senior" and r < 3.5) or (a.grade == "Veteran" and r < 4.0):
		return CommandResult.fail(SimError.refused, "%s only joins companies rated %s stars or better." % [a.name, "4.0" if a.grade == "Veteran" else "3.5"])
	state.managerApplicants.erase(a)
	a.hiredDay = state.dayIndex
	a.lastLearnDay = state.dayIndex
	loc.staff.append(a)
	_story("%s became manager (%s)" % [a.name, a.grade])
	_timeline("%s: hired %s as manager (%s)" % [loc.name, a.name, a.grade])
	return CommandResult.good()

func _promoteToManager(staffId: int) -> CommandResult:
	var s := loc.staffById(staffId)
	if s == null: return CommandResult.fail(SimError.unknownId)
	if not ["server", "cashier", "headChef"].has(s.role) or s.skill < 60:
		return CommandResult.fail(SimError.invalidValue, "Only a server, cashier or head chef with skill 60+ can become a manager.")
	if loc.manager != null:
		return CommandResult.fail(SimError.limitReached, "This outlet already has a manager. Transfer them first.")
	var mean := 0.6 * s.skill + 10
	var m := _makeManager(mean, {}, "allRounder")
	if state.perks.has("perk_neighbourhood"):
		m.people = minf(95, m.people + 5)
	s.role = "manager"
	s.people = m.people
	s.upkeep = m.upkeep
	s.stockSkill = m.stockSkill
	s.profile = "allRounder"
	s.potential = minf(95, m.potential + 10)
	s.skill = round(s.managerSkill)
	s.wage = _expectedManagerWage(s.managerSkill)
	s.loyalty = minf(100, s.loyalty + 15)
	s.dayOff = 7
	s.lastLearnDay = state.dayIndex
	s.lastGrowthDay = state.dayIndex
	_story("%s promoted to manager" % s.name)
	_timeline("Promoted %s to manager at %s" % [s.name, loc.name])
	return CommandResult.good()

func _transfer(staffId: int, toId: int) -> CommandResult:
	var to := state.locationById(toId)
	var s := loc.staffById(staffId)
	if to == null or to.closedForGood: return CommandResult.fail(SimError.unknownId)
	if s == null: return CommandResult.fail(SimError.unknownId)
	if to.id == loc.id: return CommandResult.fail(SimError.invalidValue)
	if s.isManager and to.manager != null:
		return CommandResult.fail(SimError.limitReached, "%s already has a manager." % to.name)
	loc.staff.erase(s)
	to.staff.append(s)
	s.absentUntil = maxi(s.absentUntil, state.dayIndex + (2 if state.phase == "close" else 1))
	s.workingToday = false
	s.morale = maxf(0, s.morale - 5)
	s.moodMods.append(M.MoodMod.mk("New place", -3, state.dayIndex + 7))
	_story("%s moved to %s" % [s.name, to.name])
	var vl := state.locationById(state.viewLocationId)
	var fromName: String = vl.name if vl != null else "another outlet"
	at(to, func(): _story("%s arrived from %s" % [s.name, fromName]))
	return CommandResult.good()

func _answerRequest(id: int, answer: String) -> CommandResult:
	var r = first_or_null(state.requests, func(x): return x.id == id)
	if r == null: return CommandResult.fail(SimError.unknownId)
	var l := state.locationById(r.locationId)
	if l == null: return CommandResult.fail(SimError.unknownId)
	if answer == "deny":
		state.requests.erase(r)
		var m := l.manager
		if m != null: m.morale = maxf(0, m.morale - 2)
		return CommandResult.good()
	var cheaper: bool = answer == "cheaper" and r.cheaperCost != null
	var cost: int = r.cheaperCost if cheaper else r.cost
	var res: CommandResult = at(l, func() -> CommandResult:
		match r.kind:
			"repair":
				var e := l.equipmentById(r.subjectId)
				if e == null or not e.broken: return CommandResult.good()
				if state.cash < cost: return CommandResult.fail(SimError.notEnoughCash)
				var inst := M.IncidentInstance.new()
				inst.id = 0; inst.incidentId = "request"; inst.subjectId = e.id; inst.createdDay = state.dayIndex
				_applyEffect({"type": "repair", "mode": "cheap" if cheaper else "proper"}, inst, [])
				return CommandResult.good()
			"replace":
				var e := l.equipmentById(r.subjectId)
				if e == null: return CommandResult.good()
				return _buyEquipment(e.type, cheaper, e.id)
			"hire":
				var role_: String = r.subjectKey
				var cands: Array = state.applicants.filter(func(a): return a.role == role_ or (role_ == "lineCook" and a.role == "headChef"))
				dsort(cands, func(a, c): return cmpn(c.skill, a.skill))
				if cands.is_empty():
					return CommandResult.fail(SimError.unknownId, "No %s applied this week. New applicants come on Sunday." % roleName(role_).to_lower())
				return _hire(cands[0].id)
			"raise":
				var s := l.staffById(r.subjectId)
				if s == null: return CommandResult.good()
				var exp := _expectedWage(s.role, s.skill)
				return _setWage(s.id, roundi((s.wage + exp) / 2.0) if cheaper else exp)
			"marketing":
				return _startCampaign(r.subjectKey if r.subjectKey != null else "localAd")
			"training":
				var s := l.staffById(r.subjectId)
				if s == null or s.trainingUntil > state.dayIndex: return CommandResult.good()
				return _train(s.id)
			"promote":
				var s := l.staffById(r.subjectId)
				if s == null or s.role != "lineCook" or any(l.staff, func(o): return o.role == "headChef"):
					return CommandResult.good()
				return _promote(s.id)
		return CommandResult.good())
	if res.ok: state.requests.erase(r)
	return res

func _audit() -> CommandResult:
	if state.ownerLocationId != loc.id:
		return CommandResult.fail(SimError.locked, "You must be at %s to audit it." % loc.name)
	var cost := b.i("AUDIT_COST")
	if state.cash < cost: return CommandResult.fail(SimError.notEnoughCash)
	spend(cost, "other")
	var cheats: Array = loc.staff.filter(func(s): return s.honesty < 40 and (s.isManager or s.role == "cashier" or s.role == "server"))
	for s in cheats:
		s.daysWorked = maxi(s.daysWorked, 14)
	var text: String
	if cheats.is_empty():
		text = "The books are clean. Nobody is taking money."
	else:
		var names: Array = []
		for s in cheats: names.append("%s (%s)" % [s.name, roleName(s.role).to_lower()])
		text = "The audit found who is taking money: %s." % ", ".join(names)
	_note("audit", text, 0)
	return CommandResult.good(text)

# ---------------------------------------------------------- the outlet market

func _refreshOutletMarket() -> void:
	state.outletMarket.clear()
	var names: Array = theme.restaurantNames.duplicate()
	_rng.shuffle(names)
	var taken := {}
	for l in state.locations: taken[l.name] = true
	var free: Array = names.filter(func(n): return not taken.has(n))
	var factor := b.d("TAKEOVER_MARKET_PRICE_FACTOR")
	var ni := 0
	for tier in content.tiers:
		var saved := state.nextId
		var nm: String
		if free.is_empty():
			nm = "Outlet %d" % state.nextLocId
		else:
			nm = free[ni % free.size()]
			ni += 1
		var l := _generateLocation(tier, nm)
		state.nextId = maxi(saved, state.nextId)
		l.format = ("highStreet" if _rng.chance(0.5) else "officeDistrict") if (state.stage >= 3 and _rng.chance(0.4)) else "neighbourhood"
		l.rentWeekly = roundi(l.rentWeekly * _format(l).get("rentMult", 1.0))
		state.outletMarket.append(M.Offer.mk(tier.id, roundi(tier.price * factor), 0, l))
	state.sites.clear()
	var classes := ["weak", "average", "good", "prime"]
	for i in 3:
		var fmt: String = ["neighbourhood", "highStreet", "officeDistrict"][i]
		var sid := state.allocId()
		var cls: String = _rng.pick(classes)
		var area: String = _rng.pick(["North", "East", "River", "Market", "Station", "Park", "Old Town", "Harbour"])
		state.sites.append(M.Site.mk(sid, cls, fmt, "%s %s" % [area, "Business Park" if fmt == "officeDistrict" else ("High Street" if fmt == "highStreet" else "Corner")]))

func _weeklyFixed(l: M.Location) -> int:
	var w := 0
	for s in l.staff: w += s.wage * 6
	return l.rentWeekly + w + roundi(b.d("UTILITIES_BASE") * 7)

func _adopt(l: M.Location, invested: int, themeId = null) -> M.Location:
	l.id = state.nextLocId
	state.nextLocId += 1
	l.themeId = themeId if themeId != null else state.themeId
	l.invested = invested
	l.lastVisitDay = state.dayIndex
	l.originalTables = l.tableSeats.size()
	l.today = M.DayStats.mk(state.dayIndex)
	if l.format == "officeDistrict":
		l.deliveryOn = true
		state.perks["delivery_unlocked"] = true
	if not state.brands.has(l.themeId): state.brands.append(l.themeId)
	for s in l.staff:
		s.id = state.allocId()
		s.hiredDay = state.dayIndex
	for e in l.equipment:
		e.id = state.allocId()
	# A different cuisine needs its own menu and kitchen (doc 13: second brand).
	if l.themeId != state.themeId or any(l.menu.keys(), func(d): return content.dishes[d].theme != l.themeId and l.themeId != "mixed"):
		var th: Content.CuisineTheme = content.themes[l.themeId]
		l.menu.clear()
		for d in content.dishes_for(l.themeId):
			var mi := M.MenuItem.new()
			mi.dishId = d.id; mi.price = d.basePrice; mi.enabled = th.startingMenu == null or th.startingMenu.has(d.id)
			l.menu[d.id] = mi
		remove_where(l.equipment, func(e): return content.equipment[e.type].kind == "station")
		for e in th.startingEquipment["base"]:
			for i in e[1]:
				var q := M.Equipment.new()
				q.id = state.allocId(); q.type = e[0]; q.condition = 70; q.ageDays = 400
				l.equipment.append(q)
	state.locations.append(l)
	return l

func _buyOutlet(index: int, themeId) -> CommandResult:
	if state.stage < 3: return CommandResult.fail(SimError.locked, "Opening more outlets unlocks at Stage 3.")
	if index < 0 or index >= state.outletMarket.size(): return CommandResult.fail(SimError.unknownId)
	if themeId != null and themeId != state.themeId and state.stage < 5:
		return CommandResult.fail(SimError.locked, "A second brand (another cuisine) unlocks at Stage 5.")
	var o: M.Offer = state.outletMarket[index]
	var reserve := b.i("OPENING_RESERVE_WEEKS") * _weeklyFixed(o.location)
	if state.cash - o.price < reserve:
		return CommandResult.fail(SimError.notEnoughCash, "After paying %s you must keep %s (two weeks of its running costs). Cash now: %s." % [money(o.price), money(reserve), money(state.cash)])
	state.cash -= o.price
	state.outletMarket.remove_at(index)
	var l := _adopt(o.location, o.price, themeId)
	l.openDay = state.dayIndex + 1
	at(l, func():
		_activateHiddenProblems(l)
		_story("Bought for %s" % money(o.price)))
	_timeline("Bought a second-hand restaurant: %s (%s)" % [l.name, money(o.price)])
	state.pendingNotices.append("%s is yours. It trades from tomorrow. It needs a manager on days you are not there." % l.name)
	return CommandResult.good(l.id)

func _inspectOutlet(index: int) -> CommandResult:
	if index < 0 or index >= state.outletMarket.size(): return CommandResult.fail(SimError.unknownId)
	var o: M.Offer = state.outletMarket[index]
	if o.inspected: return CommandResult.fail(SimError.limitReached, "Already inspected.")
	var cost := b.i("DUE_DILIGENCE_COST")
	if state.cash < cost: return CommandResult.fail(SimError.notEnoughCash)
	state.cash -= cost
	o.inspected = true
	var hidden: Array = o.location.hidden.duplicate()
	_rng.shuffle(hidden)
	for k in ceili(hidden.size() / 2.0):
		hidden[k].revealed = true
	return CommandResult.good()

## Cost of building from scratch (doc 02 §15.9 route B), broken down for the UI.
func _buildCost(site: M.Site, size: String, fitOut: String, themeId: String) -> Dictionary:
	var cls: Content.LocationClass = content.locationClasses[site.classId]
	var sizeT: Dictionary = b.map("BUILD_SIZES")[size]
	var fitT: Dictionary = b.map("FIT_OUTS")[fitOut]
	var rent := roundi(cls.weeklyRent * float(sizeT["rent"]) * float(b.map("FORMATS")[site.format]["rentMult"]))
	var fit := roundi(float(fitT["cost"]) * float(sizeT["fitOut"]))
	var eq := 0
	var th: Content.CuisineTheme = content.themes[themeId]
	for e in th.startingEquipment["base"]:
		eq += content.equipment[e[0]].price * e[1]
	for t in ["eq_fridge", "eq_freezer", "eq_shelving", "eq_dish_machine", "eq_hood", "eq_pos"]:
		eq += content.equipment[t].price
	return {"fitOut": fit, "equipment": eq, "deposit": rent * 4, "licence": b.i("OPENING_LICENCE"), "rent": rent, "days": int(fitT["days"])}

func _buildOutlet(siteId: int, size: String, fitOut: String, themeId) -> CommandResult:
	if state.stage < 3: return CommandResult.fail(SimError.locked, "Opening more outlets unlocks at Stage 3.")
	var site = first_or_null(state.sites, func(s): return s.id == siteId)
	if site == null: return CommandResult.fail(SimError.unknownId)
	var th: String = themeId if themeId != null else state.themeId
	if th != state.themeId and state.stage < 5:
		return CommandResult.fail(SimError.locked, "A second brand (another cuisine) unlocks at Stage 5.")
	var c := _buildCost(site, size, fitOut, th)
	var upFront: int = c.fitOut + c.equipment + c.deposit + c.licence
	var sizeT: Dictionary = b.map("BUILD_SIZES")[size]
	var fitT: Dictionary = b.map("FIT_OUTS")[fitOut]
	var tables := int(sizeT["tables"])
	var staffWeek := 6 * (220 + 140 + 80 + 100 * 2 + 80)
	var reserve: int = b.i("OPENING_RESERVE_WEEKS") * (c.rent + staffWeek)
	if state.cash - upFront < reserve:
		return CommandResult.fail(SimError.notEnoughCash, "You need %s now plus %s in reserve." % [money(upFront), money(reserve)])
	state.cash -= upFront
	state.sites.erase(site)
	var six := maxi(1, roundi(tables * 0.15))
	var four := roundi(tables * 0.45)
	var seats: Array = []
	for i in tables - six - four: seats.append(2)
	for i in four: seats.append(4)
	for i in six: seats.append(6)
	var l := M.Location.new()
	l.id = 0; l.name = site.name; l.tierId = "good"; l.classId = site.classId; l.rentWeekly = c.rent
	l.tableSeats = seats; l.reputation = b.d("SCRATCH_START_RATING"); l.hygiene = 95
	l.buzz = float(fitT["buzz"]); l.freshness = 1; l.awareness = b.d("SCRATCH_START_AWARENESS")
	l.format = site.format
	for ing in content.ingredients.values():
		l.priceIndex[ing.id] = state.loc.priceIndex.get(ing.id, 1.0)
	for s in content.suppliers.values():
		l.supplierRel[s.id] = 50
	var thm: Content.CuisineTheme = content.themes[th]
	for e in thm.startingEquipment["base"]:
		for i in e[1]:
			var q := M.Equipment.new()
			q.id = 0; q.type = e[0]; q.condition = 100
			l.equipment.append(q)
	for t in ["eq_fridge", "eq_freezer", "eq_shelving", "eq_dish_machine", "eq_hood", "eq_pos"]:
		var q := M.Equipment.new()
		q.id = 0; q.type = t; q.condition = 100
		l.equipment.append(q)
	# An opening crew recruited during the fit-out (paid from the opening day).
	var used := {}
	for x in state.locations:
		for s in x.staff: used[s.name] = true
	var centre := 20 + 10 * _companyRating()
	for role_ in ["headChef", "lineCook", "lineCook", "dishwasher", "server", "server", "cleaner"]:
		var skill := round(_rng.triangular(15, 90, clampf(centre, 20, 80)))
		l.staff.append(_makeStaff(role_, skill, 65, 1, used))
	_assignDaysOff(l.staff)
	_adopt(l, upFront, th)
	l.openDay = state.dayIndex + c.days
	at(l, func(): _story("Lease signed; fit-out started (%s)" % money(upFront)))
	_timeline("Started building %s; opens on day %d" % [l.name, l.openDay + 1])
	state.pendingNotices.append("Work has started on %s. Rent is due from today; it opens on day %d." % [l.name, l.openDay + 1])
	return CommandResult.good(l.id)

# ---------------------------------------------------------- selling and closing

func _saleEstimate() -> int:
	var l := loc
	var resale := 0
	for e in l.equipment: resale += _equipmentResale(e)
	var ws: Array = l.weeks if l.weeks.size() <= 8 else l.weeks.slice(l.weeks.size() - 8)
	var avg := 0
	if not ws.is_empty():
		var a := 0
		for w in ws: a += w.operatingProfit
		avg = a / ws.size()
	var est: int = resale + b.i("SALE_PROFIT_MULT") * maxi(0, avg) + roundi(10000 * l.reputation)
	est = roundi(est * (1 + {"bronze": 0.05, "silver": 0.10, "gold": 0.20}.get(l.badge, 0.0)))
	if l.crisis: est = roundi(est * 0.6)
	return est

func _sellCheck() -> CommandResult:
	if state.openLocations.size() < 2: return CommandResult.fail(SimError.locked, "You cannot sell your only restaurant.")
	if loc.leaseLockUntil > state.dayIndex: return CommandResult.fail(SimError.locked, "The 2-year lease lock-in forbids selling.")
	if loc.closedUntil > state.dayIndex: return CommandResult.fail(SimError.locked, "Not while it is closed by an inspector.")
	return CommandResult.good()

func _completeSale(amount: int) -> void:
	var l := loc
	state.cash += amount
	# A loan secured on this outlet is paid first (the starting loan is secured on the first).
	if l.id == state.locations[0].id:
		for loan in state.loans.filter(func(x): return x.secured):
			var pay := mini(loan.outstanding, state.cash)
			state.cash -= pay
			loan.outstanding -= pay
			if loan.outstanding <= 0: state.loans.erase(loan)
	for p in l.payables:
		state.cash -= p.amount
	l.payables.clear()
	_retire(l, "Sold for %s" % money(amount))

func _retire(l: M.Location, why: String) -> void:
	l.closedForGood = true
	l.service = null
	l.listedDay = -1
	remove_where(state.requests, func(r): return r.locationId == l.id)
	remove_where(state.incidents, func(i): return i.locationId == l.id and not i.resolved)
	at(l, func(): _story(why))
	_timeline("%s: %s" % [l.name, why])
	if state.ownerLocationId == l.id:
		state.ownerLocationId = state.openLocations[0].id
	if state.viewLocationId == l.id:
		state.viewLocationId = state.ownerLocationId

func _quickSale() -> CommandResult:
	var chk := _sellCheck()
	if not chk.ok: return chk
	var amount := roundi(_saleEstimate() * 0.7)
	_completeSale(amount)
	return CommandResult.good(amount)

func _closeOutlet() -> CommandResult:
	if state.openLocations.size() < 2: return CommandResult.fail(SimError.locked, "You cannot close your only restaurant.")
	var l := loc
	var resale := 0
	for e in l.equipment: resale += _equipmentResale(e)
	var severance := 0
	for s in l.staff: severance += s.wage * b.i("SEVERANCE_DAYS")
	var fee := l.rentWeekly * 4
	state.cash += resale - severance - fee
	_retire(l, "Closed (equipment sold %s, severance %s, lease fee %s)" % [money(resale), money(severance), money(fee)])
	return CommandResult.good()

func _renovate(tables: int) -> CommandResult:
	var l := loc
	if tables <= 0 or tables % 2 != 0: return CommandResult.fail(SimError.invalidValue, "Add tables in pairs.")
	var mx := (l.tableSeats.size() if l.originalTables == 0 else l.originalTables) * 1.5
	if l.tableSeats.size() + tables > mx:
		return CommandResult.fail(SimError.limitReached, "The room fits at most %d tables." % floori(mx))
	var cost := tables * b.i("RENOVATION_COST_PER_TABLE")
	if state.cash < cost: return CommandResult.fail(SimError.notEnoughCash, "Renovation costs %s." % money(cost))
	spend(cost, "upkeep")
	for i in tables:
		l.tableSeats.append(4 if i % 2 == 0 else 2)
	var days := ceili(tables / 4.0)
	var from := state.dayIndex + 1 if state.phase == "close" else state.dayIndex
	l.closedUntil = maxi(l.closedUntil, from + days)
	l.buzz = minf(1, l.buzz + 0.3)
	l.competition = maxf(0, l.competition - 0.1)
	l.invested += cost
	_story("Renovated: +%d tables" % tables)
	return CommandResult.good()

# ---------------------------------------------------------- stage 4–5 systems

func _buildCentralKitchen() -> CommandResult:
	if state.stage < 4: return CommandResult.fail(SimError.locked, "A central kitchen unlocks at Stage 4 (Chain).")
	if state.centralKitchen: return CommandResult.fail(SimError.limitReached, "You already have one.")
	var cost := b.i("CENTRAL_KITCHEN_COST")
	if state.cash < cost: return CommandResult.fail(SimError.notEnoughCash, "A central kitchen costs %s." % money(cost))
	state.cash -= cost
	state.centralKitchen = true
	_timeline("Built a central kitchen")
	return CommandResult.good()

func _signBulk() -> CommandResult:
	if state.stage < 4: return CommandResult.fail(SimError.locked, "Bulk contracts unlock at Stage 4 (Chain).")
	if state.bulkContractUntil > state.dayIndex: return CommandResult.fail(SimError.limitReached, "A contract is already running.")
	var fee := b.i("BULK_CONTRACT_FEE")
	if state.cash < fee: return CommandResult.fail(SimError.notEnoughCash)
	state.cash -= fee
	state.bulkContractUntil = state.dayIndex + 26 * 7
	if state.openLocations.size() >= 3: _completeObjective("obj_4_bulk")
	_timeline("Signed a 26-week bulk contract")
	return CommandResult.good()

func _startFranchise() -> CommandResult:
	if state.stage < 5: return CommandResult.fail(SimError.locked, "Franchising unlocks at Stage 5 (Group).")
	if not any(state.openLocations, func(l): return l.badge == "gold"):
		return CommandResult.fail(SimError.locked, "Buyers want proof the recipe works without you: earn a gold badge first.")
	state.franchises += 1
	var fee := b.i("FRANCHISE_SIGNING_FEE")
	state.cash += fee
	_timeline("Sold franchise number %d (%s)" % [state.franchises, money(fee)])
	return CommandResult.good(fee)

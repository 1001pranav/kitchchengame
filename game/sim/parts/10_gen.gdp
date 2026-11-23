
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

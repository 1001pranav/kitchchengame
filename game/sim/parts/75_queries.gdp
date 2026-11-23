
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


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
				var s := l.service
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
	var sv := l.service
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

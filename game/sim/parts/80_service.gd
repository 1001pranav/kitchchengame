
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
	var s := loc.service
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
	var s := loc.service
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

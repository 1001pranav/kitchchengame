# Hand-written methods injected into the generated model classes.
EXTRA = {
"Staff": '''
	func hasTrait(t: String) -> bool:
		return traits.has(t)
	var skillKnown: bool:
		get: return daysWorked >= 7
	var reliabilityKnown: bool:
		get: return daysWorked >= 7
	var honestyKnown: bool:
		get: return daysWorked >= 14
	var isCook: bool:
		get: return role == "headChef" or role == "lineCook"
	var isManager: bool:
		get: return role == "manager"
	var managerSkill: float:
		get: return (people + upkeep + stockSkill) / 3
	var grade: String:
		get:
			var m := managerSkill
			if m < 35: return "Trainee"
			if m < 50: return "Junior"
			if m < 65: return "Capable"
			if m < 80: return "Senior"
			return "Veteran"
	var isKitchen: bool:
		get: return role == "headChef" or role == "lineCook" or role == "prepCook" or role == "dishwasher"
''',
"MoodMod": '''
	static func mk(k: String, s: float, u: int) -> MoodMod:
		var m := MoodMod.new(); m.key = k; m.score = s; m.untilDay = u; return m
''',
"Batch": '''
	static func mk(i: String, q: int, qu: int, d: int) -> Batch:
		var b := Batch.new(); b.ingredientId = i; b.qty = q; b.quality = qu; b.daysLeft = d; return b
''',
"Payable": '''
	static func mk(i: int, s, a: int, d: int, l: String, inh: bool) -> Payable:
		var p := Payable.new(); p.id = i; p.supplierId = s; p.amount = a; p.dueDay = d; p.label = l; p.inherited = inh; return p
''',
"Loan": '''
	var interestDue: int:
		get: return roundi(outstanding * weeklyRate)
	var instalment: int:
		get:
			if outstanding <= 0: return 0
			var p := roundi(float(principal0) / termWeeks + outstanding * weeklyRate)
			var cap := outstanding + interestDue
			return cap if p > cap else p
''',
"Campaign": '''
	var spend: int:
		get: return cost + discountGiven
	var returnOnSpend:
		get: return null if spend == 0 else extraProfit / spend
''',
"Mod": '''
	static func mk(k: String, m: float, u: int) -> Mod:
		var o := Mod.new(); o.key = k; o.mult = m; o.untilDay = u; return o
''',
"ParLevel": '''
	static func mk(p: int, s: String) -> ParLevel:
		var o := ParLevel.new(); o.par = p; o.supplierId = s; return o
''',
"HiddenProblem": '''
	static func mk(k: String) -> HiddenProblem:
		var o := HiddenProblem.new(); o.kind = k; return o
''',
"Group": '''
	var waiting: bool:
		get: return state == "waitTable" or state == "waitOrder" or state == "waitFood" or state == "waitBill"
	var gone: bool:
		get: return state == "left" or state == "walkedOut"
''',
"TableRt": '''
	static func mk(i: int, s: int) -> TableRt:
		var o := TableRt.new(); o.id = i; o.seats = s; return o
''',
"Ticket": '''
	static func mk(i: int, g: int, d: String) -> Ticket:
		var o := Ticket.new(); o.id = i; o.groupId = g; o.dishId = d; return o
''',
"Task": '''
	var started: bool:
		get: return assignee != null
''',
"Arrival": '''
	static func mk(t: int, s: int, seg: String, crit := false, deliv := false) -> Arrival:
		var o := Arrival.new(); o.tick = t; o.size = s; o.segment = seg; o.critic = crit; o.delivery = deliv; return o
''',
"ServiceState": '''
	func group(id) -> Group:
		if id == null: return null
		for g in groups:
			if g.id == id: return g
		return null
	func table(id) -> TableRt:
		if id == null: return null
		for t in tables:
			if t.id == id: return t
		return null
	func ticket(id) -> Ticket:
		if id == null: return null
		for t in tickets:
			if t.id == id: return t
		return null
	func task(id) -> Task:
		if id == null: return null
		for t in tasks:
			if t.id == id: return t
		return null
''',
"DayEvent": '''
	static func mk(k: String, t: String, v: int) -> DayEvent:
		var o := DayEvent.new(); o.kind = k; o.text = t; o.value = v; return o
''',
"DayStats": '''
	static func mk(d: int) -> DayStats:
		var o := DayStats.new(); o.dayIndex = d; return o
	var walkouts: int:
		get: return walkTable + walkOrder + walkFood + walkBill
	var costs: int:
		get: return ingredientSpend + wages + rent + utilities + upkeep + marketing + other
	var profit: int:
		get: return revenue - costs
	var avgStars: float:
		get: return 0.0 if starsN == 0 else starsSum / starsN
	func add(kind: String, text: String, value := 0) -> void:
		events.append(DayEvent.mk(kind, text, value))
''',
"WeekRecord": '''
	var netProfit: int:
		get: return operatingProfit - interest
''',
"Scheduled": '''
	static func mk(inc: String, d: int, sid = null, skey = null, lid := 1) -> Scheduled:
		var o := Scheduled.new(); o.incidentId = inc; o.day = d; o.subjectId = sid; o.subjectKey = skey; o.locationId = lid; return o
''',
"SaleOffer": '''
	static func mk(a: int, e: int) -> SaleOffer:
		var o := SaleOffer.new(); o.amount = a; o.expiresDay = e; return o
''',
"Site": '''
	static func mk(i: int, c: String, f: String, n: String) -> Site:
		var o := Site.new(); o.id = i; o.classId = c; o.format = f; o.name = n; return o
''',
"Location": '''
	func staffById(id) -> Staff:
		if id == null: return null
		for s in staff:
			if s.id == id: return s
		return null
	func equipmentById(id) -> Equipment:
		if id == null: return null
		for e in equipment:
			if e.id == id: return e
		return null
	var manager: Staff:
		get:
			for s in staff:
				if s.role == "manager": return s
			return null
	var trading: bool:
		get: return not closedForGood
	func stockOf(ingredient_id: String) -> int:
		var n := 0
		for b in stock:
			if b.ingredientId == ingredient_id: n += b.qty
		return n
''',
"Offer": '''
	static func mk(t: String, p: int, l: int, loc: Location) -> Offer:
		var o := Offer.new(); o.tierId = t; o.price = p; o.loan = l; o.location = loc; return o
''',
"TimelineEntry": '''
	static func mk(d: int, t: String) -> TimelineEntry:
		var o := TimelineEntry.new(); o.day = d; o.text = t; return o
''',
"GameState": '''
	var loc: Location:
		get: return locations[0]
	func locationById(id: int) -> Location:
		for l in locations:
			if l.id == id: return l
		return null
	var viewLoc: Location:
		get:
			var l := locationById(viewLocationId)
			return l if l != null else locations[0]
	var openLocations: Array:
		get: return locations.filter(func(l): return not l.closedForGood)
	var travelling: bool:
		get: return travelTo >= 0
	var hasLocation: bool:
		get: return not locations.is_empty()
	var weekday: int:
		get: return posmod(dayIndex, 7)
	var weekIndex: int:
		get: return dayIndex / 7
	var dayOfMonth: int:
		get: return posmod(dayIndex, 28) + 1
	var month: int:
		get: return posmod(dayIndex / 28, 12) + 1
	var year: int:
		get: return dayIndex / 336 + 1
	var season: String:
		get: return ["spring", "summer", "autumn", "winter"][(month - 1) / 3]
	func flag(k: String) -> bool:
		return flags.get(k, -1) >= dayIndex
	func allocId() -> int:
		nextId += 1
		return nextId - 1
	var totalOutstanding: int:
		get:
			var a := 0
			for l in loans: a += l.outstanding
			return a
	var openIncidents: Array:
		get: return incidents.filter(func(i): return not i.resolved)
''',
}

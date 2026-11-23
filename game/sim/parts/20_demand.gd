
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
			var portions := people * perPerson * d.popularity / totalPop
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

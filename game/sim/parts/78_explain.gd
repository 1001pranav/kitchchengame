
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

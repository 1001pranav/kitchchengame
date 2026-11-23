
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

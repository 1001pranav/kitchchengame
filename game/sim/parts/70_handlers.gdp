
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

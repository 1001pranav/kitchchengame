
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

part of '../sim.dart';

// Day orchestration: prep (beginDay) and close (endDay) in the exact order of doc 02 §3.

extension _Day on Sim {
  void _beginDay() {
    final l = loc;
    state.phase = 'prep';
    state.today = DayStats(dayIndex: state.dayIndex);
    l.service = null;
    if (state.weekday == 0) state.owner.restDaysThisWeek = 0;
    // Yearly cost creep notice (doc 11 §A.4).
    if (state.dayIndex > 0 && state.dayIndex % 336 == 0) {
      state.pendingNotices.add(
          'A new year: wages people expect and ingredient prices have gone up about 3%. Customers will accept prices about 3% higher too.');
    }
    // Owner rest.
    state.owner.restingToday = state.owner.forcedRestDay == state.dayIndex;
    if (state.owner.restingToday) {
      state.pendingNotices.add(
          'You are exhausted and must rest today. The team runs the shift without you.');
    }
    for (final m in l.menu.values) {
      m.soldYesterday = m.soldToday;
      m.soldToday = 0;
      m.unavailableToday = 0;
    }
    l.demandMods.removeWhere((m) => m.untilDay < state.dayIndex);
    state.flags.removeWhere((k, v) => v < state.dayIndex);
    // Campaign outcomes are revealed the next morning (doc 02 §13.1).
    for (final c in l.campaigns) {
      if (!c.revealed && c.startDay < state.dayIndex && c.type != 'blogger') {
        c.revealed = true;
        state.pendingNotices.add(c.reason);
      }
    }
    // 2. Deliveries and bills due.
    _processDeliveries();
    _payPayables();
    // 3. Absences.
    _rollAttendance();
    // 4. Prices.
    _updatePrices();
    // Scheduled state changes from hidden problems.
    for (final sc in List<Scheduled>.of(state.scheduled)) {
      if (sc.day > state.dayIndex) continue;
      if (sc.incidentId == '@flag:pests') {
        state.scheduled.remove(sc);
        state.flags['pests'] = 1 << 30;
      } else if (sc.incidentId == '@fake_reviews') {
        state.scheduled.remove(sc);
        l.reputation = math.max(0, l.reputation - 0.5);
        state.pendingNotices.add(
            'A review site removed dozens of fake 5-star reviews the last owner had bought. Your rating fell by 0.5.');
        _note('fakeReviews', 'Fake reviews removed: rating −0.5', 50);
        _timeline('Fake reviews removed: rating −0.5');
        _markHidden('fake_reviews');
      }
    }
    if (_rng.chance(b.d('GAS_LOW_CHANCE'))) {
      state.flags['gas_low'] = state.dayIndex;
    }
    // 5. Overnight incidents: forced/scheduled first, then up to two rolls.
    _incidentsAtPrep();
    if (state.flag('ill_guest')) {
      state.flags.remove('ill_guest');
      _raiseIncident('inc_food_poisoning', forced: true);
    }
    // 6. Forecast.
    state.today.forecast = _forecast().groups;
    emit('dayStarted', {'day': state.dayIndex});
  }

  // ---------------------------------------------------------- close

  void _closeDay() {
    final l = loc;
    final t = state.today;
    final closedToday = l.closedUntil > state.dayIndex;
    // Fixed costs accrue every day (paid in cash weekly / monthly).
    final d = state.weekday;
    t.rent =
        (l.rentWeekly * (d + 1) / 7).round() - (l.rentWeekly * d / 7).round();
    final working = l.equipment.where(_isWorking).length;
    final util = b.d('UTILITIES_BASE') +
        b.d('UTILITIES_PER_GROUP') * t.groupsServed +
        b.d('UTILITIES_PER_UNIT') * working;
    t.utilities = util.round();
    state.monthUtilities += t.utilities;
    // Skimming by a dishonest cashier nobody caught.
    final skimmer = l.staff
        .where((s) => s.workingToday && s.role == 'cashier' && s.honesty < 40)
        .firstOrNull;
    if (skimmer != null && t.revenue > 0) {
      final lost = (t.revenue * b.d('SKIM_PCT')).round();
      state.cash -= lost;
      t.other += lost;
      _note('skim', 'Cash in the till was ${money(lost)} short of sales', lost);
    }
    // 2. Stock.
    _ageStock();
    // 3. Equipment wear and breakdowns.
    _equipmentClose();
    // 4. Hygiene.
    _hygieneClose(closedToday);
    // 5. Staff.
    _staffClose();
    // 6. Owner energy.
    _ownerClose();
    // 7. Reputation.
    _reputationClose();
    // 8. Marketing, buzz, freshness.
    _lifecycleClose();
    // Close-timing incidents.
    _rollIncidents('close');
    // Par levels (stage 2).
    _autoOrder();
    // 9. Weekly.
    if (state.weekday == 6) _weekly();
    // 10. Monthly.
    if (state.dayOfMonth == 28) _monthly();
    _checkObjectives();
    // 11. Bankruptcy.
    _bankruptcyCheck();
    state.cashHistory.add(state.cash);
    if (state.cashHistory.length > 56) state.cashHistory.removeAt(0);
    emit('dayClosed', {'profit': t.profit});
  }

  double _maxCondition(Equipment e) => math
      .max(b.d('MAX_CONDITION_FLOOR'),
          b.d('MAX_CONDITION_START') - 5 * (e.ageDays ~/ 168))
      .toDouble();

  double _breakChance(Equipment e) {
    var p = b.d('BREAK_BASE') +
        math.max(0, 60 - e.condition) / b.d('BREAK_COND_DIVISOR');
    if (e.fragileUntil >= state.dayIndex) p += b.d('CHEAP_REPAIR_FAIL_PER_DAY');
    return p;
  }

  void _equipmentClose() {
    final l = loc;
    final busy =
        state.today.groupsArrived > 1.2 * math.max(1, state.today.forecast);
    for (final e in l.equipment) {
      e.ageDays++;
      if (e.broken) continue;
      final t = content.equipment[e.type]!;
      e.condition = math.max(0, e.condition - t.wearPerDay * (busy ? 1.5 : 1));
      if (_rng.chance(_breakChance(e))) {
        e.broken = true;
        _note('breakdown', '${t.name} broke down', t.price ~/ 10);
        _timeline('${t.name} broke down');
        emit('equipmentBroke', {'equipmentId': e.id});
        state.scheduled.add(
            Scheduled('inc_breakdown', state.dayIndex + 1, subjectId: e.id));
      }
    }
  }

  void _hygieneClose(bool closed) {
    final l = loc;
    var h = l.hygiene;
    h -= state.today.groupsServed * b.d('HYGIENE_PER_GROUP');
    final cleaners =
        l.staff.where((s) => s.workingToday && s.role == 'cleaner').toList();
    var sum = 0.0;
    for (final c in cleaners) {
      sum += 0.5 + c.skill / 100;
    }
    if (cleaners.isEmpty) {
      // Stand-in: the dishwasher cleans at half effect.
      for (final w
          in l.staff.where((s) => s.workingToday && s.role == 'dishwasher')) {
        sum += 0.5 * (0.5 + (w.skill - 15) / 100);
      }
    }
    h += b.d('HYGIENE_CLEAN_PCT') * (100 - h) * sum;
    if (!closed &&
        !l.staff.any((s) => s.workingToday && s.role == 'dishwasher')) {
      h -= 5;
    }
    if (!_hasWorking('eq_hood')) h -= 5;
    if (state.flag('pests')) h -= 8;
    if (state.flag('leak')) h -= 10;
    l.hygiene = h.clamp(0, 100).toDouble();
  }

  void _ownerClose() {
    final o = state.owner;
    if (o.restingToday) {
      o.energy = 100;
      o.zeroEnergyDays = 0;
      o.restDaysThisWeek++;
      return;
    }
    if (o.energy <= 0.5) {
      o.zeroEnergyDays++;
    } else {
      o.zeroEnergyDays = 0;
    }
    if (o.zeroEnergyDays >= 3) {
      o.forcedRestDay = state.dayIndex + 1;
      o.zeroEnergyDays = 0;
      _note(
          'ownerExhausted',
          'You worked yourself to exhaustion: tomorrow is a forced rest day',
          0);
    }
    o.energy = math.min(100, o.energy + b.d('OWNER_RECOVERY'));
  }

  void _reputationClose() {
    final l = loc;
    final t = state.today;
    if (t.starsN <= 0) return;
    final avg = t.starsSum / t.starsN;
    final weight = math.min(1.0, t.starsN / 20);
    final k = avg > l.reputation ? b.d('REP_UP') : b.d('REP_DOWN');
    l.reputation = (l.reputation + (avg - l.reputation) * k * weight)
        .clamp(0, 5)
        .toDouble();
  }

  void _lifecycleClose() {
    final l = loc;
    // Buzz decay, keeping each campaign's share in proportion.
    final b0 = l.buzz;
    l.buzz = math.max(0, l.buzz - b.d('BUZZ_DECAY'));
    for (final c in l.campaigns) {
      c.buzzLeft = b0 <= 0 ? 0 : c.buzzLeft * l.buzz / b0;
    }
    l.freshness = math.max(0, l.freshness - b.d('FRESHNESS_DECAY'));
    final aw = b.d('AWARENESS_GAIN') *
        (0.5 + l.buzz) *
        math.min(1.5, l.reputation / 3.5);
    l.awareness = math.min(1, l.awareness + aw);
    _campaignAccounting();
  }

  // ---------------------------------------------------------- objectives and stages

  void _markHidden(String kind) {
    for (final hp in loc.hidden) {
      if (hp.kind == kind) hp.done = true;
    }
  }

  void _updateHiddenProblems() {
    final l = loc;
    for (final hp in l.hidden) {
      if (hp.done) continue;
      switch (hp.kind) {
        case 'supplier_debt':
          if (!l.payables.any((p) => p.inherited)) hp.done = true;
        case 'chef_leaving':
          final chef = l.staff.where((s) => s.role == 'headChef').firstOrNull;
          if (chef == null ||
              chef.morale >= 60 ||
              state.dayIndex > hp.dueDay + 7) {
            hp.done = true;
          }
        case 'pests':
          if (state.dayIndex > hp.dueDay && !state.flag('pests')) {
            hp.done = true;
          }
        case 'fridge_failing':
          if (l.equipment
              .where((e) => e.type == 'eq_fridge')
              .every((e) => e.condition >= 50 && !e.broken)) {
            hp.done = true;
          }
        case 'cashier_skimming':
          if (!l.staff.any((s) => s.role == 'cashier' && s.honesty < 40)) {
            hp.done = true;
          }
        case 'staff_feud':
          if (!state.flag('feud')) hp.done = true;
        case 'health_violation':
        case 'overdue_licence':
        case 'lease_increase':
        case 'fake_reviews':
          break; // marked when their incident resolves
      }
    }
  }

  void _completeObjective(String id) {
    if (state.objectivesDone.contains(id)) return;
    final obj = content.objectives.where((o) => o.id == id).firstOrNull;
    if (obj == null || obj.stage > state.stage) return;
    state.objectivesDone.add(id);
    for (final r in obj.reward) {
      switch (r['type']) {
        case 'cash':
          earn((r['amount'] as num).toInt(), 'none');
        case 'reputation':
          loc.reputation =
              math.min(5, loc.reputation + (r['delta'] as num).toDouble());
        case 'loyalty':
          for (final s in loc.staff) {
            s.loyalty =
                math.min(100, s.loyalty + (r['delta'] as num).toDouble());
          }
        case 'flag':
          state.flags[r['key'] as String] = 1 << 30;
      }
    }
    state.pendingNotices
        .add('Goal complete: ${obj.text}. Reward: ${obj.rewardText}.');
    _timeline('Goal complete: ${obj.text}');
    emit('objectiveDone', {'id': id});
  }

  void _checkObjectives() {
    final l = loc;
    final t = state.today;
    _updateHiddenProblems();
    if (t.profit > 0 && !t.closed) _completeObjective('obj_1_first_profit');
    final s = l.service;
    if (s != null && !state.owner.restingToday) {
      bool covered(List<String> rs) =>
          l.staff.any((x) => x.workingToday && rs.contains(x.role));
      final allCovered = covered(['headChef', 'lineCook']) &&
          covered(['server']) &&
          covered(['cashier']) &&
          covered(['dishwasher']) &&
          covered(['cleaner']);
      final served = s.tick > 0 ? 1 - t.ownerTasks * 2 / s.tick : 0;
      if (allCovered && served >= 0.5 && t.groupsServed > 0) {
        _completeObjective('obj_1_full_rota');
      }
    }
    if (l.hidden.isNotEmpty &&
        l.hidden.every((h) => h.done) &&
        state.dayIndex > 0) {
      _completeObjective('obj_1_clear_problems');
    }
    if (l.reputation >= 4.0) _completeObjective('obj_2_four_star');
    if (state.flag('promoted_trained_chef')) {
      _completeObjective('obj_2_train_chef');
    }
  }

  void _checkStage() {
    if (state.stage == 1 &&
        state.profitableWeeksInRow >= b.i('STAGE2_PROFIT_WEEKS') &&
        loc.reputation >= b.d('STAGE2_REP')) {
      state.stage = 2;
      state.pendingNotices.add('@stage2');
      _timeline('Reached Stage 2: Stable');
      emit('stageReached', {'stage': 2});
    } else if (state.stage == 2 &&
        state.cash >= b.i('STAGE3_CASH') &&
        loc.reputation >= b.d('STAGE3_REP') &&
        state.dayIndex - state.lastMissDay > 56) {
      state.stage = 3;
      state.pendingNotices.add('@stage3');
      _timeline('Ready to expand: Stage 3 reached');
      emit('stageReached', {'stage': 3});
    }
  }
}

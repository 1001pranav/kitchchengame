part of '../sim.dart';

// Staff: rota, absence, happiness, fatigue, quitting, hiring, training (doc 02 §7).

extension _Staff on Sim {
  bool _rosteredToday(Staff s) {
    if (s.trainingUntil > state.dayIndex) return false;
    if (s.workDayOffDay == state.dayIndex) return true;
    return s.dayOff != state.weekday;
  }

  double _outletHappiness() {
    if (loc.staff.isEmpty) return 50;
    return loc.staff.fold(0.0, (a, s) => a + s.morale) / loc.staff.length;
  }

  /// Rolls absence and lateness at prep (doc 02 §7.4).
  void _rollAttendance() {
    for (final s in loc.staff) {
      s.workingToday = false;
      s.absentToday = false;
      s.lateTick = 0;
      s.rushToday = false;
      s.tipsToday = 0;
      if (!_rosteredToday(s)) continue;
      if (s.absentUntil > state.dayIndex) {
        s.absentToday = true;
        continue;
      }
      var p = (100 - s.reliability) / b.d('ABSENCE_DIVISOR');
      if (s.fatigue > 80) p += 0.05;
      if (s.morale < 30) p += 0.05;
      if (lf('festival_refused') && _festivalOn(state.dayIndex) != null) {
        p *= 2;
      }
      if (lf('festival_absence') && _festivalOn(state.dayIndex) != null) {
        p += (state.flags['${loc.id}:festival_absence_pct'] ?? 0) / 100;
      }
      if (_rng.chance(p)) {
        s.absentToday = true;
        state.pendingNotices
            .add('${s.name} (${roleName(s.role)}) is absent today.');
        _note('absent', '${s.name} (${roleName(s.role)}) did not come in', 1);
        emit('staffAbsent', {'staffId': s.id});
        continue;
      }
      s.workingToday = true;
      var pLate = (100 - s.reliability) / 300;
      if (s.hasTrait('trait_often_late')) pLate *= 2;
      if (_rng.chance(pLate)) {
        s.lateTick = _rng.nextInt(15, 60);
        _note('late', '${s.name} arrived late (${_clock(s.lateTick)})', 0);
      }
    }
  }

  /// Every happiness factor for one person (doc 02 §7.3). The same function sets the target.
  Map<String, double> _happinessFactors(Staff s) {
    final f = <String, double>{};
    final exp = _expectedWage(s.role, s.skill) *
        math.pow(b.d('YEARLY_COST_CREEP_WAGE'), state.dayIndex ~/ 336);
    f['Pay'] = ((s.wage - exp) / exp * 100).clamp(-20, 10).toDouble();
    if (s.fatigue > 50) {
      f['Tiredness'] = math.max(-15, -0.3 * (s.fatigue - 50));
    } else if (s.fatigue < 30) {
      f['Tiredness'] = 3;
    }
    var rest = 0.0;
    if (s.dayOff == s.preferredDayOff) rest += 3;
    if (s.workedDayOffWeek == state.weekIndex) rest -= 5;
    f['Rest'] = rest;
    if (s.recentRush.isNotEmpty) {
      f['Short-staffed shifts'] =
          -10 * s.recentRush.where((x) => x == 1).length / s.recentRush.length;
    }
    var team = 0.0;
    if (loc.staff.any((o) =>
        o.id != s.id && o.role == s.role && o.hasTrait('trait_mentor'))) {
      team += 3;
    }
    if (loc.staff.any((o) => o.id != s.id && o.hasTrait('trait_toxic'))) {
      team -= 5;
    }
    f['Team'] = team;
    final mgr = loc.manager;
    if (mgr != null && mgr != s && state.ownerLocationId != loc.id) {
      f['Boss'] = ((mgr.people - 50) / 5).clamp(-10, 10).toDouble();
    } else {
      f['Boss'] = state.owner.restDaysThisWeek >= 7 ? 0 : 3;
    }
    var growth = 0.0;
    final since = state.dayIndex - s.lastGrowthDay;
    if (since < 28) growth += 5;
    final limit = s.hasTrait('trait_ambitious') ? 56 : 112;
    if (s.skill > 60 && since > limit && state.dayIndex - s.hiredDay > limit) {
      growth -= s.hasTrait('trait_ambitious') ? 10 : 5;
    }
    f['Growth'] = growth;
    var cond = 0.0;
    if (!_hasWorking('eq_ac') && loc.tierId != 'bad' && loc.tierId != 'worst') {
      cond -= state.season == 'summer' ? 8 : 4;
    } else if (!_hasWorking('eq_ac') && state.season == 'summer') {
      cond -= 4;
    }
    if (s.isKitchen && !_hasWorking('eq_hood')) cond -= 4;
    if (s.isCook &&
        loc.equipment.any((e) =>
            content.equipment[e.type]!.kind == 'station' &&
            e.condition < 40 &&
            !e.broken)) {
      cond -= 3;
    }
    if (loc.hygiene < 50) cond -= 3;
    f['Working conditions'] = cond;
    var rec = 0.0;
    if (s.recentTips.isNotEmpty) {
      rec += math.min(
          5, s.recentTips.reduce((a, c) => a + c) / s.recentTips.length / 20);
    }
    f['Recognition'] = rec;
    if (s.hasTrait('trait_loyal')) f['Personal'] = 3;
    for (final m in s.moodMods) {
      if (m.untilDay >= state.dayIndex) f[m.key] = (f[m.key] ?? 0) + m.score;
    }
    f.removeWhere((k, v) => v == 0);
    return f;
  }

  double _happinessTarget(Staff s) =>
      (50 + _happinessFactors(s).values.fold(0.0, (a, v) => a + v))
          .clamp(0, 100)
          .toDouble();

  void _staffClose() {
    final today = loc.today;
    // Tips split among those who worked.
    final worked = loc.staff.where((s) => s.workingToday).toList();
    if (worked.isNotEmpty && today.tips > 0) {
      final each = today.tips ~/ worked.length;
      for (final s in worked) {
        s.tipsToday = each;
      }
    }
    final rush = loc.service?.rushRoles ?? <String>{};
    final metTarget =
        loc.service != null && loc.service!.lost <= loc.service!.target;
    for (final s in List<Staff>.of(loc.staff)) {
      // Wages accrue for days worked; paid on Sunday.
      if (s.workingToday) {
        final overtime =
            s.dayOff == state.weekday && s.workDayOffDay == state.dayIndex;
        final festivalPay =
            lf('festival_double_pay') && _festivalOn(state.dayIndex) != null
                ? 2
                : 1;
        final pay =
            (s.wage * (overtime ? b.d('OVERTIME_MULT') : 1) * festivalPay)
                .round();
        loc.today.wages += pay;
        state.wagesOwed += pay; // paid in cash on Sunday
        s.daysWorked++;
        s.consecutiveDays++;
        // SPEC-GAP: doc 02 §7.2 gives +12 per worked day and −30 per day off, which nets
        // +42 a week and pins everyone at 100 within two weeks. A night's sleep also
        // recovers FATIGUE_OVERNIGHT (balance-log entry 13).
        final wasRush = rush.contains(s.role);
        final gain = b.d('FATIGUE_WORK') + (wasRush ? b.d('FATIGUE_RUSH') : 0);
        if (!s.isManager) {
          s.fatigue += gain * (s.hasTrait('trait_hard_worker') ? 0.7 : 1) -
              b.d('FATIGUE_OVERNIGHT');
        }
        s.recentRush.add(wasRush ? 1 : 0);
        if (s.recentRush.length > 7) s.recentRush.removeAt(0);
        s.recentTips.add(s.tipsToday);
        if (s.recentTips.length > 7) s.recentTips.removeAt(0);
        if (metTarget) s.morale += b.d('TARGET_MET_MORALE');
        if (s.daysWorked == 7) {
          state.pendingNotices.add(
              'You now know ${s.name}\'s true skill (${s.skill.round()}) and reliability.');
        }
      } else if (!_rosteredToday(s) || s.trainingUntil > state.dayIndex) {
        s.fatigue -= b.d('FATIGUE_REST') + b.d('FATIGUE_OVERNIGHT');
        s.consecutiveDays = 0;
      } else {
        s.fatigue -= b.d('FATIGUE_REST') +
            b.d('FATIGUE_OVERNIGHT'); // absent: they rested
      }
      s.fatigue = s.fatigue.clamp(0, 100).toDouble();
      final target = _happinessTarget(s);
      s.morale += (target - s.morale) * b.d('HAPPINESS_SPEED');
      s.morale = s.morale.clamp(0, 100).toDouble();
      s.moodMods.removeWhere((m) => m.untilDay < state.dayIndex);
      if (s.hasTrait('trait_light_fingered')) {
        s.honesty = math.min(s.honesty, 30);
      }
      // Training finished.
      if (s.trainingUntil == state.dayIndex + 1) {
        state.pendingNotices.add('${s.name} is back from training.');
      }
      // Notice period.
      if (s.status == 'notice') {
        s.noticeLeft--;
        if (s.noticeLeft <= 0) {
          _removeStaff(s, '${s.name} worked their last day and left');
          continue;
        }
      }
      // Quitting (doc 02 §7.5).
      if (s.status == 'active') {
        final quitMult = s.hasTrait('trait_loyal') ? 0.5 : 1.0;
        final pQuit = math.max(0, 30 - s.morale) /
            300 *
            (1 - s.loyalty / 200) *
            quitMult *
            (1 -
                0.5 *
                    (loc.manager == null ? 0 : _mastery(loc.manager!.people)));
        if (pQuit > 0 && _rng.chance(pQuit)) {
          var pNo = diff('NO_NOTICE_BASE') +
              (40 - s.morale) / 100 +
              (50 - s.loyalty) / 200;
          if (s.deniedUntil >= state.dayIndex) pNo += 0.10;
          pNo = pNo.clamp(0.02, 0.90);
          if (_rng.chance(pNo)) {
            final reasons =
                (_happinessFactors(s).entries.where((e) => e.value < 0).toList()
                      ..sort((a, c) => a.value.compareTo(c.value)))
                    .take(3)
                    .map((e) => e.key.toLowerCase())
                    .join(', ');
            state.pendingNotices.add(
                '${s.name} did not come in and is not answering. They have quit without notice. (Unhappy about: ${reasons.isEmpty ? 'many things' : reasons}.)');
            _removeStaff(
                s, '${s.name} (${roleName(s.role)}) quit without notice');
            emit('staffWalkedOut', {'name': s.name});
          } else {
            _raiseIncident('inc_resignation', subjectId: s.id, forced: true);
          }
        }
      }
    }
  }

  void _removeStaff(Staff s, String why) {
    loc.staff.remove(s);
    _note('staffLeft', why, 1);
    _timeline(why);
  }

  String roleName(String role) =>
      const {
        'headChef': 'Head chef',
        'lineCook': 'Line cook',
        'prepCook': 'Prep cook',
        'dishwasher': 'Dishwasher',
        'server': 'Server',
        'cashier': 'Cashier',
        'cleaner': 'Cleaner',
        'manager': 'Manager',
      }[role] ??
      role;

  // ------------------------------------------------------------ commands

  CommandResult _hire(int applicantId) {
    final a = state.applicants.where((x) => x.id == applicantId).firstOrNull;
    if (a == null) {
      return CommandResult.fail(SimError.unknownId, 'That applicant has gone.');
    }
    if (loc.staff.length >= b.i('MAX_STAFF')) {
      return CommandResult.fail(SimError.limitReached,
          'The kitchen and floor cannot fit more people.');
    }
    state.applicants.remove(a);
    a.hiredDay = state.dayIndex;
    a.wage = a.askingWage;
    a.morale = 60;
    // Day off: the weekday with the fewest people off, Mon–Thu first.
    final offCount = List<int>.filled(7, 0);
    for (final s in loc.staff) {
      offCount[s.dayOff]++;
    }
    var best = 0;
    for (var d = 0; d < 7; d++) {
      final sameRole = loc.staff.any((s) => s.role == a.role && s.dayOff == d);
      final score = offCount[d] + (sameRole ? 10 : 0) + (d >= 4 ? 5 : 0);
      final bestScore = offCount[best] +
          (loc.staff.any((s) => s.role == a.role && s.dayOff == best)
              ? 10
              : 0) +
          (best >= 4 ? 5 : 0);
      if (score < bestScore) best = d;
    }
    a.dayOff = best;
    loc.staff.add(a);
    _timeline('Hired ${a.name} as ${roleName(a.role).toLowerCase()}');
    emit('staffHired', {'staffId': a.id});
    return const CommandResult(true);
  }

  CommandResult _fire(int staffId) {
    final s = loc.staffById(staffId);
    if (s == null) return CommandResult.fail(SimError.unknownId);
    final severance = s.wage * b.i('SEVERANCE_DAYS');
    spend(severance, 'wages');
    final toxic = s.hasTrait('trait_toxic');
    loc.staff.remove(s);
    for (final o in loc.staff) {
      o.moodMods.add(MoodMod('Team', toxic ? 5 : -5, state.dayIndex + 14));
    }
    _note(
        'fired', 'Fired ${s.name} (severance ${money(severance)})', severance);
    _timeline('Fired ${s.name}');
    return const CommandResult(true);
  }

  CommandResult _setWage(int staffId, int wage) {
    final s = loc.staffById(staffId);
    if (s == null) return CommandResult.fail(SimError.unknownId);
    if (wage <= 0 || wage > 2000) {
      return CommandResult.fail(SimError.invalidValue);
    }
    if (wage > s.wage) {
      s.lastGrowthDay = state.dayIndex;
      s.moodMods.add(MoodMod('Recognition', 3, state.dayIndex + 14));
    } else if (wage < s.wage) {
      s.morale = math.max(0, s.morale - 15);
      s.deniedUntil = state.dayIndex + 14;
    }
    s.wage = wage;
    return const CommandResult(true);
  }

  CommandResult _train(int staffId) {
    final s = loc.staffById(staffId);
    if (s == null) return CommandResult.fail(SimError.unknownId);
    if (s.trainingUntil > state.dayIndex) {
      return CommandResult.fail(SimError.limitReached, 'Already training.');
    }
    if (s.skill >= 95) {
      return CommandResult.fail(SimError.limitReached,
          '${s.name} is as good as training can make them.');
    }
    final cost = (b.d('TRAIN_COST_PER_SKILL') * s.skill).round();
    if (state.cash < cost) {
      return CommandResult.fail(
          SimError.notEnoughCash, 'Training costs ${money(cost)}.');
    }
    spend(cost, 'other');
    final start = state.phase == 'close' ? state.dayIndex + 1 : state.dayIndex;
    s.trainingUntil = start + b.i('TRAIN_DAYS');
    var gain = _rng.nextInt(5, 10).toDouble();
    if (s.hasTrait('trait_fast_learner')) gain *= 1.5;
    s.skill = math.min(95, s.skill + gain).roundToDouble();
    s.morale = math.min(100, s.morale + 5);
    s.lastGrowthDay = state.dayIndex;
    s.trainedByOwner = true;
    if (state.phase == 'prep') s.workingToday = false;
    _note('training', 'Sent ${s.name} on a course (${money(cost)})', cost);
    return CommandResult(true, value: gain.round());
  }

  CommandResult _setDayOff(int staffId, int weekday) {
    final s = loc.staffById(staffId);
    if (s == null) return CommandResult.fail(SimError.unknownId);
    if (weekday < 0 || weekday > 6) {
      return CommandResult.fail(SimError.invalidValue);
    }
    s.dayOff = weekday;
    return const CommandResult(true);
  }

  CommandResult _workDayOff(int staffId) {
    final s = loc.staffById(staffId);
    if (s == null) return CommandResult.fail(SimError.unknownId);
    final day = state.phase == 'close' ? state.dayIndex + 1 : state.dayIndex;
    if (s.dayOff != day % 7) {
      return CommandResult.fail(
          SimError.invalidValue, 'That is not ${s.name}\'s day off.');
    }
    if (s.fatigue > 70 || s.morale < 35) {
      return CommandResult.fail(
          SimError.refused, '${s.name} says no: too tired or too unhappy.');
    }
    if (s.lastWorkDayOffWeek >= day ~/ 7 - 1) {
      return CommandResult.fail(
          SimError.refused, 'Nobody can be asked two weeks running.');
    }
    s.workDayOffDay = day;
    s.lastWorkDayOffWeek = day ~/ 7;
    s.workedDayOffWeek = day ~/ 7;
    if (state.phase == 'prep' && s.absentUntil <= state.dayIndex) {
      s.workingToday = true;
    }
    return const CommandResult(true);
  }

  CommandResult _giveDayOff(int staffId) {
    final s = loc.staffById(staffId);
    if (s == null) return CommandResult.fail(SimError.unknownId);
    if (state.phase != 'prep') {
      return CommandResult.fail(
          SimError.wrongPhase, 'Give a day off during prep.');
    }
    if (!s.workingToday) {
      return CommandResult.fail(
          SimError.invalidValue, '${s.name} is not working today anyway.');
    }
    s.workingToday = false;
    s.fatigue = math.max(0, s.fatigue - 30);
    s.moodMods.add(MoodMod('Rest', 3, state.dayIndex + 7));
    return const CommandResult(true);
  }

  CommandResult _warn(int staffId) {
    final s = loc.staffById(staffId);
    if (s == null) return CommandResult.fail(SimError.unknownId);
    s.warnings++;
    s.morale = math.max(0, s.morale - 8);
    s.reliability = math.min(100, s.reliability + 5);
    return const CommandResult(true);
  }

  CommandResult _promote(int staffId) {
    final s = loc.staffById(staffId);
    if (s == null) return CommandResult.fail(SimError.unknownId);
    if (s.role != 'lineCook') {
      return CommandResult.fail(SimError.invalidValue,
          'Only a line cook can be promoted to head chef (managers come with more outlets).');
    }
    if (loc.staff.any((o) => o.role == 'headChef')) {
      return CommandResult.fail(
          SimError.limitReached, 'You already have a head chef.');
    }
    s.role = 'headChef';
    s.wage = math.max(s.wage, _expectedWage('headChef', s.skill));
    s.lastGrowthDay = state.dayIndex;
    s.morale = math.min(100, s.morale + 10);
    if (s.trainedByOwner &&
        !state.objectivesDone.contains('obj_2_train_chef')) {
      state.flags['promoted_trained_chef'] = 1 << 30;
    }
    _timeline('Promoted ${s.name} to head chef');
    return const CommandResult(true);
  }
}

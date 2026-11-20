part of '../sim.dart';

// Incident engine: conditions, effects, rolls, cooldowns, forced, follow-ups (doc 02 §11, doc 05 §2).

/// Every condition key the evaluator understands. The validator rejects others.
const conditionKeys = {
  'stageMin',
  'stageMax',
  'dayMin',
  'weekday',
  'season',
  'cashBelow',
  'cashAbove',
  'reputationBelow',
  'reputationAbove',
  'hygieneBelow',
  'hygieneAbove',
  'flag',
  'notFlag',
  'hasStaff',
  'hasEquipment',
  'noEquipmentWorking',
  'ownerIdleTicks',
  'ownerEnergyBelow',
  'stat',
  'any',
  'tablesAtLeast',
  'tickAfter',
  'groupWaitFoodShare',
  'festivalInDays',
  'seasonChangeDay',
  'hasGenerator',
  'noGenerator',
  'payableOverdue',
};

/// Every effect type the applier understands.
const effectTypes = {
  'cash',
  'reputation',
  'hygiene',
  'morale',
  'mood',
  'staffStat',
  'staffStatus',
  'staffLeaves',
  'staffFired',
  'setWage',
  'equipment',
  'stock',
  'demand',
  'patience',
  'closeLocation',
  'flag',
  'followUp',
  'inspection',
  'ownerEnergy',
  'payable',
  'reveal',
  'log',
  'repair',
  'replace',
  'inspect',
  'lifeline',
  'priceSpike',
  'raisePrices',
  'eightySixCostliest',
  'stationOff',
  'noSeating',
  'billSlow',
  'roleSlow',
  'ownerBusy',
  'groupSatisfaction',
  'rejectBatch',
  'refundOrder',
  'supplierRel',
  'supplierBlock',
  'supplierCashOnly',
  'payPayables',
  'supplierDeal',
  'rent',
  'leaseLock',
  'competition',
  'shortage',
  'dayOffChange',
  'removeTrait',
  'critic',
  'bigBooking',
  'filmCrew',
  'festivalLeave',
  'festivalPay',
  'train',
  'none',
  'cancelResignation',
  'noticeLeave',
  'scheduleInspection',
  'clearFlag',
  'markHidden',
};

extension _Incidents on Sim {
  // ---------------------------------------------------------- conditions

  bool _staffMatches(Staff s, Map<String, dynamic> f) {
    if (f['role'] != null) {
      final r = f['role'];
      if (r is List) {
        if (!r.contains(s.role)) return false;
      } else if (s.role != r) {
        return false;
      }
    }
    if (f['trait'] != null && !s.hasTrait(f['trait'] as String)) return false;
    if (f['moraleBelow'] != null && s.morale >= (f['moraleBelow'] as num))
      return false;
    if (f['moraleAbove'] != null && s.morale <= (f['moraleAbove'] as num))
      return false;
    if (f['fatigueAbove'] != null && s.fatigue <= (f['fatigueAbove'] as num))
      return false;
    if (f['honestyBelow'] != null && s.honesty >= (f['honestyBelow'] as num))
      return false;
    if (f['skillAbove'] != null && s.skill <= (f['skillAbove'] as num))
      return false;
    if (f['reliabilityBelow'] != null &&
        s.reliability >= (f['reliabilityBelow'] as num)) return false;
    if (f['absentToday'] == true && !s.absentToday) return false;
    if (f['working'] == true && !s.workingToday) return false;
    if (f['underpaid'] == true &&
        s.wage >= _expectedWage(s.role, s.skill) * 0.9) return false;
    if (f['wrongDayOff'] == true && s.dayOff == s.preferredDayOff) return false;
    if (f['statusActive'] == true && s.status != 'active') return false;
    return true;
  }

  bool _equipmentMatches(Equipment e, Map<String, dynamic> f) {
    final t = content.equipment[e.type]!;
    if (f['type'] != null && e.type != f['type']) return false;
    if (f['kind'] != null && t.kind != f['kind']) return false;
    if (f['conditionBelow'] != null &&
        e.condition >= (f['conditionBelow'] as num)) return false;
    if (f['broken'] != null && e.broken != f['broken']) return false;
    if (f['working'] == true && !_isWorking(e)) return false;
    return true;
  }

  bool _cond(Map<String, dynamic> c) {
    final l = loc;
    for (final entry in c.entries) {
      final v = entry.value;
      switch (entry.key) {
        case 'stageMin':
          if (state.stage < (v as num)) return false;
        case 'stageMax':
          if (state.stage > (v as num)) return false;
        case 'dayMin':
          if (state.dayIndex < (v as num)) return false;
        case 'weekday':
          if (!(v as List).contains(state.weekday)) return false;
        case 'season':
          if (!(v as List).contains(state.season)) return false;
        case 'cashBelow':
          if (state.cash >= (v as num)) return false;
        case 'cashAbove':
          if (state.cash <= (v as num)) return false;
        case 'reputationBelow':
          if (l.reputation >= (v as num)) return false;
        case 'reputationAbove':
          if (l.reputation <= (v as num)) return false;
        case 'hygieneBelow':
          if (l.hygiene >= (v as num)) return false;
        case 'hygieneAbove':
          if (l.hygiene <= (v as num)) return false;
        case 'flag':
          if (!state.flag(v as String)) return false;
        case 'notFlag':
          if (state.flag(v as String)) return false;
        case 'hasStaff':
          final f = (v as Map).cast<String, dynamic>();
          final n = l.staff.where((s) => _staffMatches(s, f)).length;
          if (n < ((f['count'] as num?) ?? 1)) return false;
        case 'hasEquipment':
          final f = (v as Map).cast<String, dynamic>();
          if (!l.equipment.any((e) => _equipmentMatches(e, f))) return false;
        case 'noEquipmentWorking':
          if (_hasWorking(v as String)) return false;
        case 'hasGenerator':
          if (!_hasWorking('eq_generator')) return false;
        case 'noGenerator':
          if (_hasWorking('eq_generator')) return false;
        case 'ownerIdleTicks':
          if (l.service == null || l.service!.ownerIdleTicks < (v as num))
            return false;
        case 'ownerEnergyBelow':
          if (state.owner.energy >= (v as num)) return false;
        case 'tablesAtLeast':
          if (l.tableSeats.length < (v as num)) return false;
        case 'tickAfter':
          if (l.service == null || l.service!.tick < (v as num)) return false;
        case 'groupWaitFoodShare':
          final s = l.service;
          if (s == null) return false;
          final ok = s.groups.any((g) =>
              g.state == 'waitFood' &&
              g.counter > _patienceLimit(g) * (v as num));
          if (!ok) return false;
        case 'festivalInDays':
          final f = _festivalOn(state.dayIndex + (v as num).toInt());
          if (f == null ||
              _festivalOn(state.dayIndex + (v).toInt() - 1) != null)
            return false;
        case 'seasonChangeDay':
          if (state.dayIndex == 0 || state.dayIndex % 84 != 0) return false;
        case 'payableOverdue':
          if (!l.payables.any((p) => p.dueDay < state.dayIndex)) return false;
        case 'stat':
          final m = (v as Map).cast<String, dynamic>();
          final x = _stat(m['name'] as String);
          if (m['below'] != null && x >= (m['below'] as num)) return false;
          if (m['above'] != null && x <= (m['above'] as num)) return false;
        case 'any':
          if (!(v as List)
              .any((x) => _cond((x as Map).cast<String, dynamic>())))
            return false;
        default:
          throw StateError('Unknown condition key ${entry.key}');
      }
    }
    return true;
  }

  double _stat(String name) {
    final t = state.today;
    switch (name) {
      case 'walkoutShare':
        return t.groupsArrived == 0 ? 0 : t.walkouts / t.groupsArrived;
      case 'walkouts':
        return t.walkouts.toDouble();
      case 'groupsServed':
        return t.groupsServed.toDouble();
      case 'wastePct':
        return t.revenue == 0 ? 0 : t.wasteCost / t.revenue;
      case 'profitWeek':
        return state.weeks.isEmpty ? 0 : state.weeks.last.netProfit.toDouble();
      case 'supplierRelMin':
        return loc.supplierRel.values.fold(100, math.min).toDouble();
    }
    return 0;
  }

  // ---------------------------------------------------------- raising

  /// Binds a subject and creates an instance. Returns null if no subject fits.
  IncidentInstance? _raiseIncident(String id,
      {int? subjectId,
      String? subjectKey,
      bool forced = false,
      Map<String, int>? vars}) {
    final def = content.incidents[id];
    if (def == null) return null;
    if (state.phase == 'gameOver') return null;
    // One open card per incident type.
    if (state.openIncidents
        .any((i) => i.incidentId == id && i.subjectId == subjectId))
      return null;
    final inst = IncidentInstance(
        id: state.allocId(),
        incidentId: id,
        createdDay: state.dayIndex,
        vars: vars);
    if (def.subject == 'staff') {
      var s = loc.staffById(subjectId);
      if (s == null) {
        final cands = loc.staff
            .where((x) => _staffMatches(
                x,
                ((def.subjectFilter?['hasStaff'] as Map?) ?? {})
                    .cast<String, dynamic>()))
            .toList();
        if (cands.isEmpty) return null;
        s = _rng.pick(cands);
      }
      s = s!;
      inst.subjectId = s.id;
      inst.subjectName = s.name;
    } else if (def.subject == 'equipment') {
      var e = loc.equipmentById(subjectId);
      if (e == null) {
        final cands = loc.equipment
            .where((x) => _equipmentMatches(
                x,
                ((def.subjectFilter?['hasEquipment'] as Map?) ?? {})
                    .cast<String, dynamic>()))
            .toList();
        if (cands.isEmpty) return null;
        e = _rng.pick(cands);
      }
      e = e!;
      inst.subjectId = e.id;
      inst.subjectName = content.equipment[e.type]!.name;
    } else if (def.subject == 'supplier') {
      final sid = subjectKey ?? 'sup_standard';
      inst.subjectKey = sid;
      inst.subjectName = content.suppliers[sid]?.name ?? sid;
    } else if (def.subject == 'ingredient') {
      final cats = content.ingredients.values
          .where((i) => i.category == 'produce')
          .toList();
      final ing = subjectKey != null
          ? content.ingredients[subjectKey]!
          : _rng.pick(cats);
      inst.subjectKey = ing.id;
      inst.subjectName = ing.name;
    } else if (def.subject == 'category') {
      final cats = ['produce', 'dairy', 'meat_fish', 'dry'];
      final cat = subjectKey ?? _rng.pick(cats);
      inst.subjectKey = cat;
      inst.subjectName = const {
        'produce': 'vegetables',
        'dairy': 'dairy',
        'meat_fish': 'meat and fish',
        'dry': 'dry goods'
      }[cat]!;
    } else if (subjectKey != null) {
      inst.subjectKey = subjectKey;
    }
    if (def.id == 'inc_festival_leave') {
      final f = _festivalOn(state.dayIndex + 3);
      inst.subjectName = f?.name ?? 'the festival';
    }
    if (def.id == 'inc_day_off_request') {
      final s = loc.staffById(inst.subjectId)!;
      inst.vars['weekday'] = s.preferredDayOff;
    }
    // Service incidents get a countdown; the UI pauses and shows the card.
    if (state.phase == 'service') inst.countdown = b.i('INCIDENT_COUNTDOWN');
    state.incidents.add(inst);
    state.cooldowns[id] = state.dayIndex + def.cooldownDays;
    _note('incident', _fill(def.title, inst), 0);
    emit('incidentRaised', {'instanceId': inst.id, 'incidentId': id});
    // Auto-resolution: a working generator handles a power cut on its own.
    if (id == 'inc_power_cut' && _hasWorking('eq_generator')) {
      _resolveIncident(inst, 'generator');
    }
    return inst;
  }

  void _incidentsAtPrep() {
    // Scheduled (hidden problems, follow-ups, breakdowns, inspections).
    for (final sc in List<Scheduled>.of(state.scheduled)) {
      if (sc.day > state.dayIndex || sc.incidentId.startsWith('@')) continue;
      state.scheduled.remove(sc);
      if (sc.incidentId == 'inc_resignation') {
        final s = loc.staffById(sc.subjectId);
        if (s == null ||
            s.status != 'active' ||
            (sc.subjectKey != 'force' && s.morale >= 60)) continue;
        _raiseIncident('inc_resignation', subjectId: s.id, forced: true);
        continue;
      }
      if (sc.incidentId == 'inc_breakdown') {
        final e = loc.equipmentById(sc.subjectId);
        if (e == null || !e.broken) continue;
      }
      _raiseIncident(sc.incidentId,
          subjectId: sc.subjectId, subjectKey: sc.subjectKey, forced: true);
    }
    // Forced-by-condition incidents.
    for (final def in content.incidents.values) {
      if (!def.forced || def.timing != 'prep' || def.trigger.isEmpty) continue;
      if ((state.cooldowns[def.id] ?? -1) >= state.dayIndex) continue;
      if (_cond(def.trigger)) _raiseIncident(def.id, forced: true);
    }
    // Random inspection chance (about once per 8 weeks).
    if (_rng.chance(1 / b.d('INSPECTION_EVERY_DAYS')) &&
        (state.cooldowns['inc_inspection'] ?? -1) < state.dayIndex) {
      _raiseIncident('inc_inspection', forced: true);
    }
    for (var i = 0; i < 2; i++) {
      _rollIncidents('prep');
    }
  }

  void _rollIncidents(String timing) {
    final eligible = <IncidentDef>[];
    final weights = <double>[];
    final idle = loc.service?.ownerIdleTicks ?? 999;
    for (final def in content.incidents.values) {
      if (def.timing != timing || def.forced || def.weight <= 0) continue;
      if ((state.cooldowns[def.id] ?? -1) >= state.dayIndex) continue;
      if (def.tags.contains('observation') && idle < 10) continue;
      if (state.openIncidents.any((i) => i.incidentId == def.id)) continue;
      if (!_cond(def.trigger)) continue;
      var w = def.weight;
      if (def.id == 'inc_staff_conflict' && state.flag('feud')) w *= 3;
      if (def.id == 'inc_power_cut' && state.season == 'summer') w *= 2;
      if (timing == 'service') w /= 12;
      eligible.add(def);
      weights.add(w);
    }
    if (eligible.isEmpty) return;
    final total = weights.fold(0.0, (a, w) => a + w);
    if (!_rng.chance(math.min(0.9, total * diff('DIFF_INCIDENTS')))) return;
    final def = _rng.weighted(eligible, weights);
    _raiseIncident(def.id);
  }

  // ---------------------------------------------------------- resolving

  String _fill(String text, IncidentInstance inst) {
    var t = text
        .replaceAll('{staff}', inst.subjectName)
        .replaceAll('{equipment}', inst.subjectName)
        .replaceAll('{supplier}', inst.subjectName)
        .replaceAll('{ingredient}', inst.subjectName)
        .replaceAll('{category}', inst.subjectName)
        .replaceAll('{festival}', inst.subjectName);
    if (inst.vars['weekday'] != null)
      t = t.replaceAll('{weekday}', _weekdayName(inst.vars['weekday']!));
    final s = loc.staffById(inst.subjectId);
    if (s != null) {
      t = t.replaceAll('{role}', roleName(s.role).toLowerCase());
      t = t.replaceAll('{dayWage}', money(s.wage));
    }
    final e = loc.equipmentById(inst.subjectId);
    if (e != null) {
      final p = content.equipment[e.type]!.price;
      t = t
          .replaceAll('{cheap}', money(p * 0.10))
          .replaceAll('{proper}', money(p * 0.25))
          .replaceAll('{new}', money(p))
          .replaceAll('{used}', money(p * 0.5))
          .replaceAll('{emergency}', money(p * 0.4))
          .replaceAll('{service}', money(p * 0.1));
    }
    t = t.replaceAll('{deficit}',
        money(math.max(0, -state.cash) + b.i('EMERGENCY_LOAN_EXTRA')));
    return t;
  }

  String _weekdayName(int d) => const [
        'Mondays',
        'Tuesdays',
        'Wednesdays',
        'Thursdays',
        'Fridays',
        'Saturdays',
        'Sundays'
      ][d];

  /// Why an option cannot be chosen right now, or null.
  String? _optionBlocked(IncidentOption o, IncidentInstance inst) {
    if (o.requires != null && !_cond(o.requires!))
      return o.hint ?? 'Not possible right now';
    for (final e in o.effects) {
      if (e['type'] == 'cash' && e['chance'] == null && e['amount'] != null) {
        final amt = _amount(e['amount'], inst);
        if (amt < 0 && state.cash + amt < 0 && !(e['allowDebt'] == true))
          return 'Not enough cash';
      }
      if (e['type'] == 'lifeline' &&
          e['kind'] == 'investor' &&
          state.investorTaken) return 'Only once per game';
      if (e['type'] == 'lifeline' &&
          e['kind'] == 'sellEquipment' &&
          loc.equipment.isEmpty) return 'Nothing to sell';
      if (e['type'] == 'repair' || e['type'] == 'replace') {
        final eq = loc.equipmentById(inst.subjectId);
        if (eq == null) return 'Already gone';
        final p = content.equipment[eq.type]!.price;
        final k = e['type'] == 'replace'
            ? (e['secondHand'] == true ? 0.5 : 1.0)
            : (b.map('REPAIR')[e['mode']] as Map)['cost'] as num;
        if (state.cash < p * k) return 'Not enough cash';
      }
    }
    return null;
  }

  int _amount(dynamic a, IncidentInstance inst) {
    if (a is num) return a.round();
    final s = a as String;
    double k = 1;
    var key = s;
    if (s.contains('*')) {
      final parts = s.split('*');
      key = parts[0];
      k = double.parse(parts[1]);
    }
    final staff = loc.staffById(inst.subjectId);
    final eq = loc.equipmentById(inst.subjectId);
    switch (key) {
      case 'dayWage':
        return ((staff?.wage ?? 100) * k).round();
      case 'weekWage':
        return ((staff?.wage ?? 100) * 7 * k).round();
      case 'eqPrice':
        return ((eq == null ? 3000 : content.equipment[eq.type]!.price) * k)
            .round();
      case 'dayRevenue':
        return (math.max(state.today.revenue,
                    state.days.isEmpty ? 1000 : state.days.last.revenue) *
                k)
            .round();
      case 'rent':
        return (loc.rentWeekly * k).round();
      case 'orderTotal':
        return ((inst.vars['total'] ?? 0) * k).round();
    }
    throw StateError('Unknown amount expression $s');
  }

  void _resolveIncident(IncidentInstance inst, String optionId,
      {bool ignored = false}) {
    if (inst.resolved) return;
    final def = content.incidents[inst.incidentId]!;
    var opt = def.options.where((o) => o.id == optionId).firstOrNull ??
        def.options.firstWhere((o) => o.id == def.defaultOption);
    if (_optionBlocked(opt, inst) != null && opt.id != def.defaultOption) {
      opt = def.option(def.defaultOption);
    }
    inst.resolved = true;
    inst.chosen = opt.id;
    final lines = <String>[];
    _applyEffects(opt.effects, inst, lines);
    inst.result = lines.isEmpty ? 'Done.' : lines.join(' ');
    if (ignored)
      inst.result =
          'Nobody decided in time: "${_fill(opt.label, inst)}". ${inst.result}';
    _note('incidentResult', '${_fill(def.title, inst)}: ${inst.result}', 0);
    emit('incidentResolved', {'instanceId': inst.id, 'result': inst.result});
  }

  void _applyEffects(List<Map<String, dynamic>> effects, IncidentInstance inst,
      List<String> out) {
    for (final e in effects) {
      final chance = e['chance'];
      if (chance != null && !_rng.chance((chance as num).toDouble())) {
        final alt = (e['else'] as List?)
            ?.map((x) => (x as Map).cast<String, dynamic>())
            .toList();
        if (alt != null) _applyEffects(alt, inst, out);
        if (e['failText'] != null)
          out.add(_fill(e['failText'] as String, inst));
        continue;
      }
      _applyEffect(e, inst, out);
      if (e['text'] != null) out.add(_fill(e['text'] as String, inst));
    }
  }

  List<Staff> _targets(dynamic target, IncidentInstance inst) {
    final t = (target as String?) ?? 'subject';
    if (t == 'subject')
      return [
        if (loc.staffById(inst.subjectId) != null)
          loc.staffById(inst.subjectId)!
      ];
    if (t == 'all') return List.of(loc.staff);
    if (t == 'others')
      return loc.staff.where((s) => s.id != inst.subjectId).toList();
    if (t.startsWith('role:'))
      return loc.staff.where((s) => s.role == t.substring(5)).toList();
    return const [];
  }

  void _applyEffect(
      Map<String, dynamic> e, IncidentInstance inst, List<String> out) {
    final l = loc;
    final eq = l.equipmentById(inst.subjectId);
    final st = l.staffById(inst.subjectId);
    final ss = l.service;
    num n(String k, [num d = 0]) => (e[k] as num?) ?? d;
    switch (e['type'] as String) {
      case 'none':
      case 'log':
        break;
      case 'cash':
        final a = e['pctOfDayRevenue'] != null
            ? (state.today.revenue * (e['pctOfDayRevenue'] as num)).round()
            : _amount(e['amount'], inst);
        if (a < 0) {
          spend(-a, (e['bucket'] as String?) ?? 'other');
        } else {
          earn(a, 'other');
        }
        if (e['text'] == null && a != 0)
          out.add(a < 0 ? 'Paid ${money(-a)}.' : 'Received ${money(a)}.');
      case 'reputation':
        l.reputation = (l.reputation + n('delta')).clamp(0, 5).toDouble();
        if (e['text'] == null)
          out.add('Rating ${n('delta') > 0 ? '+' : ''}${n('delta')}.');
      case 'hygiene':
        l.hygiene = (l.hygiene + n('delta')).clamp(0, 100).toDouble();
      case 'morale':
        for (final s in _targets(e['target'], inst)) {
          s.morale = (s.morale + n('delta')).clamp(0, 100).toDouble();
        }
      case 'mood':
        for (final s in _targets(e['target'], inst)) {
          s.moodMods.add(MoodMod(e['key'] as String, n('score').toDouble(),
              state.dayIndex + n('days').toInt()));
        }
      case 'staffStat':
        if (st != null) {
          final stat = e['stat'] as String;
          final d = n('delta').toDouble();
          switch (stat) {
            case 'skill':
              st.skill = (st.skill + d).clamp(0, 100).toDouble();
            case 'reliability':
              st.reliability = (st.reliability + d).clamp(0, 100).toDouble();
            case 'loyalty':
              st.loyalty = (st.loyalty + d).clamp(0, 100).toDouble();
            case 'honesty':
              st.honesty = (st.honesty + d).clamp(0, 100).toDouble();
            case 'fatigue':
              st.fatigue = (st.fatigue + d).clamp(0, 100).toDouble();
            case 'morale':
              st.morale = (st.morale + d).clamp(0, 100).toDouble();
          }
          if (e['set'] != null && stat == 'morale')
            st.morale = n('set').toDouble();
        }
      case 'staffStatus':
        if (st != null) {
          final status = e['status'] as String;
          final days = n('days', 1).toInt();
          if (status == 'absent') {
            final from =
                state.phase == 'close' ? state.dayIndex + 1 : state.dayIndex;
            st.absentUntil = math.max(st.absentUntil, from + days);
            if (state.phase != 'close') st.workingToday = false;
            if (e['text'] == null)
              out.add(
                  '${st.name} is off for $days day${days == 1 ? '' : 's'}.');
          } else if (status == 'notice') {
            st.status = 'notice';
            st.noticeLeft = _rng.nextInt(3, 7);
            if (e['text'] == null)
              out.add(
                  '${st.name} will work ${st.noticeLeft} more days, then leave.');
          }
        }
      case 'noticeLeave':
        if (st != null) {
          st.status = 'notice';
          st.noticeLeft = _rng.nextInt(3, 7);
        }
      case 'staffLeaves':
        if (st != null) {
          _removeStaff(st, '${st.name} left');
          if (state.phase == 'service') ss?.moves.remove('${st.id}');
        }
      case 'staffFired':
        if (st != null) _fire(st.id);
      case 'setWage':
        if (st != null) {
          st.wage = (st.wage * n('mult', 1)).round();
          st.lastGrowthDay = state.dayIndex;
        }
      case 'cancelResignation':
        if (st != null) {
          st.status = 'active';
          st.noticeLeft = 0;
        }
      case 'equipment':
        if (eq != null) {
          if (e['condition'] != null)
            eq.condition =
                math.min(_maxCondition(eq), n('condition').toDouble());
          if (e['conditionDelta'] != null) {
            eq.condition = (eq.condition + n('conditionDelta'))
                .clamp(0, _maxCondition(eq))
                .toDouble();
          }
          if (e['broken'] != null) {
            eq.broken = e['broken'] as bool;
            if (eq.broken) {
              if (e['text'] == null)
                out.add(
                    'The ${content.equipment[eq.type]!.name.toLowerCase()} is out of action until repaired.');
              _timeline('${content.equipment[eq.type]!.name} broke down');
            }
          }
          if (e['shakyDays'] != null)
            eq.fragileUntil = state.dayIndex + n('shakyDays').toInt();
        }
      case 'repair':
        if (eq != null) {
          final cfg =
              (b.map('REPAIR')[e['mode']] as Map).cast<String, dynamic>();
          final price = content.equipment[eq.type]!.price;
          final cost = (price * (cfg['cost'] as num)).round();
          spend(cost, 'upkeep');
          eq.broken = false;
          eq.condition =
              math.min(_maxCondition(eq), (cfg['condition'] as num).toDouble());
          final days = (cfg['days'] as num).toInt();
          eq.unavailableUntil =
              state.dayIndex + (state.phase == 'close' ? 1 : 0) + days;
          if (e['mode'] == 'cheap') eq.fragileUntil = state.dayIndex + 7;
          out.add(
              'Repair booked for ${money(cost)}; back in use ${days <= 0 ? 'today' : (days == 1 ? 'tomorrow' : 'in $days days')}.');
          _markFridge(eq);
        }
      case 'replace':
        if (eq != null) {
          final secondHand = e['secondHand'] == true;
          _buyEquipment(eq.type, secondHand: secondHand, replaceId: eq.id);
          out.add(secondHand
              ? 'A second-hand unit arrives tomorrow.'
              : 'A new unit arrives in 2 days.');
        }
      case 'stock':
        final pct = n('losePct').toDouble();
        final qd = n('qualityDelta').toInt();
        final dl = n('daysLeftDelta').toInt();
        for (final bt in l.stock) {
          final ing = content.ingredients[bt.ingredientId]!;
          if (e['storage'] != null && ing.storage != e['storage']) continue;
          if (e['ingredientId'] != null && bt.ingredientId != e['ingredientId'])
            continue;
          if (pct > 0) bt.qty = (bt.qty * (1 - pct)).floor();
          if (qd != 0) bt.quality = (bt.quality + qd).clamp(0, 100);
          if (dl != 0) bt.daysLeft = math.max(1, bt.daysLeft + dl);
        }
        l.stock.removeWhere((bt) => bt.qty <= 0);
      case 'demand':
        l.demandMods.add(Mod(inst.incidentId, n('mult', 1).toDouble(),
            state.dayIndex + n('days', 1).toInt() - 1));
      case 'competition':
        l.competition = (l.competition + n('delta'))
            .clamp(0, b.d('COMPETITION_MAX'))
            .toDouble();
      case 'patience':
        if (ss != null) {
          ss.patienceMult = n('mult', 1).toDouble();
          ss.patienceUntil = ss.tick + n('ticks', 30).toInt();
        }
      case 'stationOff':
        if (ss != null) {
          final ticks = n('ticks', 20).toInt();
          for (final station in (e['stations'] as List).cast<String>()) {
            ss.stationOffUntil[station] = ss.tick + ticks;
          }
        }
      case 'noSeating':
        if (ss != null) {
          ss.noSeatUntil = ss.tick + n('ticks', 40).toInt();
          if (e['walkWaiting'] == true) {
            for (final g
                in ss.groups.where((g) => g.state == 'waitTable').toList()) {
              _walkOut(g, 'waitTable');
            }
          }
        }
      case 'billSlow':
        if (ss != null) {
          ss.billMult = n('mult', 2).toDouble();
          ss.billMultUntil = ss.tick + n('ticks', 999).toInt();
        }
      case 'roleSlow':
        if (ss != null) {
          for (final s in _targets(e['target'], inst)) {
            ss.roleSlow[s.role] = n('mult', 1.2).toDouble();
          }
        }
      case 'ownerBusy':
        if (ss != null) ss.ownerBusyUntil = ss.tick + n('ticks', 5).toInt();
        state.owner.energy = math.max(0,
            state.owner.energy - n('ticks', 5) * b.d('OWNER_ENERGY_PER_TICK'));
      case 'groupSatisfaction':
        if (ss != null) {
          final scope = (e['scope'] as String?) ?? 'eating';
          for (final g in ss.groups) {
            if (scope == 'eating' && g.state != 'eating') continue;
            if (scope == 'waitFood' && g.state != 'waitFood') continue;
            g.satAdj += n('delta');
            if (e['patience'] != null) g.totalLimit += n('patience').toInt();
            if (e['patience'] != null && g.waiting)
              g.counter = math.max(0, g.counter - n('patience').toInt());
          }
        }
      case 'closeLocation':
        final from =
            state.phase == 'close' ? state.dayIndex + 1 : state.dayIndex;
        l.closedUntil = math.max(l.closedUntil, from + n('days', 1).toInt());
        out.add(
            'The restaurant is closed ${n('days', 1) == 1 ? 'for a day' : 'for ${n('days')} days'}. Wages are still due.');
        _timeline('Closed for ${n('days', 1)} day(s)');
      case 'flag':
        final days =
            e['days'] == null ? (1 << 30) : state.dayIndex + n('days').toInt();
        state.flags[e['key'] as String] = days;
      case 'clearFlag':
        state.flags.remove(e['key'] as String);
      case 'followUp':
        state.scheduled.add(Scheduled(
            e['incidentId'] as String, state.dayIndex + n('days', 1).toInt(),
            subjectId: e['sameSubject'] == true ? inst.subjectId : null,
            subjectKey: e['sameSubject'] == true ? 'force' : null));
      case 'inspection':
      case 'scheduleInspection':
        final day = state.dayIndex + n('days', 7).toInt();
        state.scheduled.add(Scheduled('inc_inspection', day));
        l.inspectionDay = day;
      case 'inspect':
        _inspect(out);
      case 'ownerEnergy':
        state.owner.energy =
            (state.owner.energy + n('delta')).clamp(0, 100).toDouble();
      case 'payable':
        l.payables.add(Payable(
            state.allocId(),
            null,
            _amount(e['amount'], inst),
            state.dayIndex + n('days', 7).toInt(),
            (e['label'] as String?) ?? 'Bill',
            false));
      case 'reveal':
        if (st != null) {
          st.daysWorked = math.max(st.daysWorked, 14);
          out.add('${st.name}\'s honesty: ${st.honesty.round()}.');
        }
      case 'lifeline':
        _lifeline(e['kind'] as String,
            e['kind'] == 'sellEquipment' ? _mostValuableSpare() : null);
      case 'priceSpike':
        l.categorySpikeUntil[inst.subjectKey ?? 'produce'] =
            state.dayIndex + n('days', 7).toInt() - 1;
      case 'raisePrices':
        final cat = inst.subjectKey;
        for (final m in l.menu.values) {
          final d = content.dishes[m.dishId]!;
          if (d.recipe.any(
              (r) => content.ingredients[r.ingredientId]!.category == cat)) {
            m.price = math.min((d.basePrice * 1.8).floor(),
                (m.price * (1 + n('pct', 0.1))).round());
          }
        }
      case 'eightySixCostliest':
        final cat = inst.subjectKey;
        final hit = l.menu.values
            .where((m) => content.dishes[m.dishId]!.recipe.any(
                (r) => content.ingredients[r.ingredientId]!.category == cat))
            .toList()
          ..sort((a, c) => c.price.compareTo(a.price));
        for (final m in hit.take(2)) {
          m.enabled = false;
          m.offSinceDay = state.dayIndex;
        }
        out.add(
            'Took ${hit.take(2).map((m) => content.dishes[m.dishId]!.name).join(' and ')} off the menu.');
      case 'rejectBatch':
        final orderLines = l.stock.where((bt) => bt.quality < 50).toList();
        l.stock.removeWhere(orderLines.contains);
        final refund = inst.vars['total'] ?? 0;
        if (refund > 0) {
          final p = l.payables
              .where((p) =>
                  p.supplierId == inst.subjectKey && p.dueDay > state.dayIndex)
              .lastOrNull;
          if (p != null) {
            l.payables.remove(p);
            state.today.ingredientSpend -= p.amount;
          } else {
            earn(refund, 'none');
            state.today.ingredientSpend -= refund;
          }
        }
      case 'refundOrder':
        final r = ((inst.vars['total'] ?? 300) * n('pct', 0.1)).round();
        earn(r, 'none');
      case 'supplierRel':
        final sid = inst.subjectKey ?? 'sup_standard';
        l.supplierRel[sid] =
            ((l.supplierRel[sid] ?? 50) + n('delta')).clamp(0, 100).toInt();
        if (e['set'] != null) l.supplierRel[sid] = n('set').toInt();
      case 'supplierBlock':
        l.supplierBlockedUntil[inst.subjectKey ?? 'sup_standard'] =
            state.dayIndex + n('days', 28).toInt();
      case 'supplierCashOnly':
        l.supplierCashOnlyUntil[inst.subjectKey ?? 'sup_standard'] =
            state.dayIndex + n('days', 56).toInt();
      case 'payPayables':
        final sid = inst.subjectKey;
        for (final p in l.payables.where((p) => p.supplierId == sid).toList()) {
          if (state.cash < p.amount) break;
          l.payables.remove(p);
          state.cash -= p.amount;
          out.add('Paid ${money(p.amount)} to ${inst.subjectName}.');
        }
      case 'supplierDeal':
        l.supplierDeal[inst.subjectKey ?? 'sup_standard'] =
            n('discount', 0.08).toDouble();
        state.flags['deal_${inst.subjectKey}'] = state.dayIndex + 56;
      case 'rent':
        final pct = n('pct').toDouble();
        l.rentWeekly = (l.rentWeekly * (1 + pct)).round();
        out.add(
            'Rent is now ${money(l.rentWeekly)} a week (${pct >= 0 ? '+' : ''}${(pct * 100).round()}%).');
        _timeline('Rent changed to ${money(l.rentWeekly)}/week');
        if (inst.subjectKey == 'hidden') _markHidden('lease_increase');
      case 'leaseLock':
        l.leaseLockUntil = state.dayIndex + 672;
      case 'shortage':
        l.shortageIngredient = inst.subjectKey;
        l.shortageUntil = state.dayIndex + n('days', 7).toInt() - 1;
      case 'dayOffChange':
        if (st != null) {
          st.dayOff = st.preferredDayOff;
          st.preferredKnown = true;
          out.add('${st.name} now has ${_weekdayName(st.dayOff)} off.');
        }
      case 'removeTrait':
        st?.traits.remove(e['trait']);
      case 'critic':
        state.flags['critic_next'] = state.dayIndex;
      case 'bigBooking':
        state.flags['big_booking_today'] = state.dayIndex;
      case 'filmCrew':
        state.flags['film_crew_today'] = state.dayIndex;
      case 'festivalLeave':
        state.flags['festival_absence'] = state.dayIndex + 6;
        state.flags['festival_absence_pct'] = (n('pct') * 100).round();
      case 'festivalPay':
        state.flags['festival_double_pay'] = state.dayIndex + 6;
      case 'train':
        if (st != null) _train(st.id);
      case 'markHidden':
        _markHidden(e['kind'] as String);
      default:
        throw StateError('Unknown effect ${e['type']}');
    }
  }

  void _markFridge(Equipment e) {
    if (e.type == 'eq_fridge') _updateHiddenProblems();
  }

  int? _mostValuableSpare() {
    Equipment? best;
    for (final e in loc.equipment) {
      final t = content.equipment[e.type]!;
      if (t.kind == 'storage' &&
          loc.equipment.where((x) => x.type == e.type).length < 2) continue;
      if (best == null || _equipmentResale(e) > _equipmentResale(best))
        best = e;
    }
    return best?.id;
  }

  /// Health inspection outcome (doc 02 §12).
  void _inspect(List<String> out) {
    final l = loc;
    final h = l.hygiene;
    _markHidden('health_violation');
    if (h >= b.d('INSPECTION_PASS')) {
      l.reputation = math.min(5, l.reputation + 0.1);
      out.add(
          'The inspector passed you (cleanliness ${h.round()}). Rating +0.1.');
      _timeline('Passed a health inspection (${h.round()})');
      if (h >= 90) _completeObjective('obj_2_inspection_a');
    } else if (h >= b.d('INSPECTION_WARN')) {
      spend(b.i('INSPECTION_FINE_WARN'), 'other');
      state.scheduled.add(Scheduled('inc_inspection', state.dayIndex + 7));
      out.add(
          'Warning and a ${money(b.i('INSPECTION_FINE_WARN'))} fine (cleanliness ${h.round()}). They will be back in 7 days.');
      _timeline('Health inspection warning (${h.round()})');
    } else {
      spend(b.i('INSPECTION_FINE_CLOSE'), 'other');
      l.reputation = math.max(0, l.reputation - 0.5);
      final from = state.phase == 'close' ? state.dayIndex + 1 : state.dayIndex;
      l.closedUntil = math.max(l.closedUntil, from + 2);
      for (final s in l.staff) {
        s.moodMods.add(MoodMod('Job security', -6, state.dayIndex + 14));
      }
      out.add(
          'Closed for 2 days, fined ${money(b.i('INSPECTION_FINE_CLOSE'))}, rating −0.5 (cleanliness ${h.round()}).');
      _timeline('Closed by the health inspector (${h.round()})');
    }
    _note('inspection', out.last, 0);
  }
}

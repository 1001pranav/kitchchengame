part of '../sim.dart';

// Several outlets (doc 02 §15, doc 11 Parts B–D): travel, managers, requests, neglect,
// skimming, the outlet market and building, selling and closing, badges, chain perks,
// central kitchen, bulk contract and franchising (doc 13).

const managerProfiles = {
  'allRounder': [0.0, 0.0, 0.0],
  'peoplePerson': [15.0, -5.0, -10.0],
  'tightShip': [-10.0, 15.0, -5.0],
  'numbers': [-5.0, -10.0, 15.0],
};
const profileNames = {
  'allRounder': 'All-rounder',
  'peoplePerson': 'People person',
  'tightShip': 'Tight ship',
  'numbers': 'Numbers',
};
const formatNames = {
  'neighbourhood': 'Neighbourhood',
  'highStreet': 'High street',
  'officeDistrict': 'Office district',
};

extension _Chain on Sim {
  // ---------------------------------------------------------- basics

  Map<String, double> _format(Location l) =>
      (b.map('FORMATS')[l.format] as Map? ??
              b.map('FORMATS')['neighbourhood'] as Map)
          .map((k, v) => MapEntry(k as String, (v as num).toDouble()));

  bool get _unattended =>
      state.ownerLocationId != loc.id || state.owner.restingToday;

  /// Average rating over all trading outlets.
  double _companyRating() {
    final ls =
        state.openLocations.where((l) => l.openDay <= state.dayIndex).toList();
    if (ls.isEmpty) return state.loc.reputation;
    return ls.fold(0.0, (a, l) => a + l.reputation) / ls.length;
  }

  void _story(String text) {
    loc.story.add(TimelineEntry(state.dayIndex, text));
    if (loc.story.length > 40) loc.story.removeAt(0);
  }

  void _managerNote(String text, int cost) {
    if (cost >= 0) {
      loc.managerCostWeek += cost;
    } else {
      loc.managerSaveWeek -= cost;
    }
    loc.managerNotes.add(text);
    if (loc.managerNotes.length > 12) loc.managerNotes.removeAt(0);
  }

  int _expectedManagerWage(double meanSkill) =>
      (b.dmap('BASE_WAGE')['manager']! * (0.4 + 1.2 * meanSkill / 100)).round();

  double _mastery(double skill) => ((skill - b.d('MASTERY_FROM')) /
          (b.d('MASTERY_FULL') - b.d('MASTERY_FROM')))
      .clamp(0, 1)
      .toDouble();

  /// Standards slipping at an outlet the owner has not visited (doc 02 §15.5).
  double _slack() {
    if (state.locations.length < 2) return 0;
    final m = loc.manager;
    if (m == null || !_unattended) return 0;
    final grace = m.managerSkill * m.managerSkill / b.d('NEGLECT_GRACE_SQ_DIV');
    final neglect = math.max(0, (state.dayIndex - loc.lastVisitDay) - grace);
    return math.min(b.d('NEGLECT_MAX'), neglect * b.d('NEGLECT_PER_DAY'));
  }

  // ---------------------------------------------------------- morning and evening

  void _chainMorning() {
    if (state.locationById(state.ownerLocationId)?.closedForGood ?? true) {
      state.ownerLocationId = state.openLocations.first.id;
    }
    if (state.locationById(state.viewLocationId)?.closedForGood ?? true) {
      state.viewLocationId = state.ownerLocationId;
    }
    if (state.stage >= 3) {
      if (state.marketRefreshDay < 0 ||
          state.dayIndex >= state.marketRefreshDay) {
        _refreshOutletMarket();
        state.marketRefreshDay = state.dayIndex + 28;
      }
      if (state.managerApplicants.isEmpty || state.dayIndex % 14 == 0) {
        _generateManagerApplicants();
      }
    }
    // Offers for listed outlets (doc 02 §14.7).
    for (final l in state.openLocations) {
      l.saleOffers.removeWhere((o) => o.expiresDay < state.dayIndex);
      if (l.listedDay >= 0) {
        final waited = state.dayIndex - l.listedDay;
        if (waited >= 7 && l.saleOffers.length < 3 && _rng.chance(1 / 7)) {
          final est = at(l, _saleEstimate);
          l.saleOffers.add(SaleOffer(
              (est * _rng.range(0.8, 1.1)).round(), state.dayIndex + 7));
          state.pendingNotices.add(
              'A buyer has made an offer for ${l.name}: ${money(l.saleOffers.last.amount)} (valid 7 days).');
        }
      }
    }
    // Old requests: unanswered for 3 days, the manager is fed up.
    for (final r in state.requests) {
      if (state.dayIndex - r.raisedDay > 3) {
        final m = state.locationById(r.locationId)?.manager;
        if (m != null) m.morale = math.max(0, m.morale - 2);
      }
    }
    state.requests.removeWhere((r) =>
        state.dayIndex - r.raisedDay > 14 ||
        state.locationById(r.locationId) == null);
  }

  void _chainEvening() {
    for (final l in state.openLocations) {
      at(l, () {
        // A visit: at least VISIT_MIN_TICKS of service with the owner there (doc 02 §15.3).
        final present = l.ownerTicksToday >= b.i('VISIT_MIN_TICKS') ||
            (l.service?.done == true &&
                l.today.closed &&
                state.ownerLocationId == l.id);
        if (present) {
          l.lastVisitDay = state.dayIndex;
          l.ownerDaysThisWeek++;
          final m = l.manager;
          if (m != null && state.dayIndex - m.lastCoachDay >= 7) {
            _growManager(m, 1);
            m.lastCoachDay = state.dayIndex;
          }
        }
        final m = l.manager;
        if (m == null) return;
        // Learning on the job: +1 to the weakest sub-skill per 28 days in post.
        if (state.dayIndex - m.lastLearnDay >= 28) {
          m.lastLearnDay = state.dayIndex;
          _growManager(m, 1);
        }
        // A dishonest manager skims (doc 02 §15.6).
        if (m.honesty < 40 &&
            l.today.revenue > 0 &&
            _rng.chance((40 - m.honesty) / 100 + _slack())) {
          final lost = (l.today.revenue * b.d('SKIM_PCT')).round();
          state.cash -= lost;
          l.today.other += lost;
          _note('skim', 'Cash in the till was ${money(lost)} short of sales',
              lost);
        }
        // People mastery: the crew improves (doc 02 §15.16).
        final pm = _mastery(m.people);
        if (pm > 0 &&
            (state.dayIndex - m.hiredDay) % 28 == 27 &&
            _rng.chance(pm)) {
          for (final s in l.staff) {
            if (!s.isManager && s.skill < 80) s.skill += 1;
          }
          _managerNote('${m.name} developed the crew (+1 skill each)', -300);
        }
      });
    }
  }

  void _growManager(Staff m, int n) {
    for (var i = 0; i < n; i++) {
      if (m.managerSkill >= m.potential) return;
      if (m.people <= m.upkeep && m.people <= m.stockSkill) {
        m.people = math.min(90, m.people + 1);
      } else if (m.upkeep <= m.stockSkill) {
        m.upkeep = math.min(90, m.upkeep + 1);
      } else {
        m.stockSkill = math.min(90, m.stockSkill + 1);
      }
    }
    m.skill = m.managerSkill.roundToDouble();
  }

  // ---------------------------------------------------------- the manager runs prep

  void _managerPrep() {
    final l = loc;
    final m = l.manager!;
    final p = l.policies;
    // People: rota mistakes, absence cover, fatigue care.
    if (_rng.chance((100 - m.people) / 300)) {
      final working =
          l.staff.where((s) => s.workingToday && !s.isManager).toList();
      if (working.isNotEmpty) {
        final s = _rng.pick(working);
        s.workingToday = false;
        _managerNote('${m.name} left ${s.name} off the rota by mistake', 150);
        _note('managerRota', '${m.name} left ${s.name} off the rota by mistake',
            150);
      }
    }
    for (final s in l.staff.where((s) => s.absentToday).toList()) {
      if (_rng.chance(m.people / 100)) {
        final cover = l.staff
            .where((x) =>
                (x.role == s.role || (x.isCook && s.isCook)) &&
                !x.workingToday &&
                !x.absentToday &&
                x.absentUntil <= state.dayIndex &&
                x.trainingUntil <= state.dayIndex)
            .firstOrNull;
        if (cover != null) {
          cover.workingToday = true;
          cover.workDayOffDay = state.dayIndex;
          cover.fatigue = math.min(100, cover.fatigue + 6);
          _managerNote(
              '${m.name} called in ${cover.name} to cover ${s.name}', -200);
        }
      }
    }
    if (m.people >= 60) {
      for (final s in l.staff
          .where((s) => s.workingToday && s.fatigue > 75 && !s.isManager)
          .toList()) {
        final others = l.staff
            .where((x) => x != s && x.role == s.role && x.workingToday)
            .length;
        if (others > 0) {
          s.workingToday = false;
          s.fatigue = math.max(0, s.fatigue - 30);
        }
      }
    }
    // Stock: order to cover today and tomorrow, with errors that shrink with skill.
    if (p.autoOrder) {
      final u = _rng.range(-1, 1);
      final mult = 1 + u * (100 - m.stockSkill) / 200;
      for (final sup in ['sup_standard']) {
        final lines =
            _suggestedOrder(sup).map((k, v) => MapEntry(k, (v * mult).round()));
        lines.removeWhere((k, v) => v <= 0);
        if (lines.isNotEmpty &&
            _orderTotal(sup, lines) >= content.suppliers[sup]!.minOrder) {
          _placeOrder(sup, lines);
          if (mult > 1.15) {
            _managerNote('${m.name} over-ordered stock',
                ((mult - 1) * _orderTotal(sup, lines)).round());
          }
          if (mult < 0.85) {
            _managerNote('${m.name} under-ordered: dishes may sell out', 200);
          }
        }
      }
      // Same-day top-up if something runs out today.
      final short = <String, int>{};
      _expectedDailyUse(l).forEach((ing, perDay) {
        final need = perDay.ceil() - l.stockOf(ing);
        if (need > 0 && m.stockSkill >= 50) short[ing] = need;
      });
      if (short.isNotEmpty && state.cash > 2000) {
        _placeOrder('sup_cash_carry', short);
      }
    }
    // Upkeep: servicing, repairs within the spending limit, early warnings.
    for (final e in List<Equipment>.of(l.equipment)) {
      final t = content.equipment[e.type]!;
      if (e.broken) {
        final mode = m.upkeep >= 60 ? 'proper' : 'cheap';
        final cost =
            (t.price * ((b.map('REPAIR')[mode] as Map)['cost'] as num)).round();
        if (cost <= p.spendingLimit && state.cash >= cost) {
          _applyEffect(
              {'type': 'repair', 'mode': mode},
              IncidentInstance(
                  id: 0,
                  incidentId: 'manager',
                  subjectId: e.id,
                  createdDay: state.dayIndex),
              []);
          if (mode == 'cheap') {
            _managerNote(
                '${m.name} chose a cheap repair on the ${t.name.toLowerCase()}',
                (t.price * 0.05).round());
          }
        } else {
          _request('repair',
              cost: (t.price * 0.25).round(),
              cheaper: (t.price * 0.10).round(),
              subjectId: e.id,
              text:
                  'The ${t.name.toLowerCase()} is broken. Repair it properly?',
              skill: m.upkeep);
        }
        continue;
      }
      if (e.condition < p.maintenanceThreshold &&
          state.dayIndex - e.lastMaintDay >= 7 &&
          e.condition < _maxCondition(e) - 5) {
        if (_rng.chance((0.3 + m.upkeep / 100).clamp(0, 1))) {
          if (e.condition >= 50 || state.weekday == 0) _maintain(e.id);
        } else {
          _managerNote(
              '${m.name} skipped servicing the ${t.name.toLowerCase()}', 100);
        }
      }
      if (e.condition < 45 && _rng.chance(m.upkeep / 100) && _rng.chance(0.2)) {
        _request('replace',
            cost: t.price,
            cheaper: (t.price * 0.5).round(),
            subjectId: e.id,
            text:
                'The ${t.name.toLowerCase()} is worn out (condition ${e.condition.round()}). Replace it?',
            skill: m.upkeep);
      }
    }
    // Requests for things beyond their authority (doc 02 §15.10).
    for (final role in ['lineCook', 'server', 'dishwasher', 'cleaner']) {
      final have = l.staff
          .where((s) =>
              s.role == role || (role == 'lineCook' && s.role == 'headChef'))
          .length;
      // Same rule as the competent owner: three cooks (so a day off never leaves one
      // alone), two servers, one of everything else (doc 02 §15.10, doc 06 §6.1).
      final need = switch (role) { 'lineCook' => 3, 'server' => 2, _ => 1 };
      if (have < need) {
        final wage = _expectedWage(role, 50) * 7;
        if (p.mayHire) {
          final a = state.applicants.where((x) => x.role == role).firstOrNull;
          if (a != null) {
            _hire(a.id);
            continue;
          }
        }
        _request('hire',
            cost: wage,
            subjectKey: role,
            text:
                'We are short of a ${roleName(role).toLowerCase()}. Hire one?',
            skill: m.people);
      }
    }
    for (final s in l.staff
        .where((s) =>
            !s.isManager &&
            s.morale < 45 &&
            s.wage < _expectedWage(s.role, s.skill))
        .toList()) {
      final exp = _expectedWage(s.role, s.skill);
      if (p.mayGiveRaises) {
        _setWage(s.id, exp);
      } else {
        _request('raise',
            cost: (exp - s.wage) * 7,
            cheaper: ((exp - s.wage) * 3.5).round(),
            subjectId: s.id,
            text:
                '${s.name} is unhappy and underpaid. Raise to ${money(exp)} a day?',
            skill: m.people);
      }
    }
    if (l.buzz < 0.25 && state.stage >= 2) {
      _request('marketing',
          cost: 3000,
          subjectKey: 'localAd',
          text: 'Buzz is low. Run a local ad?',
          skill: m.managerSkill);
    }
  }

  void _request(String kind,
      {required int cost,
      int? cheaper,
      int? subjectId,
      String? subjectKey,
      required String text,
      required double skill}) {
    if (state.requests.any((r) =>
        r.locationId == loc.id &&
        r.kind == kind &&
        r.subjectId == subjectId &&
        r.subjectKey == subjectKey)) {
      return;
    }
    if (!_rng.chance((0.4 + skill / 100).clamp(0, 1))) {
      _managerNote(
          '${loc.manager?.name ?? 'The manager'} did not raise: ${text.split('.').first.toLowerCase()}',
          100);
      return;
    }
    state.requests.add(Request(
      id: state.allocId(),
      locationId: loc.id,
      kind: kind,
      subjectId: subjectId,
      subjectKey: subjectKey,
      cost: cost,
      cheaperCost: cheaper,
      text: text,
      raisedDay: state.dayIndex,
    ));
  }

  void _managerClose() {
    // Upkeep mastery slows wear (doc 02 §15.16): give some condition back.
    final m = loc.manager;
    if (m == null) return;
    final um = _mastery(m.upkeep);
    if (um > 0) {
      for (final e in loc.equipment) {
        if (!e.broken) {
          e.condition = math.min(_maxCondition(e),
              e.condition + content.equipment[e.type]!.wearPerDay * 0.3 * um);
        }
      }
    }
  }

  /// What happens to a card nobody answers: the manager decides by the stance, else the default.
  String _ignoredChoice(IncidentInstance inst) {
    final def = content.incidents[inst.incidentId]!;
    final l = state.locationById(inst.locationId);
    if (l == null || l.manager == null || state.ownerLocationId == l.id) {
      return def.defaultOption;
    }
    return at(l, () {
      final opts =
          def.options.where((o) => _optionBlocked(o, inst) == null).toList();
      if (opts.isEmpty) return def.defaultOption;
      final scored = [
        for (final o in opts) MapEntry(o, _optionCashForManager(inst, o))
      ]..sort((a, c) => c.value.compareTo(a.value));
      final within =
          scored.where((e) => -e.value <= l.policies.spendingLimit).toList();
      final pool = within.isEmpty ? [scored.first] : within;
      return switch (l.policies.stance) {
        'frugal' => pool.first.key.id,
        'quality' => pool.last.key.id,
        _ => pool[pool.length ~/ 2].key.id,
      };
    });
  }

  int _optionCashForManager(IncidentInstance inst, IncidentOption o) {
    var sum = 0;
    for (final e in o.effects) {
      if (e['type'] == 'cash' && e['amount'] != null && e['chance'] == null) {
        sum += _amount(e['amount'], inst);
      }
      if (e['type'] == 'repair' || e['type'] == 'replace') {
        final eq = loc.equipmentById(inst.subjectId);
        if (eq != null) {
          sum -= (content.equipment[eq.type]!.price *
                  (e['type'] == 'replace' ? 1.0 : 0.25))
              .round();
        }
      }
    }
    return sum;
  }

  // ---------------------------------------------------------- weekly per outlet

  void _weeklyOutlet(WeekRecord w) {
    final l = loc;
    // Ledger (doc 02 §15.8).
    if (w.operatingProfit > 0) l.returned += w.operatingProfit;
    // Losing weeks and crisis (doc 02 §15.7), with an opening grace for new builds.
    final inGrace = l.openDay > 0 &&
        state.dayIndex - l.openDay < 7 * b.i('OPENING_GRACE_WEEKS') &&
        !l.weeks.any((x) => x.operatingProfit > 0);
    if (w.operatingProfit >= 0) {
      if (l.crisis) {
        state.pendingNotices.add('${l.name} is out of trouble.');
        _story('Out of trouble');
      }
      l.lossWeeks = 0;
      l.crisis = false;
    } else if (!inGrace) {
      l.lossWeeks++;
      if (l.lossWeeks >= 4 && !l.crisis && state.locations.length > 1) {
        l.crisis = true;
        state.pendingNotices.add(
            '${l.name} has lost money four weeks running: it is in trouble. Staff are worried about their jobs.');
        _story('In trouble after four losing weeks');
        for (final s in l.staff) {
          s.moodMods.add(MoodMod('Job security', -10, state.dayIndex + 28));
        }
      }
      if (l.lossWeeks >= 8 && state.locations.length > 1) {
        _raiseIncident('inc_location_failing', forced: true);
      }
    }
    // Manager's profit bonus.
    final m = l.manager;
    if (m != null && m.bonusPct > 0 && w.operatingProfit > 0) {
      final bonus = (w.operatingProfit * m.bonusPct / 100).round();
      spend(bonus, 'wages');
    }
    // Badges (doc 11 §D.1).
    final wasGold = l.badge == 'gold';
    if (w.operatingProfit > 0 && l.ownerDaysThisWeek <= 1) {
      l.goldWeeks++;
    } else {
      l.goldWeeks = 0;
    }
    String badge = l.badge;
    if (l.invested > 0 && l.returned >= l.invested * 0.5 && badge == '') {
      badge = 'bronze';
      l.buzz = math.min(1, l.buzz + 0.2);
    }
    if (l.invested > 0 &&
        l.returned >= l.invested &&
        l.reputation >= 4.0 &&
        (badge == 'bronze' || badge == '')) {
      badge = 'silver';
      for (final s in l.staff) {
        s.loyalty = math.min(100, s.loyalty + 5);
      }
    }
    if (l.goldWeeks >= 8 && l.reputation >= 4.3 && badge != 'gold') {
      badge = 'gold';
      l.buzz = math.min(1, l.buzz + 0.4);
      l.competition = math.max(0, l.competition - 0.1);
      final perk = 'perk_${l.format}';
      if (state.perks.add(perk)) {
        state.pendingNotices
            .add('Chain perk earned: ${perkText[perk] ?? perk}.');
      }
    }
    if (wasGold && l.lossWeeks >= 4) badge = 'silver';
    if (badge != l.badge) {
      final name =
          badge.isEmpty ? '' : '${badge[0].toUpperCase()}${badge.substring(1)}';
      if (badge.isNotEmpty) {
        state.pendingNotices.add('${l.name} earned a $name badge.');
        _story('$name badge');
        _timeline('${l.name}: $name badge');
      }
      l.badge = badge;
    }
    l.managerCostWeek = 0;
    l.managerSaveWeek = 0;
  }

  void _weeklyChain() {
    // Central kitchen running cost.
    if (state.centralKitchen) {
      at(state.openLocations.first,
          () => spend(b.i('CENTRAL_KITCHEN_WEEKLY'), 'other'));
    }
    // Franchises pay their fees and sometimes embarrass the brand (doc 13).
    if (state.franchises > 0) {
      final fee = state.franchises * b.i('FRANCHISE_WEEKLY_FEE');
      state.cash += fee;
      at(state.openLocations.first, () {
        loc.today.other -= fee;
        _note('franchise', 'Franchise fees: ${money(fee)}', 0);
      });
      if (_rng.chance(b.d('FRANCHISE_SCANDAL_CHANCE') * state.franchises)) {
        for (final l in state.openLocations) {
          l.reputation = math.max(0, l.reputation - 0.1);
        }
        state.pendingNotices.add(
            'A franchisee served something awful and it went viral. Every outlet\'s rating fell by 0.1.');
        _timeline('Franchise scandal: every rating −0.1');
      }
    }
  }

  // ---------------------------------------------------------- travel

  int get _globalTick {
    var t = 0;
    for (final l in state.openLocations) {
      final s = l.service;
      if (s != null && s.tick > t) t = s.tick;
    }
    return t;
  }

  void _travelTick() {
    if (!state.travelling) return;
    if (_globalTick >= state.travelUntilTick) {
      state.ownerLocationId = state.travelTo;
      state.viewLocationId = state.travelTo;
      state.travelTo = -1;
      final dest = state.locationById(state.ownerLocationId);
      if (dest?.service != null) {
        dest!.service!.ownerArea = state.owner.startArea ?? 'door';
      }
      emit('ownerArrived', {'locationId': state.ownerLocationId});
    }
  }

  CommandResult _ownerTravel(int toId) {
    final to = state.locationById(toId);
    if (to == null || to.closedForGood) {
      return CommandResult.fail(SimError.unknownId);
    }
    if (toId == state.ownerLocationId && !state.travelling) {
      return const CommandResult(true);
    }
    if (state.phase == 'prep') {
      state.ownerLocationId = toId;
      state.viewLocationId = toId;
      return const CommandResult(true);
    }
    if (state.phase != 'service') {
      return CommandResult.fail(SimError.wrongPhase);
    }
    if (state.travelling) {
      return CommandResult.fail(
          SimError.limitReached, 'You are already on the road.');
    }
    if (state.owner.restingToday) {
      return CommandResult.fail(SimError.locked, 'You are resting today.');
    }
    final from = state.locationById(state.ownerLocationId);
    if (from?.service != null) {
      at(from!, () {
        for (final id in ss.ownerQueue) {
          ss.task(id)?.reserved = false;
        }
        ss.ownerQueue.clear();
        ss.ownerArea = null;
      });
    }
    state.travelTo = toId;
    state.travelUntilTick = _globalTick + b.i('TRAVEL_TICKS');
    state.owner.energy = math.max(0, state.owner.energy - b.d('TRAVEL_ENERGY'));
    emit('ownerTravelling', {'to': toId});
    return const CommandResult(true);
  }

  // ---------------------------------------------------------- managers

  void _generateManagerApplicants() {
    state.managerApplicants.clear();
    final r = _companyRating();
    final grades = ['Trainee', 'Junior', 'Capable', 'Senior', 'Veteran'];
    final w = [
      30.0,
      30.0,
      25.0,
      math.max(0.0, 10 + 10 * (r - 3.5)),
      math.max(0.0, 5 + 10 * (r - 4.0))
    ];
    final ranges = {
      'Trainee': [20, 34],
      'Junior': [35, 49],
      'Capable': [50, 64],
      'Senior': [65, 79],
      'Veteran': [80, 92]
    };
    final used = {
      for (final l in state.locations)
        for (final s in l.staff) s.name
    };
    for (var i = 0; i < 3; i++) {
      final g = _rng.weighted(grades, w);
      final mean = _rng.nextInt(ranges[g]![0], ranges[g]![1]).toDouble();
      final m = _makeManager(mean, used);
      state.managerApplicants.add(m);
    }
  }

  Staff _makeManager(double mean, Set<String> used, {String? profile}) {
    final String prof = profile ?? _rng.pick(managerProfiles.keys.toList());
    final off = managerProfiles[prof]!;
    double sub(int i) =>
        (mean + off[i] + _rng.range(-5, 5)).clamp(5, 95).roundToDouble();
    final m = _makeStaff(
        role: 'manager', skill: mean, morale: 60, wageMult: 1, usedNames: used);
    m.people = sub(0);
    m.upkeep = sub(1);
    m.stockSkill = sub(2);
    m.profile = prof;
    m.potential = math.min(95, m.managerSkill + _rng.nextInt(5, 35)).toDouble();
    m.skill = m.managerSkill.roundToDouble();
    m.wage = _expectedManagerWage(m.managerSkill);
    m.askingWage = m.wage;
    m.dayOff =
        7; // managers work every day the outlet is open (SPEC-GAP, doc 12)
    m.traits = [];
    m.hiredDay = state.dayIndex;
    m.lastLearnDay = state.dayIndex;
    m.bonusPct = switch (m.grade) {
      'Veteran' => 5,
      'Senior' => 3,
      'Capable' => 1,
      _ => 0
    };
    return m;
  }

  CommandResult _hireManager(int id) {
    final a = state.managerApplicants.where((x) => x.id == id).firstOrNull;
    if (a == null) return CommandResult.fail(SimError.unknownId);
    if (loc.manager != null) {
      return CommandResult.fail(
          SimError.limitReached, '${loc.name} already has a manager.');
    }
    final r = _companyRating();
    if (a.grade == 'Senior' && r < 3.5 || a.grade == 'Veteran' && r < 4.0) {
      return CommandResult.fail(SimError.refused,
          '${a.name} only joins companies rated ${a.grade == 'Veteran' ? '4.0' : '3.5'}★ or better.');
    }
    state.managerApplicants.remove(a);
    a.hiredDay = state.dayIndex;
    a.lastLearnDay = state.dayIndex;
    loc.staff.add(a);
    _story('${a.name} became manager (${a.grade})');
    _timeline('${loc.name}: hired ${a.name} as manager (${a.grade})');
    return const CommandResult(true);
  }

  CommandResult _promoteToManager(int staffId) {
    final s = loc.staffById(staffId);
    if (s == null) return CommandResult.fail(SimError.unknownId);
    if (!['server', 'cashier', 'headChef'].contains(s.role) || s.skill < 60) {
      return CommandResult.fail(SimError.invalidValue,
          'Only a server, cashier or head chef with skill 60+ can become a manager.');
    }
    if (loc.manager != null) {
      return CommandResult.fail(SimError.limitReached,
          'This outlet already has a manager. Transfer them first.');
    }
    final mean = 0.6 * s.skill + 10;
    final m = _makeManager(mean, {}, profile: 'allRounder');
    if (state.perks.contains('perk_neighbourhood')) {
      m.people = math.min(95, m.people + 5);
    }
    s.role = 'manager';
    s.people = m.people;
    s.upkeep = m.upkeep;
    s.stockSkill = m.stockSkill;
    s.profile = 'allRounder';
    s.potential = math.min(95, m.potential + 10);
    s.skill = s.managerSkill.roundToDouble();
    s.wage = _expectedManagerWage(s.managerSkill);
    s.loyalty = math.min(100, s.loyalty + 15);
    s.dayOff = 7;
    s.lastLearnDay = state.dayIndex;
    s.lastGrowthDay = state.dayIndex;
    _story('${s.name} promoted to manager');
    _timeline('Promoted ${s.name} to manager at ${loc.name}');
    return const CommandResult(true);
  }

  CommandResult _transfer(int staffId, int toId) {
    final to = state.locationById(toId);
    final s = loc.staffById(staffId);
    if (to == null || to.closedForGood) {
      return CommandResult.fail(SimError.unknownId);
    }
    if (s == null) return CommandResult.fail(SimError.unknownId);
    if (to.id == loc.id) return CommandResult.fail(SimError.invalidValue);
    if (s.isManager && to.manager != null) {
      return CommandResult.fail(
          SimError.limitReached, '${to.name} already has a manager.');
    }
    loc.staff.remove(s);
    to.staff.add(s);
    s.absentUntil = math.max(
        s.absentUntil, state.dayIndex + (state.phase == 'close' ? 2 : 1));
    s.workingToday = false;
    s.morale = math.max(0, s.morale - 5);
    s.moodMods.add(MoodMod('New place', -3, state.dayIndex + 7));
    _story('${s.name} moved to ${to.name}');
    at(
        to,
        () => _story(
            '${s.name} arrived from ${state.locationById(state.viewLocationId)?.name ?? 'another outlet'}'));
    return const CommandResult(true);
  }

  CommandResult _answerRequest(int id, String answer) {
    final r = state.requests.where((x) => x.id == id).firstOrNull;
    if (r == null) return CommandResult.fail(SimError.unknownId);
    final l = state.locationById(r.locationId);
    if (l == null) return CommandResult.fail(SimError.unknownId);
    if (answer == 'deny') {
      state.requests.remove(r);
      final m = l.manager;
      if (m != null) m.morale = math.max(0, m.morale - 2);
      return const CommandResult(true);
    }
    final cheaper = answer == 'cheaper' && r.cheaperCost != null;
    final cost = cheaper ? r.cheaperCost! : r.cost;
    final res = at(l, () {
      switch (r.kind) {
        case 'repair':
          final e = l.equipmentById(r.subjectId);
          if (e == null || !e.broken) return const CommandResult(true);
          if (state.cash < cost) {
            return CommandResult.fail(SimError.notEnoughCash);
          }
          _applyEffect(
              {'type': 'repair', 'mode': cheaper ? 'cheap' : 'proper'},
              IncidentInstance(
                  id: 0,
                  incidentId: 'request',
                  subjectId: e.id,
                  createdDay: state.dayIndex),
              []);
          return const CommandResult(true);
        case 'replace':
          final e = l.equipmentById(r.subjectId);
          if (e == null) return const CommandResult(true);
          return _buyEquipment(e.type, secondHand: cheaper, replaceId: e.id);
        case 'hire':
          final role = r.subjectKey!;
          final cands = state.applicants
              .where((a) =>
                  a.role == role ||
                  (role == 'lineCook' && a.role == 'headChef'))
              .toList()
            ..sort((a, c) => c.skill.compareTo(a.skill));
          if (cands.isEmpty) {
            return CommandResult.fail(SimError.unknownId,
                'No ${roleName(role).toLowerCase()} applied this week. New applicants come on Sunday.');
          }
          return _hire(cands.first.id);
        case 'raise':
          final s = l.staffById(r.subjectId);
          if (s == null) return const CommandResult(true);
          final exp = _expectedWage(s.role, s.skill);
          return _setWage(s.id, cheaper ? ((s.wage + exp) / 2).round() : exp);
        case 'marketing':
          return _startCampaign(r.subjectKey ?? 'localAd');
      }
      return const CommandResult(true);
    });
    if (res.ok) state.requests.remove(r);
    return res;
  }

  CommandResult _audit() {
    if (state.ownerLocationId != loc.id) {
      return CommandResult.fail(
          SimError.locked, 'You must be at ${loc.name} to audit it.');
    }
    final cost = b.i('AUDIT_COST');
    if (state.cash < cost) return CommandResult.fail(SimError.notEnoughCash);
    spend(cost, 'other');
    final cheats = loc.staff
        .where((s) =>
            s.honesty < 40 &&
            (s.isManager || s.role == 'cashier' || s.role == 'server'))
        .toList();
    for (final s in cheats) {
      s.daysWorked = math.max(s.daysWorked, 14);
    }
    final text = cheats.isEmpty
        ? 'The books are clean. Nobody is taking money.'
        : 'The audit found who is taking money: ${cheats.map((s) => '${s.name} (${roleName(s.role).toLowerCase()})').join(', ')}.';
    _note('audit', text, 0);
    return CommandResult(true, value: text);
  }

  // ---------------------------------------------------------- the outlet market

  void _refreshOutletMarket() {
    state.outletMarket.clear();
    final names = List<String>.of(theme.restaurantNames);
    _rng.shuffle(names);
    final taken = {for (final l in state.locations) l.name};
    final free = names.where((n) => !taken.contains(n)).toList();
    final factor = b.d('TAKEOVER_MARKET_PRICE_FACTOR');
    var ni = 0;
    for (final tier in content.tiers) {
      final saved = state.nextId;
      final l = _generateLocation(
          tier,
          free.isEmpty
              ? 'Outlet ${state.nextLocId}'
              : free[ni++ % free.length]);
      state.nextId = math.max(saved, state.nextId);
      l.format = state.stage >= 3 && _rng.chance(0.4)
          ? (_rng.chance(0.5) ? 'highStreet' : 'officeDistrict')
          : 'neighbourhood';
      l.rentWeekly = (l.rentWeekly * (_format(l)['rentMult'] ?? 1)).round();
      state.outletMarket
          .add(Offer(tier.id, (tier.price * factor).round(), 0, l));
    }
    state.sites.clear();
    final classes = ['weak', 'average', 'good', 'prime'];
    for (var i = 0; i < 3; i++) {
      final fmt = ['neighbourhood', 'highStreet', 'officeDistrict'][i];
      state.sites.add(Site(
          state.allocId(),
          _rng.pick(classes),
          fmt,
          '${_rng.pick([
                'North',
                'East',
                'River',
                'Market',
                'Station',
                'Park',
                'Old Town',
                'Harbour'
              ])} ${fmt == 'officeDistrict' ? 'Business Park' : (fmt == 'highStreet' ? 'High Street' : 'Corner')}'));
    }
  }

  int _weeklyFixed(Location l) =>
      l.rentWeekly +
      l.staff.fold<int>(0, (a, s) => a + s.wage * 6) +
      (b.d('UTILITIES_BASE') * 7).round();

  Location _adopt(Location l, {required int invested, String? themeId}) {
    l.id = state.nextLocId++;
    l.themeId = themeId ?? state.themeId;
    l.invested = invested;
    l.lastVisitDay = state.dayIndex;
    l.originalTables = l.tableSeats.length;
    l.today = DayStats(dayIndex: state.dayIndex);
    if (l.format == 'officeDistrict') {
      l.deliveryOn = true;
      state.perks.add('delivery_unlocked');
    }
    if (!state.brands.contains(l.themeId)) state.brands.add(l.themeId);
    for (final s in l.staff) {
      s.id = state.allocId();
      s.hiredDay = state.dayIndex;
    }
    for (final e in l.equipment) {
      e.id = state.allocId();
    }
    // A different cuisine needs its own menu and kitchen (doc 13: second brand).
    if (l.themeId != state.themeId ||
        l.menu.keys.any((d) =>
            content.dishes[d]!.theme != l.themeId && l.themeId != 'mixed')) {
      final th = content.themes[l.themeId]!;
      l.menu.clear();
      for (final d in content.dishesFor(l.themeId)) {
        l.menu[d.id] = MenuItem(
            dishId: d.id,
            price: d.basePrice,
            enabled:
                th.startingMenu == null || th.startingMenu!.contains(d.id));
      }
      l.equipment
          .removeWhere((e) => content.equipment[e.type]!.kind == 'station');
      for (final e in th.startingEquipment['base']!) {
        for (var i = 0; i < e.value; i++) {
          l.equipment.add(Equipment(
              id: state.allocId(), type: e.key, condition: 70, ageDays: 400));
        }
      }
    }
    state.locations.add(l);
    return l;
  }

  CommandResult _buyOutlet(int index, String? themeId) {
    if (state.stage < 3) {
      return CommandResult.fail(
          SimError.locked, 'Opening more outlets unlocks at Stage 3.');
    }
    if (index < 0 || index >= state.outletMarket.length) {
      return CommandResult.fail(SimError.unknownId);
    }
    if (themeId != null && themeId != state.themeId && state.stage < 5) {
      return CommandResult.fail(SimError.locked,
          'A second brand (another cuisine) unlocks at Stage 5.');
    }
    final o = state.outletMarket[index];
    final reserve = b.i('OPENING_RESERVE_WEEKS') * _weeklyFixed(o.location);
    if (state.cash - o.price < reserve) {
      return CommandResult.fail(SimError.notEnoughCash,
          'After paying ${money(o.price)} you must keep ${money(reserve)} (two weeks of its running costs). Cash now: ${money(state.cash)}.');
    }
    state.cash -= o.price;
    state.outletMarket.removeAt(index);
    final l = _adopt(o.location, invested: o.price, themeId: themeId);
    l.openDay = state.dayIndex + 1;
    at(l, () {
      _activateHiddenProblems(l);
      _story('Bought for ${money(o.price)}');
    });
    _timeline('Bought a second-hand restaurant: ${l.name} (${money(o.price)})');
    state.pendingNotices.add(
        '${l.name} is yours. It trades from tomorrow. It needs a manager on days you are not there.');
    return CommandResult(true, value: l.id);
  }

  CommandResult _inspectOutlet(int index) {
    if (index < 0 || index >= state.outletMarket.length) {
      return CommandResult.fail(SimError.unknownId);
    }
    final o = state.outletMarket[index];
    if (o.inspected) {
      return CommandResult.fail(SimError.limitReached, 'Already inspected.');
    }
    final cost = b.i('DUE_DILIGENCE_COST');
    if (state.cash < cost) return CommandResult.fail(SimError.notEnoughCash);
    state.cash -= cost;
    o.inspected = true;
    final hidden = List<HiddenProblem>.of(o.location.hidden);
    _rng.shuffle(hidden);
    for (var k = 0; k < (hidden.length / 2).ceil(); k++) {
      hidden[k].revealed = true;
    }
    return const CommandResult(true);
  }

  /// Cost of building from scratch (doc 02 §15.9 route B), broken down for the UI.
  Map<String, int> _buildCost(
      Site site, String size, String fitOut, String themeId) {
    final cls = content.locationClasses[site.classId]!;
    final sizeT = (b.map('BUILD_SIZES')[size] as Map).cast<String, dynamic>();
    final fitT = (b.map('FIT_OUTS')[fitOut] as Map).cast<String, dynamic>();
    final rent = (cls.weeklyRent *
            (sizeT['rent'] as num) *
            (b.map('FORMATS')[site.format] as Map)['rentMult'])
        .round();
    final fit = ((fitT['cost'] as num) * (sizeT['fitOut'] as num)).round();
    var eq = 0;
    final th = content.themes[themeId]!;
    for (final e in th.startingEquipment['base']!) {
      eq += content.equipment[e.key]!.price * e.value;
    }
    for (final t in [
      'eq_fridge',
      'eq_freezer',
      'eq_shelving',
      'eq_dish_machine',
      'eq_hood',
      'eq_pos'
    ]) {
      eq += content.equipment[t]!.price;
    }
    return {
      'fitOut': fit,
      'equipment': eq,
      'deposit': rent * 4,
      'licence': b.i('OPENING_LICENCE'),
      'rent': rent,
      'days': (fitT['days'] as num).toInt(),
    };
  }

  CommandResult _buildOutlet(
      int siteId, String size, String fitOut, String? themeId) {
    if (state.stage < 3) {
      return CommandResult.fail(
          SimError.locked, 'Opening more outlets unlocks at Stage 3.');
    }
    final site = state.sites.where((s) => s.id == siteId).firstOrNull;
    if (site == null) return CommandResult.fail(SimError.unknownId);
    final th = themeId ?? state.themeId;
    if (th != state.themeId && state.stage < 5) {
      return CommandResult.fail(SimError.locked,
          'A second brand (another cuisine) unlocks at Stage 5.');
    }
    final c = _buildCost(site, size, fitOut, th);
    final upFront =
        c['fitOut']! + c['equipment']! + c['deposit']! + c['licence']!;
    final sizeT = (b.map('BUILD_SIZES')[size] as Map).cast<String, dynamic>();
    final fitT = (b.map('FIT_OUTS')[fitOut] as Map).cast<String, dynamic>();
    final tables = (sizeT['tables'] as num).toInt();
    final staffWeek = 6 * (220 + 140 + 80 + 100 * 2 + 80);
    final reserve = b.i('OPENING_RESERVE_WEEKS') * (c['rent']! + staffWeek);
    if (state.cash - upFront < reserve) {
      return CommandResult.fail(SimError.notEnoughCash,
          'You need ${money(upFront)} now plus ${money(reserve)} in reserve.');
    }
    state.cash -= upFront;
    state.sites.remove(site);
    final six = math.max(1, (tables * 0.15).round());
    final four = (tables * 0.45).round();
    final seats = [
      for (var i = 0; i < tables - six - four; i++) 2,
      for (var i = 0; i < four; i++) 4,
      for (var i = 0; i < six; i++) 6
    ];
    final l = Location(
      id: 0,
      name: site.name,
      tierId: 'good',
      classId: site.classId,
      rentWeekly: c['rent']!,
      tableSeats: seats,
      reputation: b.d('SCRATCH_START_RATING'),
      hygiene: 95,
      buzz: (fitT['buzz'] as num).toDouble(),
      freshness: 1,
      awareness: b.d('SCRATCH_START_AWARENESS'),
    );
    l.format = site.format;
    for (final ing in content.ingredients.values) {
      l.priceIndex[ing.id] = state.loc.priceIndex[ing.id] ?? 1;
    }
    for (final s in content.suppliers.values) {
      l.supplierRel[s.id] = 50;
    }
    final thm = content.themes[th]!;
    for (final e in thm.startingEquipment['base']!) {
      for (var i = 0; i < e.value; i++) {
        l.equipment.add(Equipment(id: 0, type: e.key, condition: 100));
      }
    }
    for (final t in [
      'eq_fridge',
      'eq_freezer',
      'eq_shelving',
      'eq_dish_machine',
      'eq_hood',
      'eq_pos'
    ]) {
      l.equipment.add(Equipment(id: 0, type: t, condition: 100));
    }
    // An opening crew recruited during the fit-out (paid from the opening day).
    final used = {
      for (final x in state.locations)
        for (final s in x.staff) s.name
    };
    final centre = 20 + 10 * _companyRating();
    for (final role in [
      'headChef',
      'lineCook',
      'lineCook',
      'dishwasher',
      'server',
      'server',
      'cleaner'
    ]) {
      final skill =
          _rng.triangular(15, 90, centre.clamp(20, 80)).roundToDouble();
      l.staff.add(_makeStaff(
          role: role, skill: skill, morale: 65, wageMult: 1, usedNames: used));
    }
    _assignDaysOff(l.staff);
    _adopt(l, invested: upFront, themeId: th);
    l.openDay = state.dayIndex + c['days']!;
    at(l, () => _story('Lease signed; fit-out started (${money(upFront)})'));
    _timeline('Started building ${l.name}; opens on day ${l.openDay + 1}');
    state.pendingNotices.add(
        'Work has started on ${l.name}. Rent is due from today; it opens on day ${l.openDay + 1}.');
    return CommandResult(true, value: l.id);
  }

  // ---------------------------------------------------------- selling and closing

  int _saleEstimate() {
    final l = loc;
    final resale = l.equipment.fold<int>(0, (a, e) => a + _equipmentResale(e));
    final ws =
        l.weeks.length <= 8 ? l.weeks : l.weeks.sublist(l.weeks.length - 8);
    final avg = ws.isEmpty
        ? 0
        : ws.fold<int>(0, (a, w) => a + w.operatingProfit) ~/ ws.length;
    int est = resale +
        b.i('SALE_PROFIT_MULT') * math.max(0, avg).toInt() +
        (10000 * l.reputation).round();
    est = (est *
            (1 +
                (const {
                      'bronze': 0.05,
                      'silver': 0.10,
                      'gold': 0.20
                    }[l.badge] ??
                    0)))
        .round();
    if (l.crisis) est = (est * 0.6).round();
    return est;
  }

  CommandResult _sellCheck() {
    if (state.openLocations.length < 2) {
      return CommandResult.fail(
          SimError.locked, 'You cannot sell your only restaurant.');
    }
    if (loc.leaseLockUntil > state.dayIndex) {
      return CommandResult.fail(
          SimError.locked, 'The 2-year lease lock-in forbids selling.');
    }
    if (loc.closedUntil > state.dayIndex) {
      return CommandResult.fail(
          SimError.locked, 'Not while it is closed by an inspector.');
    }
    return const CommandResult(true);
  }

  void _completeSale(int amount) {
    final l = loc;
    state.cash += amount;
    // A loan secured on this outlet is paid first (the starting loan is secured on the first).
    if (l.id == state.locations.first.id) {
      for (final loan in state.loans.where((x) => x.secured).toList()) {
        final pay = math.min(loan.outstanding, state.cash);
        state.cash -= pay;
        loan.outstanding -= pay;
        if (loan.outstanding <= 0) state.loans.remove(loan);
      }
    }
    for (final p in l.payables) {
      state.cash -= p.amount;
    }
    l.payables.clear();
    _retire(l, 'Sold for ${money(amount)}');
  }

  void _retire(Location l, String why) {
    l.closedForGood = true;
    l.service = null;
    l.listedDay = -1;
    state.requests.removeWhere((r) => r.locationId == l.id);
    state.incidents.removeWhere((i) => i.locationId == l.id && !i.resolved);
    at(l, () => _story(why));
    _timeline('${l.name}: $why');
    if (state.ownerLocationId == l.id) {
      state.ownerLocationId = state.openLocations.first.id;
    }
    if (state.viewLocationId == l.id) {
      state.viewLocationId = state.ownerLocationId;
    }
  }

  CommandResult _quickSale() {
    final chk = _sellCheck();
    if (!chk.ok) return chk;
    final amount = (_saleEstimate() * 0.7).round();
    _completeSale(amount);
    return CommandResult(true, value: amount);
  }

  CommandResult _closeOutlet() {
    if (state.openLocations.length < 2) {
      return CommandResult.fail(
          SimError.locked, 'You cannot close your only restaurant.');
    }
    final l = loc;
    final resale = l.equipment.fold<int>(0, (a, e) => a + _equipmentResale(e));
    final severance =
        l.staff.fold<int>(0, (a, s) => a + s.wage * b.i('SEVERANCE_DAYS'));
    final fee = l.rentWeekly * 4;
    state.cash += resale - severance - fee;
    _retire(l,
        'Closed (equipment sold ${money(resale)}, severance ${money(severance)}, lease fee ${money(fee)})');
    return const CommandResult(true);
  }

  CommandResult _renovate(int tables) {
    final l = loc;
    if (tables <= 0 || tables % 2 != 0) {
      return CommandResult.fail(SimError.invalidValue, 'Add tables in pairs.');
    }
    final max =
        (l.originalTables == 0 ? l.tableSeats.length : l.originalTables) * 1.5;
    if (l.tableSeats.length + tables > max) {
      return CommandResult.fail(SimError.limitReached,
          'The room fits at most ${max.floor()} tables.');
    }
    final cost = tables * b.i('RENOVATION_COST_PER_TABLE');
    if (state.cash < cost) {
      return CommandResult.fail(
          SimError.notEnoughCash, 'Renovation costs ${money(cost)}.');
    }
    spend(cost, 'upkeep');
    for (var i = 0; i < tables; i++) {
      l.tableSeats.add(i.isEven ? 4 : 2);
    }
    final days = (tables / 4).ceil();
    final from = state.phase == 'close' ? state.dayIndex + 1 : state.dayIndex;
    l.closedUntil = math.max(l.closedUntil, from + days);
    l.buzz = math.min(1, l.buzz + 0.3);
    l.competition = math.max(0, l.competition - 0.1);
    l.invested += cost;
    _story('Renovated: +$tables tables');
    return const CommandResult(true);
  }

  // ---------------------------------------------------------- stage 4–5 systems

  CommandResult _buildCentralKitchen() {
    if (state.stage < 4) {
      return CommandResult.fail(
          SimError.locked, 'A central kitchen unlocks at Stage 4 (Chain).');
    }
    if (state.centralKitchen) {
      return CommandResult.fail(SimError.limitReached, 'You already have one.');
    }
    final cost = b.i('CENTRAL_KITCHEN_COST');
    if (state.cash < cost) {
      return CommandResult.fail(
          SimError.notEnoughCash, 'A central kitchen costs ${money(cost)}.');
    }
    state.cash -= cost;
    state.centralKitchen = true;
    _timeline('Built a central kitchen');
    return const CommandResult(true);
  }

  CommandResult _signBulk() {
    if (state.stage < 4) {
      return CommandResult.fail(
          SimError.locked, 'Bulk contracts unlock at Stage 4 (Chain).');
    }
    if (state.bulkContractUntil > state.dayIndex) {
      return CommandResult.fail(
          SimError.limitReached, 'A contract is already running.');
    }
    final fee = b.i('BULK_CONTRACT_FEE');
    if (state.cash < fee) return CommandResult.fail(SimError.notEnoughCash);
    state.cash -= fee;
    state.bulkContractUntil = state.dayIndex + 26 * 7;
    if (state.openLocations.length >= 3) _completeObjective('obj_4_bulk');
    _timeline('Signed a 26-week bulk contract');
    return const CommandResult(true);
  }

  CommandResult _startFranchise() {
    if (state.stage < 5) {
      return CommandResult.fail(
          SimError.locked, 'Franchising unlocks at Stage 5 (Group).');
    }
    if (!state.openLocations.any((l) => l.badge == 'gold')) {
      return CommandResult.fail(SimError.locked,
          'Buyers want proof the recipe works without you: earn a gold badge first.');
    }
    state.franchises++;
    final fee = b.i('FRANCHISE_SIGNING_FEE');
    state.cash += fee;
    _timeline('Sold franchise number ${state.franchises} (${money(fee)})');
    return CommandResult(true, value: fee);
  }
}

const perkText = {
  'perk_neighbourhood':
      'staff you promote to manager start with +5 people skill',
  'perk_highStreet': 'marketing costs 15% less everywhere',
  'perk_officeDistrict': 'delivery platforms take 16% instead of 20%',
};

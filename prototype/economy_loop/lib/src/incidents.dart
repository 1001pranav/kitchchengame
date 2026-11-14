import 'dart:math' as math;

import 'model.dart';
import 'sim.dart';

/// Incidents and hidden problems for the day-resolution prototype (doc 05, engine rules
/// doc 02 §11, decisions away from the owner §15.4, manager authority §15.10, §15.12).
///
/// Only the incidents whose effects a day model can express are here (see the README
/// table); per-tick service incidents (complaints, rowdy tables, critics…) are not.
/// Effects follow doc 05's numbers except where `balance.json` says otherwise; every
/// such change is listed in docs/balance-log.md entry 9.
///
/// Who answers a card:
/// - attentive owner at the outlet: best option by the doc 06 §6.1 scoring;
/// - attentive owner away: a phone call — no `inPerson` options, chances −0.10;
/// - passive owner with a manager: the call is never answered, so the manager decides
///   (only options within the 500 spending limit, chances shifted by
///   (skill − 50)/200, and only with probability clamp(0.4 + skill/100), §15.12);
/// - passive owner running the outlet alone: the default option, always.

enum Who { owner, phone, manager, nobody }

class Opt {
  final String id;
  final int cost; // known cash cost shown on the card (authority + cash floor)
  final bool inPerson;

  /// Expected value in coins (doc 06 §6.1: cash + 20,000 × rating + 50 × morale summed),
  /// given the shift applied to this option's success chances.
  final double Function(double shift) ev;
  final void Function(double shift) apply;
  const Opt(this.id, this.cost, this.ev, this.apply, {this.inPerson = false});
}

class Card {
  final String id;
  final String cat; // staff | stock | upkeep | customer | money
  final List<Opt> options;
  final String defaultId;
  final String text;
  Card(this.id, this.cat, this.text, this.options, this.defaultId);
}

class _Def {
  final String id;
  final String timing; // prep | close
  final double weight;
  final int cooldown;
  final bool Function() trigger;
  final Card? Function() make;
  _Def(this.id, this.timing, this.weight, this.cooldown, this.trigger,
      this.make);
}

class IncidentEngine {
  final OutletSim s;
  final Map<String, int> _last = {};
  final List<(int, Card Function())> _scheduled = [];
  final List<(int, int)> _payables = []; // (due day, amount)
  late final List<_Def> _defs;

  /// Hidden problems drawn at takeover (doc 05 §4), for reports.
  final List<String> hidden = [];

  /// Over the whole run: incidents raised, by who decided, and default choices.
  final Map<Who, int> decided = {for (final w in Who.values) w: 0};
  int raised = 0, defaults = 0;
  final Map<String, int> byId = {};

  IncidentEngine(this.s) {
    _defs = _catalogue();
    if (s.scratch == null && !_disabled.contains('hidden')) {
      _drawHidden(s.b.i('HIDDEN_PROBLEMS'));
    }
  }

  // ------------------------------------------------------------- helpers

  double get _mpg =>
      s.b.d('PROTO_SPEND_PER_GROUP') *
      s.priceIndex *
      (1 - s.b.d('PROTO_FOOD_COST') * (1 + s.b.d('PROTO_BASE_WASTE')));
  double get _groups => s.forecast();
  double get _dayMargin => _groups * _mpg;
  double get _dayRevenue =>
      _groups * s.b.d('PROTO_SPEND_PER_GROUP') * s.priceIndex;
  double get _dayIngredients =>
      _groups * s.b.d('PROTO_SPEND_PER_GROUP') * s.b.d('PROTO_FOOD_COST');
  double get _weekCosts => s.fixedPerDay * 7;
  int get _n => math.max(1, s.crew.where((c) => !c.vacant).length);
  double _p(double p, double shift) =>
      p + shift < 0 ? 0 : (p + shift > 1 ? 1 : p + shift);

  void _cash(int amount) {
    s.cash += amount;
    if (amount < 0) s.week.other -= amount;
  }

  void _morale(double summed) =>
      s.crewMorale = clampD(s.crewMorale + summed / _n, 0, 100);

  /// Expected days a vacancy stays open, by who hires (doc 02 §15.12, doc 06 §6.1).
  double get _vacancyDays {
    if (s.ownerRun) return s.ownerDoesChores ? 4 : 90;
    final p = clampD(0.4 + s.manager.people / 100, 0.05, 1);
    return 3.5 + 7 * (1 - p) / p;
  }

  /// Coins lost while [st] is gone: the gap's walk-outs minus the wage saved.
  double _vacancyCost(Staff st) {
    final shared = s.crew.any((o) => o != st && o.role == st.role && !o.vacant);
    final gap = shared ? 0.5 : 1.0;
    final chef = st.role == 'headChef' ? 0.06 * _dayRevenue : 0.0; // food score
    final perDay = gap * s.b.d('PROTO_WALKOUT_PER_GAP') * _groups * _mpg +
        chef -
        st.wage * 6 / 7;
    return -perDay * _vacancyDays;
  }

  void _leave(Staff st, int inDays, String why, List<String> notes) {
    _schedule(inDays, () {
      st.vacant = true;
      notes.add('Your ${st.role} left ($why).');
      return null;
    });
  }

  Staff? _pickStaff(bool Function(Staff) f) {
    final c = s.crew.where((x) => !x.vacant && f(x)).toList();
    return c.isEmpty ? null : c[s.rng.nextInt(0, c.length - 1)];
  }

  void _schedule(int inDays, Card? Function() f) =>
      _scheduled.add((s.day + inDays, () => f() ?? _noop));
  static final _noop = Card('noop', 'money', '', const [], '');

  Who _who(bool present) {
    if (s.ownerAnswersCards) return present ? Who.owner : Who.phone;
    if (s.ownerRun) return Who.nobody;
    return Who.manager;
  }

  double _skill(String cat) => switch (cat) {
        'staff' => s.manager.people,
        'upkeep' => s.manager.upkeep,
        'stock' => s.manager.stock,
        _ => s.manager.mean,
      };

  // ------------------------------------------------------------- resolution

  void raise(Card c, bool present, List<String> notes) {
    if (c.options.isEmpty || _disabled.contains(c.id)) return;
    raised++;
    s.week.incidents++;
    byId[c.id] = (byId[c.id] ?? 0) + 1;
    final dflt = c.options.firstWhere((o) => o.id == c.defaultId);
    final who = _who(present);
    decided[who] = decided[who]! + 1;
    var shift = 0.0;
    var pool = <Opt>[];
    switch (who) {
      case Who.owner:
      case Who.phone:
        shift = who == Who.phone ? -s.b.d('PHONE_PENALTY') : 0;
        pool = c.options
            .where((o) => who == Who.owner || !o.inPerson)
            .where((o) => o.cost <= 0 || s.cash - o.cost >= _weekCosts)
            .toList();
      case Who.manager:
        final sk = _skill(c.cat);
        shift = (sk - 50) / 200;
        if (s.rng.chance(clampD(0.4 + sk / 100, 0, 1))) {
          pool = c.options
              .where((o) =>
                  !o.inPerson &&
                  o.cost <= s.b.i('MANAGER_SPENDING_LIMIT') &&
                  o.cost <= s.cash)
              .toList();
        }
      case Who.nobody:
        break;
    }
    if (!pool.contains(dflt)) pool.add(dflt);
    var best = dflt;
    var bestEv = dflt.ev(shift);
    for (final o in pool) {
      final v = o.ev(shift);
      if (v > bestEv + 1) {
        best = o;
        bestEv = v;
      }
    }
    if (best == dflt) {
      defaults++;
      s.week.incidentDefaults++;
    }
    final by = switch (who) {
      Who.owner => 'you',
      Who.phone => 'you, by phone',
      Who.manager => s.manager.name,
      Who.nobody => 'nobody',
    };
    notes.add('Incident: ${c.text} → ${best.id} ($by).');
    best.apply(shift);
  }

  /// A breakdown handled by the existing repair rule in sim.dart (doc 05 #21).
  void countForced(bool byDefault) {
    raised++;
    s.week.incidents++;
    if (byDefault) {
      defaults++;
      s.week.incidentDefaults++;
    }
  }

  // ------------------------------------------------------------- daily hooks

  void prep(bool present, List<String> notes) {
    // Debts falling due (doc 05 `payable`).
    for (final p in _payables.where((p) => p.$1 == s.day)) {
      s.cash -= p.$2;
      s.week.inherited += p.$2;
      notes.add('Paid an old supplier debt of ${p.$2}.');
    }
    // Scheduled follow-ups and hidden problems.
    final due = _scheduled.where((x) => x.$1 == s.day).toList();
    _scheduled.removeWhere((x) => x.$1 == s.day);
    for (final (_, f) in due) {
      raise(f(), present, notes);
    }
    if (s.day < s.closedUntil) return;

    // Ongoing problems left by a default option.
    if (s.flag('leak') && s.rng.chance(s.b.d('LEAK_FLOOD_CHANCE'))) {
      s.closedUntil = math.max(s.closedUntil, s.day + 1);
      notes.add('The leak flooded the kitchen: closed today.');
      s.flags.remove('leak');
      _cash(-s.b.i('LEAK_FLOOD_COST'));
      return;
    }
    if (s.flag('skimming')) s.revenueLossToday += 0.03;

    // Deliveries (doc 02 §9: problem chance 1 − reliability; 50% late, 30% short,
    // 20% bad batch).
    if (s.rng.chance(1 - s.b.d('SUPPLIER_RELIABILITY'))) {
      final r = s.rng.nextFloat();
      if (r < 0.5) {
        raise(_deliveryLate(), present, notes);
      } else if (r < 0.8) {
        s.menuLossToday += s.rng.uniform(0.1, 0.25);
        notes.add('The delivery came short; some dishes are off today.');
      } else {
        raise(_badBatch(), present, notes);
      }
    }
    // Inspection notice (doc 05 #36): 50% of inspections give a day's warning.
    if (s.inspectionDay == s.day + 1 && s.rng.chance(0.5)) {
      raise(_inspectionNotice(), present, notes);
    }
    // Rare compliance incidents with no weight (doc 05 #38, #39).
    if (s.tradingDay > 0 &&
        s.tradingDay % 28 == 0 &&
        _off('inc_tax_audit', 168) &&
        s.rng.chance(0.10)) {
      _last['inc_tax_audit'] = s.day;
      raise(_taxAudit(), present, notes);
    }
    if (_off('inc_licence_overdue', 168) && s.rng.chance(0.02 / 28)) {
      _last['inc_licence_overdue'] = s.day;
      raise(_licence(), present, notes);
    }
    // Landlord (doc 05 #28): forced every 168 days from day 84.
    if (s.tradingDay >= 84 && (s.tradingDay - 84) % 168 == 0) {
      raise(_landlord(hidden.contains('lease') && s.tradingDay == 84), present,
          notes);
    }
    // Food poisoning the day after an ill group (doc 05 #30).
    if (s.illGroupToday) raise(_foodPoisoning(), present, notes);

    // Weighted prep rolls (doc 02 §11): up to two.
    for (var i = 0; i < 2; i++) {
      if (!_roll('prep', present, notes)) break;
    }
  }

  void close(bool present, List<String> notes, {required double walkoutShare}) {
    _walkoutShare = walkoutShare;
    _roll('close', present, notes);
    // An ill group from a bad batch used today, or a dirty kitchen (PROTO).
    final pIll = (s.flag('badBatchUsed') ? s.b.d('ILL_FROM_BAD_BATCH') : 0.0) +
        (s.hygiene < 50 ? s.b.d('ILL_FROM_LOW_HYGIENE') : 0.0);
    if (s.rng.chance(pIll)) s.illGroupToday = true;
  }

  double _walkoutShare = 0;

  static final _disabled =
      const String.fromEnvironment('OFF').split(',').toSet();
  bool _off(String id, int cd) => s.day - (_last[id] ?? -9999) >= cd;

  bool _roll(String timing, bool present, List<String> notes) {
    final elig = _defs
        .where(
            (d) => d.timing == timing && _off(d.id, d.cooldown) && d.trigger())
        .toList();
    if (elig.isEmpty) return false;
    final total = elig.fold(0.0, (a, d) => a + d.weight);
    if (!s.rng.chance(math.min(0.9, total * s.b.d('INCIDENT_FREQ')))) {
      return false;
    }
    final d = s.rng.weighted(elig, elig.map((d) => d.weight).toList());
    _last[d.id] = s.day;
    final c = d.make();
    if (c != null) raise(c, present, notes);
    return true;
  }

  // ------------------------------------------------------------- hidden problems

  void _drawHidden(int n) {
    final pool = [
      'supplierDebt',
      'healthViolation',
      'chefLeaving',
      'pests',
      'fridge',
      if (s.ownerRun)
        'skimming', // a managed crew has no cashier (doc 02 §15.15)
      'lease',
      'licence',
      'feud',
      'fakeReviews',
    ];
    for (var i = 0; i < n && pool.isNotEmpty; i++) {
      final h = pool.removeAt(s.rng.nextInt(0, pool.length - 1));
      hidden.add(h);
      final o = s.openDay;
      switch (h) {
        case 'supplierDebt':
          _payables
              .add((o + s.rng.nextInt(14, 28), s.rng.nextInt(8, 20) * 1000));
        case 'healthViolation':
          s.hygiene = math.max(0, s.hygiene - 20);
          s.inspectionDay = o + s.rng.nextInt(7, 14);
        case 'chefLeaving':
          final chef = s.crew.firstWhere((c) => c.role == 'headChef');
          _schedule(s.rng.nextInt(10, 20),
              () => s.crewMorale >= 60 ? null : _resignation(chef));
        case 'pests':
          _schedule(5, () {
            s.flags['pests'] = 1 << 30;
            return null;
          });
        case 'fridge':
          s.equipment.firstWhere((e) => e.type == 'fridge').condition = 30;
        case 'skimming':
          s.flags['skimming'] = 1 << 30;
        case 'lease':
          break; // landlord card at day 84 asks +15%
        case 'licence':
          _schedule(7, _licence);
        case 'feud':
          _morale(-40);
        case 'fakeReviews':
          _schedule(s.rng.nextInt(14, 21), () {
            s.reputation = math.max(0, s.reputation - 0.5);
            return null;
          });
      }
    }
  }

  // ------------------------------------------------------------- catalogue

  List<_Def> _catalogue() => [
        _Def('inc_wage_demand', 'close', 0.3, 14, () => s.crew.any(_underpaid),
            _wageDemand),
        _Def(
            'inc_poaching',
            'close',
            0.15,
            21,
            () =>
                s.reputation >= 3.5 &&
                s.crew.any((c) => !c.vacant && c.skill > 65),
            _poaching),
        _Def('inc_skimming', 'close', 0.4, 14,
            () => s.flag('skimming') && s.ownerRun, _skimming),
        _Def('inc_price_spike', 'prep', 0.2, s.b.i('PRICE_SPIKE_COOLDOWN'),
            () => true, _priceSpike),
        _Def(
            'inc_fridge_warm',
            'prep',
            0.4,
            7,
            () => s.equipment.any(
                (e) => e.type == 'fridge' && !e.broken && e.condition < 50),
            _fridgeWarm),
        _Def('inc_plumbing_leak', 'prep', 0.08, s.b.i('LEAK_COOLDOWN'),
            () => !s.flag('leak'), _leak),
        _Def('inc_pests', 'prep', 0.3, 21, () => s.hygiene < 55, _pests),
        // A service incident (weight ÷ 12, rolled about 16 times a service, doc 02 §11)
        // rolled once a day here. The summer ×2 is not modelled.
        _Def('inc_power_cut', 'prep', 0.1 * 16 / 12, 14, () => true, _powerCut),
        _Def('inc_competitor_opens', 'prep', 0.1, 112, () => s.tradingDay >= 56,
            _competitor),
        _Def('inc_big_booking', 'prep', 0.15, 10, () => s.b.i('TABLES') >= 12,
            _bigBooking),
        _Def(
            'inc_unexpected_windfall', 'prep', 0.05, 28, () => true, _windfall),
        _Def('inc_bad_review_viral', 'close', 0.3, 14,
            () => _walkoutShare > 0.2, _badReview),
      ];

  /// doc 05 #2: wage < expectedWage × 0.9 (doc 02 §7: base × (0.6 + 0.8 × skill/100)),
  /// or back from a course in the last week.
  bool _underpaid(Staff c) {
    if (c.vacant) return false;
    final base = (s.b.map('BASE_WAGE')[c.role] as num).toDouble();
    final expected = base * (0.6 + 0.8 * c.skill / 100);
    return c.wage < 0.9 * expected ||
        (c.trainingUntil > 0 &&
            c.trainingUntil <= s.day &&
            c.trainingUntil > s.day - 7);
  }

  Card _wageDemand() {
    final st = _pickStaff(_underpaid)!;
    final quitCost = 0.4 * _vacancyCost(st);
    final raiseCost = st.wage * 6 * 13; // a quarter's wages
    return Card(
        'inc_wage_demand',
        'staff',
        '${st.role} asks for a raise',
        [
          Opt('agree', 0, (_) => -0.15 * raiseCost + 50 * 10, (_) {
            st.wage = (st.wage * 1.15).round();
            _morale(10);
          }),
          Opt(
              'offer half',
              0,
              (sh) =>
                  -0.07 * raiseCost +
                  50 * (_p(0.5, sh) * 3 - (1 - _p(0.5, sh)) * 8), (sh) {
            st.wage = (st.wage * 1.07).round();
            _morale(s.rng.chance(_p(0.5, sh)) ? 3 : -8);
          }),
          Opt('refuse', 0, (_) => -50 * 15 + quitCost, (_) {
            _morale(-15);
            if (s.rng.chance(0.4)) _schedule(7, () => _resignation(st));
          }),
        ],
        'refuse');
  }

  Card? _resignation(Staff st) {
    if (st.vacant) return null;
    final gone = _vacancyCost(st);
    final notes = <String>[];
    return Card(
        'inc_resignation',
        'staff',
        '${st.role} hands in notice',
        [
          Opt('counter-offer', 0,
              (sh) => -0.2 * st.wage * 6 * 13 + (1 - _p(0.6, sh)) * gone, (sh) {
            st.wage = (st.wage * 1.2).round();
            if (!s.rng.chance(_p(0.6, sh))) {
              _leave(st, 5, 'after notice', notes);
            }
          }),
          Opt('accept', 0, (_) => gone,
              (_) => _leave(st, 5, 'after notice', notes)),
          Opt('leave today', 0, (_) => gone * 1.1 - 50 * 3, (_) {
            st.vacant = true;
            _morale(-3);
          }),
        ],
        'accept');
  }

  Card? _poaching() {
    final st = _pickStaff((c) => c.skill > 65);
    if (st == null) return null;
    final gone = _vacancyCost(st);
    final notes = <String>[];
    return Card(
        'inc_poaching',
        'staff',
        'a rival tries to poach your ${st.role}',
        [
          Opt('match', 0, (_) => -0.25 * st.wage * 6 * 13,
              (_) => st.wage = (st.wage * 1.25).round()),
          Opt('wish well', 0, (_) => 0.7 * gone, (_) {
            if (s.rng.chance(0.7)) _leave(st, 5, 'poached', notes);
          }),
        ],
        'wish well');
  }

  Card _skimming() {
    final cashier = s.crew.firstWhere((c) => c.role == 'cashier');
    final loss = 0.03 * _dayRevenue * 60;
    return Card(
        'inc_skimming',
        'staff',
        'the till keeps coming up short',
        [
          Opt('fire', 0, (_) => _vacancyCost(cashier) - 50 * 2 * _n, (_) {
            s.flags.remove('skimming');
            cashier.vacant = true;
            _morale(-2.0 * _n);
          }, inPerson: true),
          Opt('warn', 0, (sh) => -(1 - _p(0.5, sh)) * loss, (sh) {
            if (s.rng.chance(_p(0.5, sh))) s.flags.remove('skimming');
          }),
          Opt('not sure', 0, (_) => -loss, (_) {}),
        ],
        'not sure');
  }

  Card _priceSpike() {
    final week = 7 * _dayIngredients * 0.125;
    final until = s.day + 6;
    return Card(
        'inc_price_spike',
        'stock',
        'a food category costs 50% more this week',
        [
          Opt('absorb', 0, (_) => -week,
              (_) => s.ingredientMods.add((1.125, until))),
          Opt('raise prices', 0, (_) => -week + 7 * 0.0125 * _dayRevenue, (_) {
            s.ingredientMods.add((1.125, until));
            s.priceMods.add((1.025, until));
          }),
          Opt(
              '86 dishes',
              0,
              (_) => -7 * 0.1 * 0.5 * _dayRevenue - 20000 * 0.02,
              (_) => s.menuLossMods.add((0.1, until))),
        ],
        'absorb');
  }

  Card _deliveryLate() {
    final shortMenu = -0.3 * 0.5 * _dayRevenue - 20000 * 0.01;
    return Card(
        'inc_delivery_late',
        'stock',
        'the delivery is a day late',
        [
          Opt(
              'cash & carry',
              (0.15 * 0.4 * _dayIngredients).round(),
              (_) => -0.15 * 0.4 * _dayIngredients,
              (_) => s.ingredientMods.add((1.06, s.day))),
          Opt('short menu', 0, (_) => shortMenu, (_) => s.menuLossToday += 0.3),
          Opt('complain', 0,
              (sh) => shortMenu + _p(0.4, sh) * 0.1 * 0.4 * _dayIngredients,
              (sh) {
            s.menuLossToday += 0.3;
            if (s.rng.chance(_p(0.4, sh))) {
              _cash((0.04 * _dayIngredients).round());
            }
          }),
        ],
        'short menu');
  }

  Card _badBatch() {
    final ill = s.b.d('ILL_FROM_BAD_BATCH') * 0.5 * 20000 * 0.6;
    return Card(
        'inc_bad_batch',
        'stock',
        'a delivery batch is spoiled',
        [
          Opt(
              'reject',
              (0.15 * 0.3 * _dayIngredients).round(),
              (_) => -0.15 * 0.3 * _dayIngredients,
              (_) => s.ingredientMods.add((1.045, s.day))),
          Opt('use anyway', 0, (_) => -20000 * 0.02 - ill, (_) {
            s.foodPenaltyToday += s.b.d('BAD_BATCH_FOOD_PENALTY');
            s.flags['badBatchUsed'] = s.day;
          }),
          Opt('staff meals', 0, (_) => -0.3 * 0.5 * _dayRevenue + 50 * 2 * _n,
              (_) {
            s.menuLossToday += 0.3;
            _morale(2.0 * _n);
          }),
        ],
        'use anyway');
  }

  Card _fridgeWarm() {
    final fridge = s.equipment.firstWhere((e) => e.type == 'fridge');
    // A failure costs the breakdown's spoilage, a repair and two days without chilled dishes.
    final breakCost =
        600 + 4000 * s.b.d('PROPER_REPAIR_PCT') + 2 * 0.3 * 0.5 * _dayRevenue;
    return Card(
        'inc_fridge_warm',
        'upkeep',
        'the fridge is running warm',
        [
          Opt('emergency service', 400, (_) => -400, (_) {
            _cash(-400);
            fridge.condition =
                math.min(fridge.maxCondition, fridge.condition + 20);
          }),
          Opt('hope', 0, (sh) => -(1 - _p(0.65, sh)) * breakCost, (sh) {
            // 35%: it fails tonight; the breakdown rule then spoils the stock and repairs it
            // (or, for the passive bot, leaves it broken).
            if (!s.rng.chance(_p(0.65, sh))) s.forceBreak.add('fridge');
          }),
          Opt('ice boxes', 150, (_) => -150 - 80, (_) {
            _cash(-150 - 80);
            fridge.condition =
                math.min(fridge.maxCondition, fridge.condition + 15);
          }),
        ],
        'hope');
  }

  Card _leak() {
    final days = 1 / s.b.d('LEAK_FLOOD_CHANCE');
    final bucket = -days *
            (s.b.d('LEAK_HYGIENE') *
                    50 + // hygiene → inspection fines and rating
                0) -
        (0.9 * _dayRevenue * 0.66 + s.b.d('LEAK_FLOOD_COST'));
    return Card(
        'inc_plumbing_leak',
        'upkeep',
        'a pipe is leaking',
        [
          Opt('plumber now', 600, (_) => -600, (_) => _cash(-600)),
          Opt('bucket', 0, (_) => bucket, (_) => s.flags['leak'] = 1 << 30),
        ],
        'bucket');
  }

  Card _pests() {
    final ongoing = -s.b.d('PESTS_HYGIENE') * 50 * 28 - 0.5 * 1500;
    return Card(
        'inc_pests',
        'upkeep',
        'staff have seen mice',
        [
          Opt('treatment', 1200, (_) => -1200 - _dayMargin, (_) {
            _cash(-1200);
            s.closedUntil = math.max(s.closedUntil, s.day + 1);
            s.hygiene = math.min(100, s.hygiene + 20);
            s.flags.remove('pests');
          }),
          Opt('diy traps', 150, (sh) => -150 + (1 - _p(0.5, sh)) * ongoing,
              (sh) {
            _cash(-150);
            if (s.rng.chance(_p(0.5, sh))) {
              s.flags.remove('pests');
            } else {
              s.flags['pests'] = 1 << 30;
            }
          }),
          Opt('ignore', 0, (_) => ongoing, (_) {
            s.flags['pests'] = 1 << 30;
            if (s.rng.chance(0.5)) {
              s.inspectionDay = s.inspectionDay > s.day
                  ? math.min(s.inspectionDay, s.day + 7)
                  : s.day + 7;
            }
          }),
        ],
        'ignore');
  }

  Card _powerCut() {
    return Card(
        'inc_power_cut',
        'upkeep',
        'a power cut in service',
        [
          Opt('candles', 0, (_) => -0.03 * _dayRevenue,
              (_) => s.revenueLossToday += 0.03,
              inPerson: true),
          Opt('close the hour', 0, (_) => -0.08 * _dayRevenue - 20000 * 0.005,
              (_) => s.revenueLossToday += 0.08),
          Opt('generator', 800, (_) => -800 - 0.015 * _dayRevenue, (_) {
            _cash(-800);
            s.revenueLossToday += 0.015;
          }),
        ],
        'close the hour');
  }

  Card _competitor() {
    final m = _dayMargin;
    final until = s.day + 27;
    return Card(
        'inc_competitor_opens',
        'customer',
        'a competitor opens nearby',
        [
          Opt('hold steady', 0, (_) => -0.15 * 28 * m,
              (_) => s.demandMods.add((0.85, until))),
          // Prices −10% for 14 days hold demand (the lower price itself brings some back),
          // then the competitor bites for the other 14.
          Opt('price promotion', 0,
              (_) => -0.15 * 14 * m - 0.1 * 14 * _dayRevenue, (_) {
            s.priceMods.add((0.9, s.day + 13));
            s.delayedDemandMods.add((s.day + 14, 0.85, until));
          }),
          Opt('marketing push', 1500, (_) => -1500 - 0.05 * 28 * m, (_) {
            _cash(-1500);
            s.week.marketing += 1500;
            s.week.other -= 1500;
            s.demandMods.add((0.95, until));
          }),
        ],
        'hold steady');
  }

  Card _bigBooking() {
    final party = 12 * s.b.d('PROTO_SPEND_PER_GROUP') / 2.4 * s.priceIndex;
    final margin = party * (1 - s.b.d('PROTO_FOOD_COST'));
    return Card(
        'inc_big_booking',
        'customer',
        'a party of 12 wants to book',
        [
          Opt('accept', 0, (_) => 0.85 * margin, (_) {
            if (s.rng.chance(0.85)) _bonusRevenue(party);
          }),
          Opt('deposit', 0, (_) => 200 + 0.7 * margin, (_) {
            _cash(200);
            if (s.rng.chance(0.7)) _bonusRevenue(party);
          }),
          Opt('decline', 0, (_) => 0, (_) {}),
        ],
        'decline');
  }

  void _bonusRevenue(double party) {
    final food = (party * s.b.d('PROTO_FOOD_COST')).round();
    s.cash += party.round() - food;
    s.week.revenue += party.round();
    s.week.ingredients += food;
  }

  Card _windfall() {
    return Card(
        'inc_unexpected_windfall',
        'money',
        'a film crew wants the dining room',
        [
          Opt('accept', 0, (_) => 1200 - 0.15 * _dayMargin, (_) {
            s.cash += 1200;
            s.week.revenue += 1200;
            s.revenueLossToday += 0.15;
          }),
          Opt('decline', 0, (_) => 0, (_) {}),
        ],
        'decline');
  }

  Card _badReview() {
    return Card(
        'inc_bad_review_viral',
        'customer',
        'an angry review is spreading',
        [
          Opt('apologise', 300, (_) => -300 + 0.05 * 3 * _dayMargin, (_) {
            _cash(-300);
            s.demandMods.add((1.05, s.day + 3));
          }),
          Opt(
              'argue',
              0,
              (sh) => 20000 * (_p(0.3, sh) * 0.1 - (1 - _p(0.3, sh)) * 0.3),
              (sh) => s.reputation = clampD(
                  s.reputation + (s.rng.chance(_p(0.3, sh)) ? 0.1 : -0.3),
                  0,
                  5)),
          Opt('ignore', 0, (_) => -20000 * 0.15,
              (_) => s.reputation = math.max(0, s.reputation - 0.15)),
        ],
        'ignore');
  }

  Card _foodPoisoning() {
    return Card(
        'inc_food_poisoning',
        'customer',
        'a guest says they got food poisoning',
        [
          Opt('apologise, pay', 500, (_) => -500 - 20000 * 0.1, (_) {
            _cash(-500);
            s.reputation = math.max(0, s.reputation - 0.1);
          }),
          Opt('deny', 0, (sh) => -(1 - _p(0.5, sh)) * (20000 * 0.6 + 1500),
              (sh) {
            if (!s.rng.chance(_p(0.5, sh))) {
              s.reputation = math.max(0, s.reputation - 0.6);
              s.inspectionDay = s.day + 2;
            }
          }),
          Opt('refund quietly', 150,
              (sh) => -150 - (1 - _p(0.75, sh)) * (20000 * 0.6 + 1500), (sh) {
            _cash(-150);
            if (!s.rng.chance(_p(0.75, sh))) {
              s.reputation = math.max(0, s.reputation - 0.6);
              s.inspectionDay = s.day + 2;
            }
          }),
        ],
        'deny');
  }

  Card _inspectionNotice() {
    // Expected fine avoided by +15 hygiene: rough, from the doc 02 §12 bands.
    double fine(double h) => h >= 80
        ? -20000 * 0.1
        : h >= 50
            ? s.b.d('INSPECTION_FINE_WARN')
            : s.b.d('INSPECTION_FINE_CLOSE') + 20000 * 0.5 + 2 * _dayMargin;
    final gain = fine(s.hygiene) - fine(math.min(100, s.hygiene + 15));
    return Card(
        'inc_inspection',
        'upkeep',
        'an inspector is coming tomorrow',
        [
          Opt('deep clean', 400, (_) => -400 + gain, (_) {
            _cash(-400);
            s.hygiene = math.min(100, s.hygiene + 15);
          }, inPerson: true),
          Opt('carry on', 0, (_) => 0, (_) {}),
        ],
        'carry on');
  }

  Card _taxAudit() {
    return Card(
        'inc_tax_audit',
        'money',
        'the tax office opens an audit',
        [
          Opt('accountant', 800, (_) => -800, (_) => _cash(-800)),
          Opt('handle yourself', 0,
              (sh) => -(1 - _p(0.7, sh)) * 2000 - s.b.d('OWNER_DAY_VALUE'),
              (sh) {
            if (!s.rng.chance(_p(0.7, sh))) _cash(-2000);
          }),
        ],
        'handle yourself');
  }

  Card _licence() {
    return Card(
        'inc_licence_overdue',
        'upkeep',
        'the trading licence is overdue',
        [
          Opt('pay now', 1000, (_) => -1000, (_) => _cash(-1000)),
          Opt('delay', 0, (_) => -3000 - _dayMargin, (_) => _licenceDelay()),
        ],
        'delay');
  }

  /// Delay: 25% a week that the council fines 3,000 and closes the outlet for a day,
  /// then the licence is settled (doc 05 #39).
  void _licenceDelay() {
    _schedule(7, () {
      if (s.rng.chance(0.25)) {
        _cash(-3000);
        s.closedUntil = math.max(s.closedUntil, s.day + 1);
        return null;
      }
      _licenceDelay();
      return null;
    });
  }

  Card _landlord(bool hiddenLease) {
    final up = hiddenLease ? 0.15 : 0.08;
    final w = s.b.i('WEEKLY_RENT') * 26.0;
    final good = s.reputation >= 4 ? 0.6 : 0.3;
    return Card(
        'inc_landlord_rent',
        'money',
        'the landlord raises the rent ${(up * 100).round()}%',
        [
          Opt('accept', 0, (_) => -up * w, (_) => s.rentMult *= 1 + up),
          Opt('negotiate', 0, (sh) {
            final p = _p(good, sh);
            return -(p * 0.03 + (1 - p) * (s.reputation >= 4 ? up : 0.10)) * w;
          }, (sh) {
            final p = _p(good, sh);
            s.rentMult *=
                1 + (s.rng.chance(p) ? 0.03 : (s.reputation >= 4 ? up : 0.10));
          }),
          Opt('lock in', 0, (_) => -0.04 * w, (_) => s.rentMult *= 1.04),
        ],
        'accept');
  }
}

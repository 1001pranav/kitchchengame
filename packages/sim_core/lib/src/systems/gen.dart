part of '../sim.dart';

// Generators: restaurant offers, staff, applicants (doc 01 §4.3, doc 04 §3, §5, §6).

const hiddenProblemKinds = [
  'supplier_debt',
  'health_violation',
  'chef_leaving',
  'pests',
  'fridge_failing',
  'cashier_skimming',
  'lease_increase',
  'overdue_licence',
  'staff_feud',
  'fake_reviews',
];

const hiddenProblemText = {
  'supplier_debt': 'Unpaid bill to a supplier',
  'health_violation': 'A health violation is about to be reported',
  'chef_leaving': 'The head chef is planning to quit',
  'pests': 'Pests are moving in',
  'fridge_failing': 'The fridge is about to fail',
  'cashier_skimming': 'The cashier takes money from the till',
  'lease_increase': 'The landlord will raise the rent',
  'overdue_licence': 'The trading licence is overdue',
  'staff_feud': 'Two staff members are feuding',
  'fake_reviews': 'Fake good reviews are about to be removed',
};

extension _Gen on Sim {
  int _expectedWage(String role, double skill) {
    final base = b.dmap('BASE_WAGE')[role]!;
    return (base * (0.6 + 0.8 * skill / 100)).round();
  }

  List<String> _rollTraits(String role, {bool forceBadApple = false}) {
    final traits = content.traits.values
        .where((t) => t.roles == null || t.roles!.contains(role))
        .toList();
    final r = _rng.nextFloat();
    final n = r < 0.5 ? 0 : (r < 0.9 ? 1 : 2);
    final out = <String>[];
    if (forceBadApple)
      out.add(_rng.chance(0.5) ? 'trait_toxic' : 'trait_hot_headed');
    for (var i = 0; i < n; i++) {
      final t = _rng.pick(traits).id;
      if (out.contains(t)) continue;
      if ((t == 'trait_toxic' && out.contains('trait_mentor')) ||
          (t == 'trait_mentor' && out.contains('trait_toxic'))) {
        continue;
      }
      out.add(t);
    }
    return out;
  }

  int _preferredDayOff() {
    final r = _rng.nextFloat();
    if (r < 0.25) return 5;
    if (r < 0.5) return 6;
    return _rng.nextInt(0, 4);
  }

  String _personName(Set<String> used) {
    for (var i = 0; i < 20; i++) {
      final n =
          '${_rng.pick(theme.firstNames)} ${_rng.pick(theme.lastNames)[0]}.';
      if (!used.contains(n)) {
        used.add(n);
        return n;
      }
    }
    return '${_rng.pick(theme.firstNames)} ${state.nextId}';
  }

  Staff _makeStaff({
    required String role,
    required double skill,
    required double morale,
    required double wageMult,
    required Set<String> usedNames,
    bool badApple = false,
  }) {
    final rel = (morale + _rng.range(-20, 20)).clamp(5, 98).toDouble();
    final loy = (morale + _rng.range(-20, 20)).clamp(5, 98).toDouble();
    final traits = _rollTraits(role, forceBadApple: badApple);
    var honesty = _rng.range(30, 95);
    if (traits.contains('trait_light_fingered'))
      honesty = math.min(honesty, 30);
    return Staff(
      id: state.allocId(),
      name: _personName(usedNames),
      role: role,
      skill: skill.roundToDouble(),
      reliability: rel.roundToDouble(),
      loyalty: loy.roundToDouble(),
      honesty: honesty.roundToDouble(),
      morale: morale.clamp(0, 100).roundToDouble(),
      fatigue: 20,
      wage: (_expectedWage(role, skill) * wageMult).round(),
      traits: traits,
      dayOff: 0,
      preferredDayOff: _preferredDayOff(),
    );
  }

  /// Days off across Mon–Thu; same-role holders on different days (doc 02 §7.7).
  void _assignDaysOff(List<Staff> staff) {
    final used = <String, Set<int>>{};
    var cursor = 0;
    for (final s in staff) {
      final taken = used.putIfAbsent(s.role, () => {});
      var d = cursor % 4;
      for (var k = 0; k < 4 && taken.contains(d); k++) {
        d = (d + 1) % 4;
      }
      s.dayOff = d;
      taken.add(d);
      cursor++;
    }
  }

  void _generateOffers() {
    state.offers.clear();
    final names = List<String>.of(theme.restaurantNames);
    _rng.shuffle(names);
    var ni = 0;
    for (final tier in content.tiers) {
      final location = _generateLocation(tier, names[ni++ % names.length]);
      state.offers.add(Offer(tier.id, tier.price, tier.loan, location));
    }
  }

  Location _generateLocation(Tier tier, String name) {
    final cls = content.locationClasses[tier.locationClass]!;
    // Tables: 40% two-seat, 45% four-seat, 15% six-seat, at least one six.
    final n = tier.tables;
    final six = math.max(1, (n * 0.15).round());
    final four = (n * 0.45).round();
    final two = n - six - four;
    final seats = [
      for (var i = 0; i < two; i++) 2,
      for (var i = 0; i < four; i++) 4,
      for (var i = 0; i < six; i++) 6
    ];
    final hyg = b.dmap('START_HYGIENE')[tier.id]!;
    final loc = Location(
      id: 1,
      name: name,
      tierId: tier.id,
      classId: cls.id,
      rentWeekly: tier.rentOverride ?? cls.weeklyRent,
      tableSeats: seats,
      reputation: tier.reputation,
      hygiene: hyg,
      buzz: b.d('BUZZ_START'),
      freshness: b.d('FRESHNESS_START'),
      awareness: b.d('TAKEOVER_START_AWARENESS'),
    );
    // Staff.
    final usedNames = <String>{};
    final badIndex =
        tier.badApple ? _rng.nextInt(0, tier.staffRoles.length - 1) : -1;
    for (var i = 0; i < tier.staffRoles.length; i++) {
      final role = tier.staffRoles[i];
      final skill =
          _rng.nextInt(tier.skillRange[0], tier.skillRange[1]).toDouble();
      final morale = tier.morale + _rng.range(-5, 5);
      loc.staff.add(_makeStaff(
          role: role,
          skill: skill,
          morale: morale,
          wageMult: tier.wageMult,
          usedNames: usedNames,
          badApple: i == badIndex));
    }
    _assignDaysOff(loc.staff);
    // Equipment.
    void addEq(String type, int count) {
      for (var i = 0; i < count; i++) {
        final c = _rng
            .nextInt(tier.equipmentCondition[0], tier.equipmentCondition[1])
            .toDouble();
        final age = _rng.nextInt(
            tier.equipmentAgeYears[0] * 336, tier.equipmentAgeYears[1] * 336);
        final e = Equipment(
            id: state.allocId(), type: type, condition: c, ageDays: age);
        e.condition = math.min(e.condition, _maxCondition(e));
        loc.equipment.add(e);
      }
    }

    final set = tier.stationSet == 'excellent' || tier.stationSet == 'best'
        ? 'base'
        : tier.stationSet;
    for (final e in theme.startingEquipment[set]!) {
      addEq(e.key, e.value);
    }
    if (tier.stationSet == 'excellent') {
      for (final e in theme.startingEquipment['excellentAdds']!) {
        addEq(e.key, e.value);
      }
    } else if (tier.stationSet == 'best') {
      final first = theme.startingEquipment['excellentAdds']!.first;
      addEq(first.key, 1);
    }
    addEq('eq_fridge', tier.extraFridge ? 2 : 1);
    addEq('eq_freezer', 1);
    addEq('eq_shelving', 1);
    addEq('eq_dish_machine', 1);
    addEq('eq_hood', 1);
    addEq('eq_pos', 1);
    if (tier.hasAc) addEq('eq_ac', 1);
    if (tier.hasGenerator) addEq('eq_generator', 1);
    if (tier.oneBroken) {
      final stations = loc.equipment
          .where((e) => content.equipment[e.type]!.kind == 'station')
          .toList();
      _rng.pick(stations).broken = true;
    }
    // Menu: every theme dish at base price.
    for (final d in content.dishesFor(theme.id)) {
      loc.menu[d.id] =
          MenuItem(dishId: d.id, price: d.basePrice, enabled: true);
    }
    for (final ing in content.ingredients.values) {
      loc.priceIndex[ing.id] = 1.0;
    }
    for (final s in content.suppliers.values) {
      loc.supplierRel[s.id] = 50;
    }
    // Starting stock.
    final use = _expectedDailyUse(loc);
    use.forEach((ingId, perDay) {
      final ing = content.ingredients[ingId]!;
      final qty = (perDay * tier.stockDays).ceil();
      if (qty <= 0) return;
      var days = _rng.nextInt(1, ing.shelfLifeDays);
      if (tier.id == 'worst' && ing.storage == 'chilled' && _rng.chance(0.3))
        days = 1;
      loc.stock.add(Batch(ingId, qty, 65, days));
    });
    // Hidden problems.
    final count = _rng.nextInt(tier.hiddenProblems[0], tier.hiddenProblems[1]);
    final kinds = List<String>.of(hiddenProblemKinds);
    _rng.shuffle(kinds);
    for (var i = 0; i < count; i++) {
      final k = kinds[i];
      final hp = HiddenProblem(k);
      switch (k) {
        case 'supplier_debt':
          hp.amount = (_rng.nextInt(8, 20) * 1000);
          hp.dueDay = _rng.nextInt(14, 28);
        case 'health_violation':
          hp.dueDay = _rng.nextInt(7, 14);
          loc.hygiene = math.max(0, loc.hygiene - 20);
        case 'chef_leaving':
          hp.dueDay = _rng.nextInt(10, 20);
          for (final s in loc.staff) {
            if (s.role == 'headChef') {
              s.loyalty = 10;
              s.morale = 30;
            }
          }
        case 'pests':
          hp.dueDay = 5;
        case 'fridge_failing':
          for (final e in loc.equipment) {
            if (e.type == 'eq_fridge') {
              e.condition = 30;
              break;
            }
          }
        case 'cashier_skimming':
          for (final s in loc.staff) {
            if (s.role == 'cashier') {
              s.honesty = 15;
              if (!s.traits.contains('trait_light_fingered'))
                s.traits.add('trait_light_fingered');
            }
          }
        case 'lease_increase':
          hp.dueDay = 84;
        case 'overdue_licence':
          hp.dueDay = 7;
        case 'staff_feud':
          final a = _rng.nextInt(0, loc.staff.length - 1);
          var c = _rng.nextInt(0, loc.staff.length - 1);
          if (c == a) c = (a + 1) % loc.staff.length;
          loc.staff[a].morale = math.max(0, loc.staff[a].morale - 20);
          loc.staff[c].morale = math.max(0, loc.staff[c].morale - 20);
        case 'fake_reviews':
          hp.dueDay = _rng.nextInt(14, 21);
      }
      loc.hidden.add(hp);
    }
    return loc;
  }

  /// Wire hidden problems into the running game at purchase (doc 05 §4).
  void _activateHiddenProblems(Location loc) {
    for (final hp in loc.hidden) {
      switch (hp.kind) {
        case 'supplier_debt':
          loc.payables.add(Payable(
              state.allocId(),
              'sup_standard',
              hp.amount,
              hp.dueDay,
              'Old bill from City Foodservice (left by the last owner)',
              true));
        case 'health_violation':
          state.scheduled.add(Scheduled('inc_inspection', hp.dueDay));
        case 'chef_leaving':
          final chef = loc.staff.where((s) => s.role == 'headChef').firstOrNull;
          if (chef != null) {
            state.scheduled.add(
                Scheduled('inc_resignation', hp.dueDay, subjectId: chef.id));
          }
        case 'pests':
          state.scheduled.add(Scheduled('@flag:pests', hp.dueDay));
        case 'lease_increase':
          state.scheduled.add(
              Scheduled('inc_landlord_rent', hp.dueDay, subjectKey: 'hidden'));
        case 'overdue_licence':
          state.scheduled.add(Scheduled('inc_licence_overdue', hp.dueDay));
        case 'staff_feud':
          state.flags['feud'] = 28;
        case 'fake_reviews':
          state.scheduled.add(Scheduled('@fake_reviews', hp.dueDay));
        default:
          break;
      }
    }
  }

  void _generateApplicants() {
    state.applicants.clear();
    final n = _rng.nextInt(3, 5);
    final centre = 20 + 10 * loc.reputation;
    final hap = _outletHappiness();
    final usedNames = {for (final s in loc.staff) s.name};
    // Bias toward roles the outlet is short of.
    final counts = {
      for (final r in roles) r: loc.staff.where((s) => s.role == r).length
    };
    for (var i = 0; i < n; i++) {
      final weights = [
        for (final r in roles)
          counts[r] == 0 ? 4.0 : (r == 'server' || r == 'lineCook' ? 2.0 : 1.0)
      ];
      final role = _rng.weighted(roles, weights);
      final skill =
          _rng.triangular(5, 95, centre.clamp(10, 90)).roundToDouble();
      final s = _makeStaff(
          role: role,
          skill: skill,
          morale: 60,
          wageMult: 1,
          usedNames: usedNames);
      s.hiredDay = state.dayIndex;
      s.askingWage = (_expectedWage(role, skill) *
              _rng.range(0.9, 1.2) *
              (1.15 - hap / 400))
          .round();
      s.wage = s.askingWage;
      state.applicants.add(s);
    }
  }
}

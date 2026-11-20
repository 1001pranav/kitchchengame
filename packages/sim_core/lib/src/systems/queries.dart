part of '../sim.dart';

/// Read-only helpers for the UI. They call the same functions the rules use.
extension SimQueries on Sim {
  ServiceState? get service => state.hasLocation ? loc.service : null;
  bool get ownerPresent => state.hasLocation && !state.owner.restingToday;

  String clock(int tick) => _clock(tick);
  String role(String r) => roleName(r);
  int expectedWage(String role, double skill) => _expectedWage(role, skill);
  double happinessTarget(Staff s) => _happinessTarget(s);
  Map<String, double> happinessFactors(Staff s) => _happinessFactors(s);
  double outletHappiness() => _outletHappiness();
  bool rosteredOn(Staff s, int weekday) => s.dayOff != weekday;
  bool equipmentWorking(Equipment e) => _isWorking(e);
  double maxCondition(Equipment e) => _maxCondition(e);
  double breakChance(Equipment e) => _breakChance(e);
  int equipmentResale(Equipment e) => _equipmentResale(e);
  int capacity(String storage) => _capacity(storage);
  int stored(String storage) => _stored(storage);
  double unitPrice(String supplierId, String ingredientId) =>
      _unitPrice(supplierId, ingredientId);
  bool supplierSells(String supplierId, String ingredientId) =>
      _supplierSells(supplierId, ingredientId);
  int orderTotal(String supplierId, Map<String, int> lines) =>
      _orderTotal(supplierId, lines);
  Map<String, int> suggestedOrder(String supplierId) =>
      _suggestedOrder(supplierId);
  Map<String, double> expectedDailyUse({int? day}) =>
      _expectedDailyUse(loc, day: day);
  int valuation() => _valuation();
  int creditLimit() => _creditLimit();
  int avgWeeklyProfit() => _avgWeeklyOpProfit();
  int weeklyInstalments() => _currentInstalments();
  double loanRate({bool secured = false, bool private = false}) =>
      _loanRate(secured: secured, private: private);
  List<MapEntry<String, bool>> bankChecks(int amount, int term, bool secured) =>
      _bankChecks(amount, term, secured);
  double campaignFit(String type) => _campaignFit(type);
  String fitWord(double fit) => _fitWord(fit);
  int? lastCampaignDay(String type) => _lastCampaignDay(type);
  double priceIndex() => _priceIndexOf(loc);
  Festival? festivalOn(int day) => _festivalOn(day);
  bool stationDown(String station) => _stationDown(station);
  int stationCapacity(String station) => _stationCapacity(station);
  int patienceLimit(Group g) => _patienceLimit(g);
  bool dishOrderable(String dishId) => _dishOrderable(dishId);
  bool hasWorking(String type) => _hasWorking(type);
  int eatTicks(int size) => _eatTicks(size);
  bool rosteredToday(Staff s) => _rosteredToday(s);

  /// Text with {staff}, {equipment} … filled in.
  String incidentText(IncidentInstance inst, String text) => _fill(text, inst);

  /// Why an option is unavailable, or null.
  String? optionBlocked(IncidentInstance inst, IncidentOption o) =>
      _optionBlocked(o, inst);

  /// Odds word for an option: likely / even odds / risky, from its first chance effect.
  String? optionOdds(IncidentOption o) {
    for (final e in o.effects) {
      final c = e['chance'];
      if (c is num)
        return c >= 0.7 ? 'likely' : (c >= 0.4 ? 'even odds' : 'risky');
    }
    return null;
  }

  /// Known cash cost of an option (negative = cost), for the cost chip.
  int optionCash(IncidentInstance inst, IncidentOption o) {
    var sum = 0;
    for (final e in o.effects) {
      if (e['chance'] != null) continue;
      if (e['type'] == 'cash' && e['amount'] != null)
        sum += _amount(e['amount'], inst);
      if (e['type'] == 'repair') {
        final eq = loc.equipmentById(inst.subjectId);
        if (eq != null) {
          sum -= (content.equipment[eq.type]!.price *
                  ((b.map('REPAIR')[e['mode']] as Map)['cost'] as num))
              .round();
        }
      }
      if (e['type'] == 'replace') {
        final eq = loc.equipmentById(inst.subjectId);
        if (eq != null)
          sum -= (content.equipment[eq.type]!.price *
                  (e['secondHand'] == true ? 0.5 : 1))
              .round();
      }
    }
    return sum;
  }

  /// Ingredient that will run out today (for the prep board): id → share of the day covered.
  Map<String, double> runOutRisks() {
    final use = _expectedDailyUse(loc);
    final out = <String, double>{};
    use.forEach((ing, perDay) {
      if (perDay < 1) return;
      final have = loc.stockOf(ing) +
          loc.orders
              .where((o) => o.dueDay <= state.dayIndex)
              .fold<int>(0, (a, o) => a + (o.lines[ing] ?? 0));
      final cover = have / perDay;
      if (cover < 1) out[ing] = cover;
    });
    return out;
  }

  /// Roles with nobody working today.
  List<String> uncoveredRoles() {
    final out = <String>[];
    bool working(List<String> rs) =>
        loc.staff.any((s) => s.workingToday && rs.contains(s.role));
    if (!working(['headChef', 'lineCook'])) out.add('cook');
    for (final r in ['server', 'cashier', 'dishwasher', 'cleaner']) {
      if (!working([r])) out.add(r);
    }
    return out;
  }

  /// Roles with no primary holder on a given weekday (rota coverage strip).
  List<String> uncoveredOn(int weekday) {
    final out = <String>[];
    bool on(List<String> rs) =>
        loc.staff.any((s) => rs.contains(s.role) && s.dayOff != weekday);
    if (!on(['headChef', 'lineCook'])) out.add('cook');
    for (final r in ['server', 'cashier', 'dishwasher', 'cleaner']) {
      if (loc.staff.any((s) => s.role == r) && !on([r])) out.add(r);
    }
    return out;
  }

  bool get canAutoRun => uncoveredRoles().isEmpty;

  /// The day's top causes, worst first (close report page 2).
  List<DayEvent> topCauses(DayStats t, {int max = 5}) {
    final out = <DayEvent>[];
    if (t.walkTable > 0) {
      out.add(DayEvent(
          'walkTable',
          '${t.walkTable} parties gave up waiting for a table or to be seated',
          t.walkTable * 60));
    }
    if (t.walkOrder > 0)
      out.add(DayEvent(
          'walkOrder',
          '${t.walkOrder} parties left before anyone took their order',
          t.walkOrder * 60));
    if (t.walkFood > 0)
      out.add(DayEvent('walkFood',
          '${t.walkFood} parties left waiting for food', t.walkFood * 70));
    if (t.walkBill > 0)
      out.add(DayEvent(
          'walkBill',
          '${t.walkBill} parties got tired of waiting for the bill',
          t.walkBill * 20));
    final seen = <String>{};
    for (final e in t.events) {
      if (e.value <= 0) continue;
      if (e.kind == 'incident' || e.kind == 'incidentResult') continue;
      if (e.kind == 'soldOut' && !seen.add('soldOut')) continue;
      out.add(e);
    }
    out.sort((a, c) => c.value.compareTo(a.value));
    return out.take(max).toList();
  }

  /// Short sentence for the close report.
  String dayInOneLine(DayStats t) {
    if (t.closed) return 'The doors stayed shut today.';
    final busy = t.forecast == 0
        ? 'A'
        : (t.groupsArrived > t.forecast * 1.15
            ? 'A busier than expected'
            : (t.groupsArrived < t.forecast * 0.85 ? 'A quiet' : 'A normal'));
    final day = const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ][t.dayIndex % 7];
    final lost = t.walkouts;
    if (lost == 0) return '$busy $day. Nobody walked out.';
    final worst = [
      MapEntry('waiting for a table', t.walkTable),
      MapEntry('waiting to order', t.walkOrder),
      MapEntry('waiting for food', t.walkFood),
      MapEntry('waiting for the bill', t.walkBill),
    ]..sort((a, c) => c.value.compareTo(a.value));
    return '$busy $day. Lost $lost ${lost == 1 ? 'party' : 'parties'}, most ${worst.first.key}.';
  }

  /// Health card gauges (doc 11 §A.7): name → (effect multiplier, suggestion).
  List<(String, double, String, String)> healthGauges() {
    final l = loc;
    final avgAge = l.equipment.isEmpty
        ? 0
        : l.equipment.fold<int>(0, (a, e) => a + e.ageDays) /
            l.equipment.length;
    final creep = math
        .pow(b.d('YEARLY_COST_CREEP_WAGE'), state.dayIndex ~/ 336)
        .toDouble();
    return [
      (
        'Buzz',
        0.90 + 0.20 * l.buzz,
        '${(l.buzz * 100).round()}%',
        'Advertise, or rework the menu'
      ),
      (
        'Menu freshness',
        0.94 + 0.10 * l.freshness,
        '${(l.freshness * 100).round()}%',
        'Rework the menu or bring back a dish'
      ),
      (
        'Equipment age',
        1.0,
        '${(avgAge / 336).toStringAsFixed(1)} yrs',
        'Replace the oldest machines'
      ),
      (
        'Cost pressure',
        1 / creep,
        '×${creep.toStringAsFixed(2)}',
        'Raise prices about 3% a year'
      ),
      (
        'Rivals',
        1 - 0.30 * l.competition,
        '${(l.competition * 100).round()}%',
        'Stay fresh; rivals arrive when you do well'
      ),
    ];
  }
}

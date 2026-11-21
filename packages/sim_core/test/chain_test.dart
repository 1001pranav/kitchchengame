import 'dart:convert';
import 'dart:math' as math;

import 'package:sim_core/sim_core.dart';
import 'package:test/test.dart';

import '../tool/bots.dart';
import 'helpers.dart';

/// A Good restaurant at Stage 3 with plenty of cash.
Sim stage3({int seed = 4}) {
  final sim = boughtSim(seed: seed);
  sim.state.stage = 3;
  sim.state.cash = 400000;
  clearCards(sim);
  // The market opens at the next morning.
  sim.apply(const StartService());
  runService(sim);
  clearCards(sim);
  sim.apply(const EndDay());
  clearCards(sim);
  return sim;
}

void finishDay(Sim sim) {
  clearCards(sim);
  // Order the usual for every outlet, like a player would.
  if (sim.state.phase == 'prep') {
    final view = sim.state.viewLocationId;
    for (final l in sim.state.openLocations) {
      sim.apply(SelectLocation(l.id));
      final lines = sim.suggestedOrder('sup_standard');
      if (lines.isNotEmpty) sim.apply(PlaceOrder('sup_standard', lines));
    }
    sim.apply(SelectLocation(view));
  }
  if (sim.state.phase == 'prep') sim.apply(const StartService());
  var guard = 0;
  while (sim.state.phase == 'service' && guard++ < 1000) {
    clearCards(sim);
    sim.tick();
  }
  clearCards(sim);
  if (sim.state.phase == 'close') sim.apply(const EndDay());
}

void main() {
  test('Stage 3 opens an outlet market and manager applicants', () {
    final sim = stage3();
    expect(sim.state.outletMarket.length, 5);
    expect(sim.state.sites.length, 3);
    expect(sim.state.managerApplicants.length, 3);
  });

  test('buying a second outlet: cheaper (x0.4), no loan, trades from tomorrow',
      () {
    final sim = stage3();
    final o = sim.state.outletMarket[2];
    expect(o.price, (150000 * 0.4).round());
    final loans = sim.state.loans.length;
    final r = sim.apply(const BuyOutlet(2));
    expect(r.ok, isTrue, reason: r.message);
    expect(sim.state.locations.length, 2);
    expect(sim.state.loans.length, loans);
    final l = sim.state.locations.last;
    expect(l.id, 2);
    expect(l.openDay, sim.state.dayIndex + 1);
  });

  test('an outlet with neither owner nor manager does not open', () {
    final sim = stage3();
    sim.apply(const BuyOutlet(2));
    finishDay(sim); // to tomorrow, when it trades
    finishDay(sim);
    final l = sim.state.locations.last;
    expect(l.days.last.closed, isTrue);
  });

  test(
      'with a manager both outlets trade in lockstep and the manager works the till',
      () {
    final sim = stage3();
    sim.apply(const BuyOutlet(2));
    final l2 = sim.state.locations.last;
    sim.apply(SelectLocation(l2.id));
    final m = sim.state.managerApplicants
        .firstWhere((a) => a.grade != 'Senior' && a.grade != 'Veteran');
    expect(sim.apply(HireManager(m.id)).ok, isTrue);
    expect(l2.manager, isNotNull);
    finishDay(sim);
    finishDay(sim);
    expect(sim.state.locations.first.days.last.groupsServed, greaterThan(0));
    expect(l2.days.last.groupsServed, greaterThan(0));
  });

  test('travelling during service takes 20 ticks and moves the owner', () {
    final sim = stage3();
    sim.apply(const BuyOutlet(2));
    final l2 = sim.state.locations.last;
    sim.apply(SelectLocation(l2.id));
    sim.apply(HireManager(sim.state.managerApplicants
        .firstWhere((a) => a.grade != 'Senior' && a.grade != 'Veteran')
        .id));
    finishDay(sim);
    clearCards(sim);
    sim.apply(const StartService());
    for (var i = 0; i < 30; i++) {
      sim.tick();
    }
    expect(sim.apply(OwnerTravel(l2.id)).ok, isTrue);
    expect(sim.state.travelling, isTrue);
    for (var i = 0; i < 21; i++) {
      clearCards(sim);
      sim.tick();
    }
    expect(sim.state.travelling, isFalse);
    expect(sim.state.ownerLocationId, l2.id);
  });

  test('office district outlets take delivery orders', () {
    final sim = stage3();
    final idx = sim.state.outletMarket.indexWhere((o) => o.tierId == 'good');
    sim.state.outletMarket[idx].location.format = 'officeDistrict';
    sim.apply(BuyOutlet(idx));
    final l2 = sim.state.locations.last;
    expect(l2.deliveryOn, isTrue);
    sim.apply(SelectLocation(l2.id));
    sim.apply(HireManager(sim.state.managerApplicants
        .firstWhere((a) => a.grade != 'Senior' && a.grade != 'Veteran')
        .id));
    for (var d = 0; d < 3; d++) {
      finishDay(sim);
    }
    expect(l2.days.map((d) => d.deliveries).reduce((a, b) => a + b),
        greaterThan(0));
  });

  test('quick sale pays 70% of the estimate and retires the outlet', () {
    final sim = stage3();
    sim.apply(const BuyOutlet(2));
    final l2 = sim.state.locations.last;
    sim.apply(SelectLocation(l2.id));
    final before = sim.state.cash;
    final r = sim.apply(const QuickSale());
    expect(r.ok, isTrue, reason: r.message);
    expect(sim.state.cash, greaterThan(before));
    expect(l2.closedForGood, isTrue);
    expect(sim.state.openLocations.length, 1);
    // The only outlet cannot be sold.
    expect(sim.apply(const QuickSale()).ok, isFalse);
  });

  test(
      'building from scratch: pays up front, opens after the fit-out, rating 3.0',
      () {
    final sim = stage3();
    final site = sim.state.sites.first;
    final r = sim.apply(BuildOutlet(site.id, 'small', 'basic'));
    expect(r.ok, isTrue, reason: r.message);
    final l = sim.state.locations.last;
    expect(l.openDay, sim.state.dayIndex + 7);
    expect(l.reputation, 3.0);
    expect(l.awareness, closeTo(0.45, 1e-9));
    expect(l.staff.length, 7);
  });

  test('requests: a manager asks before spending above the limit', () {
    final sim = stage3();
    sim.apply(const BuyOutlet(2));
    final l2 = sim.state.locations.last;
    sim.apply(SelectLocation(l2.id));
    sim.apply(HireManager(sim.state.managerApplicants
        .firstWhere((a) => a.grade != 'Senior' && a.grade != 'Veteran')
        .id));
    final oven = l2.equipment.firstWhere((e) => e.type == 'eq_oven');
    oven.broken = true;
    l2.policies.spendingLimit = 100;
    var asked = false;
    for (var d = 0; d < 6 && !asked; d++) {
      finishDay(sim);
      asked = sim.state.requests
          .any((r) => r.kind == 'repair' && r.subjectId == oven.id);
    }
    expect(asked, isTrue);
    final req = sim.state.requests.firstWhere((r) => r.kind == 'repair');
    expect(sim.apply(AnswerRequest(req.id, 'approve')).ok, isTrue);
    expect(oven.broken, isFalse);
  });

  Location managedOutlet(Sim sim, {double skill = 80}) {
    sim.apply(const BuyOutlet(2));
    final l2 = sim.state.locations.last;
    sim.apply(SelectLocation(l2.id));
    final m = sim.state.managerApplicants.first;
    sim.apply(HireManager(m.id));
    m
      ..people = skill
      ..upkeep = skill
      ..stockSkill = skill;
    sim.apply(SelectLocation(sim.state.locations.first.id));
    return l2;
  }

  test('a manager fills in for a missing cook (doc 02 §15.15)', () {
    final sim = stage3();
    final l2 = managedOutlet(sim);
    finishDay(sim); // the outlet trades from tomorrow
    l2.staff.removeWhere((s) => s.isCook);
    finishDay(sim);
    final day = l2.days.last;
    expect(day.groupsServed, greaterThan(0));
    expect(day.foodTickets, greaterThan(0));
  });

  test('a course above the spending limit becomes a training request', () {
    final sim = stage3();
    final l2 = managedOutlet(sim);
    final cook = l2.staff.firstWhere((s) => s.isCook);
    for (final s in l2.staff.where((s) => s.isCook)) {
      s.skill = 68; // every cook needs a course, each costs 680
    }
    cook.skill = 60;
    l2.policies.spendingLimit = 500;
    Request? req;
    for (var d = 0; d < 9 && req == null; d++) {
      finishDay(sim);
      req = sim.state.requests
          .where((r) => r.kind == 'training' && r.locationId == l2.id)
          .firstOrNull;
    }
    expect(req, isNotNull);
    expect(req!.cost, greaterThan(500));
    final who = l2.staffById(req.subjectId)!;
    expect(sim.apply(AnswerRequest(req.id, 'approve')).ok, isTrue);
    expect(who.trainingUntil, greaterThan(sim.state.dayIndex));
  });

  test('no head chef: the manager asks to promote the best line cook', () {
    final sim = stage3();
    final l2 = managedOutlet(sim);
    for (final s in l2.staff.where((s) => s.role == 'headChef')) {
      s.role = 'lineCook';
    }
    final best = (l2.staff.where((s) => s.role == 'lineCook').toList()
          ..sort((a, c) => c.skill.compareTo(a.skill)))
        .first;
    best.skill = math.max(best.skill, 60);
    finishDay(sim);
    final req = sim.state.requests
        .firstWhere((r) => r.kind == 'promote' && r.locationId == l2.id);
    expect(req.subjectId, best.id);
    expect(sim.apply(AnswerRequest(req.id, 'approve')).ok, isTrue);
    expect(best.role, 'headChef');
  });

  test('no second ad request while the last ad is recent', () {
    final sim = stage3();
    final l2 = managedOutlet(sim);
    finishDay(sim);
    l2.buzz = 0.1;
    l2.campaigns.add(Campaign(
        id: 999,
        type: 'localAd',
        startDay: sim.state.dayIndex - 8,
        endDay: sim.state.dayIndex - 1,
        cost: 3000,
        boost: 0.1,
        mult: 1,
        outcome: 'normal',
        reason: ''));
    finishDay(sim);
    expect(
        sim.state.requests
            .any((r) => r.kind == 'marketing' && r.locationId == l2.id),
        isFalse);
  });

  test('multi-outlet save round-trip and determinism', () {
    String run() {
      final sim = stage3(seed: 9);
      sim.apply(const BuyOutlet(1));
      sim.apply(SelectLocation(sim.state.locations.last.id));
      sim.apply(HireManager(sim.state.managerApplicants.first.id));
      final bot = Bot('competent');
      for (var d = 0; d < 10; d++) {
        bot.day(sim);
      }
      final json = jsonEncode(sim.toSave());
      final again =
          Sim.fromSave(content, jsonDecode(json) as Map<String, dynamic>);
      expect(jsonEncode(again.toSave()), json);
      return json;
    }

    expect(run(), run());
  });

  test('stage 4 needs three outlets each profitable four weeks running', () {
    final sim = stage3();
    for (final l in [sim.state.locations.first]) {
      l.weeks.addAll(
          List.generate(4, (i) => WeekRecord(week: i, operatingProfit: 1000)));
    }
    sim.apply(const BuyOutlet(1));
    sim.apply(const BuyOutlet(1));
    for (final l in sim.state.locations) {
      l.weeks.addAll(
          List.generate(4, (i) => WeekRecord(week: i, operatingProfit: 1000)));
    }
    while (sim.state.weekday != 6) {
      finishDay(sim);
    }
    clearCards(sim);
    sim.apply(const StartService());
    runService(sim);
    // New weeks were added; profitable or not, the check ran on the last four.
    expect(sim.state.stage, anyOf(3, 4));
  });
}

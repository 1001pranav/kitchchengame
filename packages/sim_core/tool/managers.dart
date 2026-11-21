// Manager grades, owner never visits outlet 2 (doc 06 §4 manager targets).
// Usage: dart run tool/managers.dart [seeds] [weeks]
import 'dart:math' as math;

import 'package:sim_core/sim_core.dart';

import 'bots.dart';
import 'load.dart';

void main(List<String> args) {
  final content = loadContent();
  final seeds = args.isNotEmpty ? int.parse(args[0]) : 8;
  final weeks = args.length > 1 ? int.parse(args[1]) : 12;
  final meansArg = args.where((a) => a.startsWith('--means=')).firstOrNull;
  final means = meansArg == null
      ? [27.0, 42.0, 57.0, 72.0, 86.0]
      : meansArg.substring(8).split(',').map(double.parse).toList();
  for (final mean in means) {
    var total = 0, n = 0, lossWeeks = 0, weekCount = 0;
    var firstBad = 0, firstBadN = 0;
    final sums = <String, int>{};
    for (var seed = 1; seed <= seeds; seed++) {
      final sim =
          Sim.newGame(content: content, seed: seed, difficulty: 'normal');
      sim.apply(const BuyRestaurant(2));
      sim.state.stage = 3;
      sim.state.cash = 300000;
      final bot = Bot('competent');
      bot.day(sim); // market opens next morning
      final idx = sim.state.outletMarket.indexWhere((o) => o.tierId == 'good');
      // Doc 06 §4: a Good-tier outlet in an average location (neighbourhood).
      final offer = sim.state.outletMarket[idx].location;
      if (args.contains('-v')) {
        print(
            '  seed $seed: ${offer.classId} ${offer.format} rent ${offer.rentWeekly}');
      }
      if (!args.contains('--any-site')) {
        final fa = args.where((a) => a.startsWith('--format=')).firstOrNull;
        offer
          ..format = fa == null ? 'neighbourhood' : fa.substring(9)
          ..classId = 'average'
          ..rentWeekly = sim.content.locationClasses['average']!.weeklyRent;
        offer.rentWeekly =
            (offer.rentWeekly * (sim.formatInfo(offer)['rentMult'] ?? 1))
                .round();
      }
      sim.apply(BuyOutlet(idx));
      final l2 = sim.state.locations.last;
      sim.apply(SelectLocation(l2.id));
      // A manager of the chosen grade (fixed skill, all-rounder).
      final m = sim.state.managerApplicants.first;
      m.people = mean;
      m.upkeep = mean;
      m.stockSkill = mean;
      m.potential = mean;
      m.wage = sim.expectedWage('manager', mean);
      sim.state.perks; // keep analyzer quiet
      final r = sim.apply(HireManager(m.id));
      if (!r.ok) {
        sim.state.managerApplicants.remove(m);
        l2.staff.add(m
          ..role = 'manager'
          ..dayOff = 7);
      }
      if (args.contains('--delivery')) sim.apply(const SetDelivery(true));
      // The manager works the till: let the cashier go (doc 02 §15.15).
      for (final c in l2.staff.where((s) => s.role == 'cashier').toList()) {
        sim.apply(Fire(c.id));
      }
      sim.apply(SelectLocation(sim.state.locations.first.id));
      while (
          sim.state.dayIndex < weeks * 7 + 1 && sim.state.phase != 'gameOver') {
        if (args.contains('--market') && sim.state.phase == 'prep') {
          sim.apply(SelectLocation(l2.id));
          if (sim.state.dayIndex % 28 == 2) {
            sim.apply(const StartCampaign('localAd'));
          }
          if (sim.state.dayIndex % 56 == 9) sim.apply(const ReworkMenu());
          sim.apply(SelectLocation(sim.state.locations.first.id));
        }
        bot.day(sim);
        sim.apply(SelectLocation(sim.state.locations.first.id));
      }
      if (args.contains('-w')) {
        final ds = l2.days.skip(math.max(0, l2.days.length - 28));
        int sum(int Function(DayStats) f) => ds.fold(0, (a, d) => a + f(d));
        print(
            '  seed $seed last 28d: arrived ${sum((d) => d.groupsArrived)} served ${sum((d) => d.groupsServed)} T${sum((d) => d.walkTable)} O${sum((d) => d.walkOrder)} F${sum((d) => d.walkFood)} B${sum((d) => d.walkBill)} deliv ${sum((d) => d.deliveries)} cancel ${sum((d) => d.deliveriesCancelled)} lost ${sum((d) => d.lost)}');
      }
      // First 4-week block (weeks 1-4, 2-5, ...) with negative total profit.
      for (var s0 = 0; s0 + 4 <= l2.weeks.length; s0++) {
        if (l2.weeks.skip(s0).take(4).fold(0, (a, w) => a + w.operatingProfit) <
            0) {
          firstBad += s0 + 4;
          firstBadN++;
          break;
        }
      }
      for (final w in l2.weeks.skip(args.contains("--from5") ? 4 : 1)) {
        total += w.operatingProfit;
        for (final e in {
          'rev': w.revenue,
          'ingr': w.ingredientSpend,
          'wages': w.wages,
          'upk': w.upkeep,
          'mkt': w.marketing,
          'oth': w.other,
          'groups': w.groupsServed,
          'walk': w.walkouts,
          'waste': w.wasteCost,
        }.entries) {
          sums[e.key] = (sums[e.key] ?? 0) + e.value;
        }
        n++;
        if (w.operatingProfit < 0) {
          lossWeeks++;
          if (args.contains('-v')) {
            print(
                '  seed $seed wk ${w.week}: op ${w.operatingProfit} rev ${w.revenue} ingr ${w.ingredientSpend} wages ${w.wages} upk ${w.upkeep} mkt ${w.marketing} oth ${w.other} groups ${w.groupsServed} walk ${w.walkouts}');
          }
        }
        weekCount++;
      }
    }
    print(
        '  per week: ${sums.map((k, v) => MapEntry(k, n == 0 ? 0 : v ~/ n))}');
    print(
        'manager skill ${mean.round()}: outlet 2 avg weekly op profit ${n == 0 ? 0 : total ~/ n}, losing weeks ${(100 * lossWeeks / (weekCount == 0 ? 1 : weekCount)).round()}%, a losing 4-week block in $firstBadN/$seeds runs (ends week ${firstBadN == 0 ? '-' : (firstBad / firstBadN).toStringAsFixed(1)})');
  }
}

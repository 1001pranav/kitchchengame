// Manager grades, owner never visits outlet 2 (doc 06 §4 manager targets).
// Usage: dart run tool/managers.dart [seeds] [weeks]
import 'package:sim_core/sim_core.dart';

import 'bots.dart';
import 'load.dart';

void main(List<String> args) {
  final content = loadContent();
  final seeds = args.isNotEmpty ? int.parse(args[0]) : 8;
  final weeks = args.length > 1 ? int.parse(args[1]) : 12;
  for (final mean in [27.0, 42.0, 57.0, 72.0, 86.0]) {
    var total = 0, n = 0, lossWeeks = 0, weekCount = 0;
    for (var seed = 1; seed <= seeds; seed++) {
      final sim =
          Sim.newGame(content: content, seed: seed, difficulty: 'normal');
      sim.apply(const BuyRestaurant(2));
      sim.state.stage = 3;
      sim.state.cash = 300000;
      final bot = Bot('competent');
      bot.day(sim); // market opens next morning
      final idx = sim.state.outletMarket.indexWhere((o) => o.tierId == 'good');
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
      for (final w in l2.weeks.skip(args.contains("--from5") ? 4 : 1)) {
        total += w.operatingProfit;
        n++;
        if (w.operatingProfit < 0) lossWeeks++;
        weekCount++;
      }
    }
    print(
        'manager skill ${mean.round()}: outlet 2 avg weekly op profit ${n == 0 ? 0 : total ~/ n}, losing weeks ${(100 * lossWeeks / (weekCount == 0 ? 1 : weekCount)).round()}%');
  }
}

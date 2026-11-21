import 'package:sim_core/sim_core.dart';

import 'bots.dart';
import 'load.dart';

void main(List<String> args) {
  final content = loadContent();
  final mean = double.parse(args[0]);
  final sim = Sim.newGame(content: content, seed: 3, difficulty: 'normal');
  sim.apply(const BuyRestaurant(2));
  sim.state.stage = 3;
  sim.state.cash = 300000;
  final bot = Bot('competent');
  bot.day(sim);
  final idx = sim.state.outletMarket.indexWhere((o) => o.tierId == 'good');
  sim.apply(BuyOutlet(idx));
  final l2 = sim.state.locations.last;
  sim.apply(SelectLocation(l2.id));
  final m = sim.state.managerApplicants.first;
  m.people = mean;
  m.upkeep = mean;
  m.stockSkill = mean;
  m.potential = mean;
  m.wage = sim.expectedWage('manager', mean);
  if (!sim.apply(HireManager(m.id)).ok) {
    sim.state.managerApplicants.remove(m);
    l2.staff.add(m
      ..role = 'manager'
      ..dayOff = 7);
  }
  for (final c in l2.staff.where((s) => s.role == 'cashier').toList()) {
    sim.apply(Fire(c.id));
  }
  sim.apply(SelectLocation(sim.state.locations.first.id));
  while (sim.state.dayIndex < 6 * 7 + 1) {
    bot.day(sim);
    sim.apply(SelectLocation(sim.state.locations.first.id));
  }
  print(
      'wk   rev   ingr  wages  rent  util upk  mkt  oth  op groups walk stars');
  for (final w in l2.weeks) {
    print(
        '${w.week} ${w.revenue} ${w.ingredientSpend} ${w.wages} ${w.rent} ${w.utilities} ${w.upkeep} ${w.marketing} ${w.other} ${w.operatingProfit} ${w.groupsServed} ${w.walkouts} ${w.avgStars.toStringAsFixed(2)}');
  }
  for (final d in l2.days.skip(l2.days.length - 10)) {
    final q = d.foodTickets == 0 ? 0 : d.foodQualitySum / d.foodTickets;
    print(
        'd${d.dayIndex} q ${q.round()} stars ${d.avgStars.toStringAsFixed(1)} ing ${d.ingredientSpend} arr ${d.groupsArrived} served ${d.groupsServed} walk T${d.walkTable} O${d.walkOrder} F${d.walkFood} unav ${d.unavailable} ${d.events.take(6).map((e) => e.text).toList()}');
  }
  print('requests ${sim.state.requests.map((r) => r.text).toList()}');
  print(
      'staff ${l2.staff.map((s) => '${s.role}:${s.skill.round()}').toList()} rep ${l2.reputation.toStringAsFixed(2)}');
}

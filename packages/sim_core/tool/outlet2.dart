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
  final wks = args.length > 1 ? int.parse(args[1]) : 6;
  final rep = <int, List<String>>{};
  while (sim.state.dayIndex < wks * 7 + 1) {
    if (args.contains('--market') && sim.state.phase == 'prep') {
      sim.apply(SelectLocation(l2.id));
      if (sim.state.dayIndex % 28 == 2) {
        sim.apply(const StartCampaign('localAd'));
      }
      if (sim.state.dayIndex % 56 == 9) sim.apply(const ReworkMenu());
      sim.apply(SelectLocation(sim.state.locations.first.id));
    }
    bot.day(sim);
    if (sim.state.dayIndex % 7 == 0) {
      rep[sim.state.dayIndex ~/ 7] = [
        for (final l in sim.state.locations)
          'rep ${l.reputation.toStringAsFixed(2)} aw ${l.awareness.toStringAsFixed(2)} buzz ${l.buzz.toStringAsFixed(2)} hyg ${l.hygiene.round()} fresh ${l.freshness.toStringAsFixed(2)}'
      ];
    }
    sim.apply(SelectLocation(sim.state.locations.first.id));
  }
  print(
      'wk   rev   ingr  wages  rent  util upk  mkt  oth  op groups walk stars');
  print('--- owner-run outlet 1');
  for (final w in sim.state.locations.first.weeks) {
    print(
        '${w.week} ${w.revenue} ${w.ingredientSpend} ${w.wages} ${w.rent} ${w.utilities} ${w.upkeep} ${w.marketing} ${w.other} ${w.operatingProfit} ${w.groupsServed} ${w.walkouts} ${w.avgStars.toStringAsFixed(2)}');
  }
  print('--- manager-run outlet 2');
  for (final w in l2.weeks) {
    print(
        '${w.week} ${w.revenue} ${w.ingredientSpend} ${w.wages} ${w.rent} ${w.utilities} ${w.upkeep} ${w.marketing} ${w.other} ${w.operatingProfit} ${w.groupsServed} ${w.walkouts} ${w.avgStars.toStringAsFixed(2)}');
  }
  for (final d in l2.days.skip(l2.days.length - 10)) {
    final q = d.foodTickets == 0 ? 0 : d.foodQualitySum / d.foodTickets;
    print(
        'd${d.dayIndex} q ${q.round()} stars ${d.avgStars.toStringAsFixed(1)} ing ${d.ingredientSpend} arr ${d.groupsArrived} served ${d.groupsServed} walk T${d.walkTable} O${d.walkOrder} F${d.walkFood} unav ${d.unavailable} ${d.events.take(6).map((e) => e.text).toList()}');
  }
  for (final l in sim.state.locations) {
    print('--- daily averages per week, outlet ${l.id}');
    for (var w = 0; w * 7 < l.days.length; w++) {
      final ds = l.days.skip(w * 7).take(7).toList();
      double avg(num Function(DayStats) f) =>
          ds.fold<double>(0, (a, d) => a + f(d)) / ds.length;
      final q = ds.fold<double>(0, (a, d) => a + d.foodQualitySum) /
          ds.fold<int>(1, (a, d) => a + d.foodTickets);
      print(
          'w$w arr ${avg((d) => d.groupsArrived).round()} fc ${avg((d) => d.forecast).round()} served ${avg((d) => d.groupsServed).round()} walk T${avg((d) => d.walkTable).round()} O${avg((d) => d.walkOrder).round()} F${avg((d) => d.walkFood).round()} B${avg((d) => d.walkBill).round()} q ${q.round()} waste ${avg((d) => d.wasteCost).round()} unav ${avg((d) => d.unavailable).round()}  ${rep[w + 1]?[l.id == 1 ? 0 : 1] ?? ''}');
    }
  }
  for (final l in sim.state.locations) {
    sim.apply(SelectLocation(l.id));
    final f = sim.forecast();
    print(
        'factors ${l.id}: ${f.factors.map((k, v) => MapEntry(k, v.toStringAsFixed(3)))}');
    print(
        '  staff ${l.staff.map((s) => '${s.role}:${s.skill.round()}/f${s.fatigue.round()}/m${s.morale.round()}').join(' ')}');
    print(
        '  equip ${l.equipment.map((e) => '${e.type.replaceFirst('eq_', '')}:${e.condition.round()}').join(' ')}');
    print(
        '  par ${l.parLevels.values.map((p) => p.supplierId).toSet()} tables ${l.tableSeats.length}');
    print(
        '  menu ${l.menu.values.where((m) => m.enabled).map((m) => '${m.dishId}:${m.price}').join(' ')}');
  }
  print('requests ${sim.state.requests.map((r) => r.text).toList()}');
  print(
      'staff ${l2.staff.map((s) => '${s.role}:${s.skill.round()}').toList()} rep ${l2.reputation.toStringAsFixed(2)}');
}

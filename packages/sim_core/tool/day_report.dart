import 'package:sim_core/sim_core.dart';

import 'bots.dart';
import 'load.dart';

void main(List<String> args) {
  final content = loadContent();
  final sim = Sim.newGame(
      content: content,
      seed: int.parse(args.isEmpty ? '1' : args[0]),
      difficulty: 'normal');
  sim.apply(BuyRestaurant(content.tiers
      .indexWhere((t) => t.id == (args.length > 1 ? args[1] : 'good'))));
  final bot = Bot(args.length > 2 ? args[2] : 'competent');
  for (var d = 0; d < (args.length > 3 ? int.parse(args[3]) : 10); d++) {
    bot.day(sim);
    final t = sim.state.loc.days.last;
    final q = t.foodTickets == 0 ? 0 : t.foodQualitySum / t.foodTickets;
    print(
        'd${t.dayIndex} arr ${t.groupsArrived} fc ${t.forecast} seat ${t.groupsSeated} served ${t.groupsServed} '
        'walk T${t.walkTable} O${t.walkOrder} F${t.walkFood} B${t.walkBill} stars ${t.avgStars.toStringAsFixed(2)} q ${q.toStringAsFixed(0)} '
        'unav ${t.unavailable} rev ${t.revenue} profit ${t.profit} waste ${t.wasteCost} rep ${sim.state.loc.reputation.toStringAsFixed(2)} hyg ${sim.state.loc.hygiene.round()} '
        'staff ${sim.state.loc.staff.where((s) => s.workingToday).length}/${sim.state.loc.staff.length} cash ${sim.state.cash}');
    print(
        '     working: ${sim.state.loc.days.last.dayIndex == t.dayIndex ? '' : ''}${_roles(sim)} ing ${t.ingredientSpend} used ${t.ingredientsUsedCost} wages ${t.wages} rent ${t.rent} util ${t.utilities} upkeep ${t.upkeep} other ${t.other} mkt ${t.marketing}');
    for (final e in t.events.where((e) => e.kind != 'incidentResult')) {
      if (args.contains('-e')) print('     ${e.kind}: ${e.text}');
    }
  }
}

String _roles(Sim sim) => '';

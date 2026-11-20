import 'package:sim_core/sim_core.dart';

import 'bots.dart';
import 'load.dart';

void main(List<String> args) {
  final content = loadContent();
  final sim = Sim.newGame(
      content: content, seed: int.parse(args[0]), difficulty: 'normal');
  sim.apply(BuyRestaurant(2));
  final bot = Bot('competent');
  final target = int.parse(args[1]);
  while (sim.state.dayIndex < target) {
    bot.day(sim);
  }
  bot.prep(sim);
  for (final s in sim.state.loc.staff) {
    print(
        '${s.name} ${s.role} working=${s.workingToday} absent=${s.absentToday} dayOff=${s.dayOff} late=${s.lateTick} train=${s.trainingUntil} absUntil=${s.absentUntil} skill=${s.skill} fat=${s.fatigue.round()} mor=${s.morale.round()}');
  }
  sim.apply(const StartService());
  for (var i = 0; i < 400 && sim.state.phase == 'service'; i++) {
    sim.tick();
    final s = sim.service!;
    if (i % 30 == 0) {
      final waitCook =
          s.tasks.where((k) => k.type == 'cook' && !k.started).length;
      final cooking =
          s.tasks.where((k) => k.type == 'cook' && k.started).length;
      print(
          't$i groups ${s.groups.where((g) => !g.gone).length} waitFood ${s.groups.where((g) => g.state == 'waitFood').length} cookQ $waitCook cooking $cooking dirty ${s.dirtyDishes.round()} lost ${s.lost} owner ${s.ownerArea}');
    }
  }
}

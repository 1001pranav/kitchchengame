import 'package:sim_core/sim_core.dart';

import 'bots.dart';
import 'load.dart';

void main(List<String> args) {
  final content = loadContent();
  final sim = Sim.newGame(
      content: content, seed: int.parse(args[0]), difficulty: 'normal');
  sim.apply(BuyRestaurant(content.tiers.indexWhere((t) => t.id == args[1])));
  final bot = Bot(args[2]);
  while (sim.state.dayIndex < int.parse(args[3]) * 7 &&
      sim.state.phase != 'gameOver') {
    bot.day(sim);
  }
  print(
      'wk   rev   ingr  wages  rent  util upk  mkt  oth  opProfit int  groups walk stars rep');
  for (final w in sim.state.weeks) {
    print(
        '${w.week.toString().padLeft(2)} ${w.revenue.toString().padLeft(6)} ${w.ingredientSpend.toString().padLeft(5)} ${w.wages.toString().padLeft(5)} ${w.rent.toString().padLeft(5)} ${w.utilities.toString().padLeft(4)} ${w.upkeep.toString().padLeft(4)} ${w.marketing.toString().padLeft(4)} ${w.other.toString().padLeft(4)} ${w.operatingProfit.toString().padLeft(6)} ${w.interest.toString().padLeft(4)} ${w.groupsServed.toString().padLeft(4)} ${w.walkouts.toString().padLeft(4)} ${w.avgStars.toStringAsFixed(2)}');
  }
  print(
      'rep ${sim.state.loc.reputation.toStringAsFixed(2)} stage ${sim.state.stage} cash ${sim.state.cash} ${sim.state.gameOverReason ?? ''}');
}

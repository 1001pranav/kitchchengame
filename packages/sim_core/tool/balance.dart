// Balance bot runner (doc 06 §6). Usage:
//   dart run tool/balance.dart [tier] [policy] [seeds] [weeks]
import 'package:sim_core/sim_core.dart';

import 'bots.dart';
import 'load.dart';

void main(List<String> args) {
  final tier = args.isNotEmpty ? args[0] : 'good';
  final policy = args.length > 1 ? args[1] : 'competent';
  final seeds = args.length > 2 ? int.parse(args[2]) : 20;
  final weeks = args.length > 3 ? int.parse(args[3]) : 26;
  final theme =
      args.length > 4 && !args[4].startsWith('-') ? args[4] : 'italian';
  final content = loadContent();
  var survived = 0;
  final stage2 = <int>[];
  var walk = 0, groups = 0, incidents = 0;
  final profits = <int>[];
  final sw = Stopwatch()..start();
  for (var seed = 1; seed <= seeds; seed++) {
    final sim = Sim.newGame(
        content: content, seed: seed, difficulty: 'normal', themeId: theme);
    final idx = content.tiers.indexWhere((t) => t.id == tier);
    sim.apply(BuyRestaurant(idx));
    final bot = Bot(policy)..absentOwner = args.contains('--absent');
    int? s2;
    while (sim.state.dayIndex < weeks * 7 && sim.state.phase != 'gameOver') {
      bot.day(sim);
      final t = sim.state.loc.days.isNotEmpty
          ? sim.state.loc.days.last
          : sim.state.loc.today;
      walk += t.walkouts;
      groups += t.groupsArrived;
      incidents += t.events.where((e) => e.kind == 'incident').length;
      if (s2 == null && sim.state.stage >= 2) s2 = sim.state.weekIndex;
    }
    if (sim.state.phase != 'gameOver') survived++;
    if (s2 != null) stage2.add(s2);
    final w = sim.state.weeks;
    final avg = w.isEmpty
        ? 0
        : w.map((x) => x.operatingProfit).reduce((a, c) => a + c) ~/ w.length;
    profits.add(avg);
    if (args.contains('-v')) {
      print(
          'seed $seed: ${sim.state.phase} day ${sim.state.dayIndex} cash ${sim.state.cash} rep ${sim.state.loc.reputation.toStringAsFixed(2)} '
          'avgWeekProfit $avg stage ${sim.state.stage} ${sim.state.gameOverReason ?? ''}');
    }
  }
  stage2.sort();
  profits.sort();
  print(
      'tier=$tier policy=$policy seeds=$seeds weeks=$weeks  (${sw.elapsed.inSeconds}s)');
  print('survival ${(100 * survived / seeds).toStringAsFixed(0)}%');
  print(
      'median week reaching stage 2: ${stage2.isEmpty ? 'never' : stage2[stage2.length ~/ 2]} (${stage2.length}/$seeds reached)');
  print('walk-out rate ${(100 * walk / groups).toStringAsFixed(1)}%');
  print('median avg weekly operating profit ${profits[profits.length ~/ 2]}');
  print('incidents per week ${(incidents / seeds / weeks).toStringAsFixed(1)}');
}

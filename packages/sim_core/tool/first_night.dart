// Opening night: how many parties a new owner serves against the forecast.
// dart run tool/first_night.dart
import 'package:sim_core/sim_core.dart';

import 'load.dart';

void main() {
  final content = loadContent();
  for (final diff in ['easy', 'normal', 'hard']) {
    for (var tier = 0; tier < content.tiers.length; tier++) {
      final ratios = <double>[];
      var fc = 0;
      for (var seed = 1; seed <= 60; seed++) {
        final sim = Sim.newGame(content: content, seed: seed, difficulty: diff);
        if (!sim.apply(BuyRestaurant(tier)).ok) continue;
        void clear() {
          for (final i in List.of(sim.state.openIncidents)) {
            sim.apply(ResolveIncident(
                i.id, content.incidents[i.incidentId]!.defaultOption));
          }
        }

        clear();
        fc += sim.forecast().groups;
        sim.apply(const StartService());
        var g = 0;
        while (sim.state.phase == 'service' && g++ < 1000) {
          clear();
          sim.tick();
        }
        final t = sim.state.viewLoc.today;
        ratios.add(t.groupsServed / t.forecast);
      }
      ratios.sort();
      String p(double q) =>
          ratios[(q * (ratios.length - 1)).round()].toStringAsFixed(2);
      print('$diff ${content.tiers[tier].id.padRight(8)} n=${ratios.length} '
          'fc~${(fc / ratios.length).toStringAsFixed(0)} served/fc p10=${p(0.1)} p25=${p(0.25)} p50=${p(0.5)} p90=${p(0.9)}');
    }
  }
}

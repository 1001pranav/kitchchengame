import 'package:sim_core/sim_core.dart';

import '../tool/load.dart';

final content = loadContent();

Sim boughtSim(
    {int seed = 1, String tier = 'good', String difficulty = 'normal'}) {
  final sim = Sim.newGame(content: content, seed: seed, difficulty: difficulty);
  final r =
      sim.apply(BuyRestaurant(content.tiers.indexWhere((t) => t.id == tier)));
  if (!r.ok) throw StateError('buy failed: ${r.message}');
  return sim;
}

/// Resolves every open card with its default option.
void clearCards(Sim sim) {
  for (final i in sim.state.openIncidents) {
    sim.apply(ResolveIncident(
        i.id, sim.content.incidents[i.incidentId]!.defaultOption));
  }
}

void runService(Sim sim) {
  var guard = 0;
  while (sim.state.phase == 'service' && guard++ < 1000) {
    sim.tick();
  }
}

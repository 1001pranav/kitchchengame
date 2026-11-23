import 'dart:convert';
import 'dart:io';

import 'package:sim_core/sim_core.dart';

import 'load.dart';

/// Parity trace: plays a scripted game and prints the full state after each day
/// as one JSON line. game/tools/trace.gd plays the same script in Godot.
/// Usage: `dart run tool/trace.dart SEED DIFFICULTY OFFER DAYS [chain]`
void main(List<String> args) {
  final seed = int.parse(args[0]);
  final diff = args[1];
  final offer = int.parse(args[2]);
  final days = int.parse(args[3]);
  final sim = Sim.newGame(content: loadContent(), seed: seed, difficulty: diff);
  final out = stdout;
  void snap(String tag) =>
      out.writeln(jsonEncode({'tag': tag, 'save': sim.toSave()}));
  snap('market');
  sim.apply(BuyRestaurant(offer));
  void defaults() {
    for (final i in sim.state.openIncidents) {
      sim.apply(ResolveIncident(
          i.id, sim.content.incidents[i.incidentId]!.defaultOption));
    }
  }

  const areas = ['door', 'tables', 'pass', 'dishes'];
  for (var d = 0; d < days && sim.state.phase != 'gameOver'; d++) {
    defaults();
    if (d % 3 == 0) {
      final lines = sim.suggestedOrder('sup_standard');
      if (lines.isNotEmpty) sim.apply(PlaceOrder('sup_standard', lines));
    }
    if (args.length > 4 && args[4] == 'chain' && d == 2) {
      // Jump to the chain stage: a second outlet with a manager (exercises chain.dart).
      sim.state.stage = 3;
      sim.state.cash = 400000;
      sim.state.marketRefreshDay = -1;
      sim.apply(
          const EndDay()); // close phase is required; we are in prep, so this fails harmlessly
    }
    if (args.length > 4 &&
        args[4] == 'chain' &&
        d == 3 &&
        sim.state.outletMarket.isNotEmpty) {
      sim.apply(const BuyOutlet(2));
      final l2 = sim.state.locations.last;
      sim.apply(SelectLocation(l2.id));
      final cands = sim.state.managerApplicants
          .where((a) => a.grade != 'Senior' && a.grade != 'Veteran')
          .toList();
      if (cands.isNotEmpty) sim.apply(HireManager(cands.first.id));
      sim.apply(SelectLocation(sim.state.locations.first.id));
    }
    snap('prep$d');
    sim.apply(const StartService());
    var k = 0;
    while (sim.state.phase == 'service') {
      defaults();
      if (k % 40 == 0) sim.apply(OwnerStand(areas[(k ~/ 40) % 4]));
      sim.tick();
      k++;
    }
    defaults();
    snap('close$d');
    sim.apply(const EndDay());
  }
  snap('end');
}

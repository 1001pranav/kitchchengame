// Preview entry point: opens straight into a running service so the restaurant
// scene can be recorded in a browser. Not used by the Android app.
// Build: flutter build web -t tool/preview_service.dart
import 'package:flutter/material.dart';
import 'package:kitchen_chain/main.dart';
import 'package:kitchen_chain/state/game_controller.dart';
import 'package:kitchen_chain/state/save_service.dart';
import 'package:kitchen_chain/state/settings.dart';
import 'package:sim_core/sim_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final content = await loadContent();
  final theme = Uri.base.queryParameters['cuisine'] ?? 'italian';
  final c = GameController(
      content: content,
      saves: SaveService(),
      settings: Settings(tutorial: false, sound: false));
  final screen = Uri.base.queryParameters['screen'] ?? 'service';
  if (screen == 'title') {
    runApp(KitchenChainApp(controller: c));
    return;
  }
  c.newGame(seed: 11, difficulty: 'easy', themeId: theme);
  if (screen != 'intro') c.finishIntro();
  if (screen == 'market' || screen == 'intro') {
    runApp(KitchenChainApp(controller: c));
    return;
  }
  c.send(const BuyRestaurant(2));
  void clear() {
    for (final i in List.of(c.state!.openIncidents)) {
      c.send(ResolveIncident(
          i.id, c.content.incidents[i.incidentId]!.defaultOption));
    }
    c.send(const AckNotices());
  }

  clear();
  if (screen == 'prep') {
    runApp(KitchenChainApp(controller: c));
    return;
  }
  // Skip ahead in the day so the room is busy when the recording starts.
  c.send(const StartService());
  if (screen == 'close') {
    c.send(const EndService());
    clear();
    runApp(KitchenChainApp(controller: c));
    return;
  }
  final skip = int.tryParse(Uri.base.queryParameters['skip'] ?? '') ?? 60;
  for (var i = 0; i < skip && c.state!.phase == 'service'; i++) {
    c.sim!.tick();
    clear();
  }
  c.send(const OwnerStand('tables'));
  c.events.listen((e) {
    if (e.type == 'incidentRaised') Future.microtask(clear);
  });
  runApp(KitchenChainApp(controller: c));
  c.setSpeed(Speed.normal);
}

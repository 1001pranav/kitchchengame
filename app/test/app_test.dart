import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_chain/main.dart';
import 'package:kitchen_chain/state/game_controller.dart';
import 'package:kitchen_chain/state/save_service.dart';
import 'package:kitchen_chain/state/settings.dart';
import 'package:sim_core/sim_core.dart';

Future<GameController> _controller() async {
  final content = await loadContent();
  return GameController(content: content, saves: SaveService(), settings: Settings(tutorial: true));
}

Future<void> _pump(WidgetTester t, GameController c, Size size) async {
  final prev = FlutterError.onError;
  FlutterError.onError = (d) {
    if ('${d.exception}'.contains('overflowed')) {
      for (final n in d.informationCollector?.call() ?? const <DiagnosticsNode>[]) {
        try {
          // ignore: avoid_print
          print('OVF ${n.toStringDeep(minLevel: DiagnosticLevel.info).split('\n').take(3).join(' ')}');
        } catch (_) {}
      }
    }
    prev?.call(d);
  };
  addTearDown(() => FlutterError.onError = prev);
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(KitchenChainApp(controller: c));
  await t.pump(const Duration(milliseconds: 300));
}

/// Answers open cards with their default and closes any sheets, like a player tapping through.
Future<void> _closeSheets(WidgetTester t, GameController c) async {
  for (var i = 0; i < 8; i++) {
    for (final inst in c.state!.openIncidents) {
      c.send(ResolveIncident(inst.id, c.content.incidents[inst.incidentId]!.defaultOption));
    }
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    if (!nav.canPop()) break;
    nav.pop();
    await t.pump(const Duration(milliseconds: 400));
  }
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  for (final size in const [Size(360, 640), Size(390, 844)]) {
    testWidgets('title and market build at $size', (t) async {
      final c = await t.runAsync(_controller);
      await _pump(t, c!, size);
      expect(find.text('Kitchen Chain'), findsOneWidget);
      c.newGame(seed: 3, difficulty: 'normal');
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Restaurants for sale'), findsOneWidget);
    });

    testWidgets('a full day: buy, prep, every tab, service, close, next day at $size', (t) async {
      final c = await t.runAsync(_controller);
      await _pump(t, c!, size);
      c.newGame(seed: 5, difficulty: 'normal');
      c.send(const BuyRestaurant(2));
      await t.pump(const Duration(milliseconds: 500));
      await _closeSheets(t, c);
      expect(find.text('FORECAST'), findsOneWidget);
      for (final tab in ['Staff', 'Stock', 'Kitchen', 'Money', 'Today']) {
        await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)));
        await t.pump(const Duration(milliseconds: 300));
        await _closeSheets(t, c);
      }
      // Resolve any open cards, then open the doors.
      for (final i in c.state!.openIncidents) {
        c.send(ResolveIncident(i.id, c.content.incidents[i.incidentId]!.defaultOption));
      }
      await t.pump(const Duration(milliseconds: 300));
      c.send(const StartService());
      c.setSpeed(Speed.paused);
      await t.pump(const Duration(milliseconds: 300));
      await _closeSheets(t, c);
      expect(find.textContaining('/${c.sim!.service!.target}'), findsWidgets);
      for (var k = 0; k < 400 && c.state!.phase == 'service'; k++) {
        for (final i in c.state!.openIncidents) {
          c.send(ResolveIncident(i.id, c.content.incidents[i.incidentId]!.defaultOption));
        }
        c.sim!.tick();
        if (k % 40 == 0) {
          c.send(const OwnerStand('door'));
          await t.pump(const Duration(milliseconds: 50));
        }
      }
      c.send(const OwnerStand(null)); // no-op in close, refreshes listeners
      await t.pump(const Duration(milliseconds: 500));
      await _closeSheets(t, c);
      expect(c.state!.phase, 'close');
      expect(find.textContaining('Sleep'), findsOneWidget);
      await t.tap(find.text('Why'));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text('Tomorrow'));
      await t.pump(const Duration(milliseconds: 300));
      c.send(const EndDay());
      await t.pump(const Duration(milliseconds: 500));
      await _closeSheets(t, c);
      expect(c.state!.dayIndex, 1);
    });
  }
}

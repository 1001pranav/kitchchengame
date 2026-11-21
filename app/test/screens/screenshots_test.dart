// Renders real-font screenshots of the chain screens for review.
// Run: flutter test test/screens --run-skipped --update-goldens (writes PNGs next to this file)
@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_chain/main.dart';
import 'package:kitchen_chain/state/game_controller.dart';
import 'package:kitchen_chain/state/save_service.dart';
import 'package:kitchen_chain/state/settings.dart';
import 'package:sim_core/sim_core.dart';

Future<void> _font(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  await loader.load();
}

void main() {
  testWidgets('chain screenshots', (t) async {
    await t.runAsync(() async {
      const base =
          '/opt/flutter-sdk/flutter/bin/cache/dart-sdk/bin/resources/devtools/assets/packages/devtools_app_shared/fonts/Roboto';
      final roboto = FontLoader('Roboto');
      for (final w in ['Regular', 'Medium', 'Bold']) {
        final f = File('$base/Roboto-$w.ttf');
        if (f.existsSync()) {
          roboto
              .addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
        }
      }
      await roboto.load();
      final icons = Directory('/opt/flutter-sdk/flutter/bin/cache')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('MaterialIcons-Regular.otf'))
          .firstOrNull;
      if (icons != null) await _font('MaterialIcons', icons.path);
    });
    final c = (await t.runAsync(() async => GameController(
        content: await loadContent(),
        saves: SaveService(),
        settings: Settings(tutorial: false))))!;
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(KitchenChainApp(controller: c));
    c.newGame(seed: 4, difficulty: 'normal', themeId: 'mixed');
    c.send(const BuyRestaurant(2));
    final st = c.state!;
    st.stage = 3;
    st.cash = 400000;
    void clear() {
      for (final i in c.state!.openIncidents) {
        c.send(ResolveIncident(
            i.id, c.content.incidents[i.incidentId]!.defaultOption));
      }
      c.send(const AckNotices());
    }

    clear();
    c.send(const StartService());
    c.send(const EndService());
    clear();
    c.send(const EndDay());
    clear();
    c.send(const BuyOutlet(2));
    final l2 = c.state!.locations.last;
    c.send(SelectLocation(l2.id));
    c.send(HireManager(c.state!.managerApplicants
        .firstWhere((a) => a.grade != 'Senior' && a.grade != 'Veteran')
        .id));
    c.send(SelectLocation(1));
    clear();
    Future<void> shot(String name) async {
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      await expectLater(
          find.byType(MaterialApp), matchesGoldenFile('$name.png'));
    }

    await shot('prep_desk');
    await t.tap(find.descendant(
        of: find.byType(NavigationBar), matching: find.text('Company')));
    await shot('company_overview');
    await t.tap(find.text('Outlets'));
    await shot('company_outlets');
    await t.tap(find.text('Expand'));
    await shot('company_expand');
    await t.tap(find.descendant(
        of: find.byType(NavigationBar), matching: find.text('Today')));
    c.send(const StartService());
    c.setSpeed(Speed.paused);
    for (var i = 0; i < 150; i++) {
      c.sim!.tick();
      clear();
    }
    c.send(const OwnerStand('door'));
    await shot('service_mixed');
    c.send(SelectLocation(l2.id));
    await shot('service_watching_other');
  });
}

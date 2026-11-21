import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sim_core/sim_core.dart';

import 'state/game_controller.dart';
import 'state/save_service.dart';
import 'state/settings.dart';
import 'state/sound_service.dart';
import 'ui/screens/title_screen.dart';
import 'ui/shell/shell.dart';
import 'ui/theme.dart';
import 'ui/widgets/common.dart';

Future<Content> loadContent() async {
  final files = <String, String>{};
  for (final f in contentFiles) {
    files[f] = await rootBundle.loadString('packages/sim_core/data/$f');
  }
  return ContentLoader.load(files);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final content = await loadContent();
  final saves = SaveService();
  final settingsJson = await saves.read('settings');
  final settings =
      settingsJson == null ? Settings() : Settings.fromJson(settingsJson);
  final controller =
      GameController(content: content, saves: saves, settings: settings);
  SoundService(controller);
  runApp(KitchenChainApp(controller: controller));
}

class KitchenChainApp extends StatelessWidget {
  final GameController controller;
  const KitchenChainApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return GameScope(
      controller: controller,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => MaterialApp(
          title: 'Kitchen Chain',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(_accent(controller)),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(controller.settings.textScale),
              disableAnimations: controller.settings.reducedMotion ||
                  MediaQuery.of(context).disableAnimations,
            ),
            child: child!,
          ),
          home: const RootRouter(),
        ),
      ),
    );
  }
}

/// Title → market → game shell, driven by the state.
class RootRouter extends StatelessWidget {
  const RootRouter({super.key});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final st = c.state;
    if (st == null) return const TitleScreen();
    if (st.phase == 'market') return const MarketScreen();
    return const GameShell();
  }
}

Color _accent(GameController c) {
  final st = c.state;
  if (st == null) return Palette.accent;
  final hex = c.content.themes[st.themeId]?.accent ?? '#2F7D4F';
  return Color(int.parse('FF${hex.substring(1)}', radix: 16));
}

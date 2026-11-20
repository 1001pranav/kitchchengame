import 'package:flutter/material.dart';
import 'package:sim_core/sim_core.dart';

import '../../state/game_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Searchable list of every term (doc 07 §5).
class HandbookScreen extends StatefulWidget {
  const HandbookScreen({super.key});
  @override
  State<HandbookScreen> createState() => _HandbookScreenState();
}

class _HandbookScreenState extends State<HandbookScreen> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final terms = c.content.terms.values
        .where((t) => q.isEmpty || '${t.name} ${t.meaning} ${t.why}'.toLowerCase().contains(q.toLowerCase()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return Scaffold(
      appBar: AppBar(title: const Text('Handbook'), backgroundColor: Palette.bg),
      body: Centered(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search: rating, waste, loan…', border: OutlineInputBorder()),
              onChanged: (v) => setState(() => q = v),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: terms.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, i) {
                final t = terms[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(t.meaning),
                    const SizedBox(height: 2),
                    Text('Why it matters: ${t.why}', style: const TextStyle(color: Palette.muted)),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final s = c.settings;
    void save() => c.saveSettings();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), backgroundColor: Palette.bg),
      body: Centered(
        child: ListView(padding: const EdgeInsets.all(8), children: [
          SwitchListTile(title: const Text('Sound'), value: s.sound, onChanged: (v) {
            s.sound = v;
            save();
          }),
          SwitchListTile(title: const Text('Vibration on taps'), value: s.haptics, onChanged: (v) {
            s.haptics = v;
            save();
          }),
          SwitchListTile(
            title: const Text('Reduce motion'),
            subtitle: const Text('No moving figures or floating numbers'),
            value: s.reducedMotion,
            onChanged: (v) {
              s.reducedMotion = v;
              save();
            },
          ),
          SwitchListTile(
            title: const Text('Speed through quiet spells'),
            subtitle: const Text('When nobody is waiting, the clock runs 4× faster'),
            value: s.quietFastForward,
            onChanged: (v) {
              s.quietFastForward = v;
              save();
            },
          ),
          ListTile(
            title: const Text('Text size'),
            subtitle: Slider(
              value: s.textScale,
              min: 0.9,
              max: 1.3,
              divisions: 4,
              label: '${(s.textScale * 100).round()}%',
              onChanged: (v) {
                s.textScale = v;
                save();
              },
            ),
          ),
          SwitchListTile(title: const Text('Tutorial tips (first 3 days)'), value: s.tutorial, onChanged: (v) {
            s.tutorial = v;
            save();
          }),
          ListTile(
            title: const Text('Show every term card again'),
            trailing: const Icon(Icons.refresh),
            onTap: () {
              s.seenTerms.clear();
              s.tutorial = true;
              save();
              showToast(context, 'Tutorial reset.', bad: false);
            },
          ),
          const AboutListTile(
            applicationName: 'Kitchen Chain',
            applicationVersion: '0.1.0',
            aboutBoxChildren: [Text('An offline restaurant management game. No ads, no accounts, no network.')],
          ),
        ]),
      ),
    );
  }
}

void showLoadSheet(BuildContext context) {
  final c = GameScope.read(context);
  showModalBottomSheet(
    context: context,
    builder: (sheet) => FutureBuilder<List<Map<String, dynamic>?>>(
      future: Future.wait([for (final s in SaveSlots.all) c.saves.read(s)]),
      builder: (context, snap) {
        final data = snap.data;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Load a game', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (var i = 0; i < SaveSlots.all.length; i++)
                ListTile(
                  leading: Icon(i == 0 ? Icons.autorenew : Icons.save),
                  title: Text(SaveSlots.names[i]),
                  subtitle: Text(data == null ? '…' : SaveSlots.describe(data[i])),
                  enabled: data != null && data[i] != null,
                  onTap: () async {
                    final ok = await c.load(SaveSlots.all[i]);
                    if (sheet.mounted) Navigator.pop(sheet);
                    if (!ok && context.mounted) showToast(context, 'That save could not be loaded.');
                  },
                ),
            ]),
          ),
        );
      },
    ),
  );
}

class SaveSlots {
  static const all = ['autosave', 'save_1', 'save_2', 'save_3'];
  static const names = ['Autosave', 'Slot 1', 'Slot 2', 'Slot 3'];
  static String describe(Map<String, dynamic>? d) {
    if (d == null) return 'Empty';
    try {
      final st = (d['state'] as Map).cast<String, dynamic>();
      final locs = st['locations'] as List;
      if (locs.isEmpty) return 'Choosing a restaurant';
      final name = (locs.first as Map)['name'];
      return '$name · Day ${(st['dayIndex'] as num).toInt() + 1} · ${fmtMoney((st['cash'] as num).toInt())} coins';
    } catch (_) {
      return 'Unreadable';
    }
  }
}

void showPauseMenu(BuildContext context) {
  final c = GameScope.read(context);
  final was = c.speed;
  c.setSpeed(Speed.paused);
  showModalBottomSheet(
    context: context,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Paused', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: () => Navigator.pop(sheet), icon: const Icon(Icons.play_arrow), label: const Text('Resume')),
          const SizedBox(height: 8),
          Row(children: [
            for (var i = 1; i < SaveSlots.all.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: OutlinedButton(
                    onPressed: () async {
                      await c.saveTo(SaveSlots.all[i]);
                      if (context.mounted) showToast(context, 'Saved to ${SaveSlots.names[i]}.', bad: false);
                    },
                    child: Text('Save ${SaveSlots.names[i]}'),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HandbookScreen())),
            icon: const Icon(Icons.menu_book),
            label: const Text('Handbook'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            icon: const Icon(Icons.settings),
            label: const Text('Settings'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Palette.bad),
            onPressed: () {
              Navigator.pop(sheet);
              c.quitToTitle();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Save and quit to title'),
          ),
        ]),
      ),
    ),
  ).then((_) {
    if (c.state?.phase == 'service' && was != Speed.paused) c.setSpeed(was);
  });
}

/// Timeline of what led here, final stats, retry (doc 07 §4.10).
class GameOverScreen extends StatelessWidget {
  const GameOverScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final st = c.state!;
    final sim = c.sim!;
    return Scaffold(
      body: SafeArea(
        child: Centered(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const SizedBox(height: 20),
            const Icon(Icons.sentiment_very_dissatisfied, size: 72, color: Palette.bad),
            const SizedBox(height: 8),
            Text('${st.loc.name} has closed', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(st.gameOverReason ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.4)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Panel(child: Column(children: [const Text('Days survived', style: TextStyle(color: Palette.muted)), Text('${st.dayIndex + 1}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))]))),
              const SizedBox(width: 8),
              Expanded(child: Panel(child: Column(children: [const Text('Final rating', style: TextStyle(color: Palette.muted)), Text(st.loc.reputation.toStringAsFixed(1), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))]))),
              const SizedBox(width: 8),
              Expanded(child: Panel(child: Column(children: [const Text('Stage', style: TextStyle(color: Palette.muted)), Text('${st.stage}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))]))),
            ]),
            const SectionTitle('What happened'),
            for (final e in st.timeline.reversed.take(15))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 64, child: Text('Day ${e.day + 1}', style: const TextStyle(color: Palette.muted))),
                  Expanded(child: Text(e.text)),
                ]),
              ),
            const SizedBox(height: 10),
            Panel(
              color: Palette.accentSoft,
              borderColor: Colors.transparent,
              child: const Text(
                'Most restaurants fail on cash, not on food: a profitable week can still leave you unable to pay Sunday\'s wages, rent and loan. '
                'Watch "Cash in hand" on the Money tab, not just profit.',
                style: TextStyle(height: 1.4),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
              onPressed: () => c.newGame(seed: st.seed, difficulty: st.difficulty),
              icon: const Icon(Icons.replay),
              label: const Text('Try again (same restaurants)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: () {
                c.saves.delete('autosave');
                c.quitToTitle();
              },
              child: const Text('Back to title'),
            ),
            Text('Company value at the end: ${fmtMoney(sim.valuation())}', textAlign: TextAlign.center, style: const TextStyle(color: Palette.muted)),
          ]),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:sim_core/sim_core.dart';

import '../shell/shell.dart';
import 'chain_screens.dart';
import '../theme.dart';
import '../widgets/juice.dart';
import '../scene/shopfront.dart';
import '../widgets/common.dart';

const areaLabels = {
  'door': 'Door',
  'tables': 'Tables',
  'pass': 'Pass',
  'dishes': 'Dishes'
};
const areaIcons = {
  'door': Icons.door_front_door_outlined,
  'tables': Icons.table_restaurant_outlined,
  'pass': Icons.room_service_outlined,
  'dishes': Icons.wash_outlined
};

class _Attention {
  final IconData icon;
  final String text;
  final Color color;
  final int tab;
  const _Attention(this.icon, this.text, this.color, this.tab);
}

/// Prep board (doc 07 §4.3): three taps to get through when nothing is wrong.
class PrepBoard extends StatelessWidget {
  const PrepBoard({super.key});

  List<_Attention> _attention(Sim sim) {
    final st = sim.state;
    final l = st.viewLoc;
    final out = <_Attention>[];
    for (final s in l.staff.where((s) => s.absentToday)) {
      out.add(_Attention(
          Icons.person_off,
          '${s.name} (${sim.role(s.role).toLowerCase()}) is absent today',
          Palette.bad,
          1));
    }
    for (final r in sim.uncoveredRoles()) {
      final who = r == 'cook'
          ? 'No cook in today — you will cook at the Pass, slowly'
          : 'Nobody on ${sim.role(r).toLowerCase()} duty today — a stand-in will cover, slower';
      out.add(_Attention(Icons.report, who, Palette.warn, 1));
    }
    final risks = sim.runOutRisks().entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    for (final e in risks.take(3)) {
      final ing = sim.content.ingredients[e.key]!;
      final hour = 11 + (12 * e.value).floor();
      out.add(_Attention(Icons.inventory_2, '${ing.name} runs out by ~$hour:00',
          Palette.warn, 2));
    }
    if (risks.length > 3) {
      out.add(_Attention(
          Icons.inventory_2,
          '${risks.length - 3} more ingredients are short today',
          Palette.warn,
          2));
    }
    for (final e in l.equipment.where((e) => e.broken)) {
      out.add(_Attention(Icons.build,
          '${sim.content.equipment[e.type]!.name} is broken', Palette.bad, 3));
    }
    for (final e in l.equipment.where((e) => !e.broken && e.condition < 40)) {
      out.add(_Attention(
          Icons.build_circle,
          '${sim.content.equipment[e.type]!.name} condition ${e.condition.round()} — may break',
          Palette.warn,
          3));
    }
    for (final s in l.staff.where((s) => s.morale < 30)) {
      out.add(_Attention(Icons.sentiment_very_dissatisfied,
          '${s.name} is very unhappy and may leave', Palette.bad, 1));
    }
    for (final s in l.staff.where((s) => s.status == 'notice')) {
      out.add(_Attention(Icons.logout,
          '${s.name} leaves in ${s.noticeLeft} days', Palette.warn, 1));
    }
    final due = l.payables
        .where((p) => p.dueDay <= st.dayIndex + 3)
        .fold<int>(0, (a, p) => a + p.amount);
    if (due > 0) {
      out.add(_Attention(
          Icons.request_quote,
          'Supplier bills of ${fmtMoney(due)} due within 3 days',
          Palette.warn,
          4));
    }
    final sunday = st.wagesOwed + l.rentWeekly + sim.weeklyInstalments();
    if (st.cash < sunday * 1.2 && st.weekday >= 3) {
      out.add(_Attention(
          Icons.savings,
          'Cash is tight: about ${fmtMoney(sunday)} goes out on Sunday',
          Palette.bad,
          4));
    }
    if (l.hygiene < 60) {
      out.add(_Attention(
          Icons.cleaning_services,
          'Cleanliness ${l.hygiene.round()} — an inspection would fail',
          Palette.warn,
          1));
    }
    if (l.closedUntil > st.dayIndex) {
      out.add(const _Attention(
          Icons.block, 'The restaurant is closed today', Palette.bad, 0));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final st = sim.state;
    final l = st.viewLoc;
    final fc = sim.forecast();
    final att = _attention(sim);
    final working = l.staff.where((s) => s.workingToday).toList();
    int count(List<String> roles) =>
        working.where((s) => roles.contains(s.role)).length;
    final fest = sim.festivalOn(st.dayIndex);
    final orders = l.orders;
    final target = sim.targetPreview();
    final closed = l.closedUntil > st.dayIndex;
    final busy = fc.label.contains('busy');
    final stations = <(String, int, bool)>[
      ('Kitchen', count(['headChef', 'lineCook']), false),
      ('Floor', count(['server']), false),
      ('Till', count(['cashier']), false),
      ('Dishes', count(['dishwasher']), false),
      ('Cleaning', count(['cleaner']), false),
      ('Prep', count(['prepCook']), true),
    ];
    return Column(children: [
      Expanded(
        child: Centered(
          child: ListView(padding: EdgeInsets.zero, children: [
            // Hero: the place at dawn, and tonight in one number.
            Stack(children: [
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.white, Colors.transparent],
                  stops: [0, 0.55, 1],
                ).createShader(r),
                blendMode: BlendMode.dstIn,
                child: Shopfront(
                    name: l.name,
                    quality: tierQuality(l.tierId),
                    time: DayTime.morning,
                    open: false,
                    animate: true,
                    height:
                        MediaQuery.of(context).size.height < 700 ? 150 : 200,
                    seed: l.id),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 4,
                child:
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('TONIGHT AT',
                              style: TextStyle(
                                  color: Palette.accent,
                                  fontSize: 10.5,
                                  letterSpacing: 2.2,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(l.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontSize: 26)),
                        ]),
                  ),
                  GestureDetector(
                    onTap: () => showWhy(context, sim.explain('demand')),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${fc.groups}',
                              style: const TextStyle(
                                  fontSize: 40,
                                  height: 1,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: [
                                    FontFeature.tabularFigures()
                                  ])),
                          Text(
                              fest != null
                                  ? fest.name.toUpperCase()
                                  : 'PARTIES · ${fc.label.toUpperCase()}',
                              style: TextStyle(
                                  color: busy || fest != null
                                      ? Palette.tomato
                                      : Palette.muted,
                                  fontSize: 10,
                                  letterSpacing: 1.6,
                                  fontWeight: FontWeight.w600)),
                        ]),
                  ),
                ]),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tonight in three numbers.
                    _Brief(items: [
                      (
                        'TARGET',
                        '≤ $target',
                        target == 1 ? 'party lost' : 'parties lost',
                        () => showTerm(context, 'shift_target')
                      ),
                      (
                        'ON SHIFT',
                        '${working.length}/${l.staff.length}',
                        'staff',
                        () => ShellNav.to(context, 1)
                      ),
                      (
                        'ARRIVING',
                        '${orders.length}',
                        orders.length == 1 ? 'delivery' : 'deliveries',
                        () => ShellNav.to(context, 2)
                      ),
                    ]),
                    const SizedBox(height: 4),
                    if (c.settings.tutorial && st.dayIndex < 3)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _Tutorial(day: st.dayIndex)),
                    const OwnersDesk(),
                    SectionTitle(att.isEmpty
                        ? 'Before you open'
                        : 'Before you open · ${att.length}'),
                    if (att.isEmpty)
                      const _AllClear()
                    else
                      for (final a in att) _AttentionRow(a: a),
                    const SectionTitle('Stations'),
                    GestureDetector(
                      onTap: () => ShellNav.to(context, 1),
                      child: GridView(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 1,
                            crossAxisSpacing: 1,
                            mainAxisExtent: 18 +
                                MediaQuery.textScalerOf(context).scale(36)),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (final (name, n, optional) in stations)
                            _StationCell(
                                name: name, n: n, missing: n == 0 && !optional),
                        ],
                      ),
                    ),
                    SectionTitle(
                      'Your post',
                      trailing: st.owner.restingToday
                          ? const Text('RESTING',
                              style: TextStyle(
                                  color: Palette.owner,
                                  fontSize: 10.5,
                                  letterSpacing: 1.6,
                                  fontWeight: FontWeight.w700))
                          : null,
                    ),
                    Row(children: [
                      for (final a in areaLabels.keys)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: _AreaButton(
                              area: a,
                              selected: st.owner.startArea == a &&
                                  !st.owner.restingToday,
                              onTap: st.owner.restingToday
                                  ? null
                                  : () => sendCmd(context, OwnerStand(a)),
                            ),
                          ),
                        ),
                    ]),
                  ]),
            ),
          ]),
        ),
      ),
      // The one decision that matters most, always in reach.
      Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0E0C0A),
          border: Border(top: BorderSide(color: Palette.line)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Centered(
          child: Row(children: [
            SizedBox(
              width: 56,
              height: 56,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () async {
                  if (st.owner.restingToday) {
                    sendCmd(context, const OwnerRest(false));
                    return;
                  }
                  final ok = await confirm(context, 'Take the day off?',
                      'Your energy goes back to 100. The team runs the whole shift without you.',
                      ok: 'Rest');
                  if (ok && context.mounted) {
                    sendCmd(context, const OwnerRest(true));
                  }
                },
                child: Tooltip(
                  message: st.owner.restingToday ? 'Work today' : 'Rest today',
                  child: Icon(
                      st.owner.restingToday
                          ? Icons.directions_walk
                          : Icons.bedtime_outlined,
                      color: st.owner.restingToday
                          ? Palette.owner
                          : Palette.muted),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Pressable(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: Palette.tomato,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                          fontSize: 15,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700)),
                  onPressed: () => sendCmd(context, const StartService()),
                  child: Text(closed ? 'SKIP THE DAY' : 'OPEN THE DOORS'),
                ),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}

/// Three numbers side by side, separated by hairlines.
class _Brief extends StatelessWidget {
  final List<(String, String, String, VoidCallback)> items;
  const _Brief({required this.items});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.symmetric(
            horizontal: BorderSide(color: Palette.line.withValues(alpha: 0.9))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: IntrinsicHeight(
        child: Row(children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const VerticalDivider(width: 1, color: Palette.line),
            Expanded(
              child: InkWell(
                onTap: items[i].$4,
                child: Column(children: [
                  Text(items[i].$1,
                      style: const TextStyle(
                          color: Palette.muted,
                          fontSize: 9.5,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(items[i].$2,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()])),
                  Text(items[i].$3,
                      style: const TextStyle(
                          color: Palette.muted, fontSize: 11.5)),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _AllClear extends StatelessWidget {
  const _AllClear();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(Icons.check, size: 18, color: Palette.ok),
          SizedBox(width: 10),
          Expanded(
            child: Text('All clear. Open on time.',
                style: TextStyle(color: Palette.muted, fontSize: 14.5)),
          ),
        ]),
      );
}

/// One problem to deal with before service: a severity bar, the line, a way to fix it.
class _AttentionRow extends StatelessWidget {
  final _Attention a;
  const _AttentionRow({required this.a});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Palette.surface,
        child: InkWell(
          onTap: a.tab == 0 ? null : () => ShellNav.to(context, a.tab),
          child: IntrinsicHeight(
            child: Row(children: [
              Container(width: 3, color: a.color),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Icon(a.icon, size: 18, color: a.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(a.text, style: const TextStyle(fontSize: 14)),
                ),
              ),
              if (a.tab != 0)
                const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child:
                      Icon(Icons.chevron_right, size: 18, color: Palette.muted),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _StationCell extends StatelessWidget {
  final String name;
  final int n;
  final bool missing;
  const _StationCell(
      {required this.name, required this.n, required this.missing});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: missing ? const Color(0xFF2E1A16) : Palette.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(name.toUpperCase(),
                  style: TextStyle(
                      color: missing ? Palette.bad : Palette.muted,
                      fontSize: 9.5,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(missing ? 'none' : '$n',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: missing ? Palette.bad : Palette.ink)),
            ]),
      ),
    );
  }
}

class _AreaButton extends StatelessWidget {
  final String area;
  final bool selected;
  final VoidCallback? onTap;
  const _AreaButton({required this.area, required this.selected, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF16302F) : Palette.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: selected ? Palette.owner : Palette.line)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          height: 58,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(areaIcons[area],
                color: selected ? Palette.owner : Palette.muted, size: 19),
            const SizedBox(height: 4),
            Text(areaLabels[area]!.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 9.5,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: selected ? Palette.ink : Palette.muted)),
          ]),
        ),
      ),
    );
  }
}

class _Tutorial extends StatelessWidget {
  final int day;
  const _Tutorial({required this.day});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    const tips = [
      (
        'Day 1 · Running the floor',
        'When you open the doors, customers arrive in waves. Pick where to stand: the jam moves from the door, to orders, to the kitchen, to the bills. '
            'Your staff there work faster. Tap a table to Rush its food or Treat waiting guests.'
      ),
      (
        'Day 2 · Stock and ordering',
        'Food runs out and goes off. On the Stock tab, order today for tomorrow. "Order usual" fills in what you need. '
            'Fresh herbs last 3 days; dry pasta lasts 90. Waste is money in the bin.'
      ),
      (
        'Day 3 · Your team',
        'Everyone has one day off a week. On the Staff tab, check Happiness: unhappy people are slower, call in sick and may quit without warning. '
            'Tap a person to see exactly why they feel the way they do.'
      ),
    ];
    final t = tips[day.clamp(0, 2)];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        color: const Color(0xFF1F1B15),
        borderColor: const Color(0xFF5C4A23),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(t.$1,
                    style: const TextStyle(fontWeight: FontWeight.w800))),
            TextButton(
              onPressed: () {
                c.settings.tutorial = false;
                c.saveSettings();
              },
              child: const Text('Skip tips'),
            ),
          ]),
          Text(t.$2, style: const TextStyle(height: 1.4)),
        ]),
      ),
    );
  }
}

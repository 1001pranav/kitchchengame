import 'package:flutter/material.dart';
import 'package:sim_core/sim_core.dart';

import '../shell/shell.dart';
import '../theme.dart';
import '../widgets/common.dart';

const areaLabels = {
  'door': 'Door & till',
  'tables': 'Tables',
  'pass': 'Pass',
  'dishes': 'Dishes'
};
const areaIcons = {
  'door': Icons.door_front_door,
  'tables': Icons.table_restaurant,
  'pass': Icons.room_service,
  'dishes': Icons.wash
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
    final l = st.loc;
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
    final l = st.loc;
    final fc = sim.forecast();
    final att = _attention(sim);
    final working = l.staff.where((s) => s.workingToday).toList();
    int count(List<String> roles) =>
        working.where((s) => roles.contains(s.role)).length;
    final fest = sim.festivalOn(st.dayIndex);
    final orders = l.orders;
    return Centered(
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (c.settings.tutorial && st.dayIndex < 3)
              _Tutorial(day: st.dayIndex),
            Panel(
              onTap: () => showWhy(context, sim.explain('demand')),
              child: Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      color: Palette.accentSoft,
                      borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.groups_2,
                      color: Palette.accent, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('FORECAST',
                            style: TextStyle(
                                fontSize: 12,
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.w800,
                                color: Palette.muted)),
                        Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            children: [
                              Text('~${fc.groups}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium),
                              const TermText('parties', 'group',
                                  style: TextStyle(fontSize: 16)),
                              Pill(fc.label,
                                  color: fc.label.contains('busy')
                                      ? Palette.tomato
                                      : Palette.accent),
                            ]),
                        if (fest != null)
                          Text('${fest.name} is on: busier than usual',
                              style: const TextStyle(
                                  color: Palette.tomato,
                                  fontWeight: FontWeight.w600)),
                      ]),
                ),
                const Icon(Icons.help_outline, color: Palette.muted),
              ]),
            ),
            SectionTitle('Needs attention (${att.length})'),
            if (att.isEmpty)
              const EmptyNote('Nothing urgent. A good day to open on time.')
            else
              Panel(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (var i = 0; i < att.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      leading: Icon(att[i].icon, color: att[i].color),
                      title: Text(att[i].text,
                          style: const TextStyle(fontSize: 14.5)),
                      trailing: att[i].tab == 0
                          ? null
                          : const Icon(Icons.chevron_right),
                      onTap: att[i].tab == 0
                          ? null
                          : () => ShellNav.to(context, att[i].tab),
                    ),
                  ],
                ]),
              ),
            const SectionTitle('Today\'s team'),
            Panel(
              onTap: () => ShellNav.to(context, 1),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(
                              '${working.length} of ${l.staff.length} working',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16))),
                      const TermText('Days off', 'rota',
                          style: TextStyle(color: Palette.muted)),
                    ]),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _teamChip('Kitchen', count(['headChef', 'lineCook']),
                          Icons.soup_kitchen),
                      _teamChip('Prep', count(['prepCook']), Icons.blender,
                          optional: true),
                      _teamChip('Floor', count(['server']), Icons.room_service),
                      _teamChip(
                          'Till', count(['cashier']), Icons.point_of_sale),
                      _teamChip('Dishes', count(['dishwasher']), Icons.wash),
                      _teamChip('Cleaning', count(['cleaner']),
                          Icons.cleaning_services),
                    ]),
                  ]),
            ),
            if (orders.isNotEmpty) ...[
              const SectionTitle('Deliveries coming'),
              for (final o in orders)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Panel(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      const Icon(Icons.local_shipping, color: Palette.muted),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                              '${sim.content.suppliers[o.supplierId]!.name} · ${o.lines.length} items${o.late ? ' · late' : ''}')),
                      Text(o.dueDay == st.dayIndex ? 'today' : 'tomorrow',
                          style: const TextStyle(color: Palette.muted)),
                    ]),
                  ),
                ),
            ],
            const SectionTitle('Shift'),
            Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.flag, color: Palette.tomato),
                      const SizedBox(width: 8),
                      const TermText('Target', 'shift_target',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(
                              'lose no more than ${sim.targetPreview()} part${sim.targetPreview() == 1 ? 'y' : 'ies'}')),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      const TermText('Where you start', 'area',
                          style: TextStyle(color: Palette.muted)),
                      const Spacer(),
                      if (st.owner.restingToday)
                        const Pill('Resting today',
                            color: Palette.owner, icon: Icons.bedtime),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      for (final a in areaLabels.keys)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
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
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56)),
                  onPressed: () async {
                    if (st.owner.restingToday) {
                      sendCmd(context, const OwnerRest(false));
                      return;
                    }
                    final ok = await confirm(context, 'Rest today?',
                        'Your energy goes back to 100, but the team runs the whole shift without you. If a job has nobody, nobody does it.',
                        ok: 'Rest');
                    if (ok && context.mounted) {
                      sendCmd(context, const OwnerRest(true));
                    }
                  },
                  icon: Icon(st.owner.restingToday
                      ? Icons.directions_run
                      : Icons.bedtime),
                  label:
                      Text(st.owner.restingToday ? 'Work today' : 'Rest today'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: Palette.tomato),
                  onPressed: () => sendCmd(context, const StartService()),
                  icon: const Icon(Icons.storefront),
                  label: Text(l.closedUntil > st.dayIndex
                      ? 'SKIP THE DAY'
                      : 'OPEN DOORS'),
                ),
              ),
            ]),
          ]),
    );
  }

  Widget _teamChip(String label, int n, IconData icon,
      {bool optional = false}) {
    final missing = n == 0 && !optional;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: missing ? Palette.bad.withValues(alpha: 0.1) : Palette.surface2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: missing ? Palette.bad : Palette.ink),
        const SizedBox(width: 5),
        Text('$label $n',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: missing ? Palette.bad : Palette.ink)),
        if (missing)
          const Padding(
              padding: EdgeInsets.only(left: 3),
              child: Icon(Icons.warning_amber_rounded,
                  size: 15, color: Palette.bad)),
      ]),
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
      color: selected ? Palette.owner : Palette.surface2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 58,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(areaIcons[area],
                color: selected ? Colors.white : Palette.ink, size: 20),
            const SizedBox(height: 2),
            Text(areaLabels[area]!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : Palette.ink)),
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
        color: const Color(0xFFFFF4D6),
        borderColor: const Color(0xFFF0D58A),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.school, color: Palette.warn),
            const SizedBox(width: 8),
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

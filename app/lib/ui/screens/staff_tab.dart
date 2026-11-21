import 'package:flutter/material.dart';
import 'package:sim_core/sim_core.dart';

import '../theme.dart';
import '../widgets/common.dart';

const _roleOrder = [
  'headChef',
  'lineCook',
  'prepCook',
  'server',
  'cashier',
  'dishwasher',
  'cleaner'
];

class StaffTab extends StatelessWidget {
  const StaffTab({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(children: [
        Container(
            color: Palette.surface,
            child: const TabBar(tabs: [
              Tab(text: 'Team'),
              Tab(text: 'Days off'),
              Tab(text: 'Hire')
            ])),
        const Expanded(
            child: TabBarView(children: [_TeamList(), _DaysOff(), _Hire()])),
      ]),
    );
  }
}

String faceFor(double m) => m >= 70
    ? '😄'
    : (m >= 50 ? '🙂' : (m >= 40 ? '😐' : (m >= 30 ? '😟' : '😠')));

class _TeamList extends StatelessWidget {
  const _TeamList();
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final l = sim.state.viewLoc;
    final hap = sim.outletHappiness();
    final staff = List<Staff>.of(l.staff)
      ..sort((a, b) =>
          _roleOrder.indexOf(a.role).compareTo(_roleOrder.indexOf(b.role)));
    final wages = l.staff.fold<int>(0, (a, s) => a + s.wage);
    return Centered(
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Panel(
              child: Row(children: [
                Text(faceFor(hap), style: const TextStyle(fontSize: 34)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TermText('Team happiness', 'morale',
                            style: TextStyle(color: Palette.muted)),
                        Text('${hap.round()} / 100',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w900)),
                      ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${l.staff.length} people',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Row(children: [
                    Money(wages, size: 13),
                    const Text(' /day',
                        style: TextStyle(color: Palette.muted, fontSize: 12))
                  ]),
                ]),
              ]),
            ),
            const SizedBox(height: 10),
            for (final s in staff)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: StaffRow(
                    staff: s, onTap: () => showStaffDetail(context, s.id)),
              ),
          ]),
    );
  }
}

class StaffRow extends StatelessWidget {
  final Staff staff;
  final VoidCallback? onTap;
  final Widget? trailing;
  const StaffRow({super.key, required this.staff, this.onTap, this.trailing});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final s = staff;
    final st = sim.state;
    String status;
    Color sc;
    if (s.status == 'notice') {
      status = 'leaving in ${s.noticeLeft}d';
      sc = Palette.warn;
    } else if (s.trainingUntil > st.dayIndex) {
      status = 'training';
      sc = Palette.staff;
    } else if (s.absentToday || s.absentUntil > st.dayIndex) {
      status = 'absent';
      sc = Palette.bad;
    } else if (st.phase != 'close' && s.workingToday) {
      status = 'working';
      sc = Palette.ok;
    } else if (s.dayOff == st.weekday) {
      status = 'day off';
      sc = Palette.muted;
    } else {
      status = '';
      sc = Palette.muted;
    }
    final skillText = s.skillKnown
        ? '${s.skill.round()}'
        : '${(s.skill - 15).clamp(0, 100).round()}–${(s.skill + 15).clamp(0, 100).round()}';
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          CircleAvatar(
              radius: 22,
              backgroundColor: Palette.surface2,
              child: Icon(AssetCatalog.role(s.role), color: Palette.ink)),
          Positioned(
              right: -6,
              bottom: -6,
              child: Text(faceFor(s.morale),
                  style: const TextStyle(fontSize: 18))),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                  child: Text(s.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15))),
              const SizedBox(width: 6),
              if (status.isNotEmpty) Pill(status, color: sc),
            ]),
            Text(sim.role(s.role),
                style: const TextStyle(color: Palette.muted, fontSize: 12.5)),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.construction, size: 13, color: Palette.muted),
              const SizedBox(width: 3),
              Expanded(
                  child:
                      StatBar(s.skill / 100, color: Palette.staff, height: 6)),
              const SizedBox(width: 6),
              Text(skillText,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Icon(Icons.battery_charging_full,
                  size: 14,
                  color: s.fatigue > 70
                      ? Palette.bad
                      : (s.fatigue > 50 ? Palette.warn : Palette.ok)),
              Text('${(100 - s.fatigue).round()}',
                  style: const TextStyle(fontSize: 11)),
            ]),
            if (s.morale < 40)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Pill(s.morale < 30 ? 'may leave' : 'unhappy',
                    color: Palette.bad, icon: Icons.warning_amber_rounded),
              ),
          ]),
        ),
        const SizedBox(width: 8),
        trailing ??
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Money(s.wage, size: 13),
              const Text('/day',
                  style: TextStyle(color: Palette.muted, fontSize: 11))
            ]),
      ]),
    );
  }
}

void showStaffDetail(BuildContext context, int id) {
  showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StaffDetail(id: id));
}

class _StaffDetail extends StatelessWidget {
  final int id;
  const _StaffDetail({required this.id});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final s = sim.state.viewLoc.staffById(id);
    if (s == null) {
      return const SizedBox(
          height: 120, child: Center(child: Text('No longer works here.')));
    }
    final factors = sim.happinessFactors(s).entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final target = sim.happinessTarget(s);
    final exp = sim.expectedWage(s.role, s.skill);
    final trainCost = (10 * s.skill).round();
    final canAct = sim.state.phase != 'service';
    Widget stat(String k, String v, {String? term}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(
                child: term == null
                    ? Text(k, style: const TextStyle(color: Palette.muted))
                    : TermText(k, term,
                        style: const TextStyle(color: Palette.muted))),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
        );
    String remedy(String k) => switch (k) {
          'Pay' => 'Raise',
          'Tiredness' || 'Rest' => 'Day off',
          'Growth' => 'Train',
          _ => '',
        };
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Row(children: [
              CircleAvatar(
                  radius: 28,
                  backgroundColor: Palette.surface2,
                  child: Icon(AssetCatalog.role(s.role),
                      size: 30, color: Palette.ink)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          style: Theme.of(context).textTheme.titleLarge),
                      Text('${sim.role(s.role)} · since day ${s.hiredDay + 1}',
                          style: const TextStyle(color: Palette.muted)),
                    ]),
              ),
              Text(faceFor(s.morale), style: const TextStyle(fontSize: 36)),
            ]),
            if (s.traits.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final t in s.traits)
                  Tooltip(
                    message: c.content.traits[t]?.description ?? '',
                    triggerMode: TooltipTriggerMode.tap,
                    child: Chip(
                        label: Text(c.content.traits[t]?.name ?? t),
                        avatar: const Icon(Icons.psychology_alt, size: 16)),
                  ),
              ]),
            ],
            const SectionTitle('Numbers'),
            stat(
                'Skill',
                s.skillKnown
                    ? '${s.skill.round()}'
                    : '${(s.skill - 15).clamp(0, 100).round()}–${(s.skill + 15).clamp(0, 100).round()} (known after 7 days)'),
            stat(
                'Reliability',
                s.reliabilityKnown
                    ? '${s.reliability.round()}'
                    : '? (after 7 days)',
                term: 'reliability'),
            stat('Honesty',
                s.honestyKnown ? '${s.honesty.round()}' : '? (after 14 days)'),
            stat('Tiredness', '${s.fatigue.round()}', term: 'fatigue'),
            stat('Wage', '${fmtMoney(s.wage)} a day (fair: ${fmtMoney(exp)})'),
            stat(
                'Day off',
                s.preferredKnown
                    ? '${weekdayLong(s.dayOff)} (prefers ${weekdayLong(s.preferredDayOff)})'
                    : weekdayLong(s.dayOff)),
            SectionTitle(
                'Happiness ${s.morale.round()} → heading to ${target.round()}'),
            Panel(
              onTap: () =>
                  showWhy(context, sim.explain('staffHappiness', id: s.id)),
              child: Column(children: [
                if (factors.isEmpty)
                  const Text('Nothing in particular. Feeling neutral.',
                      style: TextStyle(color: Palette.muted)),
                for (final f in factors)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Expanded(child: Text(f.key)),
                      if (f.value < 0 && remedy(f.key).isNotEmpty && canAct)
                        Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Pill(remedy(f.key), color: Palette.accent)),
                      Text(
                          '${f.value > 0 ? '+' : '−'}${f.value.abs().toStringAsFixed(1)}',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: f.value < 0 ? Palette.bad : Palette.ok)),
                    ]),
                  ),
              ]),
            ),
            const SectionTitle('Actions'),
            if (!canAct)
              const Text('Staff changes wait until the shift is over.',
                  style: TextStyle(color: Palette.muted))
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                _act(
                    context,
                    Icons.trending_up,
                    'Raise to ${fmtMoney((s.wage * 1.1).round())}',
                    () => sendCmd(
                        context, SetWage(s.id, (s.wage * 1.1).round()),
                        okText: '${s.name} got a raise.')),
                _act(
                    context,
                    Icons.school,
                    'Train · ${fmtMoney(trainCost)}',
                    () => sendCmd(context, Train(s.id),
                        okText: '${s.name} is on a 2-day course.')),
                if (sim.state.phase == 'prep' && s.workingToday)
                  _act(
                      context,
                      Icons.beach_access,
                      'Day off today',
                      () => sendCmd(context, GiveDayOff(s.id),
                          okText: '${s.name} has today off.')),
                _act(
                    context,
                    Icons.report_gmailerrorred,
                    'Warn',
                    () =>
                        sendCmd(context, Warn(s.id), okText: 'Warning given.')),
                if (sim.state.stage >= 3 &&
                    ['server', 'cashier', 'headChef'].contains(s.role) &&
                    s.skill >= 60)
                  _act(
                      context,
                      Icons.badge,
                      'Make manager',
                      () => sendCmd(context, PromoteToManager(s.id),
                          okText:
                              '${s.name} now manages ${sim.state.viewLoc.name}.')),
                for (final other in sim.state.openLocations
                    .where((x) => x.id != sim.state.viewLocationId))
                  _act(context, Icons.swap_horiz, 'Move to ${other.name}',
                      () async {
                    final ok = await confirm(context, 'Move ${s.name}?',
                        '${s.name} starts at ${other.name} the day after tomorrow and is a bit unsettled for a week.');
                    if (ok &&
                        context.mounted &&
                        sendCmd(context, TransferStaff(s.id, other.id),
                            okText: '${s.name} moves to ${other.name}.')) {
                      Navigator.pop(context);
                    }
                  }),
                if (s.role == 'lineCook')
                  _act(
                      context,
                      Icons.military_tech,
                      'Promote to head chef',
                      () => sendCmd(context, Promote(s.id),
                          okText: '${s.name} is now head chef.')),
                _act(context, Icons.person_remove,
                    'Fire · ${fmtMoney(s.wage * 7)}', () async {
                  final ok = await confirm(context, 'Fire ${s.name}?',
                      'Severance is a week\'s wage (${fmtMoney(s.wage * 7)}). The rest of the team will be shaken for two weeks.',
                      ok: 'Fire');
                  if (ok && context.mounted) {
                    sendCmd(context, Fire(s.id));
                    Navigator.pop(context);
                  }
                }, danger: true),
              ]),
          ]),
    );
  }

  Widget _act(
          BuildContext context, IconData icon, String label, VoidCallback onTap,
          {bool danger = false}) =>
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
            foregroundColor: danger ? Palette.bad : Palette.ink),
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
}

class _DaysOff extends StatelessWidget {
  const _DaysOff();
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final l = sim.state.viewLoc;
    final staff = List<Staff>.of(l.staff)
      ..sort((a, b) =>
          _roleOrder.indexOf(a.role).compareTo(_roleOrder.indexOf(b.role)));
    final canAct = sim.state.phase != 'service';
    return Centered(
      child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                  'The restaurant opens every day. Everyone gets one day off a week. Keep the busy weekend covered and keep people of the same job on different days.',
                  style: TextStyle(color: Palette.muted, height: 1.35)),
            ),
            const SectionTitle('Who is missing on each day'),
            Row(children: [
              for (var d = 0; d < 7; d++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Builder(builder: (context) {
                      final gaps = sim.uncoveredOn(d);
                      return Tooltip(
                        message: gaps.isEmpty
                            ? 'All jobs covered'
                            : 'No ${gaps.join(', ')}',
                        triggerMode: TooltipTriggerMode.tap,
                        child: Container(
                          height: 58,
                          decoration: BoxDecoration(
                            color: gaps.isEmpty
                                ? Palette.accentSoft
                                : Palette.warn.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: d == sim.state.weekday
                                    ? Palette.ink
                                    : Colors.transparent,
                                width: 1.5),
                          ),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(weekdays[d],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12)),
                                Icon(
                                    gaps.isEmpty
                                        ? Icons.check
                                        : Icons.warning_amber_rounded,
                                    size: 16,
                                    color: gaps.isEmpty
                                        ? Palette.ok
                                        : Palette.warn),
                                Text(gaps.isEmpty ? '' : '${gaps.length} gap',
                                    style: const TextStyle(fontSize: 10)),
                              ]),
                        ),
                      );
                    }),
                  ),
                ),
            ]),
            const SectionTitle('Each person\'s day off'),
            for (final s in staff)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Panel(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(AssetCatalog.role(s.role), size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(
                                  '${s.name} · ${sim.role(s.role).toLowerCase()}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700))),
                          if (canAct &&
                              s.dayOff ==
                                  (sim.state.phase == 'close'
                                      ? (sim.state.weekday + 1) % 7
                                      : sim.state.weekday))
                            TextButton(
                              onPressed: () => sendCmd(
                                  context, WorkDayOff(s.id),
                                  okText:
                                      '${s.name} will work their day off (paid ×1.5).'),
                              child: const Text('Ask to work'),
                            ),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          for (var d = 0; d < 7; d++)
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 1.5),
                                child: Material(
                                  color: s.dayOff == d
                                      ? Palette.accent
                                      : Palette.surface2,
                                  borderRadius: BorderRadius.circular(8),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: canAct && s.dayOff != d
                                        ? () =>
                                            sendCmd(context, SetDayOff(s.id, d))
                                        : null,
                                    child: SizedBox(
                                      height: 34,
                                      child: Center(
                                        child: Text(
                                          '${weekdays[d].substring(0, 2)}${s.preferredKnown && s.preferredDayOff == d ? '♥' : ''}',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: s.dayOff == d
                                                  ? Colors.white
                                                  : Palette.ink),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ]),
                      ]),
                ),
              ),
          ]),
    );
  }
}

class _Hire extends StatelessWidget {
  const _Hire();
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final apps = sim.state.applicants;
    final canAct = sim.state.phase != 'service';
    return Centered(
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const Text(
                'New people apply every Sunday. You only see a rough skill range until they have worked a week.',
                style: TextStyle(color: Palette.muted, height: 1.35)),
            const SizedBox(height: 10),
            if (apps.isEmpty)
              const EmptyNote('No applicants this week. More on Sunday.',
                  icon: Icons.hourglass_empty),
            for (final a in apps)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: StaffRow(
                  staff: a,
                  trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Money(a.askingWage, size: 13),
                        const SizedBox(height: 4),
                        FilledButton(
                          style: FilledButton.styleFrom(
                              minimumSize: const Size(72, 36)),
                          onPressed: canAct
                              ? () => sendCmd(context, Hire(a.id),
                                  okText: '${a.name} joins the team.')
                              : null,
                          child: const Text('Hire'),
                        ),
                      ]),
                ),
              ),
          ]),
    );
  }
}

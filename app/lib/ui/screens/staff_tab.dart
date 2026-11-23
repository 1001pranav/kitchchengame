import 'package:flutter/material.dart';
import 'package:sim_core/sim_core.dart';

import '../theme.dart';
import '../scene/pictures.dart';
import '../widgets/common.dart';
import '../widgets/ledger.dart';

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
        const GameTabBar(tabs: [
          Tab(text: 'Team'),
          Tab(text: 'Days off'),
          Tab(text: 'Hire')
        ]),
        const Expanded(
            child: TabBarView(children: [_TeamList(), _DaysOff(), _Hire()])),
      ]),
    );
  }
}

class _TeamList extends StatelessWidget {
  const _TeamList();
  static const _sections = [
    ('Kitchen', ['headChef', 'lineCook', 'prepCook']),
    ('Floor', ['server', 'cashier']),
    ('Back of house', ['dishwasher', 'cleaner']),
  ];
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final st = sim.state;
    final l = st.viewLoc;
    final hap = sim.outletHappiness();
    final staff = List<Staff>.of(l.staff)
      ..sort((a, b) =>
          _roleOrder.indexOf(a.role).compareTo(_roleOrder.indexOf(b.role)));
    final wages = l.staff.fold<int>(0, (a, s) => a + s.wage);
    final onShift = l.staff.where((s) => s.workingToday).length;
    final atRisk = l.staff.where((s) => s.morale < 30 || s.status == 'notice');
    final managers = staff.where((s) => s.isManager).toList();
    return Centered(
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 14, 2, 14),
              child: Row(children: [
                RingGauge(hap, size: 58),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('THE BRIGADE',
                            style: TextStyle(
                                color: Palette.accent,
                                fontSize: 10.5,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(_mood(hap),
                            style: const TextStyle(
                                fontFamily: displayFont,
                                fontSize: 22,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        TermText(
                            'Team happiness ${hap.round()} of 100', 'morale',
                            style: const TextStyle(
                                color: Palette.muted, fontSize: 12.5)),
                      ]),
                ),
              ]),
            ),
            StatStrip(items: [
              StatItem('ON SHIFT', '$onShift/${l.staff.length}', 'today'),
              StatItem('WAGES', fmtMoney(wages), 'per day'),
              StatItem('AT RISK', '${atRisk.length}', 'may leave',
                  color: atRisk.isEmpty ? null : Palette.bad),
            ]),
            if (managers.isNotEmpty) ...[
              const SectionTitle('Manager'),
              LedgerGroup(padding: EdgeInsets.zero, children: [
                for (final s in managers)
                  StaffRow(
                      staff: s,
                      grouped: true,
                      onTap: () => showStaffDetail(context, s.id)),
              ]),
            ],
            for (final (title, roles) in _sections)
              if (staff.any((s) => !s.isManager && roles.contains(s.role))) ...[
                SectionTitle(title,
                    trailing: Text(
                        '${staff.where((s) => !s.isManager && roles.contains(s.role)).length}',
                        style: const TextStyle(
                            color: Palette.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700))),
                LedgerGroup(padding: EdgeInsets.zero, children: [
                  for (final s in staff
                      .where((s) => !s.isManager && roles.contains(s.role)))
                    StaffRow(
                        staff: s,
                        grouped: true,
                        onTap: () => showStaffDetail(context, s.id)),
                ]),
              ],
          ]),
    );
  }

  static String _mood(double h) => h >= 75
      ? 'A happy kitchen'
      : h >= 55
          ? 'Steady'
          : h >= 40
              ? 'Grumbling'
              : 'Close to walking out';
}

class StaffRow extends StatelessWidget {
  final Staff staff;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Inside a [LedgerGroup]: no card of its own.
  final bool grouped;
  const StaffRow(
      {super.key,
      required this.staff,
      this.onTap,
      this.trailing,
      this.grouped = false});
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
    } else if (s.morale < 30) {
      status = 'may leave';
      sc = Palette.bad;
    } else if (s.trainingUntil > st.dayIndex) {
      status = 'training';
      sc = Palette.staff;
    } else if (s.absentToday || s.absentUntil > st.dayIndex) {
      status = 'absent';
      sc = Palette.bad;
    } else if (st.phase != 'close' && s.workingToday) {
      status = 'on shift';
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
    final energy = (100 - s.fatigue) / 100;
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(children: [
        StaffAvatar(
            seed: s.id,
            name: s.name,
            role: s.isManager ? 'manager' : s.role,
            size: 46,
            morale: s.morale),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 2),
            Row(children: [
              Flexible(
                child: Text(sim.role(s.role),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Palette.muted, fontSize: 12.5)),
              ),
              if (status.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(child: StateDot(status, color: sc)),
              ],
            ]),
            const SizedBox(height: 7),
            Row(children: [
              const Text('ENERGY',
                  style: TextStyle(
                      color: Palette.muted,
                      fontSize: 8.5,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Flexible(
                  child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 54),
                child: Meter(energy,
                    color: energy < 0.3
                        ? Palette.bad
                        : (energy < 0.5 ? Palette.warn : Palette.owner)),
              )),
            ]),
          ]),
        ),
        const SizedBox(width: 10),
        trailing ??
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(skillText,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()])),
              const Text('SKILL',
                  style: TextStyle(
                      color: Palette.muted,
                      fontSize: 8.5,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              Text('${fmtMoney(s.wage)}/day',
                  style: const TextStyle(color: Palette.muted, fontSize: 11.5)),
            ]),
      ]),
    );
    if (grouped) {
      return Material(
          type: MaterialType.transparency,
          child: InkWell(onTap: onTap, child: row));
    }
    return Panel(onTap: onTap, padding: EdgeInsets.zero, child: row);
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
              StaffAvatar(
                  seed: s.id,
                  name: s.name,
                  role: s.isManager ? 'manager' : s.role,
                  size: 60,
                  morale: s.morale),
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
              RingGauge(s.morale, size: 48),
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
                                          '${weekdays[d].substring(0, 2)}${s.preferredKnown && s.preferredDayOff == d ? '*' : ''}',
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

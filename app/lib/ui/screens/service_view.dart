import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sim_core/sim_core.dart';

import '../../state/game_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'prep_board.dart';
import '../scene/restaurant_scene.dart';

/// The live restaurant (doc 07 §4.4). Drawn with widgets instead of Flame (see README).
class ServiceView extends StatefulWidget {
  const ServiceView({super.key});
  @override
  State<ServiceView> createState() => _ServiceViewState();
}

class _ServiceViewState extends State<ServiceView> {
  int? selectedGroup;

  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final ss = sim.service;
    if (ss == null) return const SizedBox();
    if (ss.tables.isEmpty) {
      // Closed today (fit-out, inspection, nobody to run it): nothing to watch.
      final why = sim.state.viewLoc.today.events
          .where((e) => e.kind == 'closed' || e.kind == 'building')
          .map((e) => e.text)
          .firstOrNull;
      return SingleChildScrollView(
          child: Centered(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.door_front_door_outlined,
                size: 56, color: Palette.muted),
            const SizedBox(height: 10),
            Text('${sim.state.viewLoc.name} is closed today',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(why ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Palette.muted)),
          ]),
        ),
      ));
    }
    final sel = ss.group(selectedGroup);
    if (sel != null && sel.gone) selectedGroup = null;
    final room = RestaurantScene(
      ss: ss,
      selectedGroup: selectedGroup,
      onSelect: (g) =>
          setState(() => selectedGroup = g == selectedGroup ? null : g),
    );
    final controls = _Controls(
        ss: ss,
        selectedGroup: selectedGroup,
        onClear: () => setState(() => selectedGroup = null));
    return LayoutBuilder(builder: (context, box) {
      // Small screens or large text: the scene keeps its full height and the page scrolls.
      if (box.maxHeight < 600) {
        return SingleChildScrollView(
          child: Column(children: [
            _ClockBar(ss: ss),
            SizedBox(
                height: RestaurantScene.neededHeight(
                    box.maxWidth, ss.tables.length),
                child: room),
            controls,
          ]),
        );
      }
      return Column(children: [
        _ClockBar(ss: ss),
        Expanded(child: room),
        controls,
      ]);
    });
  }
}

// ------------------------------------------------------------------ top line

class _ClockBar extends StatelessWidget {
  final ServiceState ss;
  const _ClockBar({required this.ss});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final over = ss.lost > ss.target;
    Widget sp(Speed s, IconData icon, String tip, {bool enabled = true}) =>
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Tooltip(
            message: tip,
            child: Material(
              color: c.speed == s ? Palette.accent : Palette.surface2,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: enabled
                    ? () => c.setSpeed(s)
                    : () => showToast(
                        context, 'Fast-forward needs every job covered today.'),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(icon,
                      size: 22,
                      color: c.speed == s
                          ? Colors.white
                          : (enabled
                              ? Palette.ink
                              : Palette.muted.withValues(alpha: 0.4))),
                ),
              ),
            ),
          ),
        );
    return Container(
      color: Palette.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
      child: Column(children: [
        Row(children: [
          Text(sim.clock(math.min(ss.tick, 390)),
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: c.quietSpell &&
                      c.speed != Speed.paused &&
                      c.settings.quietFastForward
                  ? const Pill('quiet ×4',
                      color: Palette.muted, icon: Icons.fast_forward)
                  : const SizedBox(),
            ),
          ),
          sp(Speed.paused, Icons.pause, 'Pause'),
          sp(Speed.normal, Icons.play_arrow, 'Normal speed'),
          sp(Speed.fast, Icons.fast_forward, 'Double speed'),
          sp(Speed.auto, Icons.double_arrow, 'Fast-forward (every job covered)',
              enabled: sim.canAutoRun),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
              child: StatBar(ss.tick / 360, color: Palette.accent, height: 6)),
          const SizedBox(width: 10),
          Flexible(
              child:
                  Money(sim.state.viewLoc.today.revenue, size: 14, sign: true)),
          const SizedBox(width: 10),
          Semantics(
            label: 'Lost ${ss.lost} of target ${ss.target}',
            child: GestureDetector(
              onTap: () => showTerm(context, 'shift_target'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: over ? Palette.bad : Palette.line),
                  borderRadius: BorderRadius.circular(8),
                  color: over ? Palette.bad.withValues(alpha: 0.08) : null,
                ),
                child: Row(children: [
                  Icon(Icons.flag,
                      size: 14, color: over ? Palette.bad : Palette.muted),
                  const SizedBox(width: 3),
                  Text('${ss.lost}/${ss.target}',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: over ? Palette.bad : Palette.ink)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => showTerm(context, 'favour'),
            child: Row(children: [
              for (var i = 0; i < 3; i++)
                Container(
                  margin: const EdgeInsets.only(left: 3),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < ss.favours ? Palette.owner : Colors.transparent,
                    border: Border.all(color: Palette.owner, width: 2),
                  ),
                ),
            ]),
          ),
        ]),
      ]),
    );
  }
}

// ------------------------------------------------------------------ owner controls

class _Controls extends StatelessWidget {
  final ServiceState ss;
  final int? selectedGroup;
  final VoidCallback onClear;
  const _Controls(
      {required this.ss, required this.selectedGroup, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final g = ss.group(selectedGroup);
    final present = sim.ownerPresent;
    final floor = sim.state.viewLoc.staff
        .where((s) => s.workingToday && floorRoles.contains(s.role))
        .toList();
    final waitOrder = ss.groups.where((x) => x.state == 'waitOrder').length;
    final waitFood = ss.groups.where((x) => x.state == 'waitFood').length;
    final waitBill = ss.groups.where((x) => x.state == 'waitBill').length;
    final atDoor = ss.groups.where((x) => x.state == 'waitTable').length;
    return Container(
      decoration: const BoxDecoration(
          color: Palette.surface,
          border: Border(top: BorderSide(color: Palette.line))),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!present)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                    'You are resting today. Watch how the team copes without you.',
                    style: TextStyle(
                        color: Palette.owner, fontWeight: FontWeight.w700)),
              ),
            // Selected party.
            SizedBox(
              height: 44,
              child: g == null || g.gone
                  ? Row(children: [
                      const Icon(Icons.touch_app,
                          size: 18, color: Palette.muted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Waiting: door $atDoor · order $waitOrder · food $waitFood · bill $waitBill',
                          style: const TextStyle(
                              color: Palette.muted,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ])
                  : Row(children: [
                      Expanded(
                        child: Text(
                          '${g.tableId != null && g.state != 'waitTable' ? 'T${g.tableId}' : 'Door'} · ${g.size}p',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      _ActBtn(
                        label: 'Rush',
                        icon: Icons.bolt,
                        enabled: present &&
                            g.state == 'waitFood' &&
                            !g.rushed &&
                            ss.favours > 0,
                        onTap: () => sendCmd(context, OwnerRush(g.id)),
                        term: 'rush',
                      ),
                      _ActBtn(
                        label: 'Treat 8',
                        icon: Icons.local_cafe,
                        enabled: present &&
                            g.waiting &&
                            !g.treated &&
                            ss.favours > 0,
                        onTap: () => sendCmd(context, OwnerTreat(g.id)),
                        term: 'treat',
                      ),
                      _ActBtn(
                        label: 'Bill',
                        icon: Icons.receipt,
                        enabled: present &&
                            g.state == 'eating' &&
                            !g.broughtBill &&
                            g.eatUntil - ss.tick > 3,
                        onTap: () => sendCmd(context, OwnerBringBill(g.id)),
                        term: 'bring_the_bill',
                      ),
                      IconButton(
                          onPressed: onClear,
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: 'Deselect'),
                    ]),
            ),
            const SizedBox(height: 6),
            // Stand row.
            Row(children: [
              const SizedBox(
                  width: 46,
                  child: TermText('Stand', 'area',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Palette.muted))),
              for (final a in areaLabels.keys)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Material(
                      color:
                          ss.ownerArea == a ? Palette.owner : Palette.surface2,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: present
                            ? () => sendCmd(context,
                                OwnerStand(ss.ownerArea == a ? null : a))
                            : null,
                        child: SizedBox(
                          height: 44,
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(areaIcons[a],
                                    size: 16,
                                    color: ss.ownerArea == a
                                        ? Colors.white
                                        : Palette.ink),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                      a == 'door' ? 'Door' : areaLabels[a]!,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: ss.ownerArea == a
                                              ? Colors.white
                                              : Palette.ink)),
                                ),
                              ]),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 6),
            // Team row.
            SizedBox(
              height: 42,
              child: Row(children: [
                const SizedBox(
                    width: 46,
                    child: Text('TEAM',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Palette.muted))),
                Expanded(
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (final s in floor)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _TeamChip(
                            staff: s, role: ss.moves['${s.id}'] ?? s.role),
                      ),
                  ]),
                ),
              ]),
            ),
          ]),
    );
  }
}

class _ActBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final String term;
  const _ActBtn(
      {required this.label,
      required this.icon,
      required this.enabled,
      required this.onTap,
      required this.term});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: GestureDetector(
        onLongPress: () => showTerm(context, term),
        child: FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            backgroundColor: Palette.owner.withValues(alpha: 0.12),
            foregroundColor: Palette.owner,
          ),
          onPressed: enabled ? onTap : null,
          icon: Icon(icon, size: 16),
          label: Text(label, style: const TextStyle(fontSize: 13)),
        ),
      ),
    );
  }
}

class _TeamChip extends StatelessWidget {
  final Staff staff;
  final String role;
  const _TeamChip({required this.staff, required this.role});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final moved = role != staff.role;
    return Material(
      color: Palette.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
            color: moved ? Palette.warn : Colors.transparent, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          final i = floorRoles.indexOf(role);
          final next = floorRoles[(i + 1) % floorRoles.length];
          sendCmd(context, MoveStaff(staff.id, next));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            Icon(AssetCatalog.role(role), size: 16),
            const SizedBox(width: 4),
            Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(staff.name.split(' ').first,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.1)),
                  Text(c.sim!.role(role).toLowerCase(),
                      style: TextStyle(
                          fontSize: 10,
                          height: 1.1,
                          color: moved ? Palette.warn : Palette.muted)),
                ]),
          ]),
        ),
      ),
    );
  }
}

const stationNames = {
  'stove': 'Hob',
  'oven': 'Ovens',
  'cold': 'Cold',
  'wok': 'Woks',
  'grill': 'Grill',
  'fryer': 'Fryer',
  'tandoor': 'Tandoor',
};
const stationIcons = {
  'stove': Icons.local_fire_department,
  'oven': Icons.microwave,
  'cold': Icons.kitchen,
  'wok': Icons.ramen_dining,
  'grill': Icons.outdoor_grill,
  'fryer': Icons.set_meal,
  'tandoor': Icons.fireplace,
};

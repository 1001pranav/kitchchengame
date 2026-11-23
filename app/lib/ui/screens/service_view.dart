import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sim_core/sim_core.dart';

import '../../state/game_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../opening_goal.dart';
import 'prep_board.dart';
import '../widgets/juice.dart';
import '../scene/pictures.dart';
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
    final goal =
        OpeningGoal.of(sim, forecast: sim.state.viewLoc.today.forecast);
    final goalStrip = goal == null
        ? const SizedBox.shrink()
        : _GoalStrip(goal: goal, served: sim.state.viewLoc.today.groupsServed);
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
            goalStrip,
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
        goalStrip,
        Expanded(child: room),
        controls,
      ]);
    });
  }
}

// ------------------------------------------------------------------ top line

/// Opening night only: parties served against the goal, live.
class _GoalStrip extends StatefulWidget {
  final OpeningGoal goal;
  final int served;
  const _GoalStrip({required this.goal, required this.served});
  @override
  State<_GoalStrip> createState() => _GoalStripState();
}

class _GoalStripState extends State<_GoalStrip> {
  late bool _wasMet = widget.goal.met(widget.served);

  @override
  void didUpdateWidget(_GoalStrip old) {
    super.didUpdateWidget(old);
    final met = widget.goal.met(widget.served);
    if (met && !_wasMet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showToast(context, 'Opening-night goal met. Keep them coming.',
              bad: false);
        }
      });
    }
    _wasMet = met;
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.goal;
    final met = g.met(widget.served);
    final k = (widget.served / g.parties).clamp(0.0, 1.0);
    final col = met ? Palette.accent : Palette.ink;
    return Semantics(
      label:
          'Opening night goal: ${widget.served} of ${g.parties} parties served',
      child: Container(
        color: const Color(0xFF171410),
        padding: const EdgeInsets.fromLTRB(14, 7, 14, 8),
        child: Row(children: [
          Text(met ? 'GOAL MET' : 'OPENING NIGHT',
              style: TextStyle(
                  color: met ? Palette.accent : Palette.muted,
                  fontSize: 9,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Stack(children: [
                Container(height: 4, color: Palette.line),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: k),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => FractionallySizedBox(
                    widthFactor: v,
                    child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Palette.accent.withValues(alpha: 0.6),
                            Palette.accent
                          ]),
                        )),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: '${widget.served}',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13, color: col)),
                TextSpan(
                    text: ' / ${g.parties}',
                    style: const TextStyle(
                        color: Palette.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ]),
              style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()])),
        ]),
      ),
    );
  }
}

class _ClockBar extends StatelessWidget {
  final ServiceState ss;
  const _ClockBar({required this.ss});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final over = ss.lost > ss.target;
    final speeds = [
      (Speed.paused, Icons.pause, 'Pause', true),
      (Speed.normal, Icons.play_arrow, 'Normal speed', true),
      (Speed.fast, Icons.fast_forward, 'Double speed', true),
      (
        Speed.auto,
        Icons.double_arrow,
        'Fast-forward (every job covered)',
        sim.canAutoRun
      ),
    ];
    const label = TextStyle(
        color: Palette.muted,
        fontSize: 9,
        letterSpacing: 1.6,
        fontWeight: FontWeight.w600);
    return Container(
      color: const Color(0xFF0E0C0A),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sim.clock(math.min(ss.tick, 390)),
                  style: const TextStyle(
                      fontSize: 24,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()])),
              const SizedBox(height: 3),
              c.quietSpell &&
                      c.speed != Speed.paused &&
                      c.settings.quietFastForward
                  ? const Text('QUIET · ×4',
                      style: TextStyle(
                          color: Palette.accent,
                          fontSize: 9,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w600))
                  : const Text('SERVICE', style: label),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Takings tonight.
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TAKINGS', style: label),
                            const SizedBox(height: 2),
                            RollingMoney(sim.state.viewLoc.today.revenue,
                                size: 15, sign: true),
                          ]),
                      const SizedBox(width: 12),
                      // Parties lost against tonight's target.
                      Semantics(
                        label: 'Lost ${ss.lost} of target ${ss.target}',
                        child: GestureDetector(
                          onTap: () => showTerm(context, 'shift_target'),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('LOST',
                                    style: label.copyWith(
                                        color: over
                                            ? Palette.bad
                                            : Palette.muted)),
                                const SizedBox(height: 2),
                                Text('${ss.lost}/${ss.target}',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            over ? Palette.bad : Palette.ink)),
                              ]),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Favours: rush or treat a table.
                      GestureDetector(
                        onTap: () => showTerm(context, 'favour'),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('FAVOURS', style: label),
                              const SizedBox(height: 5),
                              Row(children: [
                                for (var i = 0; i < 3; i++)
                                  Container(
                                    margin: const EdgeInsets.only(right: 4),
                                    width: 8,
                                    height: 8,
                                    transform: Matrix4.rotationZ(math.pi / 4),
                                    transformAlignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: i < ss.favours
                                          ? Palette.accent
                                          : Colors.transparent,
                                      border: Border.all(
                                          color: Palette.accent, width: 1.2),
                                    ),
                                  ),
                              ]),
                            ]),
                      ),
                    ]),
              ),
            ),
            const SizedBox(width: 8),
            // Speed: one segmented control.
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Palette.line),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(children: [
                for (final (sp, icon, tip, enabled) in speeds)
                  Tooltip(
                    message: tip,
                    child: InkWell(
                      onTap: enabled
                          ? () => c.setSpeed(sp)
                          : () => showToast(context,
                              'Fast-forward needs every job covered today.'),
                      child: Container(
                        width: 32,
                        height: 34,
                        color:
                            c.speed == sp ? Palette.accent : Colors.transparent,
                        child: Icon(icon,
                            size: 18,
                            color: c.speed == sp
                                ? Palette.onAccent
                                : (enabled
                                    ? Palette.ink
                                    : Palette.muted.withValues(alpha: 0.4))),
                      ),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
        // The evening, as a hairline that fills.
        Stack(children: [
          Container(height: 2, color: Palette.line),
          FractionallySizedBox(
            widthFactor: (ss.tick / 360).clamp(0.0, 1.0),
            child: Container(height: 2, color: Palette.accent),
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
          color: Color(0xFF0E0C0A),
          border: Border(top: BorderSide(color: Palette.line))),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
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
                  ? (sim.state.dayIndex < 3 && present
                      ? const Row(children: [
                          Icon(Icons.touch_app_outlined,
                              size: 16, color: Palette.accent),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tap the floor to walk there. Tap a bubble to do that job yourself.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Palette.muted, fontSize: 12.5),
                            ),
                          ),
                        ])
                      : Row(children: [
                          for (final (k, n) in [
                            ('AT DOOR', atDoor),
                            ('TO ORDER', waitOrder),
                            ('FOR FOOD', waitFood),
                            ('FOR BILL', waitBill),
                          ])
                            Expanded(
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('$n',
                                        style: TextStyle(
                                            fontSize: 16,
                                            height: 1.1,
                                            fontWeight: FontWeight.w700,
                                            color: n > 2
                                                ? Palette.warn
                                                : Palette.ink)),
                                    Text(k,
                                        maxLines: 1,
                                        style: const TextStyle(
                                            color: Palette.muted,
                                            fontSize: 8.5,
                                            letterSpacing: 1.2,
                                            fontWeight: FontWeight.w600)),
                                  ]),
                            ),
                        ]))
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
                  child: TermText('POST', 'area',
                      style: TextStyle(
                          fontSize: 9.5,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w700,
                          color: Palette.muted))),
              for (final a in areaLabels.keys)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Material(
                      color: ss.ownerArea == a
                          ? const Color(0xFF16302F)
                          : Palette.surface,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                              color: ss.ownerArea == a
                                  ? Palette.owner
                                  : Palette.line)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
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
                                        ? Palette.owner
                                        : Palette.muted),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(areaLabels[a]!.toUpperCase(),
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 9.5,
                                          letterSpacing: 1,
                                          fontWeight: FontWeight.w700,
                                          color: ss.ownerArea == a
                                              ? Palette.ink
                                              : Palette.muted)),
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
                            fontSize: 9.5,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w700,
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
            backgroundColor: const Color(0xFF16302F),
            foregroundColor: const Color(0xFF8FD3DE),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Palette.owner)),
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
      color: Palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: moved ? Palette.warn : Palette.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          final i = floorRoles.indexOf(role);
          final next = floorRoles[(i + 1) % floorRoles.length];
          sendCmd(context, MoveStaff(staff.id, next));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            StaffAvatar(
                seed: staff.id,
                name: staff.name,
                role: role,
                size: 26,
                morale: staff.morale),
            const SizedBox(width: 8),
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

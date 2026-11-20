import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sim_core/sim_core.dart';

import '../../state/game_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'prep_board.dart';

/// The live restaurant (doc 07 §4.4). Drawn with widgets instead of Flame (see README).
class ServiceView extends StatefulWidget {
  const ServiceView({super.key});
  @override
  State<ServiceView> createState() => _ServiceViewState();
}

class _Float {
  final int tableId;
  final String text;
  final Color color;
  final DateTime at;
  _Float(this.tableId, this.text, this.color) : at = DateTime.now();
}

class _ServiceViewState extends State<ServiceView> {
  int? selectedGroup;
  StreamSubscription<SimEvent>? _sub;
  final List<_Float> floats = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub ??= GameScope.read(context).events.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onEvent(SimEvent e) {
    if (!mounted) return;
    final c = GameScope.read(context);
    if (c.settings.reducedMotion) return;
    if (e.type == 'groupPaid' && e.args['tableId'] != null) {
      floats.add(
          _Float(e.args['tableId'] as int, '+${e.args['amount']}', Palette.ok));
    } else if (e.type == 'groupWalkedOut' &&
        e.args['tableId'] != null &&
        e.args['from'] != 'waitTable') {
      floats.add(_Float(e.args['tableId'] as int, 'walked out', Palette.bad));
    }
    floats.removeWhere(
        (f) => DateTime.now().difference(f.at).inMilliseconds > 1400);
  }

  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final ss = sim.service;
    if (ss == null) return const SizedBox();
    final sel = ss.group(selectedGroup);
    if (sel != null && sel.gone) selectedGroup = null;
    final room = Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: _Room(
        ss: ss,
        selectedGroup: selectedGroup,
        floats: floats,
        onSelect: (g) =>
            setState(() => selectedGroup = g == selectedGroup ? null : g),
      ),
    );
    final controls = _Controls(
        ss: ss,
        selectedGroup: selectedGroup,
        onClear: () => setState(() => selectedGroup = null));
    return LayoutBuilder(builder: (context, box) {
      // Small screens or large text: the room keeps a usable height and the page scrolls.
      if (box.maxHeight < 600) {
        return SingleChildScrollView(
          child: Column(children: [
            _ClockBar(ss: ss),
            _KitchenStrip(ss: ss),
            SizedBox(height: 300, child: room),
            controls,
          ]),
        );
      }
      return Column(children: [
        _ClockBar(ss: ss),
        _KitchenStrip(ss: ss),
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
          Flexible(child: Money(sim.state.today.revenue, size: 14, sign: true)),
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

// ------------------------------------------------------------------ kitchen strip

class _KitchenStrip extends StatelessWidget {
  final ServiceState ss;
  const _KitchenStrip({required this.ss});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final stations = sim.content.themes[sim.state.themeId]!.stations;
    final cookTasks = ss.tasks.where((k) => k.type == 'cook').toList();
    int inUse(String st) => cookTasks
        .where((k) =>
            k.started &&
            sim.content.dishes[ss.ticket(k.ticketId)!.dishId]!.station == st)
        .length;
    int queued(String st) => cookTasks
        .where((k) =>
            !k.started &&
            sim.content.dishes[ss.ticket(k.ticketId)!.dishId]!.station == st)
        .length;
    final plateCap =
        sim.content.balance.i('PLATES_PER_TABLE') * ss.tables.length;
    final dirtyShare = ss.dirtyDishes / plateCap;
    final ready = ss.groups
        .where((g) =>
            g.state == 'waitFood' &&
            g.ticketIds
                .map(ss.ticket)
                .whereType<Ticket>()
                .where((t) => t.state != 'cancel')
                .every((t) => t.state == 'ready'))
        .length;
    return Container(
      color: Palette.kitchen,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Builder(builder: (context) {
            Widget tile(String st) => _StationTile(
                  name: stationNames[st] ?? st,
                  icon: stationIcons[st] ?? Icons.local_fire_department,
                  cap: sim.stationCapacity(st),
                  used: inUse(st),
                  queued: queued(st),
                  down: sim.stationDown(st),
                );
            if (stations.length <= 3) {
              return Row(children: [
                for (final st in stations) Expanded(child: tile(st))
              ]);
            }
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final st in stations) SizedBox(width: 82, child: tile(st))
              ]),
            );
          }),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.wash,
                          size: 14,
                          color: dirtyShare > 1
                              ? const Color(0xFFFF8A75)
                              : Colors.white70),
                      const SizedBox(width: 3),
                      const Flexible(
                          child: Text('Plates',
                              overflow: TextOverflow.clip,
                              maxLines: 1,
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700))),
                    ]),
                    const SizedBox(height: 6),
                    StatBar(dirtyShare,
                        color: dirtyShare > 0.8
                            ? Palette.bad
                            : (dirtyShare > 0.5 ? Palette.warn : Palette.ok),
                        height: 6),
                    const SizedBox(height: 4),
                    Text(
                        dirtyShare > 1
                            ? 'no clean plates!'
                            : '${(dirtyShare * 100).round()}% dirty',
                        style: TextStyle(
                            color: dirtyShare > 1
                                ? const Color(0xFFFF8A75)
                                : Colors.white60,
                            fontSize: 10.5)),
                  ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 3),
          child: Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
                color: Palette.gold.withValues(alpha: ready > 0 ? 0.35 : 0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              const Icon(Icons.room_service, size: 16, color: Colors.white),
              Text('$ready',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15)),
              const Text('pass',
                  style: TextStyle(color: Colors.white70, fontSize: 10)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _StationTile extends StatelessWidget {
  final String name;
  final IconData icon;
  final int cap, used, queued;
  final bool down;
  const _StationTile(
      {required this.name,
      required this.icon,
      required this.cap,
      required this.used,
      required this.queued,
      required this.down});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Container(
        clipBehavior: Clip.hardEdge,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: down
              ? Palette.bad.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: down
                  ? const Color(0xFFFF8A75)
                  : (queued > 3 ? Palette.warn : Colors.transparent)),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Icon(icon, size: 14, color: Colors.white70),
                const SizedBox(width: 3),
                Flexible(
                    child: Text(name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 5),
              if (down)
                const Text('DOWN',
                    style: TextStyle(
                        color: Color(0xFFFF8A75),
                        fontWeight: FontWeight.w900,
                        fontSize: 12))
              else
                Wrap(spacing: 3, runSpacing: 3, children: [
                  for (var i = 0; i < cap; i++)
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < used
                            ? const Color(0xFFFFB25B)
                            : Colors.transparent,
                        border: Border.all(
                            color: i < used
                                ? const Color(0xFFFFB25B)
                                : Colors.white38,
                            width: 1.5),
                      ),
                    ),
                ]),
              const SizedBox(height: 3),
              Text(queued == 0 ? 'no queue' : '$queued waiting',
                  style: TextStyle(
                      color:
                          queued > 3 ? const Color(0xFFFFC56B) : Colors.white60,
                      fontSize: 10.5)),
            ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ dining room

Color patienceColor(double share) =>
    share < 0.5 ? Palette.ok : (share < 0.8 ? Palette.warn : Palette.bad);

class _Room extends StatelessWidget {
  final ServiceState ss;
  final int? selectedGroup;
  final List<_Float> floats;
  final void Function(int groupId) onSelect;
  const _Room(
      {required this.ss,
      required this.selectedGroup,
      required this.floats,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final queue = ss.groups.where((g) => g.state == 'waitTable').toList();
    return Container(
      decoration: BoxDecoration(
        color: Palette.floor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.line),
      ),
      child: Column(children: [
        // Door queue lane.
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: Palette.line, style: BorderStyle.solid))),
          child: Row(children: [
            const Icon(Icons.door_front_door, color: Palette.muted, size: 20),
            const SizedBox(width: 4),
            Text(queue.isEmpty ? 'Nobody waiting' : 'Door',
                style: const TextStyle(
                    color: Palette.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
            const SizedBox(width: 6),
            Expanded(
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final g in queue)
                  Padding(
                    padding: const EdgeInsets.only(right: 6, top: 6, bottom: 6),
                    child: _QueueChip(
                        group: g,
                        selected: g.id == selectedGroup,
                        onTap: () => onSelect(g.id),
                        sim: sim,
                        ss: ss),
                  ),
              ]),
            ),
          ]),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            final n = ss.tables.length;
            final cols = n <= 12 ? 4 : (n <= 20 ? 5 : 6);
            final rows = (n / cols).ceil();
            const pad = 6.0;
            final w = (box.maxWidth - pad * (cols + 1)) / cols;
            final h = math.max(40.0, (box.maxHeight - pad * (rows + 1)) / rows);
            Rect rectOf(int tableId) {
              final i = tableId - 1;
              final col = i % cols, row = i ~/ cols;
              return Rect.fromLTWH(
                  pad + col * (w + pad), pad + row * (h + pad), w, h);
            }

            final figures =
                _figures(sim, ss, rectOf, box.maxWidth, box.maxHeight);
            return SingleChildScrollView(
              child: SizedBox(
                height: math.max(box.maxHeight, pad + rows * (h + pad)),
                child: Stack(clipBehavior: Clip.none, children: [
                  for (final t in ss.tables)
                    Positioned.fromRect(
                      rect: rectOf(t.id),
                      child: _TableTile(
                          table: t,
                          ss: ss,
                          sim: sim,
                          selected:
                              t.groupId != null && t.groupId == selectedGroup,
                          onSelect: onSelect),
                    ),
                  for (final f in figures)
                    AnimatedPositioned(
                      key: ValueKey(f.id),
                      duration: Duration(
                          milliseconds: c.settings.reducedMotion ? 0 : 450),
                      curve: Curves.easeInOut,
                      left: f.pos.dx - f.size / 2,
                      top: f.pos.dy - f.size / 2,
                      child: IgnorePointer(child: _Figure(f: f)),
                    ),
                  for (final fl in floats)
                    if (ss.table(fl.tableId) != null)
                      Positioned(
                        left: rectOf(fl.tableId).left,
                        width: rectOf(fl.tableId).width,
                        top: rectOf(fl.tableId).top - 6,
                        child: IgnorePointer(child: _FloatLabel(f: fl)),
                      ),
                ]),
              ),
            );
          }),
        ),
      ]),
    );
  }

  List<_Fig> _figures(Sim sim, ServiceState ss, Rect Function(int) rectOf,
      double width, double height) {
    final out = <_Fig>[];
    final rnd = math.Random(7);
    Offset home(String role, int i) {
      final x = switch (role) {
        'cashier' => 18.0,
        'server' => width * 0.5 + i * 22,
        'cleaner' => width - 22,
        'dishwasher' => width - 22,
        _ => width * 0.3,
      };
      final y = switch (role) {
        'cashier' => 14.0,
        'dishwasher' => 14.0,
        _ => height - 16,
      };
      return Offset(x, y);
    }

    var serverIndex = 0;
    for (final s in sim.state.loc.staff) {
      if (!s.workingToday || s.lateTick > ss.tick) continue;
      final role = ss.moves['${s.id}'] ?? s.role;
      if (role == 'headChef' || role == 'lineCook' || role == 'prepCook') {
        continue; // they live in the kitchen strip
      }
      Task? task;
      for (final k in ss.tasks) {
        if (k.assignee == '${s.id}') task = k;
      }
      Offset pos = home(role, role == 'server' ? serverIndex++ : 0);
      if (task?.tableId != null && ss.table(task!.tableId) != null) {
        final r = rectOf(task.tableId!);
        pos = Offset(r.left + 10 + rnd.nextDouble() * 8, r.bottom - 10);
      } else if (task?.type == 'seat') {
        pos = const Offset(30, 10);
      }
      out.add(_Fig('s${s.id}', pos, Palette.staff, s.name.substring(0, 1), 22,
          moved: ss.moves.containsKey('${s.id}')));
    }
    if (sim.ownerPresent) {
      Task? ot;
      for (final k in ss.tasks) {
        if (k.assignee == 'owner') ot = k;
      }
      var pos = switch (ss.ownerArea) {
        'door' => const Offset(44, 16),
        'pass' => Offset(width * 0.5, 12),
        'dishes' => Offset(width - 40, 16),
        'tables' => Offset(width * 0.5, height * 0.5),
        _ => Offset(width * 0.5, height - 18),
      };
      if (ot?.tableId != null && ss.table(ot!.tableId) != null) {
        final r = rectOf(ot.tableId!);
        pos = Offset(r.right - 14, r.top + 14);
      }
      out.add(_Fig('owner', pos, Palette.owner, 'You', 30));
    }
    return out;
  }
}

class _Fig {
  final String id;
  final Offset pos;
  final Color color;
  final String label;
  final double size;
  final bool moved;
  _Fig(this.id, this.pos, this.color, this.label, this.size,
      {this.moved = false});
}

class _Figure extends StatelessWidget {
  final _Fig f;
  const _Figure({required this.f});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: f.size,
      height: f.size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: f.color,
        shape: BoxShape.circle,
        border: Border.all(
            color: f.moved ? Palette.warn : Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Text(f.label,
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: f.size > 24 ? 10 : 11)),
    );
  }
}

class _FloatLabel extends StatefulWidget {
  final _Float f;
  const _FloatLabel({required this.f});
  @override
  State<_FloatLabel> createState() => _FloatLabelState();
}

class _FloatLabelState extends State<_FloatLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
    ..forward();
  @override
  void dispose() {
    a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: a,
      builder: (_, __) => Opacity(
        opacity: (1 - a.value).clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, -24 * a.value),
          child: Center(
            child: Text(widget.f.text,
                style: TextStyle(
                    color: widget.f.color,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    shadows: const [
                      Shadow(color: Colors.white, blurRadius: 4)
                    ])),
          ),
        ),
      ),
    );
  }
}

class _QueueChip extends StatelessWidget {
  final Group group;
  final bool selected;
  final VoidCallback onTap;
  final Sim sim;
  final ServiceState ss;
  const _QueueChip(
      {required this.group,
      required this.selected,
      required this.onTap,
      required this.sim,
      required this.ss});
  @override
  Widget build(BuildContext context) {
    final share = group.counter / math.max(1, sim.patienceLimit(group));
    final seat = ss.tasks
        .where((k) => k.type == 'seat' && k.groupId == group.id)
        .firstOrNull;
    return Semantics(
      button: true,
      label: 'Party of ${group.size} waiting at the door',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Palette.surface,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
                color: selected ? Palette.owner : patienceColor(share),
                width: selected ? 3 : 2.5),
          ),
          child: Row(children: [
            Icon(group.treated ? Icons.local_cafe : Icons.people,
                size: 15, color: Palette.ink),
            const SizedBox(width: 3),
            Text('${group.size}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            if (seat != null) ...[
              const SizedBox(width: 4),
              _Marker(task: seat, share: share, small: true),
            ],
          ]),
        ),
      ),
    );
  }
}

class _TableTile extends StatelessWidget {
  final TableRt table;
  final ServiceState ss;
  final Sim sim;
  final bool selected;
  final void Function(int groupId) onSelect;
  const _TableTile(
      {required this.table,
      required this.ss,
      required this.sim,
      required this.selected,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final g = ss.group(table.groupId);
    final active = g != null && !g.gone;
    Task? task;
    for (final k in ss.tasks) {
      if (k.type == 'cook') continue;
      if (k.tableId == table.id &&
          (k.type == 'clear' || (active && k.groupId == g.id))) {
        task = k;
      }
    }
    String status;
    Color bg;
    var share = 0.0;
    if (table.state == 'dirty') {
      status = 'Dirty';
      bg = const Color(0xFFE2CFAE);
    } else if (!active) {
      status = table.reserved ? 'Seating…' : 'Free';
      bg = const Color(0xFFF4ECDD);
    } else {
      share = g.waiting ? g.counter / math.max(1, sim.patienceLimit(g)) : 0;
      status = switch (g.state) {
        'waitOrder' => 'Wants to order',
        'waitFood' => _foodStatus(g),
        'eating' => 'Eating',
        'waitBill' => 'Wants the bill',
        _ => '',
      };
      bg = Palette.surface;
    }
    final label = 'Table ${table.id}, ${table.seats} seats, $status';
    return Semantics(
      button: active,
      label: label,
      child: GestureDetector(
        onTap: active ? () => onSelect(g.id) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected
                    ? Palette.owner
                    : (active && share > 0.8 ? Palette.bad : Palette.line),
                width: selected ? 3 : 1.2),
            boxShadow: active
                ? const [
                    BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 6,
                        offset: Offset(0, 2))
                  ]
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
          clipBehavior: Clip.hardEdge,
          child: Stack(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text('T${table.id}',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Palette.muted,
                            fontWeight: FontWeight.w700))),
                Text('${table.seats}',
                    style: const TextStyle(fontSize: 10, color: Palette.muted)),
                const Icon(Icons.chair_alt, size: 10, color: Palette.muted),
              ]),
              if (active)
                Flexible(
                    child: ClipRect(
                        child: Wrap(spacing: 0, children: [
                  for (var i = 0; i < g.size; i++)
                    Icon(Icons.person,
                        size: 13,
                        color: g.critic
                            ? Palette.tomato
                            : (g.state == 'eating' ? Palette.ok : Palette.ink)),
                ]))),
              const Spacer(),
              Flexible(
                  child: Text(status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10.5, fontWeight: FontWeight.w600))),
              if (active && g.waiting) ...[
                const SizedBox(height: 2),
                StatBar(1 - share, color: patienceColor(share), height: 3),
              ],
              if (active && g.state == 'eating') ...[
                const SizedBox(height: 2),
                StatBar(
                    ((g.eatUntil - ss.tick) / math.max(1, sim.eatTicks(g.size)))
                        .clamp(0, 1),
                    color: Palette.ok,
                    height: 3),
              ],
            ]),
            if (task != null)
              Positioned(
                  right: 0,
                  bottom: 8,
                  child: _Marker(task: task, share: share)),
          ]),
        ),
      ),
    );
  }

  String _foodStatus(Group g) {
    final ts = g.ticketIds
        .map(ss.ticket)
        .whereType<Ticket>()
        .where((t) => t.state != 'cancel')
        .toList();
    final ready = ts.where((t) => t.state == 'ready').length;
    return ts.isEmpty ? 'Waiting' : 'Food $ready/${ts.length}';
  }
}

/// A task bubble: tap to do this job yourself (doc 07 §4.4).
class _Marker extends StatelessWidget {
  final Task task;
  final double share;
  final bool small;
  const _Marker({required this.task, required this.share, this.small = false});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final ss = c.sim!.service!;
    final queued = ss.ownerQueue.contains(task.id) || task.assignee == 'owner';
    final taken = task.started && task.assignee != 'owner';
    final size = small ? 26.0 : 34.0;
    return Semantics(
      button: true,
      label: '${task.type} job${taken ? ', staff on it' : ''}',
      child: GestureDetector(
        onTap: taken ? null : () => sendCmd(context, OwnerQueueTask(task.id)),
        child: Opacity(
          opacity: taken ? 0.45 : 1,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: queued ? Palette.owner : Palette.surface,
              shape: BoxShape.circle,
              border: Border.all(
                  color: queued
                      ? Palette.owner
                      : (task.type == 'clear'
                          ? Palette.line
                          : patienceColor(share)),
                  width: 3),
              boxShadow: const [
                BoxShadow(color: Color(0x22000000), blurRadius: 4)
              ],
            ),
            child: Icon(AssetCatalog.task(task.type),
                size: small ? 14 : 17,
                color: queued ? Colors.white : Palette.ink),
          ),
        ),
      ),
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
    final floor = sim.state.loc.staff
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

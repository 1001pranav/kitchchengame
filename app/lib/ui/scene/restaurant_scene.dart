import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sim_core/sim_core.dart';

import '../theme.dart';
import '../widgets/common.dart';
import 'scene_art.dart';

/// The live restaurant during service, drawn as an animated top-down scene:
/// the kitchen with its stations along the back wall, the pass, the dining
/// room with tables and chairs, and the entrance with the queue and the till.
/// People walk between places; the simulation decides where they need to be.
class RestaurantScene extends StatefulWidget {
  final ServiceState ss;
  final int? selectedGroup;
  final void Function(int groupId) onSelect;
  const RestaurantScene(
      {super.key,
      required this.ss,
      required this.selectedGroup,
      required this.onSelect});

  /// Height the scene needs at [width] for [tables] tables.
  static double neededHeight(double width, int tables) {
    final cols = _cols(tables);
    final rows = (tables / cols).ceil();
    return _kitchenH + 24 + rows * _minCellH + _lobbyH;
  }

  @override
  State<RestaurantScene> createState() => _RestaurantSceneState();
}

const _kitchenH = 116.0;
const _lobbyH = 54.0;
const _minCellH = 66.0;
int _cols(int n) => n <= 8 ? 3 : (n <= 16 ? 4 : (n <= 24 ? 5 : 6));

// ------------------------------------------------------------------ layout

class _Layout {
  final Size size;
  final Rect kitchen, dining, lobby, pass, sink, till, gap;
  final List<String> stations;
  final Map<String, Rect> stationRect = {};
  final Map<int, Rect> table = {};
  final Map<int, List<(Offset, bool)>> chairs = {}; // centre, back-at-top
  final Map<int, Offset> bubble = {};
  final List<double> lanesY = []; // gaps between table rows
  final List<double> aislesX = []; // gaps between table columns

  _Layout(this.size, List<TableRt> tables, this.stations)
      : kitchen = Rect.fromLTWH(0, 0, size.width, _kitchenH),
        dining = Rect.fromLTWH(
            0, _kitchenH, size.width, size.height - _kitchenH - _lobbyH),
        lobby = Rect.fromLTWH(0, size.height - _lobbyH, size.width, _lobbyH),
        pass = Rect.fromLTWH(
            size.width * 0.2, _kitchenH - 13, size.width * 0.5, 13),
        sink = Rect.fromLTWH(size.width - 74, 20, 62, 32),
        till =
            Rect.fromLTWH(size.width - 96, size.height - _lobbyH - 9, 72, 16),
        gap = Rect.fromLTWH(56, size.height - _lobbyH - 4, 54, 8) {
    final w = size.width;
    // Stations along the back wall, left of the sink.
    final avail = w - 74 - 22;
    final n = math.max(1, stations.length);
    final sw = math.min(66.0, (avail - (n - 1) * 6) / n);
    var x = 10.0;
    for (final st in stations) {
      stationRect[st] = Rect.fromLTWH(x, 20, sw, 32);
      x += sw + 6;
    }
    // Tables in a grid.
    final cols = _cols(tables.length);
    final rows = math.max(1, (tables.length / cols).ceil());
    final area = Rect.fromLTRB(
        dining.left + 6, dining.top + 24, dining.right - 6, dining.bottom - 8);
    final cw = area.width / cols, ch = area.height / rows;
    for (var r = 0; r <= rows; r++) {
      lanesY.add(r == 0
          ? area.top - 6
          : (r == rows ? area.bottom - 2 : area.top + r * ch));
    }
    for (var k = 0; k <= cols; k++) {
      aislesX.add(k == 0
          ? area.left + 6
          : (k == cols ? area.right - 6 : area.left + k * cw));
    }
    for (var i = 0; i < tables.length; i++) {
      final t = tables[i];
      final col = i % cols, row = i ~/ cols;
      final cell =
          Rect.fromLTWH(area.left + col * cw, area.top + row * ch, cw, ch);
      final tw = math.min(
          cw * 0.62, t.seats >= 6 ? 66.0 : (t.seats >= 4 ? 48.0 : 34.0));
      final th = math.min(ch * 0.34, 24.0);
      final tr = Rect.fromCenter(
          center: cell.center.translate(0, 3), width: tw, height: th);
      table[t.id] = tr;
      final perSide = (t.seats / 2).ceil();
      final list = <(Offset, bool)>[];
      for (var k = 0; k < t.seats; k++) {
        final topSide = k < perSide;
        final idx = topSide ? k : k - perSide;
        final count = topSide ? perSide : t.seats - perSide;
        final fx = (idx + 0.5) / count;
        list.add((
          Offset(tr.left + tr.width * fx, topSide ? tr.top - 6 : tr.bottom + 7),
          topSide
        ));
      }
      chairs[t.id] = list;
      bubble[t.id] = Offset(tr.right + 4, tr.top - 22);
    }
  }

  /// Waypoints from [a] to [b] that keep to the aisles and the gaps between
  /// rows, so nobody walks through a table. [lane] nudges people in a group apart.
  List<Offset> route(Offset a, Offset b, {double lane = 0}) {
    bool inRoom(Offset p) => p.dy > dining.top + 4 && p.dy < dining.bottom - 2;
    final out = <Offset>[];
    var from = a;
    if (!inRoom(from)) {
      // From the kitchen side through the pass, or from the lobby through the gap.
      from = from.dy <= dining.top + 4
          ? Offset(from.dx.clamp(pass.left + 8, pass.right - 8), lanesY.first)
          : Offset(gap.center.dx, lanesY.last);
      out.add(from);
    }
    var to = b;
    final toOutside = !inRoom(to);
    if (toOutside) {
      to = to.dy <= dining.top + 4
          ? Offset(to.dx.clamp(pass.left + 8, pass.right - 8), lanesY.first)
          : Offset(gap.center.dx, lanesY.last);
    }
    double nearest(List<double> xs, double v) =>
        xs.reduce((x, y) => (x - v).abs() <= (y - v).abs() ? x : y);
    final la = nearest(lanesY, from.dy) + lane;
    final lb = nearest(lanesY, to.dy) + lane;
    final aisle = nearest(aislesX, (from.dx + to.dx) / 2) + lane;
    out
      ..add(Offset(from.dx, la))
      ..add(Offset(aisle, la))
      ..add(Offset(aisle, lb))
      ..add(Offset(to.dx, lb));
    if (toOutside) out.add(to);
    // Drop steps that do not move anywhere.
    final clean = <Offset>[];
    var prev = a;
    for (final p in out) {
      if ((p - prev).distance > 1) clean.add(p);
      prev = p;
    }
    return clean;
  }

  Offset get spawn => Offset(-14, lobby.center.dy + 4);
  Offset get doorIn => Offset(18, lobby.center.dy + 4);
  Offset queueSlot(int i) => Offset(40 + i * 15.0, lobby.center.dy + 8);
  Offset tableSide(int id) {
    final r = table[id];
    return r == null ? dining.center : Offset(r.right + 9, r.center.dy + 8);
  }
}

// ------------------------------------------------------------------ actors

class _Actor {
  final String id;
  Look look;
  Offset pos;
  final List<Offset> path = [];
  double bob = 0, phase = 0;
  bool moving = false;
  double facing = math.pi / 2;
  bool busy = false;
  bool seated = false;
  bool carryPlate = false, carryDirty = false, notepad = false;
  bool mop = false, box = false;
  double wanderAt = 0;
  Mood mood = Mood.happy;
  double alpha = 1;
  bool leaving = false;
  Color food = foodColors[0];
  _Actor(this.id, this.look, this.pos);

  Offset get target => path.isEmpty ? pos : path.last;
  void goTo(Offset p, {List<Offset> via = const []}) {
    if ((target - p).distance < 0.5) return;
    path
      ..clear()
      ..addAll(via)
      ..add(p);
  }

  void step(double dt, double speed) {
    if (path.isEmpty) {
      moving = false;
      // Working in place (cooking, washing, taking an order, eating) looks
      // busy; standing around breathes a little.
      phase += dt * (busy ? 12 : 2.2);
      bob = busy
          ? math.sin(phase).abs() * (seated ? 0.6 : 1.3)
          : (seated ? 0 : (math.sin(phase) + 1) * 0.35);
      return;
    }
    if (speed <= 0) {
      moving = false;
      return;
    }
    final total = speed * dt;
    var left = total;
    while (left > 0 && path.isNotEmpty) {
      final d = path.first - pos;
      final dist = d.distance;
      if (dist > 0.5) {
        // Turn smoothly toward where they are heading.
        var diff = d.direction - facing;
        while (diff > math.pi) {
          diff -= 2 * math.pi;
        }
        while (diff < -math.pi) {
          diff += 2 * math.pi;
        }
        facing += diff * math.min(1, dt * 12);
      }
      if (dist <= left) {
        pos = path.removeAt(0);
        left -= dist;
      } else {
        pos += d / dist * left;
        left = 0;
      }
    }
    moving = path.isNotEmpty;
    // One step per ~7 px walked, so legs keep pace with any game speed.
    phase += (total - left) * 0.45;
    bob = moving ? (math.cos(phase).abs() * 1.4) : bob * 0.8;
  }
}

class _Party {
  final int id;
  final List<_Actor> people;
  String state;
  int? tableId;
  bool removed = false;
  _Party(this.id, this.people, this.state);
}

class _Particle {
  final int kind; // 0 coin, 1 text, 2 steam, 3 smoke, 4 puff, 5 heart, 6 bubble
  Offset from, to;
  double age = 0;
  final double life;
  final double delay;
  final String text;
  final Color color;
  _Particle(this.kind, this.from, this.to, this.life,
      {this.delay = 0, this.text = '', this.color = Colors.white});
}

class _Hit {
  final Rect rect;
  final int? taskId;
  final int? groupId;
  _Hit(this.rect, {this.taskId, this.groupId});
}

// ------------------------------------------------------------------ state

class _RestaurantSceneState extends State<RestaurantScene>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final _frame = ValueNotifier<int>(0);
  Duration _last = Duration.zero;
  double _time = 0;
  ServiceState? _ss;
  final Map<String, _Actor> _staff = {};
  final Map<int, _Party> _parties = {};
  final List<_Particle> _particles = [];
  final List<_Hit> _hits = [];
  _Layout? _layout;
  Size? _layoutSize;
  int _layoutTables = -1;
  ui.Picture? _bg;
  ui.Picture? _light;
  double _steamClock = 0;
  double _doorOpen = 0;
  double _shake = 0;
  Offset? _ownerSpot; // where the player sent their character
  String? _spotArea;
  bool _fresh = true;
  final _rnd = math.Random(5);

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    _bg?.dispose();
    _light?.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = elapsed;
    if (!mounted) return;
    final c = GameScope.read(context);
    final reduced = c.settings.reducedMotion;
    _time += dt;
    final rate = c.playRate;
    final l = _layout;
    final sim = c.sim;
    if (l != null && sim != null && sim.service != null) {
      _sync(sim, sim.service!, l, reduced);
      final speed = 95.0 * math.max(rate, 0.0) * (reduced ? 50 : 1);
      for (final a in _staff.values) {
        a.step(dt, a.id == 'owner' ? speed * 1.4 : speed);
      }
      for (final p in _parties.values) {
        for (final a in p.people) {
          a.step(dt, speed * 0.85);
          if (a.leaving && a.path.isEmpty) {
            a.alpha = math.max(0, a.alpha - dt * 3);
          }
        }
      }
      final near = [
        ..._staff.values,
        for (final p in _parties.values) ...p.people
      ].any((a) => (a.pos - l.doorIn).distance < 30 && a.alpha > 0.1);
      _doorOpen += ((near ? 1.0 : 0.0) - _doorOpen) * math.min(1, dt * 8);
      _shake = math.max(0, _shake - dt * 12);
      _parties.removeWhere((_, p) =>
          p.removed && p.people.every((a) => a.alpha <= 0 || a.pos.dx < -10));
      if (!reduced && rate > 0) _ambient(sim, l, dt * math.min(rate, 2));
      for (final p in _particles) {
        p.age +=
            dt * (p.kind == 2 || p.kind == 3 ? 1 : math.max(1, rate * 0.6));
      }
      _particles.removeWhere((p) => p.age > p.delay + p.life);
    }
    _frame.value++;
  }

  /// Moves everyone toward where the simulation says they are.
  void _sync(Sim sim, ServiceState ss, _Layout l, bool reduced) {
    if (!identical(ss, _ss)) {
      _ss = ss;
      _staff.clear();
      _parties.clear();
      _particles.clear();
      _fresh = true;
    }
    final snap = _fresh || reduced;
    final tick = ss.tick;
    final taskByWho = <String, Task>{};
    for (final k in ss.tasks) {
      if (k.assignee != null) taskByWho[k.assignee!] = k;
    }
    // Staff.
    final seen = <String>{};
    var serverI = 0, cookI = 0, otherI = 0;
    for (final s in sim.state.viewLoc.staff) {
      if (!s.workingToday || s.lateTick > tick) continue;
      final role = ss.moves['${s.id}'] ?? (s.isManager ? 'cashier' : s.role);
      final id = 's${s.id}';
      seen.add(id);
      final a = _staff.putIfAbsent(id, () {
        final look = Look.staff(s.id, s.isManager ? 'manager' : s.role);
        return _Actor(id, look, snap ? Offset.zero : l.doorIn);
      });
      final task = taskByWho['${s.id}'];
      final idx = switch (role) {
        'server' => serverI++,
        'lineCook' || 'headChef' || 'prepCook' => cookI++,
        _ => otherI++,
      };
      _placeWorker(a, task, role, idx, sim, ss, l, snap);
    }
    if (sim.ownerPresent) {
      seen.add('owner');
      final a = _staff.putIfAbsent('owner',
          () => _Actor('owner', Look.owner, snap ? Offset.zero : l.doorIn));
      _placeWorker(a, taskByWho['owner'], 'owner', 0, sim, ss, l, snap);
    }
    _staff.removeWhere((k, _) => !seen.contains(k));

    // Parties.
    final queue =
        ss.groups.where((g) => g.state == 'waitTable' && !g.delivery).toList();
    final qIndex = <int, int>{};
    var slot = 0;
    for (final g in queue) {
      qIndex[g.id] = slot;
      slot += g.size;
    }
    for (final g in ss.groups) {
      if (g.delivery) {
        _rider(g, l, snap);
        continue;
      }
      var p = _parties[g.id];
      if (p == null) {
        if (g.gone) continue; // left before we ever saw them
        p = _Party(
            g.id,
            [
              for (var i = 0; i < g.size; i++)
                _Actor(
                    'g${g.id}_$i',
                    Look.customer(g.id * 10 + i, critic: g.critic && i == 0),
                    snap ? Offset.zero : l.spawn)
            ],
            '');
        _parties[g.id] = p;
      }
      final share =
          g.waiting ? g.counter / math.max(1, sim.patienceLimit(g)) : 0.0;
      final mood = share > 0.8
          ? Mood.angry
          : (share > 0.55
              ? Mood.annoyed
              : (share > 0.3 ? Mood.neutral : Mood.happy));
      if (g.state != p.state) _onPartyChange(p, g, sim, l);
      p.state = g.state;
      p.tableId = g.tableId;
      for (var i = 0; i < p.people.length; i++) {
        final a = p.people[i];
        if (!g.gone) a.mood = g.state == 'eating' ? Mood.happy : mood;
        a.busy = g.state == 'eating';
        Offset target;
        var seated = false;
        if (g.gone) {
          target = l.spawn;
        } else if (g.state == 'waitTable' || g.tableId == null) {
          target = l.queueSlot((qIndex[g.id] ?? 0) + i);
        } else {
          final ch = l.chairs[g.tableId]
              ?[i % math.max(1, l.chairs[g.tableId]!.length)];
          target = ch == null
              ? l.dining.center
              : ch.$1.translate(0, ch.$2 ? 1.5 : -1.5);
          seated = true;
        }
        if (snap) {
          a.pos = target;
          a.path.clear();
        } else if (g.gone) {
          if (!a.leaving) {
            a.leaving = true;
            a.seated = false;
            a.goTo(target, via: [
              ...l.route(a.pos, l.gap.center.translate(0, 8), lane: i * 4.0),
              l.doorIn,
            ]);
          }
        } else if ((a.target - target).distance > 0.5) {
          a.goTo(target,
              via: seated ? l.route(a.pos, target, lane: i * 4.0) : const []);
        }
        a.seated = seated && a.path.isEmpty;
      }
      if (g.gone) p.removed = true;
    }
    _fresh = false;
  }

  /// A delivery order: a rider waits at the till for the bag, then rides off.
  void _rider(Group g, _Layout l, bool snap) {
    var p = _parties[g.id];
    if (p == null) {
      if (g.gone) return;
      final a = _Actor('d${g.id}', Look.rider, snap ? Offset.zero : l.spawn)
        ..box = true;
      p = _Party(g.id, [a], 'rider');
      _parties[g.id] = p;
    }
    final a = p.people.first;
    final wait = Offset(
        l.till.center.dx - 14 - (g.id % 3) * 14.0, l.lobby.center.dy + 6);
    if (snap && !g.gone) {
      a.pos = wait;
      a.path.clear();
    } else if (g.gone) {
      if (!a.leaving) {
        a.leaving = true;
        a.goTo(l.spawn, via: [l.doorIn]);
        if (g.payment > 0) {
          _particles.add(_Particle(
              1, wait.translate(0, -30), wait.translate(0, -60), 1.2,
              text: '+${g.payment}', color: const Color(0xFF1B998B)));
        }
      }
      p.removed = true;
    } else {
      a.goTo(wait);
    }
  }

  void _onPartyChange(_Party p, Group g, Sim sim, _Layout l) {
    final tr = g.tableId == null ? null : l.table[g.tableId];
    final at = tr?.center ?? l.queueSlot(0);
    if (g.state == 'left' && g.payment > 0) {
      final coins = (g.payment / 12).clamp(3, 9).round();
      for (var i = 0; i < coins; i++) {
        _particles.add(_Particle(
            0, at.translate(_rnd.nextDouble() * 16 - 8, 0), l.till.center, 0.75,
            delay: i * 0.07));
      }
      _particles.add(_Particle(
          1, at.translate(0, -8), at.translate(0, -40), 1.3,
          text: '+${g.payment}', color: Palette.gold));
    } else if (g.state == 'walkedOut') {
      _shake = 4;
      for (final a in p.people) {
        a.mood = Mood.angry;
      }
      final where = tr?.center ?? l.queueSlot(0);
      for (var i = 0; i < 6; i++) {
        final ang = i * math.pi / 3;
        _particles.add(_Particle(
            4, where, where + Offset(math.cos(ang), math.sin(ang)) * 18, 0.6,
            delay: 0.02 * i));
      }
      _particles.add(_Particle(
          1, where.translate(0, -10), where.translate(0, -42), 1.4,
          text: 'Walked out', color: Palette.bad));
    } else if (g.state == 'eating') {
      for (var i = 0; i < p.people.length; i++) {
        p.people[i].food = foodColors[(g.id + i * 3) % foodColors.length];
      }
    }
  }

  void _placeWorker(_Actor a, Task? task, String role, int idx, Sim sim,
      ServiceState ss, _Layout l, bool snap) {
    a.carryPlate = false;
    a.carryDirty = false;
    a.notepad = false;
    a.mop = false;
    a.busy = task != null || (role == 'dishwasher' && ss.dirtyDishes > 0.5);
    Offset target;
    double prog() => task == null || task.endTick <= task.startTick
        ? 0
        : ((ss.tick - task.startTick) / (task.endTick - task.startTick))
            .clamp(0.0, 1.0);
    if (task != null) {
      switch (task.type) {
        case 'cook':
          final dish = sim.content.dishes[ss.ticket(task.ticketId)?.dishId];
          final r = l.stationRect[dish?.station] ?? l.stationRect.values.first;
          target = Offset(r.center.dx, r.bottom + 22);
        case 'seat':
          target = l.gap.center.translate(-6, -12);
        case 'deliver':
          if (prog() < 0.35) {
            target = Offset(
                l.pass.center.dx + (idx % 3 - 1) * 16, l.pass.bottom + 20);
          } else {
            target = l.tableSide(task.tableId ?? 0);
            a.carryPlate = true;
            a.food = foodColors[(task.groupId ?? 0) % foodColors.length];
          }
        case 'clear':
          if (prog() < 0.6) {
            target = l.tableSide(task.tableId ?? 0);
          } else {
            target = Offset(l.sink.center.dx, l.sink.bottom + 22);
            a.carryDirty = true;
          }
        case 'bill':
          target = task.tableId != null && prog() > 0.4
              ? l.tableSide(task.tableId!)
              : Offset(l.till.center.dx - 10, l.till.top - 12);
        case 'pack':
          target = Offset(l.pass.right - 12, l.pass.bottom + 20);
        default: // takeOrder, apologise
          target = l.tableSide(task.tableId ?? 0);
          a.notepad = task.type == 'takeOrder';
      }
    } else if (role == 'cleaner') {
      // Mops the floor between the tables, moving on every few seconds.
      a.mop = true;
      if (_time > a.wanderAt) {
        a.wanderAt = _time + 4 + _rnd.nextDouble() * 4;
        final x = l.aislesX[_rnd.nextInt(l.aislesX.length)];
        final y = l.lanesY[_rnd.nextInt(l.lanesY.length)];
        if (!snap) a.goTo(Offset(x, y), via: l.route(a.pos, Offset(x, y)));
      }
      if (snap) a.pos = l.dining.center;
      return;
    } else if (role == 'owner' &&
        _ownerSpot != null &&
        ss.ownerArea == _spotArea) {
      final t = _ownerSpot!;
      if (snap) {
        a.pos = t;
      } else if ((a.target - t).distance > 0.5) {
        final kitchen = a.pos.dy < l.dining.top && t.dy < l.dining.top;
        a.goTo(t, via: kitchen ? const [] : l.route(a.pos, t));
      }
      return;
    } else {
      final rs = l.stationRect.values.toList();
      target = switch (role) {
        'lineCook' || 'headChef' || 'prepCook' => rs.isEmpty
            ? l.kitchen.center
            : Offset(rs[idx % rs.length].center.dx + (idx ~/ rs.length) * 10,
                rs[idx % rs.length].bottom + 24),
        'server' => Offset(l.pass.left + 18 + idx * 22.0, l.pass.bottom + 22),
        'cashier' => Offset(l.till.center.dx + idx * 14.0, l.till.top - 12),
        'dishwasher' => Offset(l.sink.center.dx, l.sink.bottom + 22),
        'cleaner' =>
          Offset(l.size.width - 18, l.dining.top + l.dining.height * 0.45),
        'owner' => switch (ss.ownerArea) {
            'door' => l.gap.center.translate(10, -14),
            'pass' => Offset(l.pass.center.dx, l.pass.bottom + 24),
            'dishes' => Offset(l.sink.center.dx - 16, l.sink.bottom + 22),
            'tables' => l.dining.center,
            _ => Offset(l.size.width * 0.5, l.dining.bottom - 14),
          },
        _ => Offset(l.size.width - 30, l.dining.bottom - 16),
      };
    }
    if (snap) {
      a.pos = target;
      a.path.clear();
    } else if ((a.target - target).distance > 0.5) {
      final kitchenToKitchen =
          a.pos.dy < l.dining.top && target.dy < l.dining.top;
      a.goTo(target, via: kitchenToKitchen ? const [] : l.route(a.pos, target));
    }
  }

  void _ambient(Sim sim, _Layout l, double dt) {
    _steamClock += dt;
    if (_steamClock < 0.18) return;
    _steamClock = 0;
    final ss = sim.service!;
    for (final e in l.stationRect.entries) {
      final busy = ss.tasks.any((k) =>
          k.type == 'cook' &&
          k.started &&
          sim.content.dishes[ss.ticket(k.ticketId)?.dishId]?.station == e.key);
      final r = e.value;
      if (sim.stationDown(e.key)) {
        _particles.add(_Particle(3, r.center,
            r.center.translate(_rnd.nextDouble() * 10 - 5, -36), 1.6));
      } else if (busy && e.key != 'cold' && _rnd.nextDouble() < 0.6) {
        final from = Offset(r.left + _rnd.nextDouble() * r.width, r.top + 6);
        _particles.add(_Particle(
            2, from, from.translate(_rnd.nextDouble() * 8 - 4, -30), 1.4));
      }
    }
    final washing = sim.state.viewLoc.staff
            .any((s) => s.workingToday && s.role == 'dishwasher') &&
        ss.dirtyDishes > 0.5;
    if (washing && _rnd.nextDouble() < 0.5) {
      final from =
          Offset(l.sink.left + 10 + _rnd.nextDouble() * 24, l.sink.top + 14);
      _particles.add(_Particle(
          6, from, from.translate(_rnd.nextDouble() * 6 - 3, -14), 0.9));
    }
  }

  void _tap(Offset p) {
    for (final h in _hits.reversed) {
      if (!h.rect.contains(p)) continue;
      if (h.taskId != null) {
        sendCmd(context, OwnerQueueTask(h.taskId!));
        return;
      }
      if (h.groupId != null) {
        widget.onSelect(h.groupId!);
        return;
      }
    }
    // Empty floor: walk there. Where you stand decides what you help with.
    final c = GameScope.read(context);
    final l = _layout;
    if (l == null || c.sim == null || !c.sim!.ownerPresent) {
      if (l != null) {
        showToast(context, 'You are not at this restaurant right now.');
      }
      return;
    }
    String area;
    Offset spot;
    if (p.dy < l.dining.top) {
      area = p.dx > l.sink.left - 24 ? 'dishes' : 'pass';
      spot = Offset(p.dx.clamp(14, l.size.width - 14),
          p.dy.clamp(l.sink.bottom + 18, l.kitchen.bottom - 18));
    } else if (p.dy > l.dining.bottom - 26) {
      area = 'door';
      spot = Offset(p.dx.clamp(20, l.size.width - 20), l.dining.bottom - 12);
    } else {
      area = 'tables';
      spot = p;
    }
    _ownerSpot = spot;
    _spotArea = area;
    _particles.add(_Particle(7, spot, spot, 0.7));
    if (c.sim!.service?.ownerArea != area) sendCmd(context, OwnerStand(area));
  }

  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final ss = widget.ss;
    final stations = sim.content.themes[sim.state.viewLoc.themeId]?.stations ??
        sim.content.themes[sim.state.themeId]!.stations;
    return LayoutBuilder(builder: (context, box) {
      final need = RestaurantScene.neededHeight(box.maxWidth, ss.tables.length);
      final h = box.maxHeight.isFinite ? math.max(box.maxHeight, need) : need;
      final size = Size(box.maxWidth, h);
      if (_layoutSize != size || _layoutTables != ss.tables.length) {
        _layoutSize = size;
        _layoutTables = ss.tables.length;
        _layout = _Layout(size, ss.tables, stations);
        _bg?.dispose();
        _bg = recordPicture(size, (cv) => _paintBackground(cv, _layout!));
        _light?.dispose();
        _light = recordPicture(size, (cv) => _paintLight(cv, _layout!));
        _fresh = true;
      }
      final l = _layout!;
      final scene = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => _tap(d.localPosition),
        child: Stack(children: [
          ExcludeSemantics(
            child: CustomPaint(
              size: size,
              painter: _ScenePainter(this, sim, ss, l, widget.selectedGroup),
            ),
          ),
          // Screen-reader view of the tables.
          for (final t in ss.tables)
            if (l.table[t.id] != null)
              Positioned.fromRect(
                rect: l.table[t.id]!.inflate(10),
                child: Semantics(
                  label: _tableLabel(sim, ss, t),
                  button: t.groupId != null,
                  onTap: t.groupId == null
                      ? null
                      : () => widget.onSelect(t.groupId!),
                  child: const SizedBox.expand(),
                ),
              ),
        ]),
      );
      if (h > box.maxHeight && box.maxHeight.isFinite) {
        return SingleChildScrollView(child: SizedBox(height: h, child: scene));
      }
      return SizedBox(height: h, child: scene);
    });
  }

  String _tableLabel(Sim sim, ServiceState ss, TableRt t) {
    final g = ss.group(t.groupId);
    final status = t.state == 'dirty'
        ? 'needs clearing'
        : (g == null || g.gone
            ? 'free'
            : switch (g.state) {
                'waitOrder' => 'wants to order',
                'waitFood' => 'waiting for food',
                'eating' => 'eating',
                'waitBill' => 'wants the bill',
                _ => '',
              });
    return 'Table ${t.id}, ${t.seats} seats, $status';
  }

  void _paintLight(Canvas c, _Layout l) {
    final full = Offset.zero & l.size;
    c.saveLayer(full, Paint());
    c.drawRect(full, Paint()..color = const Color(0xC8080605));
    for (final r in l.table.values) {
      drawLightPool(c, r.center, r.width * 0.75 + 34, Colors.black, 0.95);
    }
    for (var x = l.pass.left + 16; x < l.pass.right - 8; x += 34) {
      drawLightPool(c, Offset(x, l.pass.center.dy + 6), 34, Colors.black, 0.9);
    }
    for (final st in l.stationRect.values) {
      drawLightPool(c, st.center.translate(0, 18), 48, Colors.black, 0.75);
    }
    drawLightPool(c, l.sink.center.translate(0, 16), 46, Colors.black, 0.7);
    drawLightPool(c, l.till.center.translate(0, -6), 52, Colors.black, 0.85);
    drawLightPool(c, Offset(40, l.lobby.center.dy), 60, Colors.black, 0.7);
    c.restore();
    // Warm and cool glows on top.
    for (final r in l.table.values) {
      drawGlow(c, r.center, r.width * 0.6 + 22, const Color(0x2EFFB45A));
    }
    for (var x = l.pass.left + 16; x < l.pass.right - 8; x += 34) {
      drawGlow(c, Offset(x, l.pass.center.dy + 2), 24, const Color(0x40FF7A2A));
    }
    for (final st in l.stationRect.values) {
      drawGlow(c, st.center.translate(0, 14), 40, const Color(0x1A9FC6FF));
    }
    drawGlow(c, l.till.center, 40, const Color(0x22FFC878));
  }

  void _paintBackground(Canvas c, _Layout l) {
    final w = l.size.width;
    drawTiles(c, l.kitchen);
    // Back wall with a steel splash-back above the stations.
    c.drawRect(
        Rect.fromLTWH(0, 0, w, 16), Paint()..color = const Color(0xFF0D0C0B));
    c.drawRect(
        Rect.fromLTWH(0, 15, w, 2), Paint()..color = const Color(0xFF4A545A));
    drawPlanks(c, l.dining);
    // Kitchen/dining wall with the pass opening.
    final wallY = l.kitchen.bottom - 4;
    final wall = Paint()..color = const Color(0xFF0D0C0B);
    c.drawRect(Rect.fromLTWH(0, wallY, l.pass.left - 4, 8), wall);
    c.drawRect(
        Rect.fromLTWH(l.pass.right + 4, wallY, w - l.pass.right - 4, 8), wall);
    final trim = Paint()..color = const Color(0xFF5C4F3A);
    c.drawRect(Rect.fromLTWH(0, wallY + 8, l.pass.left - 4, 1), trim);
    c.drawRect(
        Rect.fromLTWH(l.pass.right + 4, wallY + 8, w - l.pass.right - 4, 1),
        trim);
    // Side walls.
    c.drawRect(Rect.fromLTWH(0, l.dining.top, 3, l.dining.height), wall);
    c.drawRect(Rect.fromLTWH(w - 3, l.dining.top, 3, l.dining.height), wall);
    // Pass: a steel shelf under heat lamps.
    fillRRect(
        c,
        RRect.fromRectAndRadius(
            l.pass.shift(const Offset(1, 3)), const Radius.circular(2)),
        const Color(0x66000000));
    fillRRect(c, RRect.fromRectAndRadius(l.pass, const Radius.circular(2)),
        const Color(0xFF6E7A82));
    fillRRect(
        c,
        RRect.fromRectAndRadius(
            l.pass.deflate(1.6), const Radius.circular(1.5)),
        const Color(0xFF9AA5AC));
    for (var x = l.pass.left + 16; x < l.pass.right - 8; x += 34) {
      fillRRect(
          c,
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(x, l.pass.top - 3), width: 18, height: 4),
              const Radius.circular(1)),
          const Color(0xFF2A2A2A));
    }
    // Sink: stainless double basin.
    fillRRect(
        c,
        RRect.fromRectAndRadius(
            l.sink.shift(const Offset(1, 3)), const Radius.circular(3)),
        const Color(0x66000000));
    fillRRect(c, RRect.fromRectAndRadius(l.sink, const Radius.circular(3)),
        const Color(0xFF7A858C));
    for (final dx in [5.0, 32.0]) {
      fillRRect(
          c,
          RRect.fromRectAndRadius(
              Rect.fromLTWH(l.sink.left + dx, l.sink.top + 5, 24, 22),
              const Radius.circular(3)),
          const Color(0xFF4A555C));
    }
    // Lobby: dark stone, a runner from the door, the host stand.
    c.drawRect(l.lobby, Paint()..color = const Color(0xFF1A1817));
    for (var x = 0.0; x < w; x += 22) {
      c.drawLine(
          Offset(x, l.lobby.top),
          Offset(x, l.lobby.bottom),
          Paint()
            ..color = const Color(0x22000000)
            ..strokeWidth = 1);
    }
    drawRug(c, Rect.fromLTWH(6, l.lobby.top + 12, 74, l.lobby.height - 24));
    final low = Paint()..color = const Color(0xFF0D0C0B);
    c.drawRect(Rect.fromLTWH(0, l.lobby.top - 3, l.gap.left, 6), low);
    c.drawRect(
        Rect.fromLTWH(l.gap.right, l.lobby.top - 3, w - l.gap.right, 6), low);
    c.drawRect(Rect.fromLTWH(0, l.lobby.top + 3, l.gap.left, 1), trim);
    c.drawRect(
        Rect.fromLTWH(l.gap.right, l.lobby.top + 3, w - l.gap.right, 1), trim);
    // Kitchen: fridge and a shelf of jars beside the stations.
    final last = l.stationRect.values.isEmpty
        ? 10.0
        : l.stationRect.values.map((r) => r.right).reduce(math.max);
    final room = l.sink.left - 8 - (last + 8);
    if (room >= 26) {
      final f = Rect.fromLTWH(last + 8, 20, math.min(32.0, room), 36);
      drawFridge(c, f);
      if (room - f.width >= 26) {
        drawShelf(c, Rect.fromLTWH(f.right + 8, 24, room - f.width - 10, 6));
      }
    }
    // Till: a walnut counter with a terminal.
    fillRRect(
        c,
        RRect.fromRectAndRadius(
            l.till.shift(const Offset(1, 3)), const Radius.circular(2)),
        const Color(0x66000000));
    fillRRect(c, RRect.fromRectAndRadius(l.till, const Radius.circular(2)),
        const Color(0xFF3B2A20));
    fillRRect(
        c,
        RRect.fromRectAndRadius(
            l.till.deflate(1.5), const Radius.circular(1.5)),
        const Color(0xFF4A3528));
    fillRRect(
        c,
        RRect.fromRectAndRadius(
            Rect.fromLTWH(l.till.right - 20, l.till.top + 3, 12, 9),
            const Radius.circular(1)),
        const Color(0xFF151719));
    fillRRect(
        c,
        RRect.fromRectAndRadius(
            Rect.fromLTWH(l.till.right - 18.5, l.till.top + 4.5, 9, 4),
            const Radius.circular(0.5)),
        const Color(0xFF3F8C9A));
    // Plants.
    drawPlant(c, Offset(14, l.dining.top + 26), s: 0.9);
    drawPlant(c, Offset(w - 14, l.dining.top + 26), s: 0.9);
    drawPlant(c, Offset(w - 14, l.lobby.top + 27), s: 0.8);
    // Chairs (empty ones stay visible under people).
    for (final e in l.chairs.entries) {
      for (final (o, top) in e.value) {
        drawChair(c, o, top: top);
      }
    }
  }
}

// ------------------------------------------------------------------ painter

class _ScenePainter extends CustomPainter {
  final _RestaurantSceneState s;
  final Sim sim;
  final ServiceState ss;
  final _Layout l;
  final int? selected;
  _ScenePainter(this.s, this.sim, this.ss, this.l, this.selected)
      : super(repaint: s._frame);

  @override
  void paint(Canvas c, Size size) {
    final t = s._time;
    s._hits.clear();
    if (s._shake > 0) {
      c.translate(
          math.sin(t * 90) * s._shake, math.cos(t * 77) * s._shake * 0.6);
    }
    c.drawPicture(s._bg!);
    final evening = ((ss.tick - 220) / 120).clamp(0.0, 1.0);
    _kitchen(c, t);
    _prepTable(c, t);
    // Tables with the people at them: far side, table, near side.
    final byTable = <int, _Party>{};
    for (final p in s._parties.values) {
      if (p.tableId != null && !p.removed && p.state != 'waitTable') {
        byTable[p.tableId!] = p;
      }
    }
    for (final tb in ss.tables) {
      final r = l.table[tb.id];
      if (r == null) continue;
      final p = byTable[tb.id];
      final g = ss.group(tb.groupId);
      final seatedPeople =
          p?.people.where((a) => a.seated && !a.leaving).toList() ?? const [];
      for (final a in seatedPeople) {
        if (a.pos.dy < r.center.dy) _person(c, a, r.center);
      }
      drawTable(c, r,
          dirty: tb.state == 'dirty',
          selected: g != null && g.id == selected && !g.gone);
      if (tb.state != 'dirty' && (g == null || g.gone || !g.foodDelivered)) {
        drawTableSetting(c, r, evening, t);
      }
      if (g != null && !g.gone && (g.state == 'eating' || g.foodDelivered)) {
        final eatLeft = g.state == 'eating'
            ? ((g.eatUntil - ss.tick) / math.max(1, sim.eatTicks(g.size)))
                .clamp(0.0, 1.0)
            : 1.0;
        final ch = l.chairs[tb.id] ?? const [];
        for (var i = 0; i < math.min(g.size, ch.length); i++) {
          final (o, top) = ch[i];
          drawPlate(c, Offset(o.dx, top ? r.top + 7 : r.bottom - 7),
              foodColors[(g.id + i * 3) % foodColors.length],
              left: eatLeft);
        }
      }
      for (final a in seatedPeople) {
        if (a.pos.dy >= r.center.dy) _person(c, a, r.center);
      }
      if (g != null && !g.gone) {
        s._hits.add(_Hit(r.inflate(12), groupId: g.id));
      }
    }
    // Everyone standing or walking, back to front.
    final walkers = <_Actor>[
      ...s._staff.values,
      for (final p in s._parties.values)
        for (final a in p.people)
          if (!a.seated || a.leaving) a,
    ]..sort((a, b) => a.pos.dy.compareTo(b.pos.dy));
    for (final a in walkers) {
      _person(c, a);
    }
    // Owner label.
    final owner = s._staff['owner'];
    if (owner != null) {
      final tp =
          labelPainter('YOU', 7, Colors.white, shadow: false, spacing: 1.4);
      final r = Rect.fromCenter(
          center: owner.pos.translate(0, -16),
          width: tp.width + 10,
          height: 11);
      fillRRect(c, RRect.fromRectAndRadius(r, const Radius.circular(2)),
          Palette.owner);
      tp.paint(c, r.center - Offset(tp.width / 2, tp.height / 2));
    }
    drawDoor(c, Rect.fromLTWH(0, l.lobby.top + 8, 4, l.lobby.height - 16),
        s._doorOpen);
    _lighting(c, size);
    drawOpenSign(c, Offset(l.size.width * 0.5, l.lobby.bottom - 9), true);
    _queue(c);
    _bubbles(c, t);
    _particles(c);
    _banner(c, size);
  }

  /// A quiet plaque at the start of service and near the end.
  void _banner(Canvas c, Size size) {
    String? text;
    String? sub;
    double k;
    if (ss.tick < 12) {
      text = 'Service';
      sub = 'DOORS OPEN';
      k = ss.tick / 12;
    } else if (ss.tick >= 340 && ss.tick < 354) {
      text = 'Last orders';
      sub = 'THE KITCHEN CLOSES SOON';
      k = (ss.tick - 340) / 14;
    } else {
      return;
    }
    final fade = k < 0.15 ? k / 0.15 : (k > 0.8 ? (1 - k) / 0.2 : 1.0);
    final tp = labelPainter(text, 20, Palette.ink.withValues(alpha: fade),
        serif: true, shadow: false);
    final sp = labelPainter(sub, 7.5, Palette.accent.withValues(alpha: fade),
        shadow: false, spacing: 2);
    final center = Offset(size.width / 2, l.dining.top + 52);
    final r = Rect.fromCenter(
        center: center, width: math.max(tp.width, sp.width) + 56, height: 52);
    c.drawRect(r, Paint()..color = Color.fromRGBO(14, 12, 10, 0.88 * fade));
    c.drawRect(
        r.deflate(3),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Palette.accent.withValues(alpha: 0.7 * fade));
    tp.paint(c, Offset(center.dx - tp.width / 2, r.top + 10));
    sp.paint(c, Offset(center.dx - sp.width / 2, r.bottom - 15));
  }

  void _prepTable(Canvas c, double t) {
    final last = l.stationRect.values.isEmpty
        ? 10.0
        : l.stationRect.values.map((r) => r.right).reduce(math.max);
    final room = l.sink.left - 8 - (last + 8);
    if (room < 40) return;
    final busy = ss.tasks.any((k) => k.type == 'cook' && k.started);
    drawPrepTable(c, Rect.fromLTWH(last + 8, 64, room, 15), t, busy);
  }

  void _person(Canvas c, _Actor a, [Offset? faceTo]) {
    drawPerson(c, a.pos, a.look,
        facing: faceTo != null ? (faceTo - a.pos).direction : a.facing,
        s: a.id.startsWith('g') ? 1.08 : 1.15,
        bob: a.bob,
        mood: a.mood,
        seated: a.seated,
        carryPlate: a.carryPlate,
        carryDirty: a.carryDirty,
        notepad: a.notepad,
        alpha: a.alpha,
        walk: a.moving ? a.phase : -1,
        mop: a.mop,
        box: a.box,
        foodColor: a.food);
  }

  void _kitchen(Canvas c, double t) {
    final cook = ss.tasks.where((k) => k.type == 'cook').toList();
    for (final e in l.stationRect.entries) {
      final st = e.key;
      int used = 0, queued = 0;
      for (final k in cook) {
        if (sim.content.dishes[ss.ticket(k.ticketId)?.dishId]?.station != st) {
          continue;
        }
        if (k.started) {
          used++;
        } else {
          queued++;
        }
      }
      final down = sim.stationDown(st);
      drawStation(c, e.value, st,
          cap: sim.stationCapacity(st), used: used, down: down, t: t);
      // A little sign on the wall above each station.
      final tp = labelPainter((_stationName[st] ?? st).toUpperCase(), 6.5,
          down ? Palette.bad : Palette.accent,
          weight: FontWeight.w700, shadow: false, spacing: 1.4);
      final sign = Rect.fromCenter(
          center: Offset(e.value.center.dx, 8),
          width: tp.width + 10,
          height: 10);
      tp.paint(c, sign.center - Offset(tp.width / 2, tp.height / 2));
      if (queued > 0) {
        // Order tickets waiting for this station.
        final o = Offset(e.value.right - 4, e.value.top + 2);
        for (var i = 0; i < math.min(queued, 4); i++) {
          final r =
              Rect.fromLTWH(o.dx - 6 + i * 2.5, o.dy - 8 - i * 1.5, 9, 11);
          fillRRect(c, RRect.fromRectAndRadius(r, const Radius.circular(1)),
              const Color(0xFFFFF8E1));
          strokeRRect(c, RRect.fromRectAndRadius(r, const Radius.circular(1)),
              const Color(0x55000000), 0.6);
        }
        final num = labelPainter('$queued', 9,
            queued > 3 ? const Color(0xFFC24A3A) : const Color(0xFF2A2420));
        num.paint(
            c,
            Offset(o.dx - 1 + math.min(queued, 4) * 2.5 - num.width / 2,
                o.dy - 6));
      }
    }
    // Ready plates on the pass.
    var ready = 0;
    for (final k in ss.tickets) {
      if (k.state == 'ready') {
        final g = ss.group(k.groupId);
        if (g != null && !g.gone && !g.foodDelivered) ready++;
      }
    }
    for (var i = 0; i < math.min(ready, 10); i++) {
      drawPlate(c, Offset(l.pass.left + 10 + i * 12.0, l.pass.center.dy - 1),
          foodColors[i % foodColors.length]);
    }
    // Dirty plates pile by the sink.
    final cap = sim.content.balance.i('PLATES_PER_TABLE') *
        math.max(1, ss.tables.length);
    final share = ss.dirtyDishes / cap;
    final stack = (share * 8).clamp(0, 8).round();
    for (var i = 0; i < stack; i++) {
      final o = Offset(l.sink.right - 14, l.sink.bottom - 6 - i * 2.4);
      c.drawOval(Rect.fromCenter(center: o, width: 16, height: 6),
          Paint()..color = Colors.white);
      c.drawOval(
          Rect.fromCenter(center: o, width: 16, height: 6),
          Paint()
            ..color = const Color(0x44000000)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.6);
    }
    if (share > 0.8) {
      drawBubble(c, Offset(l.sink.left - 8, l.sink.center.dy + 4), Icons.wash,
          share: 1, ring: false, r: 10);
      final tp = labelPainter(
          share > 1 ? 'No clean plates!' : 'Plates running out',
          8.5,
          Palette.bad);
      tp.paint(c, Offset(l.sink.right - tp.width, l.sink.bottom + 3));
    }
  }

  void _queue(Canvas c) {
    // Tap targets and patience bubbles for parties at the door.
    for (final p in s._parties.values) {
      if (p.state != 'waitTable' || p.removed) continue;
      final g = ss.group(p.id);
      if (g == null) continue;
      var r = Rect.fromCircle(center: p.people.first.pos, radius: 1);
      for (final a in p.people) {
        r = r.expandToInclude(
            Rect.fromCircle(center: a.pos.translate(0, -12), radius: 12));
      }
      s._hits.add(_Hit(r, groupId: g.id));
      if (g.id == selected) {
        strokeRRect(
            c,
            RRect.fromRectAndRadius(r.inflate(2), const Radius.circular(10)),
            Palette.owner,
            2.5);
      }
    }
  }

  void _bubbles(Canvas c, double t) {
    final pulse = (math.sin(t * 5) + 1) / 2;
    final taskFor = <int, Task>{}; // table → open job
    Task? seatTask;
    for (final k in ss.tasks) {
      if (k.type == 'cook' || k.type == 'pack') continue;
      if (k.type == 'seat') {
        seatTask ??= k;
        continue;
      }
      if (k.tableId != null) taskFor[k.tableId!] = k;
    }
    for (final tb in ss.tables) {
      final o = l.bubble[tb.id];
      if (o == null) continue;
      final g = ss.group(tb.groupId);
      final k = taskFor[tb.id];
      final active = g != null && !g.gone;
      final share = active && g.waiting
          ? (g.counter / math.max(1, sim.patienceLimit(g))).clamp(0.0, 1.0)
          : 0.0;
      if (k != null) {
        final mine = ss.ownerQueue.contains(k.id) || k.assignee == 'owner';
        final taken = k.started && !mine;
        final hit = drawBubble(c, o, AssetCatalog.task(k.type),
            share: share,
            ring: k.type != 'clear',
            owner: mine,
            faded: taken,
            pulse: !taken && share > 0.8 ? pulse : 0);
        if (!taken) s._hits.add(_Hit(hit, taskId: k.id));
      } else if (active && g.state == 'waitFood') {
        drawBubble(c, o, Icons.hourglass_bottom,
            share: share, pulse: share > 0.8 ? pulse : 0, r: 10);
      }
    }
    // The party first in line gets the seat job bubble.
    if (seatTask != null) {
      final p = s._parties[seatTask.groupId];
      final g = ss.group(seatTask.groupId);
      if (p != null && g != null && p.people.isNotEmpty) {
        final share =
            (g.counter / math.max(1, sim.patienceLimit(g))).clamp(0.0, 1.0);
        final mine =
            ss.ownerQueue.contains(seatTask.id) || seatTask.assignee == 'owner';
        final taken = seatTask.started && !mine;
        final hit = drawBubble(
            c, p.people.first.pos.translate(2, -20), AssetCatalog.task('seat'),
            share: share,
            owner: mine,
            faded: taken,
            pulse: share > 0.8 ? pulse : 0);
        if (!taken) s._hits.add(_Hit(hit, taskId: seatTask.id));
      }
    }
  }

  void _particles(Canvas c) {
    for (final p in s._particles) {
      final a = ((p.age - p.delay) / p.life);
      if (a < 0) continue;
      final k = a.clamp(0.0, 1.0);
      switch (p.kind) {
        case 0: // coin flying in an arc to the till
          final mid = Offset(
              (p.from.dx + p.to.dx) / 2, math.min(p.from.dy, p.to.dy) - 50);
          final e = Curves.easeIn.transform(k);
          final pos = Offset(
              (1 - e) * (1 - e) * p.from.dx +
                  2 * (1 - e) * e * mid.dx +
                  e * e * p.to.dx,
              (1 - e) * (1 - e) * p.from.dy +
                  2 * (1 - e) * e * mid.dy +
                  e * e * p.to.dy);
          drawCoin(c, pos, 4, math.cos(p.age * 14));
        case 1:
          final pos = Offset.lerp(p.from, p.to, Curves.easeOut.transform(k))!;
          final tp =
              labelPainter(p.text, 12, p.color.withValues(alpha: (1 - k * k)));
          tp.paint(c, pos - Offset(tp.width / 2, tp.height / 2));
        case 2:
        case 3:
          final pos = Offset.lerp(p.from, p.to, k)!;
          final col = p.kind == 2
              ? Color.fromRGBO(255, 255, 255, 0.16 * (1 - k))
              : Color.fromRGBO(70, 70, 70, 0.55 * (1 - k));
          fillCircle(c, pos, 2 + k * 5, col);
        case 4:
          final pos = Offset.lerp(p.from, p.to, Curves.easeOut.transform(k))!;
          fillCircle(
              c, pos, 4 + k * 5, Color.fromRGBO(120, 110, 100, 0.5 * (1 - k)));
        case 5:
          final pos = Offset.lerp(p.from, p.to, Curves.easeOut.transform(k))!;
          drawHeart(c, pos, 4, p.color.withValues(alpha: 1 - k));
        case 7:
          drawRipple(c, p.from, k);
        case 8:
          final pos = Offset.lerp(p.from, p.to, Curves.easeOut.transform(k))!;
          drawStar(
              c, pos, 3.4 * (1 - k * 0.4), p.color.withValues(alpha: 1 - k));
        case 9:
          final pos = Offset.lerp(p.from, p.to, k)!;
          final col = Color.fromRGBO(214, 40, 40, 1 - k);
          for (final (dx, dy) in [
            (-1.0, -1.0),
            (1.0, -1.0),
            (-1.0, 1.0),
            (1.0, 1.0)
          ]) {
            line(c, pos + Offset(dx * 1.2, dy * 1.2),
                pos + Offset(dx * 3.6, dy * 3.6), col, 1.4);
          }
        case 6:
          final pos = Offset.lerp(p.from, p.to, k)!;
          c.drawCircle(
              pos,
              1.5 + k * 2,
              Paint()
                ..color = Color.fromRGBO(255, 255, 255, 0.8 * (1 - k))
                ..style = PaintingStyle.stroke
                ..strokeWidth = 0.8);
      }
    }
  }

  /// The baked light layer: darkness with pools of warm light over the
  /// tables, heat lamps on the pass and cool light in the kitchen. Lunch is
  /// brighter than late evening.
  void _lighting(Canvas c, Size size) {
    final pic = s._light;
    if (pic == null) return;
    final night = ((ss.tick - 150) / 180).clamp(0.0, 1.0);
    final k = 0.42 + 0.45 * night;
    c.saveLayer(
        Offset.zero & size, Paint()..color = Color.fromRGBO(0, 0, 0, k));
    c.drawPicture(pic);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) =>
      old.ss != ss || old.selected != selected || old.l != l;
}

const _stationName = {
  'stove': 'Hob',
  'oven': 'Oven',
  'cold': 'Cold',
  'wok': 'Wok',
  'grill': 'Grill',
  'fryer': 'Fryer',
  'tandoor': 'Tandoor',
};

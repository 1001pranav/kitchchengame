part of '../sim.dart';

// Service: tick loop, group state machine, tasks, kitchen, owner (doc 02 §3.2, §6, §8).

const taskRoles = {
  'seat': ['cashier', 'server'],
  'takeOrder': ['server'],
  'cook': ['headChef', 'lineCook'],
  'deliver': ['server'],
  'bill': ['cashier', 'server'],
  'clear': ['server', 'cleaner'],
};
const standInRoles = {
  'seat': ['server'],
  'bill': ['server'],
  'takeOrder': ['cashier'],
  'deliver': ['cashier'],
  'clear': ['cashier'],
  'cook': ['prepCook'],
};
const assignOrder = ['bill', 'deliver', 'takeOrder', 'seat', 'cook', 'clear'];
const areaTasks = {
  'door': ['seat', 'bill'],
  'tables': ['takeOrder', 'clear'],
  'pass': ['deliver'],
  'dishes': <String>[],
};
const areaNames = {
  'door': 'Door & till',
  'tables': 'Tables',
  'pass': 'Pass',
  'dishes': 'Dishes'
};

class _Worker {
  final Staff s;
  final String role;
  _Worker(this.s, this.role);
}

extension _Service on Sim {
  ServiceState get ss => loc.service!;

  // ---------------------------------------------------------- start

  void _startService() {
    final l = loc;
    final fc = _forecast();
    final mult =
        b.d('DEMAND_NOISE_MIN') + b.d('DEMAND_NOISE_SPAN') * _rng.nextFloat();
    var groups = (_expectedGroups(l, state.dayIndex) * mult).round();
    final service = ServiceState(
      tables: [
        for (var i = 0; i < l.tableSeats.length; i++)
          TableRt(i + 1, l.tableSeats[i])
      ],
      favours: b.i('FAVOURS_MAX'),
      ownerArea: state.owner.restingToday ? null : state.owner.startArea,
      forecast: fc.groups,
    );
    l.service = service;
    final film = state.flag('film_crew_today');
    if (film) service.seatingStartTick = b.i('FILM_CREW_TICKS');
    service.arrivals = _rollArrivals(l, groups);
    if (film) {
      for (final a in service.arrivals) {
        if (a.tick < service.seatingStartTick)
          a.tick = service.seatingStartTick + _rng.nextInt(0, 20);
      }
      service.arrivals.sort((a, c) => a.tick.compareTo(c.tick));
    }
    if (state.flag('big_booking_today')) {
      final bt = 8 * b.i('TICKS_PER_HOUR');
      for (var i = 0; i < 3; i++) {
        service.arrivals.add(Arrival(bt, 4, 'family'));
      }
      service.arrivals.sort((a, c) => a.tick.compareTo(c.tick));
      state.flags.remove('big_booking_today');
    }
    if (state.flag('critic_next')) {
      final later = service.arrivals.where((a) => a.tick > 60).toList();
      if (later.isNotEmpty) _rng.pick(later).critic = true;
      state.flags.remove('critic_next');
    }
    // Shift target (doc 02 §8.2d).
    final rostered = l.staff.where((s) => _rosteredToday(s)).length;
    final absent =
        l.staff.where((s) => _rosteredToday(s) && !s.workingToday).length;
    final share = rostered == 0 ? 0.0 : absent / rostered;
    service.target = math.max(
        1,
        (fc.groups * (b.d('TARGET_BASE') + b.d('TARGET_PER_ABSENT') * absent))
            .round());
    if (share > 0.5)
      service.target = math.max(service.target, (fc.groups * 0.3).round());
    state.today.forecast = fc.groups;
    state.today.target = service.target;
    // A breakdown during service (doc 02 §10.1), rolled once.
    final stations = l.equipment
        .where((e) =>
            _isWorking(e) && content.equipment[e.type]!.kind == 'station')
        .toList();
    for (final e in stations) {
      if (_rng.chance(_breakChance(e) / 3)) {
        service.breakdownTick = _rng.nextInt(60, 300);
        service.breakdownEqId = e.id;
        break;
      }
    }
    // Owner energy: resting owner is absent.
    state.phase = 'service';
    emit('serviceStarted', {'groups': groups, 'target': service.target});
  }

  // ---------------------------------------------------------- helpers

  bool _isWorking(Equipment e) =>
      !e.broken && e.unavailableUntil <= state.dayIndex;

  bool _hasWorking(String type) =>
      loc.equipment.any((e) => e.type == type && _isWorking(e));

  List<_Worker> _workers() {
    final out = <_Worker>[];
    final t = loc.service?.tick ?? 0;
    for (final s in loc.staff) {
      if (!s.workingToday) continue;
      if (s.lateTick > t) continue;
      out.add(_Worker(s, loc.service?.moves['${s.id}'] ?? s.role));
    }
    return out;
  }

  int _stationCapacity(String station) {
    if ((ss.stationOffUntil[station] ?? -1) > ss.tick) return 0;
    if (station == 'cold') {
      return (ss.stationOffUntil['cold'] ?? -1) > ss.tick
          ? 0
          : b.i('COLD_SLOTS');
    }
    var n = 0;
    for (final e in loc.equipment) {
      final t = content.equipment[e.type]!;
      if (t.station == station && _isWorking(e)) n += t.slots;
    }
    return n;
  }

  bool _stationDown(String station) {
    if (station == 'cold') return (ss.stationOffUntil['cold'] ?? -1) > ss.tick;
    var n = 0;
    for (final e in loc.equipment) {
      final t = content.equipment[e.type]!;
      if (t.station == station && _isWorking(e)) n += t.slots;
    }
    return n == 0;
  }

  /// Dishes a customer can order right now.
  bool _dishOrderable(String dishId) {
    final m = loc.menu[dishId];
    if (m == null || !m.enabled) return false;
    if (ss.eightySix.contains(dishId)) return false;
    final d = content.dishes[dishId]!;
    if (_stationDown(d.station)) return false;
    for (final r in d.recipe) {
      if (loc.stockOf(r.ingredientId) < r.qty) return false;
    }
    return true;
  }

  int _patienceLimit(Group g) {
    final base = b.dmap('PATIENCE')[g.state] ?? 10;
    var env = 1.0;
    if (state.season == 'summer' && !_hasWorking('eq_ac'))
      env *= b.d('AC_BROKEN_PATIENCE');
    if (ss.patienceUntil > ss.tick) env *= ss.patienceMult;
    final seg = b.map('SEGMENTS')[g.segment] as Map;
    final limit = base *
            (seg['patienceMult'] as num).toDouble() *
            diff('DIFF_PATIENCE') *
            env +
        (g.treated ? b.i('TREAT_PATIENCE') : 0);
    return limit.round();
  }

  bool _hasTask(String type, {int? groupId, int? tableId, int? ticketId}) {
    for (final t in ss.tasks) {
      if (t.type != type) continue;
      if (groupId != null && t.groupId != groupId) continue;
      if (tableId != null && t.tableId != tableId) continue;
      if (ticketId != null && t.ticketId != ticketId) continue;
      return true;
    }
    return false;
  }

  Task _newTask(String type, {int? groupId, int? tableId, int? ticketId}) {
    final t = Task(
        id: ss.nextId++,
        type: type,
        groupId: groupId,
        tableId: tableId,
        ticketId: ticketId,
        created: ss.tick);
    ss.tasks.add(t);
    return t;
  }

  TableRt? _fittingTable(int size) {
    TableRt? best;
    for (final t in ss.tables) {
      if (t.state != 'free' || t.reserved) continue;
      if (t.seats < math.max(2, size)) continue;
      if (best == null || t.seats < best.seats) best = t;
    }
    return best;
  }

  int _eatTicks(int size) => math.min(b.i('EAT_TICKS_MAX'),
      b.i('EAT_TICKS_BASE') + b.i('EAT_TICKS_PER_PERSON') * size);

  double _effectiveSkill(_Worker w, String taskType, {bool standIn = false}) {
    var sk = w.s.skill;
    if (w.role != w.s.role) sk -= b.d('OFF_ROLE_PENALTY');
    if (standIn) sk -= b.d('STAND_IN_SKILL_PENALTY');
    // Mentor in the same role.
    for (final o in loc.staff) {
      if (o.id != w.s.id &&
          o.workingToday &&
          o.role == w.s.role &&
          o.hasTrait('trait_mentor')) {
        sk += 3;
        break;
      }
    }
    if (taskType == 'cook' &&
        w.s.role == 'lineCook' &&
        loc.staff.any((o) => o.role == 'headChef' && o.workingToday)) {
      sk += b.d('HEAD_CHEF_LINE_BONUS');
    }
    return sk.clamp(0, 100).toDouble();
  }

  int _duration(String type, double base, double skill,
      {double fatigue = 0,
      double morale = 50,
      bool standIn = false,
      bool fallback = false,
      Staff? who}) {
    var d = base *
        (standIn || fallback ? b.d('STAND_IN_TIME_MULT') : 1.0) *
        (1.5 - skill / 100);
    d *= 1 + math.max(0, fatigue - 60) / 100;
    if (who != null) {
      d *= 1 + (50 - morale) / 500;
      if (who.hasTrait('trait_perfectionist')) d *= 1.1;
      d *= ss.roleSlow[who.role] ?? 1.0;
    }
    final area = ss.ownerArea;
    if (area != null &&
        (areaTasks[area]?.contains(type) ?? false) &&
        who != null) d *= b.d('ZONE_BOOST');
    if (type == 'cook') {
      final prep =
          loc.staff.where((s) => s.role == 'prepCook' && s.workingToday).length;
      d *= 1 - b.d('PREP_BONUS') * math.min(2, prep);
      if (!_hasWorking('eq_hood')) d *= b.d('HOOD_BROKEN_COOK_MULT');
      if (area == 'pass' && who != null) d *= b.d('PASS_COOK_BOOST');
    }
    if (type == 'bill') {
      if (!_hasWorking('eq_pos')) d *= 2;
      if (ss.billMultUntil > ss.tick) d *= ss.billMult;
    }
    return math.max(1, d.round());
  }

  // ---------------------------------------------------------- tick

  void _serviceTick() {
    final l = loc;
    final s = ss;
    if (s.done) return;
    final t = s.tick;
    final today = state.today;

    // 1. Arrivals.
    while (s.arrivals.isNotEmpty && s.arrivals.first.tick <= t) {
      final a = s.arrivals.removeAt(0);
      final g = Group(
          id: s.nextId++,
          size: a.size,
          segment: a.segment,
          arriveTick: t,
          critic: a.critic);
      s.groups.add(g);
      g.totalLimit = _patienceLimit(g);
      today.groupsArrived++;
      if (s.noSeatUntil > t) {
        _walkOut(g, 'closed');
        continue;
      }
      emit('groupArrived', {'groupId': g.id, 'size': g.size});
    }

    // 2. Waiting and walk-outs.
    for (final g in s.groups) {
      if (!g.waiting) continue;
      if (g.state == 'waitTable') {
        if (g.seatTaskOpen) continue;
        if (_fittingTable(g.size) != null && s.noSeatUntil <= t) continue;
      }
      g.counter++;
      g.totalWait++;
      if (g.counter > _patienceLimit(g)) _walkOut(g, g.state);
    }

    // 3. Complete tasks.
    final finishing =
        s.tasks.where((k) => k.started && k.endTick <= t).toList();
    for (final k in finishing) {
      s.tasks.remove(k);
      _completeTask(k);
    }

    // Eating → waiting for the bill.
    for (final g in s.groups) {
      if (g.state == 'eating' && t >= g.eatUntil) {
        g.state = 'waitBill';
        g.counter = 0;
        g.totalLimit += _patienceLimit(g);
      }
    }

    // A scheduled breakdown.
    if (t == s.breakdownTick) {
      final e = l.equipmentById(s.breakdownEqId);
      if (e != null && _isWorking(e))
        _raiseIncident('inc_fryer_dies_service', subjectId: e.id, forced: true);
    }

    // 4. Generate tasks.
    _generateTasks();

    // 5. Assign.
    _assign();

    // 6. Dishes.
    _wash();

    // Owner energy, idle, favours.
    _ownerUpkeep();

    // 7. Service incidents every 30 ticks.
    if (t > 0 && t % b.i('SERVICE_INCIDENT_EVERY') == 0)
      _rollIncidents('service');

    // 8. Incident countdowns.
    for (final inc in state.openIncidents) {
      if (inc.countdown > 0) {
        inc.countdown--;
        if (inc.countdown == 0) {
          final def = content.incidents[inc.incidentId]!;
          _resolveIncident(inc, def.defaultOption, ignored: true);
        }
      }
    }

    // Rush tracking for fatigue (doc 02 §7.2).
    final waitingByRole = <String, int>{};
    for (final k in s.tasks) {
      if (k.started) continue;
      for (final r in taskRoles[k.type] ?? const <String>[]) {
        waitingByRole[r] = (waitingByRole[r] ?? 0) + 1;
      }
    }
    waitingByRole.forEach((r, n) {
      if (n > 5) s.rushRoles.add(r);
    });

    // 9. End of service.
    final present = s.groups.any((g) => !g.gone);
    if ((t >= b.i('SERVICE_TICKS') && !present && s.arrivals.isEmpty) ||
        t >= b.i('SERVICE_TICKS') + b.i('OVERTIME_TICKS_MAX')) {
      _finishService();
      return;
    }
    s.tick++;
  }

  void _generateTasks() {
    final s = ss;
    final t = s.tick;
    // Seat, in arrival order.
    if (s.noSeatUntil <= t && t >= s.seatingStartTick) {
      for (final g in s.groups) {
        if (g.state != 'waitTable' || g.seatTaskOpen) continue;
        final table = _fittingTable(g.size);
        if (table == null) continue;
        table.reserved = true;
        g.seatTaskOpen = true;
        g.tableId = table.id;
        _newTask('seat', groupId: g.id, tableId: table.id);
      }
    }
    for (final g in s.groups) {
      switch (g.state) {
        case 'waitOrder':
          if (!_hasTask('takeOrder', groupId: g.id))
            _newTask('takeOrder', groupId: g.id, tableId: g.tableId);
        case 'waitFood':
          final tickets =
              g.ticketIds.map(s.ticket).whereType<Ticket>().toList();
          final live = tickets.where((k) => k.state != 'cancel').toList();
          if (live.isEmpty) {
            // Everything they ordered became unavailable.
            _walkOut(g, 'waitFood');
            continue;
          }
          if (live.every((k) => k.state == 'ready') &&
              !_hasTask('deliver', groupId: g.id)) {
            _newTask('deliver', groupId: g.id, tableId: g.tableId);
          }
          for (final k in live) {
            if (k.state == 'wait' && !_hasTask('cook', ticketId: k.id)) {
              _newTask('cook', groupId: g.id, ticketId: k.id);
            }
          }
        case 'waitBill':
          if (!_hasTask('bill', groupId: g.id))
            _newTask('bill', groupId: g.id, tableId: g.tableId);
        default:
          break;
      }
    }
    for (final tb in s.tables) {
      if (tb.state == 'dirty' && !_hasTask('clear', tableId: tb.id))
        _newTask('clear', tableId: tb.id);
    }
  }

  bool _ownerBusy() {
    final s = ss;
    if (s.ownerBusyUntil > s.tick) return true;
    return s.tasks.any((k) => k.assignee == 'owner');
  }

  bool get _ownerPresent => !state.owner.restingToday;

  void _assign() {
    final s = ss;
    final workers = _workers();
    final busy = <int, int>{}; // staff id → active task count
    for (final k in s.tasks) {
      if (k.assignee != null && k.assignee != 'owner') {
        final id = int.parse(k.assignee!);
        busy[id] = (busy[id] ?? 0) + 1;
      }
    }
    final cookParallel = b.i('COOK_PARALLEL');
    bool idle(_Worker w) {
      final n = busy[w.s.id] ?? 0;
      if (w.role == 'headChef' || w.role == 'lineCook') return n < cookParallel;
      return n == 0;
    }

    final stationUse = <String, int>{};
    for (final k in s.tasks) {
      if (k.type == 'cook' && k.started) {
        final st = content.dishes[s.ticket(k.ticketId)!.dishId]!.station;
        stationUse[st] = (stationUse[st] ?? 0) + 1;
      }
    }
    final platesFull =
        s.dirtyDishes > b.i('PLATES_PER_TABLE') * s.tables.length;
    if (platesFull) {
      s.platesFullTicks++;
      if (s.platesFullTicks == 1) {
        emit('platesFull');
        _note('platesFull', 'Ran out of clean plates: the kitchen had to stop',
            0);
      }
    }
    final kitchenBacklog =
        s.tasks.where((k) => k.type == 'cook' && !k.started).length;
    final cooksWorking = workers
        .where((w) => w.role == 'headChef' || w.role == 'lineCook')
        .length;

    List<Task> waiting(String type) {
      final list = s.tasks
          .where((k) => k.type == type && !k.started && !k.reserved)
          .toList();
      if (type == 'cook') {
        list.sort((a, c) {
          final pa = s.ticket(a.ticketId)!.priority,
              pc = s.ticket(c.ticketId)!.priority;
          if (pa != pc) return pa.compareTo(pc);
          return a.id.compareTo(c.id);
        });
      }
      return list;
    }

    bool cookAllowed(Task k) {
      if (platesFull) return false;
      final st = content.dishes[s.ticket(k.ticketId)!.dishId]!.station;
      return (stationUse[st] ?? 0) < _stationCapacity(st);
    }

    void start(Task k, String assignee, int dur) {
      k.assignee = assignee;
      k.startTick = s.tick;
      k.endTick = s.tick + dur;
      if (k.type == 'cook') {
        final st = content.dishes[s.ticket(k.ticketId)!.dishId]!.station;
        stationUse[st] = (stationUse[st] ?? 0) + 1;
      }
    }

    bool startStaff(Task k, _Worker w,
        {bool standIn = false, bool fallback = false}) {
      if (k.type == 'cook') {
        if (!cookAllowed(k)) return false;
        if (!_beginCook(k, _effectiveSkill(w, 'cook', standIn: standIn),
            kitchenBacklog > 2 * math.max(1, cooksWorking), w.s)) {
          return true; // ticket cancelled; task consumed
        }
      }
      final base = k.type == 'cook'
          ? content.dishes[s.ticket(k.ticketId)!.dishId]!.prepTicks.toDouble()
          : b.dmap('TASK_TICKS')[k.type]!;
      final sk = _effectiveSkill(w, k.type, standIn: standIn);
      var dur = _duration(k.type, base, sk,
          fatigue: w.s.fatigue,
          morale: w.s.morale,
          standIn: standIn,
          fallback: fallback,
          who: w.s);
      if (w.s.hasTrait('trait_clumsy') && _rng.chance(0.01)) dur += 3;
      start(k, '${w.s.id}', dur);
      busy[w.s.id] = (busy[w.s.id] ?? 0) + 1;
      return true;
    }

    // Primary roles.
    for (final type in assignOrder) {
      final roleList = taskRoles[type]!;
      for (final k in waiting(type)) {
        if (type == 'cook' && !cookAllowed(k)) continue;
        _Worker? pick;
        var fallback = false;
        for (var ri = 0; ri < roleList.length && pick == null; ri++) {
          final cands =
              workers.where((w) => w.role == roleList[ri] && idle(w)).toList();
          if (cands.isEmpty) continue;
          cands.sort((a, c) {
            if (type == 'cook') {
              final na = busy[a.s.id] ?? 0, nc = busy[c.s.id] ?? 0;
              if (na != nc) return na.compareTo(nc);
            }
            final sk = c.s.skill.compareTo(a.s.skill);
            return sk != 0 ? sk : a.s.id.compareTo(c.s.id);
          });
          pick = cands.first;
          fallback = type == 'bill' && roleList[ri] == 'server';
        }
        if (pick == null) continue;
        startStaff(k, pick, fallback: fallback);
      }
    }

    // Owner: reserved queue first, then their area's jobs.
    if (_ownerPresent && !_ownerBusy()) {
      Task? next;
      while (s.ownerQueue.isNotEmpty && next == null) {
        final cand = s.task(s.ownerQueue.first);
        if (cand == null || cand.started) {
          s.ownerQueue.removeAt(0);
          continue;
        }
        if (cand.type == 'cook' && !cookAllowed(cand)) break;
        next = cand;
        s.ownerQueue.removeAt(0);
      }
      if (next == null && s.ownerArea != null) {
        final types = List<String>.of(areaTasks[s.ownerArea]!);
        if (s.ownerArea == 'pass' && cooksWorking == 0) types.add('cook');
        Task? oldest;
        for (final k in s.tasks) {
          if (k.started || k.reserved || !types.contains(k.type)) continue;
          if (k.type == 'cook' && !cookAllowed(k)) continue;
          if (oldest == null || k.id < oldest.id) oldest = k;
        }
        next = oldest;
      }
      if (next != null) {
        final ownerSkill = b.dmap('OWNER_SKILL')[next.type] ?? 60;
        if (next.type == 'cook') {
          if (_beginCook(next, ownerSkill, false, null)) {
            final base = content
                .dishes[s.ticket(next.ticketId)!.dishId]!.prepTicks
                .toDouble();
            start(next, 'owner',
                _duration('cook', base, ownerSkill) + b.i('OWNER_WALK_TICKS'));
          }
        } else {
          final base = b.dmap('TASK_TICKS')[next.type]!;
          start(next, 'owner',
              _duration(next.type, base, ownerSkill) + b.i('OWNER_WALK_TICKS'));
        }
        next.reserved = false;
      }
    }

    // Stand-ins: only for roles with nobody working, and only when idle in their own job.
    for (final type in assignOrder) {
      final primary = taskRoles[type]!;
      if (workers.any((w) =>
          primary.contains(w.role) && !(type == 'bill' && w.role == 'server')))
        continue;
      final standIns = standInRoles[type]!;
      for (final k in waiting(type)) {
        if (type == 'cook' && !cookAllowed(k)) continue;
        final cands = workers
            .where((w) => standIns.contains(w.role) && idle(w))
            .where((w) {
          // Their own tasks come first.
          for (final ot in assignOrder) {
            if ((taskRoles[ot]!.contains(w.role)) &&
                s.tasks.any((x) => x.type == ot && !x.started)) return false;
          }
          return true;
        }).toList();
        if (cands.isEmpty) break;
        cands.sort((a, c) => c.s.skill.compareTo(a.s.skill));
        startStaff(k, cands.first, standIn: true);
      }
    }
  }

  /// Consumes ingredients and sets quality. Returns false if the ticket had to be cancelled.
  bool _beginCook(Task k, double skill, bool backlog, Staff? who) {
    final s = ss;
    final ticket = s.ticket(k.ticketId)!;
    final dish = content.dishes[ticket.dishId]!;
    for (final r in dish.recipe) {
      if (loc.stockOf(r.ingredientId) < r.qty) {
        ticket.state = 'cancel';
        s.tasks.remove(k);
        final g = s.group(ticket.groupId);
        if (g != null) g.unavailable++;
        state.today.unavailable++;
        loc.menu[dish.id]?.unavailableToday++;
        if (s.eightySix.add(dish.id)) {
          emit('dishUnavailable', {'dishId': dish.id});
          _note('soldOut', '${dish.name} sold out at ${_clock(s.tick)}', 1);
        }
        return false;
      }
    }
    var qSum = 0.0, qN = 0;
    var stale = false;
    final cost = _consumeRecipe(dish, (q, daysLeft) {
      qSum += q;
      qN++;
      if (daysLeft <= 1) stale = true;
    });
    state.today.ingredientsUsedCost += cost;
    final ingQ = qN == 0 ? 60 : qSum / qN;
    final effSkill = skill < dish.skillReq ? skill - 15 : skill;
    var stationCond = 100.0;
    if (dish.station != 'cold') {
      final units = loc.equipment.where((e) =>
          content.equipment[e.type]!.station == dish.station && _isWorking(e));
      if (units.isNotEmpty)
        stationCond = units.map((e) => e.condition).reduce(math.max);
    }
    var q = 0.40 * ingQ + 0.40 * effSkill + 0.20 * stationCond;
    if (backlog) q -= 10;
    if (stale && (!_hasWorking('eq_fridge'))) q -= 15;
    if (who != null && who.hasTrait('trait_perfectionist')) q += 5;
    ticket.quality = q.clamp(0, 100).toDouble();
    ticket.state = 'cook';
    if (ticket.quality < 20 && _rng.chance(b.d('FOOD_POISON_CHANCE'))) {
      s.group(ticket.groupId)?.ill = true;
    }
    return true;
  }

  void _completeTask(Task k) {
    final s = ss;
    final g = s.group(k.groupId);
    final byOwner = k.assignee == 'owner';
    var mistake = false;
    if (byOwner) {
      state.today.ownerTasks++;
      if (state.owner.energy < b.d('OWNER_LOW_ENERGY') &&
          _rng.chance(b.d('OWNER_MISTAKE_CHANCE'))) mistake = true;
    }
    switch (k.type) {
      case 'seat':
        final table = s.table(k.tableId)!;
        table.reserved = false;
        if (g == null || g.state != 'waitTable') return;
        table.state = 'occupied';
        table.groupId = g.id;
        g.seatTaskOpen = false;
        g.state = 'waitOrder';
        g.counter = 0;
        g.totalLimit += _patienceLimit(g);
        state.today.groupsSeated++;
        emit('groupSeated', {'groupId': g.id, 'tableId': table.id});
      case 'takeOrder':
        if (g == null || g.state != 'waitOrder') return;
        _takeOrder(g);
        if (mistake) g.unavailable++;
        g.state = 'waitFood';
        g.counter = 0;
        g.totalLimit += _patienceLimit(g);
      case 'cook':
        final ticket = s.ticket(k.ticketId)!;
        if (ticket.state == 'cook') {
          ticket.state = 'ready';
          if (mistake) ticket.quality = math.max(0, ticket.quality - 30);
          emit('dishReady', {'ticketId': ticket.id});
        }
      case 'deliver':
        if (g == null || g.state != 'waitFood') return;
        if (mistake) g.unavailable++;
        g.state = 'eating';
        g.foodDelivered = true;
        g.eatUntil = s.tick + _eatTicks(g.size);
        emit('foodDelivered', {'groupId': g.id});
      case 'bill':
        if (g == null || g.state != 'waitBill') return;
        _pay(g, waitScoreZero: false, mistake: mistake);
      case 'clear':
        final table = s.table(k.tableId)!;
        table.state = 'free';
        final last = s.groups.where((x) => x.tableId == table.id).lastOrNull;
        s.dirtyDishes += (last?.size ?? 2) * 2;
        table.groupId = null;
      default:
        break;
    }
  }

  void _takeOrder(Group g) {
    final s = ss;
    final seg = b.map('SEGMENTS')[g.segment] as Map;
    final spend = (seg['spendMult'] as num).toDouble();
    final sens = (seg['priceSensitivity'] as num).toDouble();
    final chance = b.dmap('COURSE_CHANCE');
    String? choose(String course) {
      final cands = <Dish>[];
      final w = <double>[];
      for (final m in loc.menu.values) {
        final d = content.dishes[m.dishId]!;
        if (d.courseGroup != course || !_dishOrderable(d.id)) continue;
        var price = m.price.toDouble();
        if (_promoActive(loc)) price *= 0.75;
        final appeal =
            (1.6 - 0.6 * (price / (d.basePrice * _referencePriceMult())) * sens)
                .clamp(0.2, 1.4);
        cands.add(d);
        w.add(d.popularity * appeal);
      }
      if (cands.isEmpty) return null;
      return _rng.weighted(cands, w).id;
    }

    final ordered = <String>[];
    for (var p = 0; p < g.size; p++) {
      final main = choose('main');
      if (main == null) {
        g.unavailable++;
        state.today.unavailable++;
      } else {
        ordered.add(main);
      }
      for (final c in ['starter', 'side', 'sweet']) {
        if (_rng.chance(math.min(0.95, chance[c]! * spend))) {
          final d = choose(c);
          if (d != null) ordered.add(d);
        }
      }
    }
    for (final d in ordered) {
      final tk = Ticket(s.nextId++, g.id, d);
      s.tickets.add(tk);
      g.ticketIds.add(tk.id);
    }
  }

  double _satisfaction(Group g, {required bool waitZero}) {
    final s = ss;
    final delivered = g.ticketIds
        .map(s.ticket)
        .whereType<Ticket>()
        .where((k) => k.state == 'ready')
        .toList();
    final food = delivered.isEmpty
        ? 0.0
        : delivered.map((k) => k.quality).reduce((a, c) => a + c) /
            delivered.length;
    final wait = waitZero || g.totalLimit == 0
        ? 0.0
        : (100 * (1 - g.totalWait / g.totalLimit)).clamp(0, 100).toDouble();
    final seg = b.map('SEGMENTS')[g.segment] as Map;
    final sens = (seg['priceSensitivity'] as num).toDouble();
    var pi = 1.0;
    if (delivered.isNotEmpty) {
      var sum = 0.0;
      for (final k in delivered) {
        final d = content.dishes[k.dishId]!;
        sum += loc.menu[d.id]!.price / (d.basePrice * _referencePriceMult());
      }
      pi = sum / delivered.length;
      if (_promoActive(loc)) pi *= 0.75;
    }
    final value = (75 - 100 * (pi - 1) * sens).clamp(0, 100).toDouble();
    final clean = loc.hygiene;
    var sat = 0.40 * food +
        0.30 * wait +
        0.15 * value +
        0.15 * clean -
        10 * g.unavailable +
        g.satAdj;
    if (g.broughtBill) sat -= b.d('BRING_BILL_SAT');
    return sat.clamp(0, 100).toDouble();
  }

  void _pay(Group g, {required bool waitScoreZero, bool mistake = false}) {
    final s = ss;
    var payment = 0;
    for (final id in g.ticketIds) {
      final k = s.ticket(id);
      if (k == null || k.state != 'ready') continue;
      var p = loc.menu[k.dishId]!.price.toDouble();
      if (_promoActive(loc)) p *= 0.75;
      payment += p.round();
      loc.menu[k.dishId]!.soldToday++;
      state.today.foodQualitySum += k.quality;
      state.today.foodTickets++;
    }
    if (mistake) payment = (payment * 0.9).round();
    final sat = _satisfaction(g, waitZero: waitScoreZero);
    g.stars = (sat / 20).clamp(0, 5).toDouble();
    g.payment = payment;
    earn(payment, 'revenue');
    // Tips (staff, not the till).
    final hap = _outletHappiness();
    var tip =
        (payment * math.max(0, sat - 60) / 400 * (0.8 + hap / 250)).round();
    if (loc.staff.any((x) =>
        x.workingToday &&
        (x.role == 'server' || x.role == 'cashier') &&
        x.hasTrait('trait_charming'))) {
      tip = (tip * 1.25).round();
    }
    state.today.tips += tip;
    final weight = g.critic ? b.d('CRITIC_WEIGHT') : 1.0;
    state.today.starsSum += g.stars * weight;
    state.today.starsN += weight;
    state.today.groupsServed++;
    if (g.critic) {
      _note(
          'critic',
          'A food critic gave you ${g.stars.toStringAsFixed(1)} stars',
          (g.stars * 100).round());
    }
    if (g.ill) state.flags['ill_guest'] = state.dayIndex + 1;
    if (state.flag('blogger_pending') &&
        !state.flag('blogger_done') &&
        g.size <= 2) {
      _bloggerVisit(g.stars);
    }
    g.state = 'left';
    final table = s.table(g.tableId);
    if (table != null) {
      table.state = 'dirty';
    }
    emit('groupPaid', {
      'groupId': g.id,
      'amount': payment,
      'stars': g.stars,
      'tableId': g.tableId
    });
  }

  void _walkOut(Group g, String from) {
    final s = ss;
    final today = state.today;
    if (from == 'waitBill') {
      // They leave money on the table (doc 02 §6.3).
      today.walkBill++;
      _pay(g, waitScoreZero: true);
      g.state = 'walkedOut';
      return;
    }
    final seated = from != 'waitTable' && from != 'closed';
    for (final id in g.ticketIds) {
      final k = s.ticket(id);
      if (k != null && k.state == 'wait') k.state = 'cancel';
    }
    s.tasks.removeWhere(
        (k) => k.groupId == g.id && !k.started && k.type != 'clear');
    s.ownerQueue.removeWhere((id) => s.task(id) == null);
    if (seated) {
      final table = s.table(g.tableId);
      if (table != null) table.state = 'dirty';
      today.starsSum += 10 / 20;
      today.starsN += 1;
      if (from == 'waitOrder') today.walkOrder++;
      if (from == 'waitFood') today.walkFood++;
    } else {
      if (g.seatTaskOpen) {
        s.table(g.tableId)?.reserved = false;
        s.tasks.removeWhere((k) => k.type == 'seat' && k.groupId == g.id);
      }
      today.starsSum += 0.5 * (30 / 20);
      today.starsN += 0.5;
      today.walkTable++;
    }
    s.lost++;
    today.lost = s.lost;
    g.state = 'walkedOut';
    emit('groupWalkedOut',
        {'groupId': g.id, 'from': from, 'tableId': g.tableId});
  }

  void _wash() {
    final s = ss;
    final workers = _workers();
    final machine = _hasWorking('eq_dish_machine') ? 2.0 : 1.0;
    final ownerHere = _ownerPresent && s.ownerArea == 'dishes';
    var rate = 0.0;
    final washers = workers.where((w) => w.role == 'dishwasher').toList();
    for (final w in washers) {
      var r =
          b.d('WASH_RATE') * machine * (0.5 + _effectiveSkill(w, 'wash') / 100);
      if (ownerHere) r /= b.d('ZONE_BOOST');
      rate += r;
    }
    if (ownerHere) rate += b.d('WASH_RATE') * machine * (0.5 + 50 / 100);
    if (washers.isEmpty && !ownerHere && s.dirtyDishes > 0) {
      // Stand-ins: an idle cleaner or prep cook (doc 02 §6.2).
      final busyIds = s.tasks
          .where((k) => k.assignee != null)
          .map((k) => k.assignee)
          .toSet();
      for (final w in workers) {
        if ((w.role == 'cleaner' || w.role == 'prepCook') &&
            !busyIds.contains('${w.s.id}')) {
          rate += b.d('WASH_RATE') *
              machine *
              (0.5 + (w.s.skill - 15) / 100) /
              b.d('STAND_IN_TIME_MULT');
        }
      }
    }
    s.dirtyDishes = math.max(0, s.dirtyDishes - rate);
  }

  void _ownerUpkeep() {
    final s = ss;
    if (!_ownerPresent) return;
    final working =
        s.tasks.any((k) => k.assignee == 'owner') || s.ownerBusyUntil > s.tick;
    var drain = 0.0;
    if (working) {
      final cooking =
          s.tasks.any((k) => k.assignee == 'owner' && k.type == 'cook');
      drain = b.d('OWNER_ENERGY_PER_TICK') * (cooking ? 1.5 : 1);
      s.ownerIdleTicks = 0;
    } else {
      s.ownerIdleTicks++;
    }
    if (s.ownerArea == 'dishes')
      drain = math.max(drain, b.d('OWNER_ENERGY_PER_TICK'));
    state.owner.energy = math.max(0, state.owner.energy - drain);
    s.favourClock++;
    if (s.favourClock >= b.i('FAVOUR_EVERY')) {
      s.favourClock = 0;
      if (s.favours < b.i('FAVOURS_MAX')) s.favours++;
    }
  }

  void _finishService() {
    final s = ss;
    for (final g in s.groups) {
      if (g.gone) continue;
      if (g.foodDelivered) {
        _pay(g, waitScoreZero: false);
      } else {
        _walkOut(g, g.state == 'waitTable' ? 'waitTable' : 'waitFood');
      }
    }
    s.done = true;
    s.tasks.clear();
    state.phase = 'close';
    emit('serviceEnded');
    _closeDay();
  }

  String _clock(int tick) {
    final minutes = 11 * 60 + tick * 2;
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------- owner commands

  CommandResult _ownerQueue(int taskId) {
    final s = ss;
    final k = s.task(taskId);
    if (k == null || k.started)
      return CommandResult.fail(
          SimError.unknownId, 'That job has already been taken.');
    if (!_ownerPresent)
      return CommandResult.fail(SimError.locked, 'You are resting today.');
    if (s.ownerQueue.contains(taskId)) {
      s.ownerQueue.remove(taskId);
      k.reserved = false;
      return const CommandResult(true);
    }
    if (s.ownerQueue.length >= b.i('OWNER_QUEUE_MAX')) {
      return CommandResult.fail(
          SimError.limitReached, 'You already have 3 jobs lined up.');
    }
    if (k.type == 'cook' &&
        _workers().any((w) => w.role == 'headChef' || w.role == 'lineCook')) {
      return CommandResult.fail(SimError.locked,
          'Your cooks are on it. You cook only when no cook is in.');
    }
    s.ownerQueue.add(taskId);
    k.reserved = true;
    emit('ownerQueued', {'taskId': taskId});
    return const CommandResult(true);
  }

  CommandResult _rush(int groupId) {
    final s = ss;
    final g = s.group(groupId);
    if (g == null || g.state != 'waitFood')
      return CommandResult.fail(SimError.invalidValue,
          'Only a table waiting for food can be rushed.');
    if (g.rushed)
      return CommandResult.fail(SimError.limitReached, 'Already rushed.');
    if (s.favours <= 0)
      return CommandResult.fail(SimError.limitReached,
          'No favours left. One comes back every ${b.i('FAVOUR_EVERY')} ticks.');
    final tickets = g.ticketIds
        .map(s.ticket)
        .whereType<Ticket>()
        .where((k) => k.state != 'cancel')
        .toList();
    if (tickets.every((k) => k.state == 'ready'))
      return CommandResult.fail(
          SimError.invalidValue, 'Their food is already at the pass.');
    for (final k in tickets) {
      if (k.state == 'wait') k.priority = -1;
      if (k.state == 'cook') {
        for (final task in s.tasks) {
          if (task.ticketId == k.id && task.started) {
            final left = task.endTick - s.tick;
            task.endTick = s.tick + math.max(1, (left / 2).ceil());
          }
        }
      }
    }
    g.rushed = true;
    s.favours--;
    emit('favourUsed', {'kind': 'rush', 'groupId': groupId});
    return const CommandResult(true);
  }

  CommandResult _treat(int groupId) {
    final s = ss;
    final g = s.group(groupId);
    if (g == null || !g.waiting)
      return CommandResult.fail(
          SimError.invalidValue, 'Only waiting customers can be treated.');
    if (g.treated)
      return CommandResult.fail(SimError.limitReached, 'Already treated.');
    if (s.favours <= 0)
      return CommandResult.fail(SimError.limitReached, 'No favours left.');
    g.treated = true;
    g.totalLimit += b.i('TREAT_PATIENCE');
    s.favours--;
    spend(b.i('TREAT_COST'), 'other');
    emit('favourUsed', {'kind': 'treat', 'groupId': groupId});
    return const CommandResult(true);
  }

  CommandResult _bringBill(int groupId) {
    final s = ss;
    final g = s.group(groupId);
    if (g == null || g.state != 'eating')
      return CommandResult.fail(
          SimError.invalidValue, 'Only a table that is eating.');
    if (g.broughtBill)
      return CommandResult.fail(SimError.limitReached, 'Already done.');
    if (g.eatUntil - s.tick <= 3)
      return CommandResult.fail(
          SimError.invalidValue, 'They are nearly finished anyway.');
    g.eatUntil = s.tick + 2;
    g.broughtBill = true;
    emit('billBrought', {'groupId': groupId});
    return const CommandResult(true);
  }

  CommandResult _moveStaff(int staffId, String role) {
    final st = loc.staffById(staffId);
    if (st == null || !st.workingToday)
      return CommandResult.fail(SimError.unknownId);
    if (!floorRoles.contains(st.role) || !floorRoles.contains(role)) {
      return CommandResult.fail(SimError.locked,
          'Only floor staff can be moved, and nobody can be moved into the kitchen.');
    }
    if (role == st.role) {
      ss.moves.remove('$staffId');
    } else {
      ss.moves['$staffId'] = role;
    }
    emit('staffMoved', {'staffId': staffId, 'role': role});
    return const CommandResult(true);
  }
}

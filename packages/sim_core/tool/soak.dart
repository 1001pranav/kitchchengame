// Soak test: long runs over many seeds checking invariants and save/load.
// Usage: dart run tool/soak.dart [seeds] [weeks]
import 'dart:convert';

import 'package:sim_core/sim_core.dart';

import 'bots.dart';
import 'load.dart';

void check(Sim sim, String where) {
  final st = sim.state;
  for (final l in st.locations) {
    for (final b in l.stock) {
      if (b.qty < 0)
        throw StateError('$where: negative stock ${b.ingredientId}');
    }
    for (final s in l.staff) {
      if (s.morale.isNaN || s.fatigue.isNaN || s.skill.isNaN)
        throw StateError('$where: NaN staff stat ${s.name}');
      if (s.morale < 0 || s.morale > 100)
        throw StateError('$where: morale out of range ${s.morale}');
    }
    if (l.reputation.isNaN || l.reputation < 0 || l.reputation > 5)
      throw StateError('$where: rating ${l.reputation}');
    if (l.hygiene.isNaN) throw StateError('$where: hygiene NaN');
    final ss = l.service;
    if (ss != null) {
      final ids = <int>{};
      for (final t in ss.tasks) {
        if (!ids.add(t.id)) throw StateError('$where: duplicate task');
      }
      final occ = ss.tables
          .where((t) => t.state == 'occupied')
          .map((t) => t.groupId)
          .toList();
      if (occ.toSet().length != occ.length)
        throw StateError('$where: two tables, one party');
      if (ss.dirtyDishes.isNaN || ss.dirtyDishes < 0)
        throw StateError('$where: dirty dishes ${ss.dirtyDishes}');
    }
  }
  if (st.owner.energy.isNaN) throw StateError('$where: energy NaN');
}

/// Competent owner who expands at Stage 3+.
class ChainBot extends Bot {
  ChainBot() : super('competent');

  void expand(Sim sim) {
    final st = sim.state;
    if (st.stage < 3 || st.phase != 'prep') return;
    final open = st.openLocations.length;
    // Expand only from strength: a healthy cushion and a manager good enough to hire.
    final best = (List.of(st.managerApplicants)
      ..sort((a, b) => b.managerSkill.compareTo(a.managerSkill)));
    final hireable = best
        .where((m) =>
            sim.companyRating() >=
                (m.grade == 'Veteran'
                    ? 4.0
                    : (m.grade == 'Senior' ? 3.5 : 0)) &&
            m.managerSkill >= 50)
        .toList();
    if (open < 3 &&
        st.cash > 150000 &&
        hireable.isNotEmpty &&
        st.outletMarket.isNotEmpty) {
      final i = st.outletMarket
          .indexWhere((o) => o.tierId == 'good' || o.tierId == 'best');
      if (i >= 0 &&
          sim
              .apply(BuyOutlet(i, themeId: st.stage >= 5 ? 'mexican' : null))
              .ok) {
        final l = st.locations.last;
        sim.apply(SelectLocation(l.id));
        sim.apply(HireManager(hireable.first.id));
        for (final c in l.staff.where((s) => s.role == 'cashier').toList()) {
          sim.apply(Fire(c.id));
        }
      }
    }
    for (final l in st.openLocations) {
      if (st.openLocations.length < 2) break;
      sim.apply(SelectLocation(l.id));
      if (l.manager == null) {
        for (final m in List.of(st.managerApplicants)
          ..sort((a, b) => b.managerSkill.compareTo(a.managerSkill))) {
          if (sim.apply(HireManager(m.id)).ok) break;
        }
      }
      // Market it monthly, rework its menu every 8 weeks (doc 06: what keeps it profitable).
      if ((st.dayIndex + l.id) % 28 == 0 && st.cash > 20000)
        sim.apply(const StartCampaign('localAd'));
      if ((st.dayIndex + l.id) % 56 == 7 && st.cash > 20000)
        sim.apply(const ReworkMenu());
    }
    sim.apply(SelectLocation(st.ownerLocationId));
    if (st.stage >= 4 && !st.centralKitchen && st.cash > 150000)
      sim.apply(const BuildCentralKitchen());
    if (st.stage >= 5 && st.cash > 50000) sim.apply(const StartFranchise());
    // Visit the outlet you have not seen for longest, every few days.
    final stale = st.openLocations
        .where((l) => l.openDay <= st.dayIndex)
        .toList()
      ..sort((a, b) => a.lastVisitDay.compareTo(b.lastVisitDay));
    final allManaged = st.openLocations
        .every((l) => l.manager != null || l.openDay > st.dayIndex);
    if (allManaged && stale.isNotEmpty && st.dayIndex % 3 == 0) {
      sim.apply(OwnerTravel(stale.first.id));
    } else if (!allManaged) {
      sim.apply(OwnerTravel(
          st.openLocations.firstWhere((l) => l.manager == null).id));
    }
    sim.apply(SelectLocation(st.ownerLocationId));
  }

  @override
  void day(Sim sim) {
    expand(sim);
    super.day(sim);
  }
}

void main(List<String> args) {
  final content = loadContent();
  final seeds = args.isNotEmpty ? int.parse(args[0]) : 12;
  final weeks = args.length > 1 ? int.parse(args[1]) : 52;
  final themes = ['italian', 'chinese', 'mexican', 'indian', 'mixed'];
  final diffs = ['easy', 'normal', 'hard'];
  var failures = 0;
  final sw = Stopwatch()..start();
  final only = args
      .where((a) => a.startsWith('--seed='))
      .map((a) => int.parse(a.substring(7)))
      .firstOrNull;
  for (var seed = only ?? 1; seed <= (only ?? seeds); seed++) {
    final theme = themes[seed % themes.length];
    final diff = diffs[seed % diffs.length];
    final tier = content.tiers[seed % content.tiers.length].id;
    var sim = Sim.newGame(
        content: content, seed: seed, difficulty: diff, themeId: theme);
    sim.apply(BuyRestaurant(content.tiers.indexWhere((t) => t.id == tier)));
    // Fast-track some runs to the chain so the chain systems get exercised.
    if (seed % 2 == 0) {
      sim.state.stage = 3;
      sim.state.cash += 300000;
    }
    if (seed % 4 == 0) sim.state.stage = 5;
    final bot = ChainBot();
    try {
      while (sim.state.dayIndex < weeks * 7 && sim.state.phase != 'gameOver') {
        // Prep and service with an invariant check every tick.
        bot.expand(sim);
        bot.prep(sim);
        sim.apply(const StartService());
        var guard = 0;
        while (sim.state.phase == 'service' && guard++ < 1000) {
          bot.service(sim);
          check(sim, 'seed $seed day ${sim.state.dayIndex}');
        }
        if (guard >= 1000)
          throw StateError('service never ended on day ${sim.state.dayIndex}');
        bot.close(sim);
        // Save and reload now and then: the game must continue identically.
        if (sim.state.dayIndex % 11 == 5) {
          final json = jsonEncode(sim.toSave());
          sim = Sim.fromSave(content, jsonDecode(json) as Map<String, dynamic>);
          if (jsonEncode(sim.toSave()) != json)
            throw StateError('save round-trip differs');
        }
        if (sim.state.phase == 'close') {
          final d = sim.state.dayIndex;
          sim.apply(const EndDay());
          if (sim.state.phase != 'gameOver' && sim.state.dayIndex != d + 1)
            throw StateError('EndDay did not advance');
        }
      }
      if (args.contains('-v')) {
        for (final l in sim.state.locations) {
          print(
              '  ${l.name} (${l.closedForGood ? 'closed' : 'open'}) mgr ${l.manager?.grade ?? '-'} weeks: ${l.weeks.map((w) => w.operatingProfit).join(' ')}');
        }
        print(
            '  company: ${sim.state.weeks.map((w) => w.netProfit).join(' ')}');
        print(
            '  timeline: ${sim.state.timeline.map((e) => 'd${e.day} ${e.text}').take(40).join(' | ')}');
      }
      print(
          'seed $seed $theme/$diff/$tier: ${sim.state.phase} day ${sim.state.dayIndex} stage ${sim.state.stage} outlets ${sim.state.openLocations.length} cash ${sim.state.cash} ${sim.state.gameOverReason ?? ''}');
    } catch (e, st) {
      failures++;
      print(
          'seed $seed $theme/$diff/$tier FAILED at day ${sim.state.dayIndex}: $e');
      print(st.toString().split('\n').take(8).join('\n'));
    }
  }
  print('done in ${sw.elapsed.inSeconds}s, failures: $failures');
}

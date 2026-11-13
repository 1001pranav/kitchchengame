import 'dart:math' as math;

import 'model.dart';
import 'sim.dart';

/// Scripted owners (doc 06 §6.1, reduced to the owner-only levers this prototype has).
abstract class OwnerPolicy {
  String get name;
  void act(OutletSim s);
}

/// Never markets, never visits, never reworks the menu, never replaces anything.
class PassiveOwner implements OwnerPolicy {
  @override
  String get name => 'passive';
  @override
  void act(OutletSim s) {}
}

/// doc 11 §A.6: one local ad per 4 weeks, a menu rework per 8 weeks, prices at 105%,
/// plus one visit a week and replacing equipment the manager flags when cash allows.
class CompetentOwner implements OwnerPolicy {
  @override
  String get name => 'competent';
  @override
  void act(OutletSim s) {
    if (s.day == 0) s.setPrice(105);
    if (s.day % 28 == 0) s.runCampaign('localAd');
    if (s.day % 56 == 14) s.reworkMenu();
    if (s.dow == 4) s.planVisit();
    final buffer = s.fixedPerDay * 14;
    for (final e in s.equipment.where((e) => e.warned && !e.broken)) {
      final price = (s.b.map('EQUIPMENT')[e.type] as Map)['price'] as num;
      if (s.cash > buffer + price) s.replaceEquipment(e.type);
    }
    s.requests.clear();
  }
}

/// Competent, but never sets foot in the outlet (isolates neglect from marketing).
class RemoteOwner extends CompetentOwner {
  @override
  String get name => 'remote';
  @override
  void act(OutletSim s) {
    super.act(s);
    s.plannedVisits.clear();
  }
}

class RunSummary {
  final bool survived;
  final int? failWeek;
  final int finalCash;
  final List<int> weeklyProfit;
  final List<int> weeklyServed;
  final double? health5to8;
  final List<double> weeklyRep;
  final double losingDaysPerWeek;
  final double dailyProfitCv;
  final int managerDecisionsCoins;
  final double managerMeanEnd;
  RunSummary({
    required this.survived,
    required this.failWeek,
    required this.finalCash,
    required this.weeklyProfit,
    required this.weeklyServed,
    required this.health5to8,
    required this.weeklyRep,
    required this.losingDaysPerWeek,
    required this.dailyProfitCv,
    required this.managerDecisionsCoins,
    required this.managerMeanEnd,
  });
}

RunSummary runOne(
    Balance b, int seed, Grade grade, OwnerPolicy owner, int weeksToRun,
    {bool ownerRun = false}) {
  final s = OutletSim(b, seed, managerGrade: grade, ownerRun: ownerRun);
  final reps = <double>[];
  while (s.day < weeksToRun * 7 && s.gameOver == null) {
    owner.act(s);
    s.step();
    if (s.dow == 0) reps.add(s.reputation);
  }
  final profits = s.days
      .where((d) => !d.closed)
      .map((d) => d.dayProfit.toDouble())
      .toList();
  final mean =
      profits.isEmpty ? 0.0 : profits.reduce((a, c) => a + c) / profits.length;
  final sd = profits.isEmpty
      ? 0.0
      : math.sqrt(
          profits.map((p) => (p - mean) * (p - mean)).reduce((a, c) => a + c) /
              profits.length);
  return RunSummary(
    survived: s.gameOver == null,
    failWeek: s.gameOver == null ? null : s.day ~/ 7 + 1,
    finalCash: s.cash,
    weeklyProfit: s.weeks.map((w) => w.netProfit).toList(),
    weeklyServed: s.weeks.map((w) => w.served).toList(),
    health5to8: s.days.length < 56
        ? null
        : s.days
                .sublist(28, 56)
                .map((d) => d.demandHealth)
                .reduce((a, c) => a + c) /
            28,
    weeklyRep: reps,
    losingDaysPerWeek: s.weeks.isEmpty
        ? 0
        : s.weeks.map((w) => w.losingDays).reduce((a, c) => a + c) /
            s.weeks.length,
    dailyProfitCv: mean.abs() < 1 ? double.infinity : sd / mean.abs(),
    managerDecisionsCoins:
        s.weeks.expand((w) => w.managerEvents).fold(0, (a, e) => a + e.coins),
    managerMeanEnd: s.manager.mean,
  );
}

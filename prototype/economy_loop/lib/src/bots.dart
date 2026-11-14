import 'dart:math' as math;

import 'model.dart';
import 'sim.dart';

/// Scripted owners (doc 06 §6.1, reduced to the owner-only levers this prototype has).
abstract class OwnerPolicy {
  String get name;
  void act(OutletSim s);
}

/// doc 06 §6.1: never markets, visits, reworks the menu, maintains, repairs, hires or
/// covers a role; every incident card resolves by its default option.
class PassiveOwner implements OwnerPolicy {
  @override
  String get name => 'passive';
  @override
  void act(OutletSim s) => s
    ..ownerDoesChores = false
    ..ownerAnswersCards = false;
}

/// An owner-run outlet whose owner works the floor and keeps the lights on —
/// maintains, covers absences, pays for the cheap repair, refills vacancies — but never
/// markets, reworks the menu, replaces ageing kit or answers any other card (default).
/// The "does nothing clever" player of doc 06 §4's passive survival band.
class ChoresOwner implements OwnerPolicy {
  @override
  String get name => 'chores';
  @override
  void act(OutletSim s) => s.ownerAnswersCards = false;
}

/// doc 11 §A.6: one local ad per 4 weeks, a menu rework per 8 weeks, prices at 105%,
/// plus one visit a week and replacing equipment the manager flags when cash allows.
class CompetentOwner implements OwnerPolicy {
  @override
  String get name => 'competent';
  @override
  void act(OutletSim s) {
    // Days counted from opening, so a scratch outlet is not advertised while shut.
    final t = s.tradingDay;
    if (t < 0) return;
    if (t == 0) s.setPrice(105);
    // A scratch outlet's launch campaign stands in for the opening-day ad.
    if (t % 28 == 0 && !(t == 0 && s.scratch?.launchCampaign == true)) {
      s.runCampaign('localAd');
    }
    if (t % 56 == 14) s.reworkMenu();
    if (s.dow == 4) s.planVisit();
    final buffer = s.fixedPerDay * 14;
    for (final e in s.equipment.where((e) => e.warned && !e.broken)) {
      final price = (s.b.map('EQUIPMENT')[e.type] as Map)['price'] as num;
      if (s.cash > buffer + price) s.replaceEquipment(e.type);
    }
    s.requests.clear();
  }
}

/// Competent, and on taking over fixes what a sensible buyer would fix first:
/// trains the head chef until skill ≥ 50 (below that the menu cannot be reworked,
/// doc 02 §13) and replaces any unit too old to service (max condition < 75,
/// doc 11 §A.3). Applies to every route, so a scratch outlet's weak chef is trained too.
class RefitOwner extends CompetentOwner {
  @override
  String get name => 'refit';
  @override
  void act(OutletSim s) {
    super.act(s);
    if (s.tradingDay < 0) return;
    if (s.tradingDay == 0) {
      for (final e
          in s.equipment.where((e) => !e.leased && e.maxCondition < 75)) {
        s.replaceEquipment(e.type);
      }
    }
    final chef = s.crew.firstWhere((c) => c.role == 'headChef');
    if (!chef.vacant && chef.skill < 50 && s.day >= chef.trainingUntil) {
      s.trainStaff('headChef');
    }
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

/// Competent, and reacts to a bad ad: if yesterday's local ad flopped or drew a weak
/// response, tries flyers today (a different channel has no repeat penalty, doc 02 §13.1).
class AdaptiveOwner extends CompetentOwner {
  @override
  String get name => 'adaptive';
  @override
  void act(OutletSim s) {
    super.act(s);
    if (s.campaignLog.isEmpty) return;
    final last = s.campaignLog.last;
    if (last.name == 'localAd' && last.day == s.day - 1 && last.mult <= 0.5) {
      s.runCampaign('flyers');
    }
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
  final int campaigns;
  final int flops;
  final int bigHits;
  final int marketingSpend;
  final int revenue;

  /// Campaigns old enough (8 weeks) for their buzz tail to have played out.
  final List<Campaign> settledCampaigns;

  /// Operating profit per week (losing-weeks targets, doc 06 §4 manager table).
  final List<int> weeklyOperating;
  final int minCash;

  /// Share of days in weeks 1–8 with cash below one week of costs (doc 06 §4).
  final double tightDays;

  /// Lowest cash in weeks 1–8, in weeks of fixed costs.
  final double minCover8;
  final int incidents;
  final int incidentDefaults;
  final List<String> hidden;
  RunSummary({
    required this.weeklyOperating,
    required this.minCash,
    required this.tightDays,
    required this.minCover8,
    required this.incidents,
    required this.incidentDefaults,
    required this.hidden,
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
    required this.campaigns,
    required this.flops,
    required this.bigHits,
    required this.marketingSpend,
    required this.revenue,
    required this.settledCampaigns,
  });
}

RunSummary runOne(
    Balance b, int seed, Grade grade, OwnerPolicy owner, int weeksToRun,
    {bool ownerRun = false}) {
  final s = OutletSim(b, seed, managerGrade: grade, ownerRun: ownerRun);
  final reps = <double>[];
  var minCash = s.cash, tight = 0, tightOf = 0;
  var minCover = double.infinity;
  while (s.day < weeksToRun * 7 && s.gameOver == null) {
    owner.act(s);
    s.step();
    if (s.dow == 0) reps.add(s.reputation);
    minCash = math.min(minCash, s.cash);
    if (s.day <= 56) {
      tightOf++;
      if (s.cash < s.fixedPerDay * 7) tight++;
      minCover = math.min(minCover, s.cash / (s.fixedPerDay * 7));
    }
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
    campaigns: s.campaignLog.length,
    flops: s.campaignLog.where((c) => c.mult == 0).length,
    bigHits: s.campaignLog.where((c) => c.mult > 2).length,
    marketingSpend: s.weeks.fold(0, (a, w) => a + w.marketing),
    revenue: s.weeks.fold(0, (a, w) => a + w.revenue),
    settledCampaigns: s.campaignLog.where((c) => c.day + 56 <= s.day).toList(),
    weeklyOperating: s.weeks.map((w) => w.operatingProfit).toList(),
    minCash: minCash,
    tightDays: tightOf == 0 ? 0 : tight / tightOf,
    minCover8: minCover,
    incidents: s.incidents?.raised ?? 0,
    incidentDefaults: s.incidents?.defaults ?? 0,
    hidden: s.incidents?.hidden ?? const [],
  );
}

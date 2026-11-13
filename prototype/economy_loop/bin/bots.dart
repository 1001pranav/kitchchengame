import 'dart:convert';
import 'dart:io';

import 'package:economy_loop/economy_loop.dart';

/// dart run bin/bots.dart [--seeds 200] [--weeks 26]
/// Runs every manager grade under a passive and a competent owner and prints a table.
void main(List<String> args) {
  int arg(String k, int d) {
    final i = args.indexOf(k);
    return i >= 0 && i + 1 < args.length ? int.parse(args[i + 1]) : d;
  }

  final seeds = arg('--seeds', 200);
  final weeks = arg('--weeks', 26);
  final dir = File(Platform.script.toFilePath()).parent.parent.path;
  final bi = args.indexOf('--balance');
  final path = bi >= 0 ? args[bi + 1] : '$dir/data/balance.json';
  final m = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  // --set KEY=VALUE (repeatable) overrides one number, for quick lever experiments.
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] != '--set') continue;
    final kv = args[i + 1].split('=');
    m[kv[0]] = num.parse(kv[1]);
  }
  final b = Balance(m);
  final only = args.contains('--grades-only');

  int median(List<int> xs) => (xs..sort())[xs.length ~/ 2];
  double avg(Iterable<num> xs) =>
      xs.isEmpty ? double.nan : xs.fold<double>(0, (a, c) => a + c) / xs.length;
  String k(num v) => v.isNaN
      ? '-'
      : v.abs() >= 1000
          ? '${(v / 1000).toStringAsFixed(1)}k'
          : v.round().toString();

  String pct(int n, int d) =>
      d == 0 ? '-' : '${(100 * n / d).toStringAsFixed(1)}%';

  stdout.writeln('Good tier, average location, $seeds seeds x $weeks weeks\n');
  stdout.writeln(
      'owner      manager   survive  fail-wk  cash-end  profit/wk  w1-4    w9-12   w23-26  demand wk5-8  rep-end  losing d/wk  day CV  mgr-decisions/wk  ads/run  flop%  bighit%  mkt%rev');
  final configs = <(OwnerPolicy, Grade?)>[
    if (!only) (PassiveOwner(), null),
    if (!only) (CompetentOwner(), null),
    if (!only) (AdaptiveOwner(), null),
    for (final o in [
      PassiveOwner(),
      RemoteOwner(),
      CompetentOwner(),
      AdaptiveOwner()
    ])
      for (final g in Grade.values) (o, g),
  ];
  final adPool = <Campaign>[];
  for (final (owner, g) in configs) {
    {
      final runs = [
        for (var s = 1; s <= seeds; s++)
          runOne(b, s, g ?? Grade.capable, owner, weeks, ownerRun: g == null)
      ];
      if (owner is CompetentOwner && owner is! RemoteOwner) {
        adPool.addAll(runs.expand((r) => r.settledCampaigns));
      }
      final surv = runs.where((r) => r.survived).length / runs.length;
      final fails =
          runs.where((r) => !r.survived).map((r) => r.failWeek!).toList();
      double window(int a, int bEnd) => avg(runs
          .where((r) => r.weeklyProfit.length >= bEnd)
          .map((r) => avg(r.weeklyProfit.sublist(a - 1, bEnd))));
      final healthRuns = runs.where((r) => r.health5to8 != null);
      final ratio = avg(healthRuns.map((r) => r.health5to8!));
      stdout.writeln([
        owner.name.padRight(10),
        (g?.name ?? 'OWNER-RUN').padRight(9),
        '${(surv * 100).round()}%'.padLeft(7),
        (fails.isEmpty ? '-' : median(fails).toString()).padLeft(8),
        k(median(runs.map((r) => r.finalCash).toList())).padLeft(9),
        k(avg(runs.expand((r) => r.weeklyProfit))).padLeft(10),
        k(window(1, 4)).padLeft(6),
        k(window(9, 12)).padLeft(7),
        k(window(23, 26)).padLeft(7),
        (ratio.isNaN ? '-' : '${((ratio - 1) * 100).round()}%').padLeft(13),
        avg(runs
            .where((r) => r.weeklyRep.isNotEmpty)
            .map((r) => r.weeklyRep.last)).toStringAsFixed(2).padLeft(8),
        avg(runs.map((r) => r.losingDaysPerWeek))
            .toStringAsFixed(1)
            .padLeft(12),
        '${(avg(runs.map((r) => r.dailyProfitCv).where((c) => c.isFinite)) * 100).round()}%'
            .padLeft(7),
        k(avg(runs.map((r) =>
            r.managerDecisionsCoins /
            (r.weeklyProfit.isEmpty ? 1 : r.weeklyProfit.length)))).padLeft(17),
        avg(runs.map((r) => r.campaigns)).toStringAsFixed(1).padLeft(8),
        pct(runs.fold(0, (a, r) => a + r.flops),
            runs.fold(0, (a, r) => a + r.campaigns)).padLeft(6),
        pct(runs.fold(0, (a, r) => a + r.bigHits),
            runs.fold(0, (a, r) => a + r.campaigns)).padLeft(8),
        pct(runs.fold(0, (a, r) => a + r.marketingSpend),
            runs.fold(0, (a, r) => a + r.revenue)).padLeft(8),
      ].join(' '));
    }
  }

  // Return on spend (doc 02 §13.2), pooled over the competent and adaptive owners.
  stdout.writeln(
      '\nAd returns: campaigns at least 8 weeks old, owners who market and visit\n');
  stdout.writeln(
      'campaign   outcome         runs   spend  extra groups  extra profit  return  net gain');
  void row(String name, String outcome, Iterable<Campaign> cs) {
    if (cs.isEmpty) return;
    final spend = avg(cs.map((c) => c.spend));
    final profit = avg(cs.map((c) => c.extraProfit));
    stdout.writeln([
      name.padRight(10),
      outcome.padRight(13),
      cs.length.toString().padLeft(6),
      k(spend).padLeft(7),
      avg(cs.map((c) => c.extraGroups)).toStringAsFixed(1).padLeft(13),
      k(profit).padLeft(13),
      (spend <= 0 ? '-' : 'x${(profit / spend).toStringAsFixed(2)}').padLeft(7),
      k(profit - spend).padLeft(9),
    ].join(' '));
  }

  for (final name in ['localAd', 'flyers', 'promoDay']) {
    final cs = adPool.where((c) => c.name == name).toList();
    row(name, 'all', cs);
    for (final o in cs.map((c) => c.outcome).toSet().toList()..sort()) {
      row('', o, cs.where((c) => c.outcome == o));
    }
  }
}

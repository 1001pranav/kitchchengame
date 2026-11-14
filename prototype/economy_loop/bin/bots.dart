import 'dart:convert';
import 'dart:math' as math;
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
  final routesOnly = args.contains('--routes-only');
  // --no-routes: skip the 104-week second-outlet and opening-routes tables.
  final noRoutes = args.contains('--no-routes');

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

  // Opening routes (doc 02 §15.9, doc 06 §4 opening-route targets): the same bot opens a
  // later outlet by buying a running Good outlet or by building one from scratch.
  // Paid from company cash (no loan, no bankruptcy). "Cash up front" includes the
  // scratch lease deposit; payback and net position leave it out because it comes back.
  // Weeks count from the decision day, so a scratch build's closed weeks are included.
  void openingRoutes() {
    if (!b.has('SCRATCH_FITOUT')) return;
    const horizon = 104;
    final price =
        (b.i('TAKEOVER_PRICE_GOOD') * b.d('TAKEOVER_MARKET_PRICE_FACTOR'))
            .round();
    final routes = <(String, ScratchPlan?)>[
      ('buy running', null),
      ('std + new', const ScratchPlan('std+new', 'standard', EquipMode.buyNew)),
      (
        'basic + 2nd-hand',
        const ScratchPlan('basic+2nd', 'basic', EquipMode.secondHand)
      ),
      (
        'basic + leased',
        const ScratchPlan('basic+lease', 'basic', EquipMode.lease)
      ),
    ];
    stdout.writeln(
        '\nOpening routes: a later Good-size outlet from company cash, '
        '$seeds seeds x $horizon weeks (buy price ${k(price)})\n');
    stdout.writeln(
        'owner      manager   route             up-front  1st profit wk  '
        'max tied up  w1-26/wk  w27-52/wk  payback wk  paid by 52  crisis<=26  net wk52  net wk104');
    for (final owner in [
      CompetentOwner(),
      RefitOwner(),
      if (!routesOnly) RemoteOwner()
    ]) {
      for (final g in [Grade.capable, Grade.senior, Grade.veteran]) {
        for (final (label, plan) in routes) {
          final paybacks = <int>[], firstProfit = <int>[];
          final net52 = <int>[], net104 = <int>[], tiedUp = <int>[];
          final first = <int>[], second = <int>[];
          var crisis = 0, upFront = 0;
          for (var seed = 1; seed <= seeds; seed++) {
            final s = OutletSim(b, seed, managerGrade: g, scratch: plan);
            s.cash += 10000000;
            while (s.day < horizon * 7 && s.gameOver == null) {
              owner.act(s);
              s.step();
            }
            final invested = plan == null ? price : s.investment;
            upFront = plan == null ? price : s.investment + s.deposit;
            final ws =
                s.weeks.map((w) => w.operatingProfit - w.inherited).toList();
            first.addAll(ws.take(26));
            second.addAll(ws.skip(26).take(26));
            var cum = 0, wk = 999, worst = 0;
            for (var i = 0; i < ws.length; i++) {
              cum += ws[i];
              worst = math.min(worst, cum);
              if (cum >= invested && wk == 999) wk = i + 1;
              if (i == 51) net52.add(cum - invested);
            }
            net104.add(cum - invested);
            // Most company cash the outlet ever has tied up: up-front money (deposit
            // included) plus the deepest dip in its running profit.
            tiedUp.add(upFront - worst);
            paybacks.add(wk);
            final fp = ws.indexWhere((p) => p > 0);
            firstProfit.add(fp < 0 ? 999 : fp + 1);
            // Crisis (doc 02 §15.7): 4 losing weeks in a row by week 26, after the
            // opening period (a scratch outlet's ramp is not a crisis).
            var run = 0, hit = false;
            for (var i = s.openingEndWeek; i < math.min(26, ws.length); i++) {
              run = ws[i] < 0 ? run + 1 : 0;
              if (run >= 4) hit = true;
            }
            if (hit) crisis++;
          }
          String wk(int w) => w > horizon ? '>$horizon' : '$w';
          stdout.writeln([
            owner.name.padRight(10),
            g.name.padRight(9),
            label.padRight(17),
            k(upFront).padLeft(8),
            wk(median(List.of(firstProfit))).padLeft(14),
            k(median(tiedUp)).padLeft(12),
            k(avg(first)).padLeft(9),
            k(avg(second)).padLeft(10),
            wk(median(List.of(paybacks))).padLeft(11),
            pct(paybacks.where((w) => w <= 52).length, seeds).padLeft(11),
            pct(crisis, seeds).padLeft(11),
            k(median(net52)).padLeft(9),
            k(median(net104)).padLeft(10),
          ].join(' '));
        }
      }
    }
  }

  // --routes-only: just the opening-routes table, competent owner (for lever sweeps).
  if (routesOnly) {
    openingRoutes();
    return;
  }

  stdout.writeln('Good tier, average location, $seeds seeds x $weeks weeks\n');
  stdout.writeln(
      'owner      manager   survive  fail-wk  cash-end  profit/wk  w1-4    w9-12   w23-26  demand wk5-8  rep-end  losing d/wk  day CV  mgr-decisions/wk  ads/run  flop%  bighit%  mkt%rev');
  final configs = <(OwnerPolicy, Grade?)>[
    if (!only) (PassiveOwner(), null),
    if (!only) (ChoresOwner(), null),
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
  final kept = <String, List<RunSummary>>{};
  for (final (owner, g) in configs) {
    {
      final runs = [
        for (var s = 1; s <= seeds; s++)
          runOne(b, s, g ?? Grade.capable, owner, weeks, ownerRun: g == null)
      ];
      kept['${owner.name}/${g?.name ?? 'owner-run'}'] = runs;
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

  // Survival, incidents and hidden problems (doc 06 §4, doc 05).
  if (!only && b.has('INCIDENTS') && b.d('INCIDENTS') > 0) {
    stdout.writeln(
        '\nSurvival, incidents and hidden problems ($seeds seeds x $weeks weeks)\n');
    stdout.writeln(
        'owner      manager   survive  fail-wk  min cash  tight d wk1-8  incidents/wk  by default');
    const rows = [
      'passive/owner-run',
      'chores/owner-run',
      'competent/owner-run',
      'remote/senior',
      'competent/senior',
      'remote/veteran',
      'competent/veteran',
    ];
    for (final key in rows) {
      final runs = kept[key]!;
      final fails =
          runs.where((r) => !r.survived).map((r) => r.failWeek!).toList();
      final inc = runs.fold(0, (a, r) => a + r.incidents);
      final wks = runs.fold(0, (a, r) => a + r.weeklyProfit.length);
      final parts = key.split('/');
      stdout.writeln([
        parts[0].padRight(10),
        (parts[1] == 'owner-run' ? 'OWNER-RUN' : parts[1]).padRight(9),
        pct(runs.where((r) => r.survived).length, runs.length).padLeft(7),
        (fails.isEmpty ? '-' : median(fails).toString()).padLeft(8),
        k(median(runs.map((r) => r.minCash).toList())).padLeft(9),
        '${(avg(runs.map((r) => r.tightDays)) * 100).round()}%'.padLeft(14),
        (inc / math.max(1, wks)).toStringAsFixed(1).padLeft(13),
        pct(runs.fold(0, (a, r) => a + r.incidentDefaults), inc).padLeft(11),
      ].join(' '));
    }
    stdout.writeln('\nSurvival by hidden problem drawn (Good tier draws 2)\n');
    final names = kept['competent/owner-run']!
        .expand((r) => r.hidden)
        .toSet()
        .toList()
      ..sort();
    stdout.writeln(
        'owner      manager   ${names.map((n) => n.padLeft(15)).join(' ')}');
    for (final key in rows) {
      final runs = kept[key]!;
      final parts = key.split('/');
      stdout.writeln([
        parts[0].padRight(10),
        (parts[1] == 'owner-run' ? 'OWNER-RUN' : parts[1]).padRight(9),
        for (final n in names)
          () {
            final with_ = runs.where((r) => r.hidden.contains(n)).toList();
            return pct(with_.where((r) => r.survived).length, with_.length)
                .padLeft(15);
          }(),
      ].join(' '));
    }
  }

  // Manager targets (doc 06 §4): skill-80 manager, owner never visits.
  if (!only) {
    stdout.writeln(
        '\nWeeks with negative operating profit, owner never visits (doc 06 §4 manager targets)\n');
    stdout.writeln('owner      manager   weeks 1-12  weeks 13-26');
    for (final key in ['remote/senior', 'remote/veteran']) {
      final runs = kept[key]!;
      String share(int a, int z) {
        final ws =
            runs.expand((r) => r.weeklyOperating.skip(a).take(z - a)).toList();
        return pct(ws.where((w) => w < 0).length, ws.length);
      }

      final parts = key.split('/');
      stdout.writeln('${parts[0].padRight(10)} ${parts[1].padRight(9)} '
          '${share(0, 12).padLeft(10)} ${share(12, 26).padLeft(12)}');
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
  // Buying a running Good outlet as a later outlet (doc 02 §15.9 route A, doc 06 §4
  // opening-route targets). The company funds it from cash, so the outlet never goes
  // bankrupt on its own and pays no loan; payback = first week its cumulative operating
  // profit covers the purchase price. Hidden problems are not modelled, so real payback
  // will be somewhat slower.
  if (!only && !noRoutes && b.has('TAKEOVER_PRICE_GOOD')) {
    final price =
        (b.i('TAKEOVER_PRICE_GOOD') * b.d('TAKEOVER_MARKET_PRICE_FACTOR'))
            .round();
    const horizon = 104;
    stdout.writeln(
        '\nSecond outlet: buy a running Good outlet for ${k(price)} from company cash, $horizon weeks\n');
    stdout.writeln(
        'owner      manager   op profit/wk  w1-26   w27-52  median payback wk  paid back by wk 52');
    for (final owner in [RemoteOwner(), CompetentOwner()]) {
      for (final g in [Grade.capable, Grade.senior, Grade.veteran]) {
        final paybacks = <int>[];
        final all = <int>[], first = <int>[], second = <int>[];
        for (var seed = 1; seed <= seeds; seed++) {
          final s = OutletSim(b, seed, managerGrade: g);
          s.cash += 10000000;
          while (s.day < horizon * 7 && s.gameOver == null) {
            owner.act(s);
            s.step();
          }
          final ws =
              s.weeks.map((w) => w.operatingProfit - w.inherited).toList();
          all.addAll(ws);
          first.addAll(ws.take(26));
          second.addAll(ws.skip(26).take(26));
          var cum = 0, wk = 999;
          for (var i = 0; i < ws.length; i++) {
            cum += ws[i];
            if (cum >= price) {
              wk = i + 1;
              break;
            }
          }
          paybacks.add(wk);
        }
        final med = median(List.of(paybacks));
        stdout.writeln([
          owner.name.padRight(10),
          g.name.padRight(9),
          k(avg(all)).padLeft(13),
          k(avg(first)).padLeft(6),
          k(avg(second)).padLeft(8),
          (med > horizon ? '>$horizon' : '$med').padLeft(18),
          pct(paybacks.where((w) => w <= 52).length, paybacks.length)
              .padLeft(19),
        ].join(' '));
      }
    }
  }

  if (!only && !noRoutes) openingRoutes();
}

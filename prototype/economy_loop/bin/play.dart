import 'dart:convert';
import 'dart:io';

import 'package:economy_loop/economy_loop.dart';

/// dart run bin/play.dart [--seed 7] [--balance data/balance-proposal.json]
/// You own one Good-tier outlet and are mostly away; a manager runs it day to day.
const _dows = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String money(num v) {
  final s = v
      .abs()
      .round()
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',');
  return v < 0 ? '−$s' : s;
}

String pct(double v) => '${(v * 100).round()}%';
String signedPct(double v) =>
    '${v >= 0 ? '+' : '−'}${(v.abs() * 100).toStringAsFixed(1)}%';

void main(List<String> args) {
  String? opt(String k) {
    final i = args.indexOf(k);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final dir = File(Platform.script.toFilePath()).parent.parent.path;
  final path = opt('--balance') ?? '$dir/data/balance.json';
  final b = Balance(
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>);
  final seed = int.parse(
      opt('--seed') ?? '${DateTime.now().millisecondsSinceEpoch % 100000}');
  final s = OutletSim(b, seed);

  stdout.writeln('''
KITCHEN CHAIN — economy loop prototype (seed $seed, ${path.split('/').last})
You bought a Good-tier Italian restaurant in an average street for 150,000:
70,000 of it is a loan at ${money(s.weeklyInstalment)}/week, and you have ${money(s.cash)} cash left.
You are not on the floor. ${s.manager.name} runs it day to day:
  ${s.manager.describe(exact: false)}
Rent, wages and the loan never stop. Customers forget you unless you give them a reason.
Type "help" for commands, or just press Enter to play the next day.
''');
  _status(s);

  while (true) {
    if (s.gameOver != null) {
      stdout.writeln('\nGAME OVER: ${s.gameOver}');
      _weeklyReport(s, all: true);
      return;
    }
    stdout.write('\n${_dows[s.dow]} wk${s.day ~/ 7 + 1} > ');
    final line = stdin.readLineSync();
    if (line == null) return;
    final parts = line.trim().split(RegExp(r'\s+'));
    final cmd = parts.first.toLowerCase();
    final arg = parts.length > 1 ? parts[1] : null;
    switch (cmd) {
      case '' || 'n' || 'next':
        final n = int.tryParse(arg ?? '') ?? 1;
        for (var i = 0; i < n && s.gameOver == null; i++) {
          _playDay(s);
        }
      case 'w' || 'week':
        do {
          _playDay(s, quiet: true);
        } while (s.dow != 0 && s.gameOver == null);
      case 'price':
        stdout.writeln(s.setPrice(int.tryParse(arg ?? '') ?? -1));
      case 'flyers':
        stdout.writeln(s.runCampaign('flyers'));
      case 'ad':
        stdout.writeln(s.runCampaign('localAd'));
      case 'promo':
        stdout.writeln(s.runCampaign('promoDay'));
      case 'rework':
        stdout.writeln(s.reworkMenu());
      case 'visit':
        stdout.writeln(s.planVisit());
      case 'replace':
        stdout.writeln(s.replaceEquipment(arg ?? ''));
      case 'repay':
        stdout.writeln(s.repay(int.tryParse(arg ?? '') ?? 0));
      case 'managers':
        stdout.writeln('Current: ${s.manager.describe()}');
        for (var i = 0; i < s.applicants.length; i++) {
          stdout.writeln(
              '  [${i + 1}] ${s.applicants[i].describe(exact: false)}');
        }
        stdout.writeln(
            'New applicants every ${b.i('MANAGER_APPLICANT_DAYS')} days. "hire N" replaces your manager.');
      case 'hire':
        stdout.writeln(s.hireManager((int.tryParse(arg ?? '') ?? 0) - 1));
      case 'kit' || 'equipment':
        for (final e in s.equipment) {
          stdout.writeln(
              '  ${e.type.padRight(12)} condition ${e.condition.round().toString().padLeft(3)}'
              ' / max ${e.maxCondition.round()}  age ${(e.ageDays / 336).toStringAsFixed(1)}y'
              '${e.broken ? '  BROKEN until ${_dows[e.readyDay % 7]}' : ''}');
        }
      case 's' || 'status':
        _status(s);
      case 'r' || 'report':
        _weeklyReport(s, all: arg == 'all');
      case 'help' || '?':
        stdout.writeln('''
  Enter / next [n]   play 1 (or n) days        week      play to the end of the week
  status             where things stand        report    last weekly report ("report all")
  price <60-180>     menu price, % of base     visit     be at the outlet today (max ${b.i('PROTO_OWNER_VISITS_PER_WEEK')}/week)
  flyers (400)       +8% for 3 days, buzz+10   ad (1,500)  +15% for 7 days, buzz+25
  promo (prices −25% today) +50% today, buzz+15
  rework (800)       menu freshness to 100%, buzz+10; head chef off the line today
  equipment          condition of each unit    replace <type>   buy new (full price)
  managers           see applicants            hire <n>   swap manager (7 days' severance)
  repay <amount>     pay the loan down early   quit''');
      case 'q' || 'quit':
        return;
      default:
        stdout.writeln('Unknown command. Type "help".');
    }
  }
}

void _playDay(OutletSim s, {bool quiet = false}) {
  final r = s.step();
  final d = _dows[r.day % 7];
  if (r.closed) {
    stdout.writeln('$d: CLOSED (inspection).');
  } else if (!quiet) {
    final lost = r.walkouts + r.turnedAway;
    stdout.writeln(
        '$d: ${r.demand} groups came, ${r.served} ate${lost > 0 ? ', $lost left unserved' : ''}'
        ' · revenue ${money(r.revenue)} · day ${money(r.dayProfit)}'
        ' (needed ${r.breakEvenGroups} to break even)${r.ownerPresent ? ' · you were there' : ''}');
  } else {
    stdout.writeln('$d: ${r.served} served · day ${money(r.dayProfit)}');
  }
  for (final n in r.notes) {
    stdout.writeln('     · $n');
  }
  if (r.day % 7 == 6) {
    _weeklyReport(s);
    _status(s);
  }
}

void _status(OutletSim s) {
  stdout.writeln('''
  Cash ${money(s.cash)} · loan ${money(s.loanOutstanding)} (${money(s.weeklyInstalment)}/wk) · reputation ${s.reputation.toStringAsFixed(2)}★
  Demand health: buzz ${pct(s.buzz)} (${signedPct(s.buzzFactor - 1)}) · menu freshness ${pct(s.freshness)} (${signedPct(s.freshnessFactor - 1)}) · rivals ${signedPct(s.competitionFactor - 1)}
  Hygiene ${s.hygiene.round()} · crew mood ${s.crewMorale.round()} · prices ${pct(s.priceIndex)} · standards slipping ${pct(s.slack)} (${s.day - s.lastVisitDay} days since you visited)
  Manager ${s.manager.name}: ${s.manager.grade.name}, ${money(s.manager.wage)}/day · fixed costs ≈ ${money(s.fixedPerDay)}/day''');
  if (s.requests.isNotEmpty) {
    stdout.writeln('  Waiting for you:');
    for (final r in s.requests) {
      stdout.writeln('   - $r');
    }
    s.requests.clear();
  }
}

void _weeklyReport(OutletSim s, {bool all = false}) {
  if (s.weeks.isEmpty) {
    stdout.writeln('No full week yet.');
    return;
  }
  final list = all ? s.weeks : [s.weeks.last];
  for (final w in list) {
    final n = s.weeks.indexOf(w) + 1;
    stdout.writeln('''
  ── Week $n ─────────────────────────────
  Revenue ${money(w.revenue).padLeft(8)}   (${w.served} groups served, ${w.walkouts} lost)
  Food    ${money(-w.ingredients).padLeft(8)}   Crew wages ${money(-w.wages)}   Manager ${money(-w.managerWage)}
  Rent    ${money(-w.rent).padLeft(8)}   Utilities ${money(-w.utilities)}   Upkeep ${money(-w.upkeep)}
  Market. ${money(-w.marketing).padLeft(8)}   Other ${money(-w.other)}   Loan interest ${money(-w.interest)}
  Operating profit ${money(w.operatingProfit)} · loan instalment paid ${money(w.loanPaid)} · losing days ${w.losingDays}/7''');
    if (!all) {
      final byKey = <String, (int, int)>{};
      for (final e in w.managerEvents) {
        final (c, sum) = byKey[e.key] ?? (0, 0);
        byKey[e.key] = (c + 1, sum + e.coins);
      }
      if (byKey.isNotEmpty) {
        final total = byKey.values.fold(0, (a, v) => a + v.$2);
        stdout.writeln("  Manager's decisions: ${money(total)}");
        for (final k in byKey.keys.toList()..sort()) {
          stdout.writeln(
              '    ${_label[k] ?? k} ×${byKey[k]!.$1}: ${money(byKey[k]!.$2)}');
        }
      }
    }
  }
}

const _label = {
  'managerCoveredAbsence': 'called in cover for a sick shift',
  'managerRotaError': 'left someone off the rota',
  'managerOverOrdered': 'over-ordered stock (waste)',
  'managerUnderOrdered': 'under-ordered (dishes sold out)',
  'managerSkippedMaintenance': 'skipped servicing',
  'managerCaughtWearEarly': 'warned you before a breakdown',
  'managerCheapRepairFailed': 'cheap repair failed again',
  'managerMissedRequest': 'did not get a vacancy filled',
};

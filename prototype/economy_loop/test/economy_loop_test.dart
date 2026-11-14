import 'dart:math' as math;

import 'dart:convert';
import 'dart:io';

import 'package:economy_loop/economy_loop.dart';
import 'package:test/test.dart';

Balance load([String f = 'data/balance.json']) =>
    Balance(jsonDecode(File(f).readAsStringSync()) as Map<String, dynamic>);

void main() {
  test('SimRng matches the doc 08 §5 test vector', () {
    expect(SimRng(1).nextU32(), 270369);
    expect(SimRng(0).state, 0x9E3779B9);
  });

  test('missing balance key names the key', () {
    expect(() => Balance({}).d('BASE_FOOTFALL'),
        throwsA(predicate((e) => e.toString().contains('BASE_FOOTFALL'))));
  });

  test('manager wage curve and grades (doc 02 §15.14)', () {
    final m = Manager('x', 'all-rounder', 50, 50, 50, 90, 0);
    expect(m.wage, (260 * (0.4 + 1.2 * 0.5)).round());
    expect(gradeOf(34.9), Grade.trainee);
    expect(gradeOf(35), Grade.junior);
    expect(gradeOf(80), Grade.veteran);
  });

  test('equipment max condition falls with age (doc 11 §A.3)', () {
    expect(Equipment('oven', 50, 0).maxCondition, 95);
    expect(Equipment('oven', 50, 168 * 3).maxCondition, 80);
    expect(Equipment('oven', 50, 168 * 20).maxCondition, 60);
  });

  test('forecast at neutral health is footfall × rep × dow (doc 02 §5.1)', () {
    final s = OutletSim(load(), 1);
    // day 0: Monday 0.80, spring 1.00, rep 3.5 -> 1.125, buzz 0.5 & freshness 0.6 -> 1.0
    expect(s.forecast(), closeTo(55 * 1.125 * 0.8, 1e-9));
  });

  test(
      'buzz decays to zero without marketing and an ad restores it (doc 11 §A.1)',
      () {
    final s = OutletSim(load(), 2, managerGrade: Grade.veteran);
    // BUZZ_DECAY 0.01 from 0.5: gone after 50 days (balance-log entry 1).
    for (var i = 0; i < 55; i++) {
      s.step();
    }
    expect(s.buzz, 0);
    s.runCampaign('localAd');
    // The outcome roll scales the gain: 0 (flop) to 3.5× (big hit), capped at 1.
    expect(s.buzz, closeTo(math.min(1, 0.25 * s.lastCampaignMult), 1e-9));
  });

  test('loan instalment matches doc 06 §3 Good tier (~1,630)', () {
    expect(OutletSim(load(), 3).weeklyInstalment, 1626);
  });

  test('same seed and commands give identical results', () {
    String run() {
      final s = OutletSim(load(), 42);
      final out = StringBuffer();
      for (var i = 0; i < 70 && s.gameOver == null; i++) {
        if (i % 28 == 0) s.runCampaign('localAd');
        out.write('${s.step().dayProfit},');
      }
      return '$out ${s.cash} ${s.reputation}';
    }

    expect(run(), run());
  });

  test('a better manager beats a worse one on average (current spec values)',
      () {
    final b = load();
    double mean(Grade g) {
      var total = 0;
      for (var seed = 1; seed <= 40; seed++) {
        total += runOne(b, seed, g, CompetentOwner(), 12).finalCash;
      }
      return total / 40;
    }

    expect(mean(Grade.veteran), greaterThan(mean(Grade.trainee)));
  });

  test('a managed outlet has no cashier; an owner-run one does (doc 02 §15.15)',
      () {
    final managed = OutletSim(load(), 5, managerGrade: Grade.capable);
    final ownerRun = OutletSim(load(), 5, ownerRun: true);
    expect(managed.crew.any((c) => c.role == 'cashier'), isFalse);
    expect(ownerRun.crew.any((c) => c.role == 'cashier'), isTrue);
  });

  test('neglect grace grows with the square of manager skill (doc 02 §15.5)',
      () {
    int daysUntilSlack(Grade g) {
      final s = OutletSim(load(), 9, managerGrade: g);
      for (var d = 0; d < 200; d++) {
        if (s.gameOver != null) return -1;
        if (s.slack > 0) return d;
        s.step();
      }
      return 200;
    }

    final trainee = daysUntilSlack(Grade.trainee);
    expect(trainee, inInclusiveRange(5, 20));
    // A veteran-run outlet is still within grace when a trainee-run one is slipping.
    final v = OutletSim(load(), 9, managerGrade: Grade.veteran);
    for (var d = 0; d < trainee + 20 && v.gameOver == null; d++) {
      v.step();
    }
    expect(v.slack, 0);
  });

  test('net profit is operating profit minus loan interest (doc 02 §14.2)', () {
    final s = OutletSim(load(), 11, ownerRun: true);
    for (var d = 0; d < 7; d++) {
      s.step();
    }
    final w = s.weeks.first;
    expect(w.interest, greaterThan(0));
    expect(w.netProfit, w.operatingProfit - w.interest);
  });

  test(
      'hygiene settles instead of pinning at 100 (doc 02 §12 proportional rule)',
      () {
    final s = OutletSim(load(), 13, ownerRun: true);
    for (var d = 0; d < 84 && s.gameOver == null; d++) {
      s.step();
    }
    expect(s.hygiene, inInclusiveRange(55, 95));
  });

  test('mastery starts at 65 and is full at 90 (doc 02 §15.16)', () {
    final s = OutletSim(load(), 17, managerGrade: Grade.capable);
    expect(s.mastery(65), 0);
    expect(s.mastery(77.5), closeTo(0.5, 1e-9));
    expect(s.mastery(95), 1);
  });

  test('a veteran pays less for ingredients than a junior on average', () {
    double foodShare(Grade g) {
      var ing = 0, rev = 0;
      for (var seed = 1; seed <= 20; seed++) {
        final s = OutletSim(load(), seed, managerGrade: g);
        for (var d = 0; d < 28 && s.gameOver == null; d++) {
          s.step();
        }
        for (final w in s.weeks) {
          ing += w.ingredients;
          rev += w.revenue;
        }
      }
      return ing / rev;
    }

    expect(foodShare(Grade.veteran), lessThan(foodShare(Grade.junior) - 0.02));
  });

  test('ad outcomes vary but average out near the listed effect (doc 02 §13.1)',
      () {
    final counts = <double, int>{};
    var sum = 0.0;
    const n = 4000;
    for (var seed = 1; seed <= n; seed++) {
      final s = OutletSim(load(), seed, ownerRun: true);
      s.runCampaign('localAd');
      counts[s.lastCampaignMult] = (counts[s.lastCampaignMult] ?? 0) + 1;
      sum += s.lastCampaignMult;
    }
    expect(counts.keys.toSet(), {0.0, 0.5, 1.0, 1.5, 3.5});
    expect(counts[0.0]! / n,
        inInclusiveRange(0.08, 0.18)); // flops are real but not common
    expect(counts[3.5]! / n, inInclusiveRange(0.05, 0.14)); // so are big hits
    expect(sum / n, inInclusiveRange(0.95, 1.2));
  });

  test('repeating the same ad too soon makes a flop more likely', () {
    var first = 0, second = 0;
    for (var seed = 1; seed <= 3000; seed++) {
      final s = OutletSim(load(), seed, ownerRun: true);
      s.runCampaign('flyers');
      if (s.lastCampaignMult == 0) first++;
      s.runCampaign('flyers');
      if (s.lastCampaignMult == 0) second++;
    }
    expect(second, greaterThan(first * 1.5));
  });

  test(
      'return on spend: a flop returns nothing, a working ad returns something (doc 02 §13.2)',
      () {
    var sawFlop = false, sawWorking = false;
    for (var seed = 1; seed <= 60 && !(sawFlop && sawWorking); seed++) {
      final s = OutletSim(load(), seed, ownerRun: true);
      s.runCampaign('localAd');
      for (var d = 0; d < 60; d++) {
        s.step();
      }
      final c = s.campaignLog.single;
      final served = s.weeks.fold(0, (a, w) => a + w.served);
      expect(c.extraGroups,
          lessThan(served)); // never credited with more than happened
      expect(c.spend, 3000);
      if (c.mult == 0) {
        sawFlop = true;
        expect(c.extraGroups, 0);
        expect(c.returnOnSpend, 0);
        expect(c.netGain, -3000);
      } else {
        sawWorking = true;
        expect(c.extraGroups, greaterThan(0));
        expect(c.returnOnSpend, greaterThan(0));
      }
    }
    expect(sawFlop && sawWorking, isTrue);
  });

  test('a promotion day counts the discount given to regulars as spend', () {
    final s = OutletSim(load(), 4, ownerRun: true);
    s.runCampaign('promoDay');
    s.step();
    final c = s.campaignLog.single;
    expect(c.cost, 0);
    expect(c.discountGiven, greaterThan(0));
    expect(c.spend, c.discountGiven);
  });
}

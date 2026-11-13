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
    expect(s.forecast(), closeTo(50 * 1.125 * 0.8, 1e-9));
  });

  test(
      'buzz decays to zero without marketing and an ad restores it (doc 11 §A.1)',
      () {
    final s = OutletSim(load(), 2, managerGrade: Grade.veteran);
    for (var i = 0; i < 30; i++) {
      s.step();
    }
    expect(s.buzz, 0);
    s.runCampaign('localAd');
    expect(s.buzz, closeTo(0.25, 1e-9));
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

  test('a better manager beats a worse one on average (proposal tuning)', () {
    final b = load('data/balance-proposal.json');
    double mean(Grade g) {
      var total = 0;
      for (var seed = 1; seed <= 40; seed++) {
        total += runOne(b, seed, g, CompetentOwner(), 12).finalCash;
      }
      return total / 40;
    }

    expect(mean(Grade.veteran), greaterThan(mean(Grade.trainee)));
  });
}

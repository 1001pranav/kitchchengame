import 'package:sim_core/sim_core.dart';
import 'package:test/test.dart';

import '../tool/bots.dart';
import 'helpers.dart';

void main() {
  for (final theme in ['italian', 'chinese', 'mexican', 'indian']) {
    test(
        '$theme pack: 3 starters, 5 mains, 2 sides, 2 dessert/drink; stations exist',
        () {
      final ds = content.dishesFor(theme);
      expect(ds.where((d) => d.course == 'starter').length, 3);
      expect(ds.where((d) => d.course == 'main').length, 5);
      expect(ds.where((d) => d.course == 'side').length, 2);
      expect(ds.where((d) => d.courseGroup == 'sweet').length, 2);
      final t = content.themes[theme]!;
      for (final d in ds) {
        expect(t.stations, contains(d.station), reason: d.id);
        expect(d.basePrice, inInclusiveRange(1, 30), reason: d.id);
      }
    });
  }

  for (final theme in ['italian', 'chinese', 'mexican', 'indian', 'mixed']) {
    test('$theme: buy Good tier and play a week without errors', () {
      final sim = Sim.newGame(
          content: content, seed: 21, difficulty: 'normal', themeId: theme);
      expect(sim.apply(const BuyRestaurant(2)).ok, isTrue);
      final enabled = sim.state.loc.menu.values.where((m) => m.enabled).length;
      expect(enabled, inInclusiveRange(6, theme == 'mixed' ? 16 : 12));
      final bot = Bot('competent');
      while (sim.state.dayIndex < 7) {
        bot.day(sim);
      }
      expect(sim.state.loc.days.where((d) => d.groupsServed > 0).length,
          greaterThan(4));
    });
  }

  test('Mixed: wider appeal (+10% demand) and a 16-dish menu cap', () {
    final sim = Sim.newGame(
        content: content, seed: 2, difficulty: 'normal', themeId: 'mixed');
    sim.apply(const BuyRestaurant(2));
    expect(sim.forecast().factors['Wide menu'], 1.10);
    final off = sim.state.loc.menu.values
        .where((m) => !m.enabled)
        .map((m) => m.dishId)
        .toList();
    var ok = 0;
    for (final id in off) {
      if (sim.apply(SetDishEnabled(id, true)).ok) ok++;
    }
    expect(sim.state.loc.menu.values.where((m) => m.enabled).length, 16);
    expect(ok, 4);
  });

  test('Italian menu cannot exceed 12 or drop below 6', () {
    final sim = boughtSim();
    final menu = sim.state.loc.menu.values.toList();
    for (final m in menu.take(6)) {
      expect(sim.apply(SetDishEnabled(m.dishId, false)).ok, isTrue);
    }
    expect(sim.apply(SetDishEnabled(menu[6].dishId, false)).ok, isFalse);
  });
}

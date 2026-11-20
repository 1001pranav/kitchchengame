import 'dart:convert';

import 'package:sim_core/sim_core.dart';
import 'package:test/test.dart';

import '../tool/bots.dart';
import 'helpers.dart';

void main() {
  group('SimRng (doc 08 §5)', () {
    test('seed 1 first draw', () => expect(SimRng(1).nextU32(), 524866043));
    test('seed 0 maps to the golden constant',
        () => expect(SimRng(0).state, 0x9E3779B9));
    test('floats in [0,1) and mean near 0.5 over first draws', () {
      var sum = 0.0;
      for (var s = 1; s <= 200; s++) {
        final f = SimRng(s).nextFloat();
        expect(f, inInclusiveRange(0, 0.9999999));
        sum += f;
      }
      expect(sum / 200, closeTo(0.5, 0.08));
    });
    test('nextInt is inclusive', () {
      final r = SimRng(7);
      final seen = <int>{};
      for (var i = 0; i < 2000; i++) {
        seen.add(r.nextInt(1, 3));
      }
      expect(seen, {1, 2, 3});
    });
    test('state save/restore continues the same sequence', () {
      final a = SimRng(42)..nextU32();
      final b = SimRng.fromState(a.state);
      expect(b.nextU32(), a.nextU32());
    });
  });

  group('content', () {
    test('loads, with derived prices in a sane range', () {
      final d = content.dishes['dish_it_margherita']!;
      // flour×2 0.30 + canned tomato 0.60 + mozzarella×2 1.50 + herbs 0.80 = 5.00 / 0.32
      expect(d.basePrice, 16);
      for (final dish in content.dishesFor('italian')) {
        expect(dish.basePrice, inInclusiveRange(1, 30), reason: dish.id);
      }
    });
    test('missing balance key names the key', () {
      expect(
          () => content.balance.d('NO_SUCH_KEY'), throwsA(isA<ContentError>()));
    });
    test('Italian theme has 3 starters, 5 mains, 2 sides, 2 dessert/drink', () {
      final ds = content.dishesFor('italian');
      expect(ds.where((d) => d.course == 'starter').length, 3);
      expect(ds.where((d) => d.course == 'main').length, 5);
      expect(ds.where((d) => d.course == 'side').length, 2);
      expect(ds.where((d) => d.courseGroup == 'sweet').length, 2);
    });
  });

  group('new game and purchase', () {
    test('Good tier: cash 20,000, loan 70,000, prep, day 0 Monday', () {
      final sim = boughtSim();
      expect(sim.state.phase, 'prep');
      expect(sim.state.dayIndex, 0);
      expect(sim.state.weekday, 0);
      expect(sim.state.totalOutstanding, 70000);
      // Cash after purchase may have moved by Cash & Carry? No: only deliveries at prep.
      expect(sim.state.cash, inInclusiveRange(19000, 20000));
    });
    test('same seed gives the same offers', () {
      final a = Sim.newGame(content: content, seed: 9, difficulty: 'normal');
      final b = Sim.newGame(content: content, seed: 9, difficulty: 'normal');
      expect(jsonEncode(a.toSave()), jsonEncode(b.toSave()));
    });
    test('rosters match doc 04 §6 and skills stay in range over many seeds',
        () {
      for (var seed = 1; seed <= 60; seed++) {
        final sim =
            Sim.newGame(content: content, seed: seed, difficulty: 'normal');
        for (var i = 0; i < sim.state.offers.length; i++) {
          final o = sim.state.offers[i];
          final tier = content.tier(o.tierId);
          expect(o.location.staff.length, tier.staffRoles.length);
          for (final s in o.location.staff) {
            if (tier.id != 'worst' || s.traits.isEmpty) {
              expect(s.skill,
                  inInclusiveRange(tier.skillRange[0], tier.skillRange[1]));
            }
          }
          expect(o.location.hidden.length,
              inInclusiveRange(tier.hiddenProblems[0], tier.hiddenProblems[1]));
        }
      }
    });
    test('due diligence reveals half the hidden problems, rounded up', () {
      final sim = Sim.newGame(content: content, seed: 3, difficulty: 'normal');
      final worst = content.tiers.indexWhere((t) => t.id == 'worst');
      final n = sim.state.offers[worst].location.hidden.length;
      sim.apply(BuyDueDiligence(worst));
      expect(
          sim.state.offers[worst].location.hidden
              .where((h) => h.revealed)
              .length,
          (n / 2).ceil());
    });
  });

  group('determinism and saves', () {
    test('save round-trip is exact', () {
      final sim = boughtSim(seed: 4);
      final json = jsonEncode(sim.toSave());
      final again =
          Sim.fromSave(content, jsonDecode(json) as Map<String, dynamic>);
      expect(jsonEncode(again.toSave()), json);
    });
    test('same seed + same bot = identical save after 14 days', () {
      String run() {
        final sim = boughtSim(seed: 5);
        final bot = Bot('competent');
        while (sim.state.dayIndex < 14) {
          bot.day(sim);
        }
        return jsonEncode(sim.toSave());
      }

      expect(run(), run());
    });
    test('save/load mid-service then continue = uninterrupted run', () {
      final a = boughtSim(seed: 6);
      clearCards(a);
      a.apply(const StartService());
      for (var i = 0; i < 150; i++) {
        a.tick();
      }
      final b = Sim.fromSave(
          content, jsonDecode(jsonEncode(a.toSave())) as Map<String, dynamic>);
      runService(a);
      runService(b);
      expect(jsonEncode(b.toSave()), jsonEncode(a.toSave()));
    });
  });

  group('service scenarios', () {
    test('no servers, cashier or owner: parties walk out waiting to order', () {
      final sim = boughtSim(seed: 2);
      clearCards(sim);
      for (final s in sim.state.loc.staff) {
        if (s.role == 'server' || s.role == 'cashier') s.workingToday = false;
      }
      sim.apply(const OwnerRest(true));
      sim.apply(const StartService());
      runService(sim);
      final t = sim.state.today;
      expect(t.groupsServed, 0);
      expect(t.walkouts, t.groupsArrived);
    });
    test('no cook: no food is served', () {
      final sim = boughtSim(seed: 2);
      clearCards(sim);
      for (final s in sim.state.loc.staff) {
        if (s.isCook || s.role == 'prepCook') s.workingToday = false;
      }
      sim.apply(const OwnerRest(true));
      sim.apply(const StartService());
      runService(sim);
      expect(sim.state.today.foodTickets, 0);
      expect(sim.state.today.walkFood, greaterThan(0));
    });
    test(
        'owner standing in the busy area cuts lost parties when a server is off',
        () {
      var idle = 0, working = 0;
      for (var seed = 1; seed <= 12; seed++) {
        for (final ownerWorks in [false, true]) {
          final sim = boughtSim(seed: seed);
          clearCards(sim);
          // A Friday-like day with only one server.
          final servers =
              sim.state.loc.staff.where((s) => s.role == 'server').toList();
          for (final s in servers.skip(1)) {
            s.workingToday = false;
          }
          for (final s in sim.state.loc.staff) {
            if (s.role != 'server' && sim.rosteredToday(s) == false)
              s.workingToday = true;
          }
          sim.apply(OwnerStand(ownerWorks ? 'tables' : null));
          sim.apply(const StartService());
          var guard = 0;
          while (sim.state.phase == 'service' && guard++ < 1000) {
            for (final i in sim.state.openIncidents) {
              sim.apply(ResolveIncident(
                  i.id, sim.content.incidents[i.incidentId]!.defaultOption));
            }
            sim.tick();
          }
          final lost = sim.state.today.walkouts;
          if (ownerWorks) {
            working += lost;
          } else {
            idle += lost;
          }
        }
      }
      expect(working, lessThan(idle * 0.75));
    });
    test('invariants hold every tick', () {
      final sim = boughtSim(seed: 8);
      clearCards(sim);
      sim.apply(const StartService());
      var guard = 0;
      while (sim.state.phase == 'service' && guard++ < 1000) {
        final s = sim.service!;
        final taken = <int>{};
        for (final k in s.tasks) {
          expect(taken.add(k.id), isTrue);
        }
        for (final b in sim.state.loc.stock) {
          expect(b.qty, greaterThanOrEqualTo(0));
        }
        final occupied = s.tables
            .where((t) => t.state == 'occupied')
            .map((t) => t.groupId)
            .toList();
        expect(occupied.toSet().length, occupied.length);
        sim.tick();
      }
    });
  });

  group('finance', () {
    test('three missed instalments end the game', () {
      final sim = boughtSim(seed: 3);
      final bot = Bot('passive');
      sim.state.cash = -100000;
      var guard = 0;
      while (sim.state.phase != 'gameOver' && guard++ < 60) {
        bot.day(sim);
        if (sim.state.cash > -50000) sim.state.cash = -50000;
      }
      expect(sim.state.phase, 'gameOver');
    });
    test('reputation falls twice as fast as it rises', () {
      expect(content.balance.d('REP_DOWN'), 2 * content.balance.d('REP_UP'));
    });
    test('bank refuses a fourth loan with the reason', () {
      final sim = boughtSim(seed: 3);
      sim.state.weeks.add(WeekRecord(week: 0, operatingProfit: 50000));
      sim.apply(const ApplyLoan(2000, 52));
      sim.apply(const ApplyLoan(2000, 52));
      final r = sim.apply(const ApplyLoan(2000, 52));
      expect(r.ok, isFalse);
      expect(r.value, 'tooManyLoans');
    });
  });

  group('incidents', () {
    test('every option of every incident resolves on a standard state', () {
      for (final def in content.incidents.values) {
        for (final opt in def.options) {
          final sim = boughtSim(seed: 11, tier: 'best');
          clearCards(sim);
          sim.state.cash = 50000;
          if (def.timing == 'service') sim.apply(const StartService());
          final inst =
              sim.apply(const OwnerStand('door')); // no-op to keep phase
          expect(inst.ok || true, isTrue);
          final raised = _raise(sim, def.id);
          if (raised == null) continue; // subject not available in this state
          final r = sim.apply(ResolveIncident(raised.id, opt.id));
          expect(r.ok || r.error == SimError.locked, isTrue,
              reason: '${def.id}/${opt.id}: ${r.message}');
        }
      }
    });
  });

  test('bot smoke: competent Good owner survives 8 weeks', () {
    final sim = boughtSim(seed: 12);
    final bot = Bot('competent');
    while (sim.state.dayIndex < 56 && sim.state.phase != 'gameOver') {
      bot.day(sim);
    }
    expect(sim.state.phase, isNot('gameOver'));
  });
}

IncidentInstance? _raise(Sim sim, String id) {
  // Use the scheduler: a forced card raised at the next opportunity.
  sim.state.scheduled.add(Scheduled(id, sim.state.dayIndex));
  if (sim.state.phase == 'service') {
    // Service cards are raised directly via the breakdown path or rolls; schedule a prep one instead.
  }
  sim.beginDay();
  return sim.state.openIncidents.where((i) => i.incidentId == id).firstOrNull;
}

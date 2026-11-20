import 'package:sim_core/sim_core.dart';

/// Bot policies (doc 06 §6.1).
///  passive: does nothing at all; every card takes its default.
///  chores: works the floor at the busiest area, orders stock, answers cards with the default.
///  competent: chores + repairs, servicing, hiring for gaps, sensible cards, marketing at stage 2.
class Bot {
  final String policy;
  Bot(this.policy);

  void prep(Sim sim) {
    final st = sim.state;
    if (policy == 'passive') {
      sim.apply(const OwnerStand(null));
      return;
    }
    _answerCards(sim);
    final loc = st.loc;
    // Order stock. Competent: fresh produce and dairy from Farm Direct, meat from the
    // butcher, the rest from City Foodservice. Chores: everything from City Foodservice.
    final plan = policy == 'competent'
        ? ['sup_farm', 'sup_butcher', 'sup_standard']
        : ['sup_standard'];
    final ordered = <String>{};
    for (final sup in plan) {
      final lines = sim.suggestedOrder(sup)
        ..removeWhere((k, v) => ordered.contains(k));
      if (lines.isEmpty) continue;
      final minOrder = sim.content.suppliers[sup]!.minOrder;
      if (sim.orderTotal(sup, lines) < minOrder) continue;
      if (sim.apply(PlaceOrder(sup, lines)).ok) ordered.addAll(lines.keys);
    }
    // Cash & Carry top-up if something runs out today.
    final risks = sim.runOutRisks();
    if (risks.isNotEmpty && policy == 'competent') {
      final use = sim.expectedDailyUse();
      final top = <String, int>{};
      for (final ing in risks.keys) {
        top[ing] = (use[ing]! * 1.1).ceil() - loc.stockOf(ing);
      }
      top.removeWhere((k, v) => v <= 0);
      if (top.isNotEmpty) sim.apply(PlaceOrder('sup_cash_carry', top));
    }
    if (policy == 'competent') {
      for (final e in loc.equipment) {
        if (e.broken) {
          sim.apply(Repair(e.id, 'proper'));
        } else if (e.condition < sim.maxCondition(e) - 10 &&
            e.condition >= 50 &&
            st.cash > 5000) {
          sim.apply(Maintain(e.id));
        }
      }
      // Train the weakest cook when there is money to spare.
      if (st.cash > 15000 && st.weekday == 1) {
        final cooks = loc.staff
            .where((s) =>
                s.isCook && s.skill < 70 && s.trainingUntil < st.dayIndex)
            .toList()
          ..sort((a, b) => a.skill.compareTo(b.skill));
        if (cooks.isNotEmpty) sim.apply(Train(cooks.first.id));
      }
      // Pay fair wages to anyone underpaid and unhappy.
      for (final s in loc.staff) {
        final exp = sim.expectedWage(s.role, s.skill);
        if (s.morale < 45 && s.wage < exp) sim.apply(SetWage(s.id, exp));
      }
      // Keep the roster the restaurant came with: hire into gaps.
      const want = {
        'lineCook': 2,
        'server': 2,
        'cashier': 1,
        'dishwasher': 1,
        'cleaner': 1
      };
      final cooks = loc.staff.where((s) => s.isCook).length;
      want.forEach((role, n) {
        final have = role == 'lineCook'
            ? cooks - 1
            : loc.staff.where((s) => s.role == role).length;
        if (have < n) {
          final a = st.applicants
              .where((x) =>
                  x.role == role ||
                  (role == 'lineCook' && x.role == 'headChef'))
              .toList()
            ..sort((x, y) => y.skill.compareTo(x.skill));
          if (a.isNotEmpty) sim.apply(Hire(a.first.id));
        }
      });
      if (!loc.staff.any((s) => s.role == 'headChef')) {
        final lc = loc.staff.where((s) => s.role == 'lineCook').toList()
          ..sort((x, y) => y.skill.compareTo(x.skill));
        if (lc.isNotEmpty) sim.apply(Promote(lc.first.id));
      }
      if (st.stage >= 2) {
        if (st.dayIndex % 28 == 3 && st.cash > 12000) {
          sim.apply(const StartCampaign('localAd'));
        }
        if (st.dayIndex % 56 == 10 && st.cash > 8000) {
          sim.apply(const ReworkMenu());
        }
      }
    }
    sim.apply(const OwnerStand('door'));
  }

  void _answerCards(Sim sim) {
    for (final inst in sim.state.openIncidents) {
      final def = sim.content.incidents[inst.incidentId]!;
      var pick = def.defaultOption;
      if (policy == 'competent') {
        const prefs = {
          'inc_breakdown': 'proper',
          'inc_pests': 'pro',
          'inc_fridge_warm': 'service',
          'inc_burnout': 'unpaid',
          'inc_lifeline': 'loan',
          'inc_plumbing_leak': 'plumber',
          'inc_food_poisoning': 'refund',
          'inc_licence_overdue': 'pay',
          'inc_supplier_cash_only': 'pay',
          'inc_bad_batch': 'reject',
          'inc_wage_demand': 'half',
          'inc_resignation': 'counter',
          'inc_inspection': 'clean',
          'inc_skimming': 'fire',
          'inc_staff_conflict': 'mediate',
          'inc_complaint_table': 'dessert',
          'inc_toxic_complaint': 'fire',
          'inc_power_cut': 'candles',
          'inc_gas_out': 'rush',
          'inc_pos_crash': 'paper',
          'inc_fryer_dies_service': 'emergency',
          'inc_tax_audit': 'accountant',
          'inc_bad_review_viral': 'apology',
          'inc_festival_leave': 'half',
        };
        final pref = prefs[inst.incidentId];
        if (pref != null) {
          final o = def.options.where((x) => x.id == pref).firstOrNull;
          if (o != null && sim.optionBlocked(inst, o) == null) pick = pref;
        }
      }
      sim.apply(ResolveIncident(inst.id, pick));
    }
  }

  void service(Sim sim) {
    var guard = 0;
    while (sim.state.phase == 'service' && guard++ < 1000) {
      if (policy != 'passive') {
        _answerCards(sim);
        // Move toward the busiest area.
        final s = sim.service!;
        final counts = {'door': 0, 'tables': 0, 'pass': 0};
        for (final k in s.tasks) {
          if (k.started) continue;
          if (k.type == 'seat' || k.type == 'bill') {
            counts['door'] = counts['door']! + 1;
          }
          if (k.type == 'takeOrder' || k.type == 'clear') {
            counts['tables'] = counts['tables']! + 1;
          }
          if (k.type == 'deliver') counts['pass'] = counts['pass']! + 1;
        }
        final best = counts.entries.reduce((a, c) => c.value > a.value ? c : a);
        if (best.value > 0 && s.ownerArea != best.key) {
          sim.apply(OwnerStand(best.key));
        }
        if (s.dirtyDishes > 6 * s.tables.length * 0.8) {
          sim.apply(const OwnerStand('dishes'));
        }
      }
      sim.tick();
    }
  }

  void close(Sim sim) {
    if (policy != 'passive') _answerCards(sim);
  }

  void day(Sim sim) {
    prep(sim);
    sim.apply(const StartService());
    service(sim);
    close(sim);
    if (sim.state.phase == 'close') sim.apply(const EndDay());
  }
}

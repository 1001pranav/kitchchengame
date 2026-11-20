part of '../sim.dart';

// "Why?" breakdowns built from the same functions the sim uses (doc 08 §4).

extension _Explain on Sim {
  String _pct(double m) {
    final p = ((m - 1) * 100).round();
    return p == 0 ? '±0%' : (p > 0 ? '+$p%' : '−${-p}%');
  }

  String _signed(num v, {int digits = 0}) {
    final s = v.abs().toStringAsFixed(digits);
    return v >= 0 ? '+$s' : '−$s';
  }

  Explanation _explain(String target, {int? id}) {
    final l = loc;
    switch (target) {
      case 'demand':
        final f = _demandFactors(l, state.dayIndex);
        final total = _expectedGroups(l, state.dayIndex).round();
        return Explanation(
          'Expected parties today',
          '~$total',
          'multiply',
          [
            for (final e in f.entries)
              Factor(
                  e.key,
                  e.value,
                  e.key == 'Base footfall'
                      ? '${e.value.round()} parties'
                      : _pct(e.value)),
          ],
          howToImprove:
              'A better rating, fair prices, a fresh menu and advertising bring more parties.',
        );
      case 'reputation':
        final t = state.days.isEmpty ? null : state.days.last;
        final factors = <Factor>[];
        if (t != null && t.starsN > 0) {
          factors.add(Factor('Yesterday\'s average review', t.avgStars,
              '${t.avgStars.toStringAsFixed(2)} ★'));
          factors.add(
              Factor('Reviews counted', t.starsN, t.starsN.toStringAsFixed(0)));
          factors.add(Factor(
              'Walk-outs yesterday', t.walkouts.toDouble(), '${t.walkouts}'));
        }
        factors.add(const Factor(
            'Rating moves toward reviews', 0, 'falls 2× faster than it rises'));
        return Explanation(
            'Rating', '${l.reputation.toStringAsFixed(2)} ★', 'add', factors,
            howToImprove:
                'Good food, short waits, fair prices and a clean room earn better reviews.');
      case 'satisfaction':
        final t = state.today.starsN > 0
            ? state.today
            : (state.days.isEmpty ? state.today : state.days.last);
        final q = t.foodTickets == 0 ? 0.0 : t.foodQualitySum / t.foodTickets;
        return Explanation('What customers thought',
            '${t.avgStars.toStringAsFixed(1)} ★', 'add', [
          Factor('Food quality (40%)', q, q.toStringAsFixed(0)),
          Factor('Waiting (30%)', 0, '${t.walkouts} walk-outs'),
          Factor('Value for money (15%)', _priceIndexOf(l),
              'prices ${_pct(_priceIndexOf(l))} vs normal'),
          Factor('Cleanliness (15%)', l.hygiene, l.hygiene.toStringAsFixed(0)),
          Factor('Dishes not available', t.unavailable.toDouble(),
              '−10 per missing dish (${t.unavailable})'),
        ]);
      case 'profit':
        final t = state.phase == 'prep' && state.days.isNotEmpty
            ? state.days.last
            : state.today;
        return Explanation(
            'Profit for ${dateLabel(t.dayIndex)}', money(t.profit), 'coins', [
          Factor('Sales', t.revenue.toDouble(), '+${money(t.revenue)}'),
          Factor('Ingredients bought', -t.ingredientSpend.toDouble(),
              '−${money(t.ingredientSpend)}'),
          Factor('Wages (paid Sundays)', -t.wages.toDouble(),
              '−${money(t.wages)}'),
          Factor(
              'Rent (paid Sundays)', -t.rent.toDouble(), '−${money(t.rent)}'),
          Factor('Utilities (paid monthly)', -t.utilities.toDouble(),
              '−${money(t.utilities)}'),
          if (t.upkeep > 0)
            Factor('Repairs and equipment', -t.upkeep.toDouble(),
                '−${money(t.upkeep)}'),
          if (t.marketing > 0)
            Factor(
                'Marketing', -t.marketing.toDouble(), '−${money(t.marketing)}'),
          if (t.other != 0)
            Factor('Other (situations, fines, tax)', -t.other.toDouble(),
                _signed(-t.other)),
        ]);
      case 'cash':
        final owed = state.wagesOwed;
        return Explanation(
            'Cash in hand',
            money(state.cash),
            'coins',
            [
              Factor('Cash now', state.cash.toDouble(), money(state.cash)),
              Factor(
                  'Wages owed on Sunday', -owed.toDouble(), '−${money(owed)}'),
              Factor('Rent due on Sunday', -l.rentWeekly.toDouble(),
                  '−${money(l.rentWeekly)}'),
              Factor(
                  'Loan payments on Sunday',
                  -_currentInstalments().toDouble(),
                  '−${money(_currentInstalments())}'),
              Factor(
                  'Supplier bills unpaid',
                  -l.payables.fold<int>(0, (a, p) => a + p.amount).toDouble(),
                  '−${money(l.payables.fold<int>(0, (a, p) => a + p.amount))}'),
              Factor(
                  'Utilities this month so far',
                  -state.monthUtilities.toDouble(),
                  '−${money(state.monthUtilities)}'),
            ],
            howToImprove:
                'Profit is not cash: wages, rent and loan payments all leave on Sunday.');
      case 'staffHappiness':
        final s = l.staffById(id);
        if (s == null) return const Explanation('Happiness', '-', 'add', []);
        final f = _happinessFactors(s).entries.toList()
          ..sort((a, c) => a.value.compareTo(c.value));
        return Explanation(
            '${s.name}\'s happiness', s.morale.round().toString(), 'add', [
          const Factor('Starting point', 50, '50'),
          for (final e in f) Factor(e.key, e.value, _signed(e.value)),
          Factor('Heading toward', _happinessTarget(s),
              _happinessTarget(s).round().toString()),
        ]);
      case 'hygiene':
        final cleaners = l.staff.where((s) => s.role == 'cleaner').length;
        return Explanation('Cleanliness', l.hygiene.round().toString(), 'add', [
          Factor('Dirt from customers', -0.15, '−0.15 per party served'),
          Factor(
              'Cleaners',
              cleaners.toDouble(),
              cleaners == 0
                  ? 'none — the dishwasher cleans at half effect'
                  : '$cleaners cleaning each night'),
          if (!_hasWorking('eq_hood'))
            const Factor('Exhaust hood broken', -5, '−5 a day'),
          if (state.flag('pests')) const Factor('Pests', -8, '−8 a day'),
          if (state.flag('leak')) const Factor('Leak', -10, '−10 a day'),
          const Factor(
              'Inspection', 80, 'pass at 80+, fine at 50–79, closure below 50'),
        ]);
      case 'energy':
        return Explanation(
            'Your energy', state.owner.energy.round().toString(), 'add', [
          Factor('Working a job', -b.d('OWNER_ENERGY_PER_TICK'),
              '−${b.d('OWNER_ENERGY_PER_TICK')} per tick'),
          const Factor('Standing at Dishes', 0, 'counts as working every tick'),
          Factor('Overnight sleep', b.d('OWNER_RECOVERY'),
              '+${b.d('OWNER_RECOVERY').round()}'),
          const Factor('Below 20', 0, 'mistakes: wrong orders, short bills'),
          const Factor('At 0 three nights running', 0, 'a forced day off'),
        ]);
      case 'dish':
        final dishId = l.menu.keys.elementAt(id ?? 0);
        final d = content.dishes[dishId]!;
        final m = l.menu[dishId]!;
        final cost = d.recipe.fold(0.0,
            (a, r) => a + r.qty * _unitPrice('sup_standard', r.ingredientId));
        return Explanation(d.name, money(m.price), 'coins', [
          for (final r in d.recipe)
            Factor(
                '${content.ingredients[r.ingredientId]!.name} ×${r.qty}',
                -r.qty * _unitPrice('sup_standard', r.ingredientId),
                '−${(r.qty * _unitPrice('sup_standard', r.ingredientId)).toStringAsFixed(2)}'),
          Factor('Profit per dish', m.price - cost,
              (m.price - cost).toStringAsFixed(2)),
          Factor('Food cost', cost / m.price,
              '${(cost / m.price * 100).round()}%'),
        ]);
      case 'valuation':
        final resale =
            l.equipment.fold<int>(0, (a, e) => a + _equipmentResale(e));
        return Explanation('Company value', money(_valuation()), 'coins', [
          Factor('Cash', state.cash.toDouble(), money(state.cash)),
          Factor('Equipment if sold', resale.toDouble(), money(resale)),
          Factor(
              'Profit power (40 weeks of avg profit)',
              40.0 * math.max(0, _avgWeeklyOpProfit()),
              money(b.i('VALUATION_PROFIT_MULT') *
                  math.max(0, _avgWeeklyOpProfit()))),
          Factor('Name and rating', b.d('VALUATION_PER_STAR') * l.reputation,
              money(b.d('VALUATION_PER_STAR') * l.reputation)),
          Factor('Debts', -state.totalOutstanding.toDouble(),
              '−${money(state.totalOutstanding)}'),
        ]);
    }
    return Explanation(target, '-', 'add', const []);
  }
}

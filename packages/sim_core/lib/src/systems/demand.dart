part of '../sim.dart';

// Calendar and demand (doc 02 §2, §5; doc 11 §A).

extension _Demand on Sim {
  Festival? _festivalOn(int day) {
    final month = (day ~/ 28) % 12 + 1;
    final dom = day % 28 + 1;
    for (final f in theme.festivals) {
      if (f.month == month && dom >= f.day && dom < f.day + f.durationDays) {
        return f;
      }
    }
    return null;
  }

  double _priceIndexOf(Location l) {
    var sum = 0.0;
    var n = 0;
    final ref = _referencePriceMult();
    for (final m in l.menu.values) {
      if (!m.enabled) continue;
      sum += m.price / (content.dishes[m.dishId]!.basePrice * ref);
      n++;
    }
    var pi = n == 0 ? 1.0 : sum / n;
    if (_promoActive(l)) pi *= 0.75;
    return pi;
  }

  /// Customers' reference price rises ×1.03 a year (doc 11 §A.4).
  double _referencePriceMult() =>
      math.pow(b.d('YEARLY_COST_CREEP_WAGE'), state.dayIndex ~/ 336).toDouble();

  bool _promoActive(Location l) => l.campaigns
      .any((c) => c.type == 'promoDay' && c.startDay == state.dayIndex);

  double _marketingBoost(Location l, int day) {
    var sum = 0.0;
    for (final c in l.campaigns) {
      if (c.type == 'blogger') continue;
      if (day >= c.startDay && day <= c.endDay) sum += c.boost;
    }
    return math.min(sum, b.d('CAMPAIGN_BOOST_CAP'));
  }

  /// Demand factors in order. The forecast leaves out the random term.
  Map<String, double> _demandFactors(Location l, int day) {
    final cls = content.locationClasses[l.classId]!;
    final f = <String, double>{};
    f['Base footfall'] = cls.baseFootfall.toDouble();
    f['Rating'] = (0.25 + 0.25 * l.reputation).clamp(0.4, 1.5);
    f['Prices'] = (1.5 - 0.5 * _priceIndexOf(l)).clamp(0.5, 1.3);
    f['Day of week'] = b.list('DOW_FACTOR')[day % 7];
    f['Season'] = b.list('SEASON_FACTOR')[((day ~/ 28) % 12) ~/ 3];
    f['Advertising'] = 1 + _marketingBoost(l, day);
    var ev = 1.0;
    final fest = _festivalOn(day);
    if (fest != null) ev *= fest.demandMult;
    for (final m in l.demandMods) {
      if (day <= m.untilDay) ev *= m.mult;
    }
    if (_promoActive(l) && day == state.dayIndex) {
      ev *= 1; // boost is in Advertising
    }
    f['Events'] = ev;
    f['Buzz'] = 0.90 + 0.20 * l.buzz;
    f['Menu freshness'] = 0.94 + 0.10 * l.freshness;
    f['Rivals'] = 1 - 0.30 * l.competition;
    f['Awareness'] = l.awareness;
    if (l.format != 'neighbourhood') {
      final fm = _format(l);
      f['Type of outlet'] =
          fm['footfallMult']! * (day % 7 >= 5 ? fm['weekendMult']! : 1);
    }
    if (content.themes[l.themeId]?.isMixed ?? false) {
      f['Wide menu'] = b.d('MIXED_DEMAND_MULT');
    }
    return f;
  }

  double _expectedGroups(Location l, int day) {
    var g = 1.0;
    _demandFactors(l, day).forEach((_, v) => g *= v);
    return g;
  }

  Forecast _forecast() {
    final f = _demandFactors(loc, state.dayIndex);
    final g = _expectedGroups(loc, state.dayIndex).round();
    final base = content.locationClasses[loc.classId]!.baseFootfall;
    final ratio = g / base;
    final label = ratio < 0.8
        ? 'quiet'
        : (ratio < 1.05 ? 'normal' : (ratio < 1.3 ? 'busy' : 'very busy'));
    return Forecast(g, label, f);
  }

  /// Expected ingredient use for one day at forecast demand (stock, warnings, "Order usual").
  Map<String, double> _expectedDailyUse(Location l, {int? day}) {
    final groups = _expectedGroups(l, day ?? state.dayIndex);
    final people = groups * b.d('AVG_GROUP_SIZE');
    final out = <String, double>{};
    final enabled = l.menu.values
        .where((m) => m.enabled)
        .map((m) => content.dishes[m.dishId]!)
        .toList();
    final courseChance = b.dmap('COURSE_CHANCE');
    for (final course in ['main', 'starter', 'side', 'sweet']) {
      final inCourse = enabled.where((d) => d.courseGroup == course).toList();
      if (inCourse.isEmpty) continue;
      final perPerson = course == 'main' ? 1.0 : courseChance[course]!;
      final totalPop = inCourse.fold(0.0, (a, d) => a + d.popularity);
      for (final d in inCourse) {
        final portions = people * perPerson * d.popularity / totalPop;
        for (final r in d.recipe) {
          out[r.ingredientId] = (out[r.ingredientId] ?? 0) + portions * r.qty;
        }
      }
    }
    return out;
  }

  /// Arrivals for today's service (doc 02 §5.2–5.3).
  List<Arrival> _rollArrivals(Location l, int groups) {
    final fm = _format(l);
    final hours = [
      for (var h = 0; h < b.list('HOUR_WEIGHTS').length; h++)
        b.list('HOUR_WEIGHTS')[h] *
            (h == 1 || h == 2
                ? fm['lunchMult']!
                : (h >= 6 ? fm['eveningMult']! : 1)),
    ];
    final cls = content.locationClasses[l.classId]!;
    final sizeW = b.list('GROUP_SIZE_WEIGHTS');
    final out = <Arrival>[];
    for (var i = 0; i < groups; i++) {
      final h =
          _rng.weighted(List<int>.generate(hours.length, (i) => i), hours);
      var tick = h * b.i('TICKS_PER_HOUR') +
          _rng.nextInt(0, b.i('TICKS_PER_HOUR') - 1);
      if (tick > b.i('LAST_SEATING_TICK')) tick = b.i('LAST_SEATING_TICK');
      final size = _rng.weighted([1, 2, 3, 4, 5, 6], sizeW);
      final w = [
        for (final s in segments)
          cls.segmentMix[s]! *
              (s == 'office'
                  ? (h == 1 || h == 2 ? 2.0 : (h > 6 ? 0.5 : 1.0))
                  : 1.0)
      ];
      out.add(Arrival(tick, size, _rng.weighted(segments, w)));
    }
    out.sort((a, c) => a.tick.compareTo(c.tick));
    return out;
  }
}

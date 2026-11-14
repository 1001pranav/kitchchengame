import 'dart:math' as math;

import 'rng.dart';

/// Typed access over balance.json. Missing key -> error naming the key (doc 09 task 0.3).
class Balance {
  final Map<String, dynamic> _m;
  Balance(this._m);

  dynamic _get(String k) {
    if (!_m.containsKey(k)) throw StateError('balance.json is missing key $k');
    return _m[k];
  }

  bool has(String k) => _m.containsKey(k);
  double d(String k) => (_get(k) as num).toDouble();
  int i(String k) => (_get(k) as num).toInt();
  Map<String, dynamic> map(String k) =>
      (_get(k) as Map).cast<String, dynamic>();
  List<dynamic> list(String k) => _get(k) as List<dynamic>;
  double listD(String k, int idx) => (list(k)[idx] as num).toDouble();
}

double clampD(double x, double lo, double hi) =>
    x < lo ? lo : (x > hi ? hi : x);

enum Grade { trainee, junior, capable, senior, veteran }

/// Mean-skill ranges per grade, doc 02 §15.14.
const gradeRanges = {
  Grade.trainee: [20, 34],
  Grade.junior: [35, 49],
  Grade.capable: [50, 64],
  Grade.senior: [65, 79],
  Grade.veteran: [80, 92],
};

Grade gradeOf(double mean) {
  if (mean < 35) return Grade.trainee;
  if (mean < 50) return Grade.junior;
  if (mean < 65) return Grade.capable;
  if (mean < 80) return Grade.senior;
  return Grade.veteran;
}

/// Profiles: offsets for people / upkeep / stock, doc 02 §15.14.
const profiles = {
  'all-rounder': [0, 0, 0],
  'people person': [15, -5, -10],
  'tight ship': [-10, 15, -5],
  'numbers': [-5, -10, 15],
};

class Manager {
  final String name;
  final String profile;
  double people;
  double upkeep;
  double stock;
  final int potential;
  int hiredDay;
  int lastCoachDay = -999;

  Manager(this.name, this.profile, this.people, this.upkeep, this.stock,
      this.potential, this.hiredDay);

  double get mean => (people + upkeep + stock) / 3;
  Grade get grade => gradeOf(mean);

  /// Manager wage curve, doc 02 §15.14.
  static double wageA = 0.4, wageB = 1.2;
  int get wage => (260 * (wageA + wageB * mean / 100)).round();

  /// Raise the lowest sub-skill by 1, bounded by potential and a cap.
  void learn(int cap) {
    if (mean >= potential) return;
    final lim = math.min(cap, 95).toDouble();
    if (people <= upkeep && people <= stock) {
      people = math.min(lim, people + 1);
    } else if (upkeep <= stock) {
      upkeep = math.min(lim, upkeep + 1);
    } else {
      stock = math.min(lim, stock + 1);
    }
  }

  static const _names = [
    'Asha',
    'Marco',
    'Lena',
    'Tomas',
    'Priya',
    'Owen',
    'Mei',
    'Ravi',
    'Sofia',
    'Jonah',
    'Ines',
    'Kofi',
    'Hana',
    'Diego',
    'Noor',
    'Felix',
  ];

  static Manager generate(SimRng rng, Grade grade, int day) {
    final r = gradeRanges[grade]!;
    final mean = rng.nextInt(r[0], r[1]).toDouble();
    final keys = profiles.keys.toList();
    final profile = keys[rng.nextInt(0, keys.length - 1)];
    final off = profiles[profile]!;
    double sub(int o) => clampD(mean + o + rng.nextInt(-5, 5), 5, 95);
    final m = Manager(_names[rng.nextInt(0, _names.length - 1)], profile,
        sub(off[0]), sub(off[1]), sub(off[2]), 0, day);
    final pot = math.min(95, m.mean.round() + rng.nextInt(5, 35));
    return Manager(m.name, m.profile, m.people, m.upkeep, m.stock, pot, day);
  }

  String describe({bool exact = true}) {
    String s(double v) => exact
        ? v.round().toString()
        : '${(v - 15).round()}-${(v + 15).round()}';
    return '$name (${grade.name}, $profile) people ${s(people)} · upkeep ${s(upkeep)}'
        ' · stock ${s(stock)} · wage $wage/day';
  }
}

class Staff {
  final String role;
  double skill;
  int wage;
  final double reliability;
  final double loyalty;
  bool vacant = false;
  bool absentToday = false;
  int trainingUntil = -1; // away on a course until this day (doc 02 §7.6)
  Staff(this.role, this.skill, this.wage, this.reliability, this.loyalty);
}

class Equipment {
  final String type;
  double condition;
  int ageDays;
  bool broken = false;
  int readyDay = -1;
  int refailUntil = -1;
  bool warned = false;
  bool leased =
      false; // doc 02 §15.9 step 3: serviced and repaired by the lessor
  Equipment(this.type, this.condition, this.ageDays);

  /// doc 11 §A.3
  double get maxCondition => math.max(60, 95 - 5 * (ageDays ~/ 168)).toDouble();
}

/// One line in the "Manager's decisions" tally (doc 02 §15.12 attribution).
/// One campaign and what it brought in (doc 02 §13.2).
class Campaign {
  final String name;
  final int day;
  final int cost;
  final double mult;
  final String outcome;
  final double boost; // demand boost while it runs, after the outcome roll
  final int until;
  double buzzLeft; // share of today's buzz that this campaign put there
  double extraGroups = 0;
  double extraProfit = 0; // gross margin on the extra groups
  double discountGiven =
      0; // promoDay only: price cut handed to customers who would have come anyway
  Campaign(this.name, this.day, this.cost, this.mult, this.outcome, this.boost,
      this.until, this.buzzLeft);

  double get spend => cost + discountGiven;
  double get netGain => extraProfit - spend;

  /// Coins of extra profit per coin spent; null when nothing was spent.
  double? get returnOnSpend => spend <= 0 ? null : extraProfit / spend;
}

class ManagerEvent {
  final String key;
  final int coins; // negative = cost, positive = saving
  ManagerEvent(this.key, this.coins);
}

class DayResult {
  final int day;
  final bool closed;
  final bool ownerPresent;
  final int demand;
  final int served;
  final int walkouts;
  final int turnedAway;
  final int revenue;
  final int ingredients;
  final double stars;
  final double gaps;
  final double menuLoss;
  final double slack;
  final int dayProfit; // revenue - variable costs - fixed costs accrued per day
  final int breakEvenGroups;

  /// buzzFactor × freshnessFactor × competitionFactor: 1.0 = neutral (doc 11 §A.6).
  final double demandHealth;
  final List<String> notes;
  DayResult({
    required this.day,
    required this.closed,
    required this.ownerPresent,
    required this.demand,
    required this.served,
    required this.walkouts,
    required this.turnedAway,
    required this.revenue,
    required this.ingredients,
    required this.stars,
    required this.gaps,
    required this.menuLoss,
    required this.slack,
    required this.dayProfit,
    required this.breakEvenGroups,
    required this.demandHealth,
    required this.notes,
  });
}

class WeekStats {
  int revenue = 0;
  int ingredients = 0;
  int wages = 0;
  int managerWage = 0;
  int rent = 0;
  int utilities = 0; // accrued, paid monthly
  int marketing = 0;
  int upkeep = 0; // maintenance + repairs + replacements
  int other = 0; // fines, licence, tax, severance
  int equipLease = 0; // leased equipment fees (doc 02 §15.9 step 3)
  /// Debts inherited at takeover (hidden problem, doc 05 §4). Cash, but not operating
  /// profit: it is part of what the outlet cost, not of how it is run.
  int inherited = 0;
  int loanPaid = 0;
  int interest =
      0; // part of loanPaid; in net profit, not operating profit (doc 02 §14.2)
  int groups = 0;
  int served = 0;
  int walkouts = 0;
  int ownerDays = 0;
  int losingDays = 0;
  int incidents = 0; // incidents raised this week (doc 06 §4: 3–6)
  int incidentDefaults = 0; // of which resolved by the default option
  final List<ManagerEvent> managerEvents = [];

  int get operatingProfit =>
      revenue -
      ingredients -
      wages -
      managerWage -
      rent -
      utilities -
      marketing -
      upkeep -
      other -
      equipLease;

  /// Operating profit minus loan interest (doc 02 §14.2). "Profitable week" means this > 0.
  int get netProfit => operatingProfit - interest;
}

/// How equipment is obtained for a from-scratch outlet (doc 02 §15.9 route B, step 3).
enum EquipMode { buyNew, secondHand, lease }

/// A from-scratch opening (doc 02 §15.9 route B). Medium size, 3-year lease.
class ScratchPlan {
  final String name;
  final String fitOut; // key into SCRATCH_FITOUT: basic | standard | premium
  final EquipMode equip;
  final bool launchCampaign;
  const ScratchPlan(this.name, this.fitOut, this.equip,
      {this.launchCampaign = true});
}

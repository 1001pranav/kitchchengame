import 'dart:math' as math;

import 'model.dart';
import 'rng.dart';

/// One outlet, one manager, the owner mostly away. Daily resolution: the per-tick
/// service of doc 02 §6 is replaced by PROTO_ aggregates (see README).
class OutletSim {
  final Balance b;
  final SimRng rng;

  int day = 0; // dayIndex; day 0 is a Monday in spring
  int cash;
  int loanPrincipal0;
  int loanOutstanding;
  int missedInRow = 0;
  int negativeDays = 0;
  String? gameOver;

  double reputation;
  double hygiene;
  double buzz;
  double freshness;
  double competition = 0;
  double priceIndex = 1.0;
  double crewMorale;

  late Manager manager;
  final List<Staff> crew = [];
  final List<Equipment> equipment = [];
  final List<({double boost, int until})> campaigns = [];
  int promoDay = -1;
  int chefOffDay = -1;
  int closedUntil = -1;
  int inspectionDay = -1;
  int lastVisitDay = 0; // the owner was there on the day they bought it
  final Set<int> plannedVisits = {};
  int utilitiesAccrued = 0;
  int monthProfit = 0;
  int lossWeeks = 0;
  final List<bool> recentGapDays = [];
  int lastSuggestionDay = -999;
  final Map<String, int> lastCampaignDay = {};

  /// Every campaign run: for the ad measures in the bot report.
  final List<({int day, String name, double mult, int cost})> campaignLog = [];
  double lastCampaignMult = 1;

  List<Manager> applicants = [];
  final List<String> requests = []; // things only the owner can decide
  final List<WeekStats> weeks = [];
  WeekStats week = WeekStats();
  final List<DayResult> days = [];

  /// Phase-1 reference: the owner runs the outlet every day and there is no manager wage.
  final bool ownerRun;

  OutletSim(this.b, int seed, {Grade? managerGrade, this.ownerRun = false})
      : rng = SimRng(seed),
        cash = b.i('START_CASH'),
        loanPrincipal0 = b.i('START_LOAN'),
        loanOutstanding = b.i('START_LOAN'),
        reputation = b.d('START_REPUTATION'),
        hygiene = b.d('START_HYGIENE'),
        buzz = b.d('BUZZ_START'),
        freshness = b.d('FRESHNESS_START'),
        crewMorale = b.d('START_CREW_MORALE') {
    final wages = b.map('BASE_WAGE');
    for (final r in b.list('CREW_ROLES')) {
      final role = r as String;
      if (!ownerRun && b.d('WORKING_MANAGER') > 0 && role == 'cashier') {
        continue;
      }
      final skill =
          rng.nextInt(b.i('CREW_SKILL_MIN'), b.i('CREW_SKILL_MAX')).toDouble();
      final base = (wages[role] as num).toDouble();
      // doc 04 §6: reliability and loyalty = tier morale ±20.
      final m = b.d('START_CREW_MORALE');
      crew.add(Staff(
          role,
          skill,
          (base * (0.6 + 0.8 * skill / 100)).round(),
          clampD(m + rng.nextInt(-20, 20), 0, 100),
          clampD(m + rng.nextInt(-20, 20), 0, 100)));
    }
    final eq = b.map('EQUIPMENT');
    for (final t in eq.keys.toList()..sort()) {
      equipment.add(Equipment(
          t,
          rng
              .nextInt(b.i('EQUIP_CONDITION_MIN'), b.i('EQUIP_CONDITION_MAX'))
              .toDouble(),
          rng.nextInt(b.i('EQUIP_AGE_DAYS_MIN'), b.i('EQUIP_AGE_DAYS_MAX'))));
    }
    Manager.wageA = b.d('MGR_WAGE_A');
    Manager.wageB = b.d('MGR_WAGE_B');
    _refreshApplicants();
    manager = managerGrade != null
        ? Manager.generate(rng, managerGrade, 0)
        : applicants.removeAt(0);
    inspectionDay = rng.nextInt(7, 27);
  }

  // ---------------------------------------------------------------- helpers

  Map<String, dynamic> _eq(String t) =>
      (b.map('EQUIPMENT')[t] as Map).cast<String, dynamic>();
  double _eqD(String t, String k) => ((_eq(t)[k] ?? 0) as num).toDouble();
  int get dow => day % 7;
  int get season => (day ~/ b.i('DAYS_PER_SEASON')) % 4;
  bool get ownerPresentToday => ownerRun || plannedVisits.contains(day);
  int get managerWage => ownerRun ? 0 : manager.wage;
  int get crewDailyWage =>
      crew.where((s) => !s.vacant).fold(0, (a, s) => a + s.wage);
  double get crewKitchenSkill {
    final k = crew.where(
        (s) => !s.vacant && (s.role.contains('Cook') || s.role == 'headChef'));
    return k.isEmpty
        ? 30
        : k.map((s) => s.skill).reduce((a, c) => a + c) / k.length;
  }

  double get buzzFactor => 0.90 + 0.20 * buzz;
  double get freshnessFactor => 0.94 + 0.10 * freshness;
  double get competitionFactor => 1 - 0.30 * competition;
  double get repFactor => clampD(0.25 + 0.25 * reputation, 0.4, 1.5);
  double get marketingFactor {
    final s =
        campaigns.where((c) => c.until >= day).fold(0.0, (a, c) => a + c.boost);
    return 1 + math.min(s, b.d('CAMPAIGN_BOOST_CAP'));
  }

  /// 0 below MASTERY_FROM, rising linearly to 1 at MASTERY_FULL (doc 02 §15.16).
  double mastery(double skill) => clampD(
      (skill - b.d('MASTERY_FROM')) /
          (b.d('MASTERY_FULL') - b.d('MASTERY_FROM')),
      0,
      1);

  double get slack {
    if (ownerPresentToday) return 0;
    final grace = b.d('NEGLECT_GRACE_SQ_DIV') > 0
        ? manager.mean * manager.mean / b.d('NEGLECT_GRACE_SQ_DIV')
        : b.d('NEGLECT_GRACE_BASE') + manager.mean / 10;
    final neglect = math.max(0, (day - lastVisitDay) - grace);
    return math.min(b.d('NEGLECT_MAX'), neglect * b.d('NEGLECT_PER_DAY'));
  }

  double get avgPriceSensitivity {
    final mix = b.map('SEGMENT_MIX');
    final sens = b.map('SEGMENT_PRICE_SENSITIVITY');
    return mix.keys.fold(0.0,
        (a, k) => a + (mix[k] as num).toDouble() * (sens[k] as num).toDouble());
  }

  int get weeklyInstalment => loanOutstanding <= 0
      ? 0
      : (math.min(loanPrincipal0 / b.i('LOAN_TERM_WEEKS'),
                  loanOutstanding.toDouble()) +
              loanOutstanding * b.d('LOAN_WEEKLY_RATE'))
          .round();

  /// Fixed cost per day, doc 02 §15.13 plus the manager's wage.
  double get fixedPerDay =>
      (b.i('WEEKLY_RENT') +
          crewDailyWage * b.i('PROTO_CREW_WORK_DAYS') +
          managerWage * 7 +
          weeklyInstalment +
          b.i('UTILITIES_BASE') * 7) /
      7;

  /// Expected groups today without the random term (doc 02 §3.1 step 6).
  double forecast({int? forDay}) {
    final d = forDay ?? day;
    final pIdx = priceIndex * (promoDay == d ? b.d('PROMO_PRICE_MULT') : 1);
    final priceFactor = clampD(1.5 - 0.5 * pIdx, 0.5, 1.3);
    return b.d('BASE_FOOTFALL') *
        repFactor *
        priceFactor *
        b.listD('DOW_FACTOR', d % 7) *
        b.listD('SEASON_FACTOR', (d ~/ b.i('DAYS_PER_SEASON')) % 4) *
        marketingFactor *
        buzzFactor *
        freshnessFactor *
        competitionFactor;
  }

  void _mgr(String key, int coins) =>
      week.managerEvents.add(ManagerEvent(key, coins));

  void _refreshApplicants() {
    final w = b.map('MANAGER_GRADE_WEIGHTS');
    final r =
        reputation; // single outlet: company average rating = its reputation
    final grades = Grade.values;
    final weights = <num>[
      w['trainee'] as num,
      w['junior'] as num,
      w['capable'] as num,
      math.max(0, 10 + 10 * (r - 3.5)),
      math.max(0, 5 + 10 * (r - 4.0)),
    ];
    applicants = List.generate(
        3, (_) => Manager.generate(rng, rng.weighted(grades, weights), day));
  }

  // ---------------------------------------------------------------- owner commands

  String setPrice(int pct) {
    if (pct < 60 || pct > 180) return 'Price must be 60-180% of base.';
    priceIndex = pct / 100;
    return 'Menu prices set to $pct% of base.';
  }

  String runCampaign(String name) {
    final c = (b.map('CAMPAIGNS')[name] as Map?)?.cast<String, dynamic>();
    if (c == null) return 'Unknown campaign $name.';
    final cost = (c['cost'] as num).toInt();
    if (cash < cost) return 'Not enough cash ($cost needed).';
    cash -= cost;
    week.marketing += cost;
    if (name == 'promoDay') promoDay = day;
    // Outcome roll (doc 02 §13.1): an ad can flop or hit big.
    var mult = 1.0;
    var label = 'as expected';
    if (b.d('CAMPAIGN_VARIANCE') > 0) {
      final mix = b.map('SEGMENT_MIX');
      final fit = (c['segments'] as List)
          .fold(0.0, (a, k) => a + (mix[k] as num).toDouble());
      final repeated =
          day - (lastCampaignDay[name] ?? -999) < b.i('CAMPAIGN_REPEAT_DAYS');
      final luck = rng.nextFloat() +
          b.d('CAMPAIGN_FIT_WEIGHT') * (fit - 0.5) +
          (freshness >= 0.8 ? b.d('CAMPAIGN_FRESH_BONUS') : 0) -
          (repeated ? b.d('CAMPAIGN_REPEAT_PENALTY') : 0) +
          b.d('CAMPAIGN_REP_WEIGHT') * (reputation - 3.5);
      final bands = b.list('CAMPAIGN_BANDS');
      for (final band in bands) {
        final m = (band as Map).cast<String, dynamic>();
        mult = (m['mult'] as num).toDouble();
        label = m['label'] as String;
        if (luck < (m['below'] as num).toDouble()) break;
      }
    }
    lastCampaignDay[name] = day;
    lastCampaignMult = mult;
    campaignLog.add((day: day, name: name, mult: mult, cost: cost));
    campaigns.add((
      boost: (c['boost'] as num).toDouble() * mult,
      until: day + (c['days'] as num).toInt() - 1
    ));
    buzz = math.min(1, buzz + (c['buzz'] as num).toDouble() * mult);
    return 'Ran $name (cost $cost): $label. Buzz now ${(buzz * 100).round()}%.';
  }

  String reworkMenu() {
    final chef = crew.firstWhere((s) => s.role == 'headChef');
    if (chef.vacant || chef.skill < 50) {
      return 'Menu rework needs a head chef with skill ≥ 50.';
    }
    final cost = b.i('MENU_REWORK_COST');
    if (cash < cost) return 'Not enough cash ($cost needed).';
    cash -= cost;
    week.marketing += cost;
    freshness = 1;
    buzz = math.min(1, buzz + b.d('MENU_REWORK_BUZZ'));
    chefOffDay = day;
    return 'Menu reworked (cost $cost). Head chef is off the line today.';
  }

  String planVisit() {
    final weekStart = day - dow;
    final used =
        plannedVisits.where((d) => d >= weekStart && d < weekStart + 7).length;
    if (plannedVisits.contains(day)) {
      return 'You are already at the outlet today.';
    }
    if (used >= b.i('PROTO_OWNER_VISITS_PER_WEEK')) {
      return 'You have no owner days left this week.';
    }
    plannedVisits.add(day);
    return 'You will spend today at the outlet.';
  }

  String replaceEquipment(String type) {
    final e = equipment.where((x) => x.type == type).firstOrNull;
    if (e == null) return 'No equipment called $type.';
    final price = _eqD(type, 'price').round();
    if (cash < price) return 'Not enough cash ($price needed).';
    cash -= price;
    week.upkeep += price;
    e
      ..condition = 100
      ..ageDays = 0
      ..broken = true
      ..readyDay = day + 2
      ..refailUntil = -1
      ..warned = false;
    requests.removeWhere((r) => r.contains(type));
    return 'New $type ordered ($price); arrives in 2 days.';
  }

  String repay(int amount) {
    final a = math.min(amount, math.min(cash, loanOutstanding));
    if (a <= 0) return 'Nothing to repay.';
    cash -= a;
    loanOutstanding -= a;
    return 'Repaid $a. Loan outstanding $loanOutstanding.';
  }

  String hireManager(int idx) {
    if (idx < 0 || idx >= applicants.length) return 'No such applicant.';
    final m = applicants[idx];
    if (m.grade == Grade.senior && reputation < 3.5 ||
        m.grade == Grade.veteran && reputation < 4.0) {
      return '${m.name} will not join an outlet rated ${reputation.toStringAsFixed(1)}.';
    }
    final severance = manager.wage * b.i('PROTO_MANAGER_SEVERANCE_DAYS');
    cash -= severance;
    week.other += severance;
    applicants.removeAt(idx);
    m.hiredDay = day;
    final old = manager.name;
    manager = m;
    return 'Hired ${m.name}; paid $old $severance severance.';
  }

  // ---------------------------------------------------------------- the day

  DayResult step() {
    if (gameOver != null) throw StateError('game over');
    final notes = <String>[];
    final present = ownerPresentToday;
    final sl = slack;
    if (present) {
      lastVisitDay = day;
      week.ownerDays++;
      if (day - manager.lastCoachDay >= 7) {
        manager.learn(95);
        manager.lastCoachDay = day;
        notes.add('You coached ${manager.name} (+1 to their weakest skill).');
      }
    }

    // Repairs and deliveries arriving.
    for (final e in equipment) {
      if (e.broken && e.readyDay == day) e.broken = false;
    }

    // Weekly maintenance, Monday prep (doc 02 §15.2, §15.12 upkeep).
    var upkeepToday = 0;
    if (dow == 0) {
      final pDo = present ? 1.0 : clampD(0.3 + manager.upkeep / 100, 0, 1);
      for (final e in equipment) {
        if (e.broken || e.condition >= b.d('MAINTENANCE_THRESHOLD')) continue;
        if (rng.chance(pDo)) {
          final c =
              (_eqD(e.type, 'price') * b.d('MAINTENANCE_COST_PCT')).round();
          upkeepToday += c;
          e.condition =
              math.min(e.maxCondition, e.condition + b.d('MAINTENANCE_GAIN'));
        } else {
          _mgr('managerSkippedMaintenance', 0);
          notes.add('${manager.name} skipped servicing the ${e.type}.');
        }
      }
    }

    // Early warning (upkeep).
    for (final e in equipment) {
      if (!e.broken && !e.warned && e.condition < 45) {
        if (present || rng.chance(manager.upkeep / 100)) {
          e.warned = true;
          requests.add(
              'Replace the ${e.type} (condition ${e.condition.round()}, '
              'max ${e.maxCondition.round()}) before it fails — ${_eqD(e.type, 'price').round()}');
          if (!present) _mgr('managerCaughtWearEarly', 0);
        }
      }
    }

    final closed = day < closedUntil;
    final crewWage = crewDailyWage;
    var wagesToday =
        closed ? 0 : (crewWage * b.i('PROTO_CREW_WORK_DAYS') / 7).round();

    // Staffing gaps (doc 02 §7.4, §15.12 people).
    double gaps = 0;
    var rotaError = false;
    if (!closed) {
      var ownerCover = present ? 1 : 0;
      var mgrStepped = false;
      for (final s in crew) {
        s.absentToday = false;
        if (s.vacant) continue;
        final p = (100 - s.reliability) / b.d('ABSENCE_DIVISOR') +
            (crewMorale < 30 ? 0.05 : 0) +
            (b.d('NEGLECT_ABSENCE_DIVISOR') > 0
                ? sl / b.d('NEGLECT_ABSENCE_DIVISOR')
                : 0);
        s.absentToday = rng.chance(p);
      }
      for (final s in crew) {
        if (!s.vacant && !s.absentToday) continue;
        // PROTO: a hole in a role someone else still fills counts as half a gap.
        final w = crew.any((o) =>
                o != s && o.role == s.role && !o.vacant && !o.absentToday)
            ? 0.5
            : 1.0;
        if (s.vacant) {
          gaps += w;
          continue;
        }
        if (ownerCover > 0) {
          ownerCover--;
          notes.add('A ${s.role} was off sick; you covered.');
        } else if (!present && rng.chance(manager.people / 100)) {
          wagesToday += (s.wage * 1.5).round();
          _mgr(
              'managerCoveredAbsence',
              (forecast() *
                          b.d('PROTO_WALKOUT_PER_GAP') *
                          w *
                          b.d('PROTO_SPEND_PER_GROUP') *
                          priceIndex -
                      s.wage * 0.5)
                  .round());
          notes.add(
              'A ${s.role} was off sick; ${manager.name} called someone in.');
        } else if (!present && b.d('WORKING_MANAGER') > 0 && !mgrStepped) {
          mgrStepped = true;
          gaps += w * b.d('MANAGER_STEP_IN_GAP');
          notes.add('A ${s.role} was off sick; ${manager.name} filled in.');
        } else {
          gaps += w;
          notes.add('A ${s.role} was off sick and nobody covered.');
        }
      }
      if (!present && rng.chance((100 - manager.people) / 300)) {
        gaps += 1;
        rotaError = true;
        notes.add('${manager.name} left someone off the rota.');
      }
      if (!ownerRun && !present && b.d('WORKING_MANAGER') > 0) {
        gaps += math.max(0, b.d('MANAGER_TILL_SKILL_REF') - manager.mean) / 100;
      }
      if (chefOffDay == day) gaps += 1;
      for (final e in equipment.where((e) => e.broken)) {
        gaps += _eqD(e.type, 'gap');
      }
    }

    // Demand (doc 02 §5.1 + doc 11 Part A).
    final fc = forecast();
    final health = buzzFactor * freshnessFactor * competitionFactor;
    final demand = closed ? 0 : (fc * (0.9 + 0.2 * rng.nextFloat())).round();
    final cap = b.i('TABLES') * b.i('PROTO_TABLE_TURNS');
    final seated = math.min(demand, cap);
    final turnedAway = demand - seated;
    final moraleMult = 1 + (50 - crewMorale) / 500;
    final wf = clampD(
        (b.d('PROTO_WALKOUT_BASE') + b.d('PROTO_WALKOUT_PER_GAP') * gaps) *
            moraleMult *
            (1 + sl),
        0,
        0.6);
    final walkouts = (seated * wf).round();
    final served = seated - walkouts;

    // Menu availability and ordering (doc 02 §15.12 stock).
    var menuLoss = 0.0;
    for (final e in equipment.where((e) => e.broken)) {
      menuLoss += _eqD(e.type, 'menuLoss');
    }
    var dev = 0.0;
    if (!present && !closed) {
      dev = rng.uniform(-1, 1) * (100 - manager.stock) / 200;
    }
    if (dev < 0) menuLoss += -dev;
    menuLoss = math.min(menuLoss, 0.8);

    final spend = b.d('PROTO_SPEND_PER_GROUP');
    final pEff = priceIndex * (promoDay == day ? b.d('PROMO_PRICE_MULT') : 1);
    final lossShare = b.d('PROTO_MENU_LOSS_REVENUE_SHARE');
    final revenue =
        (served * spend * pEff * (1 - menuLoss * lossShare)).round();
    final baseFood = served * spend * b.d('PROTO_FOOD_COST');
    // Mastery (doc 02 §15.16): a manager strong on stock negotiates supplier prices.
    final negotiation = ownerRun
        ? 0.0
        : mastery(manager.stock) * b.d('MASTERY_NEGOTIATION_MAX');
    final ingredients = (baseFood *
            (1 +
                b.d('PROTO_BASE_WASTE') +
                math.max(0, dev) +
                sl * b.d('PROTO_OVERPORTION_COST')) *
            (1 - negotiation))
        .round();
    if (negotiation > 0) {
      _mgr('managerNegotiatedPrices', (baseFood * negotiation).round());
    }
    if (dev > 0.02) {
      _mgr('managerOverOrdered', -(baseFood * dev).round());
    } else if (dev < -0.02) {
      _mgr('managerUnderOrdered',
          -(served * spend * pEff * -dev * lossShare).round());
    }
    if (rotaError) {
      _mgr('managerRotaError',
          -(seated * b.d('PROTO_WALKOUT_PER_GAP') * spend * pEff).round());
    }

    // Satisfaction -> stars (doc 02 §6.8 with PROTO_ food/wait inputs).
    final food =
        clampD(b.d('PROTO_FOOD_BASE') + 0.5 * crewKitchenSkill, 0, 100);
    final waitRatio = b.d('PROTO_WAIT_BASE') * moraleMult * (1 + sl) +
        b.d('PROTO_WAIT_PER_GAP') * gaps;
    final wait = clampD(100 * (1 - waitRatio), 0, 100);
    final value = clampD(75 - 100 * (pEff - 1) * avgPriceSensitivity, 0, 100);
    final sat = clampD(
        0.40 * food +
            0.30 * wait +
            0.15 * value +
            0.15 * hygiene -
            10 * menuLoss * b.d('PROTO_UNAVAILABLE_PER_MENU_LOSS'),
        0,
        100);
    final nsW = b.d('NEVER_SEATED_WEIGHT');
    final groupsLeft = served + walkouts + turnedAway;
    final repGroups = served + walkouts + turnedAway * nsW;
    final avgSat = groupsLeft == 0
        ? 0.0
        : (served * sat +
                walkouts * 10 +
                turnedAway * nsW * b.d('NEVER_SEATED_SAT')) /
            repGroups;
    final stars = clampD(avgSat / 20, 0, 5);

    // Utilities (doc 02 §14.1).
    final workingUnits = equipment.where((e) => !e.broken).length;
    final util = closed
        ? b.i('UTILITIES_BASE')
        : (b.d('UTILITIES_BASE') +
                b.d('UTILITIES_PER_GROUP') * served +
                b.d('UTILITIES_PER_UNIT') * workingUnits)
            .round();
    utilitiesAccrued += util;

    // ---- close

    // Equipment wear and breakdowns (doc 02 §10.1, §10.3, §15.12 upkeep).
    for (final e in equipment) {
      e.ageDays++;
      if (e.broken) continue;
      final busy = served > 1.2 * fc ? 1.5 : 1.0;
      final care = ownerRun
          ? 1.0
          : 1 - mastery(manager.upkeep) * b.d('MASTERY_WEAR_MAX');
      e.condition =
          math.max(0, e.condition - _eqD(e.type, 'wear') * busy * care);
      var p = b.d('BREAK_BASE') + math.max(0, 60 - e.condition) / 400;
      final refail = e.refailUntil >= day;
      if (refail) p += b.d('CHEAP_REPAIR_REFAIL') / b.i('PROTO_REFAIL_WINDOW');
      if (!rng.chance(p)) continue;
      e.broken = true;
      e.warned = false;
      final price = _eqD(e.type, 'price');
      final proper = (price * b.d('PROPER_REPAIR_PCT')).round();
      final cheap = (price * b.d('CHEAP_REPAIR_PCT')).round();
      if (refail) _mgr('managerCheapRepairFailed', -cheap);
      upkeepToday += _eqD(e.type, 'spoilage').round();
      if (present || (manager.upkeep >= 60 && cash >= proper)) {
        upkeepToday += proper;
        e
          ..readyDay = day + 3
          ..condition =
              math.min(e.maxCondition, b.d('PROPER_REPAIR_CONDITION'));
        notes.add(
            'The ${e.type} broke down; proper repair ($proper), back in 2 days.');
      } else {
        upkeepToday += cheap;
        e
          ..readyDay = day + 2
          ..condition = b.d('CHEAP_REPAIR_CONDITION')
          ..refailUntil = day + 1 + b.i('PROTO_REFAIL_WINDOW');
        notes.add(
            'The ${e.type} broke down; ${manager.name} paid for a cheap fix ($cheap).');
      }
    }

    // Hygiene (doc 02 §12; cleaning × upkeep and × (1 − slack) per §15.5, §15.12).
    final cleaner = crew.firstWhere((s) => s.role == 'cleaner');
    final cleanMult = present ? 1.0 : (1 - sl) * (0.8 + manager.upkeep / 250);
    hygiene -= served * b.d('HYGIENE_PER_GROUP');
    if (!cleaner.vacant && !closed) {
      // Proportional rule (doc 02 §12): cleaning recovers a share of the dirt present.
      final pct = b.d('HYGIENE_CLEAN_PCT');
      hygiene +=
          (pct > 0 ? pct * (100 - hygiene) : b.d('HYGIENE_PER_CLEANER')) *
              (0.5 + cleaner.skill / 100) *
              cleanMult;
    }
    for (final e in equipment.where((e) => e.broken)) {
      hygiene -= _eqD(e.type, 'hygiene');
    }
    hygiene = clampD(hygiene, 0, 100);

    // Crew happiness (doc 02 §7.3, reduced to the factors this prototype has).
    recentGapDays.add(gaps >= 1);
    if (recentGapDays.length > 7) recentGapDays.removeAt(0);
    final rushShare =
        recentGapDays.where((g) => g).length / recentGapDays.length;
    var target = 50.0 + (manager.people - 50) / 5 - 10 * rushShare;
    if (day - lastVisitDay < 7) target += 3;
    for (final e in equipment.where((e) => e.broken)) {
      target -= _eqD(e.type, 'morale');
    }
    if (hygiene < 50) target -= 3;
    if (lossWeeks >= 4) target -= 10;
    target = clampD(target, 0, 100);
    crewMorale += (target - crewMorale) * b.d('HAPPINESS_SPEED');
    // SPEC-GAP: §15.12 also adds a daily people modifier on top of the Boss factor.
    if (!present && b.d('DOUBLE_PEOPLE_MORALE') > 0) {
      crewMorale += clampD((manager.people - 50) / 50, -1, 1);
    }
    crewMorale = clampD(crewMorale, 0, 100);
    for (final s in crew.where((s) => !s.vacant)) {
      final pQuit = math.max(0, 30 - crewMorale) /
          300 *
          (1 - s.loyalty / 200) *
          (ownerRun
              ? 1
              : 1 - mastery(manager.people) * b.d('MASTERY_RETENTION_MAX'));
      if (rng.chance(pQuit)) {
        s.vacant = true;
        notes.add('Your ${s.role} quit.');
      }
    }

    // Reputation (doc 02 §6.8).
    if (groupsLeft > 0) {
      final w = math.min(1.0, repGroups / 20);
      final k = stars > reputation ? b.d('REP_UP') : b.d('REP_DOWN');
      reputation = clampD(reputation + (stars - reputation) * k * w, 0, 5);
    }

    // Buzz and freshness decay (doc 11 §A.1, §A.2).
    buzz = math.max(0, buzz - b.d('BUZZ_DECAY'));
    freshness = math.max(0, freshness - b.d('FRESHNESS_DECAY'));
    campaigns.removeWhere((c) => c.until < day);

    // Mastery: a manager strong on people develops the crew (doc 02 §15.16).
    if (!ownerRun &&
        (day + 1) % b.i('MASTERY_TRAIN_DAYS') == 0 &&
        rng.chance(mastery(manager.people))) {
      for (final c in crew
          .where((c) => !c.vacant && c.skill < b.d('MASTERY_TRAIN_CAP'))) {
        c.skill += 1;
      }
    }

    // Manager learns on the job (doc 02 §15.12).
    final inPost = day - manager.hiredDay;
    if (inPost > 0 && inPost % b.i('MANAGER_LEARN_DAYS') == 0) {
      manager.learn(b.i('MANAGER_LEARN_CAP'));
    }

    // Manager suggests owner-only actions (doc 11 Part B).
    if (!present && day - lastSuggestionDay >= 7) {
      final pRaise = clampD(0.4 + manager.mean / 100, 0, 1);
      if (buzz < 0.2 && rng.chance(pRaise)) {
        requests.add('${manager.name}: "Quiet lately — run a local ad?"');
        lastSuggestionDay = day;
      } else if (freshness < 0.3 && rng.chance(pRaise)) {
        requests.add(
            '${manager.name}: "Regulars say the menu is stale — rework it?"');
        lastSuggestionDay = day;
      }
    }

    // Money that moves today.
    cash += revenue - ingredients - upkeepToday;
    week.revenue += revenue;
    week.ingredients += ingredients;
    week.upkeep += upkeepToday;
    week.wages += wagesToday;
    week.managerWage += managerWage;
    week.utilities += util;
    week.groups += demand;
    week.served += served;
    week.walkouts += walkouts + turnedAway;

    // Inspection (doc 02 §12).
    if (day == inspectionDay) {
      if (hygiene >= 80) {
        reputation = math.min(5, reputation + 0.1);
        notes.add('Health inspection: passed.');
      } else if (hygiene >= 50) {
        cash -= b.i('INSPECTION_FINE_WARN');
        week.other += b.i('INSPECTION_FINE_WARN');
        inspectionDay = day + 7;
        notes.add(
            'Health inspection: warning, fine ${b.i('INSPECTION_FINE_WARN')}. Re-inspection in 7 days.');
      } else {
        cash -= b.i('INSPECTION_FINE_CLOSE');
        week.other += b.i('INSPECTION_FINE_CLOSE');
        reputation = math.max(0, reputation - 0.5);
        closedUntil = day + 1 + b.i('INSPECTION_CLOSE_DAYS');
        notes.add(
            'Health inspection: FAILED. Closed 2 days, fine ${b.i('INSPECTION_FINE_CLOSE')}.');
      }
    }

    final dayFixed = fixedPerDay;
    final dayProfit = (revenue - ingredients - upkeepToday - dayFixed).round();
    final marginPerGroup = served == 0 ? 0.0 : (revenue - ingredients) / served;
    final breakEven =
        marginPerGroup <= 0 ? 999 : (dayFixed / marginPerGroup).ceil();
    if (!closed && dayProfit < 0) week.losingDays++;

    // Sunday close (doc 02 §14.2).
    if (dow == 6) _weekly(notes);
    // Day 28 close (doc 02 §14.3).
    if (day % 28 == 27) _monthly(notes);
    if ((day + 1) % b.i('MANAGER_APPLICANT_DAYS') == 0) _refreshApplicants();

    // Bankruptcy (doc 02 §14.5; lifeline not modelled).
    negativeDays = cash < 0 ? negativeDays + 1 : 0;
    if (negativeDays >= 3) {
      gameOver = 'Cash below zero for 3 days in a row (week ${day ~/ 7 + 1}).';
    }
    if (missedInRow >= 3) {
      gameOver = 'Missed 3 loan instalments in a row (week ${day ~/ 7 + 1}).';
    }

    final r = DayResult(
      day: day,
      closed: closed,
      ownerPresent: present,
      demand: demand,
      served: served,
      walkouts: walkouts,
      turnedAway: turnedAway,
      revenue: revenue,
      ingredients: ingredients,
      stars: stars,
      gaps: gaps,
      menuLoss: menuLoss,
      slack: sl,
      dayProfit: dayProfit,
      breakEvenGroups: breakEven,
      demandHealth: health,
      notes: notes,
    );
    days.add(r);
    day++;
    return r;
  }

  void _weekly(List<String> notes) {
    cash -= week.wages + week.managerWage;
    week.rent = b.i('WEEKLY_RENT');
    cash -= week.rent;
    final pay = weeklyInstalment;
    if (pay > 0) {
      final interest = (loanOutstanding * b.d('LOAN_WEEKLY_RATE')).round();
      if (cash >= pay) {
        cash -= pay;
        loanOutstanding = math.max(0, loanOutstanding - (pay - interest));
        week.loanPaid = pay;
        week.interest = interest;
        missedInRow = 0;
      } else {
        loanOutstanding += (pay * b.d('MISSED_PAYMENT_PENALTY')).round();
        missedInRow++;
        notes.add(
            'MISSED the loan instalment ($pay). Strike $missedInRow of 3.');
      }
    }
    // Vacancies: manager raises a hire request (§15.12); prototype auto-approves.
    for (final s in crew.where((s) => s.vacant)) {
      if (rng.chance(clampD(0.4 + manager.people / 100, 0, 1))) {
        s.vacant = false;
        notes.add('${manager.name} hired a new ${s.role}.');
      } else {
        _mgr('managerMissedRequest', -s.wage);
      }
    }
    final op = week.netProfit;
    monthProfit += op;
    // Competition (doc 11 §A.5).
    competition = op > 0 && reputation >= 4.0
        ? math.min(b.d('COMPETITION_MAX'), competition + b.d('COMPETITION_UP'))
        : math.max(0, competition - b.d('COMPETITION_DOWN'));
    lossWeeks = op < 0 ? lossWeeks + 1 : 0;
    weeks.add(week);
    week = WeekStats();
  }

  void _monthly(List<String> notes) {
    final tax = math.max(0, (monthProfit * b.d('TAX_RATE')).round());
    final bill = utilitiesAccrued + tax + b.i('LICENCE_FEE');
    cash -= bill;
    // Utilities were already counted as accrued in weekly profit; record tax+licence.
    (weeks.isNotEmpty ? weeks.last : week).other += tax + b.i('LICENCE_FEE');
    notes.add(
        'Monthly bills: utilities $utilitiesAccrued, tax $tax, licence ${b.i('LICENCE_FEE')}.');
    utilitiesAccrued = 0;
    monthProfit = 0;
    inspectionDay = day + rng.nextInt(1, 28);
  }
}

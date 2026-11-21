part of '../sim.dart';

// Finance (doc 02 §14), marketing (§13) and the menu rework (doc 11 §A.2).

const campaignNames = {
  'flyers': 'Flyers',
  'localAd': 'Local ad',
  'promoDay': 'Promotion day',
  'blogger': 'Food blogger',
};
const campaignAudience = {
  'flyers': ['family', 'student'],
  'localAd': ['office', 'family'],
  'promoDay': ['student', 'family'],
};
const segmentNames = {
  'office': 'office workers',
  'family': 'families',
  'student': 'students',
  'tourist': 'tourists'
};

extension _Finance on Sim {
  // ---------------------------------------------------------- weekly and monthly

  WeekRecord _weekRecordFor(Location l) {
    final days = [
      ...l.days.where((d) => d.dayIndex > state.dayIndex - 7),
      l.today
    ];
    final w = WeekRecord(week: state.weekIndex);
    var starsSum = 0.0, starsN = 0.0;
    for (final d in days) {
      w.revenue += d.revenue;
      w.costs += d.costs;
      w.interest += d.interest;
      w.wasteCost += d.wasteCost;
      w.groupsServed += d.groupsServed;
      w.walkouts += d.walkouts;
      w.ingredientSpend += d.ingredientSpend;
      w.wages += d.wages;
      w.rent += d.rent;
      w.marketing += d.marketing;
      w.upkeep += d.upkeep;
      w.other += d.other;
      w.utilities += d.utilities;
      starsSum += d.starsSum;
      starsN += d.starsN;
    }
    w.operatingProfit = w.revenue - w.costs;
    w.avgStars = starsN == 0 ? 0 : starsSum / starsN;
    return w;
  }

  void _weekly() {
    final hq = state.openLocations.first;
    // 1. Wages (accrued daily at each outlet).
    state.cash -= state.wagesOwed;
    emit('cashChanged', {'delta': -state.wagesOwed});
    state.wagesOwed = 0;
    // 2. Rent at every outlet, open or still being fitted out.
    for (final l in state.openLocations) {
      state.cash -= l.rentWeekly;
    }
    // 3. Loan instalments (interest is booked against the first restaurant).
    for (final loan in List<Loan>.of(state.loans)) {
      if (loan.startDay > state.dayIndex - 1) {
        continue; // first instalment next Sunday
      }
      final pay = loan.instalment;
      final interest = loan.interestDue;
      if (pay <= 0) continue;
      if (state.cash >= pay) {
        state.cash -= pay;
        hq.today.interest += interest;
        loan.outstanding -= pay - interest;
        loan.missedInRow = 0;
        state.missedInRow = 0;
        state.creditScore = math.min(100, state.creditScore + 1);
        if (loan.outstanding <= 0) {
          state.loans.remove(loan);
          state.creditScore = math.min(100, state.creditScore + 3);
          state.pendingNotices.add(
              'A loan is fully repaid. The bank trusts you a little more.');
          _timeline('Loan fully repaid');
        }
      } else {
        final private = loan.lender == 'private';
        loan.outstanding += (pay * (private ? 0.10 : 0.05)).round();
        loan.missedInRow++;
        state.missedInRow++;
        state.lastMissDay = state.dayIndex;
        state.creditScore =
            math.max(0, state.creditScore - (private ? 25 : 15));
        at(
            hq,
            () => _note(
                'missedPayment',
                'Missed a loan payment of ${money(pay)}: penalty added, bank trust down',
                pay));
        _timeline('Missed a loan payment (${state.missedInRow} in a row)');
        emit('loanMissed', {'loanId': loan.id});
      }
    }
    // 4. Weekly records: each outlet, then the company.
    final company = WeekRecord(week: state.weekIndex);
    var starsSum = 0.0, starsN = 0.0;
    for (final l in state.openLocations) {
      final w = _weekRecordFor(l);
      l.weeks.add(w);
      if (l.weeks.length > 104) l.weeks.removeAt(0);
      company.revenue += w.revenue;
      company.costs += w.costs;
      company.interest += w.interest;
      company.wasteCost += w.wasteCost;
      company.groupsServed += w.groupsServed;
      company.walkouts += w.walkouts;
      company.ingredientSpend += w.ingredientSpend;
      company.wages += w.wages;
      company.rent += w.rent;
      company.marketing += w.marketing;
      company.upkeep += w.upkeep;
      company.other += w.other;
      company.utilities += w.utilities;
      starsSum += w.avgStars * w.groupsServed;
      starsN += w.groupsServed;
      at(l, () {
        // Competition (doc 11 §A.5); high streets attract rivals twice as fast.
        if (l.reputation >= 4.0 && w.operatingProfit > 0) {
          final up = b.d('COMPETITION_UP') * (l.format == 'highStreet' ? 2 : 1);
          l.competition = math.min(b.d('COMPETITION_MAX'), l.competition + up);
        } else {
          l.competition = math.max(0, l.competition - b.d('COMPETITION_DOWN'));
        }
        _weeklyOutlet(w);
      });
    }
    company.operatingProfit = company.revenue - company.costs;
    company.avgStars = starsN == 0 ? 0 : starsSum / starsN;
    state.weeks.add(company);
    if (state.weeks.length > 104) state.weeks.removeAt(0);
    if (company.netProfit > 0) {
      state.profitableWeeksInRow++;
    } else {
      state.profitableWeeksInRow = 0;
    }
    if (state.investorTaken && company.operatingProfit > 0) {
      final share = (company.operatingProfit * state.investorShare).round();
      state.cash -= share;
      at(
          hq,
          () => _note(
              'investor',
              'Your investor took their ${(state.investorShare * 100).round()}% share: ${money(share)}',
              share));
    }
    if (state.owner.restDaysThisWeek >= 2 && company.netProfit > 0) {
      _completeObjective('obj_2_week_off');
    }
    if (company.revenue > 0 && company.wasteCost < 0.03 * company.revenue) {
      _completeObjective('obj_1_no_waste');
    }
    at(hq, _generateApplicants);
    _weeklyChain();
    _checkStage();
    state.pendingNotices.add('@weekly');
  }

  void _monthly() {
    state.cash -= state.monthUtilities;
    state.monthUtilities = 0;
    // Tax on the company's profit over the last 28 days.
    var profit = 0;
    for (final l in state.openLocations) {
      profit += [
        ...l.days.where((d) => d.dayIndex > state.dayIndex - 28),
        l.today
      ].fold<int>(0, (a, d) => a + d.profit);
    }
    final hq = state.openLocations.first;
    if (profit > 0) {
      final tax = (profit * b.d('TAX_RATE')).round();
      at(hq, () {
        spend(tax, 'other');
        _note('tax', 'Paid ${money(tax)} tax on this month\'s profit', 0);
      });
    }
    for (final l in state.openLocations) {
      at(l, () {
        spend(b.i('LICENCE_FEE'), 'other');
        // Random inspection scheduling (about once per 8 weeks).
        if (l.inspectionDay < state.dayIndex &&
            _rng.chance(28 / b.d('INSPECTION_EVERY_DAYS'))) {
          final day = state.dayIndex + _rng.nextInt(1, 28);
          state.scheduled
              .add(Scheduled('inc_inspection', day, locationId: l.id));
          l.inspectionDay = day;
        }
        // The landlord reviews rent every 168 days after the first 84.
        final since = state.dayIndex - l.openDay;
        if (since >= 83 &&
            !state.scheduled.any((s) =>
                s.incidentId == 'inc_landlord_rent' && s.locationId == l.id)) {
          final next =
              state.flags['${l.id}:next_rent_review'] ?? (l.openDay + 84);
          if (state.dayIndex + 28 >= next) {
            state.scheduled.add(Scheduled(
                'inc_landlord_rent', math.max(next, state.dayIndex + 1),
                locationId: l.id));
            state.flags['${l.id}:next_rent_review'] = next + 168;
          }
        }
      });
    }
    at(hq, () {
      if (_rng.chance(0.10) &&
          (state.cooldowns['${hq.id}:inc_tax_audit'] ?? -1) < state.dayIndex) {
        _raiseIncident('inc_tax_audit', forced: true);
      }
    });
    state.pendingNotices.add('@monthly');
  }

  void _bankruptcyCheck() {
    if (state.cash < 0) {
      state.negativeDays++;
      _timeline('Closed the day with negative cash (${money(state.cash)})');
      if (state.negativeDays == 1 ||
          !state.openIncidents.any((i) => i.incidentId == 'inc_lifeline')) {
        _raiseIncident('inc_lifeline', forced: true);
      }
      if (state.negativeDays >= b.i('BANKRUPT_NEGATIVE_DAYS')) {
        _gameOver(
            'Your cash stayed below zero for ${b.i('BANKRUPT_NEGATIVE_DAYS')} days in a row. The bank closed your account.');
      }
    } else {
      state.negativeDays = 0;
    }
    if (state.missedInRow >= b.i('BANKRUPT_MISSED_PAYMENTS')) {
      _gameOver(
          'You missed ${b.i('BANKRUPT_MISSED_PAYMENTS')} loan payments in a row. The bank took the restaurant.');
    }
  }

  void _gameOver(String reason) {
    if (state.phase == 'gameOver') return;
    state.gameOverReason = reason;
    _timeline(reason);
    state.phase = 'gameOver';
    emit('gameOver', {'reason': reason});
  }

  // ---------------------------------------------------------- credit and loans

  int _equipmentResale(Equipment e) => (content.equipment[e.type]!.price *
          e.condition /
          100 *
          b.d('RESALE_FACTOR'))
      .round();

  int _avgWeeklyOpProfit({int weeks = 8}) {
    final ws = state.weeks.length <= weeks
        ? state.weeks
        : state.weeks.sublist(state.weeks.length - weeks);
    if (ws.isEmpty) return 0;
    return (ws.fold<int>(0, (a, w) => a + w.operatingProfit) / ws.length)
        .round();
  }

  int _valuation() {
    var resale = 0;
    var stars = 0.0;
    for (final l in state.openLocations) {
      resale += l.equipment.fold<int>(0, (a, e) => a + _equipmentResale(e));
      stars += l.reputation;
    }
    final profitPower = (state.perks.contains('perk_brand45')
            ? 45
            : b.i('VALUATION_PROFIT_MULT')) *
        math.max(0, _avgWeeklyOpProfit()).toInt();
    return state.cash +
        resale +
        profitPower +
        (b.d('VALUATION_PER_STAR') * stars).round() +
        state.franchises * b.i('FRANCHISE_VALUE') -
        state.totalOutstanding;
  }

  int _creditLimit() => math.max(
      0,
      (_valuation() * 0.4 * state.creditScore / 100 - state.totalOutstanding)
          .round());

  double _loanRate({bool secured = false, bool private = false}) {
    var r = b.d('LOAN_WEEKLY_RATE') *
        diff('DIFF_INTEREST') *
        (1.6 - state.creditScore / 100);
    if (secured) r *= 0.8;
    if (private) r = b.d('LOAN_WEEKLY_RATE') * diff('DIFF_INTEREST') * 3;
    return r;
  }

  int _currentInstalments() =>
      state.loans.fold<int>(0, (a, l) => a + l.instalment);

  /// The bank's five checks, in order, with pass/fail — shown before applying (doc 07 §4.8).
  List<MapEntry<String, bool>> _bankChecks(int amount, int term, bool secured) {
    final open = state.loans.where((l) => l.lender != 'start' || true).length;
    final firstPay =
        (amount / term + amount * _loanRate(secured: secured)).round();
    final afford = (secured ? 0.7 : 0.5) * _avgWeeklyOpProfit();
    final limit = _creditLimit();
    return [
      MapEntry('Fewer than 3 loans open ($open now)', open < 3),
      MapEntry('No missed payment in the last 4 weeks',
          state.dayIndex - state.lastMissDay > 28),
      MapEntry('Bank trust at least 30 (now ${state.creditScore.round()})',
          state.creditScore >= 30),
      MapEntry(
          'Repayments ${money(_currentInstalments() + firstPay)}/week within ${secured ? 70 : 50}% of weekly profit (${money(afford)})',
          _currentInstalments() + firstPay <= afford),
      MapEntry(
          'Amount within your credit limit (${money(limit)})', amount <= limit),
    ];
  }

  CommandResult _applyLoan(int amount, int term, bool secured, String lender) {
    if (amount < 1000) {
      return CommandResult.fail(
          SimError.invalidValue, 'Borrow at least 1,000.');
    }
    if (![26, 52, 104].contains(term)) {
      return CommandResult.fail(SimError.invalidValue);
    }
    if (lender == 'private') {
      if (state.loans.any((l) => l.lender == 'private')) {
        return CommandResult.fail(SimError.limitReached,
            'The private lender allows only one loan at a time.');
      }
      if (amount > b.i('PRIVATE_LENDER_MAX')) {
        return CommandResult.fail(SimError.invalidValue,
            'The private lender lends up to ${money(b.i('PRIVATE_LENDER_MAX'))}.');
      }
      _addLoan(amount, 26, 'private', false);
      return const CommandResult(true, value: 'approved');
    }
    if (state.bankBlockedUntil > state.dayIndex) {
      return CommandResult.fail(SimError.locked,
          'After a rejection the bank waits 7 days. Try again on day ${state.bankBlockedUntil + 1}.');
    }
    if (secured && state.loans.any((l) => l.secured)) {
      return CommandResult.fail(
          SimError.limitReached, 'This restaurant already secures a loan.');
    }
    final checks = _bankChecks(amount, term, secured);
    const reasons = [
      'tooManyLoans',
      'recentMissedPayment',
      'lowTrust',
      'cannotAfford'
    ];
    for (var i = 0; i < 4; i++) {
      if (!checks[i].value) {
        state.bankBlockedUntil = state.dayIndex + 7;
        return CommandResult(false,
            error: SimError.refused,
            message: 'Rejected: ${checks[i].key}.',
            value: reasons[i]);
      }
    }
    if (!checks[4].value) {
      final limit = _creditLimit();
      if (limit >= 1000) {
        state.counterOffer = limit;
        state.counterOfferTerm = term;
        return CommandResult(true,
            value: 'counterOffer',
            message: 'The bank offers ${money(limit)} instead.');
      }
      state.bankBlockedUntil = state.dayIndex + 7;
      return const CommandResult(false,
          error: SimError.refused,
          message: 'Rejected: over your credit limit.',
          value: 'overLimit');
    }
    _addLoan(amount, term, 'bank', secured);
    return const CommandResult(true, value: 'approved');
  }

  void _addLoan(int amount, int term, String lender, bool secured) {
    final rate = lender == 'private'
        ? _loanRate(private: true)
        : _loanRate(secured: secured);
    state.loans.add(Loan(
        id: state.allocId(),
        lender: lender,
        principal0: amount,
        outstanding: amount,
        weeklyRate: rate,
        termWeeks: term,
        secured: secured,
        startDay: state.dayIndex));
    state.cash += amount;
    emit('cashChanged', {'delta': amount});
    _timeline(
        'Borrowed ${money(amount)} (${lender == 'private' ? 'private lender' : 'bank'})');
  }

  CommandResult _repayLoan(int loanId, int amount) {
    final loan = state.loans.where((l) => l.id == loanId).firstOrNull;
    if (loan == null) return CommandResult.fail(SimError.unknownId);
    final pay = math.min(amount, loan.outstanding);
    if (pay <= 0) return CommandResult.fail(SimError.invalidValue);
    if (state.cash < pay) return CommandResult.fail(SimError.notEnoughCash);
    state.cash -= pay;
    loan.outstanding -= pay;
    if (loan.outstanding <= 0) {
      state.loans.remove(loan);
      state.creditScore = math.min(100, state.creditScore + 3);
      _timeline('Paid off a loan early');
    }
    return const CommandResult(true);
  }

  CommandResult _lifeline(String kind, int? equipmentId) {
    switch (kind) {
      case 'emergencyLoan':
        final amount = math.max(0, -state.cash) + b.i('EMERGENCY_LOAN_EXTRA');
        _addLoan(amount, 26, 'private', false);
        state.loans.last.weeklyRate = _loanRate() * 3;
      case 'sellEquipment':
        final e = loc.equipmentById(equipmentId);
        if (e == null) return CommandResult.fail(SimError.unknownId);
        final v = (_equipmentResale(e) * 0.5).round();
        loc.equipment.remove(e);
        earn(v, 'none');
        _timeline(
            'Sold ${content.equipment[e.type]!.name} in a hurry for ${money(v)}');
      case 'investor':
        if (state.investorTaken) {
          return CommandResult.fail(
              SimError.limitReached, 'Only one investor per game.');
        }
        state.investorTaken = true;
        state.investorShare = b.d('INVESTOR_SHARE');
        earn(b.i('INVESTOR_CASH'), 'none');
        _timeline(
            'Took an investor: ${money(b.i('INVESTOR_CASH'))} for 20% of weekly profit forever');
      default:
        return CommandResult.fail(SimError.invalidValue);
    }
    return const CommandResult(true);
  }

  // ---------------------------------------------------------- marketing

  double _campaignFit(String type) {
    final mix = content.locationClasses[loc.classId]!.segmentMix;
    final aud = campaignAudience[type];
    if (aud == null) return 0.5;
    return aud.fold(0.0, (a, s) => a + (mix[s] ?? 0));
  }

  String _fitWord(double fit) =>
      fit < 0.45 ? 'poor' : (fit < 0.6 ? 'fair' : 'good');

  int? _lastCampaignDay(String type) {
    int? last;
    for (final c in loc.campaigns) {
      if (c.type == type && (last == null || c.startDay > last)) {
        last = c.startDay;
      }
    }
    return last;
  }

  CommandResult _startCampaign(String type) {
    if (state.stage < 2) {
      return CommandResult.fail(
          SimError.locked, 'Marketing unlocks at Stage 2 (Stable).');
    }
    final def = b.map('CAMPAIGNS')[type] as Map?;
    if (def == null) return CommandResult.fail(SimError.unknownId);
    final cost = ((def['cost'] as num) *
            (state.perks.contains('perk_highStreet') ? 0.85 : 1))
        .round();
    if (state.cash < cost) {
      return CommandResult.fail(
          SimError.notEnoughCash, 'This campaign costs ${money(cost)}.');
    }
    final start = state.phase == 'close' ? state.dayIndex + 1 : state.dayIndex;
    if (loc.campaigns.any((c) => c.type == type && c.endDay >= start)) {
      return CommandResult.fail(
          SimError.limitReached, 'That campaign is already running.');
    }
    if (type == 'blogger') {
      spend(cost, 'marketing');
      state.flags['${loc.id}:blogger_pending'] = start + 3;
      state.flags.remove('${loc.id}:blogger_done');
      loc.campaigns.add(Campaign(
          id: state.allocId(),
          type: type,
          startDay: start,
          endDay: start + 3,
          cost: cost,
          boost: 0,
          mult: 1,
          outcome: 'pending',
          reason: 'A food blogger will visit within 3 days.',
          revealed: true));
      return const CommandResult(true);
    }
    final fit = _campaignFit(type);
    final last = _lastCampaignDay(type);
    final repeat = last != null && start - last < 21;
    final fresh = loc.freshness >= 0.8;
    final luck = _rng.nextFloat() +
        b.d('CAMPAIGN_FIT_WEIGHT') * (fit - 0.5) +
        (fresh ? b.d('CAMPAIGN_FRESH_BONUS') : 0) -
        (repeat ? b.d('CAMPAIGN_REPEAT_PENALTY') : 0) +
        b.d('CAMPAIGN_REP_WEIGHT') * (loc.reputation - 3.5);
    final table = [
      [0.15, 0.0, 'Flopped'],
      [0.40, 0.5, 'Weak response'],
      [0.75, 1.0, 'As expected'],
      [0.93, 1.5, 'Worked well'],
      [99.0, 3.5, 'Big hit'],
    ];
    late double mult;
    late String outcome;
    for (final row in table) {
      if (luck < (row[0] as double)) {
        mult = row[1] as double;
        outcome = row[2] as String;
        break;
      }
    }
    final name = campaignNames[type]!;
    final aud =
        campaignAudience[type]!.map((s) => segmentNames[s]).join(' and ');
    String reason;
    if (mult == 0) {
      reason = repeat
          ? 'The $name flopped. People had seen the same thing only days ago.'
          : (fit < 0.45
              ? 'The $name flopped. Few $aud around here.'
              : 'The $name flopped. Bad luck: it happens to every ad sometimes.');
    } else if (mult < 1) {
      reason =
          'The $name got a weak response${repeat ? ' — it was too soon after the last one' : ''}.';
    } else if (mult == 1) {
      reason = 'The $name did about what was expected.';
    } else {
      reason =
          'The $name ${mult > 2 ? 'was a big hit' : 'worked well'}${fresh ? ' — a fresh menu gave people a reason to come' : ''}.';
    }
    spend(cost, 'marketing');
    final days = (def['days'] as num).toInt();
    final boost = (def['boost'] as num).toDouble() * mult;
    final buzzGain = (def['buzz'] as num).toDouble() * mult;
    final before = loc.buzz;
    loc.buzz = math.min(1, loc.buzz + buzzGain);
    loc.campaigns.add(Campaign(
      id: state.allocId(),
      type: type,
      startDay: start,
      endDay: start + days - 1,
      cost: cost,
      boost: boost,
      mult: mult,
      outcome: outcome,
      reason: reason,
      buzzLeft: loc.buzz - before,
    ));
    _note('campaign', 'Started a $name (${money(cost)})', cost);
    return const CommandResult(true);
  }

  void _bloggerVisit(double stars) {
    state.flags['${loc.id}:blogger_done'] = 1 << 30;
    state.flags.remove('${loc.id}:blogger_pending');
    final c = loc.campaigns.where((c) => c.type == 'blogger').lastOrNull;
    if (stars >= 4) {
      loc.reputation = math.min(5, loc.reputation + 0.3);
      loc.buzz = math.min(1, loc.buzz + 0.3);
      c?.outcome = 'Big hit';
      c?.reason =
          'The food blogger loved it (${stars.toStringAsFixed(1)}★): rating +0.3.';
    } else {
      loc.reputation = math.max(0, loc.reputation - 0.2);
      c?.outcome = 'Flopped';
      c?.reason =
          'The food blogger was not impressed (${stars.toStringAsFixed(1)}★): rating −0.2.';
    }
    if (c != null) state.pendingNotices.add(c.reason);
  }

  /// Return on spend per campaign (doc 02 §13.2).
  void _campaignAccounting() {
    final l = loc;
    final t = loc.today;
    final active =
        l.campaigns.where((c) => c.type != 'blogger' && !c.settled).toList();
    if (active.isEmpty) return;
    final boosts = l.campaigns
        .where((c) =>
            c.type != 'blogger' &&
            state.dayIndex >= c.startDay &&
            state.dayIndex <= c.endDay)
        .toList();
    final sumBoost = boosts.fold(0.0, (a, c) => a + c.boost);
    final boostEff = math.min(sumBoost, b.d('CAMPAIGN_BOOST_CAP'));
    final sumBuzzLeft = active.fold(0.0, (a, c) => a + c.buzzLeft);
    final bf = 0.90 + 0.20 * l.buzz;
    final bfWithout = 0.90 + 0.20 * math.max(0, l.buzz - sumBuzzLeft);
    final lift = (1 + boostEff) * bf / bfWithout;
    final groups = t.groupsArrived;
    final seated = t.groupsSeated;
    if (groups > 0 && lift > 1.0001) {
      final baseGroups = groups / lift;
      final extraSeated =
          math.max(0.0, seated - math.min(baseGroups, seated.toDouble()));
      final weights = <Campaign, double>{};
      for (final c in active) {
        var w = 0.0;
        if (boosts.contains(c) && sumBoost > 0) {
          w += boostEff * c.boost / sumBoost;
        }
        w += 0.20 * c.buzzLeft / bfWithout;
        if (w > 0) weights[c] = w;
      }
      final totalW = weights.values.fold(0.0, (a, w) => a + w);
      final perGroup =
          seated == 0 ? 0 : (t.revenue - t.ingredientsUsedCost) / seated;
      weights.forEach((c, w) {
        final share = extraSeated * w / totalW;
        c.extraGroups += share;
        c.extraProfit += share * perGroup;
        if (c.type == 'promoDay' && c.startDay == state.dayIndex) {
          final avgBill = seated == 0 ? 0 : t.revenue / seated;
          c.discountGiven += (baseGroups * avgBill * (1 / 0.75 - 1)).round();
        }
      });
    }
    for (final c in active) {
      if (state.dayIndex > c.endDay && c.buzzLeft < 0.0005) c.settled = true;
    }
  }

  CommandResult _reworkMenu() {
    final chef = loc.staff.where((s) => s.role == 'headChef').firstOrNull;
    if (chef == null) {
      return CommandResult.fail(
          SimError.locked, 'You need a head chef to rework the menu.');
    }
    if (chef.skill < b.d('MENU_REWORK_SKILL')) {
      return CommandResult.fail(SimError.locked,
          '${chef.name} needs skill ${b.i('MENU_REWORK_SKILL')} to rework the menu (now ${chef.skill.round()}).');
    }
    final cost = b.i('MENU_REWORK_COST');
    if (state.cash < cost) {
      return CommandResult.fail(
          SimError.notEnoughCash, 'A menu rework costs ${money(cost)}.');
    }
    spend(cost, 'marketing');
    loc.freshness = 1;
    loc.buzz = math.min(1, loc.buzz + b.d('MENU_REWORK_BUZZ'));
    loc.lastReworkDay = state.dayIndex;
    final day = state.phase == 'close' ? state.dayIndex + 1 : state.dayIndex;
    chef.trainingUntil = math.max(chef.trainingUntil, day + 1);
    if (state.phase == 'prep') chef.workingToday = false;
    _note('rework', 'Reworked the menu: it feels new again', cost);
    _timeline('Reworked the menu');
    return const CommandResult(true);
  }
}

part of '../sim.dart';

// Command dispatch and the remaining command handlers.

extension _Handlers on Sim {
  bool _inPhase(List<String> phases) => phases.contains(state.phase);

  CommandResult _handle(Command c) {
    if (state.phase == 'gameOver')
      return CommandResult.fail(SimError.wrongPhase, 'The game is over.');
    const prepClose = ['prep', 'close'];
    switch (c) {
      case BuyDueDiligence(:final offerIndex):
        if (!_inPhase(['market']))
          return CommandResult.fail(SimError.wrongPhase);
        return _dueDiligence(offerIndex);
      case BuyRestaurant(:final offerIndex):
        if (!_inPhase(['market']))
          return CommandResult.fail(SimError.wrongPhase);
        return _buy(offerIndex);
      case ResolveIncident(:final instanceId, :final optionId):
        final inst = state.incidents
            .where((i) => i.id == instanceId && !i.resolved)
            .firstOrNull;
        if (inst == null) return CommandResult.fail(SimError.unknownId);
        final def = content.incidents[inst.incidentId]!;
        final opt = def.options.where((o) => o.id == optionId).firstOrNull;
        if (opt == null) return CommandResult.fail(SimError.unknownId);
        final why = _optionBlocked(opt, inst);
        if (why != null) return CommandResult.fail(SimError.locked, why);
        _resolveIncident(inst, optionId);
        return CommandResult(true, value: inst.result);
      default:
        break;
    }
    if (!state.hasLocation)
      return CommandResult.fail(SimError.wrongPhase, 'Buy a restaurant first.');
    switch (c) {
      case StartService():
        if (!_inPhase(['prep'])) return CommandResult.fail(SimError.wrongPhase);
        _applyPendingDefaults('prep');
        if (state.phase == 'gameOver') return const CommandResult(true);
        if (loc.closedUntil > state.dayIndex) {
          state.today.closed = true;
          state.today.add('closed', 'The restaurant was closed today', 500);
          loc.service = ServiceState(done: true, forecast: 0);
          state.phase = 'close';
          _closeDay();
          return const CommandResult(true);
        }
        _startService();
        return const CommandResult(true);
      case EndService():
        // Skip to the end: run the remaining ticks at once.
        if (!_inPhase(['service']))
          return CommandResult.fail(SimError.wrongPhase);
        var guard = 0;
        while (state.phase == 'service' && guard++ < 1000) {
          for (final inc in state.openIncidents.where((i) => i.countdown > 0)) {
            inc.countdown = 1;
          }
          _serviceTick();
        }
        return const CommandResult(true);
      case EndDay():
        if (!_inPhase(['close']))
          return CommandResult.fail(SimError.wrongPhase);
        _applyPendingDefaults('close');
        if (state.phase == 'gameOver') return const CommandResult(true);
        state.days.add(state.today);
        if (state.days.length > 56) state.days.removeAt(0);
        state.dayIndex++;
        _beginDay();
        return const CommandResult(true);
      case OwnerQueueTask(:final taskId):
        if (!_inPhase(['service']))
          return CommandResult.fail(SimError.wrongPhase);
        return _ownerQueue(taskId);
      case OwnerStand(:final area):
        if (area != null && !areaTasks.containsKey(area))
          return CommandResult.fail(SimError.invalidValue);
        if (state.phase == 'service') {
          ss.ownerArea = area;
        } else if (state.phase == 'prep') {
          state.owner.startArea = area;
        } else {
          return CommandResult.fail(SimError.wrongPhase);
        }
        return const CommandResult(true);
      case OwnerRush(:final groupId):
        if (!_inPhase(['service']))
          return CommandResult.fail(SimError.wrongPhase);
        return _rush(groupId);
      case OwnerTreat(:final groupId):
        if (!_inPhase(['service']))
          return CommandResult.fail(SimError.wrongPhase);
        return _treat(groupId);
      case OwnerBringBill(:final groupId):
        if (!_inPhase(['service']))
          return CommandResult.fail(SimError.wrongPhase);
        return _bringBill(groupId);
      case MoveStaff(:final staffId, :final role):
        if (!_inPhase(['service']))
          return CommandResult.fail(SimError.wrongPhase);
        return _moveStaff(staffId, role);
      case OwnerRest(:final rest):
        if (!_inPhase(['prep'])) return CommandResult.fail(SimError.wrongPhase);
        state.owner.restingToday = rest;
        return const CommandResult(true);
      case SetDishEnabled(:final dishId, :final enabled):
        final m = loc.menu[dishId];
        if (m == null) return CommandResult.fail(SimError.unknownId);
        if (!enabled &&
            loc.menu.values.where((x) => x.enabled).length <= b.i('MENU_MIN')) {
          return CommandResult.fail(SimError.limitReached,
              'A menu needs at least ${b.i('MENU_MIN')} dishes.');
        }
        if (enabled && !m.enabled) {
          if (state.dayIndex - m.offSinceDay >= 14 &&
              state.dayIndex - loc.lastRotateDay >= 7) {
            loc.freshness =
                math.min(1, loc.freshness + b.d('ROTATE_FRESHNESS'));
            loc.lastRotateDay = state.dayIndex;
            emit('menuRotated');
          }
        } else if (!enabled && m.enabled) {
          m.offSinceDay = state.dayIndex;
        }
        m.enabled = enabled;
        return const CommandResult(true);
      default:
        break;
    }
    if (!_inPhase(prepClose))
      return CommandResult.fail(
          SimError.wrongPhase, 'Do that before or after service.');
    switch (c) {
      case SetDayOff(:final staffId, :final weekday):
        return _setDayOff(staffId, weekday);
      case WorkDayOff(:final staffId):
        return _workDayOff(staffId);
      case PlaceOrder(:final supplierId, :final lines):
        return _placeOrder(supplierId, lines);
      case CancelOrder(:final orderId):
        final o = loc.orders.where((x) => x.id == orderId).firstOrNull;
        if (o == null) return CommandResult.fail(SimError.unknownId);
        if (o.placedDay != state.dayIndex)
          return CommandResult.fail(SimError.locked, 'Too late to cancel.');
        loc.orders.remove(o);
        return const CommandResult(true);
      case SetPrice(:final dishId, :final price):
        final m = loc.menu[dishId];
        if (m == null) return CommandResult.fail(SimError.unknownId);
        final base = content.dishes[dishId]!.basePrice;
        final lo = (base * b.d('PRICE_MIN_MULT')).ceil(),
            hi = (base * b.d('PRICE_MAX_MULT')).floor();
        if (price < lo || price > hi)
          return CommandResult.fail(
              SimError.invalidValue, 'Price must be between $lo and $hi.');
        m.price = price;
        return const CommandResult(true);
      case Hire(:final applicantId):
        return _hire(applicantId);
      case Fire(:final staffId):
        return _fire(staffId);
      case SetWage(:final staffId, :final wage):
        return _setWage(staffId, wage);
      case Train(:final staffId):
        return _train(staffId);
      case GiveDayOff(:final staffId):
        return _giveDayOff(staffId);
      case Warn(:final staffId):
        return _warn(staffId);
      case Promote(:final staffId):
        return _promote(staffId);
      case Maintain(:final equipmentId):
        return _maintain(equipmentId);
      case Repair(:final equipmentId, :final mode):
        final e = loc.equipmentById(equipmentId);
        if (e == null || !e.broken)
          return CommandResult.fail(
              SimError.invalidValue, 'Nothing to repair.');
        final cost = (content.equipment[e.type]!.price *
                ((b.map('REPAIR')[mode] as Map)['cost'] as num))
            .round();
        if (state.cash < cost)
          return CommandResult.fail(
              SimError.notEnoughCash, 'The repair costs ${money(cost)}.');
        final inst = IncidentInstance(
            id: 0,
            incidentId: 'manual',
            subjectId: e.id,
            createdDay: state.dayIndex);
        _applyEffect({'type': 'repair', 'mode': mode}, inst, []);
        return const CommandResult(true);
      case BuyEquipment(:final type, :final secondHand, :final replaceId):
        return _buyEquipment(type,
            secondHand: secondHand, replaceId: replaceId);
      case SellEquipment(:final equipmentId):
        final e = loc.equipmentById(equipmentId);
        if (e == null) return CommandResult.fail(SimError.unknownId);
        final v = _equipmentResale(e);
        loc.equipment.remove(e);
        earn(v, 'none');
        _note('sold', 'Sold ${content.equipment[e.type]!.name} for ${money(v)}',
            0);
        return CommandResult(true, value: v);
      case ApplyLoan(
          :final amount,
          :final termWeeks,
          :final secured,
          :final lender
        ):
        return _applyLoan(amount, termWeeks, secured, lender);
      case AcceptCounterOffer():
        final amt = state.counterOffer;
        if (amt == null) return CommandResult.fail(SimError.invalidValue);
        state.counterOffer = null;
        _addLoan(amt, state.counterOfferTerm, 'bank', false);
        return const CommandResult(true);
      case RepayLoan(:final loanId, :final amount):
        return _repayLoan(loanId, amount);
      case StartCampaign(:final type):
        return _startCampaign(type);
      case ReworkMenu():
        return _reworkMenu();
      case SetParLevel(:final ingredientId, :final par, :final supplierId):
        if (state.stage < 2)
          return CommandResult.fail(
              SimError.locked, 'Keep-in-stock levels unlock at Stage 2.');
        if (par <= 0) {
          loc.parLevels.remove(ingredientId);
        } else {
          loc.parLevels[ingredientId] = ParLevel(par, supplierId);
        }
        return const CommandResult(true);
      case PayPayable(:final payableId):
        return _payPayable(payableId);
      case TakeLifeline(:final kind, :final equipmentId):
        return _lifeline(kind, equipmentId);
      default:
        return CommandResult.fail(SimError.invalidValue);
    }
  }

  /// Unanswered cards of the phase being left take their default option.
  void _applyPendingDefaults(String phase) {
    for (final inst in state.openIncidents) {
      final def = content.incidents[inst.incidentId]!;
      if (def.timing == phase || phase == 'close' || inst.countdown < 0) {
        _resolveIncident(inst, def.defaultOption, ignored: true);
      }
    }
    // Keep the list short: drop old resolved cards.
    state.incidents
        .removeWhere((i) => i.resolved && i.createdDay < state.dayIndex - 1);
    if (phase == 'close') _bankruptcyCheckAfterDefaults();
  }

  void _bankruptcyCheckAfterDefaults() {
    if (state.negativeDays >= b.i('BANKRUPT_NEGATIVE_DAYS') && state.cash < 0) {
      _gameOver(
          'Your cash stayed below zero for ${b.i('BANKRUPT_NEGATIVE_DAYS')} days in a row.');
    }
  }

  CommandResult _dueDiligence(int i) {
    if (i < 0 || i >= state.offers.length)
      return CommandResult.fail(SimError.unknownId);
    final o = state.offers[i];
    if (o.inspected)
      return CommandResult.fail(SimError.limitReached, 'Already inspected.');
    final cost = b.i('DUE_DILIGENCE_COST');
    if (state.cash < cost) return CommandResult.fail(SimError.notEnoughCash);
    state.cash -= cost;
    o.inspected = true;
    final hidden = List<HiddenProblem>.of(o.location.hidden);
    _rng.shuffle(hidden);
    final reveal = (hidden.length / 2).ceil();
    for (var k = 0; k < reveal; k++) {
      hidden[k].revealed = true;
    }
    return CommandResult(true, value: reveal);
  }

  CommandResult _buy(int i) {
    if (i < 0 || i >= state.offers.length)
      return CommandResult.fail(SimError.unknownId);
    final o = state.offers[i];
    final need = o.price - o.loan;
    if (state.cash < need) return CommandResult.fail(SimError.notEnoughCash);
    state.cash -= need;
    state.locations = [o.location];
    state.offers.clear();
    if (o.loan > 0) {
      state.loans.add(Loan(
        id: state.allocId(),
        lender: 'start',
        principal0: o.loan,
        outstanding: o.loan,
        weeklyRate: b.d('LOAN_WEEKLY_RATE') * diff('DIFF_INTEREST'),
        termWeeks: 52,
        secured: true,
        startDay: 0,
      ));
    }
    _activateHiddenProblems(o.location);
    _generateApplicants();
    state.dayIndex = 0;
    _timeline(
        'Bought ${o.location.name} for ${money(o.price)}${o.loan > 0 ? ' with a ${money(o.loan)} loan' : ''}');
    state.pendingNotices.add('@welcome');
    _beginDay();
    return const CommandResult(true);
  }

  CommandResult _maintain(int id) {
    final e = loc.equipmentById(id);
    if (e == null) return CommandResult.fail(SimError.unknownId);
    if (e.broken)
      return CommandResult.fail(SimError.invalidValue,
          'It is broken: it needs a repair, not servicing.');
    if (state.dayIndex - e.lastMaintDay < 7)
      return CommandResult.fail(
          SimError.limitReached, 'Serviced this week already.');
    final t = content.equipment[e.type]!;
    final cost = (t.price * b.d('MAINTENANCE_PCT')).round();
    if (state.cash < cost) return CommandResult.fail(SimError.notEnoughCash);
    if (e.condition >= _maxCondition(e) - 0.5) {
      return CommandResult.fail(SimError.limitReached,
          'Already as good as its age allows (${_maxCondition(e).round()}).');
    }
    spend(cost, 'upkeep');
    final quick = e.condition >= 50;
    e.condition =
        math.min(_maxCondition(e), e.condition + b.d('MAINTENANCE_GAIN'));
    e.lastMaintDay = state.dayIndex;
    if (!quick) {
      final day = state.phase == 'close' ? state.dayIndex + 1 : state.dayIndex;
      e.unavailableUntil = math.max(e.unavailableUntil, day + 1);
    }
    _markFridge(e);
    return CommandResult(true, value: quick ? 'quick' : 'slow');
  }

  CommandResult _buyEquipment(String type,
      {bool secondHand = false, int? replaceId}) {
    final t = content.equipment[type];
    if (t == null) return CommandResult.fail(SimError.unknownId);
    final price = (t.price * (secondHand ? 0.5 : 1)).round();
    final old = replaceId == null ? null : loc.equipmentById(replaceId);
    final trade = old == null ? 0 : _equipmentResale(old);
    if (state.cash + trade < price)
      return CommandResult.fail(
          SimError.notEnoughCash, 'You need ${money(price - trade)}.');
    if (old != null) {
      loc.equipment.remove(old);
      if (trade > 0) earn(trade, 'none');
    }
    spend(price, 'upkeep');
    final arrive = state.dayIndex +
        (state.phase == 'close' ? 1 : 0) +
        (secondHand ? 1 : 2);
    final e = Equipment(
      id: state.allocId(),
      type: type,
      condition: secondHand ? 55 : 100,
      ageDays: secondHand ? 3 * 336 : 0,
      unavailableUntil: arrive,
    );
    e.condition = math.min(e.condition, _maxCondition(e));
    loc.equipment.add(e);
    _markFridge(e);
    _timeline(
        'Bought a ${secondHand ? 'second-hand' : 'new'} ${t.name.toLowerCase()} (${money(price)})');
    return CommandResult(true, value: e.id);
  }
}

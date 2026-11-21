part of '../sim.dart';

// Inventory: batches, FIFO, capacity, prices, orders, deliveries, payables (doc 02 §9).

extension _Inventory on Sim {
  /// FIFO (oldest = fewest days left first). Returns the cost of what was used.
  int _consumeRecipe(
      Dish dish, void Function(int quality, int daysLeft) onBatch) {
    var cost = 0.0;
    for (final r in dish.recipe) {
      var need = r.qty;
      final batches = loc.stock
          .where((x) => x.ingredientId == r.ingredientId)
          .toList()
        ..sort((a, c) => a.daysLeft.compareTo(c.daysLeft));
      for (final bt in batches) {
        if (need <= 0) break;
        final take = math.min(need, bt.qty);
        bt.qty -= take;
        need -= take;
        onBatch(bt.quality, bt.daysLeft);
      }
      cost += r.qty *
          content.ingredients[r.ingredientId]!.baseCost *
          (loc.priceIndex[r.ingredientId] ?? 1);
    }
    loc.stock.removeWhere((x) => x.qty <= 0);
    return cost.round();
  }

  int _capacity(String storage) {
    var n = 0;
    for (final e in loc.equipment) {
      final t = content.equipment[e.type]!;
      if (t.storage == storage && !e.broken) n += t.capacity;
    }
    return n;
  }

  int _stored(String storage) {
    var n = 0;
    for (final bt in loc.stock) {
      if (content.ingredients[bt.ingredientId]!.storage == storage) n += bt.qty;
    }
    return n;
  }

  double _effectivePriceIndex(String ingredientId) {
    var pi = loc.priceIndex[ingredientId] ?? 1.0;
    final cat = content.ingredients[ingredientId]!.category;
    if ((loc.categorySpikeUntil[cat] ?? -1) >= state.dayIndex) {
      pi *= b.d('PRICE_SPIKE_MULT');
    }
    return pi;
  }

  /// Unit price with two decimals (doc 02 §9.2).
  double _unitPrice(String supplierId, String ingredientId) {
    final sup = content.suppliers[supplierId]!;
    final ing = content.ingredients[ingredientId]!;
    final creep =
        math.pow(b.d('YEARLY_COST_CREEP_INGREDIENT'), state.dayIndex ~/ 336);
    var mult = sup.priceMult - (loc.supplierDeal[supplierId] ?? 0);
    // A skilled manager negotiates (doc 02 §15.16); a bulk contract cuts every price.
    final m = loc.manager;
    if (m != null) mult *= 1 - 0.08 * _mastery(m.stockSkill);
    if (state.bulkContractUntil > state.dayIndex)
      mult *= 1 - b.d('BULK_CONTRACT_DISCOUNT');
    if (state.perks.contains('perk_bulk3')) mult *= 0.97;
    return ((ing.baseCost * creep * _effectivePriceIndex(ingredientId) * mult) *
                100)
            .round() /
        100;
  }

  bool _supplierSells(String supplierId, String ingredientId) {
    final sup = content.suppliers[supplierId]!;
    final ing = content.ingredients[ingredientId]!;
    if (!sup.categories.contains(ing.category)) return false;
    if (loc.shortageIngredient == ingredientId &&
        loc.shortageUntil >= state.dayIndex &&
        supplierId != 'sup_premium') {
      return false;
    }
    return true;
  }

  int _orderTotal(String supplierId, Map<String, int> lines) {
    var t = 0.0;
    lines.forEach((ing, q) => t += q * _unitPrice(supplierId, ing));
    return t.round();
  }

  CommandResult _placeOrder(String supplierId, Map<String, int> lines,
      {bool auto = false}) {
    if (state.phase != 'prep' && state.phase != 'close') {
      return CommandResult.fail(SimError.wrongPhase);
    }
    final sup = content.suppliers[supplierId];
    if (sup == null) return CommandResult.fail(SimError.unknownId);
    if ((loc.supplierBlockedUntil[supplierId] ?? -1) >= state.dayIndex) {
      return CommandResult.fail(
          SimError.locked, '${sup.name} will not deliver to you for now.');
    }
    final clean = <String, int>{};
    lines.forEach((k, v) {
      if (v > 0) clean[k] = v;
    });
    if (clean.isEmpty) {
      return CommandResult.fail(SimError.invalidValue, 'The order is empty.');
    }
    for (final ing in clean.keys) {
      if (!_supplierSells(supplierId, ing)) {
        return CommandResult.fail(SimError.invalidValue,
            '${sup.name} cannot supply ${content.ingredients[ing]?.name ?? ing} right now.');
      }
    }
    if (sup.leadDays == 0 && state.phase != 'prep') {
      return CommandResult.fail(SimError.wrongPhase,
          'Cash & Carry is a same-day trip: only during prep.');
    }
    final total = _orderTotal(supplierId, clean);
    if (total < sup.minOrder) {
      return CommandResult.fail(SimError.belowMinimumOrder,
          '${sup.name} needs an order of at least ${money(sup.minOrder)} (this one is ${money(total)}).');
    }
    final payNow = sup.leadDays == 0;
    if (payNow && state.cash < total) {
      return CommandResult.fail(SimError.notEnoughCash,
          'Cash & Carry wants cash: you need ${money(total)}.');
    }
    final order = StockOrder(
      id: state.allocId(),
      supplierId: supplierId,
      lines: clean,
      dueDay: state.dayIndex + (state.phase == 'close' ? 1 : sup.leadDays),
      total: total,
      placedDay: state.dayIndex,
    );
    if (sup.leadDays == 0) {
      _deliver(order, immediate: true);
    } else {
      loc.orders.add(order);
    }
    emit('orderPlaced', {'supplierId': supplierId, 'total': total});
    return CommandResult(true, value: order.id);
  }

  /// At prep: deliveries due today (doc 02 §9.3).
  void _processDeliveries() {
    final due = loc.orders.where((o) => o.dueDay <= state.dayIndex).toList();
    for (final o in due) {
      loc.orders.remove(o);
      final sup = content.suppliers[o.supplierId]!;
      if (!o.late && _rng.chance(1 - sup.reliability)) {
        final r = _rng.nextFloat();
        if (r < 0.5) {
          o.late = true;
          o.dueDay = state.dayIndex + 1;
          loc.orders.add(o);
          _note('deliveryLate', '${sup.name} delivery is a day late', o.total);
          _raiseIncident('inc_delivery_late',
              subjectKey: o.supplierId, forced: true, vars: {'orderId': o.id});
          continue;
        } else if (r < 0.8) {
          final share = _rng.range(0.5, 0.8);
          o.lines.updateAll((k, v) => (v * share).floor());
          o.total = _orderTotal(o.supplierId, o.lines);
          _note('deliveryShort', '${sup.name} delivered only part of the order',
              0);
          state.pendingNotices.add(
              '${sup.name} delivered only about ${(share * 100).round()}% of your order. You were charged only for what came.');
          _deliver(o);
        } else {
          _deliver(o, badBatch: true);
        }
        continue;
      }
      _deliver(o);
    }
  }

  void _deliver(StockOrder o, {bool immediate = false, bool badBatch = false}) {
    final sup = content.suppliers[o.supplierId]!;
    o.lines.forEach((ing, q) {
      if (q <= 0) return;
      final shelf = content.ingredients[ing]!.shelfLifeDays;
      final quality = (sup.quality + _rng.nextInt(-5, 5) - (badBatch ? 30 : 0))
          .clamp(5, 100);
      loc.stock.add(Batch(ing, q, quality, shelf));
    });
    // Payment: on delivery, or on credit if the relationship allows it.
    final cashOnly =
        (loc.supplierCashOnlyUntil[o.supplierId] ?? -1) >= state.dayIndex;
    if (sup.creditDays > 0 &&
        (loc.supplierRel[o.supplierId] ?? 50) >= 50 &&
        !cashOnly) {
      loc.payables.add(Payable(state.allocId(), o.supplierId, o.total,
          state.dayIndex + sup.creditDays, '${sup.name} invoice', false));
      loc.today.ingredientSpend += o.total; // booked as a cost when received
    } else {
      spend(o.total, 'ingredients');
      loc.supplierRel[o.supplierId] =
          math.min(100, (loc.supplierRel[o.supplierId] ?? 50) + 1);
    }
    if (badBatch) {
      _note('badBatch', 'A bad batch arrived from ${sup.name}', 0);
      _raiseIncident('inc_bad_batch',
          subjectKey: o.supplierId,
          forced: true,
          vars: {'orderId': o.id, 'total': o.total});
    }
    if (!immediate) emit('deliveryArrived', {'supplierId': o.supplierId});
  }

  /// Payables due today are paid; late ones hurt the relationship.
  void _payPayables() {
    final due = loc.payables.where((p) => p.dueDay <= state.dayIndex).toList();
    for (final p in due) {
      if (state.cash >= p.amount) {
        loc.payables.remove(p);
        state.cash -= p.amount; // already booked as a cost at delivery
        emit('cashChanged', {'delta': -p.amount});
        if (p.inherited) {
          _note(
              'inheritedDebt',
              'Paid the last owner\'s old supplier bill (${money(p.amount)})',
              p.amount);
        }
        if (p.supplierId != null) {
          loc.supplierRel[p.supplierId!] =
              math.min(100, (loc.supplierRel[p.supplierId!] ?? 50) + 1);
        }
      } else if (p.dueDay < state.dayIndex - 6) {
        // Very overdue: the supplier insists.
        if (p.supplierId != null) {
          loc.supplierRel[p.supplierId!] =
              math.max(0, (loc.supplierRel[p.supplierId!] ?? 50) - 10);
          _raiseIncident('inc_supplier_cash_only',
              subjectKey: p.supplierId, forced: true);
        }
        p.dueDay = state.dayIndex + 7;
      }
    }
  }

  CommandResult _payPayable(int id) {
    final p = loc.payables.where((x) => x.id == id).firstOrNull;
    if (p == null) return CommandResult.fail(SimError.unknownId);
    if (state.cash < p.amount) {
      return CommandResult.fail(
          SimError.notEnoughCash, 'You need ${money(p.amount)}.');
    }
    loc.payables.remove(p);
    state.cash -= p.amount;
    if (p.inherited) {
      _note('inheritedDebt', 'Paid off the old supplier bill early', p.amount);
    }
    emit('cashChanged', {'delta': -p.amount});
    return const CommandResult(true);
  }

  /// Daily price drift (doc 02 §9.2).
  void _updatePrices() {
    final vol = diff('DIFF_VOLATILITY');
    for (final id in content.ingredients.keys) {
      var pi = loc.priceIndex[id] ?? 1.0;
      pi += (1 - pi) * 0.1 + (_rng.nextFloat() - 0.5) * 0.06 * vol;
      loc.priceIndex[id] = pi.clamp(0.6, 2.0);
    }
  }

  /// At close: use-by countdown, expiry → waste; storage over capacity spoils faster.
  void _ageStock() {
    final over = <String, bool>{
      for (final st in ['dry', 'chilled', 'frozen'])
        st: _stored(st) > _capacity(st),
    };
    final fridgeDown =
        !loc.equipment.any((e) => e.type == 'eq_fridge' && !e.broken);
    var waste = 0.0;
    final wasted = <String, int>{};
    for (final bt in loc.stock) {
      final storage = content.ingredients[bt.ingredientId]!.storage;
      var dec = 1;
      if (over[storage]!) {
        dec += (storage != 'dry' && (fridgeDown || _capacity(storage) == 0))
            ? 2
            : 1;
      }
      bt.daysLeft -= dec;
      if (bt.daysLeft <= 0) {
        final c = bt.qty *
            content.ingredients[bt.ingredientId]!.baseCost *
            (loc.priceIndex[bt.ingredientId] ?? 1);
        waste += c;
        wasted[bt.ingredientId] = (wasted[bt.ingredientId] ?? 0) + bt.qty;
        emit('batchExpired', {'ingredientId': bt.ingredientId, 'qty': bt.qty});
      }
    }
    loc.stock.removeWhere((x) => x.daysLeft <= 0);
    loc.today.wasteCost = waste.round();
    if (waste >= 1) {
      final names = wasted.entries.toList()
        ..sort((a, c) => c.value.compareTo(a.value));
      final top = names
          .take(3)
          .map((e) => '${content.ingredients[e.key]!.name} ×${e.value}')
          .join(', ');
      _note('waste', 'Threw away food worth ${money(waste)} ($top)',
          waste.round());
    }
  }

  /// Par-level auto-order at close (doc 02 §9.4, stage 2).
  void _autoOrder() {
    if (loc.parLevels.isEmpty) return;
    final bySup = <String, Map<String, int>>{};
    loc.parLevels.forEach((ing, par) {
      final onOrder =
          loc.orders.fold<int>(0, (a, o) => a + (o.lines[ing] ?? 0));
      final qty = par.par - loc.stockOf(ing) - onOrder;
      if (qty <= 0) return;
      var sup = par.supplierId;
      if (!_supplierSells(sup, ing) || content.suppliers[sup]!.leadDays == 0) {
        sup = 'sup_standard';
      }
      bySup.putIfAbsent(sup, () => {})[ing] = qty;
    });
    bySup.forEach((sup, lines) {
      final total = _orderTotal(sup, lines);
      if (total >= content.suppliers[sup]!.minOrder) {
        final r = _placeOrder(sup, lines, auto: true);
        if (r.ok) {
          _note(
              'autoOrder',
              'Auto-ordered stock from ${content.suppliers[sup]!.name} (${money(total)})',
              0);
        }
      }
    });
  }

  /// Suggested order for one supplier: tomorrow's use + a day's buffer, minus stock and orders.
  Map<String, int> _suggestedOrder(String supplierId, {double days = 2}) {
    final use = _expectedDailyUse(loc, day: state.dayIndex + 1);
    final out = <String, int>{};
    use.forEach((ing, perDay) {
      if (!_supplierSells(supplierId, ing)) return;
      final onOrder =
          loc.orders.fold<int>(0, (a, o) => a + (o.lines[ing] ?? 0));
      final shelf = content.ingredients[ing]!.shelfLifeDays;
      final want = (perDay * math.min(days, shelf.toDouble())).ceil();
      final q = want - loc.stockOf(ing) - onOrder;
      if (q > 0) out[ing] = q;
    });
    return out;
  }
}

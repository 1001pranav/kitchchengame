import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sim_core/sim_core.dart';

import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/ledger.dart';

class StockTab extends StatelessWidget {
  const StockTab({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(children: [
        const GameTabBar(tabs: [
          Tab(text: 'Stock'),
          Tab(text: 'Suppliers'),
          Tab(text: 'Auto-order')
        ]),
        const Expanded(
            child: TabBarView(
                children: [_StockList(), _Suppliers(), _ParLevels()])),
      ]),
    );
  }
}

class _StockList extends StatelessWidget {
  const _StockList();
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final l = sim.state.viewLoc;
    final use = sim.expectedDailyUse();
    final used = use.keys.toSet()..addAll(l.stock.map((b) => b.ingredientId));
    final canOrder = sim.state.phase != 'service';
    final risks = sim.runOutRisks();
    final useToday = used
        .where(
            (id) => l.stock.any((b) => b.ingredientId == id && b.daysLeft <= 1))
        .length;
    final value = l.stock.fold<double>(
        0, (a, b) => a + b.qty * sim.unitPrice('sup_standard', b.ingredientId));
    final urgent = risks.isNotEmpty && canOrder;
    return Centered(
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 14, 2, 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('THE LARDER',
                        style: TextStyle(
                            color: Palette.accent,
                            fontSize: 10.5,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                        risks.isEmpty
                            ? 'Stocked for tomorrow'
                            : '${risks.length} running out',
                        style: const TextStyle(
                            fontFamily: displayFont,
                            fontSize: 22,
                            fontWeight: FontWeight.w700)),
                  ]),
            ),
            StatStrip(items: [
              StatItem('RUN OUT', '${risks.length}', 'by tomorrow',
                  color: risks.isEmpty ? null : Palette.bad),
              StatItem('USE TODAY', '$useToday', 'or it goes off',
                  color: useToday == 0 ? null : Palette.warn),
              StatItem('ON SHELVES', fmtMoney(value.round()), 'at cost'),
            ]),
            const SizedBox(height: 14),
            SizedBox(
              height: 50,
              child: urgent
                  ? FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: Palette.tomato,
                          foregroundColor: Colors.white),
                      onPressed: () => showOrderSheet(context),
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: const Text('PLACE AN ORDER',
                          style: TextStyle(
                              letterSpacing: 1.6, fontWeight: FontWeight.w700)),
                    )
                  : OutlinedButton.icon(
                      onPressed:
                          canOrder ? () => showOrderSheet(context) : null,
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: Text(
                          canOrder ? 'PLACE AN ORDER' : 'ORDER AFTER SERVICE',
                          style: const TextStyle(
                              letterSpacing: 1.6, fontWeight: FontWeight.w700)),
                    ),
            ),
            const SizedBox(height: 6),
            const Text(
                'Delivered tomorrow morning. Cash & Carry is same-day, before service only, and dearer.',
                style: TextStyle(color: Palette.muted, fontSize: 12)),
            if (l.orders.isNotEmpty) ...[
              const SectionTitle('On order'),
              LedgerGroup(children: [
                for (final o in l.orders)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      const Icon(Icons.local_shipping_outlined,
                          color: Palette.muted, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sim.content.suppliers[o.supplierId]!.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              Text(
                                  '${o.lines.length} items · arrives ${o.dueDay <= sim.state.dayIndex + 1 ? 'tomorrow' : 'day ${o.dueDay + 1}'}',
                                  style: const TextStyle(
                                      color: Palette.muted, fontSize: 12)),
                            ]),
                      ),
                      Money(o.total, size: 13),
                      if (o.placedDay == sim.state.dayIndex && canOrder)
                        IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: 'Cancel order',
                            onPressed: () =>
                                sendCmd(context, CancelOrder(o.id))),
                    ]),
                  ),
              ]),
            ],
            if (l.payables.isNotEmpty) ...[
              const SectionTitle('Bills to suppliers'),
              LedgerGroup(children: [
                for (final p in l.payables)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Icon(p.inherited ? Icons.history : Icons.receipt_long,
                          size: 20,
                          color: p.inherited ? Palette.bad : Palette.muted),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(p.label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text('due day ${p.dueDay + 1}',
                                style: const TextStyle(
                                    color: Palette.muted, fontSize: 12)),
                          ])),
                      Money(p.amount, size: 13),
                      const SizedBox(width: 6),
                      if (canOrder)
                        TextButton(
                            onPressed: () => sendCmd(context, PayPayable(p.id),
                                okText: 'Paid.'),
                            child: const Text('Pay')),
                    ]),
                  ),
              ]),
            ],
            for (final storage in ['chilled', 'dry', 'frozen']) ...[
              SectionTitle(
                '${storage[0].toUpperCase()}${storage.substring(1)}',
                trailing: Text(
                    '${sim.stored(storage)} / ${sim.capacity(storage)}',
                    style: TextStyle(
                        color: sim.stored(storage) > sim.capacity(storage)
                            ? Palette.bad
                            : Palette.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Meter(
                    sim.capacity(storage) == 0
                        ? 1
                        : sim.stored(storage) / sim.capacity(storage),
                    color: sim.stored(storage) > sim.capacity(storage)
                        ? Palette.bad
                        : Palette.accent.withValues(alpha: 0.7),
                    height: 2),
              ),
              if (sim.stored(storage) > sim.capacity(storage))
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                      'Over capacity: everything in here goes off a day faster.',
                      style: TextStyle(color: Palette.bad, fontSize: 12.5)),
                ),
              LedgerGroup(children: [
                for (final id
                    in (used
                        .where((i) =>
                            sim.content.ingredients[i]!.storage == storage)
                        .toList()
                      ..sort()))
                  _IngRow(id: id, perDay: use[id] ?? 0),
              ]),
            ],
          ]),
    );
  }
}

class _IngRow extends StatelessWidget {
  final String id;
  final double perDay;
  const _IngRow({required this.id, required this.perDay});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final l = sim.state.viewLoc;
    final ing = sim.content.ingredients[id]!;
    final onHand = l.stockOf(id);
    final batches = l.stock.where((b) => b.ingredientId == id).toList();
    final expiry = batches.isEmpty
        ? null
        : batches.map((b) => b.daysLeft).reduce(math.min);
    final onOrder = l.orders.fold<int>(0, (a, o) => a + (o.lines[id] ?? 0));
    final cover = perDay <= 0 ? null : onHand / perDay;
    final coverColor = cover == null
        ? Palette.muted
        : cover < 1
            ? Palette.bad
            : (cover < 2 ? Palette.warn : Palette.ok);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(ing.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14.5)),
              ),
              if (expiry != null && expiry <= 2) ...[
                const SizedBox(width: 8),
                StateDot(expiry <= 1 ? 'use today' : 'off in ${expiry}d',
                    color: expiry <= 1 ? Palette.bad : Palette.warn),
              ],
            ]),
            const SizedBox(height: 6),
            Row(children: [
              SizedBox(
                width: 72,
                child: Meter(cover == null ? 0 : cover / 4, color: coverColor),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                    cover == null
                        ? 'not on the menu'
                        : '${cover.toStringAsFixed(1)} days left',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: cover != null && cover < 1
                            ? Palette.bad
                            : Palette.muted,
                        fontSize: 12)),
              ),
            ]),
          ]),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$onHand',
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()])),
          Text(onOrder > 0 ? '+$onOrder coming' : 'in stock',
              style: TextStyle(
                  color: onOrder > 0 ? Palette.staff : Palette.muted,
                  fontSize: 11)),
        ]),
      ]),
    );
  }
}

// ------------------------------------------------------------------ order sheet

void showOrderSheet(BuildContext context, {String? supplier}) {
  showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _OrderSheet(initialSupplier: supplier));
}

class _OrderSheet extends StatefulWidget {
  final String? initialSupplier;
  const _OrderSheet({this.initialSupplier});
  @override
  State<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<_OrderSheet> {
  late String sup;
  Map<String, int> lines = {};

  @override
  void initState() {
    super.initState();
    sup = widget.initialSupplier ?? 'sup_standard';
    _suggest();
  }

  void _suggest() {
    final sim = GameScope.read(context).sim!;
    final s = sim.content.suppliers[sup]!;
    lines = s.leadDays == 0 ? _todayShort(sim) : sim.suggestedOrder(sup);
  }

  Map<String, int> _todayShort(Sim sim) {
    final use = sim.expectedDailyUse();
    final out = <String, int>{};
    use.forEach((k, v) {
      final need = (v * 1.1).ceil() - sim.state.viewLoc.stockOf(k);
      if (need > 0 && sim.supplierSells(sup, k)) out[k] = need;
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final s = sim.content.suppliers[sup]!;
    final total = sim.orderTotal(sup, lines);
    final ok = total >= s.minOrder && lines.values.any((v) => v > 0);
    final use = sim.expectedDailyUse(day: sim.state.dayIndex + 1);
    final menuIngs = use.keys.where((k) => sim.supplierSells(sup, k)).toList()
      ..sort();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(children: [
        Expanded(
          child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                Text('New order',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (final x in sim.content.suppliers.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(x.name),
                          selected: sup == x.id,
                          onSelected: (_) => setState(() {
                            sup = x.id;
                            _suggest();
                          }),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 8),
                _SupplierFacts(s: s),
                const SizedBox(height: 10),
                Row(children: [
                  const Expanded(
                      child: Text(
                          'Suggested: tomorrow\'s needs plus a day spare, minus what you have.',
                          style:
                              TextStyle(color: Palette.muted, fontSize: 12.5))),
                  TextButton(
                      onPressed: () => setState(_suggest),
                      child: const Text('Reset')),
                ]),
                for (final id in menuIngs)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sim.content.ingredients[id]!.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              Text(
                                  'have ${sim.state.viewLoc.stockOf(id)} · need ~${use[id]!.ceil()}/day · ${sim.unitPrice(sup, id).toStringAsFixed(2)} each',
                                  style: const TextStyle(
                                      fontSize: 11.5, color: Palette.muted)),
                            ]),
                      ),
                      IconButton(
                        onPressed: () => setState(() =>
                            lines[id] = math.max(0, (lines[id] ?? 0) - 5)),
                        icon: const Icon(Icons.remove_circle_outline),
                        tooltip: 'Less',
                      ),
                      SizedBox(
                          width: 36,
                          child: Text('${lines[id] ?? 0}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15))),
                      IconButton(
                        onPressed: () =>
                            setState(() => lines[id] = (lines[id] ?? 0) + 5),
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: 'More',
                      ),
                    ]),
                  ),
              ]),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Palette.line))),
            child: Column(children: [
              Row(children: [
                const Text('Total '),
                Money(total, size: 18),
                const Spacer(),
                Text(
                    total < s.minOrder
                        ? 'Minimum ${fmtMoney(s.minOrder)}'
                        : 'Minimum met',
                    style: TextStyle(
                        color: total < s.minOrder ? Palette.bad : Palette.ok,
                        fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
                onPressed: ok
                    ? () {
                        if (sendCmd(context, PlaceOrder(sup, Map.of(lines)),
                            okText: s.leadDays == 0
                                ? 'Bought and stored.'
                                : 'Ordered. It arrives tomorrow morning.')) {
                          Navigator.pop(context);
                        }
                      }
                    : null,
                child: Text(
                    s.leadDays == 0 ? 'Buy now (cash)' : 'Order for tomorrow'),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _SupplierFacts extends StatelessWidget {
  final Supplier s;
  const _SupplierFacts({required this.s});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final rel = c.state!.viewLoc.supplierRel[s.id] ?? 50;
    return Wrap(spacing: 6, runSpacing: 6, children: [
      Pill('price ×${s.priceMult.toStringAsFixed(2)}',
          color: s.priceMult <= 1 ? Palette.ok : Palette.warn,
          icon: Icons.sell),
      Pill('quality ${s.quality}',
          color: s.quality >= 80
              ? Palette.ok
              : (s.quality >= 60 ? Palette.muted : Palette.warn),
          icon: Icons.eco),
      Pill('on time ${(s.reliability * 100).round()}%',
          color: s.reliability >= 0.93 ? Palette.ok : Palette.warn,
          icon: Icons.schedule),
      Pill(s.creditDays > 0 ? 'pay in ${s.creditDays} days' : 'pay on delivery',
          icon: Icons.payments),
      Pill(
          s.categories.length == 5
              ? 'sells everything'
              : 'sells ${s.categories.join(', ').replaceAll('meat_fish', 'meat & fish')}',
          icon: Icons.category),
      Pill('relationship $rel', icon: Icons.handshake),
    ]);
  }
}

class _Suppliers extends StatelessWidget {
  const _Suppliers();
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    return Centered(
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const Text(
                'Cheaper suppliers send worse food and are late more often. Better ingredients make better dishes, and better dishes make better reviews.',
                style: TextStyle(color: Palette.muted, height: 1.35)),
            const SizedBox(height: 10),
            for (final s in sim.content.suppliers.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Panel(
                  onTap: sim.state.phase == 'service'
                      ? null
                      : () => showOrderSheet(context, supplier: s.id),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.local_shipping,
                              color: Palette.accent),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(s.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16))),
                          Text(s.leadDays == 0 ? 'same day' : 'next day',
                              style: const TextStyle(color: Palette.muted)),
                        ]),
                        const SizedBox(height: 8),
                        _SupplierFacts(s: s),
                        const SizedBox(height: 6),
                        Text('Minimum order ${fmtMoney(s.minOrder)}',
                            style: const TextStyle(
                                color: Palette.muted, fontSize: 12.5)),
                      ]),
                ),
              ),
          ]),
    );
  }
}

class _ParLevels extends StatelessWidget {
  const _ParLevels();
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final st = sim.state;
    if (st.stage < 2) {
      return const Centered(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock, size: 40, color: Palette.muted),
            SizedBox(height: 10),
            Text('Automatic re-ordering unlocks at Stage 2.',
                style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text('Four profitable weeks in a row and a 3.5-star rating.',
                style: TextStyle(color: Palette.muted)),
          ]),
        ),
      );
    }
    final use = sim.expectedDailyUse();
    final ids = use.keys.toList()..sort();
    final canAct = st.phase != 'service';
    return Centered(
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const TermText('Keep-in-stock levels', 'par_level',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            const Text(
                'Every night the game tops each ingredient up to this level from City Foodservice.',
                style: TextStyle(color: Palette.muted)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: canAct
                      ? () {
                          for (final id in ids) {
                            final shelf =
                                sim.content.ingredients[id]!.shelfLifeDays;
                            final par = (use[id]! * math.min(2, shelf)).ceil();
                            GameScope.read(context)
                                .send(SetParLevel(id, par, 'sup_standard'));
                          }
                          showToast(context,
                              'Set to two days of use (less for fresh food).',
                              bad: false);
                        }
                      : null,
                  child: const Text('Set all to 2 days'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: canAct
                      ? () {
                          for (final id in ids) {
                            GameScope.read(context)
                                .send(SetParLevel(id, 0, 'sup_standard'));
                          }
                        }
                      : null,
                  child: const Text('Turn all off'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            for (final id in ids)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Expanded(child: Text(sim.content.ingredients[id]!.name)),
                  Text('~${use[id]!.ceil()}/day  ',
                      style:
                          const TextStyle(color: Palette.muted, fontSize: 12)),
                  IconButton(
                    onPressed: canAct
                        ? () => sendCmd(
                            context,
                            SetParLevel(
                                id,
                                math.max(0,
                                    (st.viewLoc.parLevels[id]?.par ?? 0) - 5),
                                'sup_standard'))
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  SizedBox(
                      width: 34,
                      child: Text('${st.viewLoc.parLevels[id]?.par ?? 0}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800))),
                  IconButton(
                    onPressed: canAct
                        ? () => sendCmd(
                            context,
                            SetParLevel(
                                id,
                                (st.viewLoc.parLevels[id]?.par ?? 0) + 5,
                                'sup_standard'))
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ]),
              ),
          ]),
    );
  }
}

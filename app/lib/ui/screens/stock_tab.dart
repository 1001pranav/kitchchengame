import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sim_core/sim_core.dart';

import '../theme.dart';
import '../widgets/common.dart';

class StockTab extends StatelessWidget {
  const StockTab({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(children: [
        Container(
            color: Palette.surface,
            child: const TabBar(tabs: [
              Tab(text: 'Stock'),
              Tab(text: 'Suppliers'),
              Tab(text: 'Auto-order')
            ])),
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
    final l = sim.state.loc;
    final use = sim.expectedDailyUse();
    final used = use.keys.toSet()..addAll(l.stock.map((b) => b.ingredientId));
    final canOrder = sim.state.phase != 'service';
    return Centered(
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50)),
                  onPressed: canOrder ? () => showOrderSheet(context) : null,
                  icon: const Icon(Icons.add_shopping_cart),
                  label:
                      Text(canOrder ? 'Place an order' : 'Order after service'),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            const Text(
                'Orders arrive at the start of tomorrow. Cash & Carry is the only same-day option (prep only, pricier).',
                style: TextStyle(color: Palette.muted, fontSize: 12.5)),
            if (l.orders.isNotEmpty) ...[
              const SectionTitle('On order'),
              for (final o in l.orders)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Panel(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    child: Row(children: [
                      const Icon(Icons.local_shipping, color: Palette.muted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                            '${sim.content.suppliers[o.supplierId]!.name} · ${o.lines.length} items · arrives ${o.dueDay <= sim.state.dayIndex + 1 ? 'tomorrow' : 'day ${o.dueDay + 1}'}'),
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
                ),
            ],
            if (l.payables.isNotEmpty) ...[
              const SectionTitle('Bills to suppliers'),
              for (final p in l.payables)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Panel(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    child: Row(children: [
                      Icon(p.inherited ? Icons.history : Icons.receipt_long,
                          color: p.inherited ? Palette.bad : Palette.muted),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text('${p.label}\ndue day ${p.dueDay + 1}',
                              style: const TextStyle(height: 1.3))),
                      Money(p.amount, size: 13),
                      const SizedBox(width: 6),
                      if (canOrder)
                        TextButton(
                            onPressed: () => sendCmd(context, PayPayable(p.id),
                                okText: 'Paid.'),
                            child: const Text('Pay')),
                    ]),
                  ),
                ),
            ],
            for (final storage in ['chilled', 'dry', 'frozen']) ...[
              SectionTitle(
                  '${storage[0].toUpperCase()}${storage.substring(1)} storage'),
              Panel(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Row(children: [
                    Icon(AssetCatalog.storage(storage),
                        size: 18, color: Palette.muted),
                    const SizedBox(width: 6),
                    Text(
                        '${sim.stored(storage)} / ${sim.capacity(storage)} units',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatBar(
                        sim.capacity(storage) == 0
                            ? 1
                            : sim.stored(storage) / sim.capacity(storage),
                        color: sim.stored(storage) > sim.capacity(storage)
                            ? Palette.bad
                            : Palette.staff,
                      ),
                    ),
                  ]),
                  if (sim.stored(storage) > sim.capacity(storage))
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                          'Over capacity: everything in here goes off a day faster.',
                          style: TextStyle(color: Palette.bad, fontSize: 12.5)),
                    ),
                  const SizedBox(height: 6),
                  for (final id
                      in (used
                          .where((i) =>
                              sim.content.ingredients[i]!.storage == storage)
                          .toList()
                        ..sort()))
                    _IngRow(id: id, perDay: use[id] ?? 0),
                ]),
              ),
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
    final l = sim.state.loc;
    final ing = sim.content.ingredients[id]!;
    final onHand = l.stockOf(id);
    final batches = l.stock.where((b) => b.ingredientId == id).toList();
    final expiry = batches.isEmpty
        ? null
        : batches.map((b) => b.daysLeft).reduce(math.min);
    final onOrder = l.orders.fold<int>(0, (a, o) => a + (o.lines[id] ?? 0));
    final cover = perDay <= 0 ? null : onHand / perDay;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(
          flex: 5,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ing.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
                'use-by ${ing.shelfLifeDays}d · ${sim.unitPrice('sup_standard', id).toStringAsFixed(2)}/unit',
                style: const TextStyle(color: Palette.muted, fontSize: 11.5)),
          ]),
        ),
        Expanded(
            flex: 2,
            child: Text('$onHand',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w800))),
        Expanded(
          flex: 3,
          child: Text(
            cover == null ? '' : '${cover.toStringAsFixed(1)} days',
            textAlign: TextAlign.right,
            style: TextStyle(
                color: cover != null && cover < 1 ? Palette.bad : Palette.muted,
                fontWeight: cover != null && cover < 1
                    ? FontWeight.w800
                    : FontWeight.w500),
          ),
        ),
        Expanded(
          flex: 3,
          child: expiry == null
              ? const SizedBox()
              : Align(
                  alignment: Alignment.centerRight,
                  child: Pill('${expiry}d',
                      color: expiry <= 1
                          ? Palette.bad
                          : (expiry <= 2 ? Palette.warn : Palette.muted),
                      icon: Icons.schedule)),
        ),
        Expanded(
            flex: 2,
            child: Text(onOrder > 0 ? '+$onOrder' : '',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: Palette.staff, fontWeight: FontWeight.w700))),
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
      final need = (v * 1.1).ceil() - sim.state.loc.stockOf(k);
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
                                  'have ${sim.state.loc.stockOf(id)} · need ~${use[id]!.ceil()}/day · ${sim.unitPrice(sup, id).toStringAsFixed(2)} each',
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
                        : 'Minimum met ✓',
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
    final rel = c.state!.loc.supplierRel[s.id] ?? 50;
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
            Text('Four profitable weeks in a row and a 3.5★ rating.',
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
                                math.max(
                                    0, (st.loc.parLevels[id]?.par ?? 0) - 5),
                                'sup_standard'))
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  SizedBox(
                      width: 34,
                      child: Text('${st.loc.parLevels[id]?.par ?? 0}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800))),
                  IconButton(
                    onPressed: canAct
                        ? () => sendCmd(
                            context,
                            SetParLevel(
                                id,
                                (st.loc.parLevels[id]?.par ?? 0) + 5,
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

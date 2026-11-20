import 'package:flutter/material.dart';
import 'package:sim_core/sim_core.dart';

import '../theme.dart';
import '../widgets/common.dart';

class KitchenTab extends StatelessWidget {
  const KitchenTab({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        Container(color: Palette.surface, child: const TabBar(tabs: [Tab(text: 'Menu'), Tab(text: 'Equipment')])),
        const Expanded(child: TabBarView(children: [_Menu(), _Equipment()])),
      ]),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu();
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final l = sim.state.loc;
    final dishes = sim.content.dishesFor(sim.state.themeId);
    final order = ['starter', 'main', 'side', 'dessert', 'drink'];
    dishes.sort((a, b) => order.indexOf(a.course).compareTo(order.indexOf(b.course)));
    final canPrice = sim.state.phase != 'service';
    final pi = sim.priceIndex();
    return Centered(
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        Panel(
          child: Row(children: [
            const Icon(Icons.sell, color: Palette.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Prices are ${pi >= 1 ? '${((pi - 1) * 100).round()}% above' : '${((1 - pi) * 100).round()}% below'} normal. '
                'Higher prices earn more per dish but bring fewer customers and lower "value" reviews.',
                style: const TextStyle(height: 1.35),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < dishes.length; i++) _DishRow(dish: dishes[i], index: l.menu.keys.toList().indexOf(dishes[i].id), canPrice: canPrice),
        const SectionTitle('Keep the menu fresh'),
        const HealthCard(),
        const SizedBox(height: 10),
        Panel(
          child: Row(children: [
            const Icon(Icons.auto_awesome, color: Palette.tomato),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Rework the menu', style: TextStyle(fontWeight: FontWeight.w800)),
                Text('800 coins. Your head chef spends a day on it. Freshness back to 100%, a little buzz.',
                    style: TextStyle(color: Palette.muted.withValues(alpha: 1), fontSize: 13)),
              ]),
            ),
            FilledButton.tonal(onPressed: canPrice ? () => sendCmd(context, const ReworkMenu(), okText: 'The menu feels new again.') : null, child: const Text('Rework')),
          ]),
        ),
      ]),
    );
  }
}

class _DishRow extends StatelessWidget {
  final Dish dish;
  final int index;
  final bool canPrice;
  const _DishRow({required this.dish, required this.index, required this.canPrice});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final m = sim.state.loc.menu[dish.id]!;
    final cost = dish.recipe.fold(0.0, (a, r) => a + r.qty * sim.unitPrice('sup_standard', r.ingredientId));
    final fc = cost / m.price;
    final margin = m.price - cost;
    final down = sim.stationDown(dish.station);
    final lo = (dish.basePrice * 0.6).ceil(), hi = (dish.basePrice * 1.8).floor();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: m.enabled ? 1 : 0.6,
        child: Panel(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Row(children: [
            CircleAvatar(radius: 20, backgroundColor: Palette.surface2, child: Icon(AssetCatalog.course(dish.course), color: Palette.tomato, size: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () => showWhy(context, sim.explain('dish', id: index)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(dish.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Wrap(spacing: 5, runSpacing: 3, children: [
                    Pill('food cost ${(fc * 100).round()}%', color: fc > 0.36 ? Palette.bad : (fc < 0.25 ? Palette.ok : Palette.muted)),
                    Pill('+${margin.toStringAsFixed(1)}', color: Palette.ok),
                    Pill('sold ${m.soldYesterday}', color: Palette.staff),
                    if (down) const Pill('station down', color: Palette.bad, icon: Icons.warning_amber_rounded),
                    if (dish.skillReq >= 50) Pill('chef skill ${dish.skillReq}', color: Palette.muted),
                  ]),
                ]),
              ),
            ),
            Column(children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: canPrice && m.price > lo ? () => sendCmd(context, SetPrice(dish.id, m.price - 1)) : null,
                  icon: const Icon(Icons.remove),
                  tooltip: 'Lower price',
                ),
                Money(m.price, size: 15),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: canPrice && m.price < hi ? () => sendCmd(context, SetPrice(dish.id, m.price + 1)) : null,
                  icon: const Icon(Icons.add),
                  tooltip: 'Raise price',
                ),
              ]),
              Switch(
                value: m.enabled,
                onChanged: (v) => sendCmd(context, SetDishEnabled(dish.id, v)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Five slow forces (doc 11 §A.7).
class HealthCard extends StatelessWidget {
  const HealthCard({super.key});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final terms = {'Buzz': 'buzz', 'Menu freshness': 'freshness', 'Equipment age': 'equipment_age', 'Rivals': 'competition'};
    return Panel(
      child: Column(children: [
        for (final g in sim.healthGauges())
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(
                flex: 4,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  terms[g.$1] != null ? TermText(g.$1, terms[g.$1]!, style: const TextStyle(fontWeight: FontWeight.w700)) : Text(g.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(g.$4, style: const TextStyle(color: Palette.muted, fontSize: 11.5)),
                ]),
              ),
              Expanded(flex: 2, child: Text(g.$3, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
              const SizedBox(width: 8),
              SizedBox(
                width: 58,
                child: Text(
                  '${g.$2 >= 1 ? '+' : '−'}${((g.$2 - 1).abs() * 100).toStringAsFixed(0)}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.w900, color: g.$2 >= 1 ? Palette.ok : Palette.bad),
                ),
              ),
            ]),
          ),
        const Text('Effect on customers coming in', style: TextStyle(color: Palette.muted, fontSize: 11.5)),
      ]),
    );
  }
}

class _Equipment extends StatelessWidget {
  const _Equipment();
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final l = sim.state.loc;
    final canAct = sim.state.phase != 'service';
    final eq = List<Equipment>.of(l.equipment)..sort((a, b) => a.condition.compareTo(b.condition));
    return Centered(
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        const Text('Machines wear out every day. Below 60 they break down more often. Servicing is cheap; a breakdown in the middle of a Saturday is not.',
            style: TextStyle(color: Palette.muted, height: 1.35)),
        const SizedBox(height: 10),
        for (final e in eq) _EqRow(e: e, canAct: canAct),
        const SectionTitle('Buy new equipment'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in sim.content.equipment.values.where((t) => t.station == null || sim.content.themes[sim.state.themeId]!.stations.contains(t.station)))
            ActionChip(
              avatar: Icon(AssetCatalog.equipment(t.type), size: 16),
              label: Text('${t.name} · ${fmtMoney(t.price)}'),
              onPressed: canAct
                  ? () async {
                      final ok = await confirm(context, 'Buy a ${t.name.toLowerCase()}?',
                          'New: ${fmtMoney(t.price)}, arrives in 2 days. ${t.kind == 'station' ? 'More ${t.station} space means fewer dishes waiting.' : ''}',
                          ok: 'Buy new');
                      if (ok && context.mounted) sendCmd(context, BuyEquipment(t.type), okText: 'Ordered. It arrives in 2 days.');
                    }
                  : null,
            ),
        ]),
      ]),
    );
  }
}

class _EqRow extends StatelessWidget {
  final Equipment e;
  final bool canAct;
  const _EqRow({required this.e, required this.canAct});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final t = sim.content.equipment[e.type]!;
    final maxC = sim.maxCondition(e);
    final arriving = e.unavailableUntil > sim.state.dayIndex;
    final status = e.broken ? 'Broken' : (arriving ? 'Not ready until day ${e.unavailableUntil + 1}' : 'Working');
    final serviced = sim.state.dayIndex - e.lastMaintDay < 7;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        borderColor: e.broken ? Palette.bad : Palette.line,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(AssetCatalog.equipment(e.type), color: e.broken ? Palette.bad : Palette.ink),
            const SizedBox(width: 8),
            Expanded(child: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w800))),
            Pill(status, color: e.broken ? Palette.bad : (arriving ? Palette.warn : Palette.ok)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const TermText('Condition', 'condition', style: TextStyle(color: Palette.muted, fontSize: 12)),
            const SizedBox(width: 8),
            Expanded(child: StatBar(e.condition / 100, marker: maxC / 100)),
            const SizedBox(width: 8),
            Text('${e.condition.round()}', style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 4),
          Text('Age ${(e.ageDays / 336).toStringAsFixed(1)} years · best it can be: ${maxC.round()} · breakdown risk ${(sim.breakChance(e) * 100).toStringAsFixed(1)}%/day',
              style: const TextStyle(color: Palette.muted, fontSize: 11.5)),
          if (canAct) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (e.broken) ...[
                FilledButton.tonal(
                  onPressed: () => sendCmd(context, Repair(e.id, 'cheap'), okText: 'Cheap fix booked for tomorrow.'),
                  child: Text('Cheap fix ${fmtMoney(t.price * 0.1)}'),
                ),
                FilledButton.tonal(
                  onPressed: () => sendCmd(context, Repair(e.id, 'proper'), okText: 'Proper repair booked (2 days).'),
                  child: Text('Proper repair ${fmtMoney(t.price * 0.25)}'),
                ),
              ] else
                OutlinedButton(
                  onPressed: serviced ? null : () => sendCmd(context, Maintain(e.id), okText: e.condition >= 50 ? 'Serviced.' : 'Serviced — out of action until tomorrow.'),
                  child: Text(serviced ? 'Serviced this week' : 'Service ${fmtMoney(t.price * 0.02)}'),
                ),
              OutlinedButton(
                onPressed: () async {
                  final ok = await confirm(context, 'Replace the ${t.name.toLowerCase()}?',
                      'New ${fmtMoney(t.price)} (2 days) — the old one is sold for ${fmtMoney(sim.equipmentResale(e))}.', ok: 'Replace');
                  if (ok && context.mounted) sendCmd(context, BuyEquipment(e.type, replaceId: e.id), okText: 'A new one arrives in 2 days.');
                },
                child: const Text('Replace'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final ok = await confirm(context, 'Sell the ${t.name.toLowerCase()}?', 'You get ${fmtMoney(sim.equipmentResale(e))}.', ok: 'Sell');
                  if (ok && context.mounted) sendCmd(context, SellEquipment(e.id));
                },
                child: Text('Sell ${fmtMoney(sim.equipmentResale(e))}'),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

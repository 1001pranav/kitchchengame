import 'package:flutter/material.dart';
import 'package:sim_core/sim_core.dart';

import '../theme.dart';
import '../scene/pictures.dart';
import '../widgets/common.dart';
import '../widgets/ledger.dart';

class KitchenTab extends StatelessWidget {
  const KitchenTab({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        const GameTabBar(tabs: [Tab(text: 'Menu'), Tab(text: 'Equipment')]),
        const Expanded(child: TabBarView(children: [_Menu(), _Equipment()])),
      ]),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu();
  static const _courses = [
    ('starter', 'Starters'),
    ('main', 'Mains'),
    ('side', 'Sides'),
    ('dessert', 'Desserts'),
    ('drink', 'Drinks'),
  ];
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final l = sim.state.viewLoc;
    final dishes = sim.content.dishesFor(sim.state.themeId);
    final canPrice = sim.state.phase != 'service';
    final pi = sim.priceIndex();
    final on = dishes.where((d) => l.menu[d.id]?.enabled ?? false).toList();
    double costShare(Dish d) {
      final m = l.menu[d.id]!;
      final cost = d.recipe.fold(0.0,
          (a, r) => a + r.qty * sim.unitPrice('sup_standard', r.ingredientId));
      return cost / m.price;
    }

    final avgCost =
        on.isEmpty ? 0.0 : on.fold(0.0, (a, d) => a + costShare(d)) / on.length;
    final pct = ((pi - 1) * 100).round();
    return Centered(
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 14, 2, 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('THE CARTE',
                        style: TextStyle(
                            color: Palette.accent,
                            fontSize: 10.5,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text('${on.length} dishes tonight',
                        style: const TextStyle(
                            fontFamily: displayFont,
                            fontSize: 22,
                            fontWeight: FontWeight.w700)),
                  ]),
            ),
            StatStrip(items: [
              StatItem(
                  'PRICES',
                  pct == 0 ? 'Par' : '${pct > 0 ? '+' : ''}$pct%',
                  pct > 0
                      ? 'above normal'
                      : (pct < 0 ? 'below normal' : 'normal'),
                  color: pct > 15 ? Palette.warn : null),
              StatItem('FOOD COST', '${(avgCost * 100).round()}%', 'average',
                  color: avgCost > 0.36 ? Palette.bad : null,
                  onTap: () => showTerm(context, 'food_cost')),
              StatItem('ON MENU', '${on.length}/${dishes.length}', 'dishes'),
            ]),
            const SizedBox(height: 8),
            const Text(
                'Higher prices earn more per plate but bring fewer guests and harsher "value" reviews.',
                style: TextStyle(color: Palette.muted, fontSize: 12)),
            for (final (course, title) in _courses)
              if (dishes.any((d) => d.course == course)) ...[
                SectionTitle(title),
                LedgerGroup(padding: EdgeInsets.zero, children: [
                  for (final d in dishes.where((d) => d.course == course))
                    _DishRow(
                        dish: d,
                        index: l.menu.keys.toList().indexOf(d.id),
                        canPrice: canPrice),
                ]),
              ],
            const SectionTitle('Keep the menu fresh'),
            const HealthCard(),
            const SizedBox(height: 10),
            Panel(
              child: Row(children: [
                const Icon(Icons.auto_awesome_outlined, color: Palette.accent),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rework the menu',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        SizedBox(height: 2),
                        Text(
                            '800 coins. Your head chef spends a day on it. Freshness back to 100%, a little buzz.',
                            style: TextStyle(
                                color: Palette.muted, fontSize: 12.5)),
                      ]),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                    onPressed: canPrice
                        ? () => sendCmd(context, const ReworkMenu(),
                            okText: 'The menu feels new again.')
                        : null,
                    child: const Text('Rework')),
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
  const _DishRow(
      {required this.dish, required this.index, required this.canPrice});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final m = sim.state.viewLoc.menu[dish.id]!;
    final cost = dish.recipe.fold(0.0,
        (a, r) => a + r.qty * sim.unitPrice('sup_standard', r.ingredientId));
    final fc = cost / m.price;
    final margin = m.price - cost;
    final down = sim.stationDown(dish.station);
    final lo = (dish.basePrice * 0.6).ceil(),
        hi = (dish.basePrice * 1.8).floor();
    final fcColor =
        fc > 0.36 ? Palette.bad : (fc < 0.25 ? Palette.ok : Palette.muted);
    Widget step(IconData icon, String tip, VoidCallback? onTap) => Tooltip(
          message: tip,
          child: InkResponse(
            onTap: onTap,
            radius: 20,
            child: SizedBox(
              width: 30,
              height: 34,
              child: Icon(icon,
                  size: 18,
                  color: onTap == null
                      ? Palette.muted.withValues(alpha: 0.35)
                      : Palette.muted),
            ),
          ),
        );
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => showWhy(context, sim.explain('dish', id: index)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(children: [
            Opacity(
              opacity: m.enabled ? 1 : 0.45,
              child: DishPicture(dishId: dish.id, size: 44, off: !m.enabled),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Opacity(
                opacity: m.enabled ? 1 : 0.5,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dish.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14.5)),
                      const SizedBox(height: 3),
                      Text.rich(
                          TextSpan(children: [
                            TextSpan(
                                text: 'cost ${(fc * 100).round()}%',
                                style: TextStyle(color: fcColor)),
                            TextSpan(
                                text:
                                    '  ·  +${margin.toStringAsFixed(1)}  ·  ${m.soldYesterday} sold'),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Palette.muted, fontSize: 11.5)),
                      if (down || dish.skillReq >= 50) ...[
                        const SizedBox(height: 4),
                        down
                            ? const StateDot('station down', color: Palette.bad)
                            : StateDot('chef skill ${dish.skillReq}',
                                color: Palette.muted),
                      ],
                    ]),
              ),
            ),
            const SizedBox(width: 6),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                step(
                    Icons.remove,
                    'Lower price',
                    canPrice && m.price > lo
                        ? () => sendCmd(context, SetPrice(dish.id, m.price - 1))
                        : null),
                SizedBox(
                  width: 30,
                  child: Text('${m.price}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()])),
                ),
                step(
                    Icons.add,
                    'Raise price',
                    canPrice && m.price < hi
                        ? () => sendCmd(context, SetPrice(dish.id, m.price + 1))
                        : null),
              ]),
              _OnMenuToggle(
                on: m.enabled,
                onTap: () =>
                    sendCmd(context, SetDishEnabled(dish.id, !m.enabled)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// A small text toggle instead of a stock switch: ON MENU / OFF.
class _OnMenuToggle extends StatelessWidget {
  final bool on;
  final VoidCallback onTap;
  const _OnMenuToggle({required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: on,
      button: true,
      label: on ? 'On the menu' : 'Off the menu',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(top: 2, right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: on ? Palette.accentSoft : Colors.transparent,
            border: Border.all(
                color:
                    on ? Palette.accent.withValues(alpha: 0.7) : Palette.line),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(on ? 'ON MENU' : 'OFF',
              style: TextStyle(
                  color: on ? Palette.accent : Palette.muted,
                  fontSize: 9.5,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700)),
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
    final terms = {
      'Buzz': 'buzz',
      'Menu freshness': 'freshness',
      'Equipment age': 'equipment_age',
      'Rivals': 'competition'
    };
    return Panel(
      child: Column(children: [
        for (final g in sim.healthGauges())
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(
                flex: 4,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      terms[g.$1] != null
                          ? TermText(g.$1, terms[g.$1]!,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700))
                          : Text(g.$1,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                      Text(g.$4,
                          style: const TextStyle(
                              color: Palette.muted, fontSize: 11.5)),
                    ]),
              ),
              Expanded(
                  flex: 2,
                  child: Text(g.$3,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600))),
              const SizedBox(width: 8),
              SizedBox(
                width: 58,
                child: Text(
                  '${g.$2 >= 1 ? '+' : '−'}${((g.$2 - 1).abs() * 100).toStringAsFixed(0)}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: g.$2 >= 1 ? Palette.ok : Palette.bad),
                ),
              ),
            ]),
          ),
        const Text('Effect on customers coming in',
            style: TextStyle(color: Palette.muted, fontSize: 11.5)),
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
    final l = sim.state.viewLoc;
    final canAct = sim.state.phase != 'service';
    final eq = List<Equipment>.of(l.equipment)
      ..sort((a, b) => a.condition.compareTo(b.condition));
    return Centered(
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const Text(
                'Machines wear out every day. Below 60 they break down more often. Servicing is cheap; a breakdown in the middle of a Saturday is not.',
                style: TextStyle(color: Palette.muted, height: 1.35)),
            const SizedBox(height: 10),
            for (final e in eq) _EqRow(e: e, canAct: canAct),
            const SectionTitle('Buy new equipment'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in sim.content.equipment.values.where((t) =>
                  t.station == null ||
                  sim.content.themes[sim.state.themeId]!.stations
                      .contains(t.station)))
                ActionChip(
                  avatar: Icon(AssetCatalog.equipment(t.type), size: 16),
                  label: Text('${t.name} · ${fmtMoney(t.price)}'),
                  onPressed: canAct
                      ? () async {
                          final ok = await confirm(
                              context,
                              'Buy a ${t.name.toLowerCase()}?',
                              'New: ${fmtMoney(t.price)}, arrives in 2 days. ${t.kind == 'station' ? 'More ${t.station} space means fewer dishes waiting.' : ''}',
                              ok: 'Buy new');
                          if (ok && context.mounted) {
                            sendCmd(context, BuyEquipment(t.type),
                                okText: 'Ordered. It arrives in 2 days.');
                          }
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
    final status = e.broken
        ? 'Broken'
        : (arriving
            ? 'Not ready until day ${e.unavailableUntil + 1}'
            : 'Working');
    final serviced = sim.state.dayIndex - e.lastMaintDay < 7;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        borderColor: e.broken ? Palette.bad : Palette.line,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            EquipmentPicture(
                type: e.type, station: t.station, size: 40, broken: e.broken),
            const SizedBox(width: 8),
            Expanded(
                child: Text(t.name,
                    style: const TextStyle(fontWeight: FontWeight.w800))),
            Pill(status,
                color: e.broken
                    ? Palette.bad
                    : (arriving ? Palette.warn : Palette.ok)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const TermText('Condition', 'condition',
                style: TextStyle(color: Palette.muted, fontSize: 12)),
            const SizedBox(width: 8),
            Expanded(child: StatBar(e.condition / 100, marker: maxC / 100)),
            const SizedBox(width: 8),
            Text('${e.condition.round()}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 4),
          Text(
              'Age ${(e.ageDays / 336).toStringAsFixed(1)} years · best it can be: ${maxC.round()} · breakdown risk ${(sim.breakChance(e) * 100).toStringAsFixed(1)}%/day',
              style: const TextStyle(color: Palette.muted, fontSize: 11.5)),
          if (canAct) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (e.broken) ...[
                FilledButton.tonal(
                  onPressed: () => sendCmd(context, Repair(e.id, 'cheap'),
                      okText: 'Cheap fix booked for tomorrow.'),
                  child: Text('Cheap fix ${fmtMoney(t.price * 0.1)}'),
                ),
                FilledButton.tonal(
                  onPressed: () => sendCmd(context, Repair(e.id, 'proper'),
                      okText: 'Proper repair booked (2 days).'),
                  child: Text('Proper repair ${fmtMoney(t.price * 0.25)}'),
                ),
              ] else
                OutlinedButton(
                  onPressed: serviced
                      ? null
                      : () => sendCmd(context, Maintain(e.id),
                          okText: e.condition >= 50
                              ? 'Serviced.'
                              : 'Serviced — out of action until tomorrow.'),
                  child: Text(serviced
                      ? 'Serviced this week'
                      : 'Service ${fmtMoney(t.price * 0.02)}'),
                ),
              OutlinedButton(
                onPressed: () async {
                  final ok = await confirm(
                      context,
                      'Replace the ${t.name.toLowerCase()}?',
                      'New ${fmtMoney(t.price)} (2 days) — the old one is sold for ${fmtMoney(sim.equipmentResale(e))}.',
                      ok: 'Replace');
                  if (ok && context.mounted) {
                    sendCmd(context, BuyEquipment(e.type, replaceId: e.id),
                        okText: 'A new one arrives in 2 days.');
                  }
                },
                child: const Text('Replace'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final ok = await confirm(
                      context,
                      'Sell the ${t.name.toLowerCase()}?',
                      'You get ${fmtMoney(sim.equipmentResale(e))}.',
                      ok: 'Sell');
                  if (ok && context.mounted) {
                    sendCmd(context, SellEquipment(e.id));
                  }
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

import 'package:flutter/material.dart';
import 'package:sim_core/sim_core.dart';

import '../shell/shell.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'kitchen_tab.dart';
import 'stock_tab.dart';

/// Close report in three pages (doc 07 §4.5).
class CloseReport extends StatelessWidget {
  const CloseReport({super.key});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final t = sim.state.viewLoc.today;
    return DefaultTabController(
      length: 3,
      child: Column(children: [
        Container(
          color: Palette.surface,
          child: const TabBar(tabs: [
            Tab(text: 'The day'),
            Tab(text: 'Why'),
            Tab(text: 'Tomorrow')
          ]),
        ),
        Expanded(
          child: TabBarView(children: [
            _DayPage(t: t),
            _WhyPage(t: t),
            const _TomorrowPage(),
          ]),
        ),
        SafeArea(
          top: false,
          child: Container(
            color: Palette.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Centered(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54)),
                onPressed: () => sendCmd(context, const EndDay()),
                icon: const Icon(Icons.bedtime),
                label: Text(
                    'Sleep · next day (${weekdays[(sim.state.weekday + 1) % 7]})'),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _DayPage extends StatelessWidget {
  final DayStats t;
  const _DayPage({required this.t});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final ss = sim.service;
    final met = ss != null && !t.closed && ss.lost <= ss.target;
    Widget stat(String k, String v,
            {IconData? icon,
            Color? color,
            VoidCallback? onTap,
            String? term}) =>
        Expanded(
          child: Panel(
            onTap: onTap,
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: color ?? Palette.muted),
                  const SizedBox(width: 4)
                ],
                Flexible(
                  child: term == null
                      ? Text(k,
                          style: const TextStyle(
                              color: Palette.muted, fontSize: 12))
                      : TermText(k, term,
                          style: const TextStyle(
                              color: Palette.muted, fontSize: 12)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(v,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: color ?? Palette.ink)),
            ]),
          ),
        );
    return Centered(
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            Text(sim.dayInOneLine(t),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            if (sim.runOutRisks().isNotEmpty) ...[
              const _OrderNudge(),
              const SizedBox(height: 10),
            ],
            Panel(
              onTap: () => showWhy(context, sim.explain('profit')),
              child: Column(children: [
                Row(children: [
                  const Text('Profit today',
                      style: TextStyle(color: Palette.muted)),
                  const Spacer(),
                  const Icon(Icons.help_outline,
                      size: 18, color: Palette.muted),
                ]),
                const SizedBox(height: 6),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Money(t.profit,
                        size: 30, sign: true, weight: FontWeight.w900)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _line('Sales', t.revenue)),
                  Expanded(child: _line('Costs', -t.costs)),
                ]),
              ]),
            ),
            const SizedBox(height: 10),
            Row(children: [
              stat('Served', '${t.groupsServed}', icon: Icons.groups),
              const SizedBox(width: 8),
              stat('Walked out', '${t.walkouts}',
                  icon: Icons.directions_walk,
                  color: t.walkouts > 0 ? Palette.bad : Palette.ok,
                  term: 'walk_out'),
              const SizedBox(width: 8),
              stat('Reviews',
                  t.starsN == 0 ? '–' : '${t.avgStars.toStringAsFixed(1)}★',
                  icon: Icons.star,
                  color: Palette.gold,
                  onTap: () => showWhy(context, sim.explain('satisfaction'))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              stat('Tips for staff', fmtMoney(t.tips),
                  icon: Icons.volunteer_activism),
              const SizedBox(width: 8),
              stat('Waste', fmtMoney(t.wasteCost),
                  icon: Icons.delete_outline,
                  color: t.wasteCost > 100 ? Palette.warn : null,
                  term: 'waste'),
              const SizedBox(width: 8),
              stat('Target', t.closed ? '–' : (met ? 'Met' : 'Missed'),
                  icon: Icons.flag,
                  color: met ? Palette.ok : Palette.bad,
                  term: 'shift_target'),
            ]),
            if (met) ...[
              const SizedBox(height: 8),
              const Text('Target met: the team is a little happier tonight.',
                  style: TextStyle(
                      color: Palette.ok, fontWeight: FontWeight.w600)),
            ],
            const SectionTitle('Rating'),
            Panel(
              onTap: () => showWhy(context, sim.explain('reputation')),
              child: Row(children: [
                Stars(sim.state.viewLoc.reputation, size: 22),
                const SizedBox(width: 10),
                Text(sim.state.viewLoc.reputation.toStringAsFixed(2),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(width: 10),
                const Expanded(
                    child: Text('moves toward today\'s reviews',
                        textAlign: TextAlign.right,
                        style: TextStyle(color: Palette.muted, fontSize: 12))),
              ]),
            ),
            if (sim.state.weekday == 6 && sim.state.weeks.isNotEmpty) ...[
              const SectionTitle('Week statement'),
              _WeekPanel(w: sim.state.weeks.last),
            ],
          ]),
    );
  }

  Widget _line(String k, int v) => Row(children: [
        Flexible(
            child: Text('$k ',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Palette.muted))),
        Flexible(child: Money(v, size: 14, sign: true)),
      ]);
}

class _WeekPanel extends StatelessWidget {
  final WeekRecord w;
  const _WeekPanel({required this.w});
  @override
  Widget build(BuildContext context) {
    Widget row(String k, int v, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(
                child: Text(k,
                    style: TextStyle(
                        fontWeight: bold ? FontWeight.w800 : FontWeight.w500))),
            Money(v, sign: true, size: bold ? 16 : 14),
          ]),
        );
    return Panel(
      child: Column(children: [
        row('Sales', w.revenue),
        row('Ingredients', -w.ingredientSpend),
        row('Wages', -w.wages),
        row('Rent', -w.rent),
        row('Utilities', -w.utilities),
        row('Repairs, marketing, other', -(w.upkeep + w.marketing + w.other)),
        const Divider(height: 14),
        row('Profit', w.operatingProfit, bold: true),
        row('Loan interest', -w.interest),
        row('Net profit', w.netProfit, bold: true),
      ]),
    );
  }
}

class _WhyPage extends StatelessWidget {
  final DayStats t;
  const _WhyPage({required this.t});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final causes = sim.topCauses(t);
    final good = <String>[];
    if (t.walkouts == 0 && t.groupsServed > 0) good.add('Nobody walked out');
    if (t.avgStars >= 3.8) {
      good.add(
          'Customers loved it (${t.avgStars.toStringAsFixed(1)}★ average)');
    }
    if (t.wasteCost == 0) good.add('No food thrown away');
    if (t.profit > 0) good.add('A profitable day');
    final others = t.events
        .where((e) =>
            e.kind == 'incidentResult' ||
            (e.value == 0 && e.kind != 'incident'))
        .toList();
    return Centered(
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            const SectionTitle('What went wrong'),
            if (causes.isEmpty)
              const EmptyNote('Nothing went badly wrong today.')
            else
              for (var i = 0; i < causes.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Panel(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      CircleAvatar(
                          radius: 13,
                          backgroundColor: Palette.bad.withValues(alpha: 0.12),
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  color: Palette.bad,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(causes[i].text,
                              style: const TextStyle(height: 1.3))),
                      if (_fixTab(causes[i].kind) != null)
                        TextButton(
                            onPressed: () =>
                                ShellNav.to(context, _fixTab(causes[i].kind)!),
                            child: const Text('Fix')),
                    ]),
                  ),
                ),
            const SectionTitle('What went right'),
            if (good.isEmpty)
              const EmptyNote('Hard day. Tomorrow is another.',
                  icon: Icons.sentiment_neutral)
            else
              for (final g in good) EmptyNote(g),
            if (others.isNotEmpty) ...[
              const SectionTitle('Also today'),
              for (final e in others)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Icon(Icons.circle,
                                size: 6, color: Palette.muted)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(e.text,
                                style: const TextStyle(
                                    color: Palette.muted, height: 1.35))),
                      ]),
                ),
            ],
          ]),
    );
  }

  int? _fixTab(String kind) => switch (kind) {
        'walkTable' ||
        'walkOrder' ||
        'walkBill' ||
        'absent' ||
        'staffLeft' =>
          1,
        'walkFood' || 'breakdown' || 'platesFull' => 3,
        'soldOut' ||
        'waste' ||
        'deliveryLate' ||
        'deliveryShort' ||
        'badBatch' =>
          2,
        'missedPayment' || 'skim' || 'tax' => 4,
        _ => null,
      };
}

class _TomorrowPage extends StatelessWidget {
  const _TomorrowPage();
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final st = sim.state;
    final l = st.viewLoc;
    final tomorrow = (st.weekday + 1) % 7;
    final off = l.staff.where((s) => s.dayOff == tomorrow).toList();
    final uncovered = sim.uncoveredOn(tomorrow);
    final expiring = <String, int>{};
    for (final b in l.stock.where((b) => b.daysLeft <= 1)) {
      expiring[b.ingredientId] = (expiring[b.ingredientId] ?? 0) + b.qty;
    }
    final festival = sim.festivalOn(st.dayIndex + 1);
    return Centered(
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            SectionTitle(
                '${weekdayLong(tomorrow)}${festival != null ? ' · ${festival.name}' : ''}'),
            Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tomorrow >= 4
                          ? 'Weekends are busy: Friday ×1.25, Saturday ×1.4, Sunday ×1.2.'
                          : 'A weekday: quieter than the weekend.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(off.isEmpty
                        ? 'Nobody has the day off.'
                        : 'Day off: ${off.map((s) => '${s.name.split(' ').first} (${sim.role(s.role).toLowerCase()})').join(', ')}'),
                    if (uncovered.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                          'No ${uncovered.map((r) => r == 'cook' ? 'cook' : sim.role(r).toLowerCase()).join(', ')} rostered — stand-ins will cover, slower.',
                          style: const TextStyle(
                              color: Palette.warn,
                              fontWeight: FontWeight.w600)),
                    ],
                  ]),
            ),
            const SectionTitle('Stock'),
            if (expiring.isEmpty)
              const EmptyNote('Nothing goes off tonight.')
            else
              Panel(
                child: Text(
                    'Going off tonight: ${expiring.entries.map((e) => '${sim.content.ingredients[e.key]!.name} ×${e.value}').join(', ')}',
                    style: const TextStyle(color: Palette.warn)),
              ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50)),
                  onPressed: () {
                    var placed = 0;
                    final done = <String>{};
                    for (final sup in ['sup_standard']) {
                      final lines = sim.suggestedOrder(sup)
                        ..removeWhere((k, v) => done.contains(k));
                      if (lines.isEmpty) continue;
                      if (sendCmd(context, PlaceOrder(sup, lines))) {
                        placed++;
                        done.addAll(lines.keys);
                      }
                    }
                    if (placed > 0) {
                      showToast(context,
                          'Ordered the usual from City Foodservice for tomorrow.',
                          bad: false);
                    }
                    if (placed == 0 &&
                        sim.suggestedOrder('sup_standard').isEmpty) {
                      showToast(context, 'You have enough stock for tomorrow.',
                          bad: false);
                    }
                  },
                  icon: const Icon(Icons.shopping_cart_checkout),
                  label: const Text('Order usual'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50)),
                  onPressed: () => showOrderSheet(context),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit order'),
                ),
              ),
            ]),
            if (l.orders.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                  'Already on order: ${l.orders.map((o) => '${sim.content.suppliers[o.supplierId]!.name} (${fmtMoney(o.total)})').join(', ')}',
                  style: const TextStyle(color: Palette.muted)),
            ],
            const SectionTitle('Health of the business'),
            const HealthCard(),
          ]),
    );
  }
}

/// Tomorrow's stock will not last: the most common way to lose a day early on.
class _OrderNudge extends StatelessWidget {
  const _OrderNudge();
  @override
  Widget build(BuildContext context) {
    final sim = GameScope.of(context).sim!;
    final n = sim.runOutRisks().length;
    return Panel(
      color: const Color(0xFFFFF4D6),
      borderColor: const Color(0xFFF0D58A),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.inventory_2, color: Palette.warn),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  '$n ingredient${n == 1 ? '' : 's'} will run out tomorrow',
                  style: const TextStyle(fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 4),
        const Text(
            'Orders placed now arrive tomorrow morning. No stock, no dishes, angry customers.',
            style: TextStyle(height: 1.35)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () {
                final lines = sim.suggestedOrder('sup_standard');
                if (lines.isEmpty) return;
                sendCmd(context, PlaceOrder('sup_standard', lines),
                    okText: 'Ordered the usual from City Foodservice.');
              },
              icon: const Icon(Icons.shopping_cart_checkout, size: 18),
              label: const Text('Order usual'),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
              onPressed: () => showOrderSheet(context),
              child: const Text('Choose')),
        ]),
      ]),
    );
  }
}

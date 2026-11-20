import 'package:flutter/material.dart';
import 'package:sim_core/sim_core.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// Morning notices: yesterday's news, weekly/monthly statements, stage-ups (doc 07 §4.5, §4.10).
Future<void> showNotices(BuildContext context) async {
  final c = GameScope.read(context);
  final st = c.state!;
  final notes = List<String>.of(st.pendingNotices);
  c.send(const AckNotices());
  final special = notes.where((n) => n.startsWith('@')).toList();
  final plain = notes.where((n) => !n.startsWith('@')).toList();
  for (final s in special) {
    if (!context.mounted) return;
    switch (s) {
      case '@welcome':
        await _sheet(context, const _Welcome());
      case '@stage2':
        await _sheet(context, const _StageUp(stage: 2));
      case '@stage3':
        await _sheet(context, const _StageUp(stage: 3));
      case '@weekly':
        await _sheet(
            context, _Statement(week: st.weeks.isEmpty ? null : st.weeks.last));
      case '@monthly':
        break; // folded into the weekly statement and Money tab
    }
  }
  if (plain.isEmpty || !context.mounted) return;
  await _sheet(
    context,
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Icon(Icons.wb_sunny_outlined, color: Palette.warn),
        const SizedBox(width: 8),
        Text('Good morning', style: Theme.of(context).textTheme.titleLarge),
      ]),
      const SizedBox(height: 4),
      const Text('Here is what happened since yesterday.',
          style: TextStyle(color: Palette.muted)),
      const SizedBox(height: 12),
      for (final n in plain)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Panel(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.circle, size: 8, color: Palette.accent)),
              const SizedBox(width: 10),
              Expanded(child: Text(n, style: const TextStyle(height: 1.35))),
            ]),
          ),
        ),
    ]),
  );
}

Future<void> _sheet(BuildContext context, Widget child) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Centered(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    child,
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52)),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ]),
            ),
          ),
        ),
      ),
    );

class _Welcome extends StatelessWidget {
  const _Welcome();
  @override
  Widget build(BuildContext context) {
    final st = GameScope.of(context).state!;
    Widget step(IconData i, String t, String b) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
                radius: 18,
                backgroundColor: Palette.accentSoft,
                child: Icon(i, color: Palette.accent, size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(b,
                        style: const TextStyle(
                            color: Palette.muted, height: 1.35)),
                  ]),
            ),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('The keys to ${st.loc.name} are yours',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      const Text('Every day has three parts. It takes about five minutes.',
          style: TextStyle(color: Palette.muted)),
      const SizedBox(height: 16),
      step(Icons.checklist, 'Prep',
          'Check who came in, what is running low and what broke. Fix what you can, then open the doors.'),
      step(Icons.restaurant, 'Service',
          'Customers arrive in waves. Stand where the queue is longest, spend favours on tables about to leave.'),
      step(Icons.receipt_long, 'Close',
          'See what went right and wrong, and why. Order for tomorrow, then sleep.'),
      const SizedBox(height: 4),
      Panel(
        color: Palette.accentSoft,
        borderColor: Palette.accentSoft,
        child: const Text(
            'Tap any number with a ? or an underlined word to learn what it means.'),
      ),
    ]);
  }
}

class _StageUp extends StatelessWidget {
  final int stage;
  const _StageUp({required this.stage});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final st = c.state!;
    final title = stage == 2 ? 'Stage 2 · Stable' : 'Stage 3 · Ready to expand';
    final body = stage == 2
        ? 'Four profitable weeks in a row with a good rating. The restaurant is no longer a rescue job.'
        : 'Cash in the bank, a 4-star rating and a clean payment record. You have built a business someone would want to copy.';
    final unlocks = stage == 2
        ? [
            'Marketing: flyers, local ads, promotion days, food bloggers',
            'Keep-in-stock levels (automatic re-ordering)',
            'New goals'
          ]
        : [
            'Company value is now your score',
            'Opening a second location arrives in the next update',
            'Keep playing: the restaurant still needs you'
          ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Icon(Icons.emoji_events, color: Palette.gold, size: 72),
      const SizedBox(height: 8),
      Text(title,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      Text(body,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, height: 1.4)),
      const SizedBox(height: 16),
      const SectionTitle('Unlocked'),
      for (final u in unlocks)
        ListTile(
            dense: true,
            leading: const Icon(Icons.lock_open, color: Palette.accent),
            title: Text(u)),
      if (stage == 3) ...[
        const SectionTitle('Company value'),
        Center(child: Money(c.sim!.valuation(), size: 26)),
      ],
      Text('Day ${st.dayIndex + 1}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Palette.muted)),
    ]);
  }
}

class _Statement extends StatelessWidget {
  final WeekRecord? week;
  const _Statement({required this.week});
  @override
  Widget build(BuildContext context) {
    final w = week;
    if (w == null) return const SizedBox();
    Widget row(String k, int v, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(
                child: Text(k,
                    style: TextStyle(
                        fontWeight: bold ? FontWeight.w800 : FontWeight.w500))),
            Money(v, sign: true, size: bold ? 17 : 14),
          ]),
        );
    final c = GameScope.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Week ${w.week + 1} statement',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      Text('Wages, rent and loan payments left your account on Sunday night.',
          style: const TextStyle(color: Palette.muted)),
      const SizedBox(height: 12),
      row('Sales', w.revenue),
      row('Ingredients', -w.ingredientSpend),
      row('Wages', -w.wages),
      row('Rent', -w.rent),
      row('Utilities', -w.utilities),
      row('Repairs and equipment', -w.upkeep),
      if (w.marketing > 0) row('Marketing', -w.marketing),
      row('Other', -w.other),
      const Divider(height: 18),
      Row(children: [
        const Expanded(
            child: TermText('Profit', 'operating_profit',
                style: TextStyle(fontWeight: FontWeight.w800))),
        Money(w.operatingProfit, sign: true, size: 18),
      ]),
      row('Loan interest', -w.interest),
      row('Net profit', w.netProfit, bold: true),
      const SizedBox(height: 10),
      Panel(
        color: w.netProfit > 0
            ? Palette.accentSoft
            : Palette.bad.withValues(alpha: 0.08),
        borderColor: Colors.transparent,
        child: Text(
          w.netProfit > 0
              ? 'A profitable week (${c.state!.profitableWeeksInRow} in a row). ${c.state!.stage == 1 ? 'Four in a row with a 3.5★ rating reaches Stage 2.' : ''}'
              : 'A losing week. The weekly report on the Money tab shows where the money went.',
        ),
      ),
      const SizedBox(height: 8),
      Text(
          '${w.groupsServed} parties served · ${w.walkouts} walked out · ${w.avgStars.toStringAsFixed(1)}★ average',
          style: const TextStyle(color: Palette.muted)),
    ]);
  }
}

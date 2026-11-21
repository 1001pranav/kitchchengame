import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sim_core/sim_core.dart';

import '../theme.dart';
import 'chain_screens.dart';
import '../widgets/common.dart';

class MoneyTab extends StatelessWidget {
  const MoneyTab({super.key});
  @override
  Widget build(BuildContext context) {
    final chain = GameScope.of(context).state!.stage >= 3;
    final tabs = [
      const Tab(text: 'Overview'),
      if (chain) const Tab(text: 'Outlets'),
      if (chain) const Tab(text: 'Expand'),
      const Tab(text: 'Marketing'),
      const Tab(text: 'Goals'),
    ];
    return DefaultTabController(
      key: ValueKey(chain),
      length: tabs.length,
      child: Column(children: [
        Container(
            color: Palette.surface,
            child: TabBar(
                isScrollable: chain,
                tabAlignment: chain ? TabAlignment.start : null,
                tabs: tabs)),
        Expanded(
          child: TabBarView(children: [
            const _Overview(),
            if (chain) const OutletsPage(),
            if (chain) const ExpandPage(),
            const _Marketing(),
            const _Goals(),
          ]),
        ),
      ]),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview();
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final st = sim.state;
    final l = st.viewLoc;
    final daysToSunday = (6 - st.weekday) % 7;
    final weekDays = [
      ...st.viewLoc.days.where((d) => d.dayIndex >= st.dayIndex - st.weekday),
      if (st.phase != 'prep') st.viewLoc.today
    ];
    final weekRev = weekDays.fold<int>(0, (a, d) => a + d.revenue);
    final weekProfit = weekDays.fold<int>(0, (a, d) => a + d.profit);
    final canAct = st.phase != 'service';
    return Centered(
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Panel(
              onTap: () => showWhy(context, sim.explain('cash')),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const TermText('Cash in hand', 'cash_flow',
                          style: TextStyle(color: Palette.muted)),
                      const Spacer(),
                      const Icon(Icons.help_outline,
                          size: 18, color: Palette.muted),
                    ]),
                    const SizedBox(height: 4),
                    Money(st.cash, size: 28, weight: FontWeight.w900),
                    const SizedBox(height: 12),
                    SizedBox(
                        height: 110,
                        child: CustomPaint(
                            painter: _CashChart(st.cashHistory),
                            size: Size.infinite)),
                    const Text('Last weeks, at each close',
                        style: TextStyle(color: Palette.muted, fontSize: 11.5)),
                  ]),
            ),
            const SectionTitle('This week so far'),
            Panel(
              child: Column(children: [
                _row('Sales', weekRev),
                _row('Profit', weekProfit, bold: true),
                const SizedBox(height: 4),
                Text('Wages and rent are counted every day but paid on Sunday.',
                    style: TextStyle(
                        color: Palette.muted.withValues(alpha: 1),
                        fontSize: 12)),
              ]),
            ),
            SectionTitle(
                'Due ${daysToSunday == 0 ? 'tonight' : 'in $daysToSunday day${daysToSunday == 1 ? '' : 's'}'} (Sunday)'),
            Panel(
              child: Column(children: [
                _row('Wages owed so far', -st.wagesOwed),
                _row('Rent', -l.rentWeekly),
                _row('Loan payments', -sim.weeklyInstalments()),
                const Divider(height: 14),
                _row('Utilities this month (paid on day 28)',
                    -st.monthUtilities),
              ]),
            ),
            SectionTitle('Loans (${st.loans.length})'),
            for (final loan in st.loans)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Panel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(
                              loan.lender == 'private'
                                  ? Icons.warning_amber_rounded
                                  : Icons.account_balance,
                              color: loan.lender == 'private'
                                  ? Palette.bad
                                  : Palette.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              loan.lender == 'private'
                                  ? 'Private lender'
                                  : (loan.lender == 'start'
                                      ? 'Purchase loan (on the restaurant)'
                                      : 'Bank loan${loan.secured ? ' (on the restaurant)' : ''}'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Money(loan.outstanding, size: 15),
                        ]),
                        const SizedBox(height: 6),
                        StatBar(1 - loan.outstanding / loan.principal0,
                            color: Palette.accent),
                        const SizedBox(height: 6),
                        Text(
                            '${fmtMoney(loan.instalment)} a week · ${(loan.weeklyRate * 52 * 100).toStringAsFixed(1)}% a year · ${loan.missedInRow > 0 ? '${loan.missedInRow} missed!' : 'on time'}',
                            style: TextStyle(
                                color: loan.missedInRow > 0
                                    ? Palette.bad
                                    : Palette.muted,
                                fontSize: 12.5)),
                        if (canAct)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: st.cash <= 0
                                  ? null
                                  : () async {
                                      final amount = math.min(loan.outstanding,
                                          math.max(0, st.cash - 5000));
                                      if (amount <= 0) {
                                        showToast(context,
                                            'Keep at least 5,000 in cash for the week.');
                                        return;
                                      }
                                      final ok = await confirm(
                                          context,
                                          'Repay ${fmtMoney(amount)} early?',
                                          'No fee. Less interest from now on.',
                                          ok: 'Repay');
                                      if (ok && context.mounted) {
                                        sendCmd(
                                            context, RepayLoan(loan.id, amount),
                                            okText: 'Repaid.');
                                      }
                                    },
                              child: const Text('Repay early'),
                            ),
                          ),
                      ]),
                ),
              ),
            if (canAct)
              Row(children: [
                Expanded(
                    child: FilledButton.tonalIcon(
                        onPressed: () => showLoanSheet(context),
                        icon: const Icon(Icons.account_balance),
                        label: const Text('Ask the bank'))),
              ]),
            const SectionTitle('The bank\'s view of you'),
            Panel(
              child: Column(children: [
                Row(children: [
                  const Expanded(child: TermText('Bank trust', 'credit_score')),
                  SizedBox(width: 120, child: StatBar(st.creditScore / 100)),
                  const SizedBox(width: 8),
                  Text('${st.creditScore.round()}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => showWhy(context, sim.explain('valuation')),
                  child: Row(children: [
                    const Expanded(
                        child: TermText('Company value', 'valuation')),
                    Money(sim.valuation(), size: 16),
                    const SizedBox(width: 4),
                    const Icon(Icons.help_outline,
                        size: 16, color: Palette.muted),
                  ]),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  const Expanded(child: Text('Average weekly profit (8 wks)')),
                  Money(sim.avgWeeklyProfit(), size: 15, sign: true),
                ]),
              ]),
            ),
            if (st.weeks.isNotEmpty) ...[
              const SectionTitle('Past weeks'),
              Panel(
                child: Column(children: [
                  for (final w in st.weeks.reversed.take(8))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        SizedBox(
                            width: 64,
                            child: Text('Week ${w.week + 1}',
                                style: const TextStyle(color: Palette.muted))),
                        Expanded(
                            child: Text('sales ${fmtMoney(w.revenue)}',
                                style: const TextStyle(fontSize: 12.5))),
                        Money(w.netProfit, size: 14, sign: true),
                      ]),
                    ),
                ]),
              ),
            ],
          ]),
    );
  }

  Widget _row(String k, int v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(
              child: Text(k,
                  style: TextStyle(
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w500))),
          Money(v, size: bold ? 16 : 14, sign: true),
        ]),
      );
}

class _CashChart extends CustomPainter {
  final List<int> data;
  _CashChart(this.data);
  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) {
      final tp = TextPainter(
          text: const TextSpan(
              text: 'The chart fills in as days pass',
              style: TextStyle(color: Palette.muted)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(0, size.height / 2 - 8));
      return;
    }
    final minV = math.min(0, data.reduce(math.min)).toDouble();
    final maxV = math.max(1, data.reduce(math.max)).toDouble();
    double y(num v) => size.height - (v - minV) / (maxV - minV) * size.height;
    final dx = size.width / (data.length - 1);
    final zero = Paint()
      ..color = Palette.line
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, y(0)), Offset(size.width, y(0)), zero);
    final path = Path()..moveTo(0, y(data[0]));
    for (var i = 1; i < data.length; i++) {
      path.lineTo(i * dx, y(data[i]));
    }
    final fill = Path.from(path)
      ..lineTo(size.width, y(minV))
      ..lineTo(0, y(minV))
      ..close();
    canvas.drawPath(
        fill, Paint()..color = Palette.accent.withValues(alpha: 0.10));
    canvas.drawPath(
        path,
        Paint()
          ..color = Palette.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round);
    for (var i = 0; i < data.length; i++) {
      if (data[i] < 0) {
        canvas.drawCircle(
            Offset(i * dx, y(data[i])), 3, Paint()..color = Palette.bad);
      }
    }
  }

  @override
  bool shouldRepaint(_CashChart old) =>
      old.data != data || old.data.length != data.length;
}

// ------------------------------------------------------------------ loan application

void showLoanSheet(BuildContext context) {
  showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _LoanSheet());
}

class _LoanSheet extends StatefulWidget {
  const _LoanSheet();
  @override
  State<_LoanSheet> createState() => _LoanSheetState();
}

class _LoanSheetState extends State<_LoanSheet> {
  double amount = 10000;
  int term = 52;
  bool secured = false;
  String? result;

  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final st = sim.state;
    final checks = sim.bankChecks(amount.round(), term, secured);
    final rate = sim.loanRate(secured: secured);
    final weekly = (amount / term + amount * rate).round();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Ask the bank for a loan',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text(
              'The bank does not roll dice: it checks five things, in order. You can see them before you ask.',
              style: TextStyle(color: Palette.muted)),
          const SizedBox(height: 14),
          Row(children: [
            const Text('Amount'),
            const Spacer(),
            Money(amount, size: 18)
          ]),
          Slider(
              value: amount,
              min: 1000,
              max: 60000,
              divisions: 59,
              onChanged: (v) => setState(() => amount = v)),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 26, label: Text('6 months')),
              ButtonSegment(value: 52, label: Text('1 year')),
              ButtonSegment(value: 104, label: Text('2 years'))
            ],
            selected: {term},
            onSelectionChanged: (s) => setState(() => term = s.first),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: secured,
            onChanged: st.loans.any((l) => l.secured)
                ? null
                : (v) => setState(() => secured = v),
            title:
                const TermText('Secure it on the restaurant', 'secured_loan'),
            subtitle: Text(st.loans.any((l) => l.secured)
                ? 'The restaurant already secures a loan.'
                : 'Cheaper, and the bank allows bigger repayments.'),
          ),
          Panel(
            color: Palette.surface2,
            borderColor: Colors.transparent,
            child: Row(children: [
              const Text('About '),
              Money(weekly, size: 15),
              Text(' a week · ${(rate * 52 * 100).toStringAsFixed(1)}% a year'),
            ]),
          ),
          const SizedBox(height: 10),
          for (final ch in checks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Icon(ch.value ? Icons.check_circle : Icons.cancel,
                    color: ch.value ? Palette.ok : Palette.bad, size: 20),
                const SizedBox(width: 8),
                Expanded(
                    child:
                        Text(ch.key, style: const TextStyle(fontSize: 13.5))),
              ]),
            ),
          if (result != null) ...[
            const SizedBox(height: 10),
            Panel(
                color: Palette.accentSoft,
                borderColor: Colors.transparent,
                child: Text(result!)),
          ],
          const SizedBox(height: 14),
          if (st.counterOffer != null)
            FilledButton(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
              onPressed: () {
                if (sendCmd(context, const AcceptCounterOffer(),
                    okText: 'Loan approved.')) {
                  Navigator.pop(context);
                }
              },
              child: Text(
                  'Accept the bank\'s offer of ${fmtMoney(st.counterOffer!)}'),
            )
          else
            FilledButton(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
              onPressed: () {
                final r =
                    c.send(ApplyLoan(amount.round(), term, secured: secured));
                c.takeToast();
                setState(() {
                  if (r.ok && r.value == 'approved') {
                    result =
                        'Approved. ${fmtMoney(amount)} is in your account. First payment next Sunday.';
                  } else if (r.ok) {
                    result =
                        '${r.message} Take it, or improve your numbers and ask again.';
                  } else {
                    result =
                        '${r.message ?? 'Rejected.'} The bank will not look at another application for 7 days. Raise your weekly profit or bank trust to change the answer.';
                  }
                });
              },
              child: const Text('Apply'),
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
                foregroundColor: Palette.bad,
                minimumSize: const Size.fromHeight(46)),
            onPressed: () async {
              final ok = await confirm(context, 'Private lender?',
                  'Up to 20,000, no questions, at three times the bank\'s interest over 6 months. Missing a payment costs 10% and a lot of bank trust. A last resort.',
                  ok: 'Borrow 20,000');
              if (ok && context.mounted) {
                if (sendCmd(
                    context, const ApplyLoan(20000, 26, lender: 'private'),
                    okText: '20,000 borrowed from a private lender.')) {
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
            child:
                const TermText('Private lender (no checks)', 'private_lender'),
          ),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ marketing

class _Marketing extends StatelessWidget {
  const _Marketing();
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
            Text('Marketing unlocks at Stage 2',
                style: TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text(
                'First make the restaurant stable: four profitable weeks in a row and a 3.5★ rating.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Palette.muted)),
          ]),
        ),
      );
    }
    final defs = c.content.balance.map('CAMPAIGNS');
    final canAct = st.phase != 'service';
    const blurbs = {
      'flyers': 'Cheap, small, short. Families and students read them.',
      'localAd': 'A week in the local paper. Office workers and families.',
      'promoDay': 'Everything 25% off for one day. A crowd, thin margins.',
      'blogger':
          'A food blogger visits within 3 days. Great food: +0.3 rating. Bad: −0.2.',
    };
    final history = List<Campaign>.of(st.viewLoc.campaigns)
      ..sort((a, b) => b.startDay.compareTo(a.startDay));
    return Centered(
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const Text(
                'Advertising is a gamble: any campaign can flop or be a big hit. The right audience, a fresh menu and a good rating improve the odds; repeating the same ad too soon makes it worse.',
                style: TextStyle(color: Palette.muted, height: 1.35)),
            const SizedBox(height: 10),
            for (final type in ['flyers', 'localAd', 'promoDay', 'blogger'])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Builder(builder: (context) {
                  final d = defs[type] as Map;
                  final fit = sim.campaignFit(type);
                  final last = sim.lastCampaignDay(type);
                  final settled = st.viewLoc.campaigns
                      .where((x) => x.type == type && x.settled)
                      .toList();
                  return Panel(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(
                                switch (type) {
                                  'flyers' => Icons.description,
                                  'localAd' => Icons.newspaper,
                                  'promoDay' => Icons.percent,
                                  _ => Icons.camera_alt
                                },
                                color: Palette.tomato),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(
                                    const {
                                      'flyers': 'Flyers',
                                      'localAd': 'Local ad',
                                      'promoDay': 'Promotion day',
                                      'blogger': 'Food blogger'
                                    }[type]!,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16))),
                            Money((d['cost'] as num).toInt(), size: 14),
                          ]),
                          const SizedBox(height: 4),
                          Text(blurbs[type]!,
                              style: const TextStyle(height: 1.3)),
                          const SizedBox(height: 6),
                          Wrap(spacing: 6, runSpacing: 4, children: [
                            if (type != 'blogger')
                              Pill('audience fit: ${sim.fitWord(fit)}',
                                  color: fit >= 0.6
                                      ? Palette.ok
                                      : (fit >= 0.45
                                          ? Palette.warn
                                          : Palette.bad)),
                            if (type != 'blogger')
                              Pill(
                                  '+${((d['boost'] as num) * 100).round()}% customers for ${d['days']} day${d['days'] == 1 ? '' : 's'}',
                                  color: Palette.staff),
                            if (last != null && st.dayIndex - last < 21)
                              Pill(
                                  'ran ${st.dayIndex - last} days ago — people have seen it',
                                  color: Palette.warn),
                            if (st.viewLoc.freshness >= 0.8)
                              const Pill('fresh menu: better odds',
                                  color: Palette.ok),
                          ]),
                          if (settled.length >= 2) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Here: ×${(settled.fold(0.0, (a, x) => a + x.extraProfit) / math.max(1, settled.fold(0, (a, x) => a + x.spend))).toStringAsFixed(1)} on average over ${settled.length}, ${settled.where((x) => x.mult == 0).length} flopped',
                              style: const TextStyle(
                                  color: Palette.muted, fontSize: 12.5),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.tonal(
                              onPressed: canAct
                                  ? () => sendCmd(context, StartCampaign(type),
                                      okText:
                                          'Campaign started. You will hear how it went tomorrow morning.')
                                  : null,
                              child: const Text('Run it'),
                            ),
                          ),
                        ]),
                  );
                }),
              ),
            if (history.isNotEmpty) ...[
              const SectionTitle('Campaign history'),
              for (final h in history)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Panel(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(
                                  '${const {
                                    'flyers': 'Flyers',
                                    'localAd': 'Local ad',
                                    'promoDay': 'Promotion day',
                                    'blogger': 'Food blogger'
                                  }[h.type]} · day ${h.startDay + 1}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                            ),
                            Pill(h.revealed ? h.outcome : 'find out tomorrow',
                                color: !h.revealed
                                    ? Palette.muted
                                    : (h.mult == 0
                                        ? Palette.bad
                                        : (h.mult >= 1.5
                                            ? Palette.ok
                                            : Palette.warn))),
                          ]),
                          if (h.type != 'blogger') ...[
                            const SizedBox(height: 4),
                            Text(
                              'spent ${fmtMoney(h.spend)} · +${h.extraGroups.round()} parties · brought back ${fmtMoney(h.extraProfit)}'
                              '${h.returnOnSpend == null ? '' : ' · ×${h.returnOnSpend!.toStringAsFixed(1)}'}${h.settled ? '' : ' so far'}',
                              style: TextStyle(
                                  color: (h.returnOnSpend ?? 0) >= 1
                                      ? Palette.ok
                                      : Palette.bad,
                                  fontSize: 12.5),
                            ),
                          ],
                        ]),
                  ),
                ),
            ],
          ]),
    );
  }
}

class _Goals extends StatelessWidget {
  const _Goals();
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final st = c.state!;
    final stageNames = {1: 'Takeover', 2: 'Stable', 3: 'Ready to expand'};
    final nextStage = st.stage == 1
        ? 'Four profitable weeks in a row (now ${st.profitableWeeksInRow}) with a rating of 3.5 or more (now ${st.viewLoc.reputation.toStringAsFixed(2)}).'
        : (st.stage == 2
            ? 'Cash of 60,000 or more (now ${fmtMoney(st.cash)}), a 4.0 rating (now ${st.viewLoc.reputation.toStringAsFixed(2)}) and no missed loan payment for 8 weeks.'
            : 'You reached the last stage of this version. Keep growing your company value.');
    return Centered(
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Panel(
              color: Palette.accentSoft,
              borderColor: Colors.transparent,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stage ${st.stage} · ${stageNames[st.stage]}',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(st.stage < 3 ? 'Next stage: $nextStage' : nextStage,
                        style: const TextStyle(height: 1.35)),
                  ]),
            ),
            for (final stage in [1, 2])
              if (stage <= st.stage) ...[
                SectionTitle('Stage $stage goals'),
                for (final o
                    in c.content.objectives.where((o) => o.stage == stage))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Panel(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Icon(
                            st.objectivesDone.contains(o.id)
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: st.objectivesDone.contains(o.id)
                                ? Palette.ok
                                : Palette.muted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(o.text,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                Text('Reward: ${o.rewardText}',
                                    style: const TextStyle(
                                        color: Palette.muted, fontSize: 12.5)),
                              ]),
                        ),
                      ]),
                    ),
                  ),
              ],
            if (st.viewLoc.hidden.isNotEmpty) ...[
              const SectionTitle('Inherited problems'),
              for (final h in st.viewLoc.hidden)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                      h.done
                          ? Icons.check_circle
                          : (h.revealed
                              ? Icons.warning_amber_rounded
                              : Icons.help_outline),
                      color: h.done ? Palette.ok : Palette.warn),
                  title: Text(h.revealed || h.done
                      ? _hidden(h.kind)
                      : 'Unknown problem (not found before buying)'),
                ),
            ],
            const SectionTitle('Story so far'),
            for (final e in st.timeline.reversed.take(12))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          width: 62,
                          child: Text('Day ${e.day + 1}',
                              style: const TextStyle(color: Palette.muted))),
                      Expanded(child: Text(e.text)),
                    ]),
              ),
          ]),
    );
  }

  String _hidden(String k) =>
      const {
        'supplier_debt': 'An old supplier bill',
        'health_violation': 'A health violation',
        'chef_leaving': 'The head chef wanted to quit',
        'pests': 'Pests',
        'fridge_failing': 'A failing fridge',
        'cashier_skimming': 'A cashier stealing from the till',
        'lease_increase': 'A rent rise',
        'overdue_licence': 'An overdue licence',
        'staff_feud': 'A staff feud',
        'fake_reviews': 'Fake reviews',
      }[k] ??
      k;
}

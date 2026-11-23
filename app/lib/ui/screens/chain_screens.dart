import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sim_core/sim_core.dart';

import '../theme.dart';
import '../widgets/common.dart';
import '../scene/pictures.dart';
import '../scene/shopfront.dart';
import 'title_screen.dart' show cuisines, tierColors;

const formatLabels = {
  'neighbourhood': 'Neighbourhood',
  'highStreet': 'High street',
  'officeDistrict': 'Office district'
};
const formatBlurbs = {
  'neighbourhood': 'Steady trade from people who live nearby.',
  'highStreet': 'Busy weekends and high rent; rivals arrive twice as fast.',
  'officeDistrict':
      'A big lunch rush and dead evenings. Takeaway and delivery orders on top.',
};
const badgeColors = {
  'bronze': Color(0xFFB07A44),
  'silver': Color(0xFF8F9AA3),
  'gold': Color(0xFFE0A526)
};

Color statusColor(Sim sim, Location l) {
  if (l.openDay > sim.state.dayIndex) return Palette.muted;
  if (l.crisis) return Palette.bad;
  if (l.weeks.isNotEmpty && l.weeks.last.operatingProfit < 0) {
    return Palette.warn;
  }
  return Palette.ok;
}

String statusText(Sim sim, Location l) {
  if (l.openDay > sim.state.dayIndex) return 'being fitted out';
  if (l.crisis) return 'in trouble';
  if (l.weeks.isNotEmpty && l.weeks.last.operatingProfit < 0) {
    return 'lost money last week';
  }
  return 'fine';
}

/// One chip per outlet above the Today tab (doc 07 §4.11).
class LocationStrip extends StatelessWidget {
  const LocationStrip({super.key});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final st = sim.state;
    final ls = st.openLocations;
    if (ls.length < 2) return const SizedBox.shrink();
    return Container(
      color: Palette.surface,
      height: 54,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          children: [
            for (final l in ls)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Material(
                  color: l.id == st.viewLocationId
                      ? Palette.accentSoft
                      : Palette.surface2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: l.id == st.viewLocationId
                            ? Palette.accent
                            : Colors.transparent,
                        width: 1.5),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => sendCmd(context, SelectLocation(l.id)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(children: [
                        Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: statusColor(sim, l))),
                        const SizedBox(width: 6),
                        Text(l.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                        if (l.service != null && !l.service!.done) ...[
                          const SizedBox(width: 6),
                          Pill(
                              '${l.service!.groups.where((g) => g.waiting).length}',
                              icon: Icons.people,
                              color: Palette.staff),
                        ],
                        if (st.ownerLocationId == l.id && !st.travelling) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.person_pin_circle,
                              size: 18, color: Palette.owner),
                        ],
                        if (st.travelTo == l.id) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.directions_car,
                              size: 18, color: Palette.owner),
                        ],
                        if (l.badge.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.workspace_premium,
                              size: 16, color: badgeColors[l.badge]),
                        ],
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
    );
  }
}

/// Shown on the service view when looking at an outlet the owner is not in.
class AwayBanner extends StatelessWidget {
  const AwayBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final st = c.state!;
    if (st.openLocations.length < 2) return const SizedBox.shrink();
    final here = st.viewLoc;
    if (st.travelling) {
      final to = st.locationById(st.travelTo)!;
      return _bar(context, Icons.directions_car,
          'On the road to ${to.name}… arriving soon.', null);
    }
    if (st.ownerLocationId == here.id) return const SizedBox.shrink();
    final at = st.locationById(st.ownerLocationId)!;
    final m = here.manager;
    return _bar(
      context,
      Icons.visibility,
      'Watching ${here.name}. You are at ${at.name}. ${m == null ? 'Nobody is in charge here!' : '${m.name} is in charge.'}',
      st.phase == 'service' || st.phase == 'prep'
          ? FilledButton.tonal(
              onPressed: () => sendCmd(context, OwnerTravel(here.id),
                  okText: st.phase == 'prep'
                      ? 'You will start the day at ${here.name}.'
                      : 'On your way: about 40 minutes, a little tiring.'),
              child: Text(st.phase == 'prep' ? 'Start here' : 'Go there'),
            )
          : null,
    );
  }

  Widget _bar(
          BuildContext context, IconData icon, String text, Widget? action) =>
      Material(
        color: Palette.owner.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
          child: Row(children: [
            Icon(icon, color: Palette.owner, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text(text,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13))),
            if (action != null) action,
          ]),
        ),
      );
}

/// Top of Prep with two or more outlets: results, requests, where to be (doc 07 §4.11).
class OwnersDesk extends StatelessWidget {
  const OwnersDesk({super.key});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final st = sim.state;
    final ls = st.openLocations;
    if (ls.length < 2) return const SizedBox.shrink();
    final suggestion = ls
        .where((l) => l.openDay <= st.dayIndex)
        .fold<Location?>(null, (best, l) {
      final days = st.dayIndex - l.lastVisitDay;
      if (best == null) return l;
      return days > st.dayIndex - best.lastVisitDay ? l : best;
    });
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Owner\'s desk'),
      Panel(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          for (final l in ls)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: statusColor(sim, l))),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${l.name}${l.manager == null && st.ownerLocationId != l.id && l.openDay <= st.dayIndex ? ' · no manager: won\'t open without you' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (l.days.isNotEmpty)
                  Money(l.days.last.profit, size: 13, sign: true)
                else
                  const Text('new', style: TextStyle(color: Palette.muted)),
              ]),
            ),
        ]),
      ),
      if (st.requests.isNotEmpty) ...[
        SectionTitle('Requests (${st.requests.length})'),
        for (final r in st.requests.take(5)) RequestCard(r: r),
      ],
      const SectionTitle('Where will you be today?'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final l in ls)
          ChoiceChip(
            label: Text(l.name),
            avatar: Icon(
                st.ownerLocationId == l.id
                    ? Icons.person_pin_circle
                    : Icons.storefront,
                size: 18),
            selected: st.ownerLocationId == l.id,
            onSelected: (_) => sendCmd(context, OwnerTravel(l.id)),
          ),
      ]),
      if (suggestion != null &&
          suggestion.id != st.ownerLocationId &&
          st.dayIndex - suggestion.lastVisitDay >= 5)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
              'Suggestion: ${suggestion.name} — not visited for ${st.dayIndex - suggestion.lastVisitDay} days.',
              style: const TextStyle(color: Palette.muted)),
        ),
    ]);
  }
}

class RequestCard extends StatelessWidget {
  final Request r;
  const RequestCard({super.key, required this.r});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final l = c.state!.locationById(r.locationId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.mark_email_unread, color: Palette.staff, size: 20),
            const SizedBox(width: 6),
            Expanded(
                child: Text(
                    '${l?.name ?? ''} · ${l?.manager?.name ?? 'Manager'} asks',
                    style:
                        const TextStyle(color: Palette.muted, fontSize: 12.5))),
            Money(r.cost, size: 13),
          ]),
          const SizedBox(height: 4),
          Text(r.text, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: [
            FilledButton(
                onPressed: () => sendCmd(
                    context, AnswerRequest(r.id, 'approve'),
                    okText: 'Approved.'),
                child: const Text('Approve')),
            if (r.cheaperCost != null)
              OutlinedButton(
                  onPressed: () => sendCmd(
                      context, AnswerRequest(r.id, 'cheaper'),
                      okText: 'Done the cheaper way.'),
                  child: Text('Cheaper ${fmtMoney(r.cheaperCost!)}')),
            TextButton(
                onPressed: () => sendCmd(context, AnswerRequest(r.id, 'deny')),
                child: const Text('Deny')),
          ]),
        ]),
      ),
    );
  }
}

/// Company tab: every outlet, with its ledger, badge, manager and standing orders.
class OutletsPage extends StatelessWidget {
  const OutletsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final st = sim.state;
    return Centered(
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (st.requests.isNotEmpty) ...[
              SectionTitle('Requests (${st.requests.length})'),
              for (final r in st.requests) RequestCard(r: r),
            ],
            const SectionTitle('Your outlets'),
            for (final l in st.openLocations) OutletCard(l: l),
            if (st.locations.any((l) => l.closedForGood)) ...[
              const SectionTitle('Former outlets'),
              for (final l in st.locations.where((l) => l.closedForGood))
                ListTile(
                    dense: true,
                    leading: const Icon(Icons.history),
                    title: Text(l.name),
                    subtitle: Text(l.story.isEmpty ? '' : l.story.last.text)),
            ],
          ]),
    );
  }
}

class OutletCard extends StatelessWidget {
  final Location l;
  const OutletCard({super.key, required this.l});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final st = sim.state;
    final w = l.weeks.isEmpty ? null : l.weeks.last;
    final payback = l.invested <= 0 ? 0.0 : l.returned / l.invested;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        onTap: () {
          sendCmd(context, SelectLocation(l.id));
          showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => OutletSheet(locationId: l.id));
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Shopfront(
                name: l.name,
                accent: accentOf(c.content.themes[l.themeId]?.accent),
                quality: tierQuality(l.tierId),
                open: !l.closedForGood,
                height: 70,
                seed: l.id),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: statusColor(sim, l))),
            const SizedBox(width: 8),
            Expanded(
                child: Text(l.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16))),
            if (l.badge.isNotEmpty)
              Pill(l.badge,
                  color: badgeColors[l.badge]!, icon: Icons.workspace_premium),
          ]),
          const SizedBox(height: 4),
          Text(
              '${formatLabels[l.format]} · ${cuisines[l.themeId]?.$1 ?? l.themeId} · ${statusText(sim, l)}',
              style: const TextStyle(color: Palette.muted, fontSize: 12.5)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _kv(
                    'Last week',
                    w == null
                        ? const Text('–')
                        : Money(w.operatingProfit, size: 14, sign: true))),
            Expanded(
                child: _kv(
                    'Rating',
                    Text('${l.reputation.toStringAsFixed(1)} / 5',
                        style: const TextStyle(fontWeight: FontWeight.w800)))),
            Expanded(
                child: _kv(
                    'Last visit',
                    Text(
                        st.dayIndex - l.lastVisitDay == 0
                            ? 'today'
                            : '${st.dayIndex - l.lastVisitDay}d ago',
                        style: const TextStyle(fontWeight: FontWeight.w800)))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const TermText('Paid back', 'payback',
                style: TextStyle(color: Palette.muted, fontSize: 12)),
            const SizedBox(width: 8),
            Expanded(child: StatBar(payback, color: Palette.accent)),
            const SizedBox(width: 8),
            Text('${(payback * 100).round()}%',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Text(
              l.manager == null
                  ? 'No manager'
                  : 'Manager: ${l.manager!.name} (${l.manager!.grade})',
              style: TextStyle(
                  color: l.manager == null ? Palette.warn : Palette.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _kv(String k, Widget v) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: const TextStyle(color: Palette.muted, fontSize: 12)),
        v,
      ]);
}

class OutletSheet extends StatelessWidget {
  final int locationId;
  const OutletSheet({super.key, required this.locationId});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final st = sim.state;
    final l = st.locationById(locationId);
    if (l == null || l.closedForGood) {
      return const SizedBox(height: 120, child: Center(child: Text('Gone.')));
    }
    final m = l.manager;
    final p = l.policies;
    final canAct = st.phase != 'service';
    final est = sim.saleEstimate();
    final weeks = l.weeks.reversed.take(8).toList().reversed.toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(l.name, style: Theme.of(context).textTheme.titleLarge),
            Text(
                '${formatLabels[l.format]} · ${cuisines[l.themeId]?.$1 ?? l.themeId}',
                style: const TextStyle(color: Palette.muted)),
            const SectionTitle('Contribution per week'),
            SizedBox(
                height: 90,
                child: CustomPaint(
                    painter: _Bars([for (final w in weeks) w.operatingProfit]),
                    size: Size.infinite)),
            Text(
                'Invested ${fmtMoney(l.invested)} · earned back ${fmtMoney(l.returned)}',
                style: const TextStyle(color: Palette.muted)),
            if (l.managerCostWeek > 0 ||
                l.managerSaveWeek > 0 ||
                l.managerNotes.isNotEmpty) ...[
              const SectionTitle('Manager\'s decisions this week'),
              Text(
                  'Cost about ${fmtMoney(l.managerCostWeek)} · saved about ${fmtMoney(l.managerSaveWeek)}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              for (final n in l.managerNotes.reversed.take(5))
                Text('• $n', style: const TextStyle(color: Palette.muted)),
            ],
            const SectionTitle('Manager'),
            if (m == null)
              Text(
                  st.ownerLocationId == l.id
                      ? 'You run it yourself today. Hire a manager on the Expand page so it can open without you.'
                      : 'No manager: it cannot open unless you are there.',
                  style: const TextStyle(color: Palette.warn))
            else
              ManagerCard(m: m),
            if (m != null && canAct) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Expanded(child: Text('Profit bonus')),
                IconButton(
                    onPressed: () =>
                        sendCmd(context, SetManagerBonus(m.bonusPct - 1)),
                    icon: const Icon(Icons.remove_circle_outline)),
                Text('${m.bonusPct}%',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                IconButton(
                    onPressed: () =>
                        sendCmd(context, SetManagerBonus(m.bonusPct + 1)),
                    icon: const Icon(Icons.add_circle_outline)),
              ]),
            ],
            const SectionTitle('Standing orders'),
            const TermText('What the manager may do without asking', 'policy',
                style: TextStyle(color: Palette.muted)),
            const SizedBox(height: 6),
            Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const SizedBox(width: 120, child: Text('Spending limit')),
                  for (final v in [250, 500, 1500, 3000])
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: ChoiceChip(
                          label: Text(fmtMoney(v)),
                          selected: p.spendingLimit == v,
                          onSelected: canAct
                              ? (_) => sendCmd(
                                  context, SetPolicies(spendingLimit: v))
                              : null),
                    ),
                ]),
            const SizedBox(height: 6),
            Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const SizedBox(width: 120, child: Text('In a situation')),
                  for (final s in ['frugal', 'balanced', 'quality'])
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: ChoiceChip(
                          label: Text(s),
                          selected: p.stance == s,
                          onSelected: canAct
                              ? (_) => sendCmd(context, SetPolicies(stance: s))
                              : null),
                    ),
                ]),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('May hire staff'),
                value: p.mayHire,
                onChanged: canAct
                    ? (v) => sendCmd(context, SetPolicies(mayHire: v))
                    : null),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('May give raises'),
                value: p.mayGiveRaises,
                onChanged: canAct
                    ? (v) => sendCmd(context, SetPolicies(mayGiveRaises: v))
                    : null),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Orders stock every day'),
                value: p.autoOrder,
                onChanged: canAct
                    ? (v) => sendCmd(context, SetPolicies(autoOrder: v))
                    : null),
            if (st.perks.contains('delivery_unlocked') ||
                l.format == 'officeDistrict')
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Takeaway and delivery'),
                subtitle: const Text(
                    'More orders, 20% to the platform, 0.5 per dish packaging; the kitchen is shared'),
                value: l.deliveryOn,
                onChanged:
                    canAct ? (v) => sendCmd(context, SetDelivery(v)) : null,
              ),
            const SectionTitle('Grow it'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                onPressed: canAct
                    ? () => sendCmd(context, const Renovate(2),
                        okText:
                            'Two more tables. Closed for a day while the builders work.')
                    : null,
                icon: const Icon(Icons.chair),
                label: const Text('Add 2 tables · 3,000'),
              ),
              OutlinedButton.icon(
                onPressed: canAct
                    ? () {
                        final r = c.send(const Audit());
                        c.takeToast();
                        showToast(
                            context,
                            r.ok
                                ? (r.value as String)
                                : (r.message ?? 'Not possible'),
                            bad: !r.ok);
                      }
                    : null,
                icon: const Icon(Icons.manage_search),
                label: const Text('Audit the till · 500'),
              ),
            ]),
            const SectionTitle('Sell or close'),
            Text(
                'It would sell for about ${fmtMoney(est)} today${l.crisis ? ' (a distress sale)' : ''}.'),
            const SizedBox(height: 6),
            if (l.listedDay >= 0) ...[
              Text(
                  'Listed for sale since day ${l.listedDay + 1}. ${l.saleOffers.isEmpty ? 'No offers yet.' : ''}',
                  style: const TextStyle(color: Palette.muted)),
              for (var i = 0; i < l.saleOffers.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Offer: ${fmtMoney(l.saleOffers[i].amount)}'),
                  subtitle:
                      Text('valid until day ${l.saleOffers[i].expiresDay + 1}'),
                  trailing: FilledButton(
                      onPressed: canAct
                          ? () => _confirmThen(
                              context,
                              'Sell ${l.name}?',
                              'For ${fmtMoney(l.saleOffers[i].amount)}.',
                              AcceptSaleOffer(i))
                          : null,
                      child: const Text('Accept')),
                ),
            ],
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton(
                  onPressed: canAct
                      ? () => sendCmd(context, ListOutlet(l.listedDay < 0))
                      : null,
                  child: Text(l.listedDay < 0
                      ? 'List for sale'
                      : 'Take off the market')),
              OutlinedButton(
                onPressed: canAct
                    ? () => _confirmThen(
                        context,
                        'Quick sale?',
                        'You get ${fmtMoney((est * 0.7).round())} now (30% under the estimate).',
                        const QuickSale())
                    : null,
                child: Text('Quick sale ${fmtMoney((est * 0.7).round())}'),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Palette.bad),
                onPressed: canAct
                    ? () => _confirmThen(
                        context,
                        'Close ${l.name} for good?',
                        'Equipment is sold, staff get a week\'s pay, and you pay 4 weeks\' rent to end the lease.',
                        const CloseOutlet())
                    : null,
                child: const Text('Close it'),
              ),
            ]),
            if (l.story.isNotEmpty) ...[
              const SectionTitle('Its story'),
              for (final e in l.story.reversed.take(12))
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
            ],
          ]),
    );
  }

  Future<void> _confirmThen(
      BuildContext context, String title, String body, Command cmd) async {
    final ok = await confirm(context, title, body);
    if (ok && context.mounted) {
      if (sendCmd(context, cmd, okText: 'Done.') && context.mounted) {
        Navigator.pop(context);
      }
    }
  }
}

class _Bars extends CustomPainter {
  final List<int> values;
  _Bars(this.values);
  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) {
      final tp = TextPainter(
          text: const TextSpan(
              text: 'No full week yet', style: TextStyle(color: Palette.muted)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(0, size.height / 2 - 8));
      return;
    }
    final maxAbs = values
        .map((v) => v.abs())
        .reduce(math.max)
        .toDouble()
        .clamp(1, double.infinity);
    final mid = size.height / 2;
    final w = size.width / values.length;
    canvas.drawLine(
        Offset(0, mid), Offset(size.width, mid), Paint()..color = Palette.line);
    for (var i = 0; i < values.length; i++) {
      final h = values[i] / maxAbs * (mid - 4);
      final r = Rect.fromLTRB(i * w + 4, h >= 0 ? mid - h : mid,
          (i + 1) * w - 4, h >= 0 ? mid : mid - h);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)),
          Paint()..color = values[i] >= 0 ? Palette.ok : Palette.bad);
    }
  }

  @override
  bool shouldRepaint(_Bars old) => true;
}

class ManagerCard extends StatelessWidget {
  final Staff m;
  final Widget? trailing;
  const ManagerCard({super.key, required this.m, this.trailing});
  @override
  Widget build(BuildContext context) {
    final known = m.daysWorked >= 28 || m.hiredDay < 0;
    Widget bar(String name, double v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            SizedBox(
                width: 60,
                child: Text(name, style: const TextStyle(fontSize: 12.5))),
            Expanded(child: StatBar(v / 100, color: Palette.staff, height: 7)),
            const SizedBox(width: 8),
            SizedBox(
              width: 52,
              child: Text(
                  known
                      ? '${v.round()}'
                      : '${(v - 15).clamp(0, 100).round()}–${(v + 15).clamp(0, 100).round()}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ]),
        );
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          StaffAvatar(seed: m.id, name: m.name, role: 'manager', size: 44),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              Wrap(children: [
                const TermText('Grade', 'manager_grade',
                    style: TextStyle(color: Palette.muted, fontSize: 12)),
                Text(' ${m.grade}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 12.5)),
              ]),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Money(m.wage, size: 13),
            Text('/day${m.bonusPct > 0 ? ' + ${m.bonusPct}% of profit' : ''}',
                style: const TextStyle(color: Palette.muted, fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 8),
        bar('People', m.people),
        bar('Upkeep', m.upkeep),
        bar('Stock', m.stockSkill),
        if (!known)
          const Text('Exact skills known after 4 weeks in post.',
              style: TextStyle(color: Palette.muted, fontSize: 11.5)),
        if (trailing != null)
          Align(alignment: Alignment.centerRight, child: trailing!),
      ]),
    );
  }
}

/// Opening the next outlet: buy a running one or build from scratch (doc 07 §4.11).
class ExpandPage extends StatefulWidget {
  const ExpandPage({super.key});
  @override
  State<ExpandPage> createState() => _ExpandPageState();
}

class _ExpandPageState extends State<ExpandPage> {
  String cuisine = '';

  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final st = sim.state;
    if (cuisine.isEmpty) cuisine = st.themeId;
    if (st.stage < 3) {
      return const Centered(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock, size: 40, color: Palette.muted),
            SizedBox(height: 10),
            Text('More outlets unlock at Stage 3',
                style: TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text(
                '60,000 in cash, a 4.0 rating and no missed loan payment for 8 weeks.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Palette.muted)),
          ]),
        ),
      );
    }
    final canAct = st.phase != 'service';
    final otherBrand = cuisine != st.themeId;
    return Centered(
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (st.stage >= 5) ...[
              const SectionTitle('Brand for the next outlet'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in cuisines.entries)
                  ChoiceChip(
                      label: Text(t.value.$1),
                      avatar: Icon(t.value.$2, size: 18),
                      selected: cuisine == t.key,
                      onSelected: (_) => setState(() => cuisine = t.key)),
              ]),
            ],
            const SectionTitle('Managers looking for work'),
            const Text(
                'A manager runs an outlet on the days you are not there. Better grades make fewer mistakes and cost more.',
                style: TextStyle(color: Palette.muted)),
            const SizedBox(height: 8),
            for (final m in st.managerApplicants)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ManagerCard(
                  m: m,
                  trailing: FilledButton(
                    onPressed: canAct
                        ? () => sendCmd(context, HireManager(m.id),
                            okText: '${m.name} now manages ${st.viewLoc.name}.')
                        : null,
                    child: const Text('Hire'),
                  ),
                ),
              ),
            Text(
                'Hiring puts them in charge of the outlet you are viewing: ${st.viewLoc.name}.',
                style: const TextStyle(color: Palette.muted, fontSize: 12.5)),
            const SectionTitle('Buy a running restaurant'),
            const Text(
                'Staff, customers and hidden problems included. It trades from tomorrow.',
                style: TextStyle(color: Palette.muted)),
            const SizedBox(height: 8),
            for (var i = 0; i < st.outletMarket.length; i++)
              _MarketCard(index: i, cuisine: otherBrand ? cuisine : null),
            const SectionTitle('Build from scratch'),
            const Text(
                'Cheaper, your own choices, nothing hidden — but rent starts today, it opens after the fit-out, and nobody knows it yet.',
                style: TextStyle(color: Palette.muted)),
            const SizedBox(height: 8),
            for (final s in st.sites) _SiteCard(site: s, cuisine: cuisine),
            if (st.stage >= 4) ...[
              const SectionTitle('Chain'),
              Panel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Central kitchen',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const Text(
                          'Prep made in one place and trucked out: cooking is 30% faster everywhere and needs less skill. 40,000 to build, 3,000 a week to run.'),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonal(
                            onPressed: canAct && !st.centralKitchen
                                ? () => sendCmd(
                                    context, const BuildCentralKitchen(),
                                    okText: 'Central kitchen built.')
                                : null,
                            child: Text(st.centralKitchen ? 'Built' : 'Build')),
                      ),
                      const Divider(),
                      const Text('Bulk contract',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const Text(
                          'Buy for every outlet at once: 5% off all ingredients for 26 weeks. 5,000 to sign.'),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonal(
                          onPressed: canAct &&
                                  st.bulkContractUntil <= st.dayIndex
                              ? () => sendCmd(context, const SignBulkContract(),
                                  okText: 'Signed.')
                              : null,
                          child: Text(st.bulkContractUntil > st.dayIndex
                              ? 'Running until day ${st.bulkContractUntil + 1}'
                              : 'Sign'),
                        ),
                      ),
                    ]),
              ),
            ],
            if (st.stage >= 5) ...[
              const SectionTitle('Group'),
              Panel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Franchising',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      Text(
                          'Sell the right to copy your restaurant: 25,000 now and 600 a week, but a bad franchisee can embarrass every outlet. You have ${st.franchises}.'),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonal(
                            onPressed: canAct
                                ? () => sendCmd(context, const StartFranchise(),
                                    okText: 'Franchise sold.')
                                : null,
                            child: const Text('Sell a franchise')),
                      ),
                    ]),
              ),
            ],
          ]),
    );
  }
}

class _MarketCard extends StatelessWidget {
  final int index;
  final String? cuisine;
  const _MarketCard({required this.index, this.cuisine});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final st = c.state!;
    final o = st.outletMarket[index];
    final l = o.location;
    final tier = c.content.tier(o.tierId);
    final known = l.hidden.where((h) => h.revealed).length;
    final canAct = st.phase != 'service';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(l.name,
                    style: const TextStyle(fontWeight: FontWeight.w800))),
            Pill(tier.name, color: tierColors[o.tierId]!),
          ]),
          Text(
              '${formatLabels[l.format]} · ${c.content.locationClasses[l.classId]!.name} location · rent ${fmtMoney(l.rentWeekly)}/wk · ${l.staff.length} staff · ${l.reputation.toStringAsFixed(1)} stars',
              style: const TextStyle(color: Palette.muted, fontSize: 12.5)),
          Text(formatBlurbs[l.format]!, style: const TextStyle(fontSize: 12.5)),
          const SizedBox(height: 6),
          Row(children: [
            Money(o.price, size: 16),
            const SizedBox(width: 10),
            Expanded(
                child: Text(
                    o.inspected ? 'Known issues: $known' : 'Known issues: ?',
                    style: const TextStyle(color: Palette.muted))),
          ]),
          Wrap(alignment: WrapAlignment.end, spacing: 6, children: [
            if (!o.inspected)
              TextButton(
                  onPressed: canAct
                      ? () => sendCmd(context, InspectOutlet(index))
                      : null,
                  child: const Text('Inspect 2,000')),
            FilledButton(
              onPressed: canAct
                  ? () async {
                      final ok = await confirm(context, 'Buy ${l.name}?',
                          'Pay ${fmtMoney(o.price)} from company cash. It needs a manager for the days you are not there.');
                      if (ok && context.mounted) {
                        sendCmd(context, BuyOutlet(index, themeId: cuisine),
                            okText: '${l.name} is yours.');
                      }
                    }
                  : null,
              child: const Text('Buy'),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _SiteCard extends StatefulWidget {
  final Site site;
  final String cuisine;
  const _SiteCard({required this.site, required this.cuisine});
  @override
  State<_SiteCard> createState() => _SiteCardState();
}

class _SiteCardState extends State<_SiteCard> {
  String size = 'medium';
  String fit = 'standard';
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final s = widget.site;
    final cost = sim.buildCost(s, size, fit, widget.cuisine);
    final upFront = cost['fitOut']! +
        cost['equipment']! +
        cost['deposit']! +
        cost['licence']!;
    final canAct = sim.state.phase != 'service';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(
              '${formatLabels[s.format]} · ${c.content.locationClasses[s.classId]!.name} location',
              style: const TextStyle(color: Palette.muted, fontSize: 12.5)),
          Text(formatBlurbs[s.format]!, style: const TextStyle(fontSize: 12.5)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final z in ['small', 'medium', 'large'])
              ChoiceChip(
                  label: Text(z),
                  selected: size == z,
                  onSelected: (_) => setState(() => size = z)),
          ]),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final f in ['basic', 'standard', 'premium'])
              ChoiceChip(
                  label: Text('$f fit-out'),
                  selected: fit == f,
                  onSelected: (_) => setState(() => fit = f)),
          ]),
          const SizedBox(height: 6),
          Text(
              'Fit-out ${fmtMoney(cost['fitOut']!)} · equipment ${fmtMoney(cost['equipment']!)} · deposit ${fmtMoney(cost['deposit']!)} · licence ${fmtMoney(cost['licence']!)}',
              style: const TextStyle(fontSize: 12.5)),
          Text(
              'Rent ${fmtMoney(cost['rent']!)} a week from today · opens in ${cost['days']} days',
              style: const TextStyle(color: Palette.muted, fontSize: 12.5)),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: canAct
                  ? () async {
                      final ok = await confirm(context, 'Build ${s.name}?',
                          'Pay ${fmtMoney(upFront)} now. Rent is due every week from today.');
                      if (ok && context.mounted) {
                        sendCmd(
                            context,
                            BuildOutlet(s.id, size, fit,
                                themeId: widget.cuisine == sim.state.themeId
                                    ? null
                                    : widget.cuisine),
                            okText: 'Work has started.');
                      }
                    }
                  : null,
              child: Text('Build · ${fmtMoney(upFront)}'),
            ),
          ),
        ]),
      ),
    );
  }
}

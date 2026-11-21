import 'package:flutter/material.dart';
import 'package:sim_core/sim_core.dart';

import '../theme.dart';
import '../widgets/common.dart';
import '../scene/pictures.dart';
import '../scene/shopfront.dart';
import 'misc_screens.dart';

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});
  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  Map<String, dynamic>? _auto;

  @override
  void initState() {
    super.initState();
    GameScope.read(context).saves.read('autosave').then((v) {
      if (mounted) setState(() => _auto = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    String? autoLine;
    final a = _auto;
    if (a != null) {
      try {
        final st = (a['state'] as Map).cast<String, dynamic>();
        final loc = ((st['locations'] as List).first as Map)['name'];
        autoLine = '$loc · Day ${(st['dayIndex'] as num).toInt() + 1}';
      } catch (_) {}
    }
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: IntrinsicHeight(
                child: Centered(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(children: [
                      const Spacer(flex: 2),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: const Shopfront(
                            name: 'Kitchen Chain',
                            accent: Palette.accent,
                            quality: 3,
                            animate: true,
                            height: 210,
                            seed: 3),
                      ),
                      const SizedBox(height: 18),
                      Text('Kitchen Chain',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1)),
                      const SizedBox(height: 8),
                      const Text(
                        'You bought a running restaurant — staff, debts and problems included.\nKeep it alive. Then make it great.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Palette.muted, fontSize: 15, height: 1.4),
                      ),
                      const Spacer(flex: 3),
                      if (autoLine != null) ...[
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(56)),
                          onPressed: () async {
                            final ok = await c.load('autosave');
                            if (!ok && context.mounted) {
                              showToast(
                                  context, 'That save could not be loaded.');
                            }
                          },
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text('Continue  ·  $autoLine'),
                        ),
                        const SizedBox(height: 10),
                      ],
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56)),
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const NewGameScreen())),
                        icon: const Icon(Icons.add_business),
                        label: const Text('New game'),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => showLoadSheet(context),
                            icon: const Icon(Icons.folder_open),
                            label: const Text('Load'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const HandbookScreen())),
                            icon: const Icon(Icons.menu_book),
                            label: const Text('Handbook'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.outlined(
                          tooltip: 'Settings',
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SettingsScreen())),
                          icon: const Icon(Icons.settings),
                        ),
                      ]),
                      const SizedBox(height: 24),
                      const Text('Offline · no ads · no accounts',
                          style: TextStyle(color: Palette.muted, fontSize: 12)),
                      const SizedBox(height: 12),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NewGameScreen extends StatefulWidget {
  const NewGameScreen({super.key});
  @override
  State<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends State<NewGameScreen> {
  String diff = 'normal';
  String cuisine = 'italian';
  final seedCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    Widget diffCard(String id, String title, String body, IconData icon) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(
            onTap: () => setState(() => diff = id),
            borderColor: diff == id ? Palette.accent : Palette.line,
            color: diff == id ? Palette.accentSoft : Palette.surface,
            child: Row(children: [
              Icon(icon, color: Palette.accent, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(body, style: const TextStyle(color: Palette.muted)),
                    ]),
              ),
              Icon(
                  diff == id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: Palette.accent),
            ]),
          ),
        );
    return Scaffold(
      appBar:
          AppBar(title: const Text('New game'), backgroundColor: Palette.bg),
      body: Centered(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const SectionTitle('Difficulty'),
          diffCard(
              'easy',
              'Easy',
              'Cheaper loans, fewer surprises, patient customers.',
              Icons.sentiment_satisfied_alt),
          diffCard('normal', 'Normal',
              'The way the game is meant to be played.', Icons.restaurant),
          diffCard(
              'hard',
              'Hard',
              'Expensive loans, more trouble, impatient customers, staff who walk out.',
              Icons.whatshot),
          const SectionTitle('Cuisine'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in cuisines.entries)
              ChoiceChip(
                label: Text(t.value.$1),
                avatar: Icon(t.value.$2, size: 18),
                selected: cuisine == t.key,
                onSelected: (_) => setState(() => cuisine = t.key),
              ),
          ]),
          const SizedBox(height: 8),
          Text(cuisines[cuisine]!.$3,
              style: const TextStyle(color: Palette.muted, height: 1.35)),
          const SectionTitle('Seed (optional)'),
          TextField(
            controller: seedCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Leave empty for a random start',
              border: OutlineInputBorder(),
              helperText:
                  'The same seed always gives the same restaurants for sale.',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: () {
              final seed = int.tryParse(seedCtrl.text) ??
                  (DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF);
              c.newGame(seed: seed, difficulty: diff, themeId: cuisine);
              Navigator.popUntil(context, (r) => r.isFirst);
            },
            icon: const Icon(Icons.storefront),
            label: const Text('See restaurants for sale'),
          ),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ market

const tierColors = {
  'excellent': Color(0xFF2F7D4F),
  'best': Color(0xFF3A6EA8),
  'good': Color(0xFF8A6A3B),
  'bad': Color(0xFFC98A1B),
  'worst': Color(0xFFC24A3A),
};

class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final st = c.state!;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.bg,
        title: const Text('Restaurants for sale'),
        leading:
            IconButton(icon: const Icon(Icons.close), onPressed: c.quitToTitle),
        actions: [
          Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Money(st.cash, size: 17))
        ],
      ),
      body: Centered(
        child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              const Text(
                'You have 100,000 coins. Anything above that is borrowed from the bank. Cheap places come with cheap problems.',
                style: TextStyle(color: Palette.muted, height: 1.4),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < st.offers.length; i++)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OfferCard(index: i)),
            ]),
      ),
    );
  }
}

int estWeeklyRevenue(Content content, Offer o) {
  final cls = content.locationClasses[o.location.classId]!;
  // Average week: footfall × rating, less the usual ~10% who walk out, ~55 coins a party.
  final groups = cls.baseFootfall *
      (0.25 + 0.25 * o.location.reputation).clamp(0.4, 1.5) *
      1.06 *
      0.9;
  return (groups * 7 * 55).round();
}

class OfferCard extends StatelessWidget {
  final int index;
  const OfferCard({super.key, required this.index});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final o = c.state!.offers[index];
    final l = o.location;
    final tier = c.content.tier(o.tierId);
    final cls = c.content.locationClasses[l.classId]!;
    final avgCond =
        l.equipment.fold(0.0, (a, e) => a + e.condition) / l.equipment.length;
    final known = l.hidden.where((h) => h.revealed).length;
    final color = tierColors[o.tierId]!;
    final cashLeft = c.state!.cash - o.price + o.loan;
    return Panel(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => OfferDetail(index: index))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Shopfront(
            name: l.name,
            accent: accentOf(c.content.themes[c.state!.themeId]?.accent),
            quality: tierQuality(o.tierId),
            height: 104,
            seed: index + 1),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.04)
          ])),
          child: Row(children: [
            Icon(Icons.storefront, color: color),
            const SizedBox(width: 10),
            Expanded(
                child: Text(l.name,
                    style: Theme.of(context).textTheme.titleMedium)),
            Pill(tier.name, color: color),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: _kv('Price', Money(o.price, size: 16))),
              Expanded(child: _kv('Loan needed', Money(o.loan, size: 16))),
              Expanded(child: _kv('Cash left', Money(cashLeft, size: 16))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _kv(
                      'Rating',
                      Row(children: [
                        Stars(l.reputation),
                        const SizedBox(width: 4),
                        Text(l.reputation.toStringAsFixed(1))
                      ]))),
              Expanded(
                  child: _kv(
                      'Staff',
                      Text('${l.staff.length} people',
                          style:
                              const TextStyle(fontWeight: FontWeight.w700)))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _kv(
                      'Location',
                      Text('${cls.name} · rent ${fmtMoney(l.rentWeekly)}/wk',
                          style:
                              const TextStyle(fontWeight: FontWeight.w700)))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              const Text('Equipment ',
                  style: TextStyle(color: Palette.muted, fontSize: 12)),
              Expanded(child: StatBar(avgCond / 100)),
              const SizedBox(width: 8),
              Text('${avgCond.round()}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Icon(o.inspected ? Icons.search : Icons.help_outline,
                  size: 18,
                  color: l.hidden.isEmpty && o.inspected
                      ? Palette.ok
                      : Palette.warn),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  o.inspected
                      ? 'Known issues: $known found (${l.hidden.length - known > 0 ? 'maybe more' : 'none hidden'})'
                      : 'Known issues: ?',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (!o.inspected)
                TextButton(
                  onPressed: () => sendCmd(context, BuyDueDiligence(index),
                      okText: 'Inspection done. See the details.'),
                  child: const Text('Inspect · 2,000'),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _kv(String k, Widget v) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: const TextStyle(color: Palette.muted, fontSize: 12)),
        const SizedBox(height: 2),
        v,
      ]);
}

class OfferDetail extends StatelessWidget {
  final int index;
  const OfferDetail({super.key, required this.index});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    if (c.state == null || c.state!.phase != 'market') return const SizedBox();
    final o = c.state!.offers[index];
    final l = o.location;
    final tier = c.content.tier(o.tierId);
    final rev = estWeeklyRevenue(c.content, o);
    final wages = l.staff.fold<int>(0, (a, s) => a + s.wage * 6);
    return Scaffold(
      appBar: AppBar(backgroundColor: Palette.bg, title: Text(l.name)),
      body: Centered(
        child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            children: [
              Row(children: [
                Pill('${tier.name} tier', color: tierColors[o.tierId]!),
                const SizedBox(width: 8),
                Pill('${l.tableSeats.length} tables',
                    icon: Icons.table_restaurant),
              ]),
              const SectionTitle('Last owner\'s typical week (estimate)'),
              Panel(
                child: Column(children: [
                  _row('Sales', rev),
                  _row('Ingredients (~33%)', -(rev * 0.33).round()),
                  _row('Wages', -wages),
                  _row('Rent', -l.rentWeekly),
                  _row('Utilities, repairs, other', -(rev * 0.10).round()),
                  const Divider(height: 18),
                  _row('Profit before loan',
                      (rev * 0.57).round() - wages - l.rentWeekly,
                      bold: true),
                  if (o.loan > 0)
                    _row('Loan payment (first week)',
                        -(o.loan / 52 + o.loan * 0.004).round()),
                  const SizedBox(height: 6),
                  const Text(
                      'Your first month will be quieter: about a third of the regulars wait to see how the new owner does.',
                      style: TextStyle(color: Palette.muted, fontSize: 12.5)),
                ]),
              ),
              const SectionTitle('Known issues'),
              if (!o.inspected)
                Panel(
                  child: Row(children: [
                    const Icon(Icons.search, color: Palette.warn),
                    const SizedBox(width: 10),
                    const Expanded(
                        child: TermText(
                            'Pay to inspect before buying', 'due_diligence')),
                    FilledButton.tonal(
                        onPressed: () =>
                            sendCmd(context, BuyDueDiligence(index)),
                        child: const Text('2,000')),
                  ]),
                )
              else if (l.hidden.where((h) => h.revealed).isEmpty)
                const EmptyNote('The inspection found nothing.')
              else
                for (final h in l.hidden.where((h) => h.revealed))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Panel(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Palette.warn),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_hiddenText(h.kind))),
                      ]),
                    ),
                  ),
              const SectionTitle('Staff'),
              for (final s in l.staff)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: StaffAvatar(
                      seed: s.id,
                      role: s.role,
                      size: 40,
                      mood: moodFromMorale(s.morale)),
                  title: Text(s.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      '${_role(s.role)} · skill ${(s.skill - 15).clamp(0, 100).round()}–${(s.skill + 15).clamp(0, 100).round()}'),
                  trailing: Money(s.wage, size: 13),
                ),
              const SectionTitle('Equipment'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in l.equipment)
                  Chip(
                    avatar: Icon(AssetCatalog.equipment(e.type), size: 16),
                    label: Text(
                        '${c.content.equipment[e.type]!.name} ${e.broken ? '· broken' : e.condition.round()}'),
                    backgroundColor:
                        e.broken ? Palette.bad.withValues(alpha: 0.1) : null,
                  ),
              ]),
            ]),
      ),
      bottomSheet: SafeArea(
        child: Container(
          color: Palette.surface,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Centered(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56)),
              onPressed: () async {
                final ok = await confirm(context, 'Buy ${l.name}?',
                    'Price ${fmtMoney(o.price)}${o.loan > 0 ? ', of which ${fmtMoney(o.loan)} is a bank loan you repay weekly' : ''}. You keep ${fmtMoney(c.state!.cash - o.price + o.loan)} in cash.',
                    ok: 'Buy it');
                if (ok && context.mounted) {
                  sendCmd(context, BuyRestaurant(index));
                  Navigator.popUntil(context, (r) => r.isFirst);
                }
              },
              icon: const Icon(Icons.key),
              label: Text('Buy for ${fmtMoney(o.price)}'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String k, int v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
              child: Text(k,
                  style: TextStyle(
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w500))),
          Money(v, size: bold ? 16 : 14, sign: true),
        ]),
      );
}

String _role(String r) =>
    const {
      'headChef': 'Head chef',
      'lineCook': 'Line cook',
      'prepCook': 'Prep cook',
      'dishwasher': 'Dishwasher',
      'server': 'Server',
      'cashier': 'Cashier',
      'cleaner': 'Cleaner',
    }[r] ??
    r;

String _hiddenText(String k) =>
    const {
      'supplier_debt': 'Unpaid bill to a supplier — you will have to pay it',
      'health_violation': 'A health violation is about to be reported',
      'chef_leaving': 'The head chef is planning to quit',
      'pests': 'Pests are moving in',
      'fridge_failing': 'The fridge is about to fail',
      'cashier_skimming': 'The cashier takes money from the till',
      'lease_increase': 'The landlord will raise the rent',
      'overdue_licence': 'The trading licence is overdue',
      'staff_feud': 'Two staff members are feuding',
      'fake_reviews': 'Fake good reviews are about to be removed',
    }[k] ??
    k;

/// Cuisine id → (name, icon, one-line description).
const cuisines = <String, (String, IconData, String)>{
  'italian': (
    'Italian',
    Icons.local_pizza,
    'Pizza and pasta. Two ovens carry most of the menu.'
  ),
  'chinese': (
    'Chinese',
    Icons.ramen_dining,
    'Wok cooking: quick, cheap dishes. You need more customers, or slightly higher prices, to pay the same bills.'
  ),
  'mexican': (
    'Mexican',
    Icons.lunch_dining,
    'Tacos and burritos off the grill; the fryer is busy too.'
  ),
  'indian': (
    'Indian',
    Icons.rice_bowl,
    'Curries on the hob, breads in the tandoor. Spicy, skilled cooking.'
  ),
  'mixed': (
    'Mixed',
    Icons.public,
    'A bit of everything: 10% more customers, but more stock, more machines and cooks 10% slower.'
  ),
};

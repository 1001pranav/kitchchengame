import 'package:flutter/material.dart';
import 'package:sim_core/sim_core.dart';

import '../../state/game_controller.dart';
import '../screens/chain_screens.dart';
import '../screens/close_report.dart';
import '../screens/kitchen_tab.dart';
import '../screens/misc_screens.dart';
import '../screens/money_tab.dart';
import '../screens/prep_board.dart';
import '../screens/service_view.dart';
import '../screens/staff_tab.dart';
import '../screens/stock_tab.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'incident_card.dart';
import 'notices.dart';

/// Lets any screen switch the bottom tab (deep links from attention lines and reports).
class ShellNav extends InheritedWidget {
  final void Function(int tab) go;
  const ShellNav({super.key, required this.go, required super.child});
  static void to(BuildContext context, int tab) =>
      context.getInheritedWidgetOfExactType<ShellNav>()?.go(tab);
  @override
  bool updateShouldNotify(ShellNav old) => false;
}

class GameShell extends StatefulWidget {
  const GameShell({super.key});
  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  int tab = 0;
  final Set<int> deferred = {};
  bool showingCard = false;
  bool showingNotices = false;
  late GameController c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    c = GameScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => _overlays());
  }

  void _overlays() {
    if (!mounted || showingCard || showingNotices) return;
    final st = c.state;
    if (st == null || st.phase == 'gameOver') return;
    final toast = c.takeToast();
    if (toast != null) showToast(context, toast);
    // Notices first thing in the morning (and after a purchase).
    if (st.phase == 'prep' && st.pendingNotices.isNotEmpty) {
      showingNotices = true;
      showNotices(context).then((_) {
        showingNotices = false;
        _overlays();
      });
      return;
    }
    if (st.flag('ending_unlocked') && !st.ended && st.phase == 'prep') {
      showingNotices = true;
      showEnding(context).then((_) {
        showingNotices = false;
        _overlays();
      });
      return;
    }
    final open =
        st.openIncidents.where((i) => !deferred.contains(i.id)).toList();
    if (open.isEmpty) return;
    final inst = open.first;
    showingCard = true;
    final wasSpeed = c.speed;
    c.cardOpen = true;
    showIncidentCard(context, inst).then((decided) {
      c.cardOpen = false;
      showingCard = false;
      if (decided != true) deferred.add(inst.id);
      if (c.state?.phase == 'service' && wasSpeed == Speed.paused) {
        c.setSpeed(Speed.normal);
      }
      if (mounted) {
        setState(() {});
        _overlays();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = c.state!;
    if (st.phase == 'gameOver') return const GameOverScreen();
    final waitingCards = st.openIncidents.length;
    final pages = [
      const TodayTab(),
      const StaffTab(),
      const StockTab(),
      const KitchenTab(),
      const MoneyTab(),
    ];
    final loc = st.viewLoc;
    final staffBadge =
        loc.staff.where((s) => s.morale < 30 || s.status == 'notice').length;
    final stockBadge = c.sim!.runOutRisks().length;
    final kitchenBadge = loc.equipment.where((e) => e.broken).length;
    return ShellNav(
      go: (t) => setState(() => tab = t),
      child: Scaffold(
        body: Column(children: [
          const TopBar(),
          const LocationStrip(),
          if (tab == 0) const AwayBanner(),
          if (waitingCards > 0 && !showingCard && deferred.isNotEmpty)
            Material(
              color: Palette.warn.withValues(alpha: 0.15),
              child: InkWell(
                onTap: () {
                  deferred.clear();
                  _overlays();
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    const Icon(Icons.notification_important,
                        color: Palette.warn),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$waitingCards situation${waitingCards > 1 ? 's' : ''} waiting for your decision'
                        '${st.phase == 'service' ? '' : ' — ignored ones take their default'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Text('Open',
                        style: TextStyle(
                            color: Palette.accent,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            ),
          Expanded(child: IndexedStack(index: tab, children: pages)),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          height: 66,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: [
            NavigationDestination(
              icon: Badge(
                  isLabelVisible: st.phase == 'service',
                  label: const Text('LIVE'),
                  backgroundColor: Palette.tomato,
                  child: const Icon(Icons.today)),
              label: 'Today',
            ),
            NavigationDestination(
                icon: Badge(
                    isLabelVisible: staffBadge > 0,
                    label: Text('$staffBadge'),
                    child: const Icon(Icons.groups)),
                label: 'Staff'),
            NavigationDestination(
                icon: Badge(
                    isLabelVisible: stockBadge > 0,
                    label: Text('$stockBadge'),
                    child: const Icon(Icons.inventory_2)),
                label: 'Stock'),
            NavigationDestination(
                icon: Badge(
                    isLabelVisible: kitchenBadge > 0,
                    label: Text('$kitchenBadge'),
                    child: const Icon(Icons.soup_kitchen)),
                label: 'Kitchen'),
            NavigationDestination(
                icon: Badge(
                    isLabelVisible: st.requests.isNotEmpty,
                    label: Text('${st.requests.length}'),
                    child: const Icon(Icons.account_balance_wallet)),
                label: st.stage >= 3 ? 'Company' : 'Money'),
          ],
        ),
      ),
    );
  }
}

class TopBar extends StatelessWidget {
  const TopBar({super.key});
  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final st = sim.state;
    final energy = st.owner.energy / 100;
    return Material(
      color: Palette.surface,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Palette.line))),
          padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Day ${st.dayIndex + 1} · ${weekdays[st.weekday]}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(
                        '${seasonName(st.season)} · Year ${st.year} · ${st.viewLoc.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Palette.muted, fontSize: 12)),
                  ]),
            ),
            Semantics(
              button: true,
              label: 'Cash ${fmtMoney(st.cash)}. Tap for why.',
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => showWhy(context, sim.explain('cash')),
                child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Money(st.cash, size: 16)),
              ),
            ),
            Semantics(
              button: true,
              label:
                  'Rating ${st.viewLoc.reputation.toStringAsFixed(1)} stars. Tap for why.',
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => showWhy(context, sim.explain('reputation')),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(children: [
                    const Icon(Icons.star_rounded,
                        color: Palette.gold, size: 20),
                    Text(st.viewLoc.reputation.toStringAsFixed(1),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                  ]),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'Your energy ${st.owner.energy.round()}',
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => showWhy(context, sim.explain('energy')),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.bolt,
                        size: 18,
                        color: energy < 0.2 ? Palette.bad : Palette.owner),
                    SizedBox(
                        width: 30,
                        child: StatBar(energy,
                            color: energy < 0.2 ? Palette.bad : Palette.owner,
                            height: 5)),
                  ]),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Menu',
              icon: const Icon(Icons.menu),
              onPressed: () => showPauseMenu(context),
            ),
          ]),
        ),
      ),
    );
  }
}

class TodayTab extends StatelessWidget {
  const TodayTab({super.key});
  @override
  Widget build(BuildContext context) {
    final st = GameScope.of(context).state!;
    return switch (st.phase) {
      'prep' => const PrepBoard(),
      'service' => const ServiceView(),
      _ => const CloseReport(),
    };
  }
}

/// Re-exported so screens can depend on one import.
typedef Cmd = Command;

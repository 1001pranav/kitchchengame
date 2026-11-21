import 'package:flutter/material.dart';
import 'package:sim_core/sim_core.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// The incident card (doc 07 §4.9). Resolves true when a choice was made.
Future<bool?> showIncidentCard(BuildContext context, IncidentInstance inst) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _IncidentSheet(inst: inst),
  );
}

class _IncidentSheet extends StatefulWidget {
  final IncidentInstance inst;
  const _IncidentSheet({required this.inst});
  @override
  State<_IncidentSheet> createState() => _IncidentSheetState();
}

class _IncidentSheetState extends State<_IncidentSheet> {
  String? result;

  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final sim = c.sim!;
    final def = c.content.incidents[widget.inst.incidentId]!;
    final color = AssetCatalog.categoryColor(def.category);
    final service = sim.state.phase == 'service';
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Centered(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                          colors: [color, color.withValues(alpha: 0.65)]),
                    ),
                    child: Stack(children: [
                      Positioned(
                          right: -10,
                          bottom: -18,
                          child: Icon(AssetCatalog.category(def.category),
                              size: 120,
                              color: Colors.white.withValues(alpha: 0.18))),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          Icon(AssetCatalog.category(def.category),
                              color: Colors.white, size: 34),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                                sim.state.openLocations.length > 1
                                    ? (widget.inst.locationId ==
                                                sim.state.ownerLocationId &&
                                            !sim.state.travelling
                                        ? 'SITUATION · ${sim.state.locationById(widget.inst.locationId)?.name ?? ''}'
                                        : 'CALL FROM ${(sim.state.locationById(widget.inst.locationId)?.name ?? '').toUpperCase()}')
                                    : 'SITUATION',
                                style: TextStyle(
                                    color: Colors.white70,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12)),
                          ),
                          if (service && widget.inst.countdown > 0)
                            Pill('${widget.inst.countdown} ticks left',
                                color: Colors.white, icon: Icons.timer),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Text(_cap(sim.incidentText(widget.inst, def.title)),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(sim.incidentText(widget.inst, def.text),
                      style: const TextStyle(fontSize: 16, height: 1.45)),
                  const SizedBox(height: 16),
                  if (result == null) ...[
                    for (final o in def.options) _option(context, sim, def, o),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(service
                          ? 'Decide later (the clock keeps running)'
                          : 'Decide later'),
                    ),
                  ] else ...[
                    Panel(
                      color: Palette.accentSoft,
                      borderColor: Palette.accentSoft,
                      child: Row(children: [
                        const Icon(Icons.check_circle, color: Palette.accent),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(result!,
                                style: const TextStyle(
                                    fontSize: 15, height: 1.4))),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52)),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('OK'),
                    ),
                  ],
                ]),
          ),
        ),
      ),
    );
  }

  Widget _option(
      BuildContext context, Sim sim, IncidentDef def, IncidentOption o) {
    final blocked = sim.optionBlocked(widget.inst, o);
    final cash = sim.optionCash(widget.inst, o);
    final odds = sim.optionOdds(o);
    final isDefault = o.id == def.defaultOption;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: blocked == null ? 1 : 0.5,
        child: Panel(
          onTap: blocked != null
              ? () => showToast(context, blocked)
              : () {
                  final r = GameScope.read(context)
                      .send(ResolveIncident(widget.inst.id, o.id));
                  if (r.ok) {
                    setState(() => result = (r.value as String?) ?? 'Done.');
                  } else {
                    showToast(context, r.message ?? 'Not possible.');
                  }
                },
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sim.incidentText(widget.inst, o.label),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      if (cash != 0)
                        Pill('${cash > 0 ? '+' : ''}${fmtMoney(cash)}',
                            color: cash < 0 ? Palette.bad : Palette.ok,
                            icon: Icons.paid),
                      if (odds != null)
                        Pill(odds,
                            color: odds == 'likely'
                                ? Palette.ok
                                : (odds == 'risky'
                                    ? Palette.bad
                                    : Palette.warn),
                            icon: Icons.casino),
                      if (isDefault)
                        const Pill('if ignored',
                            color: Palette.muted, icon: Icons.hourglass_bottom),
                      if (blocked != null)
                        Pill(blocked, color: Palette.bad, icon: Icons.block),
                    ]),
                  ]),
            ),
            const Icon(Icons.chevron_right, color: Palette.muted),
          ]),
        ),
      ),
    );
  }
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

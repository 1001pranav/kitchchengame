import 'package:flutter/material.dart';
import 'package:sim_core/sim_core.dart';

import '../../state/game_controller.dart';
import '../theme.dart';

/// Inherited access to the controller without a state-management package.
class GameScope extends InheritedNotifier<GameController> {
  const GameScope(
      {super.key, required GameController controller, required super.child})
      : super(notifier: controller);

  static GameController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GameScope>()!.notifier!;

  static GameController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<GameScope>()!.notifier!;
}

String fmtMoney(num v, {bool sign = false}) {
  final n = v.round();
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  final prefix = n < 0 ? '−' : (sign && n > 0 ? '+' : '');
  return '$prefix$buf';
}

/// Money with a coin icon; negatives in red with a minus sign (doc 07 §2).
class Money extends StatelessWidget {
  final num value;
  final double size;
  final bool sign;
  final FontWeight weight;
  final Color? color;
  const Money(this.value,
      {super.key,
      this.size = 15,
      this.sign = false,
      this.weight = FontWeight.w700,
      this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? (value < 0 ? Palette.bad : Palette.ink);
    return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: size * 0.95,
            height: size * 0.95,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                  colors: [Color(0xFFF7D774), Color(0xFFD9A21E)]),
              border: Border.all(color: const Color(0xFFB7851A), width: 1),
            ),
            alignment: Alignment.center,
            child: Text('c',
                style: TextStyle(
                    fontSize: size * 0.55,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF7A5510),
                    height: 1)),
          ),
          SizedBox(width: size * 0.3),
          Text(fmtMoney(value, sign: sign),
              style: TextStyle(
                  fontSize: size,
                  fontWeight: weight,
                  color: c,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ]));
  }
}

class Stars extends StatelessWidget {
  final double value;
  final double size;
  const Stars(this.value, {super.key, this.size = 14});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < 5; i++)
        Icon(
          value >= i + 0.75
              ? Icons.star_rounded
              : (value >= i + 0.25
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded),
          size: size,
          color: Palette.gold,
        ),
    ]);
  }
}

/// A thin horizontal gauge with colour + label (colour is never the only signal).
class StatBar extends StatelessWidget {
  final double value; // 0..1
  final Color? color;
  final double height;
  final double? marker; // 0..1 vertical tick
  const StatBar(this.value,
      {super.key, this.color, this.height = 8, this.marker});

  static Color colorFor(double v) =>
      v >= 0.6 ? Palette.ok : (v >= 0.35 ? Palette.warn : Palette.bad);

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return LayoutBuilder(builder: (context, c) {
      return Stack(children: [
        Container(
          height: height,
          decoration: BoxDecoration(
              color: Palette.surface2,
              borderRadius: BorderRadius.circular(height)),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: height,
          width: c.maxWidth * v,
          decoration: BoxDecoration(
              color: color ?? colorFor(v),
              borderRadius: BorderRadius.circular(height)),
        ),
        if (marker != null)
          Positioned(
            left: (c.maxWidth * marker!.clamp(0.0, 1.0)) - 1,
            child: Container(
                width: 2,
                height: height,
                color: Palette.ink.withValues(alpha: 0.5)),
          ),
      ]);
    });
  }
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;
  final Color? borderColor;
  const Panel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(14),
      this.color,
      this.onTap,
      this.borderColor});
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4))
        ],
      ),
      child: Material(
        color: color ?? Palette.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor ?? Palette.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: onTap,
            splashColor: Palette.accent.withValues(alpha: 0.08),
            highlightColor: Palette.accent.withValues(alpha: 0.04),
            child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
      child: Row(children: [
        Container(width: 14, height: 1, color: Palette.accent),
        const SizedBox(width: 8),
        Flexible(
          child: Text(text.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w700,
                  color: Palette.accent)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: Palette.line)),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const Pill(this.text, {super.key, this.color = Palette.muted, this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
          borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3)
        ],
        Flexible(
            child: Text(text,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                    fontSize: 11.5,
                    letterSpacing: 0.2,
                    fontWeight: FontWeight.w600,
                    color: color))),
      ]),
    );
  }
}

void showToast(BuildContext context, String text, {bool bad = true}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.surface2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
              color:
                  (bad ? Palette.bad : Palette.accent).withValues(alpha: 0.6))),
      duration: const Duration(seconds: 3),
    ));
}

/// Sends a command and shows its error, if any. Returns true on success.
bool sendCmd(BuildContext context, Command c, {String? okText}) {
  final r = GameScope.read(context).send(c);
  GameScope.read(context).takeToast();
  if (!r.ok) {
    showToast(context, r.message ?? _errorText(r.error));
  } else if (okText != null) {
    showToast(context, okText, bad: false);
  }
  return r.ok;
}

String _errorText(SimError? e) => switch (e) {
      SimError.notEnoughCash => 'Not enough cash. Check the Money tab.',
      SimError.wrongPhase => 'You cannot do that right now.',
      SimError.unknownId => 'That is no longer there.',
      SimError.belowMinimumOrder =>
        'The order is below the supplier\'s minimum.',
      SimError.limitReached => 'Limit reached.',
      SimError.locked => 'Not available yet.',
      SimError.invalidValue => 'That value is not allowed.',
      SimError.refused => 'Refused.',
      null => 'Something went wrong.',
    };

// ------------------------------------------------------------------ Why? sheet

void showWhy(BuildContext context, Explanation ex) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Row(children: [
            const Icon(Icons.help_outline, color: Palette.accent),
            const SizedBox(width: 8),
            Expanded(
                child: Text('Why? · ${ex.title}',
                    style: Theme.of(context).textTheme.titleMedium)),
          ]),
          const SizedBox(height: 6),
          Text(ex.valueText, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          for (final f in ex.factors)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                Expanded(
                    child: Text(f.label, style: const TextStyle(fontSize: 15))),
                Text(f.display,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: f.display.startsWith('−')
                            ? Palette.bad
                            : (f.display.startsWith('+')
                                ? Palette.ok
                                : Palette.ink))),
              ]),
            ),
          if (ex.howToImprove != null) ...[
            const SizedBox(height: 12),
            Panel(
              color: Palette.accentSoft,
              borderColor: Palette.accentSoft,
              child: Row(children: [
                const Icon(Icons.lightbulb_outline, color: Palette.accent),
                const SizedBox(width: 10),
                Expanded(child: Text(ex.howToImprove!)),
              ]),
            ),
          ],
        ],
      ),
    ),
  );
}

// ------------------------------------------------------------------ term help (doc 07 §5)

void showTerm(BuildContext context, String termId) {
  final c = GameScope.read(context);
  final t = c.content.terms[termId];
  if (t == null) return;
  c.settings.seenTerms.add(termId);
  c.saveSettings();
  showModalBottomSheet(
    context: context,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.menu_book, color: Palette.accent),
              const SizedBox(width: 8),
              Text(t.name, style: Theme.of(context).textTheme.titleLarge),
            ]),
            const SizedBox(height: 12),
            Text(t.meaning, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Why it matters  ',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: Palette.accent)),
              Expanded(
                  child: Text(t.why, style: const TextStyle(fontSize: 15))),
            ]),
          ]),
    ),
  );
}

/// A label with a dotted underline that opens its term card.
class TermText extends StatelessWidget {
  final String text;
  final String term;
  final TextStyle? style;
  const TermText(this.text, this.term, {super.key, this.style});
  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    return Semantics(
      button: true,
      label: '$text, tap for meaning',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showTerm(context, term),
        child: Text(text,
            style: base.copyWith(
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
                decorationColor: Palette.muted)),
      ),
    );
  }
}

class EmptyNote extends StatelessWidget {
  final String text;
  final IconData icon;
  const EmptyNote(this.text,
      {super.key, this.icon = Icons.check_circle_outline});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Icon(icon, color: Palette.ok, size: 20),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text, style: const TextStyle(color: Palette.muted))),
      ]),
    );
  }
}

Future<bool> confirm(BuildContext context, String title, String body,
    {String ok = 'Confirm'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true), child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}

/// Content max width 600, centred (doc 07 §2).
class Centered extends StatelessWidget {
  final Widget child;
  const Centered({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600), child: child));
}

String weekdayLong(int d) => const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ][d % 7];
String seasonName(String s) => s[0].toUpperCase() + s.substring(1);

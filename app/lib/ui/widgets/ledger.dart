import 'package:flutter/material.dart';

import '../theme.dart';
import 'common.dart';

/// The house style for the management tabs: a strip of headline numbers,
/// small-caps sub-tabs, and ledger rows grouped in one panel with hairlines
/// between them (instead of a stack of separate cards).

class StatItem {
  final String label;
  final String value;
  final String sub;
  final Color? color;
  final VoidCallback? onTap;
  const StatItem(this.label, this.value, this.sub, {this.color, this.onTap});
}

/// Three or four numbers that say how this part of the business is doing.
class StatStrip extends StatelessWidget {
  final List<StatItem> items;
  const StatStrip({super.key, required this.items});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.symmetric(
            horizontal: BorderSide(color: Palette.line.withValues(alpha: 0.9))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: IntrinsicHeight(
        child: Row(children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const VerticalDivider(width: 1, color: Palette.line),
            Expanded(
              child: InkWell(
                onTap: items[i].onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(children: [
                    Text(items[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Palette.muted,
                            fontSize: 9.5,
                            letterSpacing: 1.8,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(items[i].value,
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: items[i].color ?? Palette.ink,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ])),
                    ),
                    Text(items[i].sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Palette.muted, fontSize: 11.5)),
                  ]),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

/// One panel, many rows, hairlines between them.
class LedgerGroup extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;
  const LedgerGroup(
      {super.key,
      required this.children,
      this.padding = const EdgeInsets.symmetric(horizontal: 14)});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.line.withValues(alpha: 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            Divider(
                height: 1,
                thickness: 1,
                indent: padding.left,
                endIndent: padding.right,
                color: Palette.line.withValues(alpha: 0.6)),
          Padding(
              padding:
                  EdgeInsets.only(left: padding.left, right: padding.right),
              child: children[i]),
        ],
      ]),
    );
  }
}

/// Label ........ amount, like a page in an account book.
class LedgerLine extends StatelessWidget {
  final String label;
  final num amount;
  final bool bold;
  final bool sign;
  const LedgerLine(this.label, this.amount,
      {super.key, this.bold = false, this.sign = true});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, box) =>
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: box.maxWidth * 0.62),
            child: Text(label,
                style: TextStyle(
                    color: bold ? Palette.ink : Palette.muted,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 14)),
          ),
          const Expanded(child: _Leader()),
          Text(fmtMoney(amount, sign: sign),
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  fontSize: bold ? 16 : 14,
                  color: amount < 0 ? Palette.bad : Palette.ink,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      ),
    );
  }
}

class _Leader extends StatelessWidget {
  const _Leader();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
        child:
            CustomPaint(size: const Size(double.infinity, 1), painter: _Dots()),
      );
}

class _Dots extends CustomPainter {
  @override
  void paint(Canvas c, Size size) {
    final p = Paint()..color = Palette.line;
    for (var x = 0.0; x < size.width; x += 4) {
      c.drawCircle(Offset(x, 0.5), 0.7, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// A coloured dot and a small-caps word: "● WORKING".
class StateDot extends StatelessWidget {
  final String text;
  final Color color;
  const StateDot(this.text, {super.key, required this.color});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Flexible(
        child: Text(text.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: color,
                fontSize: 9.5,
                letterSpacing: 1.3,
                fontWeight: FontWeight.w700)),
      ),
    ]);
  }
}

/// Sub-tabs for a management page.
class GameTabBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget> tabs;
  final bool scrollable;
  const GameTabBar({super.key, required this.tabs, this.scrollable = false});
  @override
  Size get preferredSize => const Size.fromHeight(44);
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0E0C0A),
      child: TabBar(
        isScrollable: scrollable,
        tabAlignment: scrollable ? TabAlignment.start : TabAlignment.fill,
        tabs: tabs,
      ),
    );
  }
}

/// A thin horizontal meter.
class Meter extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  const Meter(this.value, {super.key, required this.color, this.height = 3});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(children: [
        Container(height: height, color: Palette.line.withValues(alpha: 0.8)),
        FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(height: height, color: color),
        ),
      ]),
    );
  }
}

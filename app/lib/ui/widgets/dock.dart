import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// The game's own line icons, drawn in code so they match each other.
enum GameIcon { cloche, toque, crate, pan, ledger, building }

class GameIconView extends StatelessWidget {
  final GameIcon icon;
  final double size;
  final Color color;
  const GameIconView(this.icon,
      {super.key, this.size = 24, this.color = Palette.ink});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _IconPainter(icon, color));
}

class _IconPainter extends CustomPainter {
  final GameIcon icon;
  final Color color;
  _IconPainter(this.icon, this.color);
  @override
  void paint(Canvas c, Size size) {
    final s = size.width / 24;
    c.scale(s);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (icon) {
      case GameIcon.cloche:
        c.drawArc(
            const Rect.fromLTWH(4, 6, 16, 16), math.pi, math.pi, false, p);
        c.drawLine(const Offset(2.5, 14.5), const Offset(21.5, 14.5), p);
        c.drawLine(const Offset(4, 18), const Offset(20, 18), p);
        c.drawCircle(const Offset(12, 4.6), 1.3, p);
      case GameIcon.toque:
        final path = Path()
          ..moveTo(7, 15)
          ..cubicTo(2.5, 14, 3, 7.5, 7.5, 8.2)
          ..cubicTo(8, 4, 16, 4, 16.5, 8.2)
          ..cubicTo(21, 7.5, 21.5, 14, 17, 15)
          ..close();
        c.drawPath(path, p);
        c.drawRect(const Rect.fromLTWH(7, 15, 10, 4.5), p);
      case GameIcon.crate:
        c.drawRect(const Rect.fromLTWH(3.5, 7, 17, 13), p);
        c.drawLine(const Offset(3.5, 11.5), const Offset(20.5, 11.5), p);
        c.drawLine(const Offset(3.5, 15.5), const Offset(20.5, 15.5), p);
        c.drawLine(const Offset(6, 4), const Offset(18, 4), p);
        c.drawLine(const Offset(6, 4), const Offset(3.5, 7), p);
        c.drawLine(const Offset(18, 4), const Offset(20.5, 7), p);
      case GameIcon.pan:
        c.drawOval(const Rect.fromLTWH(2.5, 9, 13, 9), p);
        c.drawLine(const Offset(15.5, 13.5), const Offset(21.5, 11), p);
        for (final x in [6.0, 9.0, 12.0]) {
          c.drawPath(
              Path()
                ..moveTo(x, 7)
                ..quadraticBezierTo(x - 1.4, 5, x, 3),
              p);
        }
      case GameIcon.ledger:
        c.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(5, 3, 14, 18), const Radius.circular(1.5)),
            p);
        c.drawLine(const Offset(8, 3), const Offset(8, 21), p);
        c.drawLine(const Offset(11, 8), const Offset(16, 8), p);
        c.drawLine(const Offset(11, 11.5), const Offset(16, 11.5), p);
        c.drawLine(const Offset(11, 15), const Offset(14, 15), p);
      case GameIcon.building:
        c.drawRect(const Rect.fromLTWH(4, 8, 16, 13), p);
        c.drawLine(const Offset(2.5, 8), const Offset(21.5, 8), p);
        c.drawLine(const Offset(4, 8), const Offset(6, 4), p);
        c.drawLine(const Offset(6, 4), const Offset(18, 4), p);
        c.drawLine(const Offset(18, 4), const Offset(20, 8), p);
        c.drawRect(const Rect.fromLTWH(10, 14.5, 4, 6.5), p);
        c.drawRect(const Rect.fromLTWH(6.5, 11, 2.5, 2.5), p);
        c.drawRect(const Rect.fromLTWH(15, 11, 2.5, 2.5), p);
    }
  }

  @override
  bool shouldRepaint(covariant _IconPainter old) =>
      old.icon != icon || old.color != color;
}

class DockItem {
  final GameIcon icon;
  final String label;
  final String? badge;
  final bool live;
  const DockItem(this.icon, this.label, {this.badge, this.live = false});
}

/// The bottom dock: custom icons, small-caps labels, a brass marker on the
/// active tab.
class GameDock extends StatelessWidget {
  final List<DockItem> items;
  final int selected;
  final ValueChanged<int> onSelect;
  const GameDock(
      {super.key,
      required this.items,
      required this.selected,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0E0C0A),
        border: Border(top: BorderSide(color: Palette.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                  child: _DockButton(
                      item: items[i],
                      active: i == selected,
                      onTap: () => onSelect(i))),
          ]),
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  final DockItem item;
  final bool active;
  final VoidCallback onTap;
  const _DockButton(
      {required this.item, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final color = active ? Palette.accent : Palette.muted;
    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        child: Stack(alignment: Alignment.center, children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            top: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: active ? 26 : 0,
              height: 2,
              color: Palette.accent,
            ),
          ),
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Stack(clipBehavior: Clip.none, children: [
              GameIconView(item.icon, size: 23, color: color),
              if (item.live)
                Positioned(
                  right: -10,
                  top: -4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    color: Palette.tomato,
                    child: const Text('LIVE',
                        style: TextStyle(
                            fontSize: 7,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                )
              else if (item.badge != null)
                Positioned(
                  right: -7,
                  top: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 15),
                    height: 15,
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                        color: Palette.tomato,
                        borderRadius: BorderRadius.circular(8)),
                    alignment: Alignment.center,
                    child: Text(item.badge!,
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
            ]),
            const SizedBox(height: 5),
            Text(item.label.toUpperCase(),
                style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ]),
        ]),
      ),
    );
  }
}

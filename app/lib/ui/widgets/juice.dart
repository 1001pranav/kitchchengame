import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../scene/scene_art.dart';
import 'common.dart';

/// Money that rolls to its new value, with a little coin bounce when it rises.
class RollingMoney extends StatelessWidget {
  final num value;
  final double size;
  final bool sign;
  final FontWeight weight;
  const RollingMoney(this.value,
      {super.key,
      this.size = 15,
      this.sign = false,
      this.weight = FontWeight.w700});

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    if (reduced) return Money(value, size: size, sign: sign, weight: weight);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final rising = v < value - 0.5;
        return AnimatedScale(
          scale: rising ? 1.08 : 1,
          duration: const Duration(milliseconds: 160),
          child: Money(v.round(),
              size: size,
              sign: sign,
              weight: weight,
              color: rising ? const Color(0xFF2F7D4F) : null),
        );
      },
    );
  }
}

/// Shrinks a little while pressed and springs back, so big buttons feel physical.
class Pressable extends StatefulWidget {
  final Widget child;
  const Pressable({super.key, required this.child});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.95 : 1,
        duration: Duration(milliseconds: _down ? 70 : 220),
        curve: _down ? Curves.easeOut : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}

/// A burst of confetti that falls once over its child.
class Confetti extends StatefulWidget {
  final Widget child;
  final int pieces;
  const Confetti({super.key, required this.child, this.pieces = 70});
  @override
  State<Confetti> createState() => _ConfettiState();
}

class _Piece {
  final double x, speed, drift, spin, size, delay;
  final Color color;
  final bool round;
  _Piece(this.x, this.speed, this.drift, this.spin, this.size, this.delay,
      this.color, this.round);
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3200));
  late final List<_Piece> _pieces;

  static const _colors = [
    Color(0xFFE63946),
    Color(0xFFF4A261),
    Color(0xFFFFD166),
    Color(0xFF06D6A0),
    Color(0xFF118AB2),
    Color(0xFF9B5DE5),
    Color(0xFFF15BB5),
  ];

  @override
  void initState() {
    super.initState();
    final r = math.Random();
    _pieces = [
      for (var i = 0; i < widget.pieces; i++)
        _Piece(
            r.nextDouble(),
            0.5 + r.nextDouble() * 0.7,
            r.nextDouble() * 2 - 1,
            r.nextDouble() * 10 - 5,
            4 + r.nextDouble() * 5,
            r.nextDouble() * 0.35,
            _colors[r.nextInt(_colors.length)],
            r.nextBool())
    ];
    _a.forward();
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return Stack(children: [
      widget.child,
      Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _a,
            builder: (_, __) =>
                CustomPaint(painter: _ConfettiPainter(_pieces, _a.value)),
          ),
        ),
      ),
    ]);
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double t;
  _ConfettiPainter(this.pieces, this.t);
  @override
  void paint(Canvas c, Size size) {
    final p = Paint();
    for (final q in pieces) {
      final k = ((t - q.delay) / (1 - q.delay)).clamp(0.0, 1.0);
      if (k <= 0 || k >= 1) continue;
      final y = -20 + k * q.speed * (size.height + 60) * 1.2;
      final x = q.x * size.width + math.sin(k * 9 + q.drift * 4) * 18 * q.drift;
      p.color = q.color.withValues(alpha: (1 - k * k).clamp(0, 1));
      c.save();
      c.translate(x, y);
      c.rotate(k * q.spin * math.pi);
      if (q.round) {
        c.drawCircle(Offset.zero, q.size * 0.45, p);
      } else {
        c.drawRect(
            Rect.fromCenter(
                center: Offset.zero,
                width: q.size,
                height: q.size * 0.45 * (0.4 + (math.cos(k * 20)).abs())),
            p);
      }
      c.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}

/// A trophy drawn in code, for stage-ups and the ending.
class Trophy extends StatefulWidget {
  final double size;
  final int stars;
  const Trophy({super.key, this.size = 96, this.stars = 3});
  @override
  State<Trophy> createState() => _TrophyState();
}

class _TrophyState extends State<Trophy> with SingleTickerProviderStateMixin {
  late final AnimationController _a =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat();
  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: still ? 1 : 0.2, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (_, s, child) => Transform.scale(scale: s, child: child),
      child: AnimatedBuilder(
        animation: _a,
        builder: (_, __) => CustomPaint(
          size: Size.square(widget.size),
          painter: _TrophyPainter(still ? 0 : _a.value, widget.stars),
        ),
      ),
    );
  }
}

class _TrophyPainter extends CustomPainter {
  final double t;
  final int stars;
  _TrophyPainter(this.t, this.stars);
  @override
  void paint(Canvas c, Size size) {
    final s = size.width / 100;
    c.save();
    c.scale(s);
    // Rays.
    final rays = Paint()..color = const Color(0x33FFD166);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6 + t * math.pi * 2 / 6;
      final path = Path()
        ..moveTo(50, 44)
        ..lineTo(50 + math.cos(a - 0.12) * 60, 44 + math.sin(a - 0.12) * 60)
        ..lineTo(50 + math.cos(a + 0.12) * 60, 44 + math.sin(a + 0.12) * 60)
        ..close();
      c.drawPath(path, rays);
    }
    final gold = Paint()..color = const Color(0xFFF2B705);
    final dark = Paint()..color = const Color(0xFFC98A00);
    // Handles.
    final h = Paint()
      ..color = const Color(0xFFC98A00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    c.drawArc(
        const Rect.fromLTWH(18, 22, 22, 24), math.pi * 0.5, math.pi, false, h);
    c.drawArc(
        const Rect.fromLTWH(60, 22, 22, 24), -math.pi * 0.5, math.pi, false, h);
    // Cup.
    final cup = Path()
      ..moveTo(28, 18)
      ..lineTo(72, 18)
      ..quadraticBezierTo(72, 58, 50, 62)
      ..quadraticBezierTo(28, 58, 28, 18)
      ..close();
    c.drawPath(cup, gold);
    c.drawRect(const Rect.fromLTWH(45, 60, 10, 12), dark);
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(32, 72, 36, 9), const Radius.circular(3)),
        gold);
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(28, 80, 44, 9), const Radius.circular(3)),
        Paint()..color = const Color(0xFF6D4C41));
    // Shine.
    c.drawPath(
        Path()
          ..moveTo(34, 22)
          ..lineTo(40, 22)
          ..quadraticBezierTo(40, 44, 48, 54)
          ..quadraticBezierTo(34, 48, 34, 22)
          ..close(),
        Paint()..color = const Color(0x66FFFFFF));
    for (var i = 0; i < stars.clamp(0, 5); i++) {
      final x = 50 + (i - (stars - 1) / 2) * 9;
      drawStar(c, Offset(x, 36), 3.6, Colors.white);
    }
    // Sparkles.
    for (var i = 0; i < 4; i++) {
      final k = (t * 2 + i / 4) % 1;
      final o = Offset(20 + (i * 23) % 64.0, 12 + (i * 37) % 50.0);
      drawStar(c, o, 3 * math.sin(k * math.pi), const Color(0xFFFFF3B0));
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _TrophyPainter old) => old.t != t;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

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
  const Confetti({super.key, required this.child, this.pieces = 36});
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
      vsync: this, duration: const Duration(milliseconds: 5200));
  late final List<_Piece> _pieces;

  static const _colors = [
    Color(0xFFE6C77A),
    Color(0xFFC9A55B),
    Color(0xFF8A7246),
    Color(0xFFF1E8D8),
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
  final int stars; // the stage reached, shown as a Roman numeral
  _TrophyPainter(this.t, this.stars);
  @override
  void paint(Canvas c, Size size) {
    final r = size.width / 2;
    final o = Offset(r, r);
    const brass = Color(0xFFC9A55B);
    // Slow sheen around the rim.
    c.drawCircle(
        o,
        r * 0.98,
        Paint()
          ..shader = SweepGradient(
              transform: GradientRotation(t * math.pi * 2),
              colors: const [
                Color(0xFF6E5A30),
                Color(0xFFE6C77A),
                Color(0xFF6E5A30),
                Color(0xFFB8964A),
                Color(0xFF6E5A30)
              ]).createShader(Rect.fromCircle(center: o, radius: r)));
    c.drawCircle(o, r * 0.86, Paint()..color = const Color(0xFF15120F));
    c.drawCircle(
        o,
        r * 0.8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = brass.withValues(alpha: 0.6));
    // Laurel.
    final leaf = Paint()..color = brass.withValues(alpha: 0.85);
    for (final side in [-1.0, 1.0]) {
      for (var i = 0; i < 7; i++) {
        final a = math.pi / 2 + side * (0.35 + i * 0.27);
        final p = o + Offset(math.cos(a), math.sin(a)) * r * 0.66;
        c.save();
        c.translate(p.dx, p.dy);
        c.rotate(a + side * 0.6);
        c.drawOval(
            Rect.fromCenter(
                center: Offset.zero, width: r * 0.16, height: r * 0.07),
            leaf);
        c.restore();
      }
    }
    const numerals = ['I', 'II', 'III', 'IV', 'V', 'VI'];
    final n = numerals[(stars - 1).clamp(0, numerals.length - 1)];
    final tp = TextPainter(
      text: TextSpan(
          text: n,
          style: TextStyle(
              fontFamily: 'Playfair',
              fontWeight: FontWeight.w700,
              fontSize: r * 0.62,
              color: const Color(0xFFE6C77A),
              height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, o - Offset(tp.width / 2, tp.height / 2 + r * 0.04));
  }

  @override
  bool shouldRepaint(covariant _TrophyPainter old) => old.t != t;
}

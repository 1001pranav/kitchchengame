import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'scene_art.dart';

/// Time of day for a shopfront picture.
enum DayTime { morning, day, evening, night }

/// A restaurant seen from the street, drawn in code. [quality] runs from 0
/// (Worst: boarded window, torn awning) to 4 (Excellent: gold sign, string
/// lights). With [animate], clouds drift, people stroll past and stars twinkle.
class Shopfront extends StatefulWidget {
  final String name;
  final Color accent;
  final int quality;
  final DayTime time;
  final bool open;
  final bool animate;
  final double height;
  final int seed;
  const Shopfront(
      {super.key,
      required this.name,
      required this.accent,
      this.quality = 2,
      this.time = DayTime.day,
      this.open = true,
      this.animate = false,
      this.height = 160,
      this.seed = 1});

  @override
  State<Shopfront> createState() => _ShopfrontState();
}

class _ShopfrontState extends State<Shopfront>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a =
      AnimationController(vsync: this, duration: const Duration(seconds: 24));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _a.repeat();
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations || !widget.animate;
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _a,
            builder: (_, __) => CustomPaint(
              painter: _ShopPainter(widget, still ? 0.3 : _a.value, !still),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShopPainter extends CustomPainter {
  final Shopfront w;
  final double t; // 0..1 loop
  final bool moving;
  _ShopPainter(this.w, this.t, this.moving);

  Paint _p(Color c) => Paint()..color = c;

  @override
  void paint(Canvas c, Size size) {
    final W = size.width, H = size.height;
    final r = math.Random(w.seed);
    final ground = H * 0.84;
    final night = w.time == DayTime.night;
    final evening = w.time == DayTime.evening;
    final lit = night || evening;

    // Sky.
    final sky = switch (w.time) {
      DayTime.morning => [const Color(0xFFFFD6A5), const Color(0xFFBDE0FE)],
      DayTime.day => [const Color(0xFF8ECAE6), const Color(0xFFD9F0FF)],
      DayTime.evening => [const Color(0xFF6D597A), const Color(0xFFF4A261)],
      DayTime.night => [const Color(0xFF0B132B), const Color(0xFF1C2541)],
    };
    c.drawRect(
        Rect.fromLTWH(0, 0, W, ground),
        Paint()
          ..shader = LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: sky)
              .createShader(Rect.fromLTWH(0, 0, W, ground)));
    if (night) {
      for (var i = 0; i < 26; i++) {
        final o = Offset(r.nextDouble() * W, r.nextDouble() * ground * 0.6);
        final tw = 0.5 + 0.5 * math.sin(t * math.pi * 2 * 6 + i);
        c.drawCircle(o, 0.6 + tw * 0.9,
            _p(Color.fromRGBO(255, 255, 255, 0.4 + 0.5 * tw)));
      }
      c.drawCircle(
          Offset(W * 0.84, H * 0.16), H * 0.07, _p(const Color(0xFFFFF3C4)));
      c.drawCircle(Offset(W * 0.84 + H * 0.03, H * 0.15), H * 0.06, _p(sky[0]));
    } else {
      // Sun.
      final sunY = w.time == DayTime.morning
          ? H * 0.32
          : (evening ? H * 0.42 : H * 0.14);
      c.drawCircle(Offset(W * 0.82, sunY), H * 0.07,
          _p(evening ? const Color(0xFFFFB703) : const Color(0xFFFFE066)));
      // Clouds.
      for (var i = 0; i < 3; i++) {
        final x = ((r.nextDouble() + t * (0.5 + i * 0.25)) % 1.2) * W - W * 0.1;
        final y = H * (0.08 + 0.12 * i);
        final cl = _p(Colors.white.withValues(alpha: evening ? 0.35 : 0.85));
        c.drawCircle(Offset(x, y), H * 0.045, cl);
        c.drawCircle(Offset(x + H * 0.05, y - H * 0.02), H * 0.055, cl);
        c.drawCircle(Offset(x + H * 0.1, y), H * 0.04, cl);
      }
    }

    // Neighbouring buildings.
    final nb = night ? const Color(0xFF2B2D42) : const Color(0xFFCDB4A0);
    final nb2 = night ? const Color(0xFF22223B) : const Color(0xFFB79C88);
    c.drawRect(Rect.fromLTWH(0, ground - H * 0.62, W * 0.16, H * 0.62), _p(nb));
    c.drawRect(
        Rect.fromLTWH(W * 0.84, ground - H * 0.7, W * 0.16, H * 0.7), _p(nb2));
    for (var i = 0; i < 3; i++) {
      final win = _p(lit && r.nextBool()
          ? const Color(0xFFFFE8A3)
          : const Color(0x55FFFFFF));
      c.drawRect(
          Rect.fromLTWH(
              W * 0.04, ground - H * (0.55 - i * 0.16), W * 0.07, H * 0.08),
          win);
      c.drawRect(
          Rect.fromLTWH(
              W * 0.89, ground - H * (0.62 - i * 0.18), W * 0.07, H * 0.09),
          win);
    }

    // The restaurant.
    final q = w.quality.clamp(0, 4);
    final face = Rect.fromLTWH(W * 0.18, ground - H * 0.66, W * 0.64, H * 0.66);
    final wall = [
      const Color(0xFF9E9E9E),
      const Color(0xFFD8C8A8),
      const Color(0xFFF1E3C8),
      const Color(0xFFD98E5F),
      const Color(0xFF2D6A4F),
    ][q];
    c.drawRect(face, _p(night ? Color.lerp(wall, Colors.black, 0.45)! : wall));
    if (q >= 2) {
      // Brick hints.
      final b = _p(Colors.black.withValues(alpha: 0.06));
      for (var y = face.top + 6; y < face.bottom; y += 9) {
        for (var x = face.left + ((y ~/ 9).isEven ? 4 : 12);
            x < face.right - 10;
            x += 22) {
          c.drawRect(Rect.fromLTWH(x, y, 14, 4), b);
        }
      }
    }
    // Cornice.
    c.drawRect(Rect.fromLTWH(face.left - 4, face.top - 6, face.width + 8, 8),
        _p(q == 4 ? const Color(0xFFD4A017) : const Color(0xFF6D4C41)));

    // Sign.
    final signR = Rect.fromLTWH(face.left + face.width * 0.12,
        face.top + H * 0.04, face.width * 0.76, H * 0.13);
    c.drawRRect(RRect.fromRectAndRadius(signR, const Radius.circular(4)),
        _p(q == 0 ? const Color(0xFF5D5D5D) : w.accent));
    if (q == 4) {
      c.drawRRect(
          RRect.fromRectAndRadius(signR, const Radius.circular(4)),
          Paint()
            ..color = const Color(0xFFFFD166)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
    final fs =
        math.min(signR.height * 0.62, signR.width / (w.name.length * 0.62 + 1));
    final tp = labelPainter(
        w.name,
        fs,
        q == 0
            ? const Color(0xFFBDBDBD)
            : (lit ? const Color(0xFFFFF3C4) : Colors.white),
        shadow: false);
    c.save();
    if (q == 0) {
      // A crooked old sign.
      c.translate(signR.center.dx, signR.center.dy);
      c.rotate(-0.05);
      c.translate(-signR.center.dx, -signR.center.dy);
    }
    tp.paint(c, signR.center - Offset(tp.width / 2, tp.height / 2));
    c.restore();
    if (lit && q > 0) {
      c.drawRRect(
          RRect.fromRectAndRadius(signR.inflate(5), const Radius.circular(8)),
          _p(w.accent.withValues(alpha: 0.18)));
    }

    // Windows and door.
    final rowTop = face.top + H * 0.3;
    final rowH = face.bottom - rowTop - H * 0.02;
    final doorW = face.width * 0.18;
    final door = Rect.fromLTWH(
        face.center.dx - doorW / 2, rowTop, doorW, rowH + H * 0.02);
    final winL = Rect.fromLTWH(face.left + face.width * 0.06, rowTop + 4,
        door.left - face.left - face.width * 0.1, rowH * 0.7);
    final winR = Rect.fromLTWH(door.right + face.width * 0.04, rowTop + 4,
        face.right - door.right - face.width * 0.1, rowH * 0.7);
    final glass = w.open && (lit || w.time == DayTime.day)
        ? const Color(0xFFFFE8A3)
        : (night ? const Color(0xFF3A3F58) : const Color(0xFF9FC5E8));
    for (final win in [winL, winR]) {
      c.drawRect(win.inflate(3), _p(const Color(0xFF5D4037)));
      c.drawRect(win, _p(glass));
      if (w.open) {
        // Diners inside.
        for (var i = 0; i < 3; i++) {
          final x = win.left + win.width * (0.2 + 0.3 * i);
          final bob = moving ? math.sin(t * math.pi * 40 + i * 2) * 0.8 : 0;
          final col = [
            const Color(0xFFE07A5F),
            const Color(0xFF81B29A),
            const Color(0xFF4F86C6)
          ][(i + w.seed) % 3];
          c.drawCircle(
              Offset(x, win.bottom - win.height * 0.42 + bob),
              win.height * 0.13,
              _p(const Color(0xFFE8B98F).withValues(alpha: 0.9)));
          c.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromCenter(
                      center: Offset(x, win.bottom - win.height * 0.12),
                      width: win.height * 0.36,
                      height: win.height * 0.32),
                  const Radius.circular(4)),
              _p(col.withValues(alpha: 0.9)));
        }
        c.drawRect(
            Rect.fromLTWH(win.left, win.bottom - win.height * 0.1, win.width,
                win.height * 0.1),
            _p(const Color(0xFF8C5A3C)));
      }
      // Mullion and reflection.
      c.drawLine(
          Offset(win.center.dx, win.top),
          Offset(win.center.dx, win.bottom),
          Paint()
            ..color = const Color(0xFF5D4037)
            ..strokeWidth = 2);
      c.drawLine(
          Offset(win.left + 6, win.bottom - 6),
          Offset(win.left + win.width * 0.35, win.top + 6),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.35)
            ..strokeWidth = 3);
    }
    if (q == 0) {
      // Boarded-up window.
      final plank = _p(const Color(0xFF8D6E63));
      c.save();
      c.translate(winR.center.dx, winR.center.dy);
      c.rotate(0.25);
      c.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: winR.width * 1.15, height: 7),
          plank);
      c.rotate(-0.5);
      c.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: winR.width * 1.15, height: 7),
          plank);
      c.restore();
    }
    c.drawRect(door.inflate(3), _p(const Color(0xFF4E342E)));
    c.drawRect(door,
        _p(w.open && lit ? const Color(0xFFFFD98A) : const Color(0xFF795548)));
    c.drawRect(
        Rect.fromLTWH(
            door.left + 4, door.top + 4, door.width - 8, door.height * 0.45),
        _p(glass.withValues(alpha: 0.85)));
    c.drawCircle(Offset(door.right - 5, door.center.dy + 4), 1.8,
        _p(const Color(0xFFFFD166)));
    drawOpenSign(
        c, Offset(door.center.dx, door.top + door.height * 0.33), w.open);

    // Awning.
    final aw = Rect.fromLTWH(
        face.left - 2, rowTop - H * 0.09, face.width + 4, H * 0.08);
    final stripes = (aw.width / 14).floor();
    final awA = q == 0 ? const Color(0xFF8D8D8D) : w.accent;
    final awB = q == 0 ? const Color(0xFFBDBDBD) : Colors.white;
    for (var i = 0; i < stripes; i++) {
      final sx = aw.left + i * aw.width / stripes;
      final sr = Rect.fromLTWH(sx, aw.top, aw.width / stripes, aw.height);
      c.drawRect(sr, _p(i.isEven ? awA : awB));
      if (!(q == 0 && i % 4 == 3)) {
        c.drawArc(
            Rect.fromLTWH(
                sr.left, sr.bottom - sr.width / 2, sr.width, sr.width),
            0,
            math.pi,
            true,
            _p(i.isEven ? awA : awB));
      }
    }
    c.drawRect(Rect.fromLTWH(aw.left, aw.top, aw.width, 2),
        _p(Colors.black.withValues(alpha: 0.15)));

    // String lights for the best places in the evening.
    if (q >= 3 && lit) {
      final y = aw.top - 6;
      for (var i = 0; i < 12; i++) {
        final x = face.left + face.width * (i + 0.5) / 12;
        final sag = math.sin((i + 0.5) / 12 * math.pi) * 6;
        final on = 0.6 + 0.4 * math.sin(t * math.pi * 30 + i);
        c.drawCircle(
            Offset(x, y + sag), 2.2, _p(Color.fromRGBO(255, 214, 102, on)));
      }
    }

    // Pavement and street.
    c.drawRect(Rect.fromLTWH(0, ground, W, H - ground),
        _p(night ? const Color(0xFF4A4E69) : const Color(0xFFC9C3B6)));
    c.drawRect(Rect.fromLTWH(0, ground, W, 3),
        _p(Colors.black.withValues(alpha: 0.12)));
    for (var x = 0.0; x < W; x += 26) {
      c.drawLine(Offset(x, ground + 3), Offset(x, H),
          Paint()..color = Colors.black.withValues(alpha: 0.06));
    }
    // Plants and a bench for the nicer places.
    if (q >= 2) {
      drawPlant(c, Offset(door.left - 14, ground - 4), s: 1.2);
      drawPlant(c, Offset(door.right + 14, ground - 4), s: 1.2);
    }
    if (q == 0) {
      // Rubbish bag and a scribble.
      c.drawOval(Rect.fromLTWH(face.right - 30, ground - 14, 20, 15),
          _p(const Color(0xFF263238)));
      final g = Paint()
        ..color = const Color(0xFFE63946)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final path = Path()..moveTo(face.left + 10, face.bottom - 24);
      for (var i = 1; i < 6; i++) {
        path.lineTo(
            face.left + 10 + i * 6, face.bottom - 24 + (i.isEven ? -8 : 0));
      }
      c.drawPath(path, g);
    }
    // Lamp post.
    final lx = W * 0.9;
    c.drawRect(Rect.fromLTWH(lx - 1.5, ground - H * 0.5, 3, H * 0.5),
        _p(const Color(0xFF37474F)));
    c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(lx - 6, ground - H * 0.55, 12, 9),
            const Radius.circular(3)),
        _p(const Color(0xFF37474F)));
    if (lit) {
      c.drawCircle(
          Offset(lx, ground - H * 0.5),
          H * 0.2,
          Paint()
            ..shader = RadialGradient(colors: [
              const Color(0x88FFE8A3),
              const Color(0x00FFE8A3),
            ]).createShader(Rect.fromCircle(
                center: Offset(lx, ground - H * 0.5), radius: H * 0.2)));
      c.drawCircle(
          Offset(lx, ground - H * 0.505), 3, _p(const Color(0xFFFFF3C4)));
    }

    // People strolling past.
    if (!night || w.open) {
      final count = w.open ? 3 : 1;
      for (var i = 0; i < count; i++) {
        final dir = i.isEven ? 1.0 : -1.0;
        final speed = 0.55 + i * 0.2;
        var k = (t * speed * 3 + i * 0.37) % 1;
        if (dir < 0) k = 1 - k;
        final x = -20 + k * (W + 40);
        final look = Look.customer(w.seed * 13 + i);
        drawPerson(c, Offset(x, H - 4 - i * 3.0), look,
            s: H / 140, walk: moving ? t * math.pi * 2 * 90 * speed : -1);
      }
    }
    if (night) {
      c.drawRect(Offset.zero & size, _p(const Color(0x22000033)));
    }
  }

  @override
  bool shouldRepaint(covariant _ShopPainter old) =>
      old.t != t ||
      old.w.name != w.name ||
      old.w.time != w.time ||
      old.w.open != w.open;
}

/// Quality of a shopfront from a tier id (Worst 0 … Excellent 4).
int tierQuality(String tierId) => switch (tierId) {
      'worst' => 0,
      'bad' => 1,
      'best' => 3,
      'excellent' => 4,
      _ => 2,
    };

/// A cuisine's accent colour from its "#RRGGBB" string.
Color accentOf(String? hex) => hex == null || hex.length != 7
    ? const Color(0xFF2F7D4F)
    : Color(int.parse('FF${hex.substring(1)}', radix: 16));

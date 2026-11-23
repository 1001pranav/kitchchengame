import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'scene_art.dart';

/// Time of day for a shopfront picture.
enum DayTime { morning, day, evening, night }

/// A restaurant seen from the street, drawn in code as a moody illustration.
/// [quality] runs from 0 (Worst: flickering sign, boarded window) to 4
/// (Excellent: gilt lettering, string lights). With [animate], passers-by
/// walk past, lights breathe and, if [rain], rain falls on a wet street.
class Shopfront extends StatefulWidget {
  final String name;
  final Color accent; // kept for callers; the palette is set by quality
  final int quality;
  final DayTime time;
  final bool open;
  final bool animate;
  final bool rain;
  final double height;
  final int seed;
  const Shopfront(
      {super.key,
      required this.name,
      this.accent = const Color(0xFFC9A55B),
      this.quality = 2,
      this.time = DayTime.evening,
      this.open = true,
      this.animate = false,
      this.rain = false,
      this.height = 160,
      this.seed = 1});

  @override
  State<Shopfront> createState() => _ShopfrontState();
}

class _ShopfrontState extends State<Shopfront>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a =
      AnimationController(vsync: this, duration: const Duration(seconds: 30));

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
                painter: _ShopPainter(widget, still ? 0.37 : _a.value, !still)),
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
    final ground = H * 0.8;
    final q = w.quality.clamp(0, 4);
    final dark = w.time == DayTime.night || w.time == DayTime.evening;
    final lit = w.open || w.time == DayTime.night;

    // Sky.
    final sky = switch (w.time) {
      DayTime.morning => [const Color(0xFF2B3A4E), const Color(0xFF8C7A6E)],
      DayTime.day => [const Color(0xFF59646E), const Color(0xFF9AA0A2)],
      DayTime.evening => [const Color(0xFF1B1A2B), const Color(0xFF5A3A3A)],
      DayTime.night => [const Color(0xFF07080D), const Color(0xFF151824)],
    };
    c.drawRect(
        Rect.fromLTWH(0, 0, W, ground),
        Paint()
          ..shader = LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: sky)
              .createShader(Rect.fromLTWH(0, 0, W, ground)));
    if (w.time == DayTime.night) {
      for (var i = 0; i < 18; i++) {
        final o = Offset(r.nextDouble() * W, r.nextDouble() * ground * 0.35);
        c.drawCircle(o, 0.6,
            _p(Color.fromRGBO(255, 255, 255, 0.25 + r.nextDouble() * 0.3)));
      }
    }

    // Neighbouring buildings: dark masses with a few lit windows.
    final nb = Color.lerp(sky[0], Colors.black, 0.45)!;
    c.drawRect(Rect.fromLTWH(0, ground - H * 0.72, W * 0.17, H * 0.72), _p(nb));
    c.drawRect(Rect.fromLTWH(W * 0.83, ground - H * 0.78, W * 0.17, H * 0.78),
        _p(Color.lerp(nb, Colors.black, 0.2)!));
    for (var i = 0; i < 6; i++) {
      final left = i < 3;
      final x = left ? W * 0.04 : W * 0.87;
      final y = ground - H * (0.62 - (i % 3) * 0.18);
      final on = dark && r.nextDouble() < 0.5;
      c.drawRect(Rect.fromLTWH(x, y, W * 0.08, H * 0.09),
          _p(on ? const Color(0xFF8A6A3A) : const Color(0xFF1A1C22)));
    }

    // The building.
    final face = Rect.fromLTWH(W * 0.17, ground - H * 0.7, W * 0.66, H * 0.7);
    final wall = [
      const Color(0xFF3A3632), // worst: grimy render
      const Color(0xFF4A3A30), // bad: faded brick
      const Color(0xFF4E2E24), // good: brick
      const Color(0xFF26231F), // best: charcoal
      const Color(0xFF14181A), // excellent: black lacquer
    ][q];
    c.drawRect(face, _p(wall));
    if (q == 1 || q == 2) {
      final b = _p(Colors.black.withValues(alpha: 0.14));
      for (var y = face.top + 5; y < face.bottom; y += 7) {
        for (var x = face.left + ((y ~/ 7).isEven ? 3 : 10);
            x < face.right - 8;
            x += 15) {
          c.drawRect(Rect.fromLTWH(x, y, 11, 3), b);
        }
      }
    }
    // Cornice and pilasters.
    final trimC = q >= 3 ? const Color(0xFF8A7246) : const Color(0xFF2A2420);
    c.drawRect(Rect.fromLTWH(face.left - 4, face.top - 5, face.width + 8, 6),
        _p(trimC));
    c.drawRect(Rect.fromLTWH(face.left, face.top, 4, face.height),
        _p(Colors.black.withValues(alpha: 0.25)));
    c.drawRect(Rect.fromLTWH(face.right - 4, face.top, 4, face.height),
        _p(Colors.black.withValues(alpha: 0.25)));

    // Sign: serif letters, lit when open or at night.
    final flicker = q == 0 && moving
        ? (math.sin(t * math.pi * 2 * 40) > 0.6 ? 0.35 : 1.0)
        : 1.0;
    final signColor = q == 0
        ? const Color(0xFF9A8F80)
        : (q == 4 ? const Color(0xFFE6C77A) : const Color(0xFFD9B25F));
    final signR = Rect.fromLTWH(face.left + face.width * 0.08,
        face.top + H * 0.05, face.width * 0.84, H * 0.13);
    c.drawRect(signR, _p(const Color(0xFF0E0D0C)));
    c.drawRect(
        signR.deflate(2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = signColor.withValues(alpha: 0.45));
    final fs =
        math.min(signR.height * 0.6, signR.width / (w.name.length * 0.55 + 1));
    final glowOn = lit && q > 0;
    final tp = labelPainter(w.name, fs,
        signColor.withValues(alpha: (glowOn ? 1.0 : 0.55) * flicker),
        serif: true, shadow: false, spacing: 0.6);
    c.save();
    if (q == 0) {
      c.translate(signR.center.dx, signR.center.dy);
      c.rotate(-0.04);
      c.translate(-signR.center.dx, -signR.center.dy);
    }
    if (glowOn) {
      c.drawRect(
          signR.inflate(6), _p(signColor.withValues(alpha: 0.07 * flicker)));
    }
    tp.paint(c, signR.center - Offset(tp.width / 2, tp.height / 2));
    c.restore();

    // Awning: one deep colour, no stripes.
    final awColor = [
      const Color(0xFF3A3A3A),
      const Color(0xFF4A2A26),
      const Color(0xFF1F3B2D),
      const Color(0xFF1E2A3A),
      const Color(0xFF0E0E10),
    ][q];
    final rowTop = face.top + H * 0.32;
    if (q > 0) {
      final aw = Path()
        ..moveTo(face.left - 3, rowTop - H * 0.08)
        ..lineTo(face.right + 3, rowTop - H * 0.08)
        ..lineTo(face.right + 8, rowTop - H * 0.005)
        ..lineTo(face.left - 8, rowTop - H * 0.005)
        ..close();
      c.drawPath(aw, _p(awColor));
      c.drawRect(
          Rect.fromLTWH(
              face.left - 8, rowTop - H * 0.01, face.width + 16, H * 0.012),
          _p(q == 4
              ? const Color(0xFFB8964A)
              : Color.lerp(awColor, Colors.black, 0.3)!));
    }

    // Windows and door.
    final rowH = face.bottom - rowTop - H * 0.02;
    final doorW = face.width * 0.16;
    final door = Rect.fromLTWH(
        face.center.dx - doorW / 2, rowTop + 2, doorW, rowH + H * 0.02 - 2);
    final winL = Rect.fromLTWH(face.left + face.width * 0.06, rowTop + 4,
        door.left - face.left - face.width * 0.1, rowH * 0.74);
    final winR = Rect.fromLTWH(door.right + face.width * 0.04, rowTop + 4,
        face.right - door.right - face.width * 0.1, rowH * 0.74);
    final warm = w.open
        ? const Color(0xFFE0A85A)
        : (w.time == DayTime.night
            ? const Color(0xFF1C1A18)
            : const Color(0xFF3A4048));
    for (final win in [winL, winR]) {
      c.drawRect(win.inflate(2.5), _p(const Color(0xFF0E0D0C)));
      c.drawRect(
          win,
          Paint()
            ..shader = LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [warm, Color.lerp(warm, Colors.black, 0.35)!])
                .createShader(win));
      if (w.open) {
        // Diners in silhouette, a pendant lamp each.
        for (var i = 0; i < 3; i++) {
          final x = win.left + win.width * (0.2 + 0.3 * i);
          final bob = moving ? math.sin(t * math.pi * 60 + i * 2) * 0.6 : 0;
          final sil = _p(const Color(0xCC2A1A10));
          c.drawCircle(Offset(x, win.bottom - win.height * 0.46 + bob),
              win.height * 0.11, sil);
          c.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromCenter(
                      center: Offset(x, win.bottom - win.height * 0.16),
                      width: win.height * 0.34,
                      height: win.height * 0.3),
                  Radius.circular(win.height * 0.1)),
              sil);
          c.drawCircle(
              Offset(x + win.width * 0.12, win.top + win.height * 0.14),
              win.height * 0.05,
              _p(const Color(0xFFFFE2A8)));
        }
        c.drawRect(
            Rect.fromLTWH(win.left, win.bottom - win.height * 0.08, win.width,
                win.height * 0.08),
            _p(const Color(0xFF3A2414)));
      }
      c.drawLine(
          Offset(win.center.dx, win.top),
          Offset(win.center.dx, win.bottom),
          Paint()
            ..color = const Color(0xFF0E0D0C)
            ..strokeWidth = 1.6);
    }
    if (q == 0) {
      final plank = _p(const Color(0xFF4A3A2C));
      c.save();
      c.translate(winR.center.dx, winR.center.dy);
      c.rotate(0.22);
      c.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: winR.width * 1.15, height: 6),
          plank);
      c.rotate(-0.44);
      c.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: winR.width * 1.15, height: 6),
          plank);
      c.restore();
    }
    c.drawRect(door.inflate(2.5), _p(const Color(0xFF0E0D0C)));
    c.drawRect(
        door, _p(w.open ? const Color(0xFF5A3A20) : const Color(0xFF241A14)));
    c.drawRect(
        Rect.fromLTWH(
            door.left + 3, door.top + 3, door.width - 6, door.height * 0.5),
        _p(w.open ? const Color(0xFFC88A48) : const Color(0xFF2E3238)));
    c.drawLine(
        Offset(door.right - 4, door.center.dy),
        Offset(door.right - 4, door.center.dy + 7),
        Paint()
          ..color = const Color(0xFFC9A55B)
          ..strokeWidth = 1.4);
    drawOpenSign(
        c, Offset(door.center.dx, door.top + door.height * 0.32), w.open);

    // Light spilling onto the pavement.
    if (w.open) {
      c.drawRect(
          Rect.fromLTWH(face.left, ground, face.width, H - ground),
          Paint()
            ..shader = LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [const Color(0x55E0A85A), const Color(0x00E0A85A)])
                .createShader(
                    Rect.fromLTWH(face.left, ground, face.width, H - ground)));
    }

    // String lights for the finest places.
    if (q >= 3 && lit) {
      final y = face.top + H * 0.2;
      for (var i = 0; i < 14; i++) {
        final x = face.left + face.width * (i + 0.5) / 14;
        final sag = math.sin((i + 0.5) / 14 * math.pi) * 5;
        final on = 0.7 + 0.3 * math.sin(t * math.pi * 24 + i);
        c.drawCircle(Offset(x, y + sag + H * 0.1), 1.6,
            _p(Color.fromRGBO(255, 214, 140, on)));
      }
    }

    // Pavement, wet when it rains.
    final pave = w.time == DayTime.night
        ? const Color(0xFF15171B)
        : const Color(0xFF2A2C30);
    c.drawRect(Rect.fromLTWH(0, ground, W, H - ground),
        _p(pave.withValues(alpha: w.open ? 0.85 : 1)));
    c.drawRect(Rect.fromLTWH(0, ground, W, 2),
        _p(Colors.black.withValues(alpha: 0.4)));
    if (w.rain && w.open) {
      // Reflections of the windows and the sign.
      for (final win in [winL, winR]) {
        c.drawRect(
            Rect.fromLTWH(win.left, ground + 3, win.width, (H - ground) * 0.7),
            _p(const Color(0x22E0A85A)));
      }
    }
    if (q >= 2) {
      drawPlantSide(c, Offset(door.left - 12, ground), H / 150);
      drawPlantSide(c, Offset(door.right + 12, ground), H / 150);
    }
    // Lamp post.
    final lx = W * 0.91;
    c.drawRect(Rect.fromLTWH(lx - 1.5, ground - H * 0.56, 3, H * 0.56),
        _p(const Color(0xFF0C0C0E)));
    c.drawRect(Rect.fromLTWH(lx - 5, ground - H * 0.6, 10, 6),
        _p(const Color(0xFF0C0C0E)));
    if (dark || w.time == DayTime.morning) {
      final lamp = Offset(lx, ground - H * 0.55);
      c.drawCircle(
          lamp,
          H * 0.28,
          Paint()
            ..shader = RadialGradient(
                    colors: [const Color(0x55FFD9A0), const Color(0x00FFD9A0)])
                .createShader(Rect.fromCircle(center: lamp, radius: H * 0.28)));
      c.drawCircle(lamp, 2.4, _p(const Color(0xFFFFE8C0)));
    }

    // Passers-by in silhouette.
    final count = w.open ? 3 : 1;
    for (var i = 0; i < count; i++) {
      final dir = i.isEven ? 1.0 : -1.0;
      final speed = 0.5 + i * 0.22;
      var k = (t * speed * 4 + i * 0.37) % 1;
      if (dir < 0) k = 1 - k;
      final x = -20 + k * (W + 40);
      final y = H - 3 - i * 2.0;
      final s = H / 150;
      final step = moving ? math.sin(t * math.pi * 2 * 160 * speed) : 0.0;
      final sil = _p(const Color(0xFF07070A));
      c.drawCircle(Offset(x, y - 32 * s), 4.2 * s, sil);
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x - 5 * s, y - 27 * s, 10 * s, 15 * s),
              Radius.circular(3 * s)),
          sil);
      c.drawLine(
          Offset(x - 2 * s, y - 13 * s),
          Offset(x - 2 * s + step * 3 * s, y),
          Paint()
            ..color = const Color(0xFF07070A)
            ..strokeWidth = 3 * s
            ..strokeCap = StrokeCap.round);
      c.drawLine(
          Offset(x + 2 * s, y - 13 * s),
          Offset(x + 2 * s - step * 3 * s, y),
          Paint()
            ..color = const Color(0xFF07070A)
            ..strokeWidth = 3 * s
            ..strokeCap = StrokeCap.round);
      if (w.rain && i == 0) {
        // An umbrella.
        c.drawArc(
            Rect.fromCenter(
                center: Offset(x, y - 38 * s), width: 26 * s, height: 16 * s),
            math.pi,
            math.pi,
            true,
            _p(const Color(0xFF1A1A20)));
      }
    }

    // Rain.
    if (w.rain) {
      final rain = Paint()
        ..color = const Color(0x33B8C4D0)
        ..strokeWidth = 1;
      final rr = math.Random(9);
      for (var i = 0; i < 70; i++) {
        final x0 = rr.nextDouble() * (W + 40);
        final sp = 0.6 + rr.nextDouble() * 0.6;
        final y0 = ((rr.nextDouble() + t * 40 * sp) % 1) * (H + 20) - 10;
        c.drawLine(Offset(x0 - y0 * 0.15, y0),
            Offset(x0 - y0 * 0.15 - 2.5, y0 + 9), rain);
      }
    }
    // Vignette.
    c.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
              radius: 0.95,
              colors: [const Color(0x00000000), const Color(0x88000000)],
              stops: const [0.55, 1]).createShader(Offset.zero & size));
  }

  @override
  bool shouldRepaint(covariant _ShopPainter old) =>
      old.t != t ||
      old.w.name != w.name ||
      old.w.time != w.time ||
      old.w.open != w.open;
}

/// A clipped bay tree in a planter, seen from the street.
void drawPlantSide(Canvas c, Offset base, double s) {
  final pot = Rect.fromCenter(
      center: base.translate(0, -5 * s), width: 11 * s, height: 10 * s);
  c.drawRect(pot, Paint()..color = const Color(0xFF151413));
  c.drawLine(
      base.translate(0, -10 * s),
      base.translate(0, -18 * s),
      Paint()
        ..color = const Color(0xFF2A1E16)
        ..strokeWidth = 1.4 * s);
  c.drawCircle(base.translate(0, -24 * s), 8 * s,
      Paint()..color = const Color(0xFF1E3326));
  c.drawCircle(base.translate(-2 * s, -26 * s), 4 * s,
      Paint()..color = const Color(0xFF2A4532));
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
    ? const Color(0xFFC9A55B)
    : Color(int.parse('FF${hex.substring(1)}', radix: 16));

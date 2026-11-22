import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'scene_art.dart';

/// Small drawn pictures used across the app: staff portraits, dishes and
/// kitchen equipment. All code-drawn, matching the restaurant scene.

Mood moodFromMorale(double morale) => morale >= 60
    ? Mood.happy
    : (morale >= 40
        ? Mood.neutral
        : (morale >= 25 ? Mood.annoyed : Mood.angry));

Color moodColor(double v) => v >= 60
    ? const Color(0xFF74C08F)
    : (v >= 40 ? const Color(0xFFE2AE52) : const Color(0xFFE3705C));

/// A monogram portrait: initials on a dark plate tinted by role, with a
/// thin ring in the colour of their mood and a small role badge.
class StaffAvatar extends StatelessWidget {
  final int seed;
  final String role;
  final String name;
  final double size;
  final double? morale;
  const StaffAvatar(
      {super.key,
      required this.seed,
      required this.role,
      this.name = '',
      this.size = 44,
      this.morale});

  static const _tint = {
    'headChef': Color(0xFF7A5A2E),
    'lineCook': Color(0xFF6B4A35),
    'prepCook': Color(0xFF5E4A3A),
    'server': Color(0xFF3B4A5E),
    'cashier': Color(0xFF3E5A48),
    'dishwasher': Color(0xFF3A5560),
    'cleaner': Color(0xFF4E4A44),
    'manager': Color(0xFF5A3E5E),
    'owner': Color(0xFF2E5E68),
  };

  @override
  Widget build(BuildContext context) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? '?'
        : (parts.first[0] + (parts.length > 1 ? parts.last[0] : ''))
            .toUpperCase();
    final tint = _tint[role] ?? const Color(0xFF4A4038);
    final ring = morale == null ? const Color(0xFF39322B) : moodColor(morale!);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.4),
                  radius: 1.0,
                  colors: [
                    Color.lerp(tint, Colors.white, 0.12)!,
                    Color.lerp(tint, Colors.black, 0.35)!
                  ]),
              border: Border.all(color: ring, width: size > 50 ? 2.5 : 2),
            ),
            alignment: Alignment.center,
            child: Text(initials,
                style: TextStyle(
                    fontFamily: 'Playfair',
                    fontWeight: FontWeight.w700,
                    fontSize: size * 0.36,
                    color: const Color(0xFFF1E8D8),
                    height: 1)),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: size * 0.42,
              height: size * 0.42,
              decoration: BoxDecoration(
                  color: const Color(0xFF1C1916),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF39322B))),
              alignment: Alignment.center,
              child: Icon(_roleIcon(role),
                  size: size * 0.24, color: const Color(0xFFC9A55B)),
            ),
          ),
        ]),
      ),
    );
  }

  static IconData _roleIcon(String r) => switch (r) {
        'headChef' || 'lineCook' || 'prepCook' => Icons.restaurant,
        'server' => Icons.room_service_outlined,
        'cashier' => Icons.point_of_sale_outlined,
        'dishwasher' => Icons.water_drop_outlined,
        'cleaner' => Icons.cleaning_services_outlined,
        'manager' => Icons.workspace_premium_outlined,
        _ => Icons.person_outline,
      };
}

/// A ring gauge with the value in the middle (morale, happiness).
class RingGauge extends StatelessWidget {
  final double value; // 0..100
  final double size;
  const RingGauge(this.value, {super.key, this.size = 52});
  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox.square(
            dimension: size,
            child: CircularProgressIndicator(
              value: (value / 100).clamp(0, 1),
              strokeWidth: size * 0.08,
              backgroundColor: const Color(0xFF28231F),
              valueColor: AlwaysStoppedAnimation(moodColor(value)),
            ),
          ),
          Text('${value.round()}',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: size * 0.3,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      );
}

/// A plate (or bowl, or cup) with the dish on it.
class DishPicture extends StatelessWidget {
  final String dishId;
  final double size;
  final bool off;
  const DishPicture(
      {super.key, required this.dishId, this.size = 44, this.off = false});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: ColorFiltered(
          // Slightly muted so the food sits in the dark palette.
          colorFilter: const ColorFilter.matrix([
            0.72, 0.2, 0.04, 0, -8, //
            0.1, 0.78, 0.08, 0, -8, //
            0.08, 0.16, 0.7, 0, -8, //
            0, 0, 0, 1, 0,
          ]),
          child: Opacity(
            opacity: off ? 0.45 : 1,
            child: CustomPaint(
                size: Size.square(size), painter: _DishPainter(dishId)),
          ),
        ),
      );
}

class _DishPainter extends CustomPainter {
  final String id;
  _DishPainter(this.id);

  bool has(List<String> words) => words.any(id.contains);

  @override
  void paint(Canvas c, Size size) {
    final r = size.width / 2;
    final o = Offset(r, r);
    final p = Paint();
    Paint col(Color x) => p..color = x;
    final rnd = math.Random(id.hashCode);
    void dots(Offset at, double spread, int n, Color color, double sz) {
      for (var i = 0; i < n; i++) {
        final a = rnd.nextDouble() * math.pi * 2;
        final d = rnd.nextDouble() * spread;
        c.drawCircle(
            at + Offset(math.cos(a) * d, math.sin(a) * d), sz, col(color));
      }
    }

    final drink = has(['espresso', 'tea', 'chai', 'agua']);
    final bowl = has([
      'soup',
      'minestrone',
      'curry',
      'butter_chicken',
      'palak',
      'chana',
      'chilli',
      'mapo',
      'dal',
      'kung_pao',
      'sweet_sour',
      'beans',
      'gulab'
    ]);
    // Shadow.
    c.drawOval(
        Rect.fromCenter(
            center: o.translate(0, r * 0.12), width: r * 1.9, height: r * 1.7),
        col(const Color(0x22000000)));
    if (drink) {
      // Cup on a saucer.
      c.drawOval(
          Rect.fromCenter(
              center: o.translate(0, r * 0.35),
              width: r * 1.7,
              height: r * 0.7),
          col(Colors.white));
      final cup = Rect.fromCenter(
          center: o.translate(0, -r * 0.05), width: r * 1.1, height: r * 1.0);
      final isGlass = has(['agua']);
      c.drawRRect(
          RRect.fromRectAndCorners(cup,
              bottomLeft: Radius.circular(r * 0.35),
              bottomRight: Radius.circular(r * 0.35)),
          col(isGlass ? const Color(0xCCB3E5FC) : Colors.white));
      final liquid = has(['espresso'])
          ? const Color(0xFF4E342E)
          : has(['chai'])
              ? const Color(0xFFC8A27A)
              : has(['agua'])
                  ? const Color(0xFFFF6F91)
                  : const Color(0xFFC5E1A5);
      c.drawOval(
          Rect.fromCenter(
              center: cup.topCenter.translate(0, r * 0.12),
              width: cup.width * 0.86,
              height: r * 0.26),
          col(liquid));
      c.drawArc(
          Rect.fromCenter(
              center: cup.centerRight, width: r * 0.5, height: r * 0.45),
          -math.pi / 2,
          math.pi,
          false,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.12);
      return;
    }
    // Plate or bowl.
    c.drawCircle(
        o, r * 0.92, col(bowl ? const Color(0xFFF5EBDD) : Colors.white));
    c.drawCircle(
        o,
        r * 0.92,
        Paint()
          ..color = const Color(0x22000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    c.drawCircle(
        o,
        r * 0.68,
        Paint()
          ..color = const Color(0x14000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    if (bowl) {
      final sauce = has(['palak'])
          ? const Color(0xFF4F772D)
          : has(['dal', 'chana'])
              ? const Color(0xFFE9A03B)
              : has(['gulab'])
                  ? const Color(0xFFE9C46A)
                  : has(['hot_sour', 'mapo', 'chilli', 'tortilla'])
                      ? const Color(0xFFB23A1E)
                      : has(['minestrone'])
                          ? const Color(0xFFD1603D)
                          : has(['beans'])
                              ? const Color(0xFF6B3E26)
                              : const Color(0xFFE76F51);
      c.drawCircle(o, r * 0.62, col(sauce));
      if (has(['gulab'])) {
        dots(o, r * 0.25, 3, const Color(0xFF7F3B08), r * 0.2);
      } else {
        dots(o, r * 0.4, 6, const Color(0xFFFFF1D6), r * 0.1);
        dots(o, r * 0.4, 3, const Color(0xFF52B788), r * 0.07);
      }
      c.drawCircle(o.translate(-r * 0.2, -r * 0.2), r * 0.12,
          col(const Color(0x55FFFFFF)));
      return;
    }
    if (has(['pizza', 'margherita'])) {
      c.drawCircle(o, r * 0.7, col(const Color(0xFFE0A458)));
      c.drawCircle(o, r * 0.6, col(const Color(0xFFD62828)));
      dots(o, r * 0.42, 7, const Color(0xFFFFF3D6), r * 0.12);
      if (has(['salami'])) {
        dots(o, r * 0.4, 5, const Color(0xFF9A031E), r * 0.11);
      }
      dots(o, r * 0.4, 3, const Color(0xFF2D6A4F), r * 0.06);
      for (var i = 0; i < 3; i++) {
        final a = i * math.pi * 2 / 3;
        c.drawLine(
            o,
            o + Offset(math.cos(a), math.sin(a)) * r * 0.7,
            Paint()
              ..color = const Color(0x55000000)
              ..strokeWidth = 0.8);
      }
      return;
    }
    if (has(['bolognese', 'chow_mein'])) {
      final noodle = Paint()
        ..color = const Color(0xFFF2CC8F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 7; i++) {
        final path = Path()
          ..moveTo(o.dx - r * 0.5, o.dy - r * 0.35 + i * r * 0.11);
        for (var k = 1; k <= 6; k++) {
          path.lineTo(
              o.dx - r * 0.5 + k * r * 0.17,
              o.dy -
                  r * 0.35 +
                  i * r * 0.11 +
                  (k.isEven ? -r * 0.06 : r * 0.06));
        }
        c.drawPath(path, noodle);
      }
      if (has(['bolognese'])) {
        c.drawCircle(
            o.translate(0, -r * 0.05), r * 0.28, col(const Color(0xFFA4161A)));
        dots(o.translate(0, -r * 0.05), r * 0.15, 4, const Color(0xFF6A040F),
            r * 0.06);
      } else {
        dots(o, r * 0.4, 5, const Color(0xFF52B788), r * 0.07);
        dots(o, r * 0.4, 4, const Color(0xFFE76F51), r * 0.06);
      }
      return;
    }
    if (has(['rice', 'risotto', 'biryani'])) {
      final base = has(['risotto'])
          ? const Color(0xFFF1DDB0)
          : has(['biryani', 'mx_rice'])
              ? const Color(0xFFF4A259)
              : has(['fried'])
                  ? const Color(0xFFE9C46A)
                  : has(['jeera'])
                      ? const Color(0xFFFFF1D0)
                      : const Color(0xFFFFFBF0);
      c.drawCircle(o, r * 0.55, col(base));
      dots(o, r * 0.5, 22, const Color(0xFFFFFFFF), r * 0.04);
      if (has(['risotto'])) {
        dots(o, r * 0.4, 6, const Color(0xFF8D6E63), r * 0.09);
      }
      if (has(['fried', 'biryani', 'risotto'])) {
        dots(o, r * 0.45, 6, const Color(0xFF6A994E), r * 0.07);
        dots(o, r * 0.45, 4, const Color(0xFFE76F51), r * 0.07);
      }
      return;
    }
    if (has(['taco', 'burrito', 'quesadilla', 'nachos'])) {
      if (has(['nachos'])) {
        for (var i = 0; i < 8; i++) {
          final a = rnd.nextDouble() * math.pi * 2;
          final at = o + Offset(math.cos(a), math.sin(a)) * r * 0.3;
          final tri = Path()
            ..moveTo(at.dx, at.dy - r * 0.2)
            ..lineTo(at.dx + r * 0.18, at.dy + r * 0.14)
            ..lineTo(at.dx - r * 0.18, at.dy + r * 0.14)
            ..close();
          c.drawPath(tri, col(const Color(0xFFF4C430)));
        }
        dots(o, r * 0.3, 5, const Color(0xFFFFB703), r * 0.1);
        return;
      }
      final shell =
          has(['burrito']) ? const Color(0xFFF1DCA7) : const Color(0xFFE9C46A);
      for (var i = 0; i < (has(['burrito']) ? 1 : 2); i++) {
        final dy = has(['burrito']) ? 0.0 : (i == 0 ? -r * 0.2 : r * 0.2);
        final rr = Rect.fromCenter(
            center: o.translate(0, dy), width: r * 1.2, height: r * 0.5);
        c.drawRRect(
            RRect.fromRectAndRadius(rr, Radius.circular(r * 0.25)), col(shell));
        if (!has(['burrito'])) {
          dots(o.translate(0, dy - r * 0.05), r * 0.35, 5,
              const Color(0xFF52B788), r * 0.07);
          dots(o.translate(0, dy - r * 0.05), r * 0.35, 3,
              const Color(0xFFD62828), r * 0.07);
        } else {
          c.drawLine(
              rr.topLeft.translate(r * 0.3, 0),
              rr.bottomLeft.translate(r * 0.3, 0),
              Paint()
                ..color = const Color(0x33000000)
                ..strokeWidth = 1);
        }
      }
      return;
    }
    if (has(['fish'])) {
      final body = Rect.fromCenter(center: o, width: r * 1.1, height: r * 0.55);
      c.drawOval(body, col(const Color(0xFFE9C9A0)));
      final tail = Path()
        ..moveTo(body.right - r * 0.05, o.dy)
        ..lineTo(body.right + r * 0.25, o.dy - r * 0.22)
        ..lineTo(body.right + r * 0.25, o.dy + r * 0.22)
        ..close();
      c.drawPath(tail, col(const Color(0xFFD4A373)));
      c.drawCircle(body.centerLeft.translate(r * 0.15, -r * 0.05), r * 0.05,
          col(const Color(0xFF2A2420)));
      c.drawCircle(o.translate(-r * 0.4, r * 0.4), r * 0.14,
          col(const Color(0xFFFFE066)));
      return;
    }
    if (has(['tandoori', 'tikka', 'kung_pao', 'sweet_sour'])) {
      final meat =
          has(['paneer']) ? const Color(0xFFF7D9A8) : const Color(0xFFD9480F);
      for (var i = 0; i < 5; i++) {
        final a = i * math.pi * 2 / 5;
        final at = o + Offset(math.cos(a), math.sin(a)) * r * 0.3;
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: at, width: r * 0.36, height: r * 0.3),
                Radius.circular(r * 0.08)),
            col(meat));
      }
      dots(o, r * 0.5, 4, const Color(0xFF6A994E), r * 0.07);
      c.drawCircle(o.translate(r * 0.42, r * 0.42), r * 0.12,
          col(const Color(0xFFB7E4C7)));
      return;
    }
    if (has(['salad', 'greens', 'caprese', 'guacamole'])) {
      if (has(['caprese'])) {
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3;
          c.drawCircle(
              o + Offset(math.cos(a), math.sin(a)) * r * 0.38,
              r * 0.2,
              col(i.isEven
                  ? const Color(0xFFD62828)
                  : const Color(0xFFFFFBF0)));
        }
        dots(o, r * 0.2, 4, const Color(0xFF2D6A4F), r * 0.08);
        return;
      }
      final green = has(['guacamole'])
          ? const Color(0xFF90BE6D)
          : const Color(0xFF52B788);
      c.drawCircle(o, r * 0.55, col(green));
      dots(o, r * 0.45, 8, const Color(0xFF2D6A4F), r * 0.12);
      if (!has(['greens'])) {
        dots(o, r * 0.4, 4, const Color(0xFFE63946), r * 0.08);
      }
      if (has(['guacamole'])) {
        for (var i = 0; i < 4; i++) {
          final a = i * math.pi / 2 + 0.4;
          final at = o + Offset(math.cos(a), math.sin(a)) * r * 0.72;
          c.drawCircle(at, r * 0.14, col(const Color(0xFFF4C430)));
        }
      }
      return;
    }
    if (has(['bread', 'bruschetta', 'naan'])) {
      for (var i = 0; i < 3; i++) {
        final at =
            o.translate((i - 1) * r * 0.36, (i.isEven ? -1 : 1) * r * 0.1);
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: at, width: r * 0.42, height: r * 0.62),
                Radius.circular(r * 0.14)),
            col(const Color(0xFFDDA15E)));
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: at, width: r * 0.3, height: r * 0.48),
                Radius.circular(r * 0.1)),
            col(has(['bruschetta'])
                ? const Color(0xFFD62828)
                : const Color(0xFFF3D5A0)));
        if (has(['bruschetta'])) {
          dots(at, r * 0.12, 2, const Color(0xFF2D6A4F), r * 0.05);
        }
      }
      return;
    }
    if (has(['tiramisu'])) {
      final slice = Rect.fromCenter(center: o, width: r * 0.9, height: r * 0.8);
      final layers = [
        const Color(0xFF6F4518),
        const Color(0xFFF3E9DC),
        const Color(0xFF8B5E34),
        const Color(0xFFF3E9DC)
      ];
      for (var i = 0; i < 4; i++) {
        c.drawRect(
            Rect.fromLTWH(slice.left, slice.top + i * slice.height / 4,
                slice.width, slice.height / 4),
            col(layers[i]));
      }
      dots(slice.topCenter.translate(0, r * 0.06), r * 0.3, 8,
          const Color(0xFF5C3D2E), r * 0.04);
      return;
    }
    if (has(['ice_cream'])) {
      c.drawCircle(o, r * 0.42, col(const Color(0xFFE9C46A)));
      c.drawCircle(
          o.translate(0, -r * 0.05), r * 0.3, col(const Color(0xFFFFF1D0)));
      c.drawCircle(o.translate(r * 0.1, -r * 0.2), r * 0.08,
          col(const Color(0xFFD62828)));
      return;
    }
    if (has(['churros'])) {
      for (var i = 0; i < 3; i++) {
        c.save();
        c.translate(o.dx, o.dy);
        c.rotate(-0.5 + i * 0.4);
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset.zero, width: r * 1.2, height: r * 0.2),
                Radius.circular(r * 0.1)),
            col(const Color(0xFFC9852B)));
        c.restore();
      }
      c.drawCircle(o.translate(r * 0.4, r * 0.4), r * 0.16,
          col(const Color(0xFF4E342E)));
      return;
    }
    // Rolls, dumplings, samosas and other small bites.
    final bite = has(['samosa'])
        ? const Color(0xFFE0A458)
        : (has(['dumpling'])
            ? const Color(0xFFFFF4E0)
            : const Color(0xFFE9C46A));
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2 + 0.6;
      final at = o + Offset(math.cos(a), math.sin(a)) * r * 0.32;
      if (has(['samosa'])) {
        final tri = Path()
          ..moveTo(at.dx, at.dy - r * 0.2)
          ..lineTo(at.dx + r * 0.2, at.dy + r * 0.16)
          ..lineTo(at.dx - r * 0.2, at.dy + r * 0.16)
          ..close();
        c.drawPath(tri, col(bite));
      } else if (has(['spring'])) {
        c.save();
        c.translate(at.dx, at.dy);
        c.rotate(a);
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset.zero, width: r * 0.5, height: r * 0.2),
                Radius.circular(r * 0.1)),
            col(bite));
        c.restore();
      } else {
        c.drawCircle(at, r * 0.2, col(bite));
        c.drawArc(
            Rect.fromCircle(center: at, radius: r * 0.2),
            math.pi,
            math.pi,
            false,
            Paint()
              ..color = const Color(0x33000000)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8);
      }
    }
    c.drawCircle(o, r * 0.13, col(const Color(0xFFB23A1E)));
  }

  @override
  bool shouldRepaint(covariant _DishPainter old) => old.id != id;
}

/// A picture of a piece of kitchen equipment.
class EquipmentPicture extends StatelessWidget {
  final String type;
  final String? station;
  final double size;
  final bool broken;
  const EquipmentPicture(
      {super.key,
      required this.type,
      this.station,
      this.size = 44,
      this.broken = false});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CustomPaint(
            size: Size.square(size),
            painter: _EquipPainter(type, station, broken)),
      );
}

class _EquipPainter extends CustomPainter {
  final String type;
  final String? station;
  final bool broken;
  _EquipPainter(this.type, this.station, this.broken);
  @override
  void paint(Canvas c, Size size) {
    final w = size.width;
    final box = Rect.fromLTWH(w * 0.08, w * 0.12, w * 0.84, w * 0.76);
    c.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(w * 0.22)),
        Paint()..color = const Color(0xFF28231F));
    if (station != null) {
      drawStation(c, box.deflate(w * 0.06), station!,
          cap: station == 'cold'
              ? 3
              : (station == 'wok' || station == 'tandoor' ? 2 : 4),
          used: broken ? 0 : 2,
          down: broken,
          t: 0.4);
      return;
    }
    switch (type) {
      case 'eq_fridge':
      case 'eq_freezer':
        drawFridge(
            c,
            Rect.fromCenter(
                center: box.center, width: w * 0.5, height: w * 0.72));
        if (type == 'eq_freezer') {
          drawIcon(c, Icons.ac_unit, box.center.translate(0, -w * 0.18),
              w * 0.2, const Color(0xFF4FC3F7));
        }
      case 'eq_shelving':
        for (var i = 0; i < 3; i++) {
          drawShelf(
              c,
              Rect.fromLTWH(box.left + w * 0.08,
                  box.top + w * (0.24 + i * 0.22), box.width - w * 0.16, 4));
        }
      case 'eq_dish_machine':
        final r = box.deflate(w * 0.08);
        c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(w * 0.06)),
            Paint()..color = const Color(0xFFB0BEC5));
        c.drawRRect(
            RRect.fromRectAndRadius(
                r.deflate(w * 0.1), Radius.circular(w * 0.05)),
            Paint()..color = const Color(0xFF4FC3F7));
        for (var i = 0; i < 4; i++) {
          c.drawCircle(
              r.center +
                  Offset((i - 1.5) * w * 0.1, (i.isEven ? -1 : 1) * w * 0.06),
              w * 0.045,
              Paint()
                ..color = Colors.white
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1);
        }
      case 'eq_hood':
        final path = Path()
          ..moveTo(box.left + w * 0.25, box.top + w * 0.1)
          ..lineTo(box.right - w * 0.25, box.top + w * 0.1)
          ..lineTo(box.right, box.bottom - w * 0.2)
          ..lineTo(box.left, box.bottom - w * 0.2)
          ..close();
        c.drawPath(path, Paint()..color = const Color(0xFF90A4AE));
        for (var i = 0; i < 4; i++) {
          final y = box.bottom - w * 0.26 - i * w * 0.08;
          c.drawLine(
              Offset(box.left + w * 0.15, y),
              Offset(box.right - w * 0.15, y),
              Paint()
                ..color = const Color(0xFF607D8B)
                ..strokeWidth = 1);
        }
      case 'eq_pos':
        final r = Rect.fromCenter(
            center: box.center.translate(0, w * 0.08),
            width: w * 0.66,
            height: w * 0.4);
        c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(w * 0.05)),
            Paint()..color = const Color(0xFF37474F));
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(r.left + w * 0.08, r.top - w * 0.22,
                    r.width - w * 0.16, w * 0.22),
                Radius.circular(w * 0.03)),
            Paint()..color = const Color(0xFF263238));
        c.drawRect(
            Rect.fromLTWH(r.left + w * 0.12, r.top - w * 0.18,
                r.width - w * 0.24, w * 0.12),
            Paint()
              ..color =
                  broken ? const Color(0xFF455A64) : const Color(0xFF7FD1AE));
        for (var i = 0; i < 6; i++) {
          c.drawRect(
              Rect.fromLTWH(r.left + w * 0.08 + (i % 3) * w * 0.17,
                  r.top + w * 0.08 + (i ~/ 3) * w * 0.12, w * 0.12, w * 0.07),
              Paint()..color = const Color(0xFFB0BEC5));
        }
      case 'eq_ac':
        final r = Rect.fromCenter(
            center: box.center, width: w * 0.78, height: w * 0.34);
        c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(w * 0.08)),
            Paint()..color = Colors.white);
        c.drawRRect(
            RRect.fromRectAndRadius(r, Radius.circular(w * 0.08)),
            Paint()
              ..color = const Color(0x33000000)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1);
        for (var i = 0; i < 3; i++) {
          c.drawLine(
              Offset(r.left + w * 0.1, r.bottom - w * 0.06 - i * w * 0.05),
              Offset(r.right - w * 0.1, r.bottom - w * 0.06 - i * w * 0.05),
              Paint()
                ..color = const Color(0xFF90A4AE)
                ..strokeWidth = 1);
        }
      case 'eq_generator':
        final r = Rect.fromCenter(
            center: box.center.translate(0, w * 0.04),
            width: w * 0.7,
            height: w * 0.48);
        c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(w * 0.06)),
            Paint()..color = const Color(0xFFF4C430));
        drawIcon(c, Icons.bolt, r.center, w * 0.3, const Color(0xFF37474F));
      default:
        drawIcon(c, Icons.build, box.center, w * 0.4, const Color(0xFF607D8B));
    }
    if (broken) {
      drawIcon(c, Icons.warning_rounded, Offset(w * 0.8, w * 0.2), w * 0.3,
          const Color(0xFFC24A3A));
    }
  }

  @override
  bool shouldRepaint(covariant _EquipPainter old) =>
      old.type != type || old.broken != broken;
}

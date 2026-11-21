import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Flat cartoon drawing primitives for the restaurant scene. Everything is drawn
/// in code so the look stays consistent and needs no image assets.

enum Mood { happy, neutral, annoyed, angry }

enum Hat { none, chef, headChef, cap }

/// How a character looks. Built once per person from a stable seed.
class Look {
  final Color skin, hair, shirt;
  final Color? apron;
  final Hat hat;
  final bool longHair;
  final bool tie;
  final bool star; // the owner's badge
  const Look(
      {required this.skin,
      required this.hair,
      required this.shirt,
      this.apron,
      this.hat = Hat.none,
      this.longHair = false,
      this.tie = false,
      this.star = false});

  static const skins = [
    Color(0xFFF6D3B3),
    Color(0xFFE8B98F),
    Color(0xFFC98E62),
    Color(0xFF9C6644),
    Color(0xFF6E4630),
  ];
  static const hairs = [
    Color(0xFF2B1D16),
    Color(0xFF4A3021),
    Color(0xFF8A5A33),
    Color(0xFFD9A55B),
    Color(0xFF1E1E24),
    Color(0xFFB0473A),
    Color(0xFF9C9C9C),
  ];
  static const shirts = [
    Color(0xFF4F86C6),
    Color(0xFFE07A5F),
    Color(0xFF81B29A),
    Color(0xFFF2CC8F),
    Color(0xFF9B72CF),
    Color(0xFF3D5A80),
    Color(0xFFEE6C4D),
    Color(0xFF5FA8D3),
    Color(0xFFCB997E),
    Color(0xFF6D9F71),
  ];

  factory Look.customer(int seed, {bool critic = false}) {
    final r = math.Random(seed * 7919 + 13);
    return Look(
      skin: skins[r.nextInt(skins.length)],
      hair: hairs[r.nextInt(hairs.length)],
      shirt:
          critic ? const Color(0xFF2E2A2A) : shirts[r.nextInt(shirts.length)],
      longHair: r.nextBool(),
      hat: critic ? Hat.cap : Hat.none,
    );
  }

  factory Look.staff(int seed, String role) {
    final r = math.Random(seed * 104729 + 7);
    final skin = skins[r.nextInt(skins.length)];
    final hair = hairs[r.nextInt(hairs.length - 1)];
    final long = r.nextBool();
    return switch (role) {
      'headChef' => Look(
          skin: skin,
          hair: hair,
          shirt: Colors.white,
          apron: const Color(0xFFE6E6E6),
          hat: Hat.headChef,
          longHair: long),
      'lineCook' || 'prepCook' => Look(
          skin: skin,
          hair: hair,
          shirt: Colors.white,
          apron: const Color(0xFF5C6B73),
          hat: Hat.chef,
          longHair: long),
      'server' => Look(
          skin: skin,
          hair: hair,
          shirt: Colors.white,
          apron: const Color(0xFF2E2E33),
          longHair: long),
      'cashier' => Look(
          skin: skin,
          hair: hair,
          shirt: const Color(0xFF3E8E5A),
          apron: const Color(0xFF2F6B45),
          longHair: long),
      'manager' => Look(
          skin: skin,
          hair: hair,
          shirt: const Color(0xFF34495E),
          tie: true,
          longHair: long),
      'dishwasher' => Look(
          skin: skin,
          hair: hair,
          shirt: const Color(0xFF7FB3D5),
          apron: const Color(0xFF2E6F95),
          hat: Hat.cap,
          longHair: long),
      _ => Look(
          skin: skin,
          hair: hair,
          shirt: const Color(0xFFB8B8B8),
          apron: const Color(0xFF8E8E8E),
          longHair: long),
    };
  }

  static const owner = Look(
      skin: Color(0xFFE8B98F),
      hair: Color(0xFF3A2618),
      shirt: Color(0xFF7A3FA0),
      apron: Color(0xFF5B2C79),
      star: true);
}

final _paint = Paint()..isAntiAlias = true;

Paint _fill(Color c) => _paint
  ..color = c
  ..style = PaintingStyle.fill
  ..strokeWidth = 0
  ..shader = null
  ..maskFilter = null;

Paint _stroke(Color c, double w) => _paint
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..shader = null
  ..maskFilter = null;

/// A small person seen from the front and a little above (chibi style).
/// [p] is where their feet touch the floor.
void drawPerson(Canvas c, Offset p, Look look,
    {double s = 1,
    double bob = 0,
    Mood mood = Mood.happy,
    bool seated = false,
    bool carryPlate = false,
    bool carryDirty = false,
    bool notepad = false,
    double alpha = 1,
    Color? foodColor}) {
  c.save();
  c.translate(p.dx, p.dy);
  c.scale(s);
  if (alpha < 1) {
    c.saveLayer(const Rect.fromLTWH(-20, -40, 40, 50),
        Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
  }
  // Shadow.
  c.drawOval(
      const Rect.fromLTWH(-8, -2.5, 16, 5), _fill(const Color(0x2A000000)));
  final y = -bob;
  // Legs (hidden when seated).
  if (!seated) {
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(-4.5, y - 6, 3.6, 6), const Radius.circular(1.5)),
        _fill(const Color(0xFF3A3A44)));
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0.9, y - 6, 3.6, 6), const Radius.circular(1.5)),
        _fill(const Color(0xFF3A3A44)));
  }
  final bodyTop = y - (seated ? 13 : 17);
  final body = RRect.fromRectAndCorners(Rect.fromLTWH(-7, bodyTop, 14, 12),
      topLeft: const Radius.circular(6),
      topRight: const Radius.circular(6),
      bottomLeft: const Radius.circular(3),
      bottomRight: const Radius.circular(3));
  c.drawRRect(body, _fill(look.shirt));
  if (look.apron != null) {
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(-5, bodyTop + 4, 10, 8), const Radius.circular(2)),
        _fill(look.apron!));
  }
  if (look.tie) {
    final t = Path()
      ..moveTo(0, bodyTop + 1)
      ..lineTo(1.6, bodyTop + 4)
      ..lineTo(0, bodyTop + 9)
      ..lineTo(-1.6, bodyTop + 4)
      ..close();
    c.drawPath(t, _fill(const Color(0xFFC0392B)));
  }
  if (look.star) {
    _drawStar(c, Offset(-3.6, bodyTop + 4.4), 2.4, const Color(0xFFFFD166));
  }
  // Arms.
  final armY = bodyTop + 3;
  if (carryPlate || carryDirty || notepad) {
    c.drawLine(
        Offset(5.5, armY + 1), Offset(9, armY - 2), _stroke(look.shirt, 3));
    if (carryPlate || carryDirty) {
      c.drawOval(
          Rect.fromCenter(
              center: Offset(11, armY - 3.5), width: 10, height: 4.5),
          _fill(Colors.white));
      c.drawOval(
          Rect.fromCenter(
              center: Offset(11, armY - 3.5), width: 10, height: 4.5),
          _stroke(const Color(0x33000000), 0.6));
      c.drawCircle(
          Offset(11, armY - 4),
          2,
          _fill(carryDirty
              ? const Color(0xFF9E8F7A)
              : (foodColor ?? const Color(0xFFE07A5F))));
    } else {
      c.drawRect(Rect.fromLTWH(7.5, armY - 6, 5, 6.5), _fill(Colors.white));
      c.drawLine(Offset(8.4, armY - 4.2), Offset(11.6, armY - 4.2),
          _stroke(const Color(0xFF9AA5B1), 0.6));
      c.drawLine(Offset(8.4, armY - 2.6), Offset(11.6, armY - 2.6),
          _stroke(const Color(0xFF9AA5B1), 0.6));
    }
  } else {
    c.drawLine(
        Offset(6.2, armY), Offset(7.4, armY + 6), _stroke(look.shirt, 3));
  }
  c.drawLine(
      Offset(-6.2, armY), Offset(-7.4, armY + 6), _stroke(look.shirt, 3));
  // Head.
  final hc = Offset(0, bodyTop - 6);
  if (look.longHair) {
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: hc.translate(0, 2.5), width: 14.5, height: 12),
            const Radius.circular(5)),
        _fill(look.hair));
  }
  c.drawCircle(hc, 6.8, _fill(look.skin));
  // Hair cap.
  c.drawArc(Rect.fromCircle(center: hc.translate(0, -0.6), radius: 7.1),
      math.pi * 1.02, math.pi * 0.96, true, _fill(look.hair));
  c.drawCircle(hc.translate(2.8, -3.6), 2.4, _fill(look.hair));
  // Face.
  final eyeY = hc.dy + 0.8;
  final dark = const Color(0xFF2A2420);
  if (mood == Mood.angry) {
    c.drawLine(
        Offset(-3.6, eyeY - 2.6), Offset(-1.2, eyeY - 1.6), _stroke(dark, 1));
    c.drawLine(
        Offset(3.6, eyeY - 2.6), Offset(1.2, eyeY - 1.6), _stroke(dark, 1));
  }
  c.drawCircle(Offset(-2.4, eyeY), 0.95, _fill(dark));
  c.drawCircle(Offset(2.4, eyeY), 0.95, _fill(dark));
  final mouth = Path();
  switch (mood) {
    case Mood.happy:
      mouth
        ..moveTo(-1.8, eyeY + 2.2)
        ..quadraticBezierTo(0, eyeY + 4, 1.8, eyeY + 2.2);
    case Mood.neutral:
      mouth
        ..moveTo(-1.4, eyeY + 2.8)
        ..lineTo(1.4, eyeY + 2.8);
    case Mood.annoyed:
    case Mood.angry:
      mouth
        ..moveTo(-1.8, eyeY + 3.4)
        ..quadraticBezierTo(0, eyeY + 1.8, 1.8, eyeY + 3.4);
  }
  c.drawPath(mouth, _stroke(dark, 0.9));
  if (mood == Mood.angry || mood == Mood.happy) {
    final cheek =
        mood == Mood.angry ? const Color(0x88E74C3C) : const Color(0x44FF8A80);
    c.drawCircle(Offset(-4.2, eyeY + 1.8), 1.3, _fill(cheek));
    c.drawCircle(Offset(4.2, eyeY + 1.8), 1.3, _fill(cheek));
  }
  // Hats.
  switch (look.hat) {
    case Hat.chef:
    case Hat.headChef:
      final tall = look.hat == Hat.headChef ? 5.0 : 2.0;
      c.drawRect(Rect.fromLTWH(-5, hc.dy - 8.5, 10, 3), _fill(Colors.white));
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(-5.5, hc.dy - 12 - tall, 11, 5 + tall),
              const Radius.circular(3)),
          _fill(Colors.white));
      for (final dx in [-4.0, 0.0, 4.0]) {
        c.drawCircle(Offset(dx, hc.dy - 12.5 - tall), 3.4, _fill(Colors.white));
      }
      c.drawLine(Offset(-5, hc.dy - 8.6), Offset(5, hc.dy - 8.6),
          _stroke(const Color(0x22000000), 0.6));
    case Hat.cap:
      c.drawArc(
          Rect.fromCircle(center: hc.translate(0, -1.2), radius: 7.2),
          math.pi,
          math.pi,
          true,
          _fill(look.shirt == const Color(0xFF2E2A2A)
              ? const Color(0xFFB03A2E)
              : look.apron ?? look.shirt));
    case Hat.none:
      break;
  }
  if (alpha < 1) c.restore();
  c.restore();
}

void _drawStar(Canvas c, Offset o, double r, Color color) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final a = -math.pi / 2 + i * math.pi / 5;
    final rr = i.isEven ? r : r * 0.45;
    final pt = o + Offset(math.cos(a) * rr, math.sin(a) * rr);
    if (i == 0) {
      path.moveTo(pt.dx, pt.dy);
    } else {
      path.lineTo(pt.dx, pt.dy);
    }
  }
  path.close();
  c.drawPath(path, _fill(color));
}

void drawStar(Canvas c, Offset o, double r, Color color) =>
    _drawStar(c, o, r, color);

/// A round café table seen from slightly above.
void drawTable(Canvas c, Rect r, {bool dirty = false, bool selected = false}) {
  final rr = RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * 0.35));
  c.drawRRect(rr.shift(const Offset(0, 3)), _fill(const Color(0x26000000)));
  c.drawRRect(rr, _fill(const Color(0xFFB07A4F)));
  final top = RRect.fromRectAndRadius(
      r.deflate(2), Radius.circular(r.shortestSide * 0.3));
  c.drawRRect(top, _fill(const Color(0xFFFFFBF2)));
  // Tablecloth check pattern hint.
  c.drawRRect(
      top.deflate(r.shortestSide * 0.16), _stroke(const Color(0x22C8462F), 1));
  if (selected) {
    c.drawRRect(rr.inflate(4), _stroke(const Color(0xFF7A3FA0), 3));
  }
  if (dirty) {
    final rnd = math.Random(r.left.toInt() * 31 + r.top.toInt());
    for (var i = 0; i < 3; i++) {
      final o = Offset(r.left + r.width * (0.25 + 0.25 * i),
          r.center.dy + (i.isEven ? -3 : 3));
      c.drawOval(
          Rect.fromCenter(center: o, width: 9, height: 6), _fill(Colors.white));
      c.drawOval(Rect.fromCenter(center: o, width: 9, height: 6),
          _stroke(const Color(0x33000000), 0.6));
      c.drawCircle(o.translate(rnd.nextDouble() * 2 - 1, 0), 1.4,
          _fill(const Color(0xFFA68A64)));
    }
    c.drawCircle(
        Offset(r.right - 6, r.top + 5), 1.2, _fill(const Color(0xFF8D7B68)));
  }
}

void drawChair(Canvas c, Offset o, {bool top = true}) {
  final r = Rect.fromCenter(center: o, width: 12, height: 9);
  c.drawRRect(
      RRect.fromRectAndRadius(
          r.shift(const Offset(0, 1.5)), const Radius.circular(3)),
      _fill(const Color(0x22000000)));
  c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)),
      _fill(const Color(0xFF8C5A3C)));
  final back = top
      ? Rect.fromLTWH(r.left, r.top - 2, r.width, 3)
      : Rect.fromLTWH(r.left, r.bottom - 1, r.width, 3);
  c.drawRRect(RRect.fromRectAndRadius(back, const Radius.circular(1.5)),
      _fill(const Color(0xFF6B4226)));
}

/// A plate of food; [left] 0..1 shrinks the food while people eat.
void drawPlate(Canvas c, Offset o, Color food, {double left = 1}) {
  c.drawOval(
      Rect.fromCenter(center: o, width: 11, height: 7), _fill(Colors.white));
  c.drawOval(Rect.fromCenter(center: o, width: 11, height: 7),
      _stroke(const Color(0x30000000), 0.6));
  if (left > 0.05) {
    c.drawOval(
        Rect.fromCenter(
            center: o.translate(0, -0.4),
            width: 7 * left.clamp(0.3, 1),
            height: 4.4 * left.clamp(0.3, 1)),
        _fill(food));
    c.drawCircle(
        o.translate(1.2, -1.2), 0.9 * left, _fill(const Color(0x99FFFFFF)));
  }
}

const foodColors = [
  Color(0xFFE07A5F),
  Color(0xFFF2CC8F),
  Color(0xFF81B29A),
  Color(0xFFD62828),
  Color(0xFFF4A259),
  Color(0xFFBC6C25),
  Color(0xFF9A031E),
];

/// One cooking station on the back counter.
void drawStation(Canvas c, Rect r, String type,
    {required int cap,
    required int used,
    required bool down,
    required double t}) {
  final body = RRect.fromRectAndRadius(r, const Radius.circular(5));
  c.drawRRect(body.shift(const Offset(0, 2)), _fill(const Color(0x40000000)));
  c.drawRRect(
      body, _fill(down ? const Color(0xFF5E5552) : const Color(0xFF9AA3AB)));
  c.drawRRect(body.deflate(2),
      _fill(down ? const Color(0xFF4A4240) : const Color(0xFF7D868E)));
  final slots = math.max(1, cap);
  final cols = slots <= 2 ? slots : (slots <= 4 ? 2 : 3);
  final rows = (slots / cols).ceil();
  final cw = (r.width - 6) / cols, ch = (r.height - 6) / rows;
  for (var i = 0; i < slots; i++) {
    final col = i % cols, row = i ~/ cols;
    final cell =
        Rect.fromLTWH(r.left + 3 + col * cw, r.top + 3 + row * ch, cw, ch);
    final on = !down && i < used;
    final rad = math.min(cell.width, cell.height) * 0.36;
    final o = cell.center;
    switch (type) {
      case 'oven':
      case 'tandoor':
        final win = RRect.fromRectAndRadius(
            cell.deflate(2.2), Radius.circular(type == 'tandoor' ? rad : 2));
        c.drawRRect(win, _fill(const Color(0xFF2B2B2B)));
        if (on) {
          final glow = 0.75 + 0.25 * math.sin(t * 6 + i);
          c.drawRRect(
              win.deflate(1.2),
              _fill(Color.lerp(
                  const Color(0xFFB34700), const Color(0xFFFFA62B), glow)!));
        }
      case 'cold':
        c.drawRRect(
            RRect.fromRectAndRadius(cell.deflate(2), const Radius.circular(2)),
            _fill(const Color(0xFFE9D8B4)));
        if (on) {
          c.drawCircle(o.translate(-rad * 0.4, 0), rad * 0.42,
              _fill(const Color(0xFF6A994E)));
          c.drawCircle(o.translate(rad * 0.45, rad * 0.2), rad * 0.32,
              _fill(const Color(0xFFD62828)));
        }
      case 'fryer':
        c.drawRRect(
            RRect.fromRectAndRadius(cell.deflate(2), const Radius.circular(2)),
            _fill(const Color(0xFF3B3B3B)));
        c.drawRRect(
            RRect.fromRectAndRadius(
                cell.deflate(3.2), const Radius.circular(2)),
            _fill(on ? const Color(0xFFE9B949) : const Color(0xFFB8952F)));
        if (on) {
          for (var k = 0; k < 3; k++) {
            final ph = (t * 3 + k * 0.33 + i) % 1;
            c.drawCircle(
                o.translate((k - 1) * rad * 0.55, rad * 0.4 - ph * rad * 0.8),
                1 + ph,
                _stroke(const Color(0xAAFFF3C4), 0.6));
          }
        }
      case 'grill':
        c.drawRRect(
            RRect.fromRectAndRadius(cell.deflate(2), const Radius.circular(2)),
            _fill(const Color(0xFF2E2E2E)));
        if (on) {
          _flames(c, o.translate(0, rad * 0.3), rad * 0.9, t + i, gas: false);
        }
        for (var k = -1; k <= 1; k++) {
          c.drawLine(
              Offset(cell.left + 3, o.dy + k * rad * 0.55),
              Offset(cell.right - 3, o.dy + k * rad * 0.55),
              _stroke(const Color(0xFF8A8A8A), 1));
        }
      default: // stove, wok
        c.drawCircle(o, rad, _fill(const Color(0xFF2F2F2F)));
        c.drawCircle(o, rad * 0.7, _stroke(const Color(0xFF5A5A5A), 1));
        if (on) {
          _flames(c, o, rad, t + i * 0.7);
          if (type == 'wok') {
            c.drawOval(
                Rect.fromCenter(
                    center: o.translate(0, -1),
                    width: rad * 2.1,
                    height: rad * 1.5),
                _fill(const Color(0xFF3A3A3A)));
            c.drawOval(
                Rect.fromCenter(
                    center: o.translate(0, -1.5),
                    width: rad * 1.4,
                    height: rad * 0.8),
                _fill(const Color(0xFFE9A03B)));
          } else {
            c.drawCircle(
                o.translate(0, -1), rad * 0.82, _fill(const Color(0xFF8E9AA6)));
            c.drawCircle(
                o.translate(0, -1), rad * 0.6, _fill(const Color(0xFFCC6B49)));
          }
        }
    }
  }
  if (down) {
    // Warning sign.
    final w = Path()
      ..moveTo(r.center.dx, r.top - 9)
      ..lineTo(r.center.dx + 8, r.top + 4)
      ..lineTo(r.center.dx - 8, r.top + 4)
      ..close();
    c.drawPath(w, _fill(const Color(0xFFFFC145)));
    c.drawPath(w, _stroke(const Color(0xFF2A2420), 1));
    c.drawLine(Offset(r.center.dx, r.top - 4), Offset(r.center.dx, r.top),
        _stroke(const Color(0xFF2A2420), 1.4));
    c.drawCircle(
        Offset(r.center.dx, r.top + 2), 0.8, _fill(const Color(0xFF2A2420)));
  }
}

void _flames(Canvas c, Offset o, double rad, double t, {bool gas = true}) {
  for (var k = 0; k < 6; k++) {
    final a = k * math.pi / 3 + t * 0.6;
    final flick = 0.65 + 0.35 * math.sin(t * 14 + k * 2.1);
    final p = o + Offset(math.cos(a), math.sin(a)) * rad * 0.82;
    final tip =
        o + Offset(math.cos(a), math.sin(a)) * rad * (0.82 + 0.4 * flick);
    final path = Path()
      ..moveTo(p.dx - math.sin(a) * 2, p.dy + math.cos(a) * 2)
      ..quadraticBezierTo(
          tip.dx, tip.dy, p.dx + math.sin(a) * 2, p.dy - math.cos(a) * 2)
      ..close();
    c.drawPath(
        path,
        _fill(gas
            ? Color.lerp(
                const Color(0xFF1E88E5), const Color(0xFF4FC3F7), flick)!
            : Color.lerp(
                const Color(0xFFE85D04), const Color(0xFFFFBA08), flick)!));
  }
}

/// Draws an icon glyph from its font (Material icons are bundled with the app).
final _iconCache = <int, TextPainter>{};
void drawIcon(
    Canvas c, IconData icon, Offset center, double size, Color color) {
  final key = Object.hash(icon.codePoint, size.round(), color.toARGB32());
  final tp = _iconCache.putIfAbsent(key, () {
    if (_iconCache.length > 300) _iconCache.clear();
    return TextPainter(
      text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
              fontSize: size,
              color: color,
              height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
  });
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
}

final _textCache = <int, TextPainter>{};
TextPainter labelPainter(String text, double size, Color color,
    {FontWeight weight = FontWeight.w800, bool shadow = true}) {
  final key = Object.hash(text, size, color.toARGB32(), weight, shadow);
  return _textCache.putIfAbsent(key, () {
    if (_textCache.length > 400) _textCache.clear();
    return TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              fontSize: size,
              fontWeight: weight,
              color: color,
              height: 1,
              shadows: shadow
                  ? const [Shadow(color: Color(0xCCFFFFFF), blurRadius: 3)]
                  : null)),
      textDirection: TextDirection.ltr,
    )..layout();
  });
}

/// Speech bubble with an icon and a patience ring; returns its hit rect.
Rect drawBubble(Canvas c, Offset o, IconData icon,
    {double share = 0,
    bool ring = true,
    bool owner = false,
    bool faded = false,
    double pulse = 0,
    double r = 12}) {
  final ringColor = share < 0.5
      ? const Color(0xFF3E8E5A)
      : (share < 0.8 ? const Color(0xFFC98A1B) : const Color(0xFFC24A3A));
  final rr = r * (1 + 0.08 * pulse);
  final alpha = faded ? 0.5 : 1.0;
  c.drawCircle(
      o.translate(0, 1.5), rr, _fill(Color.fromRGBO(0, 0, 0, 0.16 * alpha)));
  final tail = Path()
    ..moveTo(o.dx - 4, o.dy + rr * 0.7)
    ..lineTo(o.dx - 1, o.dy + rr + 5)
    ..lineTo(o.dx + 3, o.dy + rr * 0.75)
    ..close();
  final bg = owner ? const Color(0xFF7A3FA0) : Colors.white;
  c.drawPath(tail, _fill(bg.withValues(alpha: alpha)));
  c.drawCircle(o, rr, _fill(bg.withValues(alpha: alpha)));
  if (ring) {
    c.drawCircle(o, rr - 1.4,
        _stroke(const Color(0x22000000).withValues(alpha: 0.13 * alpha), 2.6));
    c.drawArc(
        Rect.fromCircle(center: o, radius: rr - 1.4),
        -math.pi / 2,
        math.pi * 2 * (1 - share.clamp(0, 1)),
        false,
        _stroke(
            (owner ? Colors.white : ringColor).withValues(alpha: alpha), 2.6));
  }
  drawIcon(
      c,
      icon,
      o,
      rr * 1.05,
      (owner ? Colors.white : const Color(0xFF2A2420))
          .withValues(alpha: alpha));
  return Rect.fromCircle(center: o, radius: rr + 6);
}

/// Static parts of the room, recorded once per layout.
ui.Picture recordPicture(Size size, void Function(Canvas c) paint) {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec, Offset.zero & size);
  paint(c);
  return rec.endRecording();
}

void drawPlanks(Canvas c, Rect r) {
  c.drawRect(r, _fill(const Color(0xFFE3C9A1)));
  const h = 14.0;
  var row = 0;
  for (var y = r.top; y < r.bottom; y += h, row++) {
    final band = Rect.fromLTRB(r.left, y, r.right, math.min(r.bottom, y + h));
    if (row.isOdd) c.drawRect(band, _fill(const Color(0xFFDDC096)));
    c.drawLine(Offset(r.left, y), Offset(r.right, y),
        _stroke(const Color(0x22704C2B), 1));
    final off = (row * 37) % 70;
    for (var x = r.left + off; x < r.right; x += 70) {
      c.drawLine(Offset(x, y), Offset(x, math.min(r.bottom, y + h)),
          _stroke(const Color(0x1A704C2B), 1));
    }
  }
}

void drawTiles(Canvas c, Rect r) {
  c.drawRect(r, _fill(const Color(0xFFDCE3E6)));
  const s = 16.0;
  var i = 0;
  for (var y = r.top; y < r.bottom; y += s) {
    var j = i;
    for (var x = r.left; x < r.right; x += s) {
      if (j.isOdd) {
        c.drawRect(Rect.fromLTWH(x, y, s, s).intersect(r),
            _fill(const Color(0xFFC9D3D8)));
      }
      j++;
    }
    i++;
  }
}

void drawPlant(Canvas c, Offset o, {double s = 1}) {
  c.drawOval(
      Rect.fromCenter(
          center: o.translate(0, 6 * s), width: 18 * s, height: 6 * s),
      _fill(const Color(0x22000000)));
  c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: o.translate(0, 2 * s), width: 13 * s, height: 10 * s),
          Radius.circular(3 * s)),
      _fill(const Color(0xFFC0703F)));
  for (final (dx, dy, rr, col) in [
    (-5.0, -6.0, 6.0, const Color(0xFF4C956C)),
    (5.0, -7.0, 6.0, const Color(0xFF2C6E49)),
    (0.0, -11.0, 6.5, const Color(0xFF6A994E)),
    (0.0, -4.0, 5.0, const Color(0xFF3E7C59)),
  ]) {
    c.drawCircle(o.translate(dx * s, dy * s), rr * s, _fill(col));
  }
}

void drawCoin(Canvas c, Offset o, double r, double spin) {
  final w = r * 2 * (0.35 + 0.65 * spin.abs());
  c.drawOval(Rect.fromCenter(center: o, width: w, height: r * 2),
      _fill(const Color(0xFFB7791F)));
  c.drawOval(
      Rect.fromCenter(
          center: o.translate(-0.4, -0.4), width: w * 0.8, height: r * 1.6),
      _fill(const Color(0xFFF6C344)));
  c.drawCircle(o.translate(-r * 0.25, -r * 0.35), r * 0.22,
      _fill(const Color(0xCCFFFFFF)));
}

void drawHeart(Canvas c, Offset o, double s, Color color) {
  final p = Path()
    ..moveTo(o.dx, o.dy + s * 0.9)
    ..cubicTo(o.dx - s * 1.4, o.dy - s * 0.1, o.dx - s * 0.6, o.dy - s * 1.2,
        o.dx, o.dy - s * 0.4)
    ..cubicTo(o.dx + s * 0.6, o.dy - s * 1.2, o.dx + s * 1.4, o.dy - s * 0.1,
        o.dx, o.dy + s * 0.9)
    ..close();
  c.drawPath(p, _fill(color));
}

void fillCircle(Canvas c, Offset o, double r, Color color) =>
    c.drawCircle(o, r, _fill(color));
void fillRRect(Canvas c, RRect r, Color color) => c.drawRRect(r, _fill(color));
void strokeRRect(Canvas c, RRect r, Color color, double w) =>
    c.drawRRect(r, _stroke(color, w));
void line(Canvas c, Offset a, Offset b, Color color, double w) =>
    c.drawLine(a, b, _stroke(color, w));

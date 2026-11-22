import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Drawing primitives for the restaurant scene: an overhead plan of a
/// restaurant at night. Everything is drawn in code, in a restrained palette
/// (walnut, slate, linen, steel, brass) so it reads as a grown-up sim rather
/// than a cartoon.

enum Mood { happy, neutral, annoyed, angry }

enum Hat { none, chef, headChef, cap }

/// How a person looks from above. Built once per person from a stable seed.
class Look {
  final Color skin, hair, shirt;
  final Color? arms; // sleeves, when different from the body
  final Color? apron;
  final Hat hat;
  final bool longHair;
  final bool tie;
  final bool star; // the owner
  final Color? hands;
  const Look(
      {required this.skin,
      required this.hair,
      required this.shirt,
      this.arms,
      this.apron,
      this.hat = Hat.none,
      this.longHair = false,
      this.tie = false,
      this.star = false,
      this.hands});

  static const skins = [
    Color(0xFFE9C7A6),
    Color(0xFFD4A47C),
    Color(0xFFB57F58),
    Color(0xFF8A5A3C),
    Color(0xFF5E3D29),
  ];
  static const hairs = [
    Color(0xFF1B1513),
    Color(0xFF2E211A),
    Color(0xFF4A3426),
    Color(0xFF6E4A2E),
    Color(0xFF9C7A4E),
    Color(0xFF7A3B25),
    Color(0xFF8E8A86),
  ];
  static const clothes = [
    Color(0xFF2E3A59), // navy
    Color(0xFF3A3A40), // charcoal
    Color(0xFF6B2D3A), // burgundy
    Color(0xFF556B3A), // olive
    Color(0xFFA67C52), // camel
    Color(0xFFCFC2A6), // stone
    Color(0xFF4A6278), // slate blue
    Color(0xFF2F4A3A), // forest
    Color(0xFF4E3A5A), // plum
    Color(0xFF8A4B2F), // rust
    Color(0xFF1F1F24), // black
    Color(0xFF7D7366), // taupe
  ];

  factory Look.customer(int seed, {bool critic = false}) {
    final r = math.Random(seed * 7919 + 13);
    return Look(
      skin: skins[r.nextInt(skins.length)],
      hair: hairs[r.nextInt(hairs.length)],
      shirt:
          critic ? const Color(0xFF151517) : clothes[r.nextInt(clothes.length)],
      longHair: r.nextInt(3) == 0,
      tie: critic,
    );
  }

  factory Look.staff(int seed, String role) {
    final r = math.Random(seed * 104729 + 7);
    final skin = skins[r.nextInt(skins.length)];
    final hair = hairs[r.nextInt(hairs.length - 1)];
    final long = r.nextInt(3) == 0;
    const whites = Color(0xFFE9E4DA);
    return switch (role) {
      'headChef' => Look(
          skin: skin, hair: hair, shirt: whites, hat: Hat.headChef, tie: true),
      'lineCook' || 'prepCook' => Look(
          skin: skin,
          hair: hair,
          shirt: whites,
          apron: const Color(0xFF3A3F44),
          hat: Hat.chef),
      'server' => Look(
          skin: skin,
          hair: hair,
          shirt: const Color(0xFF1C1C20),
          arms: const Color(0xFFE6E1D7),
          longHair: long),
      'cashier' => Look(
          skin: skin,
          hair: hair,
          shirt: const Color(0xFF2B2E35),
          longHair: long),
      'manager' =>
        Look(skin: skin, hair: hair, shirt: const Color(0xFF26324A), tie: true),
      'dishwasher' => Look(
          skin: skin,
          hair: hair,
          shirt: const Color(0xFF5E666C),
          apron: const Color(0xFF2E4E60),
          hands: const Color(0xFFE0B23A)),
      _ => Look(
          skin: skin,
          hair: hair,
          shirt: const Color(0xFF474C52),
          hands: const Color(0xFFE0B23A),
          longHair: long),
    };
  }

  static const rider = Look(
      skin: Color(0xFFB57F58),
      hair: Color(0xFF1B1513),
      shirt: Color(0xFF1E5E5A),
      hat: Hat.cap);

  static const owner = Look(
      skin: Color(0xFFD4A47C),
      hair: Color(0xFF2E211A),
      shirt: Color(0xFF22262D),
      tie: true,
      star: true);
}

final _paint = Paint()..isAntiAlias = true;

Paint _fill(Color c) => _paint
  ..color = c
  ..style = PaintingStyle.fill
  ..strokeWidth = 0
  ..shader = null
  ..maskFilter = null
  ..blendMode = BlendMode.srcOver;

Paint _stroke(Color c, double w) => _paint
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..shader = null
  ..maskFilter = null
  ..blendMode = BlendMode.srcOver;

/// A person seen from directly above: shoulders, arms and head (hair or a
/// chef's toque), turned to face [facing] (radians; 0 = right, π/2 = down).
/// [p] is the centre of their shoulders.
void drawPerson(Canvas c, Offset p, Look look,
    {double s = 1,
    double bob = 0,
    Mood mood = Mood.neutral,
    bool seated = false,
    bool carryPlate = false,
    bool carryDirty = false,
    bool notepad = false,
    double alpha = 1,
    double walk = -1,
    bool mop = false,
    bool box = false,
    double facing = math.pi / 2,
    Color? foodColor}) {
  c.save();
  c.translate(p.dx, p.dy);
  c.scale(s);
  if (alpha < 1) {
    c.saveLayer(const Rect.fromLTWH(-20, -20, 40, 40),
        Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
  }
  // Soft shadow on the floor.
  c.drawOval(
      const Rect.fromLTWH(-8.5, -4.2, 18, 12), _fill(const Color(0x40000000)));
  if (mood == Mood.angry) {
    c.drawCircle(
        const Offset(0, 1), 10.5, _stroke(const Color(0x99E3705C), 1.4));
  }
  if (look.star) {
    c.drawCircle(
        const Offset(0, 1), 10.5, _stroke(const Color(0xCC3F8C9A), 1.6));
  }
  c.rotate(facing - math.pi / 2); // local +y is the way they face
  final stride = walk < 0 ? 0.0 : math.sin(walk);
  final sleeve = look.arms ?? look.shirt;
  final hand = look.hands ?? look.skin;
  // Delivery box on the back.
  if (box) {
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-7, -12, 14, 9), const Radius.circular(1.5)),
        _fill(const Color(0xFF1E8A80)));
    c.drawRect(
        const Rect.fromLTWH(-7, -8.5, 14, 1.4), _fill(const Color(0xFF14605A)));
  }
  // Arms: swing while walking, reach forward when seated or carrying.
  final reach = seated || carryPlate || carryDirty || notepad || mop;
  for (final side in [-1.0, 1.0]) {
    final swing = reach ? 4.5 : stride * 2.6 * side;
    final o = Offset(side * 6.8, 0.6 + swing);
    c.drawOval(
        Rect.fromCenter(center: o, width: 3.6, height: 6.4), _fill(sleeve));
    c.drawCircle(
        o.translate(0, reach ? 3.4 : 3.0 + swing * 0.1), 1.5, _fill(hand));
  }
  // Shoulders and body.
  final body = Rect.fromCenter(center: Offset.zero, width: 14.5, height: 8.6);
  c.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(4.3)),
      _fill(look.shirt));
  // Light from above catches the back of the shoulders.
  c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-6.4, -4.1, 12.8, 2.6), const Radius.circular(2)),
      _fill(Colors.white.withValues(alpha: 0.07)));
  if (look.apron != null) {
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-4.5, 1.2, 9, 3.2), const Radius.circular(1.4)),
        _fill(look.apron!));
  }
  if (look.hat == Hat.headChef || look.hat == Hat.chef) {
    // Double-breasted buttons.
    for (final y in [0.6, 2.6]) {
      c.drawCircle(Offset(-1.6, y), 0.55, _fill(const Color(0xFF6E6A64)));
      c.drawCircle(Offset(1.6, y), 0.55, _fill(const Color(0xFF6E6A64)));
    }
  }
  if (look.tie) {
    c.drawRect(Rect.fromLTWH(-0.7, 1.4, 1.4, 3),
        _fill(look.star ? const Color(0xFF3F8C9A) : const Color(0xFF7A2430)));
  }
  // Head.
  const head = Offset(0, -0.4);
  switch (look.hat) {
    case Hat.chef:
    case Hat.headChef:
      final r = look.hat == Hat.headChef ? 5.6 : 5.0;
      c.drawCircle(head.translate(0, 1.0), 3.6, _fill(look.skin));
      c.drawCircle(head, r, _fill(const Color(0xFFF2EFE9)));
      c.drawCircle(head, r * 0.66, _stroke(const Color(0x22000000), 0.7));
      if (look.hat == Hat.headChef) {
        c.drawCircle(head, r * 0.36, _stroke(const Color(0x18000000), 0.7));
      }
    case Hat.cap:
      c.drawCircle(head, 4.9, _fill(const Color(0xFF15191C)));
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(-3.4, 2.4, 6.8, 2.2), const Radius.circular(1)),
          _fill(const Color(0xFF2A3036)));
      c.drawLine(const Offset(-3, -1), const Offset(3, -1),
          _stroke(const Color(0x33FFFFFF), 0.8));
    case Hat.none:
      if (look.longHair) {
        c.drawOval(
            Rect.fromCenter(
                center: head.translate(0, -1.8), width: 10.4, height: 8.2),
            _fill(look.hair));
      }
      c.drawCircle(head.translate(0, 1.0), 4.3, _fill(look.skin));
      c.drawCircle(head.translate(0, -0.7), 4.5, _fill(look.hair));
      c.drawArc(
          Rect.fromCircle(center: head.translate(0, -0.7), radius: 3.2),
          math.pi * 1.1,
          math.pi * 0.5,
          false,
          _stroke(Colors.white.withValues(alpha: 0.10), 1));
  }
  // What they carry, in front of them.
  if (carryPlate || carryDirty) {
    final o = const Offset(3.5, 8.5);
    c.drawCircle(o.translate(0.6, 0.8), 4.2, _fill(const Color(0x33000000)));
    c.drawCircle(o, 4.2, _fill(const Color(0xFFF4F1EA)));
    c.drawCircle(o, 2.8, _fill(Colors.white));
    if (carryDirty) {
      c.drawCircle(
          o.translate(-0.6, 0.6), 4.2, _stroke(const Color(0x55000000), 0.6));
      c.drawCircle(o.translate(0.5, -0.3), 1.2, _fill(const Color(0xFF8A7A66)));
    } else {
      c.drawCircle(o, 2.1, _fill(foodColor ?? const Color(0xFFA63D2F)));
    }
  } else if (notepad) {
    c.drawRect(const Rect.fromLTWH(1.5, 5.5, 4.5, 5.5),
        _fill(const Color(0xFFF2EEE6)));
    c.drawLine(const Offset(2.3, 7.2), const Offset(5.2, 7.2),
        _stroke(const Color(0xFF8D8A85), 0.5));
    c.drawLine(const Offset(2.3, 8.8), const Offset(5.2, 8.8),
        _stroke(const Color(0xFF8D8A85), 0.5));
  } else if (mop) {
    final sweep = walk < 0 ? 0.0 : math.sin(walk * 0.5) * 2.5;
    c.drawLine(const Offset(5, 4), Offset(4 + sweep, 15),
        _stroke(const Color(0xFF8A7560), 1.2));
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(4 + sweep, 16.5), width: 9, height: 3.2),
            const Radius.circular(1.5)),
        _fill(const Color(0xFF9AA4AA)));
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

/// A linen-covered table seen from above.
void drawTable(Canvas c, Rect r, {bool dirty = false, bool selected = false}) {
  final rr = RRect.fromRectAndRadius(r, const Radius.circular(5));
  c.drawRRect(rr.shift(const Offset(1.5, 3)), _fill(const Color(0x66000000)));
  c.drawRRect(rr.inflate(1.2), _fill(const Color(0xFFD8D1C4))); // cloth drop
  c.drawRRect(rr, _fill(const Color(0xFFEDE7DC)));
  c.drawRRect(rr.deflate(2.2), _stroke(const Color(0x14000000), 0.8));
  if (selected) {
    c.drawRRect(rr.inflate(5), _stroke(const Color(0xFF3F8C9A), 2));
  }
  if (dirty) {
    final rnd = math.Random(r.left.toInt() * 31 + r.top.toInt());
    for (var i = 0; i < 3; i++) {
      final o = Offset(r.left + r.width * (0.25 + 0.25 * i),
          r.center.dy + (i.isEven ? -3 : 3));
      c.drawCircle(o, 4.2, _fill(const Color(0xFFF4F1EA)));
      c.drawCircle(o, 4.2, _stroke(const Color(0x33000000), 0.6));
      c.drawCircle(o.translate(rnd.nextDouble() * 2 - 1, 0.5), 1.6,
          _fill(const Color(0xFF9C8B74)));
    }
    // A crumpled napkin and a wine stain.
    c.drawCircle(
        Offset(r.right - 6, r.top + 5), 2.4, _fill(const Color(0xFFCFC7B9)));
    c.drawCircle(
        Offset(r.left + 7, r.bottom - 5), 2.2, _fill(const Color(0x557A2430)));
  }
}

/// An upholstered chair; [top] means it sits above the table (back to the wall side).
void drawChair(Canvas c, Offset o, {bool top = true}) {
  final r = Rect.fromCenter(center: o, width: 12, height: 10);
  c.drawRRect(
      RRect.fromRectAndRadius(
          r.shift(const Offset(1, 2)), const Radius.circular(3)),
      _fill(const Color(0x55000000)));
  c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)),
      _fill(const Color(0xFF3B2A22)));
  c.drawRRect(RRect.fromRectAndRadius(r.deflate(2), const Radius.circular(2)),
      _fill(const Color(0xFF4A352A)));
  final back = top
      ? Rect.fromLTWH(r.left - 0.5, r.top - 2.4, r.width + 1, 3.2)
      : Rect.fromLTWH(r.left - 0.5, r.bottom - 0.8, r.width + 1, 3.2);
  c.drawRRect(RRect.fromRectAndRadius(back, const Radius.circular(1.6)),
      _fill(const Color(0xFF261A14)));
}

/// A plate of food from above; [left] 0..1 shrinks the food while people eat.
void drawPlate(Canvas c, Offset o, Color food, {double left = 1}) {
  c.drawCircle(o.translate(0.6, 1), 5, _fill(const Color(0x33000000)));
  c.drawCircle(o, 5, _fill(const Color(0xFFF4F1EA)));
  c.drawCircle(o, 3.5, _fill(Colors.white));
  if (left > 0.05) {
    final k = left.clamp(0.25, 1.0);
    c.drawCircle(o, 2.6 * k, _fill(food));
    c.drawCircle(
        o.translate(-0.7, -0.7), 0.8 * k, _fill(const Color(0x55FFFFFF)));
  }
}

const foodColors = [
  Color(0xFFA63D2F), // tomato
  Color(0xFFC8913A), // golden
  Color(0xFF4F6B3A), // basil
  Color(0xFF7A2430), // red wine sauce
  Color(0xFFD19A2B), // saffron
  Color(0xFF6B4630), // braise
  Color(0xFFD9C7A0), // cream
];

/// One cooking station on the back counter, in stainless steel.
void drawStation(Canvas c, Rect r, String type,
    {required int cap,
    required int used,
    required bool down,
    required double t}) {
  final body = RRect.fromRectAndRadius(r, const Radius.circular(3));
  c.drawRRect(body.shift(const Offset(1, 3)), _fill(const Color(0x66000000)));
  c.drawRRect(
      body, _fill(down ? const Color(0xFF3A3533) : const Color(0xFF59636A)));
  c.drawRRect(body.deflate(1.6),
      _fill(down ? const Color(0xFF2C2826) : const Color(0xFF7A858C)));
  c.drawLine(Offset(r.left + 3, r.top + 2.4), Offset(r.right - 3, r.top + 2.4),
      _stroke(Colors.white.withValues(alpha: 0.18), 0.8));
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
            cell.deflate(2.2), Radius.circular(type == 'tandoor' ? rad : 1.5));
        c.drawRRect(win, _fill(const Color(0xFF151515)));
        if (on) {
          final glow = 0.75 + 0.25 * math.sin(t * 6 + i);
          c.drawRRect(
              win.deflate(1.2),
              _fill(Color.lerp(
                  const Color(0xFF7A2E08), const Color(0xFFE0861F), glow)!));
        }
      case 'cold':
        c.drawRRect(
            RRect.fromRectAndRadius(
                cell.deflate(2), const Radius.circular(1.5)),
            _fill(const Color(0xFFB08A5E)));
        if (on) {
          c.drawCircle(o.translate(-rad * 0.4, 0), rad * 0.4,
              _fill(const Color(0xFF4F6B3A)));
          c.drawCircle(o.translate(rad * 0.45, rad * 0.2), rad * 0.3,
              _fill(const Color(0xFFA63D2F)));
        }
      case 'fryer':
        c.drawRRect(
            RRect.fromRectAndRadius(
                cell.deflate(2), const Radius.circular(1.5)),
            _fill(const Color(0xFF222222)));
        c.drawRRect(
            RRect.fromRectAndRadius(
                cell.deflate(3.2), const Radius.circular(1.5)),
            _fill(on ? const Color(0xFFC9962E) : const Color(0xFF8A6A22)));
        if (on) {
          for (var k = 0; k < 3; k++) {
            final ph = (t * 3 + k * 0.33 + i) % 1;
            c.drawCircle(
                o.translate((k - 1) * rad * 0.55, rad * 0.4 - ph * rad * 0.8),
                0.8 + ph,
                _stroke(const Color(0x88FFF0C0), 0.6));
          }
        }
      case 'grill':
        c.drawRRect(
            RRect.fromRectAndRadius(
                cell.deflate(2), const Radius.circular(1.5)),
            _fill(const Color(0xFF1C1C1C)));
        if (on) {
          _flames(c, o.translate(0, rad * 0.3), rad * 0.9, t + i, gas: false);
        }
        for (var k = -1; k <= 1; k++) {
          c.drawLine(
              Offset(cell.left + 3, o.dy + k * rad * 0.55),
              Offset(cell.right - 3, o.dy + k * rad * 0.55),
              _stroke(const Color(0xFF5E5E5E), 1));
        }
      default: // stove, wok
        c.drawCircle(o, rad, _fill(const Color(0xFF1E1E1E)));
        c.drawCircle(o, rad * 0.7, _stroke(const Color(0xFF3E3E3E), 1));
        if (on) {
          _flames(c, o, rad, t + i * 0.7);
          if (type == 'wok') {
            c.drawCircle(o, rad * 0.95, _fill(const Color(0xFF2B2B2B)));
            c.drawCircle(o.translate(0, -0.5), rad * 0.6,
                _fill(const Color(0xFFB07A2A)));
          } else {
            c.drawCircle(o, rad * 0.82, _fill(const Color(0xFF8E989F)));
            c.drawCircle(o, rad * 0.6, _fill(const Color(0xFF8A3A26)));
          }
        }
    }
  }
  if (down) {
    c.drawRRect(body.inflate(1.5), _stroke(const Color(0xCCE3705C), 1.4));
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
      ..moveTo(p.dx - math.sin(a) * 1.8, p.dy + math.cos(a) * 1.8)
      ..quadraticBezierTo(
          tip.dx, tip.dy, p.dx + math.sin(a) * 1.8, p.dy - math.cos(a) * 1.8)
      ..close();
    c.drawPath(
        path,
        _fill(gas
            ? Color.lerp(
                const Color(0xFF1565C0), const Color(0xFF4FC3F7), flick)!
            : Color.lerp(
                const Color(0xFFB34700), const Color(0xFFF2A33A), flick)!));
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
    {FontWeight weight = FontWeight.w700,
    bool shadow = true,
    bool serif = false,
    double spacing = 0}) {
  final key =
      Object.hash(text, size, color.toARGB32(), weight, shadow, serif, spacing);
  return _textCache.putIfAbsent(key, () {
    if (_textCache.length > 400) _textCache.clear();
    return TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              fontFamily: serif ? 'Playfair' : 'Inter',
              fontSize: size,
              fontWeight: weight,
              color: color,
              letterSpacing: spacing,
              height: 1,
              shadows: shadow
                  ? const [Shadow(color: Color(0xCC000000), blurRadius: 4)]
                  : null)),
      textDirection: TextDirection.ltr,
    )..layout();
  });
}

/// A dark glass bubble with an icon and a patience ring; returns its hit rect.
Rect drawBubble(Canvas c, Offset o, IconData icon,
    {double share = 0,
    bool ring = true,
    bool owner = false,
    bool faded = false,
    double pulse = 0,
    double r = 12}) {
  final ringColor = share < 0.5
      ? const Color(0xFF74C08F)
      : (share < 0.8 ? const Color(0xFFE2AE52) : const Color(0xFFE3705C));
  final rr = r * (1 + 0.06 * pulse);
  final alpha = faded ? 0.45 : 1.0;
  c.drawCircle(
      o.translate(0, 2), rr + 1, _fill(Color.fromRGBO(0, 0, 0, 0.45 * alpha)));
  final bg = owner ? const Color(0xFF3F8C9A) : const Color(0xFF171411);
  c.drawCircle(o, rr, _fill(bg.withValues(alpha: 0.94 * alpha)));
  c.drawCircle(
      o, rr, _stroke(const Color(0xFF5C4F3A).withValues(alpha: alpha), 0.8));
  if (ring) {
    c.drawCircle(o, rr - 2.2,
        _stroke(const Color(0xFF3A332C).withValues(alpha: alpha), 2.2));
    c.drawArc(
        Rect.fromCircle(center: o, radius: rr - 2.2),
        -math.pi / 2,
        math.pi * 2 * (1 - share.clamp(0, 1)),
        false,
        _stroke(
            (owner ? Colors.white : ringColor).withValues(alpha: alpha), 2.2));
  }
  drawIcon(
      c, icon, o, rr * 0.95, const Color(0xFFF1E8D8).withValues(alpha: alpha));
  if (share > 0.8 && !faded && pulse > 0) {
    c.drawCircle(o, rr + 3 + pulse * 3,
        _stroke(Color.fromRGBO(227, 112, 92, 0.5 * (1 - pulse)), 1.4));
  }
  return Rect.fromCircle(center: o, radius: rr + 6);
}

/// Static parts of the room, recorded once per layout.
ui.Picture recordPicture(Size size, void Function(Canvas c) paint) {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec, Offset.zero & size);
  paint(c);
  return rec.endRecording();
}

/// Dark walnut floorboards.
void drawPlanks(Canvas c, Rect r) {
  c.drawRect(r, _fill(const Color(0xFF2A1F18)));
  const h = 9.0;
  var row = 0;
  final rnd = math.Random(4);
  for (var y = r.top; y < r.bottom; y += h, row++) {
    final band = Rect.fromLTRB(r.left, y, r.right, math.min(r.bottom, y + h));
    final tone = [
      const Color(0xFF2E2219),
      const Color(0xFF2A1F17),
      const Color(0xFF31251B)
    ][row % 3];
    c.drawRect(band, _fill(tone));
    c.drawLine(Offset(r.left, y), Offset(r.right, y),
        _stroke(const Color(0x55120C08), 0.8));
    final off = (row * 53) % 90;
    for (var x = r.left + off; x < r.right; x += 90) {
      c.drawLine(Offset(x, y), Offset(x, math.min(r.bottom, y + h)),
          _stroke(const Color(0x44120C08), 0.8));
    }
    // Grain.
    for (var k = 0; k < 3; k++) {
      final gx = r.left + rnd.nextDouble() * r.width;
      c.drawLine(
          Offset(gx, y + 2 + k * 2.2),
          Offset(gx + 18 + rnd.nextDouble() * 20, y + 2 + k * 2.2),
          _stroke(const Color(0x10FFFFFF), 0.5));
    }
  }
}

/// Slate kitchen tiles.
void drawTiles(Canvas c, Rect r) {
  c.drawRect(r, _fill(const Color(0xFF1F2427)));
  const s = 14.0;
  var i = 0;
  for (var y = r.top; y < r.bottom; y += s) {
    var j = i;
    for (var x = r.left; x < r.right; x += s) {
      if (j % 3 == 0) {
        c.drawRect(Rect.fromLTWH(x, y, s, s).intersect(r),
            _fill(const Color(0xFF232A2E)));
      }
      j++;
    }
    c.drawLine(Offset(r.left, y), Offset(r.right, y),
        _stroke(const Color(0x33000000), 0.6));
    i++;
  }
  for (var x = r.left; x < r.right; x += s) {
    c.drawLine(Offset(x, r.top), Offset(x, r.bottom),
        _stroke(const Color(0x33000000), 0.6));
  }
}

/// A potted plant from above.
void drawPlant(Canvas c, Offset o, {double s = 1}) {
  c.drawCircle(
      o.translate(1.5 * s, 2.5 * s), 9 * s, _fill(const Color(0x55000000)));
  c.drawCircle(o, 8 * s, _fill(const Color(0xFF26221F)));
  c.drawCircle(o, 6.6 * s, _fill(const Color(0xFF1A1715)));
  final rnd = math.Random((o.dx * 7 + o.dy).toInt());
  for (var i = 0; i < 9; i++) {
    final a = i * math.pi * 2 / 9 + rnd.nextDouble() * 0.4;
    final leaf = o + Offset(math.cos(a), math.sin(a)) * 5.5 * s;
    c.drawOval(
        Rect.fromCenter(center: leaf, width: 7 * s, height: 4 * s),
        _fill([
          const Color(0xFF2F4A35),
          const Color(0xFF3D5C40),
          const Color(0xFF4F7350)
        ][i % 3]));
  }
  c.drawCircle(o, 3 * s, _fill(const Color(0xFF3D5C40)));
}

void drawCoin(Canvas c, Offset o, double r, double spin) {
  final w = r * 2 * (0.35 + 0.65 * spin.abs());
  c.drawOval(Rect.fromCenter(center: o, width: w, height: r * 2),
      _fill(const Color(0xFF8A6A2E)));
  c.drawOval(
      Rect.fromCenter(
          center: o.translate(-0.3, -0.3), width: w * 0.8, height: r * 1.6),
      _fill(const Color(0xFFD9B25F)));
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

/// The glass entrance door on the left wall; [open] 0..1 swings it inwards.
void drawDoor(Canvas c, Rect frame, double open) {
  c.drawRect(frame.inflate(1.5), _fill(const Color(0xFF0B0908)));
  if (open > 0.02) {
    c.drawRect(frame, _fill(Color.fromRGBO(120, 140, 160, 0.35 * open)));
  }
  final w = frame.width * 4.6;
  final leaf = Rect.fromLTWH(
      frame.right, frame.top, w * (1 - open * 0.85), frame.height);
  c.drawRect(leaf, _fill(const Color(0xFF2A3236)));
  c.drawRect(leaf.deflate(1.4), _fill(const Color(0x664F6B78)));
  if (leaf.width > 6) {
    c.drawLine(
        Offset(leaf.right - 3, leaf.center.dy - 4),
        Offset(leaf.right - 3, leaf.center.dy + 4),
        _stroke(const Color(0xFFC9A55B), 1.4));
  }
}

/// A tall stainless double fridge.
void drawFridge(Canvas c, Rect r) {
  c.drawRRect(
      RRect.fromRectAndRadius(
          r.shift(const Offset(1, 3)), const Radius.circular(2)),
      _fill(const Color(0x66000000)));
  c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)),
      _fill(const Color(0xFF8A959C)));
  c.drawRRect(
      RRect.fromRectAndRadius(r.deflate(1.4), const Radius.circular(1.5)),
      _fill(const Color(0xFFA3AEB4)));
  c.drawLine(Offset(r.center.dx, r.top + 2), Offset(r.center.dx, r.bottom - 2),
      _stroke(const Color(0xFF5E686E), 0.8));
  for (final x in [r.center.dx - 2.5, r.center.dx + 2.5]) {
    c.drawLine(Offset(x, r.center.dy - 6), Offset(x, r.center.dy + 6),
        _stroke(const Color(0xFF3E464B), 1.4));
  }
}

/// A wall shelf of jars, seen from above.
void drawShelf(Canvas c, Rect r) {
  c.drawRect(r.inflate(2), _fill(const Color(0xFF3A2A20)));
  const jars = [
    Color(0xFF8A3B25),
    Color(0xFFB07A2A),
    Color(0xFF3F6B5E),
    Color(0xFFC9A55B),
    Color(0xFF5E6B3A)
  ];
  var x = r.left + 3;
  var i = 0;
  while (x + 5 < r.right) {
    c.drawCircle(
        Offset(x + 2.5, r.center.dy), 2.6, _fill(jars[i % jars.length]));
    c.drawCircle(
        Offset(x + 2.5, r.center.dy), 1.4, _fill(const Color(0x55FFFFFF)));
    x += 7;
    i++;
  }
}

/// Stainless prep table with a board and vegetables.
void drawPrepTable(Canvas c, Rect r, double t, bool busy) {
  c.drawRRect(
      RRect.fromRectAndRadius(
          r.shift(const Offset(1, 3)), const Radius.circular(2)),
      _fill(const Color(0x66000000)));
  c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)),
      _fill(const Color(0xFF7A858C)));
  c.drawRRect(
      RRect.fromRectAndRadius(r.deflate(1.4), const Radius.circular(1.5)),
      _fill(const Color(0xFF939EA5)));
  final board = Rect.fromLTWH(
      r.left + 6, r.top + 2.5, math.min(22, r.width * 0.4), r.height - 5);
  c.drawRRect(RRect.fromRectAndRadius(board, const Radius.circular(1.5)),
      _fill(const Color(0xFF9C7448)));
  c.drawCircle(
      board.center.translate(-3, 0), 2.4, _fill(const Color(0xFFA63D2F)));
  c.drawCircle(
      board.center.translate(3, 0.5), 2.1, _fill(const Color(0xFF4F6B3A)));
  if (busy) {
    final k = math.sin(t * 18).abs() * 2.2;
    c.drawLine(
        Offset(board.right - 4, board.top + 1 - k),
        Offset(board.right - 1, board.bottom - 1.5 - k),
        _stroke(const Color(0xFFCED6DA), 1.2));
  }
  c.drawCircle(
      Offset(r.right - 10, r.center.dy), 3.6, _fill(const Color(0xFFD9C7A0)));
}

/// A candle (and two set places) on a free table.
void drawTableSetting(Canvas c, Rect r, double evening, double t) {
  final o = r.center;
  // Cutlery at both ends.
  for (final sx in [-1.0, 1.0]) {
    final p = o.translate(sx * r.width * 0.3, 0);
    c.drawCircle(p, 3.4, _stroke(const Color(0x1A000000), 0.6));
    c.drawLine(p.translate(-5, -2), p.translate(-5, 2),
        _stroke(const Color(0x669AA0A5), 0.6));
    c.drawLine(p.translate(5, -2), p.translate(5, 2),
        _stroke(const Color(0x669AA0A5), 0.6));
  }
  c.drawCircle(o, 1.8, _fill(const Color(0xFFF7F1E1)));
  final f = 0.8 + 0.2 * math.sin(t * 11 + o.dx);
  c.drawCircle(
      o, 1.0 * f, _fill(Color.fromRGBO(255, 190, 90, 0.6 + 0.4 * evening)));
}

void drawRug(Canvas c, Rect r) {
  c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)),
      _fill(const Color(0xFF3A1F1A)));
  c.drawRRect(
      RRect.fromRectAndRadius(r.deflate(2.5), const Radius.circular(1.5)),
      _stroke(const Color(0xFF8A6A3A), 0.8));
}

/// A small brass plaque by the door.
void drawOpenSign(Canvas c, Offset o, bool open) {
  final tp = labelPainter(open ? 'OPEN' : 'CLOSED', 7,
      open ? const Color(0xFFC9A55B) : const Color(0xFFE3705C),
      shadow: false, spacing: 1.6);
  final r = Rect.fromCenter(center: o, width: tp.width + 14, height: 12);
  c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)),
      _fill(const Color(0xFF141110)));
  c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)),
      _stroke(const Color(0xFF5C4F3A), 0.8));
  tp.paint(c, o - Offset(tp.width / 2, tp.height / 2));
}

/// A ripple where the player tapped to send their character.
void drawRipple(Canvas c, Offset o, double k) {
  final a = (1 - k).clamp(0.0, 1.0);
  c.drawCircle(o, 4 + 16 * k, _stroke(Color.fromRGBO(63, 140, 154, a), 1.6));
  c.drawCircle(o, 2.2, _fill(Color.fromRGBO(63, 140, 154, a)));
}

/// Warm light from a pendant lamp or a heat lamp, used when baking the
/// lighting layer.
void drawLightPool(
    Canvas c, Offset o, double radius, Color color, double strength) {
  c.drawCircle(
      o,
      radius,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..shader = RadialGradient(colors: [
          Color.fromRGBO(0, 0, 0, strength),
          Color.fromRGBO(0, 0, 0, strength * 0.5),
          const Color(0x00000000),
        ], stops: const [
          0,
          0.45,
          1
        ]).createShader(Rect.fromCircle(center: o, radius: radius)));
}

/// Coloured glow added on top of the darkness (screen blend).
void drawGlow(Canvas c, Offset o, double radius, Color color) {
  c.drawCircle(
      o,
      radius,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: o, radius: radius)));
}

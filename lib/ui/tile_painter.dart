import 'dart:math' as math;
import 'dart:ui' show PointMode;
import 'package:flutter/material.dart';
import '../core/rules.dart';
import 'theme.dart';

const _pipTable = <int, List<int>>{
  0: [],
  1: [4],
  2: [0, 8],
  3: [0, 4, 8],
  4: [0, 2, 6, 8],
  5: [0, 2, 4, 6, 8],
  6: [0, 2, 3, 5, 6, 8],
};

double tileDepth(double w, double h) => math.min(w, h) * 0.2;

/// ظل الحجر على الطاولة (يتّسع ويخفّ كلما ارتفع الحجر).
void paintTileShadow(Canvas c, Offset center, double w, double h, double lift) {
  final depth = tileDepth(w, h);
  final r0 = Rect.fromCenter(center: center, width: w, height: h);
  final rad = Radius.circular(math.min(w, h) * 0.16);
  final k = 1 / (1 + lift / 90);
  final p = Paint()
    ..color = alpha(Colors.black, 0.55 * k)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 + lift * 0.1);
  c.drawRRect(
      RRect.fromRectAndRadius(r0.shift(Offset(1.5 + lift * 0.12, 1.5 + depth * 0.4 + lift * 0.2)), rad), p);
}

/// يرسم حجرًا مجسَّمًا. [center] هو مركز قاعدة الحجر على الأرض، [lift] ارتفاعه عنها.
void paintTile(
  Canvas c,
  Offset center,
  double w,
  double h, {
  required int a,
  required int b,
  required bool vert,
  required TileStyle st,
  double lift = 0,
  bool glow = false,
  double dim = 0,
  bool back = false,
}) {
  final depth = tileDepth(w, h);
  final rad = Radius.circular(math.min(w, h) * 0.16);
  final base = Rect.fromCenter(center: center.translate(0, -lift), width: w, height: h);
  final top = base.shift(Offset(0, -depth));
  final trr = RRect.fromRectAndRadius(top, rad);

  if (glow) {
    c.drawRRect(
        trr.inflate(3),
        Paint()
          ..color = alpha(kGold, 0.75)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
  }

  // الجوانب (السُّمك)
  for (double k = 0; k <= depth; k += 1.5) {
    final col = Color.lerp(st.edge, st.side, k / depth)!;
    c.drawRRect(RRect.fromRectAndRadius(base.shift(Offset(0, -k)), rad), Paint()..color = col);
  }

  // الوجه العلوي
  final facePaint = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: back ? [st.back1, st.back2] : [st.top1, st.top2],
    ).createShader(top);
  c.drawRRect(trr, facePaint);

  // زخرفة الخامة (رخام، خشب، كربون، معدن، جلد، جواهر) + خط التطعيم
  if (!back) {
    if (st.pat != TilePattern.none) {
      c.save();
      c.clipRRect(trr);
      _tilePattern(c, top, st);
      c.restore();
    }
    final tr = st.trim;
    if (tr != null) {
      c.drawRRect(
          trr.deflate(math.min(w, h) * 0.09),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1
            ..color = alpha(tr, 0.8));
    }
  }

  // لمعة الحافة
  c.drawRRect(
    trr.deflate(0.8),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [alpha(Colors.white, 0.75), alpha(Colors.white, 0.0), alpha(Colors.black, 0.25)],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(top),
  );

  if (back) {
    final g = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = alpha(kGold, 0.85);
    c.drawRRect(trr.deflate(math.min(w, h) * 0.14), g);
    final m = top.center;
    final r = math.min(w, h) * 0.2;
    final path = Path()
      ..moveTo(m.dx, m.dy - r)
      ..lineTo(m.dx + r, m.dy)
      ..lineTo(m.dx, m.dy + r)
      ..lineTo(m.dx - r, m.dy)
      ..close();
    c.drawPath(path, Paint()..color = kGold);
  } else {
    final Rect q1, q2;
    if (vert) {
      q1 = Rect.fromLTRB(top.left, top.top, top.right, top.center.dy);
      q2 = Rect.fromLTRB(top.left, top.center.dy, top.right, top.bottom);
    } else {
      q1 = Rect.fromLTRB(top.left, top.top, top.center.dx, top.bottom);
      q2 = Rect.fromLTRB(top.center.dx, top.top, top.right, top.bottom);
    }
    // الفاصل
    final m = top.center;
    final dark = Paint()
      ..color = alpha(Colors.black, 0.5)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final light = Paint()
      ..color = alpha(Colors.white, 0.55)
      ..strokeWidth = 1.0;
    if (vert) {
      c.drawLine(Offset(top.left + w * 0.12, m.dy), Offset(top.right - w * 0.12, m.dy), dark);
      c.drawLine(Offset(top.left + w * 0.12, m.dy + 1.4), Offset(top.right - w * 0.12, m.dy + 1.4), light);
    } else {
      c.drawLine(Offset(m.dx, top.top + h * 0.12), Offset(m.dx, top.bottom - h * 0.12), dark);
      c.drawLine(Offset(m.dx + 1.4, top.top + h * 0.12), Offset(m.dx + 1.4, top.bottom - h * 0.12), light);
    }
    // مسمار نحاسي
    final pr = math.min(w, h) * 0.055;
    c.drawCircle(m, pr, Paint()..color = kGoldDark);
    c.drawCircle(m.translate(-pr * 0.25, -pr * 0.25), pr * 0.7, Paint()..color = kGoldLight);

    _pips(c, q1, a, vert, st);
    _pips(c, q2, b, vert, st);
  }

  if (dim > 0) {
    c.drawRRect(trr, Paint()..color = alpha(Colors.black, dim));
  }
}

int _seedOf(String s) => s.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0x7fffffff);

void _tilePattern(Canvas c, Rect top, TileStyle st) {
  final rnd = math.Random(_seedOf(st.name));
  final pc = st.patColor;
  final w = top.width, h = top.height;
  switch (st.pat) {
    case TilePattern.none:
      break;
    case TilePattern.marble:
      {
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 6; i++) {
          final path = Path();
          var x = top.left + rnd.nextDouble() * w, y = top.top;
          path.moveTo(x, y);
          for (var k = 1; k <= 4; k++) {
            final nx = x + (rnd.nextDouble() - 0.5) * w * 0.7;
            final ny = top.top + h * k / 4;
            path.quadraticBezierTo(x + (rnd.nextDouble() - 0.5) * w * 0.6, (y + ny) / 2, nx, ny);
            x = nx;
            y = ny;
          }
          p.strokeWidth = 0.5 + rnd.nextDouble() * 1.3;
          p.color = alpha(pc, 0.16 + rnd.nextDouble() * 0.30);
          c.drawPath(path, p);
        }
        break;
      }
    case TilePattern.wood:
      {
        final vert = h >= w;
        const n = 9;
        final p = Paint()..style = PaintingStyle.stroke;
        for (var i = 0; i < n; i++) {
          final t = (i + 0.3 + rnd.nextDouble() * 0.4) / n;
          final path = Path();
          final amp = (vert ? w : h) * (0.015 + rnd.nextDouble() * 0.04);
          final ph = rnd.nextDouble() * 6;
          const steps = 8;
          for (var k = 0; k <= steps; k++) {
            final u = k / steps;
            final off = math.sin(u * 5 + ph) * amp;
            final pt = vert
                ? Offset(top.left + w * t + off, top.top + h * u)
                : Offset(top.left + w * u, top.top + h * t + off);
            if (k == 0) {
              path.moveTo(pt.dx, pt.dy);
            } else {
              path.lineTo(pt.dx, pt.dy);
            }
          }
          p.strokeWidth = 0.6 + rnd.nextDouble() * 1.2;
          p.color = alpha(pc, 0.12 + rnd.nextDouble() * 0.22);
          c.drawPath(path, p);
        }
        break;
      }
    case TilePattern.carbon:
      {
        final s = math.max(3.4, math.min(w, h) / 9);
        final a = Path(), b = Path();
        var yi = 0;
        for (double y = top.top; y < top.bottom; y += s, yi++) {
          var xi = 0;
          for (double x = top.left; x < top.right; x += s, xi++) {
            final r = Rect.fromLTWH(x, y, s, s);
            if ((xi + yi).isEven) {
              a.addRect(r);
            } else {
              b.addRect(r);
            }
          }
        }
        c.drawPath(a, Paint()..color = alpha(Colors.white, 0.09));
        c.drawPath(b, Paint()..color = alpha(Colors.black, 0.28));
        break;
      }
    case TilePattern.brushed:
      {
        final l = Paint()..strokeWidth = 0.9;
        for (double y = top.top; y < top.bottom; y += 2.0) {
          final t = rnd.nextDouble();
          l.color = t > 0.5 ? alpha(pc, (t - 0.5) * 0.28) : alpha(Colors.black, (0.5 - t) * 0.22);
          c.drawLine(Offset(top.left, y), Offset(top.right, y), l);
        }
        c.drawRect(
            top,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [alpha(pc, 0.40), alpha(pc, 0.0), alpha(pc, 0.20), alpha(pc, 0.0)],
                stops: const [0.0, 0.35, 0.62, 1.0],
              ).createShader(top));
        break;
      }
    case TilePattern.sparkle:
      {
        final f1 = Path()
          ..moveTo(top.left, top.top)
          ..lineTo(top.right, top.top)
          ..lineTo(top.center.dx, top.top + h * 0.38)
          ..close();
        c.drawPath(f1, Paint()..color = alpha(Colors.white, 0.14));
        final f2 = Path()
          ..moveTo(top.left, top.bottom)
          ..lineTo(top.right, top.bottom)
          ..lineTo(top.center.dx, top.bottom - h * 0.38)
          ..close();
        c.drawPath(f2, Paint()..color = alpha(Colors.black, 0.16));
        final pts = <Offset>[
          for (var i = 0; i < 26; i++) Offset(top.left + rnd.nextDouble() * w, top.top + rnd.nextDouble() * h)
        ];
        c.drawPoints(PointMode.points, pts, Paint()
          ..color = alpha(pc, 0.65)
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round);
        c.drawPoints(PointMode.points, pts.take(5).toList(), Paint()
          ..color = alpha(Colors.white, 0.95)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round);
        break;
      }
    case TilePattern.leather:
      {
        const g = 4.0;
        final dark = <Offset>[], light = <Offset>[];
        for (double y = top.top + 2; y < top.bottom; y += g) {
          for (double x = top.left + 2; x < top.right; x += g) {
            final o = Offset(x + (rnd.nextDouble() - 0.5) * 2, y + (rnd.nextDouble() - 0.5) * 2);
            if (rnd.nextBool()) {
              dark.add(o);
            } else {
              light.add(o);
            }
          }
        }
        c.drawPoints(PointMode.points, dark, Paint()
          ..color = alpha(Colors.black, 0.28)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round);
        c.drawPoints(PointMode.points, light, Paint()
          ..color = alpha(pc, 0.10)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round);
        break;
      }
  }
}

void _pips(Canvas c, Rect q, int v, bool vert, TileStyle st) {
  final cells = _pipTable[v]!;
  final r = math.min(q.width, q.height) * 0.105;
  for (final idx in cells) {
    var row = idx ~/ 3, col = idx % 3;
    if (!vert) {
      final t = row;
      row = col;
      col = t;
    }
    final p = Offset(q.center.dx + (col - 1) * q.width * 0.27, q.center.dy + (row - 1) * q.height * 0.27);
    c.drawCircle(p.translate(0.5, 0.9), r * 1.08, Paint()..color = alpha(st.pipRim, 0.55));
    c.drawCircle(p, r, Paint()..color = st.pip);
    c.drawCircle(p.translate(-r * 0.3, -r * 0.3), r * 0.38, Paint()..color = alpha(st.pipHi, 0.8));
  }
}

/// حجر كـ Widget (لليد، القائمة، الشعار...).
class TileWidget extends StatelessWidget {
  final Tile? tile;
  final TileStyle st;
  final double w, h;
  final bool vert, glow, back;
  final double dim, lift;
  const TileWidget({
    super.key,
    this.tile,
    required this.st,
    required this.w,
    required this.h,
    this.vert = true,
    this.glow = false,
    this.back = false,
    this.dim = 0,
    this.lift = 0,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(w + 12, h + 30),
        painter: _TileWidgetPainter(this),
      );
}

class _TileWidgetPainter extends CustomPainter {
  final TileWidget t;
  _TileWidgetPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, t.h / 2 + 22);
    paintTileShadow(canvas, center, t.w, t.h, t.lift);
    paintTile(canvas, center, t.w, t.h,
        a: t.tile?.a ?? 0,
        b: t.tile?.b ?? 0,
        vert: t.vert,
        st: t.st,
        lift: t.lift,
        glow: t.glow,
        dim: t.dim,
        back: t.back);
  }

  @override
  bool shouldRepaint(covariant _TileWidgetPainter old) => true;
}

/// أحجار الخصم المقلوبة (حزمة صغيرة متراصّة).
class BackStack extends StatelessWidget {
  final int count;
  final TileStyle st;
  const BackStack({super.key, required this.count, required this.st});

  @override
  Widget build(BuildContext context) {
    final k = math.min(count, 8);
    return CustomPaint(size: Size(16 + math.max(0, k - 1) * 7.0 + 6, 38), painter: _BackPainter(k, st));
  }
}

class _BackPainter extends CustomPainter {
  final int k;
  final TileStyle st;
  _BackPainter(this.k, this.st);

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < k; i++) {
      final c = Offset(10 + i * 7.0, size.height - 14);
      paintTile(canvas, c, 13, 24, a: 0, b: 0, vert: true, st: st, back: true);
    }
  }

  @override
  bool shouldRepaint(covariant _BackPainter old) => old.k != k || old.st != st;
}

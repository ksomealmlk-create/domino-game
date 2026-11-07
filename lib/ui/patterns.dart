import 'dart:math' as math;
import 'dart:ui' show PointMode;
import 'package:flutter/material.dart';
import 'theme.dart';

int _seed(String s) => s.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0x7fffffff);

/// يرسل زخرفة سطح الطاولة (كربون، جلد، رخام، خشب، معدن، نجوم، زخرفة). يُرسم مرة ويُخزَّن كصورة.
void paintTablePattern(Canvas c, Size sz, TableTheme th) {
  final w = sz.width, h = sz.height;
  final rect = Offset.zero & sz;
  final rnd = math.Random(_seed(th.name));
  final pc = th.patColor;
  switch (th.pat) {
    case TablePattern.felt:
      break;
    case TablePattern.carbon:
      {
        const s = 9.0;
        final a = Path(), b = Path();
        for (var yi = 0; yi * s < h; yi++) {
          for (var xi = 0; xi * s < w; xi++) {
            final r = Rect.fromLTWH(xi * s, yi * s, s, s);
            if ((xi + yi).isEven) {
              a.addRect(r);
            } else {
              b.addRect(r);
            }
          }
        }
        c.drawPath(a, Paint()..color = alpha(Colors.white, 0.06));
        c.drawPath(b, Paint()..color = alpha(Colors.black, 0.28));
        break;
      }
    case TablePattern.leather:
      {
        const d = 52.0;
        final p1 = Path(), p2 = Path();
        final k0 = -((h / d).ceil() * d);
        for (double k = k0; k < w + h; k += d) {
          p1.moveTo(k, 0);
          p1.lineTo(k + h, h);
          p2.moveTo(k, h);
          p2.lineTo(k + h, 0);
        }
        final shade = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..color = alpha(Colors.black, 0.28);
        final line = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = alpha(pc, 0.6);
        c.drawPath(p1, shade);
        c.drawPath(p2, shade);
        c.drawPath(p1, line);
        c.drawPath(p2, line);
        // أزرار عند التقاطعات
        for (double k1 = k0; k1 < w + h; k1 += d) {
          for (double k2 = k0; k2 < w + h; k2 += d) {
            final x = (k1 + k2 + h) / 2, y = (k2 + h - k1) / 2;
            if (x < 0 || x > w || y < 0 || y > h) continue;
            c.drawCircle(Offset(x + 1, y + 1.4), 3.4, Paint()..color = alpha(Colors.black, 0.45));
            c.drawCircle(Offset(x, y), 3.2, Paint()..color = alpha(pc, 0.95));
          }
        }
        break;
      }
    case TablePattern.marble:
      {
        final vein = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 12; i++) {
          final path = Path();
          var x = rnd.nextDouble() * w, y = -10.0;
          path.moveTo(x, y);
          const seg = 6;
          for (var k = 1; k <= seg; k++) {
            final nx = x + (rnd.nextDouble() - 0.45) * w * 0.35;
            final ny = h * k / seg;
            path.quadraticBezierTo(x + (rnd.nextDouble() - 0.5) * w * 0.3, (y + ny) / 2, nx, ny);
            x = nx;
            y = ny;
          }
          vein.strokeWidth = 0.6 + rnd.nextDouble() * 2.2;
          vein.color = alpha(pc, 0.10 + rnd.nextDouble() * 0.28);
          c.drawPath(path, vein);
        }
        c.drawRect(
            rect,
            Paint()
              ..shader = RadialGradient(
                center: const Alignment(-0.3, -0.4),
                radius: 0.8,
                colors: [alpha(Colors.white, 0.10), alpha(Colors.white, 0)],
              ).createShader(rect));
        break;
      }
    case TablePattern.wood:
      {
        final g = Paint()..style = PaintingStyle.stroke;
        for (var i = 0; i < 70; i++) {
          final y0 = h * i / 70 + rnd.nextDouble() * 4;
          final path = Path()..moveTo(0, y0);
          final amp = 2 + rnd.nextDouble() * 5, ph = rnd.nextDouble() * 6;
          for (double x = 0; x <= w; x += 20) {
            path.lineTo(x, y0 + math.sin(x / 70 + ph) * amp);
          }
          g.strokeWidth = 0.6 + rnd.nextDouble() * 1.6;
          g.color = alpha(pc, 0.06 + rnd.nextDouble() * 0.16);
          c.drawPath(path, g);
        }
        break;
      }
    case TablePattern.brushed:
      {
        final l = Paint()..strokeWidth = 1;
        for (double y = 0; y < h; y += 2.2) {
          final t = rnd.nextDouble();
          l.color = t > 0.5 ? alpha(Colors.white, (t - 0.5) * 0.22) : alpha(Colors.black, (0.5 - t) * 0.3);
          c.drawLine(Offset(0, y), Offset(w, y), l);
        }
        c.drawRect(
            rect,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [alpha(pc, 0.28), alpha(pc, 0), alpha(pc, 0.16), alpha(pc, 0)],
                stops: const [0.0, 0.3, 0.6, 1.0],
              ).createShader(rect));
        break;
      }
    case TablePattern.stars:
      {
        c.drawRect(
            rect,
            Paint()
              ..shader = RadialGradient(
                center: const Alignment(-0.5, -0.6),
                radius: 0.7,
                colors: [alpha(th.felt, 0.55), alpha(th.felt, 0)],
              ).createShader(rect));
        c.drawRect(
            rect,
            Paint()
              ..shader = RadialGradient(
                center: const Alignment(0.6, 0.5),
                radius: 0.6,
                colors: [alpha(pc, 0.10), alpha(pc, 0)],
              ).createShader(rect));
        final small = <Offset>[for (var i = 0; i < 160; i++) Offset(rnd.nextDouble() * w, rnd.nextDouble() * h)];
        c.drawPoints(PointMode.points, small, Paint()
          ..color = alpha(pc, 0.7)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round);
        final big = <Offset>[for (var i = 0; i < 30; i++) Offset(rnd.nextDouble() * w, rnd.nextDouble() * h)];
        c.drawPoints(PointMode.points, big, Paint()
          ..color = alpha(Colors.white, 0.9)
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round);
        final tw = Path();
        for (var i = 0; i < 8; i++) {
          final x = rnd.nextDouble() * w, y = rnd.nextDouble() * h, r = 6 + rnd.nextDouble() * 6;
          tw.moveTo(x - r, y);
          tw.lineTo(x + r, y);
          tw.moveTo(x, y - r);
          tw.lineTo(x, y + r);
        }
        c.drawPath(
            tw,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = alpha(Colors.white, 0.8));
        break;
      }
    case TablePattern.geo:
      {
        const g = 64.0;
        final star = Path();
        for (double cy = 0; cy < h + g; cy += g) {
          for (double cx = 0; cx < w + g; cx += g) {
            const s = g * 0.34;
            star.addRect(Rect.fromCenter(center: Offset(cx, cy), width: s * 2, height: s * 2));
            const r = s * 1.414;
            star.moveTo(cx, cy - r);
            star.lineTo(cx + r, cy);
            star.lineTo(cx, cy + r);
            star.lineTo(cx - r, cy);
            star.close();
            star.addOval(Rect.fromCircle(center: Offset(cx + g / 2, cy + g / 2), radius: 3));
          }
        }
        c.drawPath(
            star,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.1
              ..color = alpha(pc, 0.30));
        break;
      }
  }
}

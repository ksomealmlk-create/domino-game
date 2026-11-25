import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'chess_theme.dart';
import 'engine.dart';
import 'game.dart';

// ============================================================
//  مجسّمات القطع (دوران حول المحور + مكعبات + أنبوب للحصان)
// ============================================================
const List<double> kPieceHeight = [0, 0.72, 0.82, 0.98, 0.84, 1.08, 1.22];

class _Mesh {
  final Float64List px, py, pz, nx, ny, nz;
  final List<int> tris;
  final int count;
  _Mesh(List<double> p, List<double> n, this.tris)
      : count = p.length ~/ 3,
        px = Float64List.fromList([for (var i = 0; i < p.length; i += 3) p[i]]),
        py = Float64List.fromList([for (var i = 1; i < p.length; i += 3) p[i]]),
        pz = Float64List.fromList([for (var i = 2; i < p.length; i += 3) p[i]]),
        nx = Float64List.fromList([for (var i = 0; i < n.length; i += 3) n[i]]),
        ny = Float64List.fromList([for (var i = 1; i < n.length; i += 3) n[i]]),
        nz = Float64List.fromList([for (var i = 2; i < n.length; i += 3) n[i]]);
}

class _MeshB {
  final List<double> p = [], n = [];
  final List<int> t = [];

  int _v(double x, double y, double z, double nx, double ny, double nz) {
    p..add(x)..add(y)..add(z);
    n..add(nx)..add(ny)..add(nz);
    return p.length ~/ 3 - 1;
  }

  /// [pr] قائمة نقاط (نصف القطر، الارتفاع) من أسفل المركز إلى أعلى المركز.
  void lathe(List<List<double>> pr, {double ox = 0, double oy = 0, double oz = 0, int seg = 16}) {
    final m = pr.length;
    final sn = <List<double>>[];
    for (var i = 0; i < m - 1; i++) {
      final dr = pr[i + 1][0] - pr[i][0], dh = pr[i + 1][1] - pr[i][1];
      final l = math.sqrt(dr * dr + dh * dh);
      sn.add(l < 1e-9 ? [1.0, 0.0] : [dh / l, -dr / l]);
    }
    int ring(double r, double h, double nr, double nh) {
      final first = p.length ~/ 3;
      for (var k = 0; k <= seg; k++) {
        final a = 2 * math.pi * k / seg;
        final c = math.cos(a), s = math.sin(a);
        _v(ox + r * c, oy + h, oz + r * s, nr * c, nh, nr * s);
      }
      return first;
    }

    final inR = List<int>.filled(m, 0), outR = List<int>.filled(m, 0);
    for (var i = 0; i < m; i++) {
      final r = pr[i][0], h = pr[i][1];
      final hasP = i > 0, hasN = i < m - 1;
      if (hasP && hasN) {
        final a = sn[i - 1], b = sn[i];
        final d = a[0] * b[0] + a[1] * b[1];
        if (d > 0.6) {
          var x = a[0] + b[0], y = a[1] + b[1];
          final l = math.sqrt(x * x + y * y);
          x /= l;
          y /= l;
          inR[i] = outR[i] = ring(r, h, x, y);
        } else {
          inR[i] = ring(r, h, a[0], a[1]);
          outR[i] = ring(r, h, b[0], b[1]);
        }
      } else if (hasN) {
        inR[i] = outR[i] = ring(r, h, sn[i][0], sn[i][1]);
      } else {
        inR[i] = outR[i] = ring(r, h, sn[i - 1][0], sn[i - 1][1]);
      }
    }
    for (var i = 0; i < m - 1; i++) {
      if (pr[i][0] < 1e-9 && pr[i + 1][0] < 1e-9) continue;
      for (var k = 0; k < seg; k++) {
        final a = outR[i] + k, b = a + 1, c = inR[i + 1] + k, d = c + 1;
        t..add(a)..add(c)..add(b)..add(b)..add(c)..add(d);
      }
    }
  }

  void sphere(double cx, double cy, double cz, double r, {int seg = 8}) {
    final pr = <List<double>>[];
    for (var a = -90; a <= 90; a += 30) {
      final rad = a * math.pi / 180;
      pr.add([r * math.cos(rad).abs() < 1e-9 ? 0.0 : r * math.cos(rad), r * math.sin(rad)]);
    }
    lathe(pr, ox: cx, oy: cy, oz: cz, seg: seg);
  }

  void box(double cx, double cy, double cz, double hx, double hy, double hz, {double rot = 0}) {
    final c = math.cos(rot), s = math.sin(rot);
    void face(double nx, double ny, double nz, List<List<double>> pts) {
      final idx = <int>[];
      final rnx = nx * c + nz * s, rnz = -nx * s + nz * c;
      for (final q in pts) {
        final rx = q[0] * c + q[2] * s, rz = -q[0] * s + q[2] * c;
        idx.add(_v(cx + rx, cy + q[1], cz + rz, rnx, ny, rnz));
      }
      t..add(idx[0])..add(idx[1])..add(idx[2])..add(idx[0])..add(idx[2])..add(idx[3]);
    }

    face(1, 0, 0, [[hx, -hy, -hz], [hx, -hy, hz], [hx, hy, hz], [hx, hy, -hz]]);
    face(-1, 0, 0, [[-hx, -hy, hz], [-hx, -hy, -hz], [-hx, hy, -hz], [-hx, hy, hz]]);
    face(0, 1, 0, [[-hx, hy, -hz], [hx, hy, -hz], [hx, hy, hz], [-hx, hy, hz]]);
    face(0, -1, 0, [[-hx, -hy, hz], [hx, -hy, hz], [hx, -hy, -hz], [-hx, -hy, -hz]]);
    face(0, 0, 1, [[hx, -hy, hz], [-hx, -hy, hz], [-hx, hy, hz], [hx, hy, hz]]);
    face(0, 0, -1, [[-hx, -hy, -hz], [hx, -hy, -hz], [hx, hy, -hz], [-hx, hy, -hz]]);
  }

  /// أنبوب بيضاوي المقطع على منحنى في المستوى x-y: كل نقطة [x, y, rp, rz]
  void tube(List<List<double>> sp, {int seg = 12, required List<double> tip}) {
    final rings = <int>[];
    for (var k = 0; k < sp.length; k++) {
      final a = sp[math.max(0, k - 1)], b = sp[math.min(sp.length - 1, k + 1)];
      var dx = b[0] - a[0], dy = b[1] - a[1];
      final l = math.sqrt(dx * dx + dy * dy);
      dx /= l;
      dy /= l;
      final px = -dy, py = dx; // عمودي داخل المستوى
      final first = p.length ~/ 3;
      for (var j = 0; j <= seg; j++) {
        final al = 2 * math.pi * j / seg;
        final c = math.cos(al), s = math.sin(al);
        final rp = sp[k][2], rz = sp[k][3];
        final np = c / rp, nz = s / rz;
        final nl = math.sqrt(np * np + nz * nz);
        _v(sp[k][0] + px * rp * c, sp[k][1] + py * rp * c, rz * s, px * np / nl, py * np / nl, nz / nl);
      }
      rings.add(first);
    }
    for (var k = 0; k < sp.length - 1; k++) {
      for (var j = 0; j < seg; j++) {
        final a = rings[k] + j, b = a + 1, c = rings[k + 1] + j, d = c + 1;
        t..add(a)..add(c)..add(b)..add(b)..add(c)..add(d);
      }
    }
    final last = sp.last;
    var tdx = tip[0] - last[0], tdy = tip[1] - last[1];
    final tl = math.sqrt(tdx * tdx + tdy * tdy);
    tdx /= tl;
    tdy /= tl;
    final tipIdx = _v(tip[0], tip[1], 0, tdx, tdy, 0);
    for (var j = 0; j < seg; j++) {
      t..add(rings.last + j)..add(tipIdx)..add(rings.last + j + 1);
    }
  }
}

List<List<double>> _arc(double cr, double cy, double rx, double ry, int a0, int a1, int step) {
  final out = <List<double>>[];
  for (var a = a0; step > 0 ? a <= a1 : a >= a1; a += step) {
    final r = a * math.pi / 180;
    final x = cr + rx * math.cos(r);
    out.add([x < 1e-6 ? 0.0 : x, cy + ry * math.sin(r)]);
  }
  return out;
}

final Map<int, _Mesh> _meshCache = {};

_Mesh _meshFor(int t) => _meshCache.putIfAbsent(t, () => _build(t));

List<List<double>> _base() => [
      [0.0, 0.0], [0.34, 0.0], [0.355, 0.025], [0.35, 0.055], [0.30, 0.085], [0.23, 0.105], [0.21, 0.13],
    ];

_Mesh _build(int t) {
  final b = _MeshB();
  switch (t) {
    case kP:
      b.lathe([
        ..._base(),
        [0.12, 0.19], [0.09, 0.30], [0.12, 0.36], [0.19, 0.385], [0.19, 0.415], [0.11, 0.43],
        ..._arc(0, 0.54, 0.15, 0.15, -60, 90, 30),
      ]);
      break;
    case kR:
      b.lathe([
        ..._base(),
        [0.17, 0.17], [0.155, 0.45], [0.20, 0.50], [0.265, 0.54], [0.265, 0.70], [0.20, 0.70], [0.20, 0.62], [0.0, 0.62],
      ]);
      for (var k = 0; k < 4; k++) {
        final a = math.pi / 4 + k * math.pi / 2;
        b.box(0.225 * math.cos(a), 0.74, 0.225 * math.sin(a), 0.06, 0.05, 0.06, rot: -a);
      }
      break;
    case kB:
      b.lathe([
        ..._base(),
        [0.14, 0.19], [0.09, 0.34], [0.10, 0.40], [0.18, 0.425], [0.18, 0.455], [0.10, 0.475],
        ..._arc(0, 0.63, 0.15, 0.21, -75, 90, 25),
      ]);
      b.sphere(0, 0.87, 0, 0.05);
      break;
    case kQ:
      b.lathe([
        ..._base(),
        [0.14, 0.19], [0.10, 0.34], [0.17, 0.375], [0.17, 0.405], [0.10, 0.44], [0.10, 0.52], [0.14, 0.58],
        [0.23, 0.68], [0.25, 0.78], [0.21, 0.81], [0.0, 0.81],
      ]);
      for (var k = 0; k < 8; k++) {
        final a = k * math.pi / 4;
        b.sphere(0.2 * math.cos(a), 0.83, 0.2 * math.sin(a), 0.045, seg: 6);
      }
      b.sphere(0, 0.9, 0, 0.075);
      break;
    case kK:
      b.lathe([
        ..._base(),
        [0.14, 0.19], [0.10, 0.34], [0.18, 0.38], [0.18, 0.41], [0.10, 0.45], [0.11, 0.56], [0.15, 0.62],
        [0.23, 0.72], [0.24, 0.84], [0.19, 0.88], [0.0, 0.89],
      ]);
      b.box(0, 1.03, 0, 0.032, 0.14, 0.032);
      b.box(0, 1.07, 0, 0.10, 0.032, 0.032);
      break;
    case kN:
      b.lathe([
        ..._base(),
        [0.19, 0.17], [0.19, 0.2], [0.0, 0.2],
      ]);
      b.tube([
        [-0.02, 0.15, 0.20, 0.17],
        [-0.06, 0.36, 0.17, 0.15],
        [-0.04, 0.55, 0.17, 0.14],
        [0.05, 0.70, 0.15, 0.13],
        [0.17, 0.70, 0.11, 0.10],
        [0.29, 0.61, 0.08, 0.075],
      ], tip: [0.35, 0.55]);
      for (final z in const [-0.065, 0.065]) {
        b.lathe([[0.0, 0.0], [0.05, 0.0], [0.0, 0.12]], ox: -0.05, oy: 0.77, oz: z, seg: 8);
      }
      break;
  }
  return _Mesh(b.p, b.n, b.t);
}

// ============================================================
//  الكاميرا والإسقاط المنظوري
// ============================================================
class ChessProjector {
  final Size size;
  final double yaw, pitch, zoom;
  late final double px, py, pz, rx, rz, ux, uy, uz, fx, fy, fz;
  late final double scale, ox, oy;
  double outX = 0, outY = 0, outD = 1;

  static const double dist = 15.0;
  static const double targetY = 0.25;

  ChessProjector(this.size, this.yaw, this.pitch, this.zoom) {
    final cp = math.cos(pitch), sp = math.sin(pitch);
    px = dist * math.sin(yaw) * cp;
    py = targetY + dist * sp;
    pz = -dist * math.cos(yaw) * cp;
    var a = -px, b = targetY - py, c = -pz;
    final l = math.sqrt(a * a + b * b + c * c);
    a /= l;
    b /= l;
    c /= l;
    fx = a;
    fy = b;
    fz = c;
    var r1 = fz, r3 = -fx;
    final rl = math.sqrt(r1 * r1 + r3 * r3);
    rx = r1 / rl;
    rz = r3 / rl;
    ux = fy * rz;
    uy = fz * rx - fx * rz;
    uz = -fy * rx;
    // ملاءمة اللوحة داخل المساحة
    var minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9;
    void acc(double x, double y, double z) {
      final dx = x - px, dy = y - py, dz = z - pz;
      final cz = dx * fx + dy * fy + dz * fz;
      final sx = (dx * rx + dz * rz) / cz;
      final sy = (dx * ux + dy * uy + dz * uz) / cz;
      if (sx < minX) minX = sx;
      if (sx > maxX) maxX = sx;
      if (sy < minY) minY = sy;
      if (sy > maxY) maxY = sy;
    }

    for (final sx in const [-4.6, 4.6]) {
      for (final sz in const [-4.6, 4.6]) {
        acc(sx, -0.45, sz);
        acc(sx, 0.1, sz);
        acc(sx * 0.85, 1.25, sz * 0.85);
      }
    }
    final s0 = math.min(size.width * 0.98 / (maxX - minX), size.height * 0.98 / (maxY - minY));
    scale = s0 * zoom;
    ox = size.width / 2 - scale * (minX + maxX) / 2;
    oy = size.height / 2 + scale * (minY + maxY) / 2;
  }

  /// يملأ outX/outY/outD
  void proj(double x, double y, double z) {
    final dx = x - px, dy = y - py, dz = z - pz;
    final cz = dx * fx + dy * fy + dz * fz;
    outD = cz;
    outX = ox + scale * (dx * rx + dz * rz) / cz;
    outY = oy - scale * (dx * ux + dy * uy + dz * uz) / cz;
  }

  Offset p(double x, double y, double z) {
    proj(x, y, z);
    return Offset(outX, outY);
  }

  /// تقاطع الشعاع مع المستوى y = h
  Offset? unproject(Offset s, double h) {
    final xn = (s.dx - ox) / scale, yn = -(s.dy - oy) / scale;
    final dx = rx * xn + ux * yn + fx;
    final dy = uy * yn + fy;
    final dz = rz * xn + uz * yn + fz;
    if (dy > -1e-6) return null;
    final t = (h - py) / dy;
    return Offset(px + dx * t, pz + dz * t); // (x, z)
  }

  /// أي مربع تحت الإصبع؟ (يراعي ارتفاع القطع). -1 = خارج اللوحة
  int pick(Offset s, List<int> board) {
    var bestSq = -1;
    var bestD = 1e9;
    for (var sq = 0; sq < 64; sq++) {
      final pc = board[sq].abs();
      if (pc == 0) continue;
      final x = (sq & 7) - 3.5, z = (sq >> 3) - 3.5;
      final a = p(x, 0.05, z);
      final dep = outD;
      final bb = p(x, kPieceHeight[pc] * 0.92, z);
      final rad = 0.34 * scale / dep;
      // مسافة النقطة عن القطعة
      final vx = bb.dx - a.dx, vy = bb.dy - a.dy;
      final wx = s.dx - a.dx, wy = s.dy - a.dy;
      final vv = vx * vx + vy * vy;
      var tt = vv < 1e-9 ? 0.0 : (wx * vx + wy * vy) / vv;
      tt = tt.clamp(0.0, 1.0).toDouble();
      final cx = a.dx + vx * tt, cy = a.dy + vy * tt;
      final d = math.sqrt((s.dx - cx) * (s.dx - cx) + (s.dy - cy) * (s.dy - cy));
      if (d <= rad && dep < bestD) {
        bestD = dep;
        bestSq = sq;
      }
    }
    if (bestSq >= 0) return bestSq;
    final q = unproject(s, 0);
    if (q == null) return -1;
    final f = (q.dx + 4).floor(), r = (q.dy + 4).floor();
    if (f < 0 || f > 7 || r < 0 || r > 7) return -1;
    return r * 8 + f;
  }
}

// ============================================================
//  الرسّام
// ============================================================
class _Item {
  final int type, side;
  final double x, y, z, rot, scale, alpha, depth;
  const _Item(this.type, this.side, this.x, this.y, this.z, this.rot, this.scale, this.alpha, this.depth);
}

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t.clamp(0.0, 1.0).toDouble())!;
Color _dk(Color c, double t) => _mix(c, Colors.black, t);
Color _lt(Color c, double t) => _mix(c, Colors.white, t);
Color _a(Color c, double o) => c.withAlpha((o.clamp(0.0, 1.0) * 255).round());

class ChessScenePainter extends CustomPainter {
  final List<int> board;
  final double yaw, pitch, zoom;
  final ChessBoardTheme theme;
  final ChessPieceSet pset;
  final Color felt, feltDark;
  final bool shadows;
  final MoveInfo? mv;
  final double mt; // تقدّم أنيميشن النقلة 0..1
  final int selected;
  final Map<int, bool> targets; // مربع → هل هو أخذ؟
  final int lastFrom, lastTo, checkSq, hintFrom, hintTo;
  final double clock; // ثواني (للنبض)
  final Offset shake;

  ChessScenePainter({
    required this.board,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.theme,
    required this.pset,
    required this.felt,
    required this.feltDark,
    required this.shadows,
    required this.mv,
    required this.mt,
    required this.selected,
    required this.targets,
    required this.lastFrom,
    required this.lastTo,
    required this.checkSq,
    required this.hintFrom,
    required this.hintTo,
    required this.clock,
    required this.shake,
    super.repaint,
  });

  // مخازن مشتركة لتفادي التخصيص كل إطار
  static final Float32List _pos = Float32List(2 * 90000);
  static final Int32List _col = Int32List(90000);
  static final Float64List _sx = Float64List(4096), _sy = Float64List(4096);
  static final Float64List _wx = Float64List(4096), _wy = Float64List(4096), _wz = Float64List(4096);
  static final Float64List _nx = Float64List(4096), _ny = Float64List(4096), _nz = Float64List(4096);
  static final Int32List _vc = Int32List(4096);

  @override
  void paint(Canvas canvas, Size size) {
    final pr = ChessProjector(size, yaw, pitch, zoom);
    canvas.save();
    canvas.translate(shake.dx, shake.dy);
    _table(canvas, size, pr);
    _frame(canvas, pr);
    _squares(canvas, pr);
    _marks(canvas, pr);
    _labels(canvas, pr);
    _pieces(canvas, pr);
    canvas.restore();
  }

  // ---------------- الطاولة ----------------
  void _table(Canvas canvas, Size size, ChessProjector pr) {
    final rect = Offset.zero & size;
    final c = pr.p(0, -0.45, 0);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(c, size.longestSide * 0.8, [felt, feltDark, _dk(feltDark, 0.7)], [0.0, 0.55, 1.0]),
    );
    // ظل اللوحة على الطاولة
    final sh = Path();
    final pts = [pr.p(-4.9, -0.46, -4.5), pr.p(4.9, -0.46, -4.5), pr.p(5.4, -0.46, 5.0), pr.p(-5.4, -0.46, 5.0)];
    sh.addPolygon(pts, true);
    canvas.drawPath(sh, Paint()..color = _a(Colors.black, 0.30));
  }

  // ---------------- الإطار ----------------
  static const double _O = 4.55, _I = 4.0, _top = 0.10, _bot = -0.45;

  void _wall(Canvas canvas, ChessProjector pr, List<List<double>> q, double nx, double nz, Color base) {
    final cx = (q[0][0] + q[2][0]) / 2, cy = (q[0][1] + q[2][1]) / 2, cz = (q[0][2] + q[2][2]) / 2;
    final vis = nx * (pr.px - cx) + nz * (pr.pz - cz);
    if (vis <= 0) return;
    final path = Path()..addPolygon([for (final v in q) pr.p(v[0], v[1], v[2])], true);
    final lit = (nx * -0.4 + nz * -0.7);
    final col = _mix(_dk(base, 0.25), _lt(base, 0.18), (lit + 1) / 2);
    final a = pr.p(cx, q[0][1], cz), b = pr.p(cx, q[2][1], cz);
    canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(b, a, [_lt(col, 0.12), _dk(col, 0.28)]));
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 0.8..color = _a(Colors.black, 0.4));
  }

  void _frame(Canvas canvas, ChessProjector pr) {
    final f = theme.frame;
    // جدران خارجية
    _wall(canvas, pr, [[_O, _bot, -_O], [_O, _bot, _O], [_O, _top, _O], [_O, _top, -_O]], 1, 0, f[1]);
    _wall(canvas, pr, [[-_O, _bot, _O], [-_O, _bot, -_O], [-_O, _top, -_O], [-_O, _top, _O]], -1, 0, f[1]);
    _wall(canvas, pr, [[_O, _bot, _O], [-_O, _bot, _O], [-_O, _top, _O], [_O, _top, _O]], 0, 1, f[1]);
    _wall(canvas, pr, [[-_O, _bot, -_O], [_O, _bot, -_O], [_O, _top, -_O], [-_O, _top, -_O]], 0, -1, f[1]);
    // جدران داخلية (تواجه المركز)
    _wall(canvas, pr, [[_I, 0, _I], [_I, 0, -_I], [_I, _top, -_I], [_I, _top, _I]], -1, 0, f[2]);
    _wall(canvas, pr, [[-_I, 0, -_I], [-_I, 0, _I], [-_I, _top, _I], [-_I, _top, -_I]], 1, 0, f[2]);
    _wall(canvas, pr, [[-_I, 0, _I], [_I, 0, _I], [_I, _top, _I], [-_I, _top, _I]], 0, -1, f[2]);
    _wall(canvas, pr, [[_I, 0, -_I], [-_I, 0, -_I], [-_I, _top, -_I], [_I, _top, -_I]], 0, 1, f[2]);
    // السطح العلوي
    final strips = <List<double>>[
      [-_O, -_O, _O, -_I],
      [-_O, _I, _O, _O],
      [-_O, -_I, -_I, _I],
      [_I, -_I, _O, _I],
    ];
    for (var i = 0; i < strips.length; i++) {
      final s = strips[i];
      final path = Path()
        ..addPolygon([pr.p(s[0], _top, s[1]), pr.p(s[2], _top, s[1]), pr.p(s[2], _top, s[3]), pr.p(s[0], _top, s[3])], true);
      final a = pr.p(s[0], _top, s[1]), b = pr.p(s[2], _top, s[3]);
      canvas.drawPath(path, Paint()..shader = ui.Gradient.linear(a, b, [f[0], f[1], _mix(f[1], f[2], 0.6)], [0.0, 0.55, 1.0]));
      if (theme.grain == BoardGrain.wood) {
        final gp = Paint()..color = _a(Colors.black, 0.10)..strokeWidth = 0.8;
        for (var k = 1; k < 5; k++) {
          final t = k / 5;
          final x0 = s[0] + (s[2] - s[0]) * t, z0 = s[1] + (s[3] - s[1]) * t;
          canvas.drawLine(pr.p(x0, _top, s[1]), pr.p(x0, _top, s[3]), gp);
          canvas.drawLine(pr.p(s[0], _top, z0), pr.p(s[2], _top, z0), gp);
        }
      }
    }
    // خط تطعيم ذهبي
    final inl = Path()..addPolygon([pr.p(-_I - 0.12, _top, -_I - 0.12), pr.p(_I + 0.12, _top, -_I - 0.12), pr.p(_I + 0.12, _top, _I + 0.12), pr.p(-_I - 0.12, _top, _I + 0.12)], true);
    canvas.drawPath(inl, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4..color = _a(_lt(f[0], 0.35), 0.9));
    final edge = Path()..addPolygon([pr.p(-_O, _top, -_O), pr.p(_O, _top, -_O), pr.p(_O, _top, _O), pr.p(-_O, _top, _O)], true);
    canvas.drawPath(edge, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0..color = _a(Colors.white, 0.25));
  }

  // ---------------- المربعات ----------------
  List<Offset> _quad(ChessProjector pr, int sq, double y, [double inset = 0]) {
    final f = (sq & 7) - 4.0, r = (sq >> 3) - 4.0;
    return [
      pr.p(f + inset, y, r + inset),
      pr.p(f + 1 - inset, y, r + inset),
      pr.p(f + 1 - inset, y, r + 1 - inset),
      pr.p(f + inset, y, r + 1 - inset),
    ];
  }

  void _squares(Canvas canvas, ChessProjector pr) {
    for (var sq = 0; sq < 64; sq++) {
      final f = sq & 7, r = sq >> 3;
      final dark = ((f + r) & 1) == 0;
      final v = (((f * 7 + r * 13) % 5) - 2) * 0.018;
      var col = dark ? theme.dark : theme.light;
      col = v >= 0 ? _lt(col, v) : _dk(col, -v);
      final q = _quad(pr, sq, 0);
      final path = Path()..addPolygon(q, true);
      canvas.drawPath(path, Paint()..color = col..isAntiAlias = false);
      if (theme.grain == BoardGrain.wood) {
        final gp = Paint()..color = _a(dark ? Colors.black : const Color(0xFF6B3E1A), dark ? 0.16 : 0.10)..strokeWidth = 0.7;
        for (var k = 1; k < 4; k++) {
          final z0 = (sq >> 3) - 4.0 + k / 4 + ((sq * 31 + k * 17) % 7 - 3) * 0.02;
          final x0 = (sq & 7) - 4.0;
          canvas.drawLine(pr.p(x0, 0, z0), pr.p(x0 + 1, 0, z0 + ((sq + k) % 3 - 1) * 0.05), gp);
        }
      } else if (theme.grain == BoardGrain.marble) {
        final gp = Paint()..style = PaintingStyle.stroke..strokeWidth = 0.8..color = _a(dark ? Colors.white : const Color(0xFF50586A), 0.16);
        final x0 = (sq & 7) - 4.0, z0 = (sq >> 3) - 4.0;
        final s = ((sq * 37) % 10) / 10.0;
        final pth = Path()
          ..moveTo(pr.p(x0 + s, 0, z0).dx, pr.p(x0 + s, 0, z0).dy)
          ..quadraticBezierTo(pr.p(x0 + 0.5, 0, z0 + 0.4).dx, pr.p(x0 + 0.5, 0, z0 + 0.4).dy, pr.p(x0 + 1 - s * 0.6, 0, z0 + 1).dx,
              pr.p(x0 + 1 - s * 0.6, 0, z0 + 1).dy);
        canvas.drawPath(pth, gp);
      }
    }
    // لمعة خفيفة على اللوحة
    final a = pr.p(-4, 0, 4), b = pr.p(4, 0, -4);
    final full = Path()..addPolygon([pr.p(-4, 0, -4), pr.p(4, 0, -4), pr.p(4, 0, 4), pr.p(-4, 0, 4)], true);
    canvas.drawPath(full, Paint()..shader = ui.Gradient.linear(a, b, [_a(Colors.white, 0.10), _a(Colors.white, 0.0), _a(Colors.black, 0.12)], [0.0, 0.5, 1.0]));
  }

  void _fillSq(Canvas canvas, ChessProjector pr, int sq, Color c) {
    if (sq < 0) return;
    canvas.drawPath(Path()..addPolygon(_quad(pr, sq, 0.004), true), Paint()..color = c);
  }

  void _circle(Canvas canvas, ChessProjector pr, double cx, double cz, double rad, Paint p, {double y = 0.008}) {
    final pts = <Offset>[for (var i = 0; i < 28; i++) pr.p(cx + rad * math.cos(i * math.pi / 14), y, cz + rad * math.sin(i * math.pi / 14))];
    canvas.drawPath(Path()..addPolygon(pts, true), p);
  }

  void _marks(Canvas canvas, ChessProjector pr) {
    _fillSq(canvas, pr, lastFrom, _a(const Color(0xFFE9C45A), 0.32));
    _fillSq(canvas, pr, lastTo, _a(const Color(0xFFE9C45A), 0.45));
    if (hintFrom >= 0) {
      _fillSq(canvas, pr, hintFrom, _a(const Color(0xFF3BC48B), 0.5));
      _fillSq(canvas, pr, hintTo, _a(const Color(0xFF3BC48B), 0.62));
    }
    if (checkSq >= 0) {
      final x = (checkSq & 7) - 3.5, z = (checkSq >> 3) - 3.5;
      final pulse = 0.5 + 0.5 * math.sin(clock * 6);
      _circle(canvas, pr, x, z, 0.62, Paint()..color = _a(const Color(0xFFFF2D2D), 0.30 + 0.25 * pulse));
      _circle(canvas, pr, x, z, 0.42, Paint()..color = _a(const Color(0xFFFF5A4A), 0.35 + 0.25 * pulse));
    }
    if (selected >= 0) {
      _fillSq(canvas, pr, selected, _a(const Color(0xFFF6E3A1), 0.55));
      final q = Path()..addPolygon(_quad(pr, selected, 0.006, 0.03), true);
      canvas.drawPath(q, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.2..color = const Color(0xFFD4AF37));
    }
    targets.forEach((sq, cap) {
      final x = (sq & 7) - 3.5, z = (sq >> 3) - 3.5;
      if (cap) {
        final pulse = 0.5 + 0.5 * math.sin(clock * 5);
        _circle(canvas, pr, x, z, 0.46, Paint()..style = PaintingStyle.stroke..strokeWidth = 3.2..color = _a(const Color(0xFFFF4D4D), 0.75 + 0.2 * pulse));
        _circle(canvas, pr, x, z, 0.46, Paint()..color = _a(const Color(0xFFFF4D4D), 0.16));
      } else {
        _circle(canvas, pr, x, z, 0.15, Paint()..color = _a(const Color(0xFF1B1B1B), 0.42));
        _circle(canvas, pr, x, z, 0.11, Paint()..color = _a(const Color(0xFFF6E3A1), 0.95));
      }
    });
    // موجة الهبوط
    final m = mv;
    if (m != null && mt > 0.62 && mt < 1.0) {
      final u = (mt - 0.62) / 0.38;
      final x = (m.to & 7) - 3.5, z = (m.to >> 3) - 3.5;
      _circle(canvas, pr, x, z, 0.25 + 0.75 * u,
          Paint()..style = PaintingStyle.stroke..strokeWidth = 3.0 * (1 - u) + 0.5..color = _a(const Color(0xFFF6E3A1), 0.7 * (1 - u)),
          y: 0.012);
    }
  }

  // ---------------- الأحرف والأرقام ----------------
  void _labels(Canvas canvas, ChessProjector pr) {
    final color = _a(_lt(theme.frame[0], 0.5), 0.95);
    for (var i = 0; i < 8; i++) {
      _text(canvas, pr, String.fromCharCode(97 + i), i - 3.5, -4.28, color);
      _text(canvas, pr, '${i + 1}', -4.28, i - 3.5, color);
    }
  }

  void _text(Canvas canvas, ChessProjector pr, String s, double x, double z, Color c) {
    final o = pr.p(x, _top + 0.002, z);
    final d = pr.outD;
    final fs = (0.30 * pr.scale / d).clamp(6.0, 26.0).toDouble();
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: fs, fontWeight: FontWeight.w800, color: c)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
  }

  // ---------------- القطع ----------------
  double _ease(double u) => u * u * (3 - 2 * u);

  List<_Item> _collect(ChessProjector pr) {
    final items = <_Item>[];
    final m = mv;
    final animating = m != null && mt < 1.0;
    for (var sq = 0; sq < 64; sq++) {
      final p = board[sq];
      if (p == 0) continue;
      var x = (sq & 7) - 3.5, z = (sq >> 3) - 3.5, y = 0.0;
      var type = p.abs();
      final side = p > 0 ? 1 : -1;
      var scale = 1.0;
      if (m != null && animating) {
        double? fromX, fromZ;
        if (sq == m.to) {
          fromX = (m.from & 7) - 3.5;
          fromZ = (m.from >> 3) - 3.5;
          if (m.promo != 0 && mt < 0.7) type = kP;
          if (m.promo != 0 && mt >= 0.7 && mt < 0.85) scale = 1.0 + 0.25 * math.sin((mt - 0.7) / 0.15 * math.pi);
        } else if (m.isCastle && sq == m.rookTo) {
          fromX = (m.rookFrom & 7) - 3.5;
          fromZ = (m.rookFrom >> 3) - 3.5;
        }
        if (fromX != null && fromZ != null) {
          final u = (mt / 0.7).clamp(0.0, 1.0).toDouble();
          final e = _ease(u);
          x = fromX + (x - fromX) * e;
          z = fromZ + (z - fromZ) * e;
          if (mt < 0.7) {
            final dist = math.sqrt((x - fromX) * (x - fromX) + (z - fromZ) * (z - fromZ));
            y = (m.piece.abs() == kN ? 1.0 : 0.5) * math.sin(math.pi * e) * (0.5 + 0.12 * dist);
          } else {
            final w = (mt - 0.7) / 0.3;
            y = 0.11 * (1 - w) * math.sin(w * math.pi * 3).abs();
          }
        }
      }
      if (sq == selected && !animating) y += 0.16 + 0.035 * math.sin(clock * 6);
      var rot = 0.0;
      if (type == kN) rot = side > 0 ? -math.pi / 2 : math.pi / 2;
      pr.proj(x, 0.3, z);
      items.add(_Item(type, side, x, y, z, rot, scale, 1.0, pr.outD));
    }
    // القطعة المأخوذة تختفي لحظة الاصطدام
    if (m != null && animating && m.captured != 0 && mt < 0.85) {
      final x = (m.capSq & 7) - 3.5, z = (m.capSq >> 3) - 3.5;
      var s = 1.0, al = 1.0, y = 0.0;
      if (mt > 0.55) {
        final u = ((mt - 0.55) / 0.3).clamp(0.0, 1.0).toDouble();
        s = 1 - 0.6 * u;
        al = 1 - u;
        y = 0.5 * u;
      }
      final t = m.captured.abs();
      pr.proj(x, 0.3, z);
      items.add(_Item(t, m.captured > 0 ? 1 : -1, x, y, z, t == kN ? (m.captured > 0 ? -math.pi / 2 : math.pi / 2) : 0.0, s, al, pr.outD));
    }
    items.sort((a, b) => b.depth.compareTo(a.depth));
    return items;
  }

  void _shadow(Canvas canvas, ChessProjector pr, _Item it) {
    final h = kPieceHeight[it.type] * it.scale;
    final lift = it.y;
    final pts = <Offset>[];
    const dx = 0.42, dz = 0.34;
    for (var i = 0; i < 16; i++) {
      final a = i * math.pi / 8;
      pts.add(pr.p(it.x + 0.33 * it.scale * math.cos(a), 0.004, it.z + 0.33 * it.scale * math.sin(a)));
      pts.add(pr.p(it.x + dx * h + 0.12 * math.cos(a), 0.004, it.z + dz * h + 0.12 * math.sin(a)));
    }
    final hull = _hull(pts);
    final fade = (1 - (lift * 0.9)).clamp(0.25, 1.0).toDouble();
    canvas.drawPath(Path()..addPolygon(hull, true), Paint()..color = _a(Colors.black, 0.26 * fade * it.alpha));
  }

  List<Offset> _hull(List<Offset> pts) {
    final p = List<Offset>.of(pts)..sort((a, b) => a.dx != b.dx ? a.dx.compareTo(b.dx) : a.dy.compareTo(b.dy));
    double cross(Offset o, Offset a, Offset b) => (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
    final lo = <Offset>[];
    for (final q in p) {
      while (lo.length >= 2 && cross(lo[lo.length - 2], lo.last, q) <= 0) {
        lo.removeLast();
      }
      lo.add(q);
    }
    final up = <Offset>[];
    for (final q in p.reversed) {
      while (up.length >= 2 && cross(up[up.length - 2], up.last, q) <= 0) {
        up.removeLast();
      }
      up.add(q);
    }
    lo.removeLast();
    up.removeLast();
    return [...lo, ...up];
  }

  void _pieces(Canvas canvas, ChessProjector pr) {
    final items = _collect(pr);
    if (shadows) {
      for (final it in items) {
        _shadow(canvas, pr, it);
      }
    }
    // اتجاهات الإضاءة (مرتبطة بالكاميرا)
    double lx = -0.45 * pr.rx + 0.75 * pr.ux - 0.5 * pr.fx;
    double ly = 0.75 * pr.uy - 0.5 * pr.fy;
    double lz = -0.45 * pr.rz + 0.75 * pr.uz - 0.5 * pr.fz;
    var l = math.sqrt(lx * lx + ly * ly + lz * lz);
    lx /= l;
    ly /= l;
    lz /= l;
    double hx = lx - pr.fx, hy = ly - pr.fy, hz = lz - pr.fz;
    l = math.sqrt(hx * hx + hy * hy + hz * hz);
    hx /= l;
    hy /= l;
    hz /= l;
    final vx = -pr.fx, vy = -pr.fy, vz = -pr.fz;

    var n = 0; // عدد الرؤوس المكتوبة
    for (final it in items) {
      final mesh = _meshFor(it.type);
      final base = it.side > 0 ? pset.white : pset.black;
      // ignore: deprecated_member_use
      final br = base.red.toDouble(), bg = base.green.toDouble(), bb = base.blue.toDouble();
      final cr = math.cos(it.rot), sr = math.sin(it.rot);
      final alpha = (it.alpha * 255).round().clamp(0, 255).toInt();
      final shiny = it.side > 0 ? 0.42 : 0.55;
      for (var i = 0; i < mesh.count; i++) {
        final lx0 = mesh.px[i] * it.scale, ly0 = mesh.py[i] * it.scale, lz0 = mesh.pz[i] * it.scale;
        final x = it.x + lx0 * cr + lz0 * sr;
        final z = it.z - lx0 * sr + lz0 * cr;
        final y = it.y + ly0;
        pr.proj(x, y, z);
        _sx[i] = pr.outX;
        _sy[i] = pr.outY;
        _wx[i] = x;
        _wy[i] = y;
        _wz[i] = z;
        final nx = mesh.nx[i] * cr + mesh.nz[i] * sr;
        final nz = -mesh.nx[i] * sr + mesh.nz[i] * cr;
        final ny = mesh.ny[i];
        _nx[i] = nx;
        _ny[i] = ny;
        _nz[i] = nz;
        final nd = math.max(0.0, nx * lx + ny * ly + nz * lz);
        final ns = math.max(0.0, nx * hx + ny * hy + nz * hz);
        final nv = math.max(0.0, nx * vx + ny * vy + nz * vz);
        final spec = math.pow(ns, 30).toDouble() * shiny;
        final rim = math.pow(1 - nv, 3).toDouble() * 0.10;
        final amb = 0.26 + 0.10 * ny;
        final k = amb + 0.82 * nd;
        final h = 0.92 + 0.10 * (mesh.py[i]).clamp(0.0, 1.2);
        final r = br * k * h + 255 * (spec + rim);
        final g = bg * k * h + 255 * (spec + rim);
        final b = bb * k * h + 255 * (spec + rim);
        final ri = r.clamp(0.0, 255.0).round(), gi = g.clamp(0.0, 255.0).round(), bi = b.clamp(0.0, 255.0).round();
        _vc[i] = (alpha << 24) | (ri << 16) | (gi << 8) | bi;
      }
      final tr = mesh.tris;
      for (var t = 0; t + 2 < tr.length; t += 3) {
        final a = tr[t], b2 = tr[t + 1], c = tr[t + 2];
        final fnx = _nx[a] + _nx[b2] + _nx[c], fny = _ny[a] + _ny[b2] + _ny[c], fnz = _nz[a] + _nz[b2] + _nz[c];
        final dot = fnx * (pr.px - _wx[a]) + fny * (pr.py - _wy[a]) + fnz * (pr.pz - _wz[a]);
        if (dot <= 0) continue;
        if (n + 3 > 90000) break;
        _pos[n * 2] = _sx[a];
        _pos[n * 2 + 1] = _sy[a];
        _col[n] = _vc[a];
        n++;
        _pos[n * 2] = _sx[b2];
        _pos[n * 2 + 1] = _sy[b2];
        _col[n] = _vc[b2];
        n++;
        _pos[n * 2] = _sx[c];
        _pos[n * 2 + 1] = _sy[c];
        _col[n] = _vc[c];
        n++;
      }
    }
    if (n == 0) return;
    final verts = ui.Vertices.raw(ui.VertexMode.triangles, _pos.sublist(0, n * 2), colors: _col.sublist(0, n));
    canvas.drawVertices(verts, BlendMode.modulate, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant ChessScenePainter old) => true;
}

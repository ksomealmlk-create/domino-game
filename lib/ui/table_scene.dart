import 'dart:math' as math;
import 'dart:ui' show PointMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../audio/sfx.dart';
import '../core/rules.dart';
import '../core/settings.dart';
import '../core/view.dart';
import 'theme.dart';
import 'tile_painter.dart';

// ---------------- الفيزياء: جاذبية + ارتداد ----------------
const double kDropH = 230; // ارتفاع إسقاط الحجر
const double kGravity = 2600; // تسارع الجاذبية
const double kRestitution = 0.30; // مقدار الارتداد
final double kFallTime = math.sqrt(2 * kDropH / kGravity);

/// ارتفاع الحجر عن الطاولة بعد [t] ثانية من تحريره (سقوط ثم ارتداد متناقص).
double dropHeight(double t) {
  if (t < 0) return kDropH;
  if (t < kFallTime) return kDropH - 0.5 * kGravity * t * t;
  var v = kGravity * kFallTime * kRestitution;
  var tt = t - kFallTime;
  for (var i = 0; i < 4; i++) {
    final dur = 2 * v / kGravity;
    if (tt < dur) return v * tt - 0.5 * kGravity * tt * tt;
    tt -= dur;
    v *= kRestitution;
  }
  return 0;
}

// ---------------- ترتيب الأحجار (ثعبان) ----------------
class _Item {
  final int a, b;
  final bool vert;
  final double x, y, w, h;
  const _Item(this.a, this.b, this.vert, this.x, this.y, this.w, this.h);
  int get key => a < b ? a * 10 + b : b * 10 + a;
}

const _dirs = <String, List<int>>{
  'E': [1, 0],
  'S': [0, 1],
  'W': [-1, 0],
  'N': [0, -1],
};

List<_Item> _layoutChain(List<Tile> ch, int nl, double W, double H, double s) {
  final L = 2 * s + 4, S = s + 4;
  const pad = 4.0;
  final items = <_Item>[];

  void put(int near, int far, String dn, double cx, double cy, bool dbl) {
    final d = _dirs[dn]!;
    final horiz = d[1] == 0;
    final vert = dbl ? horiz : !horiz;
    final fwd = dn == 'E' || dn == 'S';
    final w = vert ? S : L, h = vert ? L : S;
    items.add(_Item(fwd ? near : far, fwd ? far : near, vert, cx - w / 2, cy - h / 2, w, h));
  }

  void walk(List<List<int>> tiles, List<double> startP, double startW, List<String> order) {
    var P = [startP[0], startP[1]];
    var di = 0;
    var wl = startW;
    for (final t in tiles) {
      final near = t[0], far = t[1];
      final dbl = near == far;
      final len = dbl ? S : L, w = dbl ? L : S;
      var dn = order[di];
      var d = _dirs[dn]!;
      var cx = P[0] + d[0] * len / 2, cy = P[1] + d[1] * len / 2;
      List<double> np;
      final hx = d[1] == 0 ? len / 2 : w / 2, hy = d[1] == 0 ? w / 2 : len / 2;
      final fits = cx - hx >= pad && cx + hx <= W - pad && cy - hy >= pad && cy + hy <= H - pad;
      if (fits) {
        np = [P[0] + d[0] * len, P[1] + d[1] * len];
      } else {
        final od = d;
        di = (di + 1) % 4;
        dn = order[di];
        d = _dirs[dn]!;
        final bx = P[0] - od[0] * w / 2, by = P[1] - od[1] * w / 2;
        cx = bx + d[0] * (wl / 2 + len / 2);
        cy = by + d[1] * (wl / 2 + len / 2);
        np = [bx + d[0] * (wl / 2 + len), by + d[1] * (wl / 2 + len)];
      }
      put(near, far, dn, cx, cy, dbl);
      P = np;
      wl = w;
    }
  }

  final a = ch[nl];
  final adbl = a.a == a.b;
  final ax = W / 2, ay = H / 2;
  put(a.a, a.b, 'E', ax, ay, adbl);
  final alen = adbl ? S : L, aw = adbl ? L : S;
  final right = <List<int>>[], left = <List<int>>[];
  for (var i = nl + 1; i < ch.length; i++) {
    right.add([ch[i].a, ch[i].b]);
  }
  for (var i = nl - 1; i >= 0; i--) {
    left.add([ch[i].b, ch[i].a]);
  }
  walk(right, [ax + alen / 2, ay], aw, ['E', 'S', 'W', 'N']);
  walk(left, [ax - alen / 2, ay], aw, ['W', 'N', 'E', 'S']);
  return items;
}

bool _layoutOk(List<_Item> items, double W, double H) {
  for (var i = 0; i < items.length; i++) {
    final a = items[i];
    if (a.x < 0 || a.y < 0 || a.x + a.w > W || a.y + a.h > H) return false;
    for (var j = i + 1; j < items.length; j++) {
      final c = items[j];
      if (a.x < c.x + c.w - 2 && c.x < a.x + a.w - 2 && a.y < c.y + c.h - 2 && c.y < a.y + a.h - 2) {
        return false;
      }
    }
  }
  return true;
}

// ---------------- المشهد ثلاثي الأبعاد ----------------
class TableScene extends StatefulWidget {
  final GameView view;
  final Settings st;

  /// عند true تظهر حلقات مضيئة على طرفي السلسلة ويضغط اللاعب على الطرف الذي يريده.
  final bool pick;
  final void Function(String side)? onPick;
  const TableScene({super.key, required this.view, required this.st, this.pick = false, this.onPick});

  @override
  State<TableScene> createState() => _TableSceneState();
}

class _TableSceneState extends State<TableScene> with SingleTickerProviderStateMixin {
  static const double _margin = 26;
  late final Ticker _tk;
  double _t = 0;
  final Map<int, double> _spawn = {};
  final List<double> _impacts = [];
  double _celebrate = -100;
  bool _wasOver = false;
  double _lastImpact = -100;

  String _sig = '';
  List<_Item> _items = const [];
  double _s = 24;

  @override
  void initState() {
    super.initState();
    for (final x in widget.view.chain) {
      _spawn[x.key] = -100;
    }
    _wasOver = widget.view.over;
    _tk = createTicker((d) {
      _t = d.inMicroseconds / 1e6;
      _fireImpacts();
      if (mounted) setState(() {});
    })..start();
  }

  void _fireImpacts() {
    if (_impacts.isEmpty) return;
    final due = _impacts.where((x) => x <= _t).toList();
    if (due.isEmpty) return;
    _impacts.removeWhere((x) => x <= _t);
    _lastImpact = _t;
    Sfx.i.enabled = widget.st.sound;
    Sfx.i.clack();
    if (widget.st.haptics) HapticFeedback.mediumImpact();
  }

  @override
  void didUpdateWidget(covariant TableScene old) {
    super.didUpdateWidget(old);
    final v = widget.view;
    final keys = {for (final x in v.chain) x.key};
    _spawn.removeWhere((k, _) => !keys.contains(k));
    var delay = 0.0;
    for (final x in v.chain) {
      if (!_spawn.containsKey(x.key)) {
        _spawn[x.key] = _t + delay;
        _impacts.add(_t + delay + kFallTime);
        delay += 0.14;
      }
    }
    if (v.over && !_wasOver) _celebrate = _t + 0.25;
    _wasOver = v.over;
  }

  @override
  void dispose() {
    _tk.dispose();
    super.dispose();
  }

  void _layout(double bw, double bh) {
    final ch = widget.view.chain;
    final sig = '${ch.map((e) => '${e.a}${e.b}').join(',')}|${widget.view.nl}|${bw.round()}|${bh.round()}';
    if (sig == _sig) return;
    _sig = sig;
    if (ch.isEmpty) {
      _items = const [];
      return;
    }
    var s = (bw / 12).floorToDouble().clamp(18.0, 34.0).toDouble();
    List<_Item> items;
    for (;;) {
      items = _layoutChain(ch, widget.view.nl, bw, bh, s);
      if (_layoutOk(items, bw, bh) || s <= 12) break;
      s -= 2;
    }
    _items = items;
    _s = s;
  }

  Offset _shake() {
    final dt = _t - _lastImpact;
    if (dt < 0 || dt > 0.6) return Offset.zero;
    final e = math.exp(-12 * dt);
    return Offset(math.sin(_t * 70) * 3.2 * e, math.cos(_t * 55) * 2.4 * e);
  }

  @override
  Widget build(BuildContext context) {
    final th = tableThemes[widget.st.table.clamp(0, tableThemes.length - 1).toInt()];
    final ts = tileStyles[widget.st.tiles.clamp(0, tileStyles.length - 1).toInt()];
    return LayoutBuilder(builder: (context, cs) {
      final pw = cs.maxWidth * 0.9, ph = cs.maxHeight * 1.12;
      _layout(pw - _margin * 2, ph - _margin * 2);
      final base = ClipRect(
        child: Center(
          child: OverflowBox(
            minWidth: pw,
            maxWidth: pw,
            minHeight: ph,
            maxHeight: ph,
            child: Transform.translate(
              offset: _shake(),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0007)
                  ..rotateX(-0.5),
                child: CustomPaint(
                  size: Size(pw, ph),
                  painter: _TablePainter(
                    items: _items,
                    s: _s,
                    t: _t,
                    spawn: _spawn,
                    th: th,
                    ts: ts,
                    celebrate: _celebrate,
                    margin: _margin,
                    shadows: widget.st.shadows,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      if (!widget.pick || widget.onPick == null || widget.view.chain.isEmpty) return base;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: base),
          ..._endMarkers(cs, pw, ph),
        ],
      );
    });
  }

  /// حلقات الضغط على طرفي السلسلة (تُسقَط بنفس منظور الطاولة).
  List<Widget> _endMarkers(BoxConstraints cs, double pw, double ph) {
    final ch = widget.view.chain;
    _Item? find(Tile t) {
      for (final it in _items) {
        if (it.key == t.key) return it;
      }
      return null;
    }

    final cx = pw / 2, cy = ph / 2;
    final tr = Matrix4.identity()
      ..setEntry(3, 2, 0.0007)
      ..rotateX(-0.5);
    final m = Matrix4.translationValues(cx, cy, 0)
      ..multiply(tr)
      ..translate(-cx, -cy);
    final ox = (cs.maxWidth - pw) / 2, oy = (cs.maxHeight - ph) / 2;

    final single = ch.length == 1;
    final out = <Widget>[];
    void add(String side, _Item? it, double dx) {
      if (it == null) return;
      final p = MatrixUtils.transformPoint(m, Offset(_margin + it.x + it.w / 2 + dx, _margin + it.y + it.h / 2));
      final w = math.max(it.w + 16, 58.0), h = math.max(it.h + 16, 58.0);
      final pulse = 1 + 0.07 * math.sin(_t * 6);
      out.add(Positioned(
        left: ox + p.dx - w / 2,
        top: oy + p.dy - h / 2,
        width: w,
        height: h,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onPick!(side),
          child: Transform.scale(
            scale: pulse,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: alpha(kGold, 0.20),
                border: Border.all(color: kGoldLight, width: 3),
                boxShadow: [BoxShadow(color: alpha(kGold, 0.65), blurRadius: 16, spreadRadius: 2)],
              ),
            ),
          ),
        ),
      ));
    }

    final first = find(ch.first), last = find(ch.last);
    if (single && first != null) {
      add('L', first, -(first.w / 2 + 34));
      add('R', first, first.w / 2 + 34);
    } else {
      add('L', first, 0);
      add('R', last, 0);
    }
    out.add(Positioned(
      top: 6,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(color: alpha(Colors.black, 0.65), borderRadius: BorderRadius.circular(20), border: Border.all(color: kGold)),
            child: const Text('اضغط على الطرف اللي تريد تنزّل الحجر يمّه', style: TextStyle(color: kGoldLight, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ),
      ),
    ));
    return out;
  }
}

class _Draw {
  final _Item it;
  final Offset c;
  final double lift, scale;
  final double dt;
  const _Draw(this.it, this.c, this.lift, this.scale, this.dt);
}

final List<Offset> _noise = () {
  final r = math.Random(7);
  return List.generate(600, (_) => Offset(r.nextDouble(), r.nextDouble()));
}();

class _TablePainter extends CustomPainter {
  final List<_Item> items;
  final double s, t, celebrate, margin;
  final Map<int, double> spawn;
  final TableTheme th;
  final TileStyle ts;
  final bool shadows;

  _TablePainter({
    required this.items,
    required this.s,
    required this.t,
    required this.spawn,
    required this.th,
    required this.ts,
    required this.celebrate,
    required this.margin,
    required this.shadows,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawTable(canvas, size);
    canvas.save();
    canvas.translate(margin, margin);

    final list = <_Draw>[];
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      final sp = spawn[it.key] ?? -100;
      final dt = t - sp;
      if (dt < 0) continue; // لم يُسقَط بعد
      var lift = dropHeight(dt);
      final cd = t - celebrate - i * 0.05;
      if (cd > 0 && cd < 0.6) lift += 55 * math.sin(math.pi * cd / 0.6);
      final c = Offset(it.x + it.w / 2, it.y + it.h / 2);
      list.add(_Draw(it, c, lift, 1 + lift / 520, dt));
    }

    // موجات الغبار عند الارتطام
    for (final d in list) {
      final k = (d.dt - kFallTime) / 0.45;
      if (k > 0 && k < 1) {
        canvas.drawCircle(
          d.c,
          s * 0.7 + s * 2.4 * k,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2 * (1 - k) + 0.4
            ..color = alpha(Colors.white, 0.26 * (1 - k)),
        );
      }
    }

    if (shadows) {
      for (final d in list) {
        paintTileShadow(canvas, d.c, d.it.w, d.it.h, d.lift);
      }
    }

    final order = [...list]..sort((p, q) {
        final ap = p.lift > 2 ? 1 : 0, aq = q.lift > 2 ? 1 : 0;
        if (ap != aq) return ap - aq;
        return p.c.dy.compareTo(q.c.dy);
      });
    for (final d in order) {
      canvas.save();
      canvas.translate(d.c.dx, d.c.dy);
      canvas.scale(d.scale);
      canvas.translate(-d.c.dx, -d.c.dy);
      paintTile(canvas, d.c, d.it.w, d.it.h, a: d.it.a, b: d.it.b, vert: d.it.vert, st: ts, lift: d.lift);
      canvas.restore();
    }
    canvas.restore();
  }

  void _drawTable(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final outer = RRect.fromRectAndRadius(full.deflate(4), const Radius.circular(40));

    canvas.drawRRect(
        outer.shift(const Offset(0, 14)),
        Paint()
          ..color = alpha(Colors.black, 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));

    // الإطار الخشبي
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8A5A33), Color(0xFF4E2F18), Color(0xFF2B170A)],
        ).createShader(full),
    );
    canvas.save();
    canvas.clipRRect(outer);
    final grain = Paint()
      ..color = alpha(Colors.black, 0.10)
      ..strokeWidth = 1;
    for (var i = 0; i < 40; i++) {
      final y = size.height * (i + 0.5) / 40;
      canvas.drawLine(Offset(0, y + math.sin(i * 1.7) * 3), Offset(size.width, y + math.cos(i * 1.3) * 3), grain);
    }
    canvas.restore();

    // تطعيم ذهبي
    canvas.drawRRect(
        outer.deflate(7),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = alpha(kGold, 0.9));
    canvas.drawRRect(
        outer.deflate(11),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = alpha(kGoldDark, 0.8));

    // القماش (الجوخ)
    final felt = outer.deflate(16);
    final feltRect = felt.outerRect;
    canvas.drawRRect(
      felt,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.15),
          radius: 0.9,
          colors: [th.felt, th.feltDark],
        ).createShader(feltRect),
    );
    canvas.save();
    canvas.clipRRect(felt);
    final dots = [for (final o in _noise) Offset(feltRect.left + o.dx * feltRect.width, feltRect.top + o.dy * feltRect.height)];
    canvas.drawPoints(
        PointMode.points,
        dots,
        Paint()
          ..color = alpha(Colors.white, 0.07)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round);
    // ظل داخلي
    canvas.drawRRect(
        felt,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 22
          ..color = alpha(Colors.black, 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11));
    // بقعة ضوء
    canvas.drawRect(
      feltRect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.1, -0.35),
          radius: 0.75,
          colors: [alpha(Colors.white, 0.14), alpha(Colors.white, 0)],
        ).createShader(feltRect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TablePainter old) => true;
}

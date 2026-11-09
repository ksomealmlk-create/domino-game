import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/rules.dart';
import '../core/settings.dart';
import '../game/controller.dart';
import '../net/presence.dart';
import '../push/push.dart';
import 'game_page.dart';
import 'avatar_widget.dart';
import 'online_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'theme.dart';
import 'tile_painter.dart';
import 'widgets.dart';

class MenuPage extends StatefulWidget {
  final Settings st;
  const MenuPage({super.key, required this.st});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 100000))..repeat();

  int _taps = 0;
  DateTime _tapT = DateTime(2000);
  void _titleTap() {
    final n = DateTime.now();
    _taps = n.difference(_tapT).inMilliseconds > 1500 ? 1 : _taps + 1;
    _tapT = n;
    if (_taps >= 7) {
      _taps = 0;
      _adminDialog();
    }
  }

  Future<void> _adminDialog() async {
    final c = TextEditingController();
    final pw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إشعارات الإدارة'),
        content: TextField(controller: c, obscureText: true, autofocus: true, decoration: const InputDecoration(hintText: 'كلمة سر الإدارة')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('تفعيل')),
        ],
      ),
    );
    if (pw == null || pw.isEmpty) return;
    Push.toast(await Push.enableAdmin(pw));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _play() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SetupSheet(
        st: widget.st,
        onStart: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => GamePage(ctrl: LocalController(widget.st), st: widget.st),
          ));
        },
      ),
    );
  }

  void _help() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Panel(
          glowing: true,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('طريقة اللعب', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kGoldLight)),
                SizedBox(height: 10),
                Text('• أول فر بالكيم: اللي عنده الدوشيش (6-6) ينزلها أول.', style: TextStyle(height: 1.6)),
                Text('• اختر حجرًا مضيئًا. وإذا ينزل بالطرفين، اضغط على الطرف اللي تريده.', style: TextStyle(height: 1.6)),
                Text('• بـ 4 لاعبين كل واحد مع المقابل له. الفريق اللي يوصل 151 نقطة يفوز بالكيم.', style: TextStyle(height: 1.6)),
                Text('• أول من يخلّص حجاراته يفوز بالفر ويأخذ نقاط حجارات الخصوم.', style: TextStyle(height: 1.6)),
                Text('• إذا انقفلت اللعبة يفوز اللي عنده أقل نقاط، واللي قفلها يبدأ الفر الجاي.', style: TextStyle(height: 1.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileChip() => GestureDetector(
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfilePage(st: widget.st)));
          if (mounted) setState(() {});
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 5, 6, 5),
          decoration: BoxDecoration(
            color: alpha(Colors.black, 0.45),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: alpha(kGold, 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<int>(
                valueListenable: Presence.coins,
                builder: (_, c, __) => c <= 0
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsetsDirectional.only(end: 10),
                        child: Text('🪙 $c', style: const TextStyle(fontWeight: FontWeight.w800, color: kGoldLight)),
                      ),
              ),
              Text(widget.st.displayName, style: const TextStyle(fontWeight: FontWeight.w700, color: kGoldLight)),
              const SizedBox(width: 8),
              AvatarCircle(bytes: widget.st.avatarBytes, name: widget.st.displayName, radius: 16, active: true),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ts = tileStyles[widget.st.tiles.clamp(0, tileStyles.length - 1).toInt()];
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => CustomPaint(painter: _BackdropPainter(_c.value * 100000, ts)),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _c,
                      builder: (_, __) {
                        final t = _c.value * 100000;
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.0018)
                            ..rotateX(-0.25)
                            ..rotateY(math.sin(t * 0.9) * 0.6),
                          child: SizedBox(
                            height: 190,
                            width: 190,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned(left: 20, top: 8, child: Transform.rotate(angle: -0.28, child: TileWidget(tile: const Tile(6, 6), st: ts, w: 70, h: 140))),
                                Positioned(right: 20, top: 24, child: Transform.rotate(angle: 0.24, child: TileWidget(tile: const Tile(3, 5), st: ts, w: 70, h: 140))),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    ShaderMask(
                      shaderCallback: (r) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [kGoldLight, kGold, kGoldDark],
                      ).createShader(r),
                      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _titleTap, child: const FittedBox(fit: BoxFit.scaleDown, child: Text('IRAQI Domeno', style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)))),
                    ),
                    const Text('D O M I N O   1 5 1', style: TextStyle(letterSpacing: 4, fontSize: 12, color: kGold)),
                    const SizedBox(height: 34),
                    _Appear(delay: 0, child: GoldButton('العب ضد الكمبيوتر', icon: Icons.smart_toy_rounded, onTap: _play)),
                    const SizedBox(height: 14),
                    _Appear(
                      delay: 1,
                      child: GoldButton('العب أونلاين', icon: Icons.public_rounded, onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => OnlinePage(st: widget.st)));
                      }),
                    ),
                    const SizedBox(height: 14),
                    _Appear(
                      delay: 2,
                      child: GoldButton('الإعدادات', ghost: true, icon: Icons.settings_rounded, onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsPage(st: widget.st)));
                        if (mounted) setState(() {});
                      }),
                    ),
                    const SizedBox(height: 14),
                    _Appear(delay: 3, child: GoldButton('طريقة اللعب', ghost: true, icon: Icons.help_outline_rounded, fontSize: 15, onTap: _help)),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(child: Align(alignment: Alignment.topRight, child: Padding(padding: const EdgeInsets.all(12), child: _profileChip()))),
        ],
      ),
    );
  }
}

class _Appear extends StatelessWidget {
  final int delay;
  final Widget child;
  const _Appear({required this.delay, required this.child});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 500 + delay * 150),
        curve: Curves.easeOutBack,
        builder: (_, v, c) => Opacity(
          opacity: v.clamp(0.0, 1.0).toDouble(),
          child: Transform.translate(offset: Offset(0, (1 - v) * 40), child: c),
        ),
        child: SizedBox(width: double.infinity, child: child),
      );
}

class _SetupSheet extends StatelessWidget {
  final Settings st;
  final VoidCallback onStart;
  const _SetupSheet({required this.st, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: st,
      builder: (_, __) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Panel(
            glowing: true,
            pad: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: Text('لعبة جديدة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kGoldLight))),
                  const SizedBox(height: 14),
                  const Text('عدد اللاعبين', style: TextStyle(color: Colors.white60)),
                  const SizedBox(height: 6),
                  ChoiceRow(labels: const ['2', '3', '4'], selected: st.players - 2, onSelect: (i) => st.update(() => st.players = i + 2)),
                  const SizedBox(height: 14),
                  const Text('الصعوبة', style: TextStyle(color: Colors.white60)),
                  const SizedBox(height: 6),
                  ChoiceRow(labels: const ['سهل', 'متوسط', 'صعب'], selected: st.level, onSelect: (i) => st.update(() => st.level = i)),
                  const SizedBox(height: 10),
                  const Text('4 لاعبين: كل واحد مع المقابل له · الفوز عند 151 نقطة', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, child: GoldButton('ابدأ', icon: Icons.play_arrow_rounded, onTap: onStart)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Float {
  final double x, speed, phase, size, rot, a, b;
  const _Float(this.x, this.speed, this.phase, this.size, this.rot, this.a, this.b);
}

final List<_Float> _floats = () {
  final r = math.Random(21);
  return List.generate(
      16,
      (_) => _Float(r.nextDouble(), 0.012 + r.nextDouble() * 0.02, r.nextDouble(), 16 + r.nextDouble() * 22,
          (r.nextDouble() - 0.5) * 0.8, r.nextInt(7).toDouble(), r.nextInt(7).toDouble()));
}();

class _BackdropPainter extends CustomPainter {
  final double t;
  final TileStyle st;
  _BackdropPainter(this.t, this.st);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.5),
          radius: 1.3,
          colors: [Color(0xFF26324A), Color(0xFF0B0F18), Color(0xFF050608)],
          stops: [0, 0.6, 1],
        ).createShader(rect),
    );
    // غبار ذهبي
    final dust = Paint()..color = alpha(kGold, 0.35);
    for (var i = 0; i < 40; i++) {
      final fx = (math.sin(i * 12.9898) * 43758.5453).abs() % 1;
      final fy = ((math.sin(i * 78.233) * 12345.678).abs() % 1 + t * 0.01 * (0.3 + (i % 5) * 0.1)) % 1;
      canvas.drawCircle(Offset(fx * size.width, (1 - fy) * size.height), 0.8 + (i % 3) * 0.6, dust);
    }
    // أحجار عائمة
    for (final f in _floats) {
      final y = ((f.phase + t * f.speed) % 1.3) - 0.15;
      final c = Offset(f.x * size.width + math.sin(t * 0.4 + f.phase * 6) * 18, size.height * (1 - y));
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(f.rot + t * 0.25 * f.rot);
      canvas.saveLayer(Rect.fromCenter(center: Offset.zero, width: f.size * 4, height: f.size * 4), Paint()..color = alpha(Colors.white, 0.16));
      paintTile(canvas, Offset.zero, f.size, f.size * 2, a: f.a.toInt(), b: f.b.toInt(), vert: true, st: st);
      canvas.restore();
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) => true;
}

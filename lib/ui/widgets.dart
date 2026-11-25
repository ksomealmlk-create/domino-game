import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

class GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool ghost;
  final double fontSize;
  final EdgeInsets pad;
  const GoldButton(
    this.label, {
    super.key,
    this.onTap,
    this.icon,
    this.ghost = false,
    this.fontSize = 18,
    this.pad = const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(18);
    final fg = ghost ? kGoldLight : kInk;
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: br,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: br,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: ghost
                    ? const [Color(0xFF1D2330), Color(0xFF10141B)]
                    : const [kGoldLight, kGold, kGoldDark],
              ),
              border: Border.all(color: ghost ? alpha(kGold, 0.6) : alpha(Colors.white, 0.5)),
              boxShadow: [BoxShadow(color: alpha(kGold, ghost ? 0.12 : 0.4), blurRadius: 20, offset: const Offset(0, 6))],
            ),
            child: Padding(
              padding: pad,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, size: fontSize + 4, color: ghost ? kGold : kInk), const SizedBox(width: 10)],
                  Text(label, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, color: fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChoiceRow extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  const ChoiceRow({super.key, required this.labels, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < labels.length; i++)
          GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: i == selected ? const LinearGradient(colors: [kGoldLight, kGold]) : null,
                color: i == selected ? null : const Color(0xFF1A1F29),
                border: Border.all(color: i == selected ? kGoldLight : const Color(0x33FFFFFF)),
              ),
              child: Text(labels[i],
                  style: TextStyle(fontWeight: FontWeight.w700, color: i == selected ? kInk : Colors.white70)),
            ),
          ),
      ],
    );
  }
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets pad;
  final bool glowing;
  const Panel({super.key, required this.child, this.pad = const EdgeInsets.all(16), this.glowing = false});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: pad,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B212C), Color(0xFF0F131A)],
          ),
          border: Border.all(color: glowing ? kGold : const Color(0x33FFFFFF), width: glowing ? 1.6 : 1),
          boxShadow: [
            BoxShadow(color: alpha(glowing ? kGold : Colors.black, glowing ? 0.45 : 0.5), blurRadius: glowing ? 18 : 14, offset: const Offset(0, 6)),
          ],
        ),
        child: child,
      );
}

class Confetti extends StatefulWidget {
  const Confetti({super.key});
  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..forward();
  static final _rnd = math.Random(11);
  final _ps = List.generate(80, (_) => [_rnd.nextDouble(), _rnd.nextDouble() * 120 - 60, 60 + _rnd.nextDouble() * 220, _rnd.nextDouble() * 6, _rnd.nextInt(5).toDouble()]);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_ps, _c.value * 6)),
        ),
      );
}

class _ConfettiPainter extends CustomPainter {
  final List<List<double>> ps;
  final double t;
  _ConfettiPainter(this.ps, this.t);
  static const cols = [kGold, kGoldLight, Color(0xFFE0394F), Color(0xFF3BC48B), Color(0xFF5AA9FF)];

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in ps) {
      final x = p[0] * size.width + p[1] * t;
      final y = -20 + p[2] * t + 0.5 * 700 * t * t; // جاذبية
      if (y > size.height + 20) continue;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p[3] * t * 3);
      canvas.drawRect(Rect.fromLTWH(-4, -2, 8, 4), Paint()..color = cols[p[4].toInt()]);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}

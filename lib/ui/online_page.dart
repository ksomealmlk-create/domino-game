import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/settings.dart';
import '../net/online.dart';
import 'game_page.dart';
import 'theme.dart';
import 'widgets.dart';

class OnlinePage extends StatefulWidget {
  final Settings st;
  const OnlinePage({super.key, required this.st});

  @override
  State<OnlinePage> createState() => _OnlinePageState();
}

class _OnlinePageState extends State<OnlinePage> {
  late final OnlineController ctrl = OnlineController(widget.st);
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    OnlineController.wake(widget.st.server);
    ctrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _code.dispose();
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ctrl.status == OnlineStatus.playing) {
      return GamePage(ctrl: ctrl, st: widget.st);
    }
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: kGoldLight),
        title: const Text('اللعب أونلاين', style: TextStyle(fontWeight: FontWeight.w900, color: kGoldLight)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(0, -0.6), radius: 1.2, colors: [Color(0xFF222C3D), kBg]),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (ctrl.status == OnlineStatus.lobby && ctrl.lobby != null) _lobby(ctrl.lobby!) else _entry(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _entry() {
    final st = widget.st;
    final busy = ctrl.status == OnlineStatus.connecting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('إعدادات المباراة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kGoldLight)),
              const SizedBox(height: 10),
              ChoiceRow(labels: const ['لاعبان', '3 لاعبين', '4 لاعبين'], selected: st.players - 2, onSelect: (i) => setState(() => st.update(() => st.players = i + 2))),
              const SizedBox(height: 8),
              const Text('4 لاعبين: كل واحد مع المقابل له · الفوز عند 151 نقطة', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GoldButton(busy ? 'جاري الاتصال… (أول مرة قد ياخذ دقيقة)' : 'مباراة سريعة', icon: Icons.bolt_rounded, onTap: busy ? null : ctrl.quick),
        const SizedBox(height: 12),
        GoldButton('إنشاء غرفة خاصة', ghost: true, icon: Icons.add_circle_outline_rounded, onTap: busy ? null : ctrl.create),
        const SizedBox(height: 16),
        Panel(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.w900),
                  decoration: const InputDecoration(counterText: '', hintText: 'كود الغرفة', border: InputBorder.none),
                ),
              ),
              GoldButton('انضمام', fontSize: 15, pad: const EdgeInsets.symmetric(vertical: 10, horizontal: 20), onTap: busy ? null : () => ctrl.join(_code.text)),
            ],
          ),
        ),
        if (ctrl.error != null) ...[
          const SizedBox(height: 14),
          Text(ctrl.error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFF8A8A), height: 1.5)),
        ],
        const SizedBox(height: 14),
        const Text('المباراة السريعة تبحث عن لاعب حقيقي، وإن لم يوجد خلال ثوانٍ يُضاف بوت تلقائيًا.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5)),
      ],
    );
  }

  Widget _lobby(LobbyInfo l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          glowing: true,
          child: Column(
            children: [
              Text(l.quick ? 'جاري البحث عن لاعبين…' : 'كود الغرفة', style: const TextStyle(color: Colors.white60)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => Clipboard.setData(ClipboardData(text: l.code)),
                child: Text(l.code, style: const TextStyle(fontSize: 54, letterSpacing: 10, fontWeight: FontWeight.w900, color: kGoldLight)),
              ),
              Text(l.n == 4 ? 'فريقان · 151 نقطة' : '151 نقطة', style: const TextStyle(color: kGold)),
              const SizedBox(height: 14),
              for (var i = 0; i < l.n; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(l.players[i] == null ? Icons.hourglass_empty_rounded : Icons.person_rounded, color: l.players[i] == null ? Colors.white30 : kGold),
                      const SizedBox(width: 10),
                      Text(l.players[i] ?? 'بانتظار لاعب…', style: TextStyle(color: l.players[i] == null ? Colors.white38 : Colors.white, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (l.host && !l.quick) GoldButton('ابدأ الآن (البقية بوتات)', icon: Icons.play_arrow_rounded, onTap: ctrl.startNow),
        const SizedBox(height: 10),
        GoldButton('خروج', ghost: true, onTap: ctrl.reset),
      ],
    );
  }
}

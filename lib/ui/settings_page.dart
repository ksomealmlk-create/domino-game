import 'package:flutter/material.dart';
import '../audio/sfx.dart';
import '../core/rules.dart';
import '../core/settings.dart';
import 'theme.dart';
import 'tile_painter.dart';
import 'widgets.dart';

class SettingsPage extends StatefulWidget {
  final Settings st;
  const SettingsPage({super.key, required this.st});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _name = TextEditingController(text: widget.st.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Widget _section(String title, List<Widget> kids) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kGoldLight)),
              const SizedBox(height: 12),
              ...kids,
            ],
          ),
        ),
      );

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(s, style: const TextStyle(color: Colors.white60, fontSize: 13)),
      );

  Widget _switch(String label, bool v, ValueChanged<bool> f) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        activeColor: kGold,
        title: Text(label),
        value: v,
        onChanged: f,
      );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFF0D1118),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: alpha(kGold, 0.4))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: alpha(kGold, 0.3))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kGold)),
      );

  @override
  Widget build(BuildContext context) {
    final st = widget.st;
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('الإعدادات', style: TextStyle(fontWeight: FontWeight.w900, color: kGoldLight)),
        iconTheme: const IconThemeData(color: kGoldLight),
      ),
      body: AnimatedBuilder(
        animation: st,
        builder: (_, __) => ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _section('اللاعب', [
              TextField(controller: _name, decoration: _dec('اسمك'), onChanged: (s) => st.update(() => st.name = s)),
            ]),
            _section('اللعب', [
              _label('عدد اللاعبين (في 4 لاعبين كل واحد مع المقابل له)'),
              ChoiceRow(labels: const ['2', '3', '4'], selected: st.players - 2, onSelect: (i) => st.update(() => st.players = i + 2)),
              _label('صعوبة الكمبيوتر'),
              ChoiceRow(labels: const ['سهل', 'متوسط', 'صعب'], selected: st.level, onSelect: (i) => st.update(() => st.level = i)),
              _label('سرعة الخصوم'),
              ChoiceRow(labels: const ['بطيئة', 'عادية', 'سريعة'], selected: st.speed, onSelect: (i) => st.update(() => st.speed = i)),
              const Padding(padding: EdgeInsets.only(top: 8), child: Text('الفوز عند جمع 151 نقطة', style: TextStyle(color: Colors.white54, fontSize: 12))),
              _switch('إضاءة الأحجار المتاحة', st.hints, (v) => st.update(() => st.hints = v)),
            ]),
            _section('المظهر', [
              _label('لون الطاولة'),
              Row(
                children: [
                  for (var i = 0; i < tableThemes.length; i++)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => st.update(() => st.table = i),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: RadialGradient(colors: [tableThemes[i].felt, tableThemes[i].feltDark]),
                            border: Border.all(color: st.table == i ? kGold : Colors.white24, width: st.table == i ? 3 : 1),
                          ),
                          alignment: Alignment.bottomCenter,
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(tableThemes[i].name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                ],
              ),
              _label('شكل الأحجار'),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (var i = 0; i < tileStyles.length; i++)
                    GestureDetector(
                      onTap: () => st.update(() => st.tiles = i),
                      child: Column(
                        children: [
                          TileWidget(tile: const Tile(4, 6), st: tileStyles[i], w: 40, h: 80, glow: st.tiles == i),
                          Text(tileStyles[i].name, style: TextStyle(fontWeight: FontWeight.w800, color: st.tiles == i ? kGold : Colors.white60)),
                        ],
                      ),
                    ),
                ],
              ),
              _switch('الظلال الواقعية', st.shadows, (v) => st.update(() => st.shadows = v)),
            ]),
            _section('الصوت والاهتزاز', [
              _switch('المؤثرات الصوتية', st.sound, (v) {
                st.update(() => st.sound = v);
                Sfx.i.enabled = v;
                if (v) Sfx.i.clack();
              }),
              _switch('الاهتزاز', st.haptics, (v) => st.update(() => st.haptics = v)),
            ]),
          ],
        ),
      ),
    );
  }
}

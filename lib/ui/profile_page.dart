import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/avatar.dart';
import '../core/settings.dart';
import 'avatar_widget.dart';
import 'menu_page.dart';
import 'theme.dart';
import 'widgets.dart';

/// شاشة أول فتح: اللاعب يكتب اسمه ويختار صورته من الاستوديو.
class ProfilePage extends StatefulWidget {
  final Settings st;
  final bool first;
  const ProfilePage({super.key, required this.st, this.first = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController _name = TextEditingController(text: widget.first ? '' : widget.st.name);
  late String _b64 = widget.st.avatarB64;
  late Uint8List? _bytes = widget.st.avatarBytes;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final b = await pickAvatar();
      if (b != null) {
        _bytes = b;
        _b64 = base64Encode(b);
      }
    } catch (_) {
      _err = 'تعذّر فتح الاستوديو';
    }
    if (mounted) setState(() => _busy = false);
  }

  void _done() {
    final nm = _name.text.trim();
    if (nm.isEmpty) {
      setState(() => _err = 'اكتب اسمك أول');
      return;
    }
    widget.st.update(() {
      widget.st.name = nm;
      widget.st.avatarB64 = _b64;
      widget.st.profileDone = true;
    });
    if (widget.first) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MenuPage(st: widget.st)));
    } else {
      Navigator.of(context).pop();
    }
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        counterText: '',
        filled: true,
        fillColor: const Color(0xFF0D1118),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: alpha(kGold, 0.4))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: alpha(kGold, 0.3))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kGold)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.first ? 'أهلاً بيك!' : 'ملفك الشخصي', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: kGoldLight)),
                const SizedBox(height: 8),
                const Text('اكتب اسمك واختر صورتك حتى يعرفونك أصدقاءك داخل الجولة', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, height: 1.5)),
                const SizedBox(height: 26),
                GestureDetector(
                  onTap: _busy ? null : _pick,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AvatarCircle(bytes: _bytes, name: _name.text, radius: 62, active: true),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: kGold),
                          child: _busy
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: kInk))
                              : const Icon(Icons.photo_camera_rounded, color: kInk, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(onPressed: _busy ? null : _pick, child: const Text('اختر صورة من الاستوديو', style: TextStyle(color: kGoldLight, fontWeight: FontWeight.w700))),
                const SizedBox(height: 14),
                TextField(
                  controller: _name,
                  maxLength: 14,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  decoration: _dec('اسمك'),
                  onChanged: (_) => setState(() => _err = null),
                ),
                if (_err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_err!, style: const TextStyle(color: Color(0xFFE57373)))),
                const SizedBox(height: 22),
                SizedBox(width: double.infinity, child: GoldButton(widget.first ? 'ابدأ اللعب' : 'حفظ', onTap: _done)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

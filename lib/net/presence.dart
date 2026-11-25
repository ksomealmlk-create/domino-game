import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/settings.dart';
import '../push/push.dart';

/// يخبر الإدارة إن اللاعب فتح اللعبة (ويحسب أنه "فاتح" ما دام مفتوحة)، ويجيب رصيد الفلوس.
class Presence with WidgetsBindingObserver {
  Presence._();
  static final Presence i = Presence._();

  /// رصيد الفلوس (من الإدارة). يتحدّث مع كل نبضة.
  static final ValueNotifier<int> coins = ValueNotifier<int>(0);

  /// نصوص من الإدارة (اسم زر الإبلاغ...). تنحفظ بالجهاز حتى تبقى بدون إنترنت.
  static Map<String, String> _txt = {};
  static String t(String key, String def) {
    final v = _txt[key];
    return (v == null || v.trim().isEmpty) ? def : v;
  }

  Settings? _st;
  Timer? _tm;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  static void start(Settings st) {
    i._st = st;
    i._loadTxt();
    WidgetsBinding.instance.addObserver(i);
    i._beat(false);
    i._timer();
  }

  Future<void> _loadTxt() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString('adminTxt');
      if (raw != null) _txt = Map<String, String>.from((jsonDecode(raw) as Map).map((k, v) => MapEntry(k.toString(), v.toString())));
    } catch (_) {}
  }

  void _timer() {
    _tm?.cancel();
    _tm = Timer.periodic(const Duration(minutes: 2), (_) => _beat(true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      // رجع من الخلفية: إذا غاب أكثر من 10 دقائق نعدّها فتحة جديدة
      final away = DateTime.now().difference(_last) > const Duration(minutes: 10);
      _beat(!away);
      _timer();
    } else if (s == AppLifecycleState.paused) {
      _tm?.cancel(); // التطبيق بالخلفية: لا نبضات
    }
  }

  Future<void> _beat(bool hb) async {
    final st = _st;
    if (st == null) return;
    _last = DateTime.now();
    try {
      final hc = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final rq = await hc.postUrl(Uri.parse('${Push.adminUrl}/api/domino/open'));
      rq.headers.contentType = ContentType.json;
      rq.write(jsonEncode({'did': st.deviceId, 'name': st.displayName, 'hb': hb}));
      final rs = await rq.close().timeout(const Duration(seconds: 15));
      final txt = await rs.transform(utf8.decoder).join();
      hc.close();
      final j = jsonDecode(txt) as Map;
      if (j['ok'] == true) {
        final tx = j['txt'];
        if (tx is Map) {
          _txt = tx.map((k, v) => MapEntry(k.toString(), v.toString()));
          (await SharedPreferences.getInstance()).setString('adminTxt', jsonEncode(_txt));
        }
        await _setCoins((j['coins'] as num?)?.toInt() ?? 0);
      }
    } catch (_) {} // لا يوقف اللعبة أبداً
  }

  Future<void> _setCoins(int c) async {
    final p = await SharedPreferences.getInstance();
    final seen = p.getInt('coinsSeen');
    if (seen != null && c > seen) Push.toast(t('giftMsg', '🎁 وصلك {n} فلس من الإدارة').replaceAll('{n}', '${c - seen}'));
    await p.setInt('coinsSeen', c);
    coins.value = c;
  }
}

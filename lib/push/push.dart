import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// إشعارات الدومينو من لوحة الإدارة (قناة Firebase اسمها domino).
/// بيانات Firebase هنا هي بيانات تطبيق العميل (موجودة بأي APK) وليست أسراراً.
class Push {
  static final GlobalKey<ScaffoldMessengerState> messenger = GlobalKey<ScaffoldMessengerState>();
  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
  /// يُضبط من main: يفتح صفحة الأونلاين وينضم للغرفة مباشرة.
  static void Function(String room)? onInvite;
  static String myDid = '';
  static int online = 0; // كم صفحة أونلاين مفتوحة الآن
  static const adminUrl = 'https://skar-subs.ksomealmlk.workers.dev';
  static const _opts = FirebaseOptions(
    apiKey: 'AIzaSyAEN2pMLaWTE7LKq0px-ayaUa_IWsybYuY',
    appId: '1:156665803904:android:9f99195af71a951fe52265',
    messagingSenderId: '156665803904',
    projectId: 'skar-7573a',
    storageBucket: 'skar-7573a.firebasestorage.app',
  );


  /// رسالة قصيرة داخل اللعبة (ترحيب / إعلان من الإدارة).
  static void toast(String t) {
    messenger.currentState?.showSnackBar(SnackBar(content: Text(t), duration: const Duration(seconds: 6), behavior: SnackBarBehavior.floating));
  }

  /// وضع المدير: يتحقق من كلمة سر الإدارة ثم يشترك بقناة سرية تجيك منها إشعارات دخول اللاعبين.
  static Future<String> enableAdmin(String pw) async {
    try {
      final hc = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final rq = await hc.postUrl(Uri.parse('$adminUrl/api/domino/admin_topic'));
      rq.headers.contentType = ContentType.json;
      rq.write(jsonEncode({'password': pw}));
      final rs = await rq.close().timeout(const Duration(seconds: 15));
      final txt = await rs.transform(utf8.decoder).join();
      hc.close();
      final j = jsonDecode(txt) as Map;
      if (j['ok'] != true) return j['error'] == 'blocked' ? 'محاولات كثيرة، انتظر 15 دقيقة' : 'كلمة السر غلط';
      final topic = j['topic'] as String;
      if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: _opts);
      await FirebaseMessaging.instance.requestPermission();
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      await (await SharedPreferences.getInstance()).setString('admTopic', topic);
      return 'تم تفعيل إشعارات الإدارة ✅';
    } catch (_) {
      return 'تعذر الاتصال بالإدارة';
    }
  }

  /// ضغط على إشعار دعوة: ينقله للغرفة (ويتجاهل دعوتك أنت).
  static void _tap(RemoteMessage r) {
    final d = r.data;
    if (d['type'] != 'invite' || d['from'] == myDid) return;
    final room = (d['room'] ?? '').toString();
    if (room.isNotEmpty) _open(room, 0);
  }

  static void _open(String room, int tries) {
    if (navKey.currentState != null && onInvite != null) {
      onInvite!(room);
    } else if (tries < 25) {
      Future.delayed(const Duration(milliseconds: 300), () => _open(room, tries + 1));
    }
  }

  /// دعوة والتطبيق مفتوح: شريط بزر انضمام.
  static void _fgInvite(RemoteMessage r) {
    final d = r.data;
    if (d['from'] == myDid) return;
    final room = (d['room'] ?? '').toString();
    final n = r.notification;
    final t = [if ((n?.title ?? '').isNotEmpty) n!.title!, if ((n?.body ?? '').isNotEmpty) n!.body!].join('\n');
    messenger.currentState?.showSnackBar(SnackBar(
      content: Text(t.isEmpty ? 'لاعب يدعوك للعب' : t),
      duration: const Duration(seconds: 12),
      behavior: SnackBarBehavior.floating,
      action: (room.isEmpty || online > 0) ? null : SnackBarAction(label: 'انضم', onPressed: () => _open(room, 0)),
    ));
  }

  /// لا يوقف اللعبة أبداً إذا فشل (لا إنترنت، رفض الإذن، إلخ).
  static Future<void> init() async {
    try {
      await Firebase.initializeApp(options: _opts);
      final m = FirebaseMessaging.instance;
      await m.requestPermission();
      await m.subscribeToTopic('domino');
      final adm = (await SharedPreferences.getInstance()).getString('admTopic');
      if (adm != null && adm.isNotEmpty) await m.subscribeToTopic(adm);
      // إشعار والتطبيق مفتوح: يظهر شريط بالأعلى لأن النظام ما يعرضه لحاله
      FirebaseMessaging.onMessageOpenedApp.listen(_tap);
      final first = await m.getInitialMessage();
      if (first != null) _tap(first);
      FirebaseMessaging.onMessage.listen((RemoteMessage r) {
        if (r.data['type'] == 'invite') {
          _fgInvite(r);
          return;
        }
        final n = r.notification;
        if (n == null) return;
        final t = [if ((n.title ?? '').isNotEmpty) n.title!, if ((n.body ?? '').isNotEmpty) n.body!].join('\n');
        messenger.currentState?.showSnackBar(SnackBar(content: Text(t), duration: const Duration(seconds: 6), behavior: SnackBarBehavior.floating));
      });
    } catch (_) {}
  }
}

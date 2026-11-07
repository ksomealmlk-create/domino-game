import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../audio/sfx.dart';
import '../core/settings.dart';
import '../core/view.dart';
import '../game/controller.dart';
import '../push/push.dart';

enum OnlineStatus { idle, connecting, lobby, playing, error }

class LobbyInfo {
  final String code;
  final int n;
  final bool five;
  final List<String?> players;
  final bool host, quick;
  const LobbyInfo(this.code, this.n, this.five, this.players, this.host, this.quick);
}

class OnlineController extends GameController {
  final Settings st;
  OnlineController(this.st);

  WebSocket? _ws;
  OnlineStatus status = OnlineStatus.idle;
  String? error;
  LobbyInfo? lobby;
  GameView? _view;
  String? _toast;
  Timer? _tt;
  bool _closed = false;

  @override
  GameView? get view => _view;
  @override
  String? get toast => _toast;
  List<Uint8List?> _avatars = const [];
  @override
  List<Uint8List?> get avatars => _avatars;
  @override
  bool get isOnline => true;

  Future<void> _connect(Map<String, dynamic> first) async {
    error = null;
    status = OnlineStatus.connecting;
    notifyListeners();
    try {
      await _ws?.close();
      var url = st.server.trim();
      if (!url.startsWith('ws')) url = 'wss://$url';
      Object? lastErr;
      WebSocket? ws;
      // السيرفر المجاني ينام عند الخمول ويحتاج حوالي دقيقة ليصحى، لذلك نعيد المحاولة.
      for (var i = 0; i < 4 && ws == null; i++) {
        try {
          ws = await WebSocket.connect(url).timeout(const Duration(seconds: 25));
        } catch (e) {
          lastErr = e;
          await Future.delayed(const Duration(seconds: 2));
        }
      }
      if (ws == null) throw lastErr ?? 'connect failed';
      _ws = ws;
      _ws!.pingInterval = const Duration(seconds: 20);
      _ws!.listen(_onData, onDone: _onDone, onError: (_) => _onDone());
      _send(first);
    } catch (e) {
      status = OnlineStatus.error;
      error = 'تعذّر الاتصال بالسيرفر. تأكد من الإنترنت وجرّب مرة ثانية.';
      notifyListeners();
    }
  }

  /// يوقظ السيرفر مسبقًا (طلب HTTP بسيط) حتى يكون جاهزًا عند الضغط على إنشاء/انضمام.
  static Future<void> wake(String wsUrl) async {
    try {
      final u = Uri.parse(wsUrl.replaceFirst('wss://', 'https://').replaceFirst('ws://', 'http://'));
      final c = HttpClient()..connectionTimeout = const Duration(seconds: 70);
      final r = await c.getUrl(u).then((r) => r.close()).timeout(const Duration(seconds: 70));
      await r.drain();
      c.close();
    } catch (_) {}
  }

  void _send(Map<String, dynamic> m) {
    try {
      _ws?.add(jsonEncode(m));
    } catch (_) {}
  }

  Map<String, dynamic> _cfg() => {'name': st.displayName, 'five': st.five, 'n': st.players, 'target': st.target, 'did': st.deviceId, if (st.avatarB64.isNotEmpty) 'av': st.avatarB64};

  Future<void> quick() => _connect({'t': 'quick', ..._cfg()});
  Future<void> create() => _connect({'t': 'create', ..._cfg()});
  Future<void> join(String code) => _connect({'t': 'join', 'code': _normCode(code), 'name': st.displayName, 'did': st.deviceId, if (st.avatarB64.isNotEmpty) 'av': st.avatarB64});

  static String _normCode(String v) {
    final b = StringBuffer();
    for (final r in v.runes) {
      if (r >= 0x30 && r <= 0x39) {
        b.writeCharCode(r);
      } else if (r >= 0x660 && r <= 0x669) {
        b.writeCharCode(0x30 + r - 0x660);
      } else if (r >= 0x6F0 && r <= 0x6F9) {
        b.writeCharCode(0x30 + r - 0x6F0);
      }
    }
    return b.toString();
  }
  void startNow() => _send({'t': 'start'});

  void _onData(dynamic raw) {
    if (_closed) return;
    try {
      final m = Map<String, dynamic>.from(jsonDecode(raw as String) as Map);
      switch (m['t']) {
        case 'lobby':
          lobby = LobbyInfo(m['code'] as String, m['n'] as int, m['five'] as bool,
              List<String?>.from(m['players'] as List), m['host'] as bool, (m['quick'] as bool?) ?? false);
          if (status != OnlineStatus.playing) status = OnlineStatus.lobby;
          break;
        case 'state':
          final v = GameView.fromJson(m);
          _view = v;
          status = OnlineStatus.playing;
          if (v.msg != null) _setToast(v.msg!);
          Sfx.i.enabled = st.sound;
          break;
        case 'av':
          _avatars = [
            for (final x in (m['list'] as List))
              if (x == null) null else base64Decode(x as String)
          ];
          break;
        case 'note':
          final nt = m['m'];
          if (nt is String && nt.isNotEmpty) Push.toast(nt);
          break;
        case 'err':
          error = m['m'] as String?;
          if (status != OnlineStatus.playing) status = OnlineStatus.error;
          break;
      }
    } catch (_) {}
    notifyListeners();
  }

  void _setToast(String s) {
    _toast = s;
    _tt?.cancel();
    _tt = Timer(const Duration(milliseconds: 1700), () {
      _toast = null;
      notifyListeners();
    });
  }

  void _onDone() {
    if (_closed) return;
    if (status != OnlineStatus.idle) {
      status = OnlineStatus.error;
      error = 'انقطع الاتصال بالسيرفر';
      notifyListeners();
    }
  }

  void reset() {
    _send({'t': 'leave'});
    _ws?.close();
    _ws = null;
    lobby = null;
    _view = null;
    _avatars = const [];
    status = OnlineStatus.idle;
    error = null;
    notifyListeners();
  }

  @override
  void play(int i, String side) => _send({'t': 'play', 'i': i, 'side': side});
  @override
  void draw() => _send({'t': 'draw'});
  @override
  void pass() => _send({'t': 'pass'});
  @override
  void next() => _send({'t': 'next'});
  @override
  void leave() {
    _send({'t': 'leave'});
    _ws?.close();
    _ws = null;
  }

  @override
  void dispose() {
    _closed = true;
    _tt?.cancel();
    leave();
    super.dispose();
  }
}

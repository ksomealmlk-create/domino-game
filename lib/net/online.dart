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

/// غرفة من قائمة الغرف النشطة
class RoomInfo {
  final String code;
  final int n, bots, specs;
  final bool started, quick;
  final List<String> players;
  const RoomInfo(this.code, this.n, this.bots, this.specs, this.started, this.quick, this.players);

  factory RoomInfo.fromJson(Map<String, dynamic> j) => RoomInfo(
        j['code'].toString(),
        (j['n'] as num?)?.toInt() ?? 4,
        (j['bots'] as num?)?.toInt() ?? 0,
        (j['specs'] as num?)?.toInt() ?? 0,
        j['started'] == true,
        j['quick'] == true,
        [for (final x in (j['players'] as List? ?? const [])) x.toString()],
      );
}

class ChatMsg {
  final String name, text;
  final bool mine, spec;
  const ChatMsg(this.name, this.text, this.mine, this.spec);
}

/// مشاهد يطلب يلعب، ينتظر موافقة كل اللاعبين
class VoteReq {
  final String name;
  final int secs;
  const VoteReq(this.name, this.secs);
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
  Timer? _tt, _vt;
  bool _closed = false;
  bool _inviteAfter = false;
  bool _browsing = false;

  // قائمة الغرف، الدردشة، المشاهدون، التصويت
  List<RoomInfo> rooms = const [];
  bool roomsLoaded = false;
  final List<ChatMsg> chat = [];
  int unread = 0;
  bool chatOpen = false;
  List<String> specNames = const [];
  VoteReq? vote;

  @override
  GameView? get view => _view;
  @override
  String? get toast => _toast;
  List<Uint8List?> _avatars = const [];
  @override
  List<Uint8List?> get avatars => _avatars;
  @override
  bool get isOnline => true;

  bool get spectating => status == OnlineStatus.playing && (_view?.spectator ?? false);

  /// يفتح الاتصال (أو يستعمل المفتوح). السيرفر المجاني ينام ويحتاج وقت ليصحى، لذلك نعيد المحاولة.
  Future<bool> _open() async {
    if (_ws != null) return true;
    var url = st.server.trim();
    if (!url.startsWith('ws')) url = 'wss://$url';
    WebSocket? ws;
    for (var i = 0; i < 4 && ws == null && !_closed; i++) {
      try {
        ws = await WebSocket.connect(url).timeout(const Duration(seconds: 25));
      } catch (_) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    if (ws == null) return false;
    final w = ws;
    if (_closed) {
      w.close();
      return false;
    }
    _ws = w;
    w.pingInterval = const Duration(seconds: 20);
    w.listen(_onData, onDone: () => _onDone(w), onError: (_) => _onDone(w));
    return true;
  }

  Future<void> _connect(Map<String, dynamic> first) async {
    error = null;
    chat.clear();
    unread = 0;
    specNames = const [];
    vote = null;
    status = OnlineStatus.connecting;
    notifyListeners();
    final ok = await _open();
    if (_closed) return;
    if (!ok) {
      status = OnlineStatus.error;
      error = 'تعذّر الاتصال بالسيرفر. تأكد من الإنترنت وجرّب مرة ثانية.';
      notifyListeners();
      return;
    }
    _send(first);
  }

  /// يتصل بالسيرفر وهو بالقائمة الرئيسية حتى يعرض الغرف النشطة.
  Future<void> browse() async {
    if (_closed || _browsing) return;
    if (_ws != null) {
      refreshRooms();
      return;
    }
    _browsing = true;
    final ok = await _open();
    _browsing = false;
    if (ok) refreshRooms();
  }

  void refreshRooms() {
    if (_closed) return;
    if (_ws != null) {
      _send({'t': 'rooms'});
    } else if (!_browsing && (status == OnlineStatus.idle || status == OnlineStatus.error)) {
      browse();
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
  Future<void> create() {
    _inviteAfter = st.inviteOnCreate;
    return _connect({'t': 'create', ..._cfg()});
  }

  /// يبلّغ كل اللاعبين بغرفتك (إشعار ينقلهم مباشرة لها) — يشتغل بالانتظار وأثناء اللعب
  void invite() => _send({'t': 'invite'});

  /// ينضم للغرفة. إذا كانت تلعب الآن يدخل مشاهدًا.
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

  // ----- دردشة / مشاهدة / تصويت -----
  void sendChat(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    _send({'t': 'chat', 'm': t});
  }

  void openChat() {
    chatOpen = true;
    unread = 0;
    notifyListeners();
  }

  void closeChat() {
    chatOpen = false;
  }

  /// مشاهد: أريد ألعب من الجولة القادمة (يحتاج موافقة كل اللاعبين)
  void wantPlay() => _send({'t': 'wantplay'});

  void answerVote(bool ok) {
    _send({'t': 'vote', 'ok': ok});
    vote = null;
    _vt?.cancel();
    notifyListeners();
  }

  void _onData(dynamic raw) {
    if (_closed) return;
    try {
      final m = Map<String, dynamic>.from(jsonDecode(raw as String) as Map);
      switch (m['t']) {
        case 'lobby':
          lobby = LobbyInfo(m['code'] as String, m['n'] as int, m['five'] as bool,
              List<String?>.from(m['players'] as List), m['host'] as bool, (m['quick'] as bool?) ?? false);
          if (status != OnlineStatus.playing) status = OnlineStatus.lobby;
          if (_inviteAfter && lobby!.host && !lobby!.quick) {
            _inviteAfter = false;
            invite();
          }
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
        case 'rooms':
          rooms = [for (final x in (m['list'] as List)) RoomInfo.fromJson(Map<String, dynamic>.from(x as Map))];
          roomsLoaded = true;
          break;
        case 'chat':
          final mine = m['mine'] == true;
          final nm = (m['n'] ?? '').toString();
          final tx = (m['m'] ?? '').toString();
          chat.add(ChatMsg(nm, tx, mine, m['sp'] == true));
          if (chat.length > 80) chat.removeAt(0);
          if (!mine && !chatOpen) {
            unread++;
            _setToast('💬 $nm: ${tx.length > 40 ? '${tx.substring(0, 40)}…' : tx}');
          }
          break;
        case 'specs':
          specNames = [for (final x in (m['list'] as List)) x.toString()];
          break;
        case 'vote':
          final secs = (m['secs'] as num?)?.toInt() ?? 20;
          vote = VoteReq((m['name'] ?? '').toString(), secs);
          _vt?.cancel();
          _vt = Timer(Duration(seconds: secs + 1), () {
            vote = null;
            notifyListeners();
          });
          break;
        case 'vote_end':
          vote = null;
          _vt?.cancel();
          break;
        case 'closed':
          error = (m['m'] ?? 'انتهت الغرفة').toString();
          status = OnlineStatus.error;
          _view = null;
          lobby = null;
          vote = null;
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

  void _onDone(WebSocket w) {
    if (_closed || !identical(w, _ws)) return;
    _ws = null;
    if (status != OnlineStatus.idle) {
      status = OnlineStatus.error;
      error ??= 'انقطع الاتصال بالسيرفر';
    }
    notifyListeners();
  }

  /// يخرج من الغرفة لكن يبقي الاتصال مفتوحًا حتى تظهر قائمة الغرف.
  void reset() {
    _send({'t': 'leave'});
    lobby = null;
    _view = null;
    _avatars = const [];
    chat.clear();
    unread = 0;
    specNames = const [];
    vote = null;
    status = OnlineStatus.idle;
    error = null;
    notifyListeners();
    refreshRooms();
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
    _vt?.cancel();
    leave();
    super.dispose();
  }
}

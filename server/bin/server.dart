// سيرفر دومينو أونلاين — Dart خالص (dart:io) بدون أي مكتبات خارجية.
// التشغيل:  cd server && dart run bin/server.dart   (المنفذ 8080 أو متغير PORT)
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../lib/core/rules.dart';
import '../../lib/core/view.dart';

final Map<String, Room> rooms = {};
final Set<Client> clients = {};
final Random _rnd = Random();

class Seat {
  String name;
  Client? client;
  bool bot;
  bool ready = false;
  String? av;
  Seat(this.name, {this.client, this.bot = false});
}

class Client {
  final WebSocket ws;
  String name = 'لاعب';
  String did = '';
  String? av;
  Room? room;
  int seat = -1;
  Client(this.ws);

  void send(Map<String, dynamic> m) {
    try {
      ws.add(jsonEncode(m));
    } catch (_) {}
  }

  void err(String m) => send({'t': 'err', 'm': m});
}

class Room {
  final String code;
  final bool five, quick;
  final int n, target;
  final List<Seat?> seats;
  DominoGame? game;
  bool started = false;
  bool _endRep = false;
  Timer? _botT, _fillT, _nextT;

  Room(this.code, this.five, this.n, this.target, {this.quick = false}) : seats = List<Seat?>.filled(n, null);

  List<String> get names => [for (final s in seats) s?.name ?? '-'];
  bool get hasHumans => seats.any((s) => s != null && !s.bot && s.client != null);

  int add(Client c) {
    for (var i = 0; i < n; i++) {
      if (seats[i] == null) {
        seats[i] = Seat(c.name, client: c)..av = c.av;
        c.room = this;
        c.seat = i;
        return i;
      }
    }
    return -1;
  }

  bool get full => !seats.contains(null);

  void lobby() {
    for (var i = 0; i < n; i++) {
      final s = seats[i];
      if (s == null || s.client == null) continue;
      s.client!.send({
        't': 'lobby',
        'code': code,
        'n': n,
        'five': five,
        'quick': quick,
        'host': i == 0,
        'players': [for (final x in seats) x?.name],
      });
    }
    sendAvatars();
  }

  /// يرسل صور اللاعبين لكل واحد بترتيبه النسبي (0 = هو نفسه).
  void sendAvatars() {
    for (var p = 0; p < n; p++) {
      final s = seats[p];
      if (s == null || s.client == null) continue;
      s.client!.send({
        't': 'av',
        'list': [for (var r = 0; r < n; r++) seats[(p + r) % n]?.av],
      });
    }
  }

  void start() {
    if (started) return;
    _fillT?.cancel();
    var b = 1;
    for (var i = 0; i < n; i++) {
      seats[i] ??= Seat('بوت ${b++}', bot: true);
    }
    started = true;
    Admin.started(this);
    sendAvatars();
    game = DominoGame(five: five, n: n, target: target);
    final r = game!.startRound();
    broadcast(last: r == null ? null : LastMove.from(r), msg: r == null ? '${seats[game!.turn]!.name} يبدأ الجولة' : null);
    _afterAction();
  }

  void broadcast({LastMove? last, String? msg}) {
    final g = game;
    if (g == null) return;
    for (var p = 0; p < n; p++) {
      final s = seats[p];
      if (s == null || s.client == null) continue;
      final v = GameView.fromGame(g, p, names, last: last, msg: msg);
      s.client!.send({'t': 'state', ...v.toJson()});
    }
  }

  void _afterAction() {
    final g = game!;
    _botT?.cancel();
    if (g.over) {
      if (g.matchOver && !_endRep) {
        _endRep = true;
        Admin.ended(this, g);
      }
      for (final s in seats) {
        if (s != null) s.ready = s.bot;
      }
      _nextT?.cancel();
      if (!g.matchOver) {
        _nextT = Timer(const Duration(seconds: 25), () {
          if (game != null && game!.over && !game!.matchOver) _newRound();
        });
      }
      return;
    }
    if (seats[g.turn]!.bot) {
      _botT = Timer(const Duration(milliseconds: 1100), _botStep);
    }
  }

  void _botStep() {
    final g = game;
    if (g == null || g.over) return;
    final p = g.turn;
    final s = seats[p]!;
    if (!s.bot) return;
    final m = g.chooseMove(p, 1);
    if (m != null) {
      final r = g.play(p, m.i, m.side);
      broadcast(last: LastMove.from(r), msg: r.gained > 0 ? '${s.name}  +${r.gained}' : null);
    } else if (g.stock.isNotEmpty) {
      g.draw(p);
      broadcast(msg: '${s.name} سحب حجرًا');
    } else {
      g.pass(p);
      broadcast(msg: '${s.name} تخطّى الدور');
    }
    _afterAction();
  }

  void _newRound() {
    final g = game!;
    if (g.matchOver) {
      game = DominoGame(five: five, n: n, target: target);
      _endRep = false;
    }
    final r = game!.startRound();
    broadcast(last: r == null ? null : LastMove.from(r), msg: r == null ? '${seats[game!.turn]!.name} يبدأ الجولة' : null);
    _afterAction();
  }

  // ----- أفعال اللاعبين -----
  void onPlay(Client c, int i, String side) {
    final g = game;
    if (g == null || g.over || g.turn != c.seat) return;
    final hand = g.hands[c.seat];
    if (i < 0 || i >= hand.length) return;
    if (!sidesFor(hand[i], g.chain).contains(side)) return c.err('حركة غير صالحة');
    final r = g.play(c.seat, i, side);
    broadcast(last: LastMove.from(r), msg: r.gained > 0 ? '${c.name}  +${r.gained}' : null);
    _afterAction();
  }

  void onDraw(Client c) {
    final g = game;
    if (g == null || g.over || g.turn != c.seat || g.canPlay(c.seat) || g.stock.isEmpty) return;
    g.draw(c.seat);
    broadcast(msg: '${c.name} سحب حجرًا');
  }

  void onPass(Client c) {
    final g = game;
    if (g == null || g.over || g.turn != c.seat || g.canPlay(c.seat) || g.stock.isNotEmpty) return;
    g.pass(c.seat);
    broadcast(msg: '${c.name} تخطّى الدور');
    _afterAction();
  }

  void onNext(Client c) {
    final g = game;
    if (g == null || !g.over) return;
    seats[c.seat]!.ready = true;
    if (seats.every((s) => s == null || s.ready || s.client == null)) {
      _nextT?.cancel();
      _newRound();
    }
  }

  void onLeave(Client c) {
    final i = c.seat;
    c.room = null;
    c.seat = -1;
    if (i < 0 || i >= n) return;
    final s = seats[i];
    if (s == null) return;
    if (!started) {
      seats[i] = null;
      if (!seats.any((x) => x != null)) {
        close();
      } else {
        // أعد ترقيم المقاعد بعد خروج لاعب من الردهة
        final cur = seats.whereType<Seat>().toList();
        for (var k = 0; k < n; k++) {
          seats[k] = k < cur.length ? cur[k] : null;
          seats[k]?.client?.seat = k;
        }
        lobby();
      }
      return;
    }
    // أثناء اللعب: يتحوّل مقعد المغادر إلى بوت
    s.client = null;
    s.bot = true;
    s.ready = true;
    s.name = '${s.name} (بوت)';
    if (!hasHumans) {
      close();
      return;
    }
    broadcast(msg: '${s.name} غادر — حلّ مكانه بوت');
    final g = game!;
    if (!g.over && g.turn == i) _afterAction();
    if (g.over) onNextCheck();
  }

  void onNextCheck() {
    if (seats.every((s) => s == null || s.ready || s.client == null) && game != null && game!.over) {
      _nextT?.cancel();
      _newRound();
    }
  }

  void close() {
    _botT?.cancel();
    _fillT?.cancel();
    _nextT?.cancel();
    rooms.remove(code);
  }
}

String _newCode() {
  for (;;) {
    final c = (1000 + _rnd.nextInt(9000)).toString();
    if (!rooms.containsKey(c)) return c;
  }
}

Room? _findQuick(bool five, int n) {
  for (final r in rooms.values) {
    if (r.quick && !r.started && r.five == five && r.n == n && !r.full) return r;
  }
  return null;
}

Room _makeQuick(bool five, int n, int target) {
  final r = Room(_newCode(), five, n, target, quick: true);
  rooms[r.code] = r;
  r._fillT = Timer(const Duration(seconds: 12), () {
    if (!r.started && r.seats.any((s) => s != null)) r.start();
  });
  return r;
}

void handle(Client c, Map<String, dynamic> m) {
  switch (m['t']) {
    case 'quick':
    case 'create':
      {
        if (c.room != null) c.room!.onLeave(c);
        c.name = _name(m['name']);
        c.av = _av(m['av']);
        c.did = _did(m['did'], c.name);
        if (!Admin.allow(c)) return;
        const five = false;
        final n = (m['n'] is int && m['n'] >= 2 && m['n'] <= 4) ? m['n'] as int : 4;
        const target = 151;
        final Room r;
        if (m['t'] == 'quick') {
          r = _findQuick(five, n) ?? _makeQuick(five, n, target);
        } else {
          r = Room(_newCode(), five, n, target);
          rooms[r.code] = r;
        }
        r.add(c);
        r.lobby();
        Admin.joined(c, r);
        if (r.quick && r.full) r.start();
        break;
      }
    case 'join':
      {
        final r = rooms[_normCode(m['code'])];
        if (r == null || r.started) return c.err('الغرفة غير موجودة أو بدأت اللعب');
        c.name = _name(m['name']);
        c.av = _av(m['av']);
        c.did = _did(m['did'], c.name);
        if (!Admin.allow(c)) return;
        if (r.add(c) < 0) return c.err('الغرفة ممتلئة');
        r.lobby();
        Admin.joined(c, r);
        if (r.quick && r.full) r.start();
        break;
      }
    case 'start':
      {
        final r = c.room;
        if (r != null && c.seat == 0) r.start();
        break;
      }
    case 'play':
      c.room?.onPlay(c, (m['i'] as int?) ?? -1, (m['side'] ?? '').toString());
      break;
    case 'draw':
      c.room?.onDraw(c);
      break;
    case 'pass':
      c.room?.onPass(c);
      break;
    case 'next':
      c.room?.onNext(c);
      break;
    case 'leave':
      c.room?.onLeave(c);
      break;
  }
}

/// يحوّل الأرقام العربية/الفارسية (٠-٩ / ۰-۹) إلى 0-9 ويحذف أي رمز غير رقم.
String _normCode(dynamic v) {
  final b = StringBuffer();
  for (final r in (v ?? '').toString().runes) {
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

/// صورة اللاعب: نص base64 فقط وبحجم معقول، وإلا تُتجاهل.
String? _av(dynamic v) {
  final s = (v ?? '').toString();
  if (s.isEmpty || s.length > 60000) return null;
  return RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(s) ? s : null;
}

String _name(dynamic v) {
  final s = (v ?? '').toString().trim();
  if (s.isEmpty) return 'لاعب';
  return s.length > 14 ? s.substring(0, 14) : s;
}

String _did(dynamic v, String name) {
  final s = (v ?? '').toString();
  if (RegExp(r'^[A-Za-z0-9]{8,40}$').hasMatch(s)) return s;
  return 'old-$name'; // نسخة قديمة بدون معرّف جهاز
}

/// الربط مع لوحة الإدارة (Cloudflare Worker). يشتغل فقط إذا ضبطت ADMIN_URL و ADMIN_KEY في Render.
/// أي فشل بالاتصال ما يأثر على اللعب أبداً.
class Admin {
  static final String url = (Platform.environment['ADMIN_URL'] ?? '').trim().replaceAll(RegExp(r'/+$'), '');
  static final String key = (Platform.environment['ADMIN_KEY'] ?? '').trim();
  static bool get on => url.isNotEmpty && key.isNotEmpty;

  static bool maint = false;
  static String maintMsg = 'اللعبة تحت الصيانة حالياً، ارجع بعد شوي';
  static String welcome = '';
  static Set<String> bans = {};
  static final HttpClient _http = HttpClient()..connectionTimeout = const Duration(seconds: 8);

  static Future<Map<String, dynamic>?> _post(String path, Map<String, dynamic> body) async {
    if (!on) return null;
    try {
      final rq = await _http.postUrl(Uri.parse('$url$path'));
      rq.headers.contentType = ContentType.json;
      rq.write(jsonEncode({'key': key, ...body}));
      final rs = await rq.close().timeout(const Duration(seconds: 12));
      final txt = await rs.transform(utf8.decoder).join();
      if (rs.statusCode != 200) return null;
      return Map<String, dynamic>.from(jsonDecode(txt) as Map);
    } catch (_) {
      return null;
    }
  }

  /// يسمح للاعب بالدخول؟ (صيانة / حظر)
  static bool allow(Client c) {
    if (bans.contains(c.did)) {
      c.err('تم حظرك من اللعب أونلاين');
      c.ws.close();
      return false;
    }
    if (maint) {
      c.err(maintMsg);
      c.ws.close();
      return false;
    }
    return true;
  }

  static void joined(Client c, Room r) {
    if (welcome.isNotEmpty) c.send({'t': 'note', 'm': welcome});
    _post('/api/domino/ev', {
      'events': [
        {'k': 'join', 'did': c.did, 'name': c.name, 'room': r.code, 'online': clients.length}
      ]
    });
  }

  static List<Map<String, String>> _humans(Room r) => [
        for (final s in r.seats)
          if (s != null && !s.bot && s.client != null) {'did': s.client!.did, 'name': s.name}
      ];

  static void started(Room r) {
    _post('/api/domino/ev', {
      'events': [
        {'k': 'start', 'room': r.code, 'players': _humans(r)}
      ]
    });
  }

  static void ended(Room r, DominoGame g) {
    final win = <Map<String, String>>[];
    for (var i = 0; i < r.seats.length; i++) {
      final s = r.seats[i];
      if (s != null && !s.bot && s.client != null && g.sameTeam(i, g.matchWinner)) win.add({'did': s.client!.did, 'name': s.name});
    }
    _post('/api/domino/ev', {
      'events': [
        {'k': 'end', 'room': r.code, 'players': _humans(r), 'win': win}
      ]
    });
  }

  /// كل 30 ثانية: يرسل لقطة حيّة ويستلم الإعدادات (صيانة، حظر، رسالة ترحيب)
  static Future<void> tick() async {
    final snap = {
      'online': clients.length,
      'rooms': [
        for (final r in rooms.values.take(40))
          {
            'code': r.code,
            'n': r.n,
            'started': r.started,
            'quick': r.quick,
            'names': [for (final s in r.seats) if (s != null && !s.bot) s.name],
            'bots': r.seats.where((s) => s != null && s.bot).length,
          }
      ],
    };
    final j = await _post('/api/domino/live', {'snap': snap});
    final cfg = j == null ? null : j['cfg'];
    if (cfg is! Map) return;
    maint = cfg['maint'] == true;
    maintMsg = (cfg['maintMsg'] ?? maintMsg).toString();
    welcome = (cfg['welcome'] ?? '').toString();
    bans = {for (final x in (cfg['bans'] as List? ?? const [])) x.toString()};
    for (final c in clients.toList()) {
      if (bans.contains(c.did)) {
        c.err('تم حظرك من اللعب أونلاين');
        c.ws.close();
      }
    }
  }

  static void start() {
    if (!on) {
      print('Admin link OFF (ADMIN_URL / ADMIN_KEY not set)');
      return;
    }
    print('Admin link ON -> $url');
    tick();
    Timer.periodic(const Duration(seconds: 30), (_) => tick());
  }
}

Future<void> main() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  print('Domino server listening on :$port');
  Admin.start();
  await for (final req in server) {
    if (WebSocketTransformer.isUpgradeRequest(req)) {
      try {
        final ws = await WebSocketTransformer.upgrade(req);
        ws.pingInterval = const Duration(seconds: 20);
        final c = Client(ws);
        clients.add(c);
        ws.listen((data) {
          try {
            handle(c, Map<String, dynamic>.from(jsonDecode(data as String) as Map));
          } catch (e) {
            c.err('رسالة غير صالحة');
          }
        }, onDone: () {
          clients.remove(c);
          c.room?.onLeave(c);
        }, onError: (_) {
          clients.remove(c);
          c.room?.onLeave(c);
        });
      } catch (_) {}
    } else {
      req.response
        ..statusCode = 200
        ..write('Domino server OK — rooms: ${rooms.length}');
      await req.response.close();
    }
  }
}

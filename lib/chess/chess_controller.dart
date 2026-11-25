import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../audio/sfx.dart';
import '../core/settings.dart';
import 'engine.dart';
import 'game.dart';

class ChessController extends ChangeNotifier {
  final Settings st;
  final bool humanWhite;
  final int level; // 0 سهل 1 متوسط 2 صعب
  final ChessGame g = ChessGame();

  int selected = -1;
  Map<int, bool> targets = {}; // مربع الهدف → هل هو أخذ
  List<int> _selMoves = [];
  MoveInfo? anim;
  int animId = 0;
  bool thinking = false;
  bool hinting = false;
  int hintFrom = -1, hintTo = -1;
  List<int>? pendingPromo;
  String? toast;

  Timer? _tt;
  bool _disposed = false;
  int _gen = 0;
  final Random _rnd = Random();

  ChessController(this.st, {required this.humanWhite, required this.level}) {
    if (!humanWhite) _bot();
  }

  bool get humanTurn => !g.over && g.whiteToMove == humanWhite;
  int get lastFrom => g.log.isEmpty ? -1 : g.log.last.from;
  int get lastTo => g.log.isEmpty ? -1 : g.log.last.to;
  int get checkSq => (g.inCheck && (!g.over || g.end == ChessEnd.checkmate)) ? g.pos.kingPos[g.whiteToMove ? 0 : 1] : -1;
  int get humanSide => humanWhite ? 1 : -1;

  void _say(String s) {
    toast = s;
    _tt?.cancel();
    _tt = Timer(const Duration(milliseconds: 1800), () {
      toast = null;
      if (!_disposed) notifyListeners();
    });
  }

  void _clearSel() {
    selected = -1;
    targets = {};
    _selMoves = [];
  }

  void tapSquare(int sq) {
    if (!humanTurn || thinking || pendingPromo != null) return;
    final b = g.pos.board;
    final p = b[sq];
    final mine = p != 0 && (p > 0) == humanWhite;
    if (selected >= 0 && targets.containsKey(sq)) {
      final ms = [for (final m in _selMoves) if (mvTo(m) == sq) m];
      if (ms.length > 1) {
        pendingPromo = ms;
        notifyListeners();
        return;
      }
      _human(ms.first);
      return;
    }
    if (mine && sq != selected) {
      selected = sq;
      _selMoves = g.legalFrom(sq);
      targets = {
        for (final m in _selMoves) mvTo(m): b[mvTo(m)] != 0 || (b[sq].abs() == kP && (sq & 7) != (mvTo(m) & 7))
      };
      if (st.haptics) HapticFeedback.selectionClick();
      Sfx.i.enabled = st.sound;
      Sfx.i.tick();
    } else {
      _clearSel();
    }
    notifyListeners();
  }

  void choosePromo(int type) {
    final ms = pendingPromo;
    if (ms == null) return;
    pendingPromo = null;
    final m = ms.firstWhere((x) => mvPromo(x) == type, orElse: () => ms.first);
    _human(m);
  }

  void cancelPromo() {
    pendingPromo = null;
    notifyListeners();
  }

  void _human(int m) {
    _clearSel();
    hintFrom = hintTo = -1;
    _apply(m);
  }

  void _apply(int m) {
    final info = g.play(m);
    if (info == null) return;
    anim = info;
    animId++;
    Sfx.i.enabled = st.sound;
    if (info.mate) {
      Sfx.i.clack();
    } else if (info.check) {
      Sfx.i.check();
    } else if (info.isCapture) {
      Sfx.i.clack();
    } else {
      Sfx.i.tock();
    }
    if (st.haptics) {
      info.isCapture ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
    }
    if (info.check && !info.mate) _say('كش!');
    notifyListeners();
    if (!g.over && !humanTurn) _bot();
  }

  Future<void> _bot() async {
    thinking = true;
    final gen = ++_gen;
    notifyListeners();
    final started = DateTime.now();
    final fen = g.pos.toFen();
    int m;
    try {
      m = await compute(chessBestMove, <dynamic>[fen, level, _rnd.nextInt(1 << 30), -1]);
    } catch (_) {
      final ms = g.legalMoves();
      m = ms.isEmpty ? -1 : ms[_rnd.nextInt(ms.length)];
    }
    final el = DateTime.now().difference(started).inMilliseconds;
    if (el < 750) await Future<void>.delayed(Duration(milliseconds: 750 - el));
    if (_disposed || gen != _gen) return;
    thinking = false;
    if (m < 0 || g.over) {
      notifyListeners();
      return;
    }
    _apply(m);
  }

  Future<void> hint() async {
    if (!humanTurn || thinking || hinting) return;
    hinting = true;
    notifyListeners();
    final ply = g.log.length;
    int m;
    try {
      m = await compute(chessBestMove, <dynamic>[g.pos.toFen(), 2, _rnd.nextInt(1 << 30), 900]);
    } catch (_) {
      m = -1;
    }
    hinting = false;
    if (_disposed) return;
    if (m >= 0 && ply == g.log.length) {
      hintFrom = mvFrom(m);
      hintTo = mvTo(m);
      _clearSel();
    }
    notifyListeners();
  }

  void undo() {
    if (g.log.isEmpty) return;
    _gen++;
    thinking = false;
    _clearSel();
    pendingPromo = null;
    hintFrom = hintTo = -1;
    g.undoOne();
    if (g.whiteToMove != humanWhite && g.log.isNotEmpty) g.undoOne();
    anim = null;
    animId++;
    notifyListeners();
    if (!g.over && !humanTurn) _bot();
  }

  void resign() {
    if (g.over) return;
    _gen++;
    thinking = false;
    _clearSel();
    g.resign(humanSide);
    notifyListeners();
  }

  void restart() {
    _gen++;
    thinking = false;
    _clearSel();
    pendingPromo = null;
    hintFrom = hintTo = -1;
    g.reset();
    anim = null;
    animId++;
    notifyListeners();
    if (!humanWhite) _bot();
  }

  @override
  void dispose() {
    _disposed = true;
    _gen++;
    _tt?.cancel();
    super.dispose();
  }
}

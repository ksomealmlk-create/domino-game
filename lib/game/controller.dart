import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../audio/sfx.dart';
import '../core/rules.dart';
import '../core/settings.dart';
import '../core/view.dart';

abstract class GameController extends ChangeNotifier {
  GameView? get view;
  String? get toast;

  /// صور اللاعبين بالترتيب النسبي (0 = أنا). null = بدون صورة.
  List<Uint8List?> get avatars;
  bool get isOnline;
  void play(int i, String side);
  void draw();
  void pass();
  void next();
  void leave();
}

class LocalController extends GameController {
  final Settings st;
  late DominoGame g;
  late final List<String> names;
  GameView? _view;
  String? _toast;
  Timer? _bt, _tt;

  LocalController(this.st) {
    final n = st.players;
    names = [st.displayName, n == 2 ? 'الكمبيوتر' : 'خالد', 'سارة', 'عمر'];
    g = _newGame();
    _startRound();
  }

  DominoGame _newGame() => DominoGame(five: st.five, n: st.players, target: st.target);

  @override
  GameView? get view => _view;
  @override
  String? get toast => _toast;
  @override
  List<Uint8List?> get avatars => [st.avatarBytes, null, null, null];
  @override
  bool get isOnline => false;

  void _startRound() {
    final r = g.startRound();
    final starter = r == null ? (g.turn == 0 ? 'أنت تبدأ الجولة' : '${names[g.turn]} يبدأ الجولة') : null;
    _emit(last: r == null ? null : LastMove.from(r), msg: starter);
    _after();
  }

  void _emit({LastMove? last, String? msg}) {
    _view = GameView.fromGame(g, 0, names, last: last, msg: msg);
    if (msg != null) {
      _toast = msg;
      _tt?.cancel();
      _tt = Timer(const Duration(milliseconds: 1700), () {
        _toast = null;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void _after() {
    if (g.over) return;
    _bt?.cancel();
    if (g.turn != 0) {
      _bt = Timer(Duration(milliseconds: st.botDelayMs), _botStep);
    } else if (!g.canPlay(0) && g.stock.isEmpty) {
      _toast = 'ما عندك حجر مناسب — تخطّي تلقائي';
      notifyListeners();
      _bt = Timer(const Duration(milliseconds: 1100), () {
        if (!g.over && g.turn == 0) pass();
      });
    }
  }

  void _botStep() {
    if (g.over) return;
    final p = g.turn;
    final m = g.chooseMove(p, st.level);
    if (m != null) {
      final r = g.play(p, m.i, m.side);
      _emit(last: LastMove.from(r), msg: r.gained > 0 ? '${names[p]}  +${r.gained}' : null);
    } else if (g.stock.isNotEmpty) {
      g.draw(p);
      Sfx.i.enabled = st.sound;
      Sfx.i.swish();
      _emit(msg: '${names[p]} سحب حجرًا');
    } else {
      g.pass(p);
      _emit(msg: '${names[p]} تخطّى الدور');
    }
    _after();
  }

  @override
  void play(int i, String side) {
    if (g.turn != 0 || g.over || i < 0 || i >= g.hands[0].length) return;
    if (!sidesFor(g.hands[0][i], g.chain).contains(side)) return;
    final r = g.play(0, i, side);
    _emit(last: LastMove.from(r), msg: r.gained > 0 ? '+${r.gained} نقطة!' : null);
    _after();
  }

  @override
  void draw() {
    if (g.turn != 0 || g.over || g.canPlay(0) || g.stock.isEmpty) return;
    g.draw(0);
    Sfx.i.enabled = st.sound;
    Sfx.i.swish();
    if (st.haptics) HapticFeedback.selectionClick();
    _emit();
    _after();
  }

  @override
  void pass() {
    if (g.turn != 0 || g.over || g.canPlay(0) || g.stock.isNotEmpty) return;
    g.pass(0);
    _emit(msg: 'تخطّيت الدور');
    _after();
  }

  @override
  void next() {
    if (!g.over) return;
    if (g.matchOver) g = _newGame();
    _startRound();
  }

  @override
  void leave() {
    _bt?.cancel();
    _tt?.cancel();
  }

  @override
  void dispose() {
    leave();
    super.dispose();
  }
}

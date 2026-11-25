import 'engine.dart';

/// تفاصيل نقلة منفَّذة (للأنيميشن والصوت وقائمة النقلات).
class MoveInfo {
  final int move, from, to;
  final int piece; // القطعة المتحركة (قبل الترقية)
  final int captured; // القطعة المأخوذة (0 = لا شيء)
  final int capSq;
  final int promo; // نوع الترقية (0 = لا)
  final int rookFrom, rookTo; // للتبييت (-1 = لا)
  final String san;
  final bool check, mate;
  const MoveInfo(this.move, this.from, this.to, this.piece, this.captured, this.capSq, this.promo, this.rookFrom,
      this.rookTo, this.san, this.check, this.mate);
  bool get isCapture => captured != 0;
  bool get isCastle => rookFrom >= 0;
}

/// نتيجة اللعبة: null = مستمرة
enum ChessEnd { checkmate, stalemate, insufficient, fifty, repetition, resign }

class ChessGame {
  final Chess pos = Chess();
  final List<MoveInfo> log = [];
  final List<String> _fens = [];
  final List<String> _keys = [];
  ChessEnd? end;
  int winner = 0; // 1 أبيض، -1 أسود، 0 تعادل/مستمرة

  ChessGame() {
    reset();
  }

  void reset() {
    pos.loadFen(Chess.startFen);
    log.clear();
    _fens
      ..clear()
      ..add(pos.toFen());
    _keys
      ..clear()
      ..add(pos.posKey);
    end = null;
    winner = 0;
  }

  bool get over => end != null;
  bool get whiteToMove => pos.white;
  bool get inCheck => pos.inCheck;
  List<int> legalMoves() => pos.legal();
  List<int> legalFrom(int sq) => [for (final m in pos.legal()) if (mvFrom(m) == sq) m];

  static const _letters = ['', '', 'N', 'B', 'R', 'Q', 'K'];

  String _san(int m, List<int> legal) {
    final from = mvFrom(m), to = mvTo(m), promo = mvPromo(m);
    final b = pos.board;
    final p = b[from], t = p.abs();
    if (t == kK && (to - from).abs() == 2) return to > from ? 'O-O' : 'O-O-O';
    final isCap = b[to] != 0 || (t == kP && (from & 7) != (to & 7));
    final sb = StringBuffer();
    if (t == kP) {
      if (isCap) sb.write('${String.fromCharCode(97 + (from & 7))}x');
    } else {
      sb.write(_letters[t]);
      var clash = false, sameFile = false, sameRank = false;
      for (final o in legal) {
        if (o == m) continue;
        final of = mvFrom(o);
        if (mvTo(o) == to && b[of] == p) {
          clash = true;
          if ((of & 7) == (from & 7)) sameFile = true;
          if ((of >> 3) == (from >> 3)) sameRank = true;
        }
      }
      if (clash) {
        if (!sameFile) {
          sb.write(String.fromCharCode(97 + (from & 7)));
        } else if (!sameRank) {
          sb.write((from >> 3) + 1);
        } else {
          sb.write(sqName(from));
        }
      }
      if (isCap) sb.write('x');
    }
    sb.write(sqName(to));
    if (promo != 0) sb.write('=${_letters[promo]}');
    return sb.toString();
  }

  /// ينفّذ نقلة قانونية ويرجع تفاصيلها. يرجع null إذا غير قانونية.
  MoveInfo? play(int m) {
    if (over) return null;
    final legal = pos.legal();
    if (!legal.contains(m)) return null;
    final from = mvFrom(m), to = mvTo(m);
    final b = pos.board;
    final p = b[from], t = p.abs();
    var cap = b[to], capSq = to;
    if (t == kP && to == pos.ep && cap == 0 && (from & 7) != (to & 7)) {
      capSq = to + (p > 0 ? -8 : 8);
      cap = b[capSq];
    }
    var rf = -1, rt = -1;
    if (t == kK && (to - from).abs() == 2) {
      if (to > from) {
        rf = from + 3;
        rt = from + 1;
      } else {
        rf = from - 4;
        rt = from - 1;
      }
    }
    var san = _san(m, legal);
    pos.make(m);
    final chk = pos.inCheck;
    final hasMove = pos.legal().isNotEmpty;
    final mate = chk && !hasMove;
    if (mate) {
      san += '#';
    } else if (chk) {
      san += '+';
    }
    final info = MoveInfo(m, from, to, p, cap, capSq, mvPromo(m), rf, rt, san, chk, mate);
    log.add(info);
    _fens.add(pos.toFen());
    _keys.add(pos.posKey);
    _evaluateEnd(hasMove, chk);
    return info;
  }

  void _evaluateEnd(bool hasMove, bool chk) {
    end = null;
    winner = 0;
    if (!hasMove) {
      if (chk) {
        end = ChessEnd.checkmate;
        winner = pos.white ? -1 : 1;
      } else {
        end = ChessEnd.stalemate;
      }
    } else if (pos.insufficientMaterial) {
      end = ChessEnd.insufficient;
    } else if (pos.half >= 100) {
      end = ChessEnd.fifty;
    } else {
      final k = _keys.last;
      var n = 0;
      for (final x in _keys) {
        if (x == k) n++;
      }
      if (n >= 3) end = ChessEnd.repetition;
    }
  }

  /// يتراجع نقلة واحدة.
  bool undoOne() {
    if (log.isEmpty) return false;
    log.removeLast();
    _fens.removeLast();
    _keys.removeLast();
    pos.loadFen(_fens.last);
    end = null;
    winner = 0;
    return true;
  }

  void resign(int side) {
    end = ChessEnd.resign;
    winner = -side;
  }

  /// القطع التي أخذها اللون [byWhite] (للعرض بجانب اللاعب).
  List<int> capturedBy(bool byWhite) {
    final r = <int>[];
    for (final m in log) {
      if (m.captured != 0 && (m.captured < 0) == byWhite) r.add(m.captured.abs());
    }
    r.sort((a, b) => b.compareTo(a));
    return r;
  }

  /// فرق المادة (موجب لصالح الأبيض) بالبيادق.
  int get materialDiff {
    const v = [0, 1, 3, 3, 5, 9, 0];
    var s = 0;
    for (final x in pos.board) {
      if (x != 0) s += x > 0 ? v[x.abs()] : -v[x.abs()];
    }
    return s;
  }

  String get lastSan => log.isEmpty ? '' : log.last.san;
}

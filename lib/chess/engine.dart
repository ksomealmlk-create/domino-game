// قطع الشطرنج: موجب = أبيض، سالب = أسود
const int kP = 1, kN = 2, kB = 3, kR = 4, kQ = 5, kK = 6;

const List<List<int>> _kn = [
  [1, 2], [2, 1], [2, -1], [1, -2], [-1, -2], [-2, -1], [-2, 1], [-1, 2]
];
const List<List<int>> _diag = [[1, 1], [1, -1], [-1, 1], [-1, -1]];
const List<List<int>> _orth = [[1, 0], [-1, 0], [0, 1], [0, -1]];
const List<List<int>> _king = [
  [1, 1], [1, -1], [-1, 1], [-1, -1], [1, 0], [-1, 0], [0, 1], [0, -1]
];

/// الحركة مرمّزة في int: من (6 بت) | إلى (6 بت) << 6 | ترقية << 12
int mvFrom(int m) => m & 63;
int mvTo(int m) => (m >> 6) & 63;
int mvPromo(int m) => (m >> 12) & 7;
int mkMove(int from, int to, [int promo = 0]) => from | (to << 6) | (promo << 12);

String sqName(int s) => '${String.fromCharCode(97 + (s & 7))}${(s >> 3) + 1}';

class _Undo {
  final int m, cap, capSq, castle, ep, half, piece;
  const _Undo(this.m, this.cap, this.capSq, this.castle, this.ep, this.half, this.piece);
}

class Chess {
  final List<int> board = List<int>.filled(64, 0);
  bool white = true;
  int castle = 0; // 1 = ك أبيض، 2 = م أبيض، 4 = ك أسود، 8 = م أسود
  int ep = -1;
  int half = 0;
  int full = 1;
  final List<int> kingPos = [4, 60];
  final List<_Undo> _stack = [];

  static const String startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  Chess() {
    loadFen(startFen);
  }

  void loadFen(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    for (var i = 0; i < 64; i++) {
      board[i] = 0;
    }
    final rows = parts[0].split('/');
    const map = {'p': kP, 'n': kN, 'b': kB, 'r': kR, 'q': kQ, 'k': kK};
    for (var i = 0; i < 8; i++) {
      final rank = 7 - i;
      var f = 0;
      for (final ch in rows[i].split('')) {
        final code = ch.codeUnitAt(0);
        if (code >= 49 && code <= 56) {
          f += code - 48;
          continue;
        }
        final lower = ch.toLowerCase();
        final t = map[lower]!;
        final sq = rank * 8 + f;
        board[sq] = ch == lower ? -t : t;
        if (t == kK) kingPos[ch == lower ? 1 : 0] = sq;
        f++;
      }
    }
    white = (parts.length > 1 ? parts[1] : 'w') == 'w';
    final c = parts.length > 2 ? parts[2] : '-';
    castle = (c.contains('K') ? 1 : 0) | (c.contains('Q') ? 2 : 0) | (c.contains('k') ? 4 : 0) | (c.contains('q') ? 8 : 0);
    final e = parts.length > 3 ? parts[3] : '-';
    ep = e == '-' ? -1 : (e.codeUnitAt(1) - 49) * 8 + (e.codeUnitAt(0) - 97);
    half = parts.length > 4 ? int.parse(parts[4]) : 0;
    full = parts.length > 5 ? int.parse(parts[5]) : 1;
    _stack.clear();
  }

  String toFen() {
    const letters = ['', 'p', 'n', 'b', 'r', 'q', 'k'];
    final sb = StringBuffer();
    for (var rank = 7; rank >= 0; rank--) {
      var empty = 0;
      for (var f = 0; f < 8; f++) {
        final p = board[rank * 8 + f];
        if (p == 0) {
          empty++;
          continue;
        }
        if (empty > 0) {
          sb.write(empty);
          empty = 0;
        }
        final l = letters[p.abs()];
        sb.write(p > 0 ? l.toUpperCase() : l);
      }
      if (empty > 0) sb.write(empty);
      if (rank > 0) sb.write('/');
    }
    var c = '';
    if (castle & 1 != 0) c += 'K';
    if (castle & 2 != 0) c += 'Q';
    if (castle & 4 != 0) c += 'k';
    if (castle & 8 != 0) c += 'q';
    if (c.isEmpty) c = '-';
    final e = ep < 0 ? '-' : sqName(ep);
    return '$sb ${white ? 'w' : 'b'} $c $e $half $full';
  }

  /// مفتاح الموضع (بدون عدّاد النقلات) لكشف التكرار.
  String get posKey => toFen().split(' ').take(4).join(' ');

  bool isAttacked(int sq, int by) {
    final r = sq >> 3, f = sq & 7;
    final b = board;
    final pr = r - by;
    if (pr >= 0 && pr < 8) {
      if (f > 0 && b[pr * 8 + f - 1] == by * kP) return true;
      if (f < 7 && b[pr * 8 + f + 1] == by * kP) return true;
    }
    for (final d in _kn) {
      final nf = f + d[0], nr = r + d[1];
      if (nf < 0 || nf > 7 || nr < 0 || nr > 7) continue;
      if (b[nr * 8 + nf] == by * kN) return true;
    }
    for (final d in _king) {
      final nf = f + d[0], nr = r + d[1];
      if (nf < 0 || nf > 7 || nr < 0 || nr > 7) continue;
      if (b[nr * 8 + nf] == by * kK) return true;
    }
    for (final d in _diag) {
      var nf = f + d[0], nr = r + d[1];
      while (nf >= 0 && nf < 8 && nr >= 0 && nr < 8) {
        final x = b[nr * 8 + nf];
        if (x != 0) {
          if (x == by * kB || x == by * kQ) return true;
          break;
        }
        nf += d[0];
        nr += d[1];
      }
    }
    for (final d in _orth) {
      var nf = f + d[0], nr = r + d[1];
      while (nf >= 0 && nf < 8 && nr >= 0 && nr < 8) {
        final x = b[nr * 8 + nf];
        if (x != 0) {
          if (x == by * kR || x == by * kQ) return true;
          break;
        }
        nf += d[0];
        nr += d[1];
      }
    }
    return false;
  }

  bool get inCheck {
    final s = white ? 1 : -1;
    return isAttacked(kingPos[white ? 0 : 1], -s);
  }

  /// حركات شبه قانونية (capsOnly: الأخذ والترقية فقط).
  List<int> gen(bool capsOnly) {
    final out = <int>[];
    final b = board;
    final side = white ? 1 : -1;
    for (var sq = 0; sq < 64; sq++) {
      final p = b[sq];
      if (p == 0 || (p > 0) != (side > 0)) continue;
      final t = p.abs(), r = sq >> 3, f = sq & 7;
      if (t == kP) {
        final nr = r + side;
        final promoRank = white ? 7 : 0;
        final startRank = white ? 1 : 6;
        final one = nr * 8 + f;
        if (b[one] == 0) {
          if (nr == promoRank) {
            out.add(mkMove(sq, one, kQ));
            if (!capsOnly) {
              out.add(mkMove(sq, one, kR));
              out.add(mkMove(sq, one, kB));
              out.add(mkMove(sq, one, kN));
            }
          } else if (!capsOnly) {
            out.add(mkMove(sq, one));
            if (r == startRank && b[one + 8 * side] == 0) out.add(mkMove(sq, one + 8 * side));
          }
        }
        for (final df in const [-1, 1]) {
          final nf = f + df;
          if (nf < 0 || nf > 7) continue;
          final to = nr * 8 + nf;
          if (b[to] != 0 && (b[to] > 0) != (side > 0)) {
            if (nr == promoRank) {
              out.add(mkMove(sq, to, kQ));
              out.add(mkMove(sq, to, kR));
              out.add(mkMove(sq, to, kB));
              out.add(mkMove(sq, to, kN));
            } else {
              out.add(mkMove(sq, to));
            }
          } else if (to == ep && b[to] == 0) {
            out.add(mkMove(sq, to));
          }
        }
      } else if (t == kN || t == kK) {
        final offs = t == kN ? _kn : _king;
        for (final d in offs) {
          final nf = f + d[0], nr = r + d[1];
          if (nf < 0 || nf > 7 || nr < 0 || nr > 7) continue;
          final to = nr * 8 + nf, x = b[to];
          if (x == 0) {
            if (!capsOnly) out.add(mkMove(sq, to));
          } else if ((x > 0) != (side > 0)) {
            out.add(mkMove(sq, to));
          }
        }
        if (t == kK && !capsOnly) {
          final base = white ? 0 : 56;
          if (sq == base + 4 && !isAttacked(sq, -side)) {
            final ks = white ? 1 : 4, qs = white ? 2 : 8;
            if ((castle & ks) != 0 &&
                b[base + 5] == 0 &&
                b[base + 6] == 0 &&
                b[base + 7] == side * kR &&
                !isAttacked(base + 5, -side) &&
                !isAttacked(base + 6, -side)) {
              out.add(mkMove(sq, base + 6));
            }
            if ((castle & qs) != 0 &&
                b[base + 3] == 0 &&
                b[base + 2] == 0 &&
                b[base + 1] == 0 &&
                b[base] == side * kR &&
                !isAttacked(base + 3, -side) &&
                !isAttacked(base + 2, -side)) {
              out.add(mkMove(sq, base + 2));
            }
          }
        }
      } else {
        final dirs = t == kB ? _diag : (t == kR ? _orth : _king);
        for (final d in dirs) {
          var nf = f + d[0], nr = r + d[1];
          while (nf >= 0 && nf < 8 && nr >= 0 && nr < 8) {
            final to = nr * 8 + nf, x = b[to];
            if (x == 0) {
              if (!capsOnly) out.add(mkMove(sq, to));
            } else {
              if ((x > 0) != (side > 0)) out.add(mkMove(sq, to));
              break;
            }
            nf += d[0];
            nr += d[1];
          }
        }
      }
    }
    return out;
  }

  void make(int m) {
    final from = mvFrom(m), to = mvTo(m), promo = mvPromo(m);
    final b = board;
    final p = b[from], t = p.abs(), side = p > 0 ? 1 : -1;
    var cap = b[to], capSq = to;
    if (t == kP && to == ep && cap == 0 && (from & 7) != (to & 7)) {
      capSq = to - 8 * side;
      cap = b[capSq];
      b[capSq] = 0;
    }
    _stack.add(_Undo(m, cap, capSq, castle, ep, half, p));
    b[to] = promo != 0 ? side * promo : p;
    b[from] = 0;
    if (t == kK) {
      kingPos[side > 0 ? 0 : 1] = to;
      if (to - from == 2) {
        b[from + 1] = b[from + 3];
        b[from + 3] = 0;
      } else if (from - to == 2) {
        b[from - 1] = b[from - 4];
        b[from - 4] = 0;
      }
      castle &= side > 0 ? ~3 : ~12;
    }
    if (from == 0 || to == 0) castle &= ~2;
    if (from == 7 || to == 7) castle &= ~1;
    if (from == 56 || to == 56) castle &= ~8;
    if (from == 63 || to == 63) castle &= ~4;
    ep = (t == kP && (to - from).abs() == 16) ? (from + to) >> 1 : -1;
    half = (t == kP || cap != 0) ? 0 : half + 1;
    if (!white) full++;
    white = !white;
  }

  void undo() {
    final u = _stack.removeLast();
    final from = mvFrom(u.m), to = mvTo(u.m);
    final b = board;
    final t = u.piece.abs(), side = u.piece > 0 ? 1 : -1;
    white = !white;
    if (!white) full--;
    b[from] = u.piece;
    b[to] = 0;
    if (u.cap != 0) b[u.capSq] = u.cap;
    if (t == kK) {
      kingPos[side > 0 ? 0 : 1] = from;
      if (to - from == 2) {
        b[from + 3] = b[from + 1];
        b[from + 1] = 0;
      } else if (from - to == 2) {
        b[from - 4] = b[from - 1];
        b[from - 1] = 0;
      }
    }
    castle = u.castle;
    ep = u.ep;
    half = u.half;
  }

  List<int> legal() {
    final res = <int>[];
    final mover = white ? 0 : 1;
    final opp = white ? -1 : 1;
    for (final m in gen(false)) {
      make(m);
      if (!isAttacked(kingPos[mover], opp)) res.add(m);
      undo();
    }
    return res;
  }

  int perft(int d) {
    if (d == 0) return 1;
    var n = 0;
    for (final m in legal()) {
      make(m);
      n += perft(d - 1);
      undo();
    }
    return n;
  }

  /// تعادل بسبب نقص القطع.
  bool get insufficientMaterial {
    var minors = 0;
    final bishopColors = <int>{};
    for (var i = 0; i < 64; i++) {
      final t = board[i].abs();
      if (t == 0 || t == kK) continue;
      if (t == kP || t == kR || t == kQ) return false;
      minors++;
      if (t == kB) bishopColors.add(((i >> 3) + (i & 7)) & 1);
    }
    if (minors <= 1) return true;
    // فيلة فقط وكلها على نفس لون المربعات
    var onlyBishops = true;
    for (var i = 0; i < 64; i++) {
      if (board[i].abs() == kN) onlyBishops = false;
    }
    return onlyBishops && bishopColors.length == 1;
  }
}

// ======================= التقييم والبحث =======================
const List<int> _val = [0, 100, 320, 330, 500, 900, 20000];
const List<List<int>> _pst = [
  [],
  [0,0,0,0,0,0,0,0, 50,50,50,50,50,50,50,50, 10,10,20,30,30,20,10,10, 5,5,10,25,25,10,5,5, 0,0,0,20,20,0,0,0, 5,-5,-10,0,0,-10,-5,5, 5,10,10,-20,-20,10,10,5, 0,0,0,0,0,0,0,0],
  [-50,-40,-30,-30,-30,-30,-40,-50, -40,-20,0,0,0,0,-20,-40, -30,0,10,15,15,10,0,-30, -30,5,15,20,20,15,5,-30, -30,0,15,20,20,15,0,-30, -30,5,10,15,15,10,5,-30, -40,-20,0,5,5,0,-20,-40, -50,-40,-30,-30,-30,-30,-40,-50],
  [-20,-10,-10,-10,-10,-10,-10,-20, -10,0,0,0,0,0,0,-10, -10,0,5,10,10,5,0,-10, -10,5,5,10,10,5,5,-10, -10,0,10,10,10,10,0,-10, -10,10,10,10,10,10,10,-10, -10,5,0,0,0,0,5,-10, -20,-10,-10,-10,-10,-10,-10,-20],
  [0,0,0,0,0,0,0,0, 5,10,10,10,10,10,10,5, -5,0,0,0,0,0,0,-5, -5,0,0,0,0,0,0,-5, -5,0,0,0,0,0,0,-5, -5,0,0,0,0,0,0,-5, -5,0,0,0,0,0,0,-5, 0,0,0,5,5,0,0,0],
  [-20,-10,-10,-5,-5,-10,-10,-20, -10,0,0,0,0,0,0,-10, -10,0,5,5,5,5,0,-10, -5,0,5,5,5,5,0,-5, 0,0,5,5,5,5,0,-5, -10,5,5,5,5,5,0,-10, -10,0,5,0,0,0,0,-10, -20,-10,-10,-5,-5,-10,-10,-20],
  [-30,-40,-40,-50,-50,-40,-40,-30, -30,-40,-40,-50,-50,-40,-40,-30, -30,-40,-40,-50,-50,-40,-40,-30, -30,-40,-40,-50,-50,-40,-40,-30, -20,-30,-30,-40,-40,-30,-30,-20, -10,-20,-20,-20,-20,-20,-20,-10, 20,20,0,0,0,0,20,20, 20,30,10,0,0,10,30,20],
];
const List<int> _kingEnd = [-50,-40,-30,-20,-20,-30,-40,-50, -30,-20,-10,0,0,-10,-20,-30, -30,-10,20,30,30,20,-10,-30, -30,-10,30,40,40,30,-10,-30, -30,-10,30,40,40,30,-10,-30, -30,-10,20,30,30,20,-10,-30, -30,-30,0,0,0,0,-30,-30, -50,-30,-30,-30,-30,-30,-30,-50];

const int _mate = 30000, _inf = 100000;

class ChessSearcher {
  final Chess c;
  int nodes = 0;
  bool _stop = false;
  final Stopwatch _sw = Stopwatch();
  int _limitMs = 0;
  int _seed;
  ChessSearcher(this.c, [int seed = 12345]) : _seed = seed;

  double _rnd() {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed / 0x7fffffff;
  }

  int _evaluate() {
    final b = c.board;
    var nonPawn = 0;
    for (var i = 0; i < 64; i++) {
      final t = b[i].abs();
      if (t > 1 && t < 6) nonPawn += _val[t];
    }
    final endgame = nonPawn <= 2600;
    var s = 0;
    for (var i = 0; i < 64; i++) {
      final p = b[i];
      if (p == 0) continue;
      final t = p.abs();
      final r = i >> 3, f = i & 7;
      final idx = p > 0 ? (7 - r) * 8 + f : r * 8 + f;
      final tbl = (t == kK && endgame) ? _kingEnd : _pst[t];
      final v = _val[t] + tbl[idx];
      s += p > 0 ? v : -v;
    }
    return c.white ? s : -s;
  }

  int _score(int m) {
    final b = c.board;
    final from = mvFrom(m), to = mvTo(m), promo = mvPromo(m);
    var s = 0;
    final v = b[to].abs();
    if (v != 0) {
      s += 10 * _val[v] - _val[b[from].abs()] ~/ 10 + 10000;
    } else if (b[from].abs() == kP && (from & 7) != (to & 7)) {
      s += 10900;
    }
    if (promo != 0) s += _val[promo] + 9000;
    return s;
  }

  List<int> _order(List<int> ms) {
    final sc = [for (final m in ms) [_score(m), m]];
    sc.sort((a, b) => b[0].compareTo(a[0]));
    return [for (final x in sc) x[1]];
  }

  void _tick() {
    if ((nodes & 2047) == 0 && _sw.elapsedMilliseconds > _limitMs) _stop = true;
  }

  int _quiesce(int alpha, int beta, int qd) {
    nodes++;
    _tick();
    if (_stop) return 0;
    final stand = _evaluate();
    if (qd <= 0) return stand;
    if (stand >= beta) return stand;
    if (stand > alpha) alpha = stand;
    final mover = c.white ? 0 : 1, opp = c.white ? -1 : 1;
    for (final m in _order(c.gen(true))) {
      c.make(m);
      if (c.isAttacked(c.kingPos[mover], opp)) {
        c.undo();
        continue;
      }
      final sc = -_quiesce(-beta, -alpha, qd - 1);
      c.undo();
      if (_stop) return 0;
      if (sc >= beta) return sc;
      if (sc > alpha) alpha = sc;
    }
    return alpha;
  }

  int _negamax(int depth, int alpha, int beta, int ply) {
    nodes++;
    _tick();
    if (_stop) return 0;
    if (c.half >= 100) return 0;
    final inChk = c.inCheck;
    if (inChk) depth++;
    if (depth <= 0) return _quiesce(alpha, beta, 6);
    final mover = c.white ? 0 : 1, opp = c.white ? -1 : 1;
    var legal = 0, best = -_inf;
    for (final m in _order(c.gen(false))) {
      c.make(m);
      if (c.isAttacked(c.kingPos[mover], opp)) {
        c.undo();
        continue;
      }
      legal++;
      final sc = -_negamax(depth - 1, -beta, -alpha, ply + 1);
      c.undo();
      if (_stop) return 0;
      if (sc > best) best = sc;
      if (sc > alpha) alpha = sc;
      if (alpha >= beta) break;
    }
    if (legal == 0) return inChk ? -_mate + ply : 0;
    return best;
  }

  /// level: 0 سهل، 1 متوسط، 2 صعب. يرجع -1 إذا ما في حركات.
  int best(int level, {int? timeMs}) {
    final moves = c.legal();
    if (moves.isEmpty) return -1;
    if (moves.length == 1) return moves[0];
    final maxDepth = const [1, 3, 6][level];
    final limit = timeMs ?? const [300, 1200, 2500][level];
    final noise = const [120, 10, 0][level];
    if (level == 0 && _rnd() < 0.12) return moves[(_rnd() * moves.length).floor() % moves.length];
    _limitMs = limit;
    _sw
      ..reset()
      ..start();
    _stop = false;
    var ordered = _order(moves);
    var bestMove = ordered[0];
    for (var d = 1; d <= maxDepth; d++) {
      var alpha = -_inf, bestHere = ordered[0], bestScore = -_inf;
      final scored = <List<num>>[];
      for (final m in ordered) {
        c.make(m);
        var sc = -_negamax(d - 1, noise > 0 ? -_inf : -_inf, noise > 0 ? _inf : -alpha, 1);
        c.undo();
        if (_stop) break;
        if (noise > 0) sc += ((_rnd() * 2 - 1) * noise).round();
        scored.add([sc, m]);
        if (sc > bestScore) {
          bestScore = sc;
          bestHere = m;
        }
        if (noise == 0 && sc > alpha) alpha = sc;
      }
      if (_stop) break;
      bestMove = bestHere;
      scored.sort((a, b) => b[0].compareTo(a[0]));
      ordered = [for (final x in scored) x[1].toInt()];
      if (bestScore > _mate - 100) break;
    }
    return bestMove;
  }
}

/// تُستدعى عبر compute() خارج الخيط الرئيسي. args = [fen, level, seed, timeMs(أو -1)]
int chessBestMove(List<dynamic> args) {
  final c = Chess()..loadFen(args[0] as String);
  final t = args.length > 3 ? args[3] as int : -1;
  final s = ChessSearcher(c, (args.length > 2 ? args[2] as int : 7) & 0x7fffffff);
  return s.best((args[1] as int).clamp(0, 2).toInt(), timeMs: t > 0 ? t : null);
}

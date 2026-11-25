import 'dart:math';

/// حجر دومينو. داخل السلسلة: a = الطرف الأيسر، b = الطرف الأيمن.
class Tile {
  final int a, b;
  const Tile(this.a, this.b);
  bool get isDouble => a == b;
  int get pips => a + b;
  int get key => a < b ? a * 10 + b : b * 10 + a;
  List<int> toJson() => [a, b];
  static Tile fromJson(dynamic j) => Tile((j as List)[0] as int, j[1] as int);
}

class Move {
  final int i;
  final String side; // 'L' أو 'R'
  const Move(this.i, this.side);
}

class PlayResult {
  final int player;
  final Tile tile; // بعد التدوير (كما وُضع في السلسلة)
  final String side;
  final int gained;
  const PlayResult(this.player, this.tile, this.side, this.gained);
}

List<Tile> fullDeck() {
  final d = <Tile>[];
  for (var i = 0; i <= 6; i++) {
    for (var j = i; j <= 6; j++) {
      d.add(Tile(i, j));
    }
  }
  return d;
}

List<Tile> simPlace(List<Tile> ch, Tile t, String side) {
  if (ch.isEmpty) return [Tile(t.a, t.b)];
  if (side == 'R') {
    final e = ch.last.b;
    return [...ch, t.a == e ? Tile(t.a, t.b) : Tile(t.b, t.a)];
  }
  final e = ch.first.a;
  return [t.b == e ? Tile(t.a, t.b) : Tile(t.b, t.a), ...ch];
}

List<String> sidesFor(Tile t, List<Tile> ch) {
  if (ch.isEmpty) return ['R'];
  final r = <String>[];
  final l = ch.first.a, rr = ch.last.b;
  if (t.a == rr || t.b == rr) r.add('R');
  if (t.a == l || t.b == l) r.add('L');
  return r;
}

int endsScore(List<Tile> ch) {
  if (ch.isEmpty) return 0;
  if (ch.length == 1) return ch[0].a + ch[0].b;
  final f = ch.first, l = ch.last;
  final L = f.a == f.b ? f.a * 2 : f.a;
  final R = l.a == l.b ? l.b * 2 : l.b;
  return L + R;
}

int pipsOf(List<Tile> h) => h.fold(0, (s, t) => s + t.pips);

class DominoGame {
  final bool five;
  final int n;
  final int target;
  final Random rnd;

  List<int> scores;
  List<List<Tile>> hands = [];
  List<Tile> stock = [];
  List<Tile> chain = [];
  int nl = 0;
  int turn = 0;
  int passes = 0;
  int round = 0;
  bool over = false;
  bool matchOver = false;
  bool blocked = false;
  int roundWinner = -1;
  int matchWinner = -1;
  int roundGain = 0;
  int lastPlayer = -1; // آخر من نزّل حجرًا
  int? nextStarter; // من يبدأ الجولة القادمة (من قفل اللعبة، أو من خلّص حجاراته)

  DominoGame({required this.five, required this.n, required this.target, Random? rnd})
      : rnd = rnd ?? Random(),
        scores = List<int>.filled(n, 0);

  /// الفريق: في 4 لاعبين كل لاعب مع المقابل له (0 و2 ضد 1 و3). غير ذلك كل لاعب لوحده.
  int teamOf(int p) => n == 4 ? p % 2 : p;
  bool sameTeam(int a, int b) => teamOf(a) == teamOf(b);

  void _addScore(int w, int gain) {
    for (var q = 0; q < n; q++) {
      if (sameTeam(q, w)) scores[q] += gain;
    }
  }

  PlayResult? startRound() {
    round++;
    final d = fullDeck()..shuffle(rnd);
    hands = [for (var i = 0; i < n; i++) d.sublist(i * 7, i * 7 + 7)];
    stock = d.sublist(n * 7);
    chain = [];
    nl = 0;
    passes = 0;
    over = false;
    blocked = false;
    roundWinner = -1;
    roundGain = 0;
    lastPlayer = -1;
    final starter = nextStarter;
    nextStarter = null;
    if (starter != null) {
      // من قفل اللعبة (أو خلّص حجاراته) يبدأ بأي حجر يريده
      turn = starter;
      return null;
    }
    var best = -1, bp = 0, bi = 0;
    for (var p = 0; p < n; p++) {
      for (var i = 0; i < hands[p].length; i++) {
        final t = hands[p][i];
        final k = (t.isDouble ? 100 : 0) + t.pips;
        if (k > best) {
          best = k;
          bp = p;
          bi = i;
        }
      }
    }
    turn = bp;
    return play(bp, bi, 'R');
  }

  List<Move> allMoves(int p) {
    final m = <Move>[];
    final h = hands[p];
    for (var i = 0; i < h.length; i++) {
      for (final s in sidesFor(h[i], chain)) {
        m.add(Move(i, s));
      }
    }
    return m;
  }

  bool canPlay(int p) => allMoves(p).isNotEmpty;

  PlayResult play(int p, int i, String side) {
    final t = hands[p].removeAt(i);
    chain = simPlace(chain, t, side);
    final placed = side == 'L' ? chain.first : chain.last;
    if (side == 'L' && chain.length > 1) nl++;
    var gained = 0;
    if (five) {
      final sc = endsScore(chain);
      if (sc > 0 && sc % 5 == 0) {
        _addScore(p, sc);
        gained = sc;
      }
    }
    lastPlayer = p;
    final res = PlayResult(p, placed, side, gained);
    if (hands[p].isEmpty) {
      _endRound(p, false);
      return res;
    }
    if (isLocked) {
      // الطرفين نفس الرقم وكل حجارته الـ7 نازلة: ما أحد يكدر يلعب بعد
      _endRound(_blockedWinner(p), true);
      return res;
    }
    passes = 0;
    turn = (turn + 1) % n;
    return res;
  }

  Tile? draw(int p) {
    if (stock.isEmpty) return null;
    final t = stock.removeLast();
    hands[p].add(t);
    return t;
  }

  /// الطرفان نفس الرقم وكل الحجارات السبع المحتوية عليه نازلة.
  bool get isLocked {
    if (chain.length < 2) return false;
    final x = chain.first.a;
    if (chain.last.b != x) return false;
    var c = 0;
    for (final t in chain) {
      if (t.a == x || t.b == x) c++;
    }
    return c >= 7;
  }

  /// عند القفل: اللاعب الواحد الأقل نقاطًا يفوز (عند التعادل الأقرب بعد من قفل).
  int _blockedWinner(int from) {
    var w = from, m = 1 << 30;
    for (var k = 1; k <= n; k++) {
      final q = (from + k) % n;
      final ip = pipsOf(hands[q]);
      if (ip < m) {
        m = ip;
        w = q;
      }
    }
    return w;
  }

  void pass(int p) {
    passes++;
    if (passes >= n) {
      _endRound(_blockedWinner(lastPlayer >= 0 ? lastPlayer : p), true);
      return;
    }
    turn = (turn + 1) % n;
  }

  void _endRound(int w, bool isBlocked) {
    // الفريق الفائز يأخذ مجموع نقاط الحجارة المتبقية عند الفريق الآخر
    var sum = 0;
    for (var p = 0; p < n; p++) {
      if (!sameTeam(p, w)) sum += pipsOf(hands[p]);
    }
    roundGain = sum;
    _addScore(w, roundGain);
    over = true;
    blocked = isBlocked;
    roundWinner = w;
    // إذا انقفلت اللعبة: اللي قفلها يبدأ الجولة الجاية. وإذا خلّص أحد حجاراته: هو يبدأ.
    nextStarter = (isBlocked && lastPlayer >= 0) ? lastPlayer : w;
    final top = scores.reduce(max);
    matchOver = top >= target;
    if (matchOver) matchWinner = scores.indexOf(top);
  }

  /// level: 0 سهل، 1 متوسط، 2 صعب
  Move? chooseMove(int p, int level) {
    final ms = allMoves(p);
    if (ms.isEmpty) return null;
    if (level <= 0) return ms[rnd.nextInt(ms.length)];
    final h = hands[p];
    var best = ms.first;
    var bk = -1e9;
    for (final m in ms) {
      final t = h[m.i];
      final nc = simPlace(chain, t, m.side);
      var k = t.pips + rnd.nextDouble();
      if (five) {
        final sc = endsScore(nc);
        if (sc > 0 && sc % 5 == 0) k += sc * 10;
      }
      if (level >= 2) {
        final l = nc.first.a, r = nc.last.b;
        var match = 0;
        for (var j = 0; j < h.length; j++) {
          if (j == m.i) continue;
          final x = h[j];
          if (x.a == l || x.b == l || x.a == r || x.b == r) match++;
        }
        k += match * 2.5;
        if (t.isDouble) k += 3;
      }
      if (k > bk) {
        bk = k;
        best = m;
      }
    }
    return best;
  }
}

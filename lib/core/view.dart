import 'rules.dart';

class LastMove {
  final int p, a, b, gained;
  final String side;
  const LastMove(this.p, this.a, this.b, this.side, this.gained);

  factory LastMove.from(PlayResult r) => LastMove(r.player, r.tile.a, r.tile.b, r.side, r.gained);

  Map<String, dynamic> toJson() => {'p': p, 'a': a, 'b': b, 's': side, 'g': gained};
  static LastMove fromJson(Map<String, dynamic> j) =>
      LastMove(j['p'] as int, j['a'] as int, j['b'] as int, j['s'] as String, j['g'] as int);
}

/// ما يراه اللاعب (المقعد 0 دائمًا هو اللاعب نفسه).
class GameView {
  final bool five;
  final int n, target, round;
  final List<String> names;
  final List<int> scores, handSizes, pipsLeft;
  final List<Tile> myHand, chain;
  final int stock, nl, turn, roundWinner, matchWinner, roundGain;
  final bool over, matchOver, blocked;
  final LastMove? last;
  final String? msg;

  /// مشاهد (لا يرى أيدي اللاعبين ولا يلعب)
  final bool spectator;

  /// هل اللاعب (بالمقعد النسبي r) بنفس فريقي؟ (0 = أنا). في 4 لاعبين الشريك هو المقابل (2).
  bool sameTeam(int r) => n == 4 ? r % 2 == 0 : r == 0;
  bool get iAmWinnerTeam => sameTeam(matchOver ? matchWinner : roundWinner);
  int get ourScore => scores[0];
  int get theirScore => n == 4 ? scores[1] : (scores.length > 1 ? scores.sublist(1).reduce((a, b) => a > b ? a : b) : 0);

  const GameView({
    required this.five,
    required this.n,
    required this.target,
    required this.round,
    required this.names,
    required this.scores,
    required this.handSizes,
    required this.pipsLeft,
    required this.myHand,
    required this.chain,
    required this.stock,
    required this.nl,
    required this.turn,
    required this.roundWinner,
    required this.matchWinner,
    required this.roundGain,
    required this.over,
    required this.matchOver,
    required this.blocked,
    this.last,
    this.msg,
    this.spectator = false,
  });

  static GameView fromGame(DominoGame g, int viewer, List<String> names, {LastMove? last, String? msg, bool spectator = false}) {
    final n = g.n;
    int ab(int r) => (viewer + r) % n;
    int rel(int p) => p < 0 ? -1 : (p - viewer + n) % n;
    return GameView(
      five: g.five,
      n: n,
      target: g.target,
      round: g.round,
      names: [for (var r = 0; r < n; r++) names[ab(r)]],
      scores: [for (var r = 0; r < n; r++) g.scores[ab(r)]],
      handSizes: [for (var r = 0; r < n; r++) g.hands[ab(r)].length],
      pipsLeft: g.over ? [for (var r = 0; r < n; r++) pipsOf(g.hands[ab(r)])] : const [],
      myHand: spectator ? <Tile>[] : List<Tile>.of(g.hands[viewer]),
      chain: List<Tile>.of(g.chain),
      stock: g.stock.length,
      nl: g.nl,
      turn: rel(g.turn),
      roundWinner: rel(g.roundWinner),
      matchWinner: rel(g.matchWinner),
      roundGain: g.roundGain,
      over: g.over,
      matchOver: g.matchOver,
      blocked: g.blocked,
      last: last == null ? null : LastMove(rel(last.p), last.a, last.b, last.side, last.gained),
      msg: msg,
      spectator: spectator,
    );
  }

  Map<String, dynamic> toJson() => {
        'five': five,
        'n': n,
        'target': target,
        'round': round,
        'names': names,
        'scores': scores,
        'hs': handSizes,
        'pl': pipsLeft,
        'hand': myHand.map((t) => t.toJson()).toList(),
        'chain': chain.map((t) => t.toJson()).toList(),
        'stock': stock,
        'nl': nl,
        'turn': turn,
        'rw': roundWinner,
        'mw': matchWinner,
        'gain': roundGain,
        'over': over,
        'mo': matchOver,
        'blocked': blocked,
        'last': last?.toJson(),
        'msg': msg,
        'spec': spectator,
      };

  static GameView fromJson(Map<String, dynamic> j) => GameView(
        five: j['five'] as bool,
        n: j['n'] as int,
        target: j['target'] as int,
        round: j['round'] as int,
        names: List<String>.from(j['names'] as List),
        scores: List<int>.from(j['scores'] as List),
        handSizes: List<int>.from(j['hs'] as List),
        pipsLeft: List<int>.from(j['pl'] as List),
        myHand: (j['hand'] as List).map(Tile.fromJson).toList(),
        chain: (j['chain'] as List).map(Tile.fromJson).toList(),
        stock: j['stock'] as int,
        nl: j['nl'] as int,
        turn: j['turn'] as int,
        roundWinner: j['rw'] as int,
        matchWinner: j['mw'] as int,
        roundGain: j['gain'] as int,
        over: j['over'] as bool,
        matchOver: j['mo'] as bool,
        blocked: j['blocked'] as bool,
        last: j['last'] == null ? null : LastMove.fromJson(Map<String, dynamic>.from(j['last'] as Map)),
        msg: j['msg'] as String?,
        spectator: j['spec'] == true,
      );
}

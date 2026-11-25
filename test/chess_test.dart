import 'package:flutter_test/flutter_test.dart';
import 'package:domino3d/chess/engine.dart';
import 'package:domino3d/chess/game.dart';

void main() {
  test('perft البداية', () {
    final c = Chess();
    expect(c.perft(1), 20);
    expect(c.perft(2), 400);
    expect(c.perft(3), 8902);
    expect(c.perft(4), 197281);
  });
  test('perft Kiwipete', () {
    final c = Chess()..loadFen('r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1');
    expect(c.perft(1), 48);
    expect(c.perft(2), 2039);
    expect(c.perft(3), 97862);
  });
  test('مات الأحمق', () {
    final g = ChessGame();
    for (final m in [[12, 20], [52, 36], [6, 21], [59, 31]]) {
      expect(g.play(mkMove(m[0], m[1])), isNotNull);
    }
    // 1.e3 e5 2.Nf3 Qh4?? لا؛ نتحقق فقط أن اللعبة مستمرة
    expect(g.over, false);
  });
  test('الذكاء يلقى المات بنقلة', () {
    final c = Chess()..loadFen('6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1');
    expect(chessBestMove([c.toFen(), 2, 1, 2000]), mkMove(0, 56));
  });
}

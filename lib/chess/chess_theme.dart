import 'package:flutter/material.dart';

enum BoardGrain { none, wood, marble }

class ChessBoardTheme {
  final String name;
  final Color light, dark;
  final List<Color> frame; // فاتح ← غامق
  final BoardGrain grain;
  const ChessBoardTheme(this.name, this.light, this.dark, this.frame, {this.grain = BoardGrain.none});
}

const List<ChessBoardTheme> chessBoards = [
  ChessBoardTheme('خشب كلاسيك', Color(0xFFEBCB9A), Color(0xFF9A6236), [Color(0xFF7A4A28), Color(0xFF4A2A14), Color(0xFF26140A)],
      grain: BoardGrain.wood),
  ChessBoardTheme('رخام ملكي', Color(0xFFF1EFEA), Color(0xFF5E6575), [Color(0xFFF6DB8C), Color(0xFFC99A2E), Color(0xFF6E4E0E)],
      grain: BoardGrain.marble),
  ChessBoardTheme('زمرد', Color(0xFFE6EFD8), Color(0xFF2F7D55), [Color(0xFF6B4423), Color(0xFF3E2512), Color(0xFF1E1008)]),
  ChessBoardTheme('أزرق ملكي', Color(0xFFD3DEF5), Color(0xFF2F4A8A), [Color(0xFFF0F2F7), Color(0xFFA2A9B8), Color(0xFF4E5465)]),
  ChessBoardTheme('أسود وذهب', Color(0xFFD9B65C), Color(0xFF23232B), [Color(0xFF3A3A42), Color(0xFF17171C), Color(0xFF060608)],
      grain: BoardGrain.marble),
  ChessBoardTheme('عنابي', Color(0xFFF2D6CF), Color(0xFF8E2A3C), [Color(0xFFF6DB8C), Color(0xFFC99A2E), Color(0xFF6E4E0E)]),
];

class ChessPieceSet {
  final String name;
  final Color white, black;
  const ChessPieceSet(this.name, this.white, this.black);
}

const List<ChessPieceSet> chessSets = [
  ChessPieceSet('عاج وأبنوس', Color(0xFFF4EAD2), Color(0xFF2B2622)),
  ChessPieceSet('ذهب وفضة', Color(0xFFE9C45A), Color(0xFFB4BCCB)),
  ChessPieceSet('رخام', Color(0xFFF7F7F5), Color(0xFF3A4A44)),
  ChessPieceSet('ياقوت وزمرد', Color(0xFFE0394F), Color(0xFF1F9A6B)),
  ChessPieceSet('لازورد ونحاس', Color(0xFF3F6FD8), Color(0xFFD08A5A)),
  ChessPieceSet('بلاتين وأوبسيديان', Color(0xFFC9CFDB), Color(0xFF1A1A20)),
];

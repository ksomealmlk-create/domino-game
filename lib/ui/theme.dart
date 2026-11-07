import 'package:flutter/material.dart';

const kGold = Color(0xFFD4AF37);
const kGoldLight = Color(0xFFF6E3A1);
const kGoldDark = Color(0xFF8A6A12);
const kBg = Color(0xFF07090D);
const kInk = Color(0xFF2A1D00);

Color alpha(Color c, double o) => c.withAlpha((o.clamp(0.0, 1.0) * 255).round());

class TableTheme {
  final String name;
  final Color felt, feltDark;
  const TableTheme(this.name, this.felt, this.feltDark);
}

const tableThemes = <TableTheme>[
  TableTheme('زمرد', Color(0xFF17935F), Color(0xFF053A24)),
  TableTheme('ياقوت أزرق', Color(0xFF2F63BF), Color(0xFF0A1E46)),
  TableTheme('عنابي', Color(0xFFA52F42), Color(0xFF3D0B14)),
  TableTheme('أسود ملكي', Color(0xFF42424F), Color(0xFF0C0C12)),
];

class TileStyle {
  final String name;
  final Color top1, top2, side, edge, pip, pipHi, pipRim, back1, back2;
  const TileStyle(this.name, this.top1, this.top2, this.side, this.edge, this.pip, this.pipHi, this.pipRim,
      this.back1, this.back2);
}

const tileStyles = <TileStyle>[
  TileStyle('عاج', Color(0xFFFFFDF4), Color(0xFFE6DABB), Color(0xFFB9AB8A), Color(0xFF7D7158), Color(0xFF16161A),
      Color(0xFF8A8A94), Color(0xFFFFFFFF), Color(0xFF24427A), Color(0xFF0F2347)),
  TileStyle('أوبسيديان', Color(0xFF3C3C46), Color(0xFF121216), Color(0xFF050507), Color(0xFF000000), Color(0xFFE9C45A),
      Color(0xFFFFF4C4), Color(0xFF000000), Color(0xFF3C3C46), Color(0xFF121216)),
  TileStyle('ياقوت', Color(0xFFE0394F), Color(0xFF7E0F22), Color(0xFF4A0612), Color(0xFF2A0209), Color(0xFFFFFFFF),
      Color(0xFFFFFFFF), Color(0xFF5A0A18), Color(0xFFE0394F), Color(0xFF7E0F22)),
];

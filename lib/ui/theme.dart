import 'package:flutter/material.dart';

const kGold = Color(0xFFD4AF37);
const kGoldLight = Color(0xFFF6E3A1);
const kGoldDark = Color(0xFF8A6A12);
const kBg = Color(0xFF07090D);
const kInk = Color(0xFF2A1D00);

Color alpha(Color c, double o) => c.withAlpha((o.clamp(0.0, 1.0) * 255).round());

Color _dk(Color c, double t) => Color.lerp(c, const Color(0xFF000000), t)!;
Color _lt(Color c, double t) => Color.lerp(c, const Color(0xFFFFFFFF), t)!;

// ===================== الطاولات =====================
enum TablePattern { felt, carbon, leather, marble, wood, brushed, stars, geo }

const List<Color> _fWood = [Color(0xFF8A5A33), Color(0xFF4E2F18), Color(0xFF2B170A)];
const List<Color> _fBlack = [Color(0xFF3A3A42), Color(0xFF17171C), Color(0xFF060608)];
const List<Color> _fGold = [Color(0xFFF6DB8C), Color(0xFFC99A2E), Color(0xFF6E4E0E)];
const List<Color> _fSilver = [Color(0xFFF0F2F7), Color(0xFFA2A9B8), Color(0xFF4E5465)];
const List<Color> _fWalnut = [Color(0xFF6B4423), Color(0xFF3E2512), Color(0xFF1E1008)];
const List<Color> _fMahog = [Color(0xFF9A3A24), Color(0xFF58190E), Color(0xFF2A0A05)];
const List<Color> _fRose = [Color(0xFFF7D0C0), Color(0xFFC98A78), Color(0xFF6E3A2C)];

class TableTheme {
  final String name;
  final Color felt, feltDark;
  final TablePattern pat;
  final Color patColor;
  final List<Color> frame; // ألوان الإطار (فاتح ← غامق)
  final Color inlay; // خط التطعيم
  final bool grain; // عروق الخشب على الإطار
  const TableTheme(this.name, this.felt, this.feltDark,
      {this.pat = TablePattern.felt,
      this.patColor = const Color(0xFFFFFFFF),
      this.frame = _fWood,
      this.inlay = kGold,
      this.grain = true});
}

const tableThemes = <TableTheme>[
  TableTheme('زمرد', Color(0xFF17935F), Color(0xFF053A24)),
  TableTheme('ياقوت أزرق', Color(0xFF2F63BF), Color(0xFF0A1E46)),
  TableTheme('عنابي', Color(0xFFA52F42), Color(0xFF3D0B14)),
  TableTheme('أسود ملكي', Color(0xFF42424F), Color(0xFF0C0C12)),
  TableTheme('بنفسجي ملكي', Color(0xFF6B3FB8), Color(0xFF1E0B45), frame: _fGold, inlay: Color(0xFFFFF3C4)),
  TableTheme('فيروزي', Color(0xFF1FB5A6), Color(0xFF053F3C), frame: _fSilver, inlay: Color(0xFFFFFFFF)),
  TableTheme('ذهبي ملكي', Color(0xFF9A7414), Color(0xFF2E1F02), frame: _fBlack),
  TableTheme('غرافيت', Color(0xFF5A5F6B), Color(0xFF14161C), frame: _fSilver, inlay: Color(0xFFE6E8EE)),
  TableTheme('أخضر غابة', Color(0xFF2E7D4F), Color(0xFF0A2A19), frame: _fWalnut),
  TableTheme('أزرق ليلي', Color(0xFF1F3A7A), Color(0xFF050B22), frame: _fBlack, inlay: Color(0xFF9DB8FF), grain: false),
  TableTheme('أحمر كازينو', Color(0xFFC62828), Color(0xFF4A0808)),
  TableTheme('أخضر كازينو', Color(0xFF0F7A4B), Color(0xFF03281A), frame: _fWalnut),
  TableTheme('كربون أسود', Color(0xFF2B2B31), Color(0xFF0A0A0D),
      pat: TablePattern.carbon, frame: _fBlack, inlay: Color(0xFFFF3B3B), grain: false),
  TableTheme('كربون أزرق', Color(0xFF1B3F86), Color(0xFF050E2B),
      pat: TablePattern.carbon, frame: _fBlack, inlay: Color(0xFF8AD8FF), grain: false),
  TableTheme('جلد أسود مخيّط', Color(0xFF35353A), Color(0xFF0C0C0E),
      pat: TablePattern.leather, patColor: Color(0xFFD4AF37), frame: _fBlack, grain: false),
  TableTheme('جلد بني', Color(0xFF9A5A2C), Color(0xFF3A1B08),
      pat: TablePattern.leather, patColor: Color(0xFFF0C070), frame: _fWalnut),
  TableTheme('رخام أبيض', Color(0xFFF2F2F0), Color(0xFFB9BCC4),
      pat: TablePattern.marble, patColor: Color(0xFF6C7280), frame: _fGold, inlay: Color(0xFFFFF3C4), grain: false),
  TableTheme('رخام أسود ذهبي', Color(0xFF24242C), Color(0xFF050507),
      pat: TablePattern.marble, patColor: Color(0xFFD4AF37), frame: _fGold, grain: false),
  TableTheme('رخام أخضر', Color(0xFF1F7A58), Color(0xFF04281C),
      pat: TablePattern.marble, patColor: Color(0xFFCFF5E1), frame: _fGold, grain: false),
  TableTheme('خشب جوز', Color(0xFF8A5A33), Color(0xFF3A2010),
      pat: TablePattern.wood, patColor: Color(0xFF1E0F05), frame: _fWalnut),
  TableTheme('خشب ماهوجني', Color(0xFF9A3A24), Color(0xFF3A0F08),
      pat: TablePattern.wood, patColor: Color(0xFF1E0603), frame: _fMahog),
  TableTheme('خشب أبنوس', Color(0xFF3A2F2A), Color(0xFF0A0605),
      pat: TablePattern.wood, patColor: Color(0xFF8A7466), frame: _fBlack, grain: false),
  TableTheme('فضي معدني', Color(0xFFC8CDD8), Color(0xFF6A7183),
      pat: TablePattern.brushed, frame: _fSilver, inlay: Color(0xFFFFFFFF), grain: false),
  TableTheme('ذهب مصقول', Color(0xFFE8C45A), Color(0xFF8A6A12),
      pat: TablePattern.brushed, patColor: Color(0xFFFFF6D0), frame: _fBlack, grain: false),
  TableTheme('مجرّة', Color(0xFF4B2C8F), Color(0xFF08041A),
      pat: TablePattern.stars, frame: _fBlack, inlay: Color(0xFFB794FF), grain: false),
  TableTheme('ليل الصحراء', Color(0xFF1D2A5C), Color(0xFF03050F),
      pat: TablePattern.stars, patColor: Color(0xFFF6E3A1), frame: _fBlack, grain: false),
  TableTheme('كريستال جليدي', Color(0xFF7FC8F8), Color(0xFF1D4E8F),
      pat: TablePattern.stars, frame: _fSilver, inlay: Color(0xFFFFFFFF), grain: false),
  TableTheme('وردي ملكي', Color(0xFFE47A9A), Color(0xFF6B1530), frame: _fRose, inlay: Color(0xFFFFFFFF), grain: false),
  TableTheme('عنابي مزخرف', Color(0xFF8E1F33), Color(0xFF2A050C),
      pat: TablePattern.geo, patColor: Color(0xFFE9C45A)),
  TableTheme('أخضر مزخرف', Color(0xFF0F6B4A), Color(0xFF031F15),
      pat: TablePattern.geo, patColor: Color(0xFFE9C45A), frame: _fWalnut),
];

// ===================== الأحجار =====================
enum TilePattern { none, marble, wood, carbon, brushed, sparkle, leather }

class TileStyle {
  final String name;
  final Color top1, top2, side, edge, pip, pipHi, pipRim, back1, back2;
  final TilePattern pat;
  final Color patColor;
  final Color? trim; // خط ذهبي/لامع داخل الحجر
  const TileStyle(this.name, this.top1, this.top2, this.side, this.edge, this.pip, this.pipHi, this.pipRim,
      this.back1, this.back2,
      {this.pat = TilePattern.none, this.patColor = const Color(0xFFFFFFFF), this.trim});

  /// يبني ستايل من لونين فقط ويشتق الباقي (الجوانب، الحواف، النقاط...)
  factory TileStyle.mk(String name, Color t1, Color t2,
      {Color pip = const Color(0xFFFFFFFF), TilePattern pat = TilePattern.none, Color? patColor, Color? trim}) {
    final lightPip = pip.computeLuminance() > 0.5;
    final lightFace = t1.computeLuminance() > 0.45;
    return TileStyle(
      name,
      t1,
      t2,
      _dk(t2, 0.35),
      _dk(t2, 0.65),
      pip,
      lightPip ? const Color(0xFFFFFFFF) : const Color(0xFF8A8A94),
      lightFace ? const Color(0xFFFFFFFF) : _dk(t2, 0.5),
      _dk(t1, 0.2),
      _dk(t2, 0.3),
      pat: pat,
      patColor: patColor ?? (lightFace ? const Color(0xFF000000) : const Color(0xFFFFFFFF)),
      trim: trim,
    );
  }
}

final List<TileStyle> tileStyles = <TileStyle>[
  const TileStyle('عاج', Color(0xFFFFFDF4), Color(0xFFE6DABB), Color(0xFFB9AB8A), Color(0xFF7D7158), Color(0xFF16161A),
      Color(0xFF8A8A94), Color(0xFFFFFFFF), Color(0xFF24427A), Color(0xFF0F2347)),
  const TileStyle('أوبسيديان', Color(0xFF3C3C46), Color(0xFF121216), Color(0xFF050507), Color(0xFF000000), Color(0xFFE9C45A),
      Color(0xFFFFF4C4), Color(0xFF000000), Color(0xFF3C3C46), Color(0xFF121216)),
  const TileStyle('ياقوت', Color(0xFFE0394F), Color(0xFF7E0F22), Color(0xFF4A0612), Color(0xFF2A0209), Color(0xFFFFFFFF),
      Color(0xFFFFFFFF), Color(0xFF5A0A18), Color(0xFFE0394F), Color(0xFF7E0F22)),
  TileStyle.mk('رخام أبيض', const Color(0xFFFAFAF8), const Color(0xFFD9D9DC),
      pip: const Color(0xFF1B1B20), pat: TilePattern.marble, patColor: const Color(0xFF7A7F8C)),
  TileStyle.mk('رخام ملكي', const Color(0xFF2B2B33), const Color(0xFF0A0A0E),
      pip: const Color(0xFFE9C45A), pat: TilePattern.marble, patColor: const Color(0xFFD4AF37), trim: const Color(0xFFD4AF37)),
  TileStyle.mk('رخام زمردي', const Color(0xFF2F8F6A), const Color(0xFF0B3D2B),
      pat: TilePattern.marble, patColor: const Color(0xFFCFF5E1)),
  TileStyle.mk('رخام وردي', const Color(0xFFF6D9D6), const Color(0xFFD9A5A5),
      pip: const Color(0xFF4A1F2A), pat: TilePattern.marble, patColor: const Color(0xFF9B5F66)),
  TileStyle.mk('لازورد', const Color(0xFF2D56B3), const Color(0xFF0B1F5C),
      pip: const Color(0xFFFFE08A), pat: TilePattern.marble, patColor: const Color(0xFFE9C45A), trim: const Color(0xFFE9C45A)),
  TileStyle.mk('ذهب', const Color(0xFFFFE08A), const Color(0xFFC9962B),
      pip: const Color(0xFF2A1D00), pat: TilePattern.brushed, patColor: const Color(0xFFFFF6D0), trim: const Color(0xFF8A6A12)),
  TileStyle.mk('فضة', const Color(0xFFF4F6FA), const Color(0xFFA9B0BF),
      pip: const Color(0xFF14161C), pat: TilePattern.brushed, patColor: const Color(0xFFFFFFFF)),
  TileStyle.mk('بلاتين', const Color(0xFF8E96A8), const Color(0xFF3C4254),
      pat: TilePattern.brushed, patColor: const Color(0xFFFFFFFF), trim: const Color(0xFFE6E8EE)),
  TileStyle.mk('نحاس', const Color(0xFFE8A070), const Color(0xFF9A4F2A),
      pip: const Color(0xFF2A1208), pat: TilePattern.brushed, patColor: const Color(0xFFFFD2B0)),
  TileStyle.mk('برونز', const Color(0xFFB98B4E), const Color(0xFF5C3A17),
      pip: const Color(0xFFFFF0CC), pat: TilePattern.brushed, patColor: const Color(0xFFE6C48A), trim: const Color(0xFFE6C48A)),
  TileStyle.mk('كربون أسود', const Color(0xFF3A3A40), const Color(0xFF0E0E12),
      pip: const Color(0xFFFF3B3B), pat: TilePattern.carbon, trim: const Color(0xFFFF3B3B)),
  TileStyle.mk('كربون أحمر', const Color(0xFF8E1020), const Color(0xFF2A0208),
      pat: TilePattern.carbon, trim: const Color(0xFFFFFFFF)),
  TileStyle.mk('كربون أزرق', const Color(0xFF1D4E9E), const Color(0xFF07163A),
      pip: const Color(0xFF8AD8FF), pat: TilePattern.carbon, trim: const Color(0xFF8AD8FF)),
  TileStyle.mk('جوز', const Color(0xFF9A6B43), const Color(0xFF4B2D16),
      pip: const Color(0xFFFFF0D6), pat: TilePattern.wood, patColor: const Color(0xFF2A1608)),
  TileStyle.mk('ماهوجني', const Color(0xFFA8462E), const Color(0xFF4A150B),
      pip: const Color(0xFFFFE6C8), pat: TilePattern.wood, patColor: const Color(0xFF220804)),
  TileStyle.mk('أبنوس', const Color(0xFF3A2F2A), const Color(0xFF0F0A08),
      pip: const Color(0xFFE9C45A), pat: TilePattern.wood, patColor: const Color(0xFF8A7466), trim: const Color(0xFFD4AF37)),
  TileStyle.mk('كرز', const Color(0xFFC9784A), const Color(0xFF7A3418),
      pip: const Color(0xFFFFF1DE), pat: TilePattern.wood, patColor: const Color(0xFF3A1606)),
  TileStyle.mk('جلد أسود', const Color(0xFF3A3A3E), const Color(0xFF121214),
      pip: const Color(0xFFE9C45A), pat: TilePattern.leather, trim: const Color(0xFFD4AF37)),
  TileStyle.mk('جلد كونياك', const Color(0xFFB4672F), const Color(0xFF5A2A0E),
      pip: const Color(0xFFFFE9C2), pat: TilePattern.leather, trim: const Color(0xFFF0C070)),
  TileStyle.mk('جلد عنابي', const Color(0xFF8E2236), const Color(0xFF35060F),
      pip: const Color(0xFFFFE3A8), pat: TilePattern.leather, trim: const Color(0xFFE9C45A)),
  TileStyle.mk('زمرد', const Color(0xFF3FD08F), const Color(0xFF0A6B45),
      pat: TilePattern.sparkle, trim: const Color(0xFFCFF5E1)),
  TileStyle.mk('ياقوت أزرق', const Color(0xFF4C86F0), const Color(0xFF10338F),
      pat: TilePattern.sparkle, trim: const Color(0xFFBBD4FF)),
  TileStyle.mk('جمشت', const Color(0xFFB07CF0), const Color(0xFF4B1C8F),
      pat: TilePattern.sparkle, trim: const Color(0xFFE2CCFF)),
  TileStyle.mk('فيروز', const Color(0xFF45E0D0), const Color(0xFF0A7F86),
      pip: const Color(0xFF06303A), pat: TilePattern.sparkle, trim: const Color(0xFFFFFFFF)),
  TileStyle.mk('مجرّة', const Color(0xFF4B2C8F), const Color(0xFF0B0620),
      pip: const Color(0xFFFFF4C4), pat: TilePattern.sparkle, trim: const Color(0xFFB794FF)),
  TileStyle.mk('ليل الصحراء', const Color(0xFF1D2A5C), const Color(0xFF050814),
      pip: const Color(0xFFE9C45A), pat: TilePattern.sparkle, patColor: const Color(0xFFF6E3A1), trim: const Color(0xFFD4AF37)),
  TileStyle.mk('ذهب وردي', const Color(0xFFF7C9B8), const Color(0xFFC27C6A),
      pip: const Color(0xFF3A1610), pat: TilePattern.brushed, trim: const Color(0xFFFFE6DA)),
];

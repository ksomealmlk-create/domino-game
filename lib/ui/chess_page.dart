import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../audio/sfx.dart';
import '../chess/chess_controller.dart';
import '../chess/chess_theme.dart';
import '../chess/engine.dart';
import '../chess/game.dart';
import '../chess/scene3d.dart';
import '../core/settings.dart';
import 'avatar_widget.dart';
import 'theme.dart';
import 'widgets.dart';

String _glyph(int type) => const ['', '\u265F', '\u265E', '\u265D', '\u265C', '\u265B', '\u265A'][type] + '\uFE0E';

class ChessPage extends StatefulWidget {
  final Settings st;
  const ChessPage({super.key, required this.st});

  @override
  State<ChessPage> createState() => _ChessPageState();
}

class _ChessPageState extends State<ChessPage> with TickerProviderStateMixin {
  late final bool _white;
  late final ChessController _c;
  late final AnimationController _clock = AnimationController(vsync: this, duration: const Duration(seconds: 100000))..repeat();
  late final AnimationController _mv = AnimationController(vsync: this, duration: const Duration(milliseconds: 750), value: 1.0);
  late final AnimationController _camA = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));

  double _yaw = 0, _pitch = 0.95, _zoom = 1.0;
  double _y0 = 0, _p0 = 0, _z0 = 1, _y1 = 0, _p1 = 0, _z1 = 1;
  double _startZoom = 1.0;
  Size _boardSize = Size.zero;
  int _lastAnimId = 0;
  bool _paused = false, _showOver = false, _overDismissed = false, _wasOver = false;
  Timer? _ot;

  @override
  void initState() {
    super.initState();
    final st = widget.st;
    _white = st.chessColor == 2 ? math.Random().nextBool() : st.chessColor == 0;
    _yaw = _white ? 0 : math.pi;
    _c = ChessController(st, humanWhite: _white, level: st.chessLevel.clamp(0, 2).toInt());
    _c.addListener(_onCtrl);
    _camA.addListener(() {
      final e = Curves.easeInOutCubic.transform(_camA.value);
      _yaw = _y0 + (_y1 - _y0) * e;
      _pitch = _p0 + (_p1 - _p0) * e;
      _zoom = _z0 + (_z1 - _z0) * e;
    });
  }

  @override
  void dispose() {
    _ot?.cancel();
    _c.removeListener(_onCtrl);
    _c.dispose();
    _clock.dispose();
    _mv.dispose();
    _camA.dispose();
    super.dispose();
  }

  void _onCtrl() {
    if (_c.animId != _lastAnimId) {
      _lastAnimId = _c.animId;
      if (_c.anim != null) {
        _mv.forward(from: 0);
      } else {
        _mv.value = 1.0;
      }
    }
    final over = _c.g.over;
    if (over && !_wasOver) {
      _ot?.cancel();
      _ot = Timer(const Duration(milliseconds: 1300), () {
        if (!mounted) return;
        Sfx.i.enabled = widget.st.sound;
        if (_c.g.winner == _c.humanSide) {
          Sfx.i.win();
        } else if (_c.g.winner != 0) {
          Sfx.i.lose();
        }
        setState(() => _showOver = true);
      });
    }
    if (!over) {
      _ot?.cancel();
      _showOver = false;
      _overDismissed = false;
    }
    _wasOver = over;
    if (mounted) setState(() {});
  }

  void _camTo({double? yaw, double? pitch, double? zoom}) {
    _y0 = _yaw;
    _p0 = _pitch;
    _z0 = _zoom;
    _y1 = yaw ?? _yaw;
    _p1 = pitch ?? _pitch;
    _z1 = zoom ?? _zoom;
    _camA.forward(from: 0);
  }

  void _flip() => _camTo(yaw: _yaw + math.pi);
  void _toggleTop() => _camTo(pitch: _pitch < 1.3 ? 1.5 : 0.95, zoom: 1.0);

  void _exit() => Navigator.of(context).pop();

  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final st = widget.st;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _paused = true);
      },
      child: Scaffold(
        backgroundColor: kBg,
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(center: Alignment(0, -0.6), radius: 1.2, colors: [Color(0xFF222C3D), Color(0xFF07090D)]),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _topBar(st),
                  _playerStrip(opponent: true),
                  Expanded(child: _board(st)),
                  _statusLine(),
                  _playerStrip(opponent: false),
                  _toolbar(),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            if (_c.pendingPromo != null) _promoDialog(),
            if (_paused) _pauseMenu(),
            if (_showOver && !_overDismissed) _overDialog(),
          ],
        ),
      ),
    );
  }

  Widget _topBar(Settings st) {
    const lv = ['سهل', 'متوسط', 'صعب'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => setState(() => _paused = true),
            icon: const Icon(Icons.pause_circle_outline_rounded, color: kGoldLight, size: 30),
          ),
          Expanded(
            child: Column(
              children: [
                const Text('شطرنج 3D', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kGoldLight)),
                Text('ضد الكمبيوتر · ${lv[_c.level]} · أنت ${_white ? 'الأبيض' : 'الأسود'}',
                    style: const TextStyle(fontSize: 11, color: Colors.white54)),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () {
              st.update(() => st.sound = !st.sound);
              Sfx.i.enabled = st.sound;
            },
            icon: Icon(st.sound ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: kGoldLight, size: 26),
          ),
        ],
      ),
    );
  }

  // ---------------- شريط اللاعب ----------------
  Widget _playerStrip({required bool opponent}) {
    final st = widget.st;
    final sideWhite = opponent ? !_white : _white;
    final name = opponent ? 'الكمبيوتر' : st.displayName;
    final active = !_c.g.over && _c.g.whiteToMove == sideWhite;
    final caps = _c.g.capturedBy(sideWhite);
    final diff = _c.g.materialDiff * (sideWhite ? 1 : -1);
    final set = chessSets[st.chessPieces.clamp(0, chessSets.length - 1).toInt()];
    final rawCap = sideWhite ? set.black : set.white;
    final capColor = rawCap.computeLuminance() < 0.15 ? Color.lerp(rawCap, Colors.white, 0.5)! : rawCap;
    final thinking = opponent && _c.thinking;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 3, 10, 3),
      child: Panel(
        glowing: active,
        pad: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            AvatarCircle(bytes: opponent ? null : st.avatarBytes, name: name, radius: 17, active: active),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: sideWhite ? const Color(0xFFF4EAD2) : const Color(0xFF1A1A1E),
                          border: Border.all(color: Colors.white54),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                      if (diff > 0) Text('  +$diff', style: const TextStyle(color: kGold, fontWeight: FontWeight.w900, fontSize: 12)),
                    ],
                  ),
                  SizedBox(
                    height: 22,
                    child: caps.isEmpty
                        ? const Text('—', style: TextStyle(color: Colors.white24, fontSize: 12))
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final t in caps)
                                  Text(_glyph(t),
                                      style: TextStyle(fontSize: 18, height: 1.2, color: capColor, shadows: const [Shadow(color: Colors.black87, blurRadius: 3)])),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
            if (thinking)
              const Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: kGold)),
                SizedBox(width: 8),
                Text('يفكر…', style: TextStyle(color: kGoldLight, fontSize: 12)),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _statusLine() {
    String s;
    Color col = Colors.white70;
    if (_c.toast != null) {
      s = _c.toast!;
      col = const Color(0xFFFF8A80);
    } else if (_c.g.over) {
      s = _resultTitle();
      col = kGoldLight;
    } else if (_c.thinking) {
      s = 'الكمبيوتر يفكر…';
    } else if (_c.hinting) {
      s = 'أبحث عن أفضل نقلة…';
    } else if (_c.humanTurn) {
      s = _c.g.inCheck ? 'كش! دافع عن ملكك' : 'دورك';
      col = _c.g.inCheck ? const Color(0xFFFF8A80) : kGoldLight;
    } else {
      s = '';
    }
    final last = _c.g.lastSan;
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(s, style: TextStyle(color: col, fontWeight: FontWeight.w800, fontSize: 14)),
          if (last.isNotEmpty) Text('   ·   آخر نقلة: $last', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  // ---------------- اللوحة ثلاثية الأبعاد ----------------
  Widget _board(Settings st) {
    final theme = chessBoards[st.chessBoard.clamp(0, chessBoards.length - 1).toInt()];
    final set = chessSets[st.chessPieces.clamp(0, chessSets.length - 1).toInt()];
    final tt = tableThemes[st.table.clamp(0, tableThemes.length - 1).toInt()];
    return LayoutBuilder(builder: (context, cons) {
      _boardSize = Size(cons.maxWidth, cons.maxHeight);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: (d) {
          _startZoom = _zoom;
          _camA.stop();
        },
        onScaleUpdate: (d) {
          if (d.pointerCount >= 2) {
            _zoom = (_startZoom * d.scale).clamp(0.8, 1.7).toDouble();
          } else {
            _yaw -= d.focalPointDelta.dx * 0.008;
            _pitch = (_pitch + d.focalPointDelta.dy * 0.005).clamp(0.35, 1.5).toDouble();
          }
        },
        onTapUp: (d) {
          final pr = ChessProjector(_boardSize, _yaw, _pitch, _zoom);
          final sq = pr.pick(d.localPosition, _c.g.pos.board);
          if (sq >= 0) _c.tapSquare(sq);
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([_clock, _mv]),
          builder: (_, __) {
            final m = _c.anim;
            final mt = m == null ? 1.0 : _mv.value;
            var shake = Offset.zero;
            if (m != null && m.isCapture && mt > 0.62 && mt < 1.0) {
              final u = (mt - 0.62) / 0.38;
              shake = Offset(math.sin(u * 50) * 5 * (1 - u), math.cos(u * 43) * 3 * (1 - u));
            }
            return CustomPaint(
              size: Size.infinite,
              painter: ChessScenePainter(
                board: _c.g.pos.board,
                yaw: _yaw,
                pitch: _pitch,
                zoom: _zoom,
                theme: theme,
                pset: set,
                felt: tt.felt,
                feltDark: tt.feltDark,
                shadows: st.shadows,
                mv: m,
                mt: mt,
                selected: _c.selected,
                targets: st.hints ? _c.targets : const <int, bool>{},
                lastFrom: _c.lastFrom,
                lastTo: _c.lastTo,
                checkSq: _c.checkSq,
                hintFrom: _c.hintFrom,
                hintTo: _c.hintTo,
                clock: _clock.value * 100000,
                shake: shake,
              ),
            );
          },
        ),
      );
    });
  }

  // ---------------- الأدوات ----------------
  Widget _tool(IconData icon, String label, VoidCallback? onTap) => Expanded(
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: kGoldLight, size: 24),
                  const SizedBox(height: 2),
                  Text(label, style: const TextStyle(fontSize: 10.5, color: Colors.white70)),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _toolbar() {
    final canAct = _c.humanTurn && !_c.thinking;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Panel(
        pad: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            _tool(Icons.cached_rounded, 'قلب اللوحة', _flip),
            _tool(Icons.layers_rounded, _pitch < 1.3 ? 'منظور علوي' : 'منظور 3D', _toggleTop),
            _tool(Icons.lightbulb_outline_rounded, 'تلميح', canAct ? _c.hint : null),
            _tool(Icons.undo_rounded, 'تراجع', (_c.g.log.isNotEmpty && !_c.g.over) ? _c.undo : null),
            _tool(Icons.flag_outlined, 'استسلام', _c.g.over ? null : _confirmResign),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmResign() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استسلام؟'),
        content: const Text('راح تخسر هذي المباراة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لا')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('استسلم')),
        ],
      ),
    );
    if (ok == true) _c.resign();
  }

  // ---------------- الترقية ----------------
  Widget _promoDialog() {
    final set = chessSets[widget.st.chessPieces.clamp(0, chessSets.length - 1).toInt()];
    final col = _white ? set.white : set.black;
    final light = col.computeLuminance() > 0.35;
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(onTap: _c.cancelPromo, child: Container(color: alpha(Colors.black, 0.65))),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Panel(
                glowing: true,
                pad: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('ترقية البيدق', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kGoldLight)),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final t in const [kQ, kR, kB, kN])
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: GestureDetector(
                              onTap: () => _c.choosePromo(t),
                              child: Container(
                                width: 62,
                                height: 70,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: light ? const Color(0xFF2B3140) : const Color(0xFFE9E2D0),
                                  border: Border.all(color: kGold, width: 1.4),
                                ),
                                child: Text(_glyph(t), style: TextStyle(fontSize: 44, height: 1.1, color: col, shadows: const [Shadow(color: Colors.black54, blurRadius: 3)])),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- القوائم ----------------
  Widget _pauseMenu() => Positioned.fill(
        child: Stack(
          children: [
            Container(color: alpha(Colors.black, 0.72)),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Panel(
                  glowing: true,
                  pad: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('متوقّف مؤقتًا', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kGoldLight)),
                      const SizedBox(height: 8),
                      const Text('اسحب باصبع واحد لتدوير اللوحة، وبإصبعين للتقريب.\nاضغط على قطعتك ثم على المربع المطلوب.',
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.6)),
                      const SizedBox(height: 18),
                      SizedBox(width: double.infinity, child: GoldButton('متابعة', icon: Icons.play_arrow_rounded, onTap: () => setState(() => _paused = false))),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: GoldButton('لعبة جديدة', ghost: true, icon: Icons.refresh_rounded, onTap: () {
                          setState(() => _paused = false);
                          _c.restart();
                        }),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(width: double.infinity, child: GoldButton('خروج للقائمة', ghost: true, icon: Icons.exit_to_app_rounded, onTap: _exit)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  String _resultTitle() {
    final g = _c.g;
    final won = g.winner == _c.humanSide;
    switch (g.end) {
      case ChessEnd.checkmate:
        return won ? '🏆 كش مات! فزت' : 'كش مات — فاز الكمبيوتر';
      case ChessEnd.resign:
        return 'استسلمت — فاز الكمبيوتر';
      case ChessEnd.stalemate:
        return 'تعادل — ستيل ميت';
      case ChessEnd.insufficient:
        return 'تعادل — مادة غير كافية';
      case ChessEnd.fifty:
        return 'تعادل — قاعدة الخمسين نقلة';
      case ChessEnd.repetition:
        return 'تعادل — تكرار الوضع';
      case null:
        return '';
    }
  }

  String _resultDetail() {
    switch (_c.g.end) {
      case ChessEnd.checkmate:
        return 'عدد النقلات: ${(_c.g.log.length + 1) ~/ 2}';
      case ChessEnd.stalemate:
        return 'ما في حركة قانونية للاعب اللي عليه الدور وملكه مو في كش';
      case ChessEnd.insufficient:
        return 'ما يكدر أي طرف يسوي كش مات';
      case ChessEnd.fifty:
        return '50 نقلة بدون أخذ أو تحريك بيدق';
      case ChessEnd.repetition:
        return 'تكرر نفس الوضع 3 مرات';
      default:
        return '';
    }
  }

  Widget _overDialog() {
    final won = _c.g.winner == _c.humanSide;
    return Positioned.fill(
      child: Stack(
        children: [
          Container(color: alpha(Colors.black, 0.72)),
          if (won) const Positioned.fill(child: Confetti()),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Panel(
                glowing: true,
                pad: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_resultTitle(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kGoldLight)),
                    const SizedBox(height: 8),
                    Text(_resultDetail(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, height: 1.5)),
                    const SizedBox(height: 18),
                    SizedBox(width: double.infinity, child: GoldButton('لعبة جديدة', icon: Icons.refresh_rounded, onTap: _c.restart)),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: GoldButton('عرض اللوحة', ghost: true, icon: Icons.visibility_rounded, onTap: () => setState(() => _overDismissed = true)),
                    ),
                    TextButton(onPressed: _exit, child: const Text('خروج للقائمة', style: TextStyle(color: Colors.white60))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

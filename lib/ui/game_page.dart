import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../audio/sfx.dart';
import '../core/rules.dart';
import '../core/settings.dart';
import '../core/view.dart';
import '../game/controller.dart';
import '../net/online.dart';
import 'chat_sheet.dart';
import 'table_scene.dart';
import 'avatar_widget.dart';
import 'theme.dart';
import 'tile_painter.dart';
import 'widgets.dart';

class GamePage extends StatefulWidget {
  final GameController ctrl;
  final Settings st;
  const GamePage({super.key, required this.ctrl, required this.st});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  int? _pending;
  bool _paused = false, _showOver = false, _wasOver = false, _ready = false;
  Timer? _ot, _tick;

  @override
  void initState() {
    super.initState();
    _wasOver = widget.ctrl.view?.over ?? false;
    widget.ctrl.addListener(_onCtrl);
    // عدّاد دور اللاعب: يحدّث الشاشة كل ثانية
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final oc = _oc;
      if (mounted && oc != null && oc.turnEnd != null) setState(() {});
    });
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_onCtrl);
    _tick?.cancel();
    _ot?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _onCtrl() {
    final v = widget.ctrl.view;
    final over = v?.over ?? false;
    if (over && !_wasOver) {
      _ot?.cancel();
      _ot = Timer(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        final vv = widget.ctrl.view;
        Sfx.i.enabled = widget.st.sound;
        if (vv != null) {
          if (vv.iAmWinnerTeam) {
            Sfx.i.win();
          } else {
            Sfx.i.lose();
          }
        }
        setState(() => _showOver = true);
      });
    }
    if (!over) {
      _ot?.cancel();
      _showOver = false;
      _ready = false;
    }
    _wasOver = over;
    if (_pending != null && (v == null || v.turn != 0 || v.over)) _pending = null;
    if (mounted) setState(() {});
  }

  OnlineController? get _oc => widget.ctrl is OnlineController ? widget.ctrl as OnlineController : null;

  void _exit() {
    widget.ctrl.leave();
    Navigator.of(context).pop();
  }

  void _tapTile(GameView v, int i) {
    if (v.spectator || v.turn != 0 || v.over) return;
    final t = v.myHand[i];
    final sides = sidesFor(t, v.chain);
    if (sides.isEmpty) return;
    if (widget.st.haptics) HapticFeedback.selectionClick();
    if (sides.length == 1) {
      widget.ctrl.play(i, sides[0]);
      return;
    }
    if (v.chain.first.a == v.chain.last.b) {
      widget.ctrl.play(i, 'R');
      return;
    }
    setState(() => _pending = _pending == i ? null : i);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.ctrl.view;
    if (v == null) {
      return const Scaffold(backgroundColor: kBg, body: Center(child: CircularProgressIndicator(color: kGold)));
    }
    final st = widget.st;
    final ts = tileStyles[st.tiles.clamp(0, tileStyles.length - 1).toInt()];
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
                  gradient: RadialGradient(
                    center: Alignment(0, -0.6),
                    radius: 1.2,
                    colors: [Color(0xFF222C3D), Color(0xFF07090D)],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _topBar(v),
                  _opponents(v, ts),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: TableScene(
                            view: v,
                            st: st,
                            pick: _pending != null,
                            onPick: (side) {
                              final i = _pending;
                              if (i == null) return;
                              setState(() => _pending = null);
                              widget.ctrl.play(i, side);
                            },
                          ),
                        ),
                        Positioned(
                          top: 6,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Center(
                              child: AnimatedOpacity(
                                opacity: widget.ctrl.toast == null ? 0 : 1,
                                duration: const Duration(milliseconds: 250),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: alpha(Colors.black, 0.75),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: alpha(kGold, 0.7)),
                                  ),
                                  child: Text(widget.ctrl.toast ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.w700, color: kGoldLight)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 6,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(child: Center(child: _timerChip(v))),
                        ),
                      ],
                    ),
                  ),
                  _statusBar(v),
                  v.spectator ? _specBar(v) : _hand(v, ts),
                ],
              ),
            ),
            if (_showOver && v.over) _roundOver(v),
            if (_paused) _pauseMenu(),
            if (_oc?.vote != null) _voteBox(_oc!.vote!),
          ],
        ),
      ),
    );
  }

  // ---------- الشريط العلوي ----------
  Widget _topBar(GameView v) {
    final mode = v.n == 4 ? 'فريقين' : '151';
    final goal = '${v.target} نقطة';
    final oc = _oc;
    final eye = (oc != null && oc.specNames.isNotEmpty) ? ' · 👁 ${oc.specNames.length}' : '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
      child: Row(
        children: [
          IconButton(onPressed: () => setState(() => _paused = true), icon: const Icon(Icons.pause_circle_outline_rounded, color: kGoldLight, size: 30)),
          Expanded(
            child: Column(
              children: [
                Text('دومينو · $mode', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kGoldLight)),
                Text('الجولة ${v.round} · الهدف $goal${widget.ctrl.isOnline ? ' · أونلاين' : ''}$eye',
                    style: const TextStyle(fontSize: 11, color: Colors.white54)),
                if (v.n == 4)
                  Text(v.spectator ? 'الأول ★ ${v.ourScore}   ·   الثاني ★ ${v.theirScore}' : 'نحن ★ ${v.ourScore}   ·   هم ★ ${v.theirScore}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kGold)),
              ],
            ),
          ),
          if (oc != null && !v.spectator) _micBtn(oc),
          if (oc != null) _chatBtn(oc),
          if (oc != null && !v.spectator)
            IconButton(
              tooltip: 'إبلاغ اللاعبين',
              visualDensity: VisualDensity.compact,
              onPressed: oc.invite,
              icon: const Icon(Icons.campaign_rounded, color: kGoldLight, size: 26),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () {
              widget.st.update(() => widget.st.sound = !widget.st.sound);
              Sfx.i.enabled = widget.st.sound;
            },
            icon: Icon(widget.st.sound ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: kGoldLight, size: 26),
          ),
        ],
      ),
    );
  }

  Uint8List? _av(int r) {
    final l = widget.ctrl.avatars;
    return r < l.length ? l[r] : null;
  }

  // ---------- الخصوم ----------
  Widget _opponents(GameView v, TileStyle ts) {
    final small = v.n >= 4;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      child: Row(
        children: [
          for (var p = 1; p < v.n; p++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Panel(
                  glowing: v.turn == p && !v.over,
                  pad: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _playerCard(p, v),
                        child: AvatarCircle(bytes: _av(p), name: v.names[p], radius: small ? 15 : 19, active: v.turn == p && !v.over),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (v.n == 4 && p == 2) const Padding(padding: EdgeInsetsDirectional.only(end: 3), child: Icon(Icons.handshake_rounded, size: 13, color: kGoldLight)),
                                Expanded(
                                  child: Text(v.names[p],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: v.n == 4 && p == 2 ? kGoldLight : Colors.white)),
                                ),
                              ],
                            ),
                            if ((_oc?.idAt(p) ?? 0) != 0)
                              Text('ID: ${_oc!.idAt(p)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 10.5, letterSpacing: 0.5)),
                            Text(v.n == 2 ? '★ ${v.scores[p]}' : '★ ${v.scores[p]} · ${v.handSizes[p]} حجر',
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kGold, fontWeight: FontWeight.w800, fontSize: 11.5)),
                          ],
                        ),
                      ),
                      if (v.n == 2)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BackStack(count: v.handSizes[p], st: ts),
                            Text('× ${v.handSizes[p]}', style: const TextStyle(fontSize: 10, color: Colors.white54)),
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

  // ---------- شريط الحالة ----------
  Widget _statusBar(GameView v) {
    final can = v.myHand.any((t) => sidesFor(t, v.chain).isNotEmpty);
    Widget mid;
    if (v.over) {
      mid = const SizedBox.shrink();
    } else if (v.spectator) {
      mid = Text('${v.names[v.turn]} يلعب…', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700));
    } else if (v.turn == 0) {
      if (can) {
        mid = AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) => Text('دورك — اختر حجرًا مضيئًا',
              style: TextStyle(fontWeight: FontWeight.w800, color: Color.lerp(kGoldLight, Colors.white, (math.sin(_pulse.value * 2 * math.pi) + 1) / 2))),
        );
      } else if (v.stock > 0) {
        mid = GoldButton('اسحب حجرًا (${v.stock})', icon: Icons.download_rounded, fontSize: 15, pad: const EdgeInsets.symmetric(vertical: 8, horizontal: 18), onTap: widget.ctrl.draw);
      } else {
        mid = const Text('ما عندك حجر — تخطّي تلقائي…', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700));
      }
    } else {
      mid = Text('${v.names[v.turn]} يفكّر…', style: const TextStyle(color: Colors.white60));
    }
    final l = v.chain.isEmpty ? '-' : '${v.chain.first.a}';
    final r = v.chain.isEmpty ? '-' : '${v.chain.last.b}';
    return Container(
      height: 56,
      margin: const EdgeInsets.fromLTRB(10, 2, 10, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: alpha(Colors.black, 0.35), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AvatarCircle(bytes: _av(0), name: v.names[0], radius: 16, active: v.turn == 0 && !v.over),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.names[0], style: const TextStyle(fontSize: 12, color: Colors.white60)),
                  if ((_oc?.myId ?? 0) != 0) Text('ID: ${_oc!.myId}', style: const TextStyle(fontSize: 10, color: Colors.white38)),
                  Text('★ ${v.scores[0]}', style: const TextStyle(color: kGold, fontWeight: FontWeight.w900, fontSize: 16)),
                ],
              ),
            ],
          ),
          Expanded(child: Center(child: mid)),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('المخزون ${v.stock}', style: const TextStyle(fontSize: 12, color: Colors.white60)),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text('◀ $l   $r ▶', style: const TextStyle(fontWeight: FontWeight.w800, color: kGoldLight)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- يدي ----------
  Widget _hand(GameView v, TileStyle ts) {
    final sw = MediaQuery.of(context).size.width;
    final w = math.min(52.0, (sw - 24) / 7 - 4);
    final h = w * 2;
    final myTurn = v.turn == 0 && !v.over;
    return SizedBox(
      height: h + 36,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < v.myHand.length; i++)
                  GestureDetector(
                    onTap: () => _tapTile(v, i),
                    child: Builder(builder: (_) {
                      final ok = myTurn && sidesFor(v.myHand[i], v.chain).isNotEmpty;
                      final hint = widget.st.hints && ok;
                      return TileWidget(
                        tile: v.myHand[i],
                        st: ts,
                        w: w,
                        h: h,
                        glow: hint,
                        lift: ok ? 10 + (hint ? 3 * math.sin(_pulse.value * 2 * math.pi + i) : 0) : 0,
                        dim: myTurn && !ok ? 0.38 : 0,
                      );
                    }),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _teamRow(String title, String names, int score, bool won, int? pips) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(won ? Icons.emoji_events_rounded : Icons.groups_rounded, color: won ? kGold : Colors.white38, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: won ? FontWeight.w900 : FontWeight.w600)),
                  Text(names, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                ],
              ),
            ),
            if (pips != null) Text('$pips متبقية  ', style: const TextStyle(fontSize: 11, color: Colors.white54)),
            Text('★ $score', style: const TextStyle(color: kGold, fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
      );

  // ---------- نهاية الجولة ----------
  Widget _roundOver(GameView v) {
    final w = v.matchOver ? v.matchWinner : v.roundWinner;
    final iWon = !v.spectator && v.iAmWinnerTeam;
    final team = v.n == 4;
    final winName = team ? (v.spectator ? '${v.names[w]} + ${v.names[(w + 2) % 4]}' : 'الفريق الآخر') : v.names[w];
    final title = v.matchOver
        ? (iWon ? (team ? '🏆 فريقكم فاز باللعبة!' : '🏆 فزت باللعبة!') : 'فاز $winName باللعبة')
        : (iWon ? (team ? '🎉 فريقكم فاز بالجولة!' : '🎉 فزت بالجولة!') : 'فاز $winName بالجولة');
    final detail = v.blocked ? 'اللعبة انغلقت — اللي عنده أقل نقاط يفوز' : 'خلّص حجاراته';
    final btn = v.matchOver ? 'إعادة اللعبة' : 'الجولة التالية';
    final online = widget.ctrl.isOnline;
    return Positioned.fill(
      child: Stack(
        children: [
          Container(color: alpha(Colors.black, 0.72)),
          if (iWon) const Positioned.fill(child: Confetti()),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Panel(
                glowing: true,
                pad: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kGoldLight)),
                    const SizedBox(height: 6),
                    Text('$detail  ·  +${v.roundGain}', style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 14),
                    if (team) ...[
                      _teamRow(v.spectator ? 'الفريق الأول' : 'فريقكم', '${v.names[0]} + ${v.names[2]}', v.ourScore, v.sameTeam(w), v.pipsLeft.length > 3 ? v.pipsLeft[0] + v.pipsLeft[2] : null),
                      _teamRow(v.spectator ? 'الفريق الثاني' : 'الفريق الآخر', '${v.names[1]} + ${v.names[3]}', v.theirScore, !v.sameTeam(w), v.pipsLeft.length > 3 ? v.pipsLeft[1] + v.pipsLeft[3] : null),
                    ] else
                      for (var p = 0; p < v.n; p++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Icon(p == w ? Icons.emoji_events_rounded : Icons.person_rounded, color: p == w ? kGold : Colors.white38, size: 20),
                              const SizedBox(width: 8),
                              Expanded(child: Text(v.names[p], style: TextStyle(fontWeight: p == w ? FontWeight.w900 : FontWeight.w500))),
                              if (v.pipsLeft.length > p) Text('${v.pipsLeft[p]} نقطة متبقية  ', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                              Text('★ ${v.scores[p]}', style: const TextStyle(color: kGold, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                    const SizedBox(height: 16),
                    if (v.spectator)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('بانتظار الجولة القادمة…', style: TextStyle(color: Colors.white70)))
                    else
                      GoldButton(
                      online && _ready ? 'بانتظار الباقين…' : (online && !v.matchOver ? 'جاهز' : btn),
                      icon: Icons.play_arrow_rounded,
                      onTap: online && _ready
                          ? null
                          : () {
                              setState(() => _ready = true);
                              widget.ctrl.next();
                            },
                    ),
                    const SizedBox(height: 8),
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

  // ---------- بطاقة اللاعب (ID + إضافة صديق) ----------
  void _playerCard(int p, GameView v) {
    final oc = _oc;
    if (oc == null) return;
    final id = oc.idAt(p);
    if (id == 0 || id == oc.myId) return;
    final name = v.names[p];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AnimatedBuilder(
        animation: oc,
        builder: (ctx, __) {
          final isF = oc.isFriend(id);
          final pend = oc.hasPending(id);
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF10151F),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              border: Border(top: BorderSide(color: kGold, width: 1.2)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kGoldLight)),
                  const SizedBox(height: 4),
                  Text('ID: $id', style: const TextStyle(color: Colors.white60, letterSpacing: 1.5)),
                  const SizedBox(height: 14),
                  if (isF)
                    const Text('صديقك ✅', style: TextStyle(color: kGoldLight, fontWeight: FontWeight.w700))
                  else if (pend)
                    const Text('تم إرسال طلب الصداقة — بانتظار الرد', style: TextStyle(color: Colors.white60))
                  else
                    GoldButton('إضافة صديق', icon: Icons.person_add_alt_1_rounded, onTap: () => oc.friendReq(id)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------- عدّاد الدور ----------
  Widget _timerChip(GameView v) {
    final oc = _oc;
    final left = oc?.turnLeft ?? 0;
    if (oc == null || left <= 0 || v.over) return const SizedBox.shrink();
    final mine = !v.spectator && v.turn == 0;
    final low = left <= 10;
    final col = low ? const Color(0xFFFF6B6B) : kGoldLight;
    final who = mine ? 'دورك' : v.names[v.turn];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: alpha(Colors.black, 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: low ? col : alpha(kGold, 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 16, color: col),
          const SizedBox(width: 6),
          Text('$who · $left', style: TextStyle(fontWeight: FontWeight.w800, color: col)),
        ],
      ),
    );
  }

  // ---------- المكالمة الصوتية ----------
  Widget _micBtn(OnlineController oc) {
    final on = oc.voiceOn;
    final muted = oc.micMuted;
    return IconButton(
      tooltip: on ? (muted ? 'افتح المايك' : 'اكتم المايك') : 'مكالمة صوتية',
      visualDensity: VisualDensity.compact,
      onPressed: oc.voiceBusy ? null : oc.toggleVoice,
      onLongPress: on ? oc.leaveVoice : null,
      icon: oc.voiceBusy
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kGoldLight))
          : Icon(
              !on ? Icons.mic_none_rounded : (muted ? Icons.mic_off_rounded : Icons.mic_rounded),
              color: !on ? kGoldLight : (muted ? Colors.redAccent : Colors.greenAccent),
              size: 26,
            ),
    );
  }

  // ---------- المشاهدة / الدردشة / التصويت ----------
  Widget _chatBtn(OnlineController oc) => IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: () => showChat(context, oc),
        icon: Badge(
          isLabelVisible: oc.unread > 0,
          label: Text('${oc.unread}'),
          child: const Icon(Icons.chat_bubble_outline_rounded, color: kGoldLight, size: 26),
        ),
      );

  Widget _specBar(GameView v) {
    final oc = _oc;
    return Container(
      height: 74,
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: alpha(Colors.black, 0.35), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(Icons.visibility_rounded, color: kGoldLight),
          const SizedBox(width: 8),
          const Expanded(child: Text('أنت تشاهد المباراة', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700))),
          if (oc != null)
            GoldButton(
              'أريد ألعب',
              fontSize: 14,
              icon: Icons.sports_esports_rounded,
              pad: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
              onTap: oc.wantPlay,
            ),
        ],
      ),
    );
  }

  Widget _voteBox(VoteReq r) {
    final oc = _oc!;
    return Positioned.fill(
      child: Container(
        color: alpha(Colors.black, 0.6),
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Panel(
            glowing: true,
            pad: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${r.name} يريد يلعب معكم', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kGoldLight)),
                const SizedBox(height: 8),
                const Text('يدخل من الجولة القادمة مكان أحد البوتات — لازم كل اللاعبين يوافقون', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, height: 1.5)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: GoldButton('موافق', fontSize: 16, pad: const EdgeInsets.symmetric(vertical: 10), onTap: () => oc.answerVote(true))),
                    const SizedBox(width: 10),
                    Expanded(child: GoldButton('رفض', ghost: true, fontSize: 16, pad: const EdgeInsets.symmetric(vertical: 10), onTap: () => oc.answerVote(false))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- القائمة المؤقتة ----------
  Widget _pauseMenu() {
    return Positioned.fill(
      child: Container(
        color: alpha(Colors.black, 0.7),
        alignment: Alignment.center,
        child: Panel(
          glowing: true,
          pad: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('إيقاف مؤقت', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kGoldLight)),
              const SizedBox(height: 16),
              GoldButton('متابعة', icon: Icons.play_arrow_rounded, onTap: () => setState(() => _paused = false)),
              const SizedBox(height: 10),
              GoldButton(widget.st.haptics ? 'الاهتزاز: يعمل' : 'الاهتزاز: متوقف', ghost: true, fontSize: 15, onTap: () {
                widget.st.update(() => widget.st.haptics = !widget.st.haptics);
                setState(() {});
              }),
              const SizedBox(height: 10),
              GoldButton('خروج', ghost: true, icon: Icons.exit_to_app_rounded, onTap: _exit),
            ],
          ),
        ),
      ),
    );
  }
}

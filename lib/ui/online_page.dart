import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/settings.dart';
import '../net/online.dart';
import '../net/presence.dart';
import '../push/push.dart';
import 'chat_sheet.dart';
import 'friends_page.dart';
import 'game_page.dart';
import 'theme.dart';
import 'widgets.dart';

class OnlinePage extends StatefulWidget {
  final Settings st;
  final String? autoJoin; // كود غرفة قادم من إشعار الدعوة
  const OnlinePage({super.key, required this.st, this.autoJoin});

  @override
  State<OnlinePage> createState() => _OnlinePageState();
}

class _OnlinePageState extends State<OnlinePage> {
  late final OnlineController ctrl = OnlineController(widget.st);
  final _code = TextEditingController();
  Timer? _rt;

  @override
  void initState() {
    super.initState();
    Push.online++;
    OnlineController.wake(widget.st.server);
    final aj = widget.autoJoin;
    if (aj != null && aj.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.join(aj));
    } else {
      ctrl.browse();
    }
    _rt = Timer.periodic(const Duration(seconds: 5), (_) {
      if (ctrl.status == OnlineStatus.idle || ctrl.status == OnlineStatus.error) ctrl.refreshRooms();
    });
    ctrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    Push.online--;
    _rt?.cancel();
    _code.dispose();
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ctrl.status == OnlineStatus.playing) {
      return GamePage(ctrl: ctrl, st: widget.st);
    }
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: kGoldLight),
        title: const Text('اللعب أونلاين', style: TextStyle(fontWeight: FontWeight.w900, color: kGoldLight)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(0, -0.6), radius: 1.2, colors: [Color(0xFF222C3D), kBg]),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (ctrl.status == OnlineStatus.lobby && ctrl.lobby != null) _lobby(ctrl.lobby!) else _entry(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _entry() {
    final st = widget.st;
    final busy = ctrl.status == OnlineStatus.connecting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _rooms(busy),
        const SizedBox(height: 10),
        _friendsBtn(),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('إعدادات المباراة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kGoldLight)),
              const SizedBox(height: 10),
              ChoiceRow(labels: const ['لاعبان', '3 لاعبين', '4 لاعبين'], selected: st.players - 2, onSelect: (i) => setState(() => st.update(() => st.players = i + 2))),
              const SizedBox(height: 8),
              const Text('4 لاعبين: كل واحد مع المقابل له · الفوز عند 151 نقطة', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GoldButton(busy ? 'جاري الاتصال… (أول مرة قد ياخذ دقيقة)' : 'مباراة سريعة', icon: Icons.bolt_rounded, onTap: busy ? null : ctrl.quick),
        const SizedBox(height: 12),
        GoldButton('إنشاء غرفة خاصة', ghost: true, icon: Icons.add_circle_outline_rounded, onTap: busy ? null : ctrl.create),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          activeColor: kGold,
          title: Text(Presence.t('invToggle', '📣 إبلاغ العرف الأصليون لما أنشئ غرفة'), style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('يوصل إشعار لكل اللاعبين وينقلهم مباشرة لغرفتك', style: TextStyle(color: Colors.white54, fontSize: 12)),
          value: st.inviteOnCreate,
          onChanged: (v) => setState(() => st.update(() => st.inviteOnCreate = v)),
        ),
        const SizedBox(height: 16),
        Panel(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.w900),
                  decoration: const InputDecoration(counterText: '', hintText: 'كود الغرفة', border: InputBorder.none),
                ),
              ),
              GoldButton('انضمام', fontSize: 15, pad: const EdgeInsets.symmetric(vertical: 10, horizontal: 20), onTap: busy ? null : () => ctrl.join(_code.text)),
            ],
          ),
        ),
        if (ctrl.error != null) ...[
          const SizedBox(height: 14),
          Text(ctrl.error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFF8A8A), height: 1.5)),
        ],
        const SizedBox(height: 14),
        const Text('المباراة السريعة تبحث عن لاعب حقيقي، وإن لم يوجد خلال ثوانٍ يُضاف بوت تلقائيًا.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5)),
      ],
    );
  }

  void _openFriends() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FriendsPage(ctrl: ctrl)));

  Widget _friendsBtn() {
    final n = ctrl.inReq.length;
    return Column(
      children: [
        GoldButton(n > 0 ? 'الأصدقاء ($n طلب جديد)' : 'الأصدقاء', ghost: true, icon: Icons.group_rounded, onTap: _openFriends),
        if (ctrl.myId != 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('رقمك (ID): ${ctrl.myId}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _rooms(bool busy) {
    final rs = ctrl.rooms;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('غرف تلعب الآن', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kGoldLight))),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: ctrl.refreshRooms,
                icon: const Icon(Icons.refresh_rounded, color: kGoldLight),
              ),
            ],
          ),
          if (!ctrl.roomsLoaded)
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('جاري تحميل الغرف…', style: TextStyle(color: Colors.white54)))
          else if (rs.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('ماكو غرف حالياً — كوّن غرفتك وبلّغ الأصدقاء', style: TextStyle(color: Colors.white54)))
          else
            for (final r in rs.take(12)) _roomTile(r, busy),
        ],
      ),
    );
  }

  Widget _roomTile(RoomInfo r, bool busy) {
    final names = r.players.isEmpty ? '—' : r.players.join('، ');
    final state = r.started ? 'جارية' : 'بالانتظار';
    final eye = r.specs > 0 ? ' · 👁 ${r.specs}' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(r.started ? Icons.sports_esports_rounded : Icons.hourglass_top_rounded, color: r.started ? kGold : Colors.white38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(names, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('$state · غرفة ${r.code}$eye', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          GoldButton(
            r.started ? 'مشاهدة' : 'انضمام',
            ghost: r.started,
            fontSize: 14,
            pad: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
            onTap: busy ? null : () => ctrl.join(r.code),
          ),
        ],
      ),
    );
  }

  Widget _lobby(LobbyInfo l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          glowing: true,
          child: Column(
            children: [
              Text(l.quick ? 'جاري البحث عن لاعبين…' : 'كود الغرفة', style: const TextStyle(color: Colors.white60)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => Clipboard.setData(ClipboardData(text: l.code)),
                child: Text(l.code, style: const TextStyle(fontSize: 54, letterSpacing: 10, fontWeight: FontWeight.w900, color: kGoldLight)),
              ),
              Text(l.n == 4 ? 'فريقان · 151 نقطة' : '151 نقطة', style: const TextStyle(color: kGold)),
              const SizedBox(height: 14),
              for (var i = 0; i < l.n; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(l.players[i] == null ? Icons.hourglass_empty_rounded : Icons.person_rounded, color: l.players[i] == null ? Colors.white30 : kGold),
                      const SizedBox(width: 10),
                      Text(l.players[i] ?? 'بانتظار لاعب…', style: TextStyle(color: l.players[i] == null ? Colors.white38 : Colors.white, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (l.host && !l.quick) GoldButton(Presence.t('invBtn', 'إبلاغ العرف الأصليون'), ghost: true, icon: Icons.campaign_rounded, onTap: ctrl.invite),
        if (l.host && !l.quick) const SizedBox(height: 10),
        if (l.host && !l.quick) GoldButton('ابدأ الآن (البقية بوتات)', icon: Icons.play_arrow_rounded, onTap: ctrl.startNow),
        const SizedBox(height: 10),
        GoldButton(ctrl.unread > 0 ? 'الدردشة (${ctrl.unread})' : 'الدردشة', ghost: true, icon: Icons.chat_bubble_outline_rounded, onTap: () => showChat(context, ctrl)),
        const SizedBox(height: 10),
        GoldButton('دعوة صديق', ghost: true, icon: Icons.person_add_alt_1_rounded, onTap: _openFriends),
        const SizedBox(height: 10),
        GoldButton('خروج', ghost: true, onTap: ctrl.reset),
      ],
    );
  }
}

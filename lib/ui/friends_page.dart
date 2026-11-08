import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../net/online.dart';
import '../push/push.dart';
import 'theme.dart';
import 'widgets.dart';

const _h = TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kGoldLight);

/// رقمك (ID) + إضافة أصدقاء + قائمة الأصدقاء وحالتهم.
class FriendsPage extends StatefulWidget {
  final OnlineController ctrl;
  const FriendsPage({super.key, required this.ctrl});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final _id = TextEditingController();
  Timer? _t;
  late OnlineStatus _start;
  bool _popped = false;
  OnlineController get c => widget.ctrl;

  @override
  void initState() {
    super.initState();
    _start = c.status;
    c.friendsRefresh();
    c.addListener(_onCtrl);
    _t = Timer.periodic(const Duration(seconds: 8), (_) => c.friendsRefresh());
  }

  @override
  void dispose() {
    _t?.cancel();
    c.removeListener(_onCtrl);
    _id.dispose();
    super.dispose();
  }

  /// لما ننضم لغرفة صديق نرجع لصفحة اللعب
  void _onCtrl() {
    if (!mounted || _popped) return;
    if (c.status != _start && (c.status == OnlineStatus.lobby || c.status == OnlineStatus.playing)) {
      _popped = true;
      Navigator.of(context).maybePop();
    }
  }

  void _add() {
    final id = int.tryParse(_id.text.trim()) ?? 0;
    if (id == 0) {
      Push.toast('اكتب رقم صحيح');
      return;
    }
    if (id == c.myId) {
      Push.toast('هذا رقمك أنت 😄');
      return;
    }
    c.friendReq(id);
    _id.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _remove(Friend f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الصديق'),
        content: Text('تحذف ${f.name} من قائمة أصدقائك؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) c.friendRemove(f.id);
  }

  Widget _me() => Panel(
        child: Column(
          children: [
            const Text('رقمك (ID)', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(c.myId == 0 ? '…' : '${c.myId}', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: kGoldLight, letterSpacing: 3)),
                IconButton(
                  onPressed: c.myId == 0
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: '${c.myId}'));
                          Push.toast('تم نسخ رقمك');
                        },
                  icon: const Icon(Icons.copy_rounded, color: kGold),
                ),
              ],
            ),
            const Text('أعطه لأصدقائك حتى يضيفونك', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      );

  Widget _addBox() => Panel(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _id,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 9,
                onSubmitted: (_) => _add(),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: const InputDecoration(counterText: '', hintText: 'اكتب رقم صديقك (ID)', hintStyle: TextStyle(color: Colors.white38)),
              ),
            ),
            const SizedBox(width: 10),
            GoldButton('إضافة', fontSize: 14, pad: const EdgeInsets.symmetric(vertical: 10, horizontal: 16), onTap: _add),
          ],
        ),
      );

  Widget _reqs() => Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('طلبات الصداقة', style: _h),
            for (final f in c.inReq)
              Row(
                children: [
                  Expanded(child: Text('${f.name}   #${f.id}', style: const TextStyle(fontWeight: FontWeight.w700))),
                  IconButton(onPressed: () => c.friendAccept(f.id), icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50))),
                  IconButton(onPressed: () => c.friendReject(f.id), icon: const Icon(Icons.cancel_rounded, color: Color(0xFFFF6B6B))),
                ],
              ),
          ],
        ),
      );

  Widget _tile(Friend f) {
    final inRoom = f.room != null;
    final myRoom = c.status == OnlineStatus.lobby || c.status == OnlineStatus.playing;
    final String stTxt;
    if (!f.online) {
      stTxt = 'غير متصل';
    } else if (inRoom) {
      stTxt = f.live ? 'يلعب الآن · غرفة ${f.room}' : 'بالانتظار · غرفة ${f.room}';
    } else {
      stTxt = 'متصل';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.circle, size: 12, color: f.online ? const Color(0xFF4CAF50) : Colors.white24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('$stTxt · #${f.id}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          if (inRoom && !myRoom)
            GoldButton(
              f.live ? 'مشاهدة' : 'انضمام',
              ghost: f.live,
              fontSize: 13,
              pad: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
              onTap: () => c.join(f.room!),
            ),
          if (myRoom && f.online && !inRoom)
            GoldButton('دعوة', fontSize: 13, pad: const EdgeInsets.symmetric(vertical: 7, horizontal: 12), onTap: () => c.friendInvite(f.id)),
          PopupMenuButton<int>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white54),
            onSelected: (_) => _remove(f),
            itemBuilder: (_) => const [PopupMenuItem(value: 1, child: Text('حذف الصديق'))],
          ),
        ],
      ),
    );
  }

  Widget _list() {
    final fs = [...c.friends]..sort((a, b) => (b.online ? 1 : 0) - (a.online ? 1 : 0));
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('أصدقائي (${fs.length})', style: _h),
          if (!c.friendsLoaded)
            const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('جاري التحميل…', style: TextStyle(color: Colors.white54)))
          else if (fs.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('ما عندك أصدقاء بعد — أضف صديقك برقمه (ID)', style: TextStyle(color: Colors.white54)))
          else
            for (final f in fs) _tile(f),
          if (c.outReq.isNotEmpty) ...[
            const Divider(color: Colors.white12),
            Text('بانتظار الرد: ${c.outReq.map((f) => f.name).join('، ')}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: kGoldLight),
        title: const Text('الأصدقاء', style: TextStyle(fontWeight: FontWeight.w900, color: kGoldLight)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(0, -0.6), radius: 1.2, colors: [Color(0xFF222C3D), kBg]),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: c,
            builder: (_, __) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _me(),
                const SizedBox(height: 14),
                _addBox(),
                if (c.inReq.isNotEmpty) ...[const SizedBox(height: 14), _reqs()],
                const SizedBox(height: 14),
                _list(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

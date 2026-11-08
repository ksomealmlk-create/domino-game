import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../net/online.dart';
import 'theme.dart';

/// نافذة الدردشة (للاعبين والمشاهدين)
Future<void> showChat(BuildContext context, OnlineController oc) {
  oc.openChat();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ChatSheet(oc: oc),
  ).whenComplete(oc.closeChat);
}

const _quick = ['مرحبا 👋', 'حظ سعيد 🍀', 'أحسنت 👏', 'سريع ⏱', 'ههه 😂'];

class _ChatSheet extends StatefulWidget {
  final OnlineController oc;
  const _ChatSheet({required this.oc});

  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  final _tc = TextEditingController();

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _send([String? t]) {
    final s = (t ?? _tc.text).trim();
    if (s.isEmpty) return;
    widget.oc.sendChat(s);
    if (t == null) _tc.clear();
  }

  Widget _bubble(ChatMsg m) {
    final head = m.spec ? '👁 ${m.name}' : m.name;
    return Align(
      alignment: m.mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: m.mine ? const Color(0xFF3A3012) : const Color(0xFF1B2332),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: m.mine ? kGold : const Color(0xFF2B3446)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!m.mine) Text(head, style: const TextStyle(fontSize: 11, color: kGold, fontWeight: FontWeight.w800)),
            Text(m.text, style: const TextStyle(color: Colors.white, height: 1.35)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final kb = mq.viewInsets.bottom;
    final safe = mq.viewPadding.bottom;
    final h = mq.size.height;
    return Padding(
      padding: EdgeInsets.only(bottom: kb),
      child: Container(
        height: math.min(h * 0.6, h - kb - 40),
        decoration: const BoxDecoration(
          color: Color(0xFF10151F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: kGold, width: 1.2)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Text('الدردشة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: kGoldLight)),
            const SizedBox(height: 6),
            Expanded(
              child: AnimatedBuilder(
                animation: widget.oc,
                builder: (_, __) {
                  final l = widget.oc.chat;
                  if (l.isEmpty) {
                    return const Center(child: Text('ابدأ الدردشة 👋', style: TextStyle(color: Colors.white38)));
                  }
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    itemCount: l.length,
                    itemBuilder: (_, i) => _bubble(l[l.length - 1 - i]),
                  );
                },
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  for (final q in _quick)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ActionChip(
                        backgroundColor: const Color(0xFF1B2332),
                        label: Text(q, style: const TextStyle(color: kGoldLight)),
                        onPressed: () => _send(q),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              margin: EdgeInsets.fromLTRB(10, 4, 10, 10 + (kb > 0 ? 0 : safe)),
              padding: const EdgeInsets.fromLTRB(14, 2, 4, 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2332),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: kGold, width: 1.4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tc,
                      maxLength: 120,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      cursorColor: kGold,
                      decoration: const InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                        hintText: 'اكتب رسالتك هنا…',
                        hintStyle: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(color: kGold, shape: BoxShape.circle),
                    child: IconButton(onPressed: _send, icon: const Icon(Icons.send_rounded, color: Color(0xFF1A1405))),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

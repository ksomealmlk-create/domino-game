import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../push/push.dart';

/// مكالمة صوتية بين لاعبي الغرفة (WebRTC). السيرفر يمرّر رسائل الاتصال فقط، والصوت يروح مباشرة بين اللاعبين.
class VoiceChat {
  final void Function(Map<String, dynamic>) send;
  final void Function() onChange;
  final String deviceId;
  VoiceChat({required this.send, required this.onChange, required this.deviceId});

  bool joined = false, joining = false, muted = false;
  MediaStream? _local;
  List<Map<String, dynamic>> _ice = const [];
  final Map<int, RTCPeerConnection> _pcs = {};
  final Set<int> _hasRemote = {};
  final Map<int, List<RTCIceCandidate>> _pending = {};

  int get peers => _pcs.length;

  static const _fallbackIce = <Map<String, dynamic>>[
    {'urls': 'stun:stun.cloudflare.com:3478'},
    {'urls': 'stun:stun.l.google.com:19302'},
  ];

  /// مفاتيح TURN المؤقتة من الـ Worker (إذا فشل نكمل بـ STUN فقط)
  Future<List<Map<String, dynamic>>> _loadIce() async {
    try {
      final hc = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final rq = await hc.postUrl(Uri.parse('${Push.adminUrl}/api/domino/turn'));
      rq.headers.contentType = ContentType.json;
      rq.write(jsonEncode({'did': deviceId}));
      final rs = await rq.close().timeout(const Duration(seconds: 10));
      final txt = await rs.transform(utf8.decoder).join();
      hc.close();
      final j = jsonDecode(txt) as Map;
      if (j['ok'] == true && j['iceServers'] is List) {
        final l = [for (final x in (j['iceServers'] as List)) Map<String, dynamic>.from(x as Map)];
        if (l.isNotEmpty) return l;
      }
    } catch (_) {}
    return _fallbackIce;
  }

  /// يدخل المكالمة: يطلب صلاحية المايك ثم يبلّغ السيرفر
  Future<void> join() async {
    if (joined || joining) return;
    joining = true;
    onChange();
    try {
      _local = await navigator.mediaDevices.getUserMedia({
        'audio': {'echoCancellation': true, 'noiseSuppression': true, 'autoGainControl': true},
        'video': false,
      });
    } catch (_) {
      joining = false;
      Push.toast('ما قدرت أفتح المايك — اسمح للتطبيق بصلاحية المايك');
      onChange();
      return;
    }
    _ice = await _loadIce();
    try {
      await Helper.setSpeakerphoneOn(true);
    } catch (_) {}
    muted = false;
    joined = true;
    joining = false;
    send({'t': 'vjoin'});
    onChange();
  }

  void toggleMute() {
    if (!joined) return;
    muted = !muted;
    for (final t in _local?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      t.enabled = !muted;
    }
    onChange();
  }

  /// رسائل السيرفر: vpeers / rtc / vgone
  Future<void> onMsg(Map<String, dynamic> m) async {
    if (!joined) return;
    try {
      switch (m['t']) {
        case 'vpeers':
          for (final s in (m['list'] as List)) {
            await _call((s as num).toInt());
          }
          break;
        case 'rtc':
          await _onRtc((m['from'] as num).toInt(), Map<String, dynamic>.from(m['d'] as Map));
          break;
        case 'vgone':
          await _drop((m['s'] as num).toInt());
          break;
      }
    } catch (_) {}
    onChange();
  }

  Future<RTCPeerConnection> _make(int seat) async {
    await _drop(seat);
    final pc = await createPeerConnection({'iceServers': _ice, 'sdpSemantics': 'unified-plan'});
    for (final t in _local!.getAudioTracks()) {
      await pc.addTrack(t, _local!);
    }
    pc.onIceCandidate = (c) {
      if (c.candidate == null) return;
      send({
        't': 'rtc',
        'to': seat,
        'd': {'k': 'cand', 'c': c.candidate, 'm': c.sdpMid, 'i': c.sdpMLineIndex},
      });
    };
    pc.onConnectionState = (_) => onChange();
    _pcs[seat] = pc;
    return pc;
  }

  /// أنا الداخل الجديد: أرسل عرض الاتصال لكل لاعب موجود
  Future<void> _call(int seat) async {
    final pc = await _make(seat);
    final offer = await pc.createOffer({'offerToReceiveAudio': 1});
    await pc.setLocalDescription(offer);
    send({
      't': 'rtc',
      'to': seat,
      'd': {'k': 'offer', 'sdp': offer.sdp},
    });
  }

  Future<void> _onRtc(int from, Map<String, dynamic> d) async {
    switch (d['k']) {
      case 'offer':
        final pc = await _make(from);
        await pc.setRemoteDescription(RTCSessionDescription(d['sdp'] as String, 'offer'));
        _hasRemote.add(from);
        final ans = await pc.createAnswer({'offerToReceiveAudio': 1});
        await pc.setLocalDescription(ans);
        send({
          't': 'rtc',
          'to': from,
          'd': {'k': 'answer', 'sdp': ans.sdp},
        });
        await _flush(from);
        break;
      case 'answer':
        final pc = _pcs[from];
        if (pc == null) return;
        await pc.setRemoteDescription(RTCSessionDescription(d['sdp'] as String, 'answer'));
        _hasRemote.add(from);
        await _flush(from);
        break;
      case 'cand':
        final c = RTCIceCandidate(d['c'] as String?, d['m'] as String?, (d['i'] as num?)?.toInt());
        if (_hasRemote.contains(from) && _pcs[from] != null) {
          await _pcs[from]!.addCandidate(c);
        } else {
          (_pending[from] ??= []).add(c);
        }
        break;
    }
  }

  Future<void> _flush(int seat) async {
    final pc = _pcs[seat];
    final l = _pending.remove(seat);
    if (pc == null || l == null) return;
    for (final c in l) {
      await pc.addCandidate(c);
    }
  }

  Future<void> _drop(int seat) async {
    _hasRemote.remove(seat);
    _pending.remove(seat);
    final pc = _pcs.remove(seat);
    if (pc == null) return;
    try {
      await pc.close();
      await pc.dispose();
    } catch (_) {}
  }

  /// يخرج من المكالمة ويقفل المايك
  Future<void> leave({bool notify = true}) async {
    if (!joined && !joining) return;
    if (notify && joined) send({'t': 'vleave'});
    joined = false;
    joining = false;
    muted = false;
    for (final s in _pcs.keys.toList()) {
      await _drop(s);
    }
    try {
      for (final t in _local?.getTracks() ?? const <MediaStreamTrack>[]) {
        await t.stop();
      }
      await _local?.dispose();
    } catch (_) {}
    _local = null;
    onChange();
  }
}

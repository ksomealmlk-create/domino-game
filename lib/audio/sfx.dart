import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// أصوات مولَّدة برمجيًا (لا حاجة لملفات صوت).
class Sfx {
  Sfx._();
  static final Sfx i = Sfx._();

  bool enabled = true;
  final List<AudioPlayer> _players = [];
  int _k = 0;
  Uint8List? _clack, _swish, _win, _lose, _tick;

  static const int _rate = 22050;

  Uint8List _wav(List<double> s) {
    final n = s.length;
    final bd = ByteData(44 + n * 2);
    void str(int o, String t) {
      for (var i = 0; i < t.length; i++) {
        bd.setUint8(o + i, t.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    bd.setUint32(4, 36 + n * 2, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little);
    bd.setUint16(22, 1, Endian.little);
    bd.setUint32(24, _rate, Endian.little);
    bd.setUint32(28, _rate * 2, Endian.little);
    bd.setUint16(32, 2, Endian.little);
    bd.setUint16(34, 16, Endian.little);
    str(36, 'data');
    bd.setUint32(40, n * 2, Endian.little);
    for (var i = 0; i < n; i++) {
      final v = s[i].clamp(-1.0, 1.0);
      bd.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return bd.buffer.asUint8List();
  }

  Uint8List _makeClack() {
    final r = Random(3);
    final n = (_rate * 0.16).toInt();
    return _wav([
      for (var i = 0; i < n; i++)
        () {
          final t = i / _rate;
          final env = exp(-t * 45);
          final tone = sin(2 * pi * 190 * t) * 0.6 + sin(2 * pi * 430 * t) * 0.25;
          final noise = (r.nextDouble() * 2 - 1) * exp(-t * 160) * 0.7;
          return (tone * env + noise) * 0.9;
        }()
    ]);
  }

  Uint8List _makeSwish() {
    final r = Random(5);
    final n = (_rate * 0.14).toInt();
    var lp = 0.0;
    return _wav([
      for (var i = 0; i < n; i++)
        () {
          final t = i / _rate;
          lp += ((r.nextDouble() * 2 - 1) - lp) * 0.25;
          return lp * sin(pi * t / 0.14) * 0.55;
        }()
    ]);
  }

  Uint8List _makeTick() {
    final n = (_rate * 0.05).toInt();
    return _wav([
      for (var i = 0; i < n; i++)
        sin(2 * pi * 900 * i / _rate) * exp(-i / _rate * 90) * 0.4
    ]);
  }

  Uint8List _notes(List<double> freqs, double each) {
    final out = <double>[];
    final n = (_rate * each).toInt();
    for (final f in freqs) {
      for (var i = 0; i < n; i++) {
        final t = i / _rate;
        final env = exp(-t * 6) * min(1.0, t * 200);
        out.add((sin(2 * pi * f * t) * 0.5 + sin(2 * pi * f * 2 * t) * 0.15) * env * 0.8);
      }
    }
    return _wav(out);
  }

  void _init() {
    if (_players.isNotEmpty) return;
    for (var i = 0; i < 3; i++) {
      final p = AudioPlayer();
      p.setReleaseMode(ReleaseMode.stop);
      _players.add(p);
    }
  }

  Future<void> _play(Uint8List b, double vol) async {
    if (!enabled) return;
    try {
      _init();
      final p = _players[_k++ % _players.length];
      await p.setVolume(vol);
      await p.play(BytesSource(b));
    } catch (_) {}
  }

  void clack() => _play(_clack ??= _makeClack(), 1.0);
  void swish() => _play(_swish ??= _makeSwish(), 0.7);
  void tick() => _play(_tick ??= _makeTick(), 0.5);
  void win() => _play(_win ??= _notes([523.25, 659.25, 783.99, 1046.5], 0.16), 0.9);
  void lose() => _play(_lose ??= _notes([392.0, 329.63, 261.63], 0.2), 0.8);
}

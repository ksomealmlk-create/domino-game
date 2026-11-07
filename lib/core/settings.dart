import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends ChangeNotifier {
  late SharedPreferences _p;

  String name = 'أنت';
  String deviceId = ''; // معرّف جهاز عشوائي (للحظر والإحصائيات فقط)
  String avatarB64 = ''; // صورة اللاعب (PNG صغير بصيغة base64)
  bool profileDone = false;
  Uint8List? _avBytes;
  String _avFor = '';
  Uint8List? get avatarBytes {
    if (avatarB64.isEmpty) return null;
    if (_avFor != avatarB64) {
      try {
        _avBytes = base64Decode(avatarB64);
      } catch (_) {
        _avBytes = null;
      }
      _avFor = avatarB64;
    }
    return _avBytes;
  }
  int table = 0;
  int tiles = 0;
  int level = 1; // 0 سهل 1 متوسط 2 صعب
  bool five = false;
  int players = 4;
  int targetDraw = 3;
  int targetFive = 100;
  bool haptics = true;
  bool sound = true;
  bool shadows = true;
  bool hints = true;
  int speed = 1; // 0 بطيء 1 عادي 2 سريع
  static const String kServer = 'wss://domino-game-7hvz.onrender.com';
  String get server => kServer;

  static Future<Settings> load() async {
    final s = Settings();
    s._p = await SharedPreferences.getInstance();
    s._read();
    return s;
  }

  void _read() {
    name = _p.getString('name') ?? name;
    deviceId = _p.getString('did') ?? '';
    if (deviceId.isEmpty) {
      final r = Random.secure();
      deviceId = List.generate(16, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[r.nextInt(36)]).join();
      _p.setString('did', deviceId);
    }
    avatarB64 = _p.getString('avatar') ?? '';
    profileDone = _p.getBool('profileDone') ?? false;
    table = _p.getInt('table') ?? table;
    tiles = _p.getInt('tiles') ?? tiles;
    level = _p.getInt('level') ?? level;
    players = _p.getInt('players') ?? players;
    targetDraw = _p.getInt('targetDraw') ?? targetDraw;
    targetFive = _p.getInt('targetFive') ?? targetFive;
    haptics = _p.getBool('haptics') ?? haptics;
    sound = _p.getBool('sound') ?? sound;
    shadows = _p.getBool('shadows') ?? shadows;
    hints = _p.getBool('hints') ?? hints;
    speed = _p.getInt('speed') ?? speed;
  }

  void _save() {
    _p.setString('name', name);
    _p.setString('avatar', avatarB64);
    _p.setBool('profileDone', profileDone);
    _p.setInt('table', table);
    _p.setInt('tiles', tiles);
    _p.setInt('level', level);
    _p.setBool('five', five);
    _p.setInt('players', players);
    _p.setInt('targetDraw', targetDraw);
    _p.setInt('targetFive', targetFive);
    _p.setBool('haptics', haptics);
    _p.setBool('sound', sound);
    _p.setBool('shadows', shadows);
    _p.setBool('hints', hints);
    _p.setInt('speed', speed);
  }

  void update(void Function() f) {
    f();
    _save();
    notifyListeners();
  }

  static const int kTarget = 151;
  int get target => kTarget;
  int get botDelayMs => const [1500, 950, 520][speed];
  String get displayName => name.trim().isEmpty ? 'أنت' : name.trim();
}

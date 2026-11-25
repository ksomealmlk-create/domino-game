import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'theme.dart';

/// دائرة صورة اللاعب (أو أول حرف من اسمه إذا ما عنده صورة).
class AvatarCircle extends StatelessWidget {
  final Uint8List? bytes;
  final String name;
  final double radius;
  final bool active;
  const AvatarCircle({super.key, required this.bytes, required this.name, this.radius = 18, this.active = false});

  @override
  Widget build(BuildContext context) {
    final n = name.trim();
    final initial = n.isEmpty ? '?' : n.substring(0, 1);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: active ? kGold : Colors.white24, width: 2)),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: active ? kGold : const Color(0xFF2A3140),
        backgroundImage: bytes == null ? null : MemoryImage(bytes!),
        child: bytes == null
            ? Text(initial, style: TextStyle(fontWeight: FontWeight.w900, fontSize: radius * 0.9, color: active ? kInk : Colors.white70))
            : null,
      ),
    );
  }
}

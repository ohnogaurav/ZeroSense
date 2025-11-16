import 'package:flutter/material.dart';

class PlayerAvatar extends StatelessWidget {
  final String username;
  final double size;

  const PlayerAvatar({super.key, required this.username, this.size = 40});

  Color _colorForName(String name) {
    // deterministic color from name hash
    final colors = [
      Color(0xFF6D5DFB),
      Color(0xFF24D2CF),
      Color(0xFF1EC6A4),
      Color(0xFFB84DFF),
      Color(0xFFFF7A00),
      Color(0xFF2193F3),
    ];
    final h = name.codeUnits.fold(0, (p, e) => p + e);
    return colors[h % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final initial = (username.isNotEmpty) ? username[0].toUpperCase() : '?';
    final bg = _colorForName(username);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: bg,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.5,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/game_state.dart';

class Leaderboard extends StatelessWidget {
  final List<Player> players;
  const Leaderboard({required this.players, super.key});

  @override
  Widget build(BuildContext context) {
    final sorted = List<Player>.from(players)..sort((a, b) => a.bestScore.compareTo(b.bestScore));
    return Card(
      color: Colors.black.withOpacity(0.6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Leaderboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...sorted.map((p) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(p.username, style: const TextStyle(color: Colors.white)),
                Text(p.bestScore.toString(), style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ))
        ]),
      ),
    );
  }
}

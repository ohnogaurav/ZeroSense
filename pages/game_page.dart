import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/game_state.dart';
import '../services/firebase_service.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final TextEditingController _guessController = TextEditingController();
  StreamSubscription<DatabaseEvent>? _roomSub;
  StreamSubscription<DatabaseEvent>? _playersSub;
  StreamSubscription<DatabaseEvent>? _guessesSub;
  String? roomId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setup());
  }

  void _setup() {
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    roomId = args?['roomId'] as String?;
    if (roomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No roomId')));
      Navigator.pop(context);
      return;
    }

    final firebase = Provider.of<FirebaseService>(context, listen: false);
    final gs = Provider.of<GameState>(context, listen: false);

    // listen root room for state/start/winner
    _roomSub = firebase.listenToRoomRaw(roomId!).listen((ev) {
      final snap = ev.snapshot;
      if (!snap.exists) return;
      final data = Map<String, dynamic>.from(snap.value as Map);
      if (data['startupHint'] != null) {
        gs.setStartupHint(data['startupHint'] as String);
        if (data['state'] == 'running') gs.startGame();
      }
      if (data['winner'] != null) {
        gs.setWinner(data['winner'] as String);
        _showWinner(gs.winner!);
      }
    });

    // players list
    _playersSub = FirebaseDatabase.instance.ref('rooms/$roomId/players').onValue.listen((ev) {
      final snap = ev.snapshot;
      if (!snap.exists) {
        gs.updatePlayers([]);
        return;
      }
      final map = Map<String, dynamic>.from(snap.value as Map);
      final list = map.entries.map((e) => Player.fromMap(e.key, Map<String, dynamic>.from(e.value))).toList();
      gs.updatePlayers(list);
    });

    // guesses list
    _guessesSub = FirebaseDatabase.instance.ref('rooms/$roomId/guesses').onValue.listen((ev) {
      final snap = ev.snapshot;
      if (!snap.exists) {
        gs.updateGuesses([]);
        return;
      }
      final map = Map<String, dynamic>.from(snap.value as Map);
      final list = map.entries.map((e) => Guess.fromMap(Map<String, dynamic>.from(e.value))).toList();
      // sort by ts descending
      list.sort((a, b) => b.ts.compareTo(a.ts));
      gs.updateGuesses(list);
    });
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _playersSub?.cancel();
    _guessesSub?.cancel();
    _guessController.dispose();
    super.dispose();
  }

  void _submitGuess() {
    final text = _guessController.text.trim().toLowerCase();
    if (text.isEmpty) return;
    final gs = Provider.of<GameState>(context, listen: false);
    final firebase = Provider.of<FirebaseService>(context, listen: false);
    firebase.submitGuess(roomId!, gs.username, text);
    _guessController.clear();
  }

  void _requestHint() {
    final gs = Provider.of<GameState>(context, listen: false);
    final firebase = Provider.of<FirebaseService>(context, listen: false);
    firebase.requestHint(roomId!, gs.username);
  }

  void _showWinner(String winnerData) {
    final parts = winnerData.split('|');
    final winnerName = parts[0];
    final secret = parts[1];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(winnerName == Provider.of<GameState>(context, listen: false).username ? 'You Won!' : '$winnerName Won!'),
        content: Text('Secret word: $secret'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
              // no explicit disconnect required
            },
            child: const Text('Back to home'),
          )
        ],
      ),
    );
  }

  Widget _heatChip(int score) {
    if (score == 0) return Chip(label: const Text('WIN'), backgroundColor: Colors.red.shade900, labelStyle: const TextStyle(color: Colors.white));
    if (score <= 5) return Chip(label: const Text('BURNING'), backgroundColor: Colors.red.shade700, labelStyle: const TextStyle(color: Colors.white));
    if (score <= 15) return Chip(label: const Text('HOT'), backgroundColor: Colors.orange.shade700, labelStyle: const TextStyle(color: Colors.white));
    if (score <= 30) return Chip(label: const Text('WARM'), backgroundColor: Colors.yellow.shade800, labelStyle: const TextStyle(color: Colors.white));
    if (score <= 50) return Chip(label: const Text('COLD'), backgroundColor: Colors.blue.shade700, labelStyle: const TextStyle(color: Colors.white));
    return Chip(label: const Text('FROZEN'), backgroundColor: Colors.blue.shade900, labelStyle: const TextStyle(color: Colors.white));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game'),
        automaticallyImplyLeading: false,
      ),
      body: Consumer<GameState>(
        builder: (_, gs, __) {
          if (!gs.gameStarted) {
            return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Waiting for host to start...')]));
          }

          final me = gs.players.firstWhere((p) => p.username == gs.username, orElse: () => Player(uid: 'me', username: gs.username));
          final hintsLeft = 3 - me.hintsUsed;

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(children: [
                      Text('Startup hint: ${gs.startupHint}', style: const TextStyle(fontStyle: FontStyle.italic)),
                      const SizedBox(height: 6),
                      Text('Players: ${gs.players.length}'),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _guessController, decoration: const InputDecoration(labelText: 'Enter guess'), onSubmitted: (_) => _submitGuess())),
                    IconButton(icon: const Icon(Icons.send), onPressed: _submitGuess),
                    IconButton(icon: Badge(label: Text('$hintsLeft'), isLabelVisible: hintsLeft > 0, child: const Icon(Icons.lightbulb_outline)), onPressed: hintsLeft > 0 ? _requestHint : null),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Guesses', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: ListView.builder(
                    itemCount: gs.guesses.length,
                    itemBuilder: (_, i) {
                      final g = gs.guesses[i];
                      if (g.score == -1) {
                        return ListTile(leading: const Icon(Icons.lightbulb, color: Colors.orange), title: Text('Hint: ${g.word}'));
                      }
                      return ListTile(
                        leading: _heatChip(g.score),
                        title: Text('${g.word} (${g.score})'),
                        subtitle: Text('by ${g.username}'),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

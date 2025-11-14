import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/game_state.dart';
import '../services/firebase_service.dart';

class HostPage extends StatefulWidget {
  const HostPage({super.key});

  @override
  State<HostPage> createState() => _HostPageState();
}

class _HostPageState extends State<HostPage> {
  final TextEditingController _secretController = TextEditingController();
  String? _roomId;
  bool _loading = false;

  // ===========================================================
  // CREATE ROOM
  // ===========================================================
  Future<void> _createRoom() async {
    final secret = _secretController.text.trim().toLowerCase();

    if (secret.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a secret word')),
      );
      return;
    }

    setState(() => _loading = true);

    final firebase = Provider.of<FirebaseService>(context, listen: false);
    final gs = Provider.of<GameState>(context, listen: false);

    gs.setUsername("Host");

    try {
      final roomId = await firebase.createRoom(secret);

      setState(() {
        _roomId = roomId;
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room created successfully')),
      );
    } catch (e) {
      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating room: $e')),
      );
    }
  }

  // ===========================================================
  // START GAME
  // ===========================================================
  Future<void> _startGame() async {
    if (_roomId == null) return;

    final firebase = Provider.of<FirebaseService>(context, listen: false);
    final gs = Provider.of<GameState>(context, listen: false);

    await firebase.broadcastStart(_roomId!);

    gs.startGame();        // mark game started locally
    gs.setStartupHint(""); // will auto-update from firebase listener

    Navigator.pushReplacementNamed(
      context,
      "/game",
      arguments: {"mode": "firebase", "roomId": _roomId},
    );
  }

  // ===========================================================
  // UI
  // ===========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Host Online Game")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Enter Secret Word (hidden after creation)",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _secretController,
              decoration: const InputDecoration(
                labelText: "Secret word",
                hintText: "e.g. planet",
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp("[a-zA-Z]")),
              ],
            ),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _createRoom,
              child: const Text("Create Room"),
            ),

            const SizedBox(height: 25),

            if (_roomId != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          "Room ID: $_roomId",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: _roomId!),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Room ID copied"),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              ElevatedButton(
                onPressed: _startGame,
                child: const Text("Start Game"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

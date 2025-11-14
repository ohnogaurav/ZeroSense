import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/game_state.dart';
import '../services/firebase_service.dart';

class JoinPage extends StatefulWidget {
  const JoinPage({super.key});

  @override
  State<JoinPage> createState() => _JoinPageState();
}

class _JoinPageState extends State<JoinPage> {
  final TextEditingController _roomIdController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  bool _isJoining = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Join Online Game"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _firebaseJoinUI(),
      ),
    );
  }

  Widget _firebaseJoinUI() {
    return Column(
      children: [
        const Text(
          "Enter Room ID",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextField(controller: _roomIdController, decoration: const InputDecoration(labelText: "Room ID", hintText: "e.g. AB12CD")),
        const SizedBox(height: 16),
        TextField(controller: _usernameController, decoration: const InputDecoration(labelText: "Username"), maxLength: 15),
        const SizedBox(height: 24),
        _isJoining ? const CircularProgressIndicator() : ElevatedButton(onPressed: _joinFirebaseRoom, child: const Text("Join Room")),
      ],
    );
  }

  Future<void> _joinFirebaseRoom() async {
    final roomId = _roomIdController.text.trim();
    final username = _usernameController.text.trim();

    if (roomId.isEmpty || username.isEmpty) {
      _show("Please fill all fields.");
      return;
    }
    if (username.toLowerCase() == "host") {
      _show("Username 'Host' is reserved.");
      return;
    }

    setState(() => _isJoining = true);

    final firebase = Provider.of<FirebaseService>(context, listen: false);
    final gameState = Provider.of<GameState>(context, listen: false);

    try {
      final success = await firebase.joinRoom(roomId, username);

      if (!success) {
        setState(() => _isJoining = false);
        _show("Room does not exist or has already started.");
        return;
      }

      // Save username locally
      gameState.setUsername(username);

      // Navigate to game page using Firebase mode
      Navigator.pushReplacementNamed(context, "/game", arguments: {"mode": "firebase", "roomId": roomId});
    } catch (e) {
      _show("Error joining room: $e");
      setState(() => _isJoining = false);
    }
  }

  void _show(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

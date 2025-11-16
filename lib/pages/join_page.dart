import 'package:flutter/material.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/fade_slide.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../services/firebase_service.dart';

class JoinPage extends StatefulWidget {
  const JoinPage({super.key});

  @override
  State<JoinPage> createState() => _JoinPageState();
}

class _JoinPageState extends State<JoinPage> {
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _loading = false;

  Future<void> _joinRoom() async {
    final roomId = _roomController.text.trim();
    final username = _nameController.text.trim();
    if (roomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter Room ID')));
      return;
    }
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your name')));
      return;
    }

    setState(() => _loading = true);

    final firebase = Provider.of<FirebaseService>(context, listen: false);
    final gs = Provider.of<GameState>(context, listen: false);

    gs.setUsername(username);

    try {
      final ok = await firebase.joinRoom(roomId, username);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to join. Check room id or game state.')));
        setState(() => _loading = false);
        return;
      }

      Navigator.pushReplacementNamed(
        context,
        "/game",
        arguments: {"mode": "firebase", "roomId": roomId},
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _roomController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,

      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1EC6A4), Color(0xFF0EB686)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 130, 20, 20),
            child: Column(
              children: [
                const FadeSlide(
                  child: Text(
                    "Join a Room",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black26, blurRadius: 10)],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                FadeSlide(
                  child: GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Enter Room ID",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _roomController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Room ID",
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                            border: InputBorder.none,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Your name",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "e.g. Arjun",
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                            border: InputBorder.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                FadeSlide(
                  offsetY: 40,
                  child: GlassButton(
                    text: _loading ? "Joining..." : "Join Room",
                    icon: Icons.login_rounded,
                    onTap: _loading ? () {} : _joinRoom,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

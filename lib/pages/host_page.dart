import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/game_state.dart';
import '../services/firebase_service.dart';
import '../models/words.dart';

class HostPage extends StatefulWidget {
  const HostPage({super.key});

  @override
  State<HostPage> createState() => _HostPageState();
}

class _HostPageState extends State<HostPage> {
  String? _roomId;
  bool _loading = false;

  Future<void> _createRoom() async {
    setState(() => _loading = true);

    final firebase = Provider.of<FirebaseService>(context, listen: false);
    final gs = Provider.of<GameState>(context, listen: false);

    gs.setUsername("Host");

    final secret = randomWords[Random().nextInt(randomWords.length)];

    try {
      final roomId = await firebase.createRoom(secret);

      setState(() {
        _roomId = roomId;
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room created! Secret word auto-generated.')),
      );
    } catch (e) {
      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _startGame() async {
    if (_roomId == null) return;

    final firebase = Provider.of<FirebaseService>(context, listen: false);
    final gs = Provider.of<GameState>(context, listen: false);

    await firebase.broadcastStart(_roomId!);

    gs.startGame();
    gs.setStartupHint("");

    Navigator.pushReplacementNamed(
      context,
      "/game",
      arguments: {"mode": "firebase", "roomId": _roomId},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Host Game",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black26, blurRadius: 8)],
          ),
        ),
      ),

      body: Stack(
        children: [
          // -------------------------------------------------------
          // PREMIUM GRADIENT BACKGROUND
          // -------------------------------------------------------
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6D5DFB), Color(0xFFB84DFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // -------------------------------------------------------
          // CONTENT
          // -------------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 120, 20, 20),
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "A random secret word\nwill be automatically generated.",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 40),

                // ---------------------------------------------------
                // GLASS CREATE ROOM BUTTON
                // ---------------------------------------------------
                _GlassButton(
                  text: "Create Room",
                  icon: Icons.add_circle_outline,
                  onTap: _createRoom,
                ),

                const SizedBox(height: 35),

                // ---------------------------------------------------
                // ROOM CREATED PANEL
                // ---------------------------------------------------
                if (_roomId != null)
                  _GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Room Ready",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "ID: $_roomId",
                                style: const TextStyle(
                                  fontSize: 26,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, color: Colors.white),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _roomId!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Room ID copied")),
                                );
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ---------------------------------------------------
                        // Floating START button
                        // ---------------------------------------------------
                        _GlassButton(
                          text: "Start Game",
                          icon: Icons.play_arrow_rounded,
                          onTap: _startGame,
                        ),
                      ],
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

// ===================================================================
// PREMIUM GLASS BUTTON
// ===================================================================
class _GlassButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;

  const _GlassButton({
    required this.text,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withOpacity(0.18),
          border: Border.all(color: Colors.white30, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 20,
              spreadRadius: 1,
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// GLASS PANEL (Frosted container)
// ===================================================================
class _GlassPanel extends StatelessWidget {
  final Widget child;

  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white30, width: 1.2),
          ),
          child: child,
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/game_state.dart';
import '../services/firebase_service.dart';

import '../widgets/glass_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/fade_slide.dart';
import '../widgets/chat_panel.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with TickerProviderStateMixin {
  final TextEditingController _guessController = TextEditingController();
  String? roomId;

  StreamSubscription<DatabaseEvent>? _roomSub;
  StreamSubscription<DatabaseEvent>? _playersSub;
  StreamSubscription<DatabaseEvent>? _guessesSub;
  StreamSubscription<DatabaseEvent>? _privateHintSub;
  StreamSubscription<DatabaseEvent>? _chatSub;
  StreamSubscription<String>? _aiErrorSub;

  bool _hasUnreadChat = false;
  OverlayEntry? _hintOverlay;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();

    final firebase = Provider.of<FirebaseService>(context, listen: false);

    // Listen to AI errors and show them visually in the app
    _aiErrorSub = firebase.aiErrors.listen((msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        ),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _setup());
  }

  void _setup() {
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    roomId = args?["roomId"] as String?;

    if (roomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No roomId")));
      Navigator.pop(context);
      return;
    }

    final firebase = Provider.of<FirebaseService>(context, listen: false);
    final gs = Provider.of<GameState>(context, listen: false);

    // ROOM LISTENER (state, start, winner)
    _roomSub = firebase.listenToRoomRaw(roomId!).listen((event) {
      final snap = event.snapshot;
      if (!snap.exists) return;

      final data = Map<String, dynamic>.from(snap.value as Map);

      if (data["startupHint"] != null) {
        gs.setStartupHint(data["startupHint"]);
        if (data["state"] == "running") gs.startGame();
      }

      if (data["winner"] != null) {
        gs.setWinner(data["winner"]);
        _showWinner(gs.winner!);
      }
    });

    // PLAYERS
    _playersSub = FirebaseDatabase.instance
        .ref('rooms/$roomId/players')
        .onValue
        .listen((ev) {
      final snap = ev.snapshot;
      if (!snap.exists) {
        gs.updatePlayers([]);
        return;
      }
      final map = Map<String, dynamic>.from(snap.value as Map);
      final players = map.entries
          .map((e) => Player.fromMap(
          e.key, Map<String, dynamic>.from(e.value)))
          .toList();
      gs.updatePlayers(players);
    });

    // GUESSES
    _guessesSub = FirebaseDatabase.instance
        .ref('rooms/$roomId/guesses')
        .onValue
        .listen((ev) {
      final snap = ev.snapshot;
      if (!snap.exists) {
        gs.updateGuesses([]);
        return;
      }
      final map = Map<String, dynamic>.from(snap.value as Map);
      final guesses = map.entries
          .map((e) => Guess.fromMap(
          Map<String, dynamic>.from(e.value)))
          .toList();
      guesses.sort((a, b) => b.ts.compareTo(a.ts));
      gs.updateGuesses(guesses);
    });

    // PRIVATE HINT (user-only)
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid != null) {
      _privateHintSub = FirebaseDatabase.instance
          .ref('rooms/$roomId/private_hints/$myUid')
          .onValue
          .listen((ev) async {
        final snap = ev.snapshot;
        if (!snap.exists) return;
        final data = Map<String, dynamic>.from(snap.value as Map);

        final hintWord = data['word'] ?? '';
        if (hintWord.isNotEmpty) {
          _showHintToast(hintWord);
          await FirebaseDatabase.instance
              .ref('rooms/$roomId/private_hints/$myUid')
              .remove();
        }
      });
    }

    // CHAT LISTENER
    _chatSub = FirebaseDatabase.instance
        .ref('rooms/$roomId/chat')
        .onChildAdded
        .listen((ev) {
      final data = Map<String, dynamic>.from(ev.snapshot.value as Map);
      final username = data['username'] ?? '';
      final myName = Provider.of<GameState>(context, listen: false).username;

      if (username != myName) {
        setState(() => _hasUnreadChat = true);
      }
    });
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _playersSub?.cancel();
    _guessesSub?.cancel();
    _privateHintSub?.cancel();
    _chatSub?.cancel();
    _aiErrorSub?.cancel();

    _guessController.dispose();
    _hideHintOverlay();
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

  Future<void> _giveUp() async {
    final snap = await FirebaseDatabase.instance
        .ref('rooms/$roomId/private/secret')
        .get();

    if (!snap.exists) return;

    final secret = (snap.value as String).toLowerCase();

    await FirebaseDatabase.instance
        .ref('rooms/$roomId')
        .update({'state': 'finished', 'winner': 'GaveUp|$secret'});

    _showWinner('GaveUp|$secret');
  }

  Future<void> _showWinner(String winnerData) async {
    final parts = winnerData.split('|');
    final winner = parts[0];
    final secret = parts[1];

    bool hintFromAI = false;

    try {
      final snap = await FirebaseDatabase.instance
          .ref('rooms/$roomId/startupHintFromAI')
          .get();

      if (snap.exists) hintFromAI = snap.value == true;
    } catch (_) {}

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        title: Text(
          winner == 'GaveUp'
              ? 'Game Over'
              : (winner ==
              Provider.of<GameState>(context, listen: false)
                  .username
              ? 'You Won!'
              : '$winner Won!'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'Secret word: $secret\nHint Source: ${hintFromAI ? "AI" : "Not AI"}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false),
            child: const Text(
              'Back to Home',
              style: TextStyle(color: Colors.cyan),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heatChip(int score) {
    if (score == 0) return _chip('WIN', Colors.green.shade700);
    if (score <= 5) return _chip('🔥 HOT', Colors.orange.shade600);
    if (score <= 15) return _chip('WARM', Colors.yellow.shade800);
    if (score <= 30) return _chip('COLD', Colors.blue.shade600);
    if (score <= 50) return _chip('ICE', Colors.blueGrey.shade700);
    return _chip('FROZEN', Colors.purple.shade700);
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  // ---- HINT TOAST ----
  void _showHintToast(String hintWord) {
    _hideHintOverlay();
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));

    final entry = OverlayEntry(builder: (ctx) {
      return Positioned(
        bottom: 130,
        left: 20,
        right: 20,
        child: FadeTransition(
          opacity: CurvedAnimation(
              parent: controller, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(
                begin: const Offset(0, 0.25), end: Offset.zero)
                .animate(CurvedAnimation(
                parent: controller, curve: Curves.easeOut)),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 14)
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb,
                        color: Colors.amber),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text("Hint: $hintWord",
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16))),
                    TextButton(
                      onPressed: _hideHintOverlay,
                      child: const Text("OK",
                          style: TextStyle(color: Colors.cyan)),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });

    overlay.insert(entry);
    controller.forward();
    _hintOverlay = entry;

    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 4), () {
      _hideHintOverlay();
      controller.dispose();
    });
  }

  void _hideHintOverlay() {
    try {
      _hintOverlay?.remove();
    } catch (_) {}
    _hintOverlay = null;
    _hintTimer?.cancel();
    _hintTimer = null;
  }

  // ---- CHAT POPUP ----
  void _openChat() {
    setState(() => _hasUnreadChat = false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final gs = Provider.of<GameState>(context, listen: false);
        return DraggableScrollableSheet(
          maxChildSize: 0.85,
          initialChildSize: 0.6,
          minChildSize: 0.3,
          builder: (_, scroll) {
            return Container(
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.92),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(22)),
                  border: Border.all(color: Colors.white24)),
              child: Padding(
                padding: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    top: 12,
                    bottom:
                    MediaQuery.of(context).viewInsets.bottom + 12),
                child: ChatPanel(
                    roomId: roomId!, username: gs.username),
              ),
            );
          },
        );
      },
    );
  }

  // ---- UI ----
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,

      floatingActionButton: Stack(
        clipBehavior: Clip.none,
        children: [
          FloatingActionButton(
            backgroundColor: Colors.cyanAccent,
            child: const Icon(Icons.chat_bubble_outline,
                color: Colors.black),
            onPressed: _openChat,
          ),
          if (_hasUnreadChat)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color:
                        Colors.red.withOpacity(0.6),
                        blurRadius: 8)
                  ],
                ),
              ),
            ),
        ],
      ),

      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [
                    Color(0xFF111111),
                    Color(0xFF1C1C1C)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
            ),
          ),

          Consumer<GameState>(
            builder: (_, gs, __) {
              if (!gs.gameStarted) {
                return const Center(
                  child: FadeSlide(
                    child: Column(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                            color: Colors.white),
                        SizedBox(height: 12),
                        Text('Waiting for host...',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 18))
                      ],
                    ),
                  ),
                );
              }

              final me = gs.players.firstWhere(
                      (p) => p.username == gs.username,
                  orElse: () => Player(
                      uid: 'me',
                      username: gs.username,
                      hintsUsed: 0));

              final hintsLeft = 3 - me.hintsUsed;

              return Padding(
                padding: const EdgeInsets.fromLTRB(
                    18, 70, 18, 20),
                child: Column(
                  children: [
                    FadeSlide(
                      child: GlassPanel(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text('Hint: ${gs.startupHint}',
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontStyle:
                                    FontStyle.italic,
                                    fontSize: 16)),
                            const SizedBox(height: 6),
                            Text('Players: ${gs.players.length}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight:
                                    FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    FadeSlide(
                      offsetY: 30,
                      child: GlassPanel(
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller:
                                _guessController,
                                style: const TextStyle(
                                    color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Enter guess...',
                                  hintStyle: const TextStyle(
                                      color:
                                      Colors.white54),
                                  border: InputBorder.none,
                                ),
                                onSubmitted: (_) =>
                                    _submitGuess(),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                  Icons.send_rounded,
                                  color: Colors.cyan),
                              onPressed: _submitGuess,
                            ),
                            IconButton(
                              icon: Stack(
                                alignment:
                                Alignment.topRight,
                                children: [
                                  const Icon(
                                      Icons
                                          .lightbulb_outline,
                                      color: Colors.amber),
                                  if (hintsLeft > 0)
                                    Positioned(
                                      right: -5,
                                      top: -5,
                                      child: Container(
                                        width: 18,
                                        height: 18,
                                        decoration:
                                        const BoxDecoration(
                                          color:
                                          Colors.orange,
                                          shape:
                                          BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '$hintsLeft',
                                            style: const TextStyle(
                                                fontSize:
                                                11,
                                                color: Colors
                                                    .white),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              onPressed: hintsLeft > 0
                                  ? _requestHint
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    FadeSlide(
                      offsetY: 40,
                      child: GlassButton(
                        text: 'Give Up',
                        icon: Icons.flag_rounded,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor:
                              const Color(0xFF1F1F1F),
                              title: const Text('Give up?',
                                  style: TextStyle(
                                      color: Colors.white)),
                              content: const Text(
                                'This will reveal the secret word and end the game.',
                                style: TextStyle(
                                    color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(
                                          context),
                                  child: const Text('Cancel',
                                      style: TextStyle(
                                          color:
                                          Colors.grey)),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _giveUp();
                                  },
                                  child: const Text('Give Up',
                                      style: TextStyle(
                                          color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    const FadeSlide(
                      child: Text('Guesses',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight:
                              FontWeight.bold)),
                    ),

                    const SizedBox(height: 10),

                    Expanded(
                      child: FadeSlide(
                        offsetY: 40,
                        child: ListView.builder(
                          itemCount: gs.guesses.length,
                          itemBuilder: (_, i) {
                            final g = gs.guesses[i];

                            if (g.score == -1) {
                              return ListTile(
                                leading: const Icon(
                                    Icons.lightbulb,
                                    color: Colors.amber),
                                title: Text('Hint: ${g.word}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16)),
                              );
                            }

                            return ListTile(
                              leading: _heatChip(g.score),
                              title: Text(
                                  '${g.word} (${g.score})',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18)),
                              subtitle: Text(
                                  'by ${g.username}',
                                  style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 14)),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          )
        ],
      ),
    );
  }
}

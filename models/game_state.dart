import 'package:flutter/foundation.dart';

class Player {
  final String uid;
  final String username;
  int bestScore;
  int hintsUsed;

  Player({
    required this.uid,
    required this.username,
    this.bestScore = 1000,
    this.hintsUsed = 0,
  });

  factory Player.fromMap(String uid, Map m) {
    return Player(
      uid: uid,
      username: (m['username'] ?? '') as String,
      bestScore: (m['bestScore'] ?? 1000) as int,
      hintsUsed: (m['hintsUsed'] ?? 0) as int,
    );
  }

  Map toMap() => {
    'username': username,
    'bestScore': bestScore,
    'hintsUsed': hintsUsed,
  };
}

class Guess {
  final String username;
  final String word;
  final int score; // -1 for hint
  final int ts;

  Guess({
    required this.username,
    required this.word,
    required this.score,
    required this.ts,
  });

  factory Guess.fromMap(Map m) {
    return Guess(
      username: m['username'] as String,
      word: m['word'] as String,
      score: (m['score'] ?? 100) as int,
      ts: (m['ts'] ?? 0) as int,
    );
  }

  Map toMap() => {
    'username': username,
    'word': word,
    'score': score,
    'ts': ts,
  };
}

class GameState extends ChangeNotifier {
  String username = 'Player';
  String startupHint = '';
  bool gameStarted = false;
  String? winner; // "username|secret"
  List<Player> players = [];
  List<Guess> guesses = [];

  void setUsername(String u) {
    username = u;
    notifyListeners();
  }

  void setStartupHint(String h) {
    startupHint = h;
    notifyListeners();
  }

  void startGame() {
    gameStarted = true;
    notifyListeners();
  }

  void setWinner(String w) {
    winner = w;
    notifyListeners();
  }

  void updatePlayers(List<Player> newList) {
    players = newList;
    notifyListeners();
  }

  void updateGuesses(List<Guess> newGuesses) {
    guesses = newGuesses;
    notifyListeners();
  }

  void reset() {
    username = 'Player';
    startupHint = '';
    gameStarted = false;
    winner = null;
    players = [];
    guesses = [];
    notifyListeners();
  }
}

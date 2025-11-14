import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';


import 'api_service.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final ApiService _api;

  // host processing subscriptions
  StreamSubscription<DatabaseEvent>? _guessesSub;
  StreamSubscription<DatabaseEvent>? _hintReqSub;

  FirebaseService(this._api);

  DatabaseReference roomRef(String roomId) => _db.ref('rooms/$roomId');

  String _makeRoomId() {
    final r = Random();
    final chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<String> createRoom(String secretWord) async {
    await _ensureAuth();
    final uid = _auth.currentUser!.uid;
    final roomId = _makeRoomId();
    final ref = roomRef(roomId);

    await ref.set({
      'hostUid': uid,
      'state': 'lobby',
      'createdAt': ServerValue.timestamp,
      'startupHint': '',
      'private': {'secret': secretWord.toLowerCase()},
      'players': {
        uid: {
          'username': 'Host',
          'bestScore': 1000,
          'hintsUsed': 0,
          'joinedAt': ServerValue.timestamp
        }
      }
    });

    // start host listeners to process guesses/hints in this room
    _attachHostListeners(roomId);

    return roomId;
  }

  Future<bool> joinRoom(String roomId, String username) async {
    await _ensureAuth();
    final uid = _auth.currentUser!.uid;
    final ref = roomRef(roomId);
    final snap = await ref.get();
    if (!snap.exists) return false;
    final state = snap.child('state').value as String? ?? 'lobby';
    if (state != 'lobby') return false;

    await ref.child('players/$uid').set({
      'username': username,
      'bestScore': 1000,
      'hintsUsed': 0,
      'joinedAt': ServerValue.timestamp
    });

    return true;
  }

  Stream<DatabaseEvent> listenToRoomRaw(String roomId) {
    return roomRef(roomId).onValue;
  }

  // client actions
  Future<void> submitGuess(String roomId, String username, String word) async {
    await _ensureAuth();
    final uid = _auth.currentUser!.uid;
    final ref = roomRef(roomId).child('guesses').push();
    await ref.set({
      'uid': uid,
      'username': username,
      'word': word.toLowerCase(),
      'score': -999, // placeholder until host processes
      'processed': false,
      'ts': ServerValue.timestamp,
    });
  }

  Future<void> requestHint(String roomId, String username) async {
    await _ensureAuth();
    final uid = _auth.currentUser!.uid;
    await roomRef(roomId).child('hint_requests').push().set({
      'uid': uid,
      'username': username,
      'ts': ServerValue.timestamp
    });
  }

  Future<void> broadcastStart(String roomId) async {
    final secretSnap = await roomRef(roomId).child('private/secret').get();
    if (!secretSnap.exists) return;
    final secret = (secretSnap.value as String).toLowerCase();
    final hint = await _api.getStartupHint(secret);

    await roomRef(roomId).update({
      'startupHint': hint,
      'state': 'running',
    });

    await roomRef(roomId).child('events').push().set({
      'type': 'START',
      'hint': hint,
      'ts': ServerValue.timestamp
    });
  }

  // host listeners to process guesses/hints
  void _attachHostListeners(String roomId) {
    final room = roomRef(roomId);

    // process guesses
    _guessesSub = room.child('guesses').onChildAdded.listen((event) async {
      final snap = event.snapshot;
      if (!snap.exists) return;
      final data = Map<String, dynamic>.from(snap.value as Map);
      final processed = data['processed'] == true;
      final guessKey = snap.key!;
      if (processed) return;

      final word = (data['word'] as String).toLowerCase();
      final username = data['username'] as String;

      // validate
      if (!RegExp(r'^[a-zA-Z]+$').hasMatch(word)) {
        await room.child('guesses/$guessKey').update({'processed': true, 'score': 100});
        return;
      }

      // compute score via AI
      final secretSnap = await room.child('private/secret').get();
      if (!secretSnap.exists) return;
      final secret = (secretSnap.value as String).toLowerCase();

      int score = 50 + Random().nextInt(40);
      try {
        score = await _api.getScore(secret, word);
      } catch (e) {
        debugPrint('scoring error $e');
      }

      await room.child('guesses/$guessKey').update({
        'score': score,
        'processed': true,
        'scoredAt': ServerValue.timestamp
      });

      // update player's bestScore
      final playersSnap = await room.child('players').get();
      if (playersSnap.exists) {
        final playersMap = Map<String, dynamic>.from(playersSnap.value as Map);
        String targetUid = playersMap.keys.firstWhere((k) {
          final p = Map<String, dynamic>.from(playersMap[k] as Map);
          return (p['username'] as String) == username;
        }, orElse: () => '');
        if (targetUid.isNotEmpty) {
          final currentBest = (playersMap[targetUid]['bestScore'] ?? 1000) as int;
          final newBest = (score >= 0 && score < currentBest) ? score : currentBest;
          await room.child('players/$targetUid').update({'bestScore': newBest});
        }
      }

      // if win
      if (score == 0) {
        await room.update({'state': 'finished', 'winner': '$username|$secret'});
        await room.child('events').push().set({
          'type': 'WINNER',
          'username': username,
          'secretWord': secret,
          'ts': ServerValue.timestamp
        });
      }
    });

    // process hint requests
    _hintReqSub = room.child('hint_requests').onChildAdded.listen((event) async {
      final snap = event.snapshot;
      if (!snap.exists) return;
      final data = Map<String, dynamic>.from(snap.value as Map);
      final targetUid = data['uid'] as String;
      final username = data['username'] as String;

      // find player's best score
      final playerSnap = await room.child('players/$targetUid').get();
      int bestScore = 100;
      if (playerSnap.exists) {
        final p = Map<String, dynamic>.from(playerSnap.value as Map);
        bestScore = (p['bestScore'] ?? 100) as int;
      }

      final secretSnap = await room.child('private/secret').get();
      if (!secretSnap.exists) return;
      final secret = (secretSnap.value as String).toLowerCase();

      String hintWord = 'word';
      try {
        hintWord = await _api.getCloserHint(secret, bestScore);
      } catch (e) {
        debugPrint('hint error $e');
      }

      // publish hint (visible to all as a Hint Bot guess and as event targeted)
      await room.child('guesses').push().set({
        'username': 'Hint Bot',
        'word': hintWord,
        'score': -1,
        'processed': true,
        'ts': ServerValue.timestamp
      });

      await room.child('players/$targetUid').update({
        'hintsUsed': ServerValue.increment(1),
      });

      await room.child('events').push().set({
        'type': 'HINT',
        'hint': hintWord,
        'targetUid': targetUid,
        'ts': ServerValue.timestamp
      });
    });
  }

  Future<void> _ensureAuth() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
  }

  Future<void> disconnectHostListeners() async {
    try {
      await _guessesSub?.cancel();
    } catch (_) {}
    try {
      await _hintReqSub?.cancel();
    } catch (_) {}
  }

  Future<void> disconnectClient() async {
    // nothing to do for client specific in this service
  }
}

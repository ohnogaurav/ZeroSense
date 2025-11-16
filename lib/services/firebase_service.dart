// lib/services/firebase_service.dart
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

  // ai error stream for UI
  final StreamController<String> _aiErrorStream = StreamController<String>.broadcast();
  Stream<String> get aiErrors => _aiErrorStream.stream;

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
      'startupHintFromAI': false,
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

  Future<void> submitGuess(String roomId, String username, String word) async {
    await _ensureAuth();
    final uid = _auth.currentUser!.uid;
    final ref = roomRef(roomId).child('guesses').push();
    await ref.set({
      'uid': uid,
      'username': username,
      'word': word.toLowerCase(),
      'score': -999,
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

  // Chat
  Future<void> sendChatMessage(String roomId, String username, String text) async {
    await _ensureAuth();
    final uid = _auth.currentUser!.uid;

    await roomRef(roomId).child('chat').push().set({
      'uid': uid,
      'username': username,
      'text': text,
      'ts': ServerValue.timestamp,
    });
  }

  // Write a debug event to room/events so you can see raw AI output & errors in Firebase
  Future<void> _pushAiDebugEvent(String roomId, Map<String, dynamic> payload) async {
    try {
      await roomRef(roomId).child('events').push().set(payload);
    } catch (e) {
      // best-effort: avoid blocking main flow
      debugPrint('Failed to write AI debug event: $e');
    }
  }

  // ============================================================
  // START GAME (AI ONLY)
  // ============================================================
  Future<void> broadcastStart(String roomId) async {
    final secretSnap = await roomRef(roomId).child('private/secret').get();
    if (!secretSnap.exists) return;

    final secret = (secretSnap.value as String).toLowerCase();

    final hintRes = await _api.getStartupHint(secret);

    // If AI failed -> record debug event, emit error and block start
    if (!hintRes.fromAI || hintRes.value == null) {
      final errMsg = "AI failed to generate startup hint.";
      debugPrint('AI ERROR: Startup hint failed: ${hintRes.error} raw:${hintRes.raw}');
      _aiErrorStream.add(errMsg);
      await _pushAiDebugEvent(roomId, {
        'type': 'AI_ERROR',
        'stage': 'startup_hint',
        'error': hintRes.error ?? 'unknown',
        'raw': hintRes.raw ?? '',
        'ts': ServerValue.timestamp
      });
      return; // BLOCK START
    }

    final hint = hintRes.value!;
    await roomRef(roomId).update({
      'startupHint': hint,
      'startupHintFromAI': true,
      'state': 'running',
    });

    await roomRef(roomId).child('events').push().set({
      'type': 'START',
      'hint': hint,
      'ts': ServerValue.timestamp
    });
  }

  // ============================================================
  // HOST LISTENERS — AI ONLY PROCESSING
  // ============================================================
  void _attachHostListeners(String roomId) {
    final room = roomRef(roomId);

    // --------- PROCESS GUESSES (AI ONLY) ---------
    _guessesSub = room.child('guesses').onChildAdded.listen((event) async {
      final snap = event.snapshot;
      if (!snap.exists) return;

      final data = Map<String, dynamic>.from(snap.value as Map);
      final processed = data['processed'] == true;
      final guessKey = snap.key!;

      if (processed) return;

      final word = (data['word'] as String).toLowerCase();
      final username = data['username'] as String;

      if (!RegExp(r'^[a-zA-Z]+$').hasMatch(word)) {
        debugPrint('Invalid guess format for $word');
        // mark as processed with a high score (avoid spam)
        await room.child('guesses/$guessKey').update({'processed': true, 'score': 100, 'scoredAt': ServerValue.timestamp});
        return;
      }

      final secretSnap = await room.child('private/secret').get();
      if (!secretSnap.exists) return;
      final secret = (secretSnap.value as String).toLowerCase();

      // Call AI — REQUIRED for scoring
      final scoreRes = await _api.getScore(secret, word);

      if (!scoreRes.fromAI || scoreRes.value == null) {
        final errMsg = "AI failed to score guess: $word";
        debugPrint('AI ERROR scoring: ${scoreRes.error} raw:${scoreRes.raw}');
        _aiErrorStream.add(errMsg);
        await _pushAiDebugEvent(roomId, {
          'type': 'AI_ERROR',
          'stage': 'scoring',
          'guessKey': guessKey,
          'username': username,
          'word': word,
          'error': scoreRes.error ?? 'unknown',
          'raw': scoreRes.raw ?? '',
          'ts': ServerValue.timestamp
        });
        return; // BLOCK GUESS PROCESSING
      }

      final score = scoreRes.value!;

      await room.child('guesses/$guessKey').update({
        'score': score,
        'processed': true,
        'scoredAt': ServerValue.timestamp
      });

      // Update player's best score if improved
      final playersSnap = await room.child('players').get();
      if (playersSnap.exists) {
        final playersMap = Map<String, dynamic>.from(playersSnap.value as Map);

        final targetUid = playersMap.keys.firstWhere(
              (k) => (playersMap[k]['username'] as String) == username,
          orElse: () => '',
        );

        if (targetUid.isNotEmpty) {
          final currentBest = (playersMap[targetUid]['bestScore'] ?? 1000) as int;
          final newBest = (score < currentBest) ? score : currentBest;

          await room.child('players/$targetUid').update({
            'bestScore': newBest,
          });
        }
      }

      // Win condition
      if (score == 0) {
        await room.update({
          'state': 'finished',
          'winner': '$username|$secret'
        });

        await room.child('events').push().set({
          'type': 'WINNER',
          'username': username,
          'secretWord': secret,
          'ts': ServerValue.timestamp
        });
      }
    });

    // --------- PROCESS HINT REQUESTS (AI ONLY) ---------
    _hintReqSub = room.child('hint_requests').onChildAdded.listen((event) async {
      final snap = event.snapshot;
      if (!snap.exists) return;
      final data = Map<String, dynamic>.from(snap.value as Map);
      final targetUid = data['uid'] as String;

      // get player's bestScore
      final playerSnap = await room.child('players/$targetUid').get();
      int bestScore = 100;
      if (playerSnap.exists) {
        final p = Map<String, dynamic>.from(playerSnap.value as Map);
        bestScore = (p['bestScore'] ?? 100) as int;
      }

      final secretSnap = await room.child('private/secret').get();
      if (!secretSnap.exists) return;
      final secret = (secretSnap.value as String).toLowerCase();

      // read used hints map for this user
      final usedSnap = await room.child('private_hints_used/$targetUid').get();
      Map<String, dynamic> usedMap = {};
      if (usedSnap.exists) {
        try {
          usedMap = Map<String, dynamic>.from(usedSnap.value as Map);
        } catch (_) {
          usedMap = {};
        }
      }
      // gather used words set
      final usedWords = usedMap.values.map((v) => (v as String).toLowerCase()).toList();

      // decide which hint number to generate next
      final usedCount = usedWords.length;
      if (usedCount >= 3) {
        // already exhausted hints for this user
        debugPrint('User $targetUid already used 3 hints');
        return;
      }

      // Option A targets (finalized): 50, 25, 10
      final desiredTargets = [50, 25, 10];
      final desiredScore = desiredTargets[usedCount];

      String? chosenHint;
      ApiResult<String>? hintRes;
      int attempts = 0;
      const maxAttempts = 3;

      // try multiple times if API returns an avoided word or parsing fails
      while (attempts < maxAttempts && (chosenHint == null)) {
        attempts += 1;
        try {
          hintRes = await _api.getCloserHint(secret, desiredScore, usedWords);
        } catch (e) {
          hintRes = ApiResult<String>(value: null, fromAI: false, raw: null, error: e.toString());
        }

        if (hintRes == null || !hintRes.fromAI || hintRes.value == null) {
          // AI failed for this attempt
          debugPrint('Attempt $attempts: AI failed to return closer hint: ${hintRes?.error} raw:${hintRes?.raw}');
          // record debug event
          await _pushAiDebugEvent(roomId, {
            'type': 'AI_ERROR',
            'stage': 'closer_hint_attempt',
            'attempt': attempts,
            'targetUid': targetUid,
            'desiredScore': desiredScore,
            'error': hintRes?.error ?? 'null_response',
            'raw': hintRes?.raw ?? '',
            'ts': ServerValue.timestamp
          });
          // continue to next attempt
          continue;
        }

        final candidate = hintRes.value!.toLowerCase().trim();
        if (candidate.isEmpty || usedWords.contains(candidate)) {
          debugPrint('Attempt $attempts: candidate empty or duplicate => $candidate');
          // push debug event and retry
          await _pushAiDebugEvent(roomId, {
            'type': 'AI_WARN',
            'stage': 'closer_hint_duplicate_or_empty',
            'attempt': attempts,
            'targetUid': targetUid,
            'candidate': candidate,
            'desiredScore': desiredScore,
            'raw': hintRes.raw ?? '',
            'ts': ServerValue.timestamp
          });
          continue;
        }

        // Accept candidate
        chosenHint = candidate;
      }

      if (chosenHint == null) {
        final errMsg = "AI failed to generate a fresh hint after $maxAttempts attempts.";
        debugPrint(errMsg);
        _aiErrorStream.add(errMsg);
        await _pushAiDebugEvent(roomId, {
          'type': 'AI_ERROR',
          'stage': 'closer_hint_final_failure',
          'targetUid': targetUid,
          'desiredScore': desiredScore,
          'attempts': attempts,
          'ts': ServerValue.timestamp
        });
        return; // BLOCK HINT
      }

      // write chosen hint to private_hints (delivered to user)
      await room.child('private_hints/$targetUid').set({
        'word': chosenHint,
        'ts': ServerValue.timestamp,
      });

      // store used hint persistently: use keys hint1, hint2, hint3
      final nextIndex = usedWords.length + 1;
      final keyName = 'hint$nextIndex';
      await room.child('private_hints_used/$targetUid/$keyName').set(chosenHint);

      // increment hintsUsed in players
      await room.child('players/$targetUid').update({
        'hintsUsed': ServerValue.increment(1),
      });

      // event for analytics / debug
      await room.child('events').push().set({
        'type': 'HINT_PRIVATE',
        'hint': chosenHint,
        'targetUid': targetUid,
        'desiredScore': desiredScore,
        'attempts': attempts,
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
    try {
      _aiErrorStream.close();
    } catch (_) {}
  }

  Future<void> disconnectClient() async {}
}

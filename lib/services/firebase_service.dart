import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chromashift/core/constants.dart';
import 'package:chromashift/models/room_model.dart';

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUid => _auth.currentUser?.uid;

  Future<String> signInAnonymously() async {
    if (_auth.currentUser != null) return _auth.currentUser!.uid;
    final result = await _auth.signInAnonymously();
    return result.user!.uid;
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Max base64 image size: ~200KB (well within Firestore 1MB doc limit)
  static const int _maxImageDataLength = 200 * 1024;

  Future<String> createRoom(
    int level,
    int seed, {
    int maxPlayers = 10,
    GameMode gameMode = GameMode.colorPuzzle,
    String? imageData,
    int gridSize = 3,
  }) async {
    // --- Input validation ---
    if (level < 1 || level > 20) {
      throw ArgumentError('Level must be between 1 and 20');
    }
    if (maxPlayers < 2 || maxPlayers > 10) {
      throw ArgumentError('Max players must be between 2 and 10');
    }
    if (gridSize < 3 || gridSize > 6) {
      throw ArgumentError('Grid size must be between 3 and 6');
    }
    if (imageData != null && imageData.length > _maxImageDataLength) {
      throw ArgumentError('Image data exceeds maximum size');
    }

    final uid = currentUid!;
    String roomCode;

    // Generate unique room code
    while (true) {
      roomCode = _generateRoomCode();
      final doc = await _firestore.collection('rooms').doc(roomCode).get();
      if (!doc.exists) break;
    }

    final now = DateTime.now();
    final roomData = <String, dynamic>{
      'hostId': uid,
      'status': 'waiting',
      'seed': seed,
      'level': level,
      'maxPlayers': maxPlayers,
      'gameMode': gameMode.name,
      'gridSize': gridSize,
      'createdAt': Timestamp.fromDate(now),
      'countdownStartedAt': null,
      'players': {
        uid: PlayerState(uid: uid, lastHeartbeat: now).toMap(),
      },
    };

    if (imageData != null) {
      roomData['imageData'] = imageData;
    }

    await _firestore.collection('rooms').doc(roomCode).set(roomData);

    return roomCode;
  }

  Future<RoomModel?> joinRoom(String roomCode) async {
    // Validate room code format (6 alphanumeric chars)
    if (roomCode.isEmpty || roomCode.length != 6) return null;
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(roomCode)) return null;

    final uid = currentUid!;
    final docRef = _firestore.collection('rooms').doc(roomCode);

    return _firestore.runTransaction<RoomModel?>((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return null;

      final data = snapshot.data()!;
      final status = data['status'] as String;
      final maxPlayers = data['maxPlayers'] as int? ?? 10;
      final playersMap =
          Map<String, dynamic>.from(data['players'] as Map? ?? {});

      // Room must be waiting and not full
      if (status != 'waiting' || playersMap.length >= maxPlayers) return null;

      // Already in room
      if (playersMap.containsKey(uid)) return null;

      final now = DateTime.now();
      transaction.update(docRef, {
        'players.$uid': PlayerState(uid: uid, lastHeartbeat: now).toMap(),
      });

      // Return updated room
      final updatedData = Map<String, dynamic>.from(data);
      playersMap[uid] = PlayerState(uid: uid, lastHeartbeat: now).toMap();
      updatedData['players'] = playersMap;

      return RoomModel.fromFirestore(roomCode, updatedData);
    });
  }

  static const _validStatuses = {'waiting', 'countdown', 'playing', 'finished'};

  Future<void> setRoomStatus(String roomCode, String status) async {
    if (!_validStatuses.contains(status)) return;
    await _firestore.collection('rooms').doc(roomCode).update({
      'status': status,
    });
  }

  Future<void> updatePlayerState(
    String roomCode,
    String uid, {
    int? moveCount,
    int? elapsedMs,
    bool? solved,
  }) async {
    // Validate: only update your own state
    if (uid != currentUid) return;

    // Validate ranges
    if (moveCount != null && (moveCount < 0 || moveCount > 99999)) return;
    if (elapsedMs != null && (elapsedMs < 0 || elapsedMs > 3600000)) return;

    final updates = <String, dynamic>{};
    if (moveCount != null) updates['players.$uid.moveCount'] = moveCount;
    if (elapsedMs != null) updates['players.$uid.elapsedMs'] = elapsedMs;
    if (solved != null) {
      updates['players.$uid.solved'] = solved;
      if (solved) {
        updates['players.$uid.solvedAt'] = FieldValue.serverTimestamp();
      }
    }

    if (updates.isNotEmpty) {
      await _firestore.collection('rooms').doc(roomCode).update(updates);
    }
  }

  Future<void> markFinished(String roomCode) async {
    await _firestore.collection('rooms').doc(roomCode).update({
      'status': 'finished',
    });
  }

  Future<void> startCountdown(String roomCode) async {
    await _firestore.collection('rooms').doc(roomCode).update({
      'status': 'countdown',
      'countdownStartedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<RoomModel?> watchRoom(String roomCode) {
    return _firestore
        .collection('rooms')
        .doc(roomCode)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return RoomModel.fromFirestore(roomCode, snapshot.data()!);
    });
  }

  Future<void> sendHeartbeat(String roomCode, String uid) async {
    await _firestore.collection('rooms').doc(roomCode).update({
      'players.$uid.connected': true,
      'players.$uid.lastHeartbeat': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setDisconnected(String roomCode, String uid) async {
    await _firestore.collection('rooms').doc(roomCode).update({
      'players.$uid.connected': false,
    });
  }

  Future<void> leaveRoom(String roomCode, String uid) async {
    try {
      await _firestore.collection('rooms').doc(roomCode).update({
        'players.$uid.connected': false,
      });
    } catch (_) {
      // Room may already be deleted
    }
  }
}

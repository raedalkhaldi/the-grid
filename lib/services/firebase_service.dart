import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  Future<String> createRoom(int level, int seed, {int maxPlayers = 10}) async {
    final uid = currentUid!;
    String roomCode;

    // Generate unique room code
    while (true) {
      roomCode = _generateRoomCode();
      final doc = await _firestore.collection('rooms').doc(roomCode).get();
      if (!doc.exists) break;
    }

    final now = DateTime.now();
    await _firestore.collection('rooms').doc(roomCode).set({
      'hostId': uid,
      'status': 'waiting',
      'seed': seed,
      'level': level,
      'maxPlayers': maxPlayers,
      'createdAt': Timestamp.fromDate(now),
      'countdownStartedAt': null,
      'players': {
        uid: PlayerState(uid: uid, lastHeartbeat: now).toMap(),
      },
    });

    return roomCode;
  }

  Future<RoomModel?> joinRoom(String roomCode) async {
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

  Future<void> setRoomStatus(String roomCode, String status) async {
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

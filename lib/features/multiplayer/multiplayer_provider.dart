import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chromashift/core/constants.dart';
import 'package:chromashift/models/room_model.dart';
import 'package:chromashift/services/firebase_service.dart';

final multiplayerProvider =
    StateNotifierProvider<MultiplayerNotifier, MultiplayerState>((ref) {
  return MultiplayerNotifier(ref);
});

/// Stream of all players in the room (ranked), used by game screen leaderboard
final playersStreamProvider =
    StreamProvider.autoDispose<List<PlayerState>>((ref) {
  final mp = ref.watch(multiplayerProvider);
  if (mp.roomCode == null) return Stream.value([]);
  final firebase = ref.read(firebaseServiceProvider);
  return firebase.watchRoom(mp.roomCode!).map((room) {
    if (room == null) return [];
    return room.getRankedPlayers();
  });
});

class MultiplayerNotifier extends StateNotifier<MultiplayerState> {
  final Ref ref;
  StreamSubscription<RoomModel?>? _roomSubscription;
  Timer? _heartbeatTimer;

  MultiplayerNotifier(this.ref) : super(const MultiplayerState());

  Future<void> createRoom(
    int level, {
    GameMode gameMode = GameMode.colorPuzzle,
    String? imageData,
    int gridSize = 3,
  }) async {
    try {
      final firebase = ref.read(firebaseServiceProvider);
      final uid = await firebase.signInAnonymously();
      final seed = Random().nextInt(999999);
      final roomCode = await firebase.createRoom(
        level,
        seed,
        gameMode: gameMode,
        imageData: imageData,
        gridSize: gridSize,
      );

      state = state.copyWith(
        roomCode: roomCode,
        myUid: uid,
        phase: MultiplayerPhase.waiting,
        errorMessage: null,
      );

      _listenToRoom(roomCode);
      _startHeartbeat(roomCode, uid);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to create room: $e');
    }
  }

  Future<void> joinRoom(String roomCode) async {
    try {
      final firebase = ref.read(firebaseServiceProvider);
      final uid = await firebase.signInAnonymously();
      final room = await firebase.joinRoom(roomCode.toUpperCase());

      if (room == null) {
        state = state.copyWith(errorMessage: 'Room not found or full');
        return;
      }

      state = state.copyWith(
        roomCode: roomCode.toUpperCase(),
        myUid: uid,
        room: room,
        phase: MultiplayerPhase.waiting,
        errorMessage: null,
      );

      _listenToRoom(roomCode.toUpperCase());
      _startHeartbeat(roomCode.toUpperCase(), uid);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to join room: $e');
    }
  }

  void _listenToRoom(String roomCode) {
    _roomSubscription?.cancel();
    final firebase = ref.read(firebaseServiceProvider);
    _roomSubscription = firebase.watchRoom(roomCode).listen((room) {
      if (room == null || !mounted) return;

      state = state.copyWith(room: room);

      // Phase transitions
      if (room.status == RoomStatus.countdown &&
          state.phase == MultiplayerPhase.waiting) {
        state = state.copyWith(phase: MultiplayerPhase.countdown);
      }
      if (room.status == RoomStatus.playing &&
          state.phase != MultiplayerPhase.playing) {
        state = state.copyWith(phase: MultiplayerPhase.playing);
      }
      if (room.status == RoomStatus.finished) {
        state = state.copyWith(phase: MultiplayerPhase.finished);
      }
    });
  }

  /// Host starts the countdown (requires >= 2 players)
  Future<void> startCountdown() async {
    if (state.roomCode == null) return;
    final room = state.room;
    if (room == null || room.hostId != state.myUid) return;
    if (room.playerCount < 2) return;

    final firebase = ref.read(firebaseServiceProvider);
    await firebase.startCountdown(state.roomCode!);
  }

  Future<void> startGame() async {
    if (state.roomCode == null) return;
    final firebase = ref.read(firebaseServiceProvider);
    await firebase.setRoomStatus(state.roomCode!, 'playing');
  }

  void syncGameState(int moveCount, int elapsedMs, bool solved) {
    if (state.roomCode == null || state.myUid == null) return;
    final firebase = ref.read(firebaseServiceProvider);
    firebase.updatePlayerState(
      state.roomCode!,
      state.myUid!,
      moveCount: moveCount,
      elapsedMs: elapsedMs,
      solved: solved,
    );

    // Check if all connected players have solved → mark room finished
    if (solved && state.room != null) {
      final allSolved = state.room!.players.values
          .where((p) => p.connected)
          .every((p) => p.solved || p.uid == state.myUid);
      if (allSolved) {
        firebase.markFinished(state.roomCode!);
      }
    }
  }

  /// Player exits mid-game (just mark disconnected, no winner assignment)
  Future<void> exitGame() async {
    if (state.roomCode == null || state.myUid == null) return;
    final firebase = ref.read(firebaseServiceProvider);
    await firebase.setDisconnected(state.roomCode!, state.myUid!);
  }

  void _startHeartbeat(String roomCode, String uid) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        ref.read(firebaseServiceProvider).sendHeartbeat(roomCode, uid);
      }
    });
  }

  Future<void> leaveRoom() async {
    _roomSubscription?.cancel();
    _heartbeatTimer?.cancel();
    if (state.roomCode != null && state.myUid != null) {
      await ref
          .read(firebaseServiceProvider)
          .leaveRoom(state.roomCode!, state.myUid!);
    }
    state = const MultiplayerState();
  }

  void reset() {
    _roomSubscription?.cancel();
    _heartbeatTimer?.cancel();
    state = const MultiplayerState();
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}

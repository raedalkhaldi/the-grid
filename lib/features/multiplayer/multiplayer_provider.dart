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

final opponentStreamProvider = StreamProvider.autoDispose<PlayerState?>((ref) {
  final mp = ref.watch(multiplayerProvider);
  if (mp.roomCode == null || mp.myUid == null) return Stream.value(null);
  final firebase = ref.read(firebaseServiceProvider);
  return firebase.watchRoom(mp.roomCode!).map((room) {
    if (room == null) return null;
    return room.getOpponent(mp.myUid!);
  });
});

class MultiplayerNotifier extends StateNotifier<MultiplayerState> {
  final Ref ref;
  StreamSubscription<RoomModel?>? _roomSubscription;
  Timer? _heartbeatTimer;

  MultiplayerNotifier(this.ref) : super(const MultiplayerState());

  Future<void> createRoom(int level) async {
    try {
      final firebase = ref.read(firebaseServiceProvider);
      final uid = await firebase.signInAnonymously();
      final seed = Random().nextInt(999999);
      final roomCode = await firebase.createRoom(level, seed);

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
        state = state.copyWith(errorMessage: 'Room not found or already full');
        return;
      }

      state = state.copyWith(
        roomCode: roomCode.toUpperCase(),
        myUid: uid,
        room: room,
        phase: MultiplayerPhase.countdown,
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
    if (solved && state.room?.winnerId == null) {
      firebase.setWinner(state.roomCode!, state.myUid!);
    }
  }

  Future<void> forfeit() async {
    if (state.roomCode == null || state.myUid == null) return;
    final firebase = ref.read(firebaseServiceProvider);
    // Set opponent as winner
    final opponent = state.room?.getOpponent(state.myUid!);
    if (opponent != null) {
      await firebase.setWinner(state.roomCode!, opponent.uid);
    }
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chromashift/core/constants.dart';

class PlayerState {
  final String uid;
  final int moveCount;
  final int elapsedMs;
  final bool solved;
  final DateTime? solvedAt;
  final bool connected;
  final DateTime lastHeartbeat;

  const PlayerState({
    required this.uid,
    this.moveCount = 0,
    this.elapsedMs = 0,
    this.solved = false,
    this.solvedAt,
    this.connected = true,
    required this.lastHeartbeat,
  });

  PlayerState copyWith({
    String? uid,
    int? moveCount,
    int? elapsedMs,
    bool? solved,
    DateTime? solvedAt,
    bool? connected,
    DateTime? lastHeartbeat,
  }) {
    return PlayerState(
      uid: uid ?? this.uid,
      moveCount: moveCount ?? this.moveCount,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      solved: solved ?? this.solved,
      solvedAt: solvedAt ?? this.solvedAt,
      connected: connected ?? this.connected,
      lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'moveCount': moveCount,
      'elapsedMs': elapsedMs,
      'solved': solved,
      'solvedAt': solvedAt != null ? Timestamp.fromDate(solvedAt!) : null,
      'connected': connected,
      'lastHeartbeat': Timestamp.fromDate(lastHeartbeat),
    };
  }

  factory PlayerState.fromMap(String uid, Map<String, dynamic> map) {
    return PlayerState(
      uid: uid,
      moveCount: map['moveCount'] as int? ?? 0,
      elapsedMs: map['elapsedMs'] as int? ?? 0,
      solved: map['solved'] as bool? ?? false,
      solvedAt: (map['solvedAt'] as Timestamp?)?.toDate(),
      connected: map['connected'] as bool? ?? true,
      lastHeartbeat:
          (map['lastHeartbeat'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class RoomModel {
  final String roomCode;
  final String hostId;
  final String? guestId;
  final RoomStatus status;
  final int seed;
  final int level;
  final DateTime createdAt;
  final DateTime? countdownStartedAt;
  final String? winnerId;
  final Map<String, PlayerState> players;

  const RoomModel({
    required this.roomCode,
    required this.hostId,
    this.guestId,
    required this.status,
    required this.seed,
    required this.level,
    required this.createdAt,
    this.countdownStartedAt,
    this.winnerId,
    this.players = const {},
  });

  RoomModel copyWith({
    String? roomCode,
    String? hostId,
    String? guestId,
    RoomStatus? status,
    int? seed,
    int? level,
    DateTime? createdAt,
    DateTime? countdownStartedAt,
    String? winnerId,
    Map<String, PlayerState>? players,
  }) {
    return RoomModel(
      roomCode: roomCode ?? this.roomCode,
      hostId: hostId ?? this.hostId,
      guestId: guestId ?? this.guestId,
      status: status ?? this.status,
      seed: seed ?? this.seed,
      level: level ?? this.level,
      createdAt: createdAt ?? this.createdAt,
      countdownStartedAt: countdownStartedAt ?? this.countdownStartedAt,
      winnerId: winnerId ?? this.winnerId,
      players: players ?? this.players,
    );
  }

  PlayerState? getOpponent(String myUid) {
    for (final entry in players.entries) {
      if (entry.key != myUid) return entry.value;
    }
    return null;
  }

  factory RoomModel.fromFirestore(String roomCode, Map<String, dynamic> data) {
    final playersMap = <String, PlayerState>{};
    final rawPlayers = data['players'] as Map<String, dynamic>? ?? {};
    for (final entry in rawPlayers.entries) {
      playersMap[entry.key] =
          PlayerState.fromMap(entry.key, entry.value as Map<String, dynamic>);
    }

    return RoomModel(
      roomCode: roomCode,
      hostId: data['hostId'] as String,
      guestId: data['guestId'] as String?,
      status: RoomStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => RoomStatus.waiting,
      ),
      seed: data['seed'] as int,
      level: data['level'] as int,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      countdownStartedAt:
          (data['countdownStartedAt'] as Timestamp?)?.toDate(),
      winnerId: data['winnerId'] as String?,
      players: playersMap,
    );
  }
}

class MultiplayerState {
  final String? roomCode;
  final String? myUid;
  final RoomModel? room;
  final MultiplayerPhase phase;
  final String? errorMessage;

  const MultiplayerState({
    this.roomCode,
    this.myUid,
    this.room,
    this.phase = MultiplayerPhase.lobby,
    this.errorMessage,
  });

  MultiplayerState copyWith({
    String? roomCode,
    String? myUid,
    RoomModel? room,
    MultiplayerPhase? phase,
    String? errorMessage,
  }) {
    return MultiplayerState(
      roomCode: roomCode ?? this.roomCode,
      myUid: myUid ?? this.myUid,
      room: room ?? this.room,
      phase: phase ?? this.phase,
      errorMessage: errorMessage,
    );
  }
}

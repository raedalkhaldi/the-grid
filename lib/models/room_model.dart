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
  final RoomStatus status;
  final int seed;
  final int level;
  final int maxPlayers;
  final DateTime createdAt;
  final DateTime? countdownStartedAt;
  final Map<String, PlayerState> players;

  const RoomModel({
    required this.roomCode,
    required this.hostId,
    required this.status,
    required this.seed,
    required this.level,
    this.maxPlayers = 10,
    required this.createdAt,
    this.countdownStartedAt,
    this.players = const {},
  });

  int get playerCount => players.length;

  /// Returns all players sorted by rank:
  /// 1. Solved players first (sorted by solvedAt ascending)
  /// 2. Unsolved players after (sorted by moves descending as a proxy for progress)
  List<PlayerState> getRankedPlayers() {
    final solved = players.values.where((p) => p.solved).toList()
      ..sort((a, b) {
        // Primary: earliest solvedAt wins
        final aTime = a.solvedAt ?? DateTime(9999);
        final bTime = b.solvedAt ?? DateTime(9999);
        final cmp = aTime.compareTo(bTime);
        if (cmp != 0) return cmp;
        // Tiebreak: fewer moves wins
        return a.moveCount.compareTo(b.moveCount);
      });

    final unsolved = players.values.where((p) => !p.solved).toList()
      ..sort((a, b) {
        // Connected players rank above disconnected
        if (a.connected != b.connected) return a.connected ? -1 : 1;
        // More moves = more progress
        return b.moveCount.compareTo(a.moveCount);
      });

    return [...solved, ...unsolved];
  }

  /// Returns 1-based rank for the given player uid
  int getMyRank(String uid) {
    final ranked = getRankedPlayers();
    for (int i = 0; i < ranked.length; i++) {
      if (ranked[i].uid == uid) return i + 1;
    }
    return ranked.length;
  }

  RoomModel copyWith({
    String? roomCode,
    String? hostId,
    RoomStatus? status,
    int? seed,
    int? level,
    int? maxPlayers,
    DateTime? createdAt,
    DateTime? countdownStartedAt,
    Map<String, PlayerState>? players,
  }) {
    return RoomModel(
      roomCode: roomCode ?? this.roomCode,
      hostId: hostId ?? this.hostId,
      status: status ?? this.status,
      seed: seed ?? this.seed,
      level: level ?? this.level,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      createdAt: createdAt ?? this.createdAt,
      countdownStartedAt: countdownStartedAt ?? this.countdownStartedAt,
      players: players ?? this.players,
    );
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
      status: RoomStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => RoomStatus.waiting,
      ),
      seed: data['seed'] as int,
      level: data['level'] as int,
      maxPlayers: data['maxPlayers'] as int? ?? 10,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      countdownStartedAt:
          (data['countdownStartedAt'] as Timestamp?)?.toDate(),
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

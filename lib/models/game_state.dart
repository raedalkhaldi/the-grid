import 'package:chromashift/core/constants.dart';
import 'package:chromashift/models/grid_model.dart';

class GameState {
  final GridModel grid;
  final int level;
  final int moveCount;
  final Duration elapsed;
  final GameStatus status;
  final int seed;

  const GameState({
    required this.grid,
    required this.level,
    this.moveCount = 0,
    this.elapsed = Duration.zero,
    this.status = GameStatus.playing,
    required this.seed,
  });

  GameState copyWith({
    GridModel? grid,
    int? level,
    int? moveCount,
    Duration? elapsed,
    GameStatus? status,
    int? seed,
  }) {
    return GameState(
      grid: grid ?? this.grid,
      level: level ?? this.level,
      moveCount: moveCount ?? this.moveCount,
      elapsed: elapsed ?? this.elapsed,
      status: status ?? this.status,
      seed: seed ?? this.seed,
    );
  }
}

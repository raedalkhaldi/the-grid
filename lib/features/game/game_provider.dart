import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chromashift/core/constants.dart';
import 'package:chromashift/models/game_state.dart';
import 'package:chromashift/models/grid_model.dart';
import 'package:chromashift/services/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final gameProvider =
    StateNotifierProvider<GameNotifier, GameState>((ref) {
  return GameNotifier(ref);
});

class GameNotifier extends StateNotifier<GameState> {
  final Ref ref;
  Timer? _timer;

  GameNotifier(this.ref)
      : super(GameState(
          grid: GridModel(level: 1, seed: Random().nextInt(999999)),
          level: 1,
          seed: Random().nextInt(999999),
        ));

  void startLevel(int level, {int? seed}) {
    _timer?.cancel();
    final gameSeed = seed ?? Random().nextInt(999999);
    final grid = GridModel(level: level, seed: gameSeed);

    state = GameState(
      grid: grid,
      level: level,
      seed: gameSeed,
    );

    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (state.status == GameStatus.playing) {
        state = state.copyWith(
          elapsed: state.elapsed + const Duration(milliseconds: 100),
        );
      }
    });
  }

  void makeMove(int index, SwipeDirection direction) {
    if (state.status != GameStatus.playing) return;

    final gridCopy = state.grid.copy();

    if (direction == SwipeDirection.left ||
        direction == SwipeDirection.right) {
      gridCopy.shiftRow(index, direction);
    } else {
      gridCopy.shiftColumn(index, direction);
    }

    final newMoveCount = state.moveCount + 1;
    final isSolved = gridCopy.isSolved();

    state = state.copyWith(
      grid: gridCopy,
      moveCount: newMoveCount,
      status: isSolved ? GameStatus.won : GameStatus.playing,
    );

    if (isSolved) {
      _timer?.cancel();
      _saveProgress();
    }
  }

  void pause() {
    if (state.status == GameStatus.playing) {
      state = state.copyWith(status: GameStatus.paused);
    }
  }

  void resume() {
    if (state.status == GameStatus.paused) {
      state = state.copyWith(status: GameStatus.playing);
    }
  }

  void restart() {
    startLevel(state.level);
  }

  void nextLevel() {
    startLevel(state.level + 1);
  }

  void _saveProgress() {
    final storage = ref.read(storageServiceProvider);
    final nextLevel = state.level + 1;
    final currentSaved = storage.getCurrentLevel();
    if (nextLevel > currentSaved) {
      storage.setCurrentLevel(nextLevel);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

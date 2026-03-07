import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chromashift/core/constants.dart';
import 'package:chromashift/models/image_puzzle_model.dart';

class ImagePuzzleState {
  final ImagePuzzleModel grid;
  final int gridSize;
  final int moveCount;
  final Duration elapsed;
  final GameStatus status;
  final List<ui.Image> tiles;

  const ImagePuzzleState({
    required this.grid,
    required this.gridSize,
    this.moveCount = 0,
    this.elapsed = Duration.zero,
    this.status = GameStatus.playing,
    this.tiles = const [],
  });

  ImagePuzzleState copyWith({
    ImagePuzzleModel? grid,
    int? gridSize,
    int? moveCount,
    Duration? elapsed,
    GameStatus? status,
    List<ui.Image>? tiles,
  }) {
    return ImagePuzzleState(
      grid: grid ?? this.grid,
      gridSize: gridSize ?? this.gridSize,
      moveCount: moveCount ?? this.moveCount,
      elapsed: elapsed ?? this.elapsed,
      status: status ?? this.status,
      tiles: tiles ?? this.tiles,
    );
  }
}

final imagePuzzleProvider =
    StateNotifierProvider<ImagePuzzleNotifier, ImagePuzzleState>((ref) {
  return ImagePuzzleNotifier();
});

class ImagePuzzleNotifier extends StateNotifier<ImagePuzzleState> {
  Timer? _timer;

  ImagePuzzleNotifier()
      : super(ImagePuzzleState(
          grid: ImagePuzzleModel(gridSize: 3, seed: 0),
          gridSize: 3,
        ));

  void startPuzzle(int gridSize, List<ui.Image> tiles) {
    _timer?.cancel();
    final seed = Random().nextInt(999999);
    final grid = ImagePuzzleModel(gridSize: gridSize, seed: seed);

    state = ImagePuzzleState(
      grid: grid,
      gridSize: gridSize,
      tiles: tiles,
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
    final solved = gridCopy.isSolved();

    state = state.copyWith(
      grid: gridCopy,
      moveCount: newMoveCount,
      status: solved ? GameStatus.won : GameStatus.playing,
    );

    if (solved) {
      _timer?.cancel();
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
    _timer?.cancel();
    final seed = Random().nextInt(999999);
    final grid = ImagePuzzleModel(gridSize: state.gridSize, seed: seed);
    state = state.copyWith(
      grid: grid,
      moveCount: 0,
      elapsed: Duration.zero,
      status: GameStatus.playing,
    );
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

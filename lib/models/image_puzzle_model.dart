import 'dart:math';

import 'package:chromashift/core/constants.dart';

class ImagePuzzleModel {
  final int gridSize;
  late List<List<int>> cells; // tile indices (0 to gridSize²-1)
  final int seed;

  ImagePuzzleModel({
    required this.gridSize,
    required this.seed,
    int? scrambleMoves,
  }) {
    _initSolved();
    _scramble(scrambleMoves ?? (gridSize * gridSize * 3));
  }

  ImagePuzzleModel._internal({
    required this.gridSize,
    required this.cells,
    required this.seed,
  });

  ImagePuzzleModel copy() {
    return ImagePuzzleModel._internal(
      gridSize: gridSize,
      cells: cells.map((row) => List<int>.from(row)).toList(),
      seed: seed,
    );
  }

  void _initSolved() {
    cells = List.generate(gridSize, (row) {
      return List.generate(gridSize, (col) {
        return row * gridSize + col;
      });
    });
  }

  void _scramble(int moves) {
    final random = Random(seed);
    for (int i = 0; i < moves; i++) {
      final isRow = random.nextBool();
      final index = random.nextInt(gridSize);
      final forward = random.nextBool();

      if (isRow) {
        shiftRow(index, forward ? SwipeDirection.right : SwipeDirection.left);
      } else {
        shiftColumn(index, forward ? SwipeDirection.down : SwipeDirection.up);
      }
    }

    // Ensure puzzle isn't already solved after scramble
    if (isSolved()) {
      shiftRow(0, SwipeDirection.right);
    }
  }

  void shiftRow(int rowIndex, SwipeDirection direction) {
    if (rowIndex < 0 || rowIndex >= gridSize) return;

    final row = cells[rowIndex];
    if (direction == SwipeDirection.right) {
      final last = row.last;
      for (int i = gridSize - 1; i > 0; i--) {
        row[i] = row[i - 1];
      }
      row[0] = last;
    } else if (direction == SwipeDirection.left) {
      final first = row.first;
      for (int i = 0; i < gridSize - 1; i++) {
        row[i] = row[i + 1];
      }
      row[gridSize - 1] = first;
    }
  }

  void shiftColumn(int colIndex, SwipeDirection direction) {
    if (colIndex < 0 || colIndex >= gridSize) return;

    if (direction == SwipeDirection.down) {
      final last = cells[gridSize - 1][colIndex];
      for (int i = gridSize - 1; i > 0; i--) {
        cells[i][colIndex] = cells[i - 1][colIndex];
      }
      cells[0][colIndex] = last;
    } else if (direction == SwipeDirection.up) {
      final first = cells[0][colIndex];
      for (int i = 0; i < gridSize - 1; i++) {
        cells[i][colIndex] = cells[i + 1][colIndex];
      }
      cells[gridSize - 1][colIndex] = first;
    }
  }

  bool isSolved() {
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        if (cells[row][col] != row * gridSize + col) return false;
      }
    }
    return true;
  }

  int getCell(int row, int col) => cells[row][col];
}

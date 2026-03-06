import 'dart:math';

import 'package:chromashift/core/constants.dart';

class GridModel {
  final int level;
  final int gridSize;
  final int quadrantSize;
  late List<List<int>> cells; // 2D array of color indices (0-3)
  final int seed;

  GridModel({
    required this.level,
    required this.seed,
  })  : gridSize = (level + 1) * 2,
        quadrantSize = level + 1 {
    _initSolved();
    _scramble();
  }

  GridModel._internal({
    required this.level,
    required this.gridSize,
    required this.quadrantSize,
    required this.cells,
    required this.seed,
  });

  /// Create a deep copy
  GridModel copy() {
    return GridModel._internal(
      level: level,
      gridSize: gridSize,
      quadrantSize: quadrantSize,
      cells: cells.map((row) => List<int>.from(row)).toList(),
      seed: seed,
    );
  }

  /// Initialize grid in solved state: each quadrant is one solid color
  void _initSolved() {
    cells = List.generate(gridSize, (row) {
      return List.generate(gridSize, (col) {
        if (row < quadrantSize && col < quadrantSize) return 0; // top-left
        if (row < quadrantSize && col >= quadrantSize) return 1; // top-right
        if (row >= quadrantSize && col < quadrantSize) return 2; // bottom-left
        return 3; // bottom-right
      });
    });
  }

  /// Scramble using seeded random for deterministic results
  void _scramble() {
    final random = Random(seed);
    final totalMoves =
        AppConstants.scrambleBaseMoves + (level * AppConstants.scrambleMovesPerLevel);

    for (int i = 0; i < totalMoves; i++) {
      final isRow = random.nextBool();
      final index = random.nextInt(gridSize);
      final forward = random.nextBool();

      if (isRow) {
        shiftRow(index, forward ? SwipeDirection.right : SwipeDirection.left);
      } else {
        shiftColumn(index, forward ? SwipeDirection.down : SwipeDirection.up);
      }
    }
  }

  /// Shift a row left or right (circular)
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

  /// Shift a column up or down (circular)
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

  /// Check if every quadrant contains only one color
  bool isSolved() {
    // Check each quadrant
    for (int q = 0; q < 4; q++) {
      final startRow = (q < 2) ? 0 : quadrantSize;
      final startCol = (q % 2 == 0) ? 0 : quadrantSize;

      final color = cells[startRow][startCol];
      for (int r = startRow; r < startRow + quadrantSize; r++) {
        for (int c = startCol; c < startCol + quadrantSize; c++) {
          if (cells[r][c] != color) return false;
        }
      }
    }
    return true;
  }

  /// Get the color index at a specific cell
  int getCell(int row, int col) => cells[row][col];
}

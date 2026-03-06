import 'package:flutter_test/flutter_test.dart';
import 'package:chromashift/models/grid_model.dart';

void main() {
  test('Grid initializes with correct size', () {
    final grid = GridModel(level: 1, seed: 42);
    expect(grid.gridSize, 4);
    expect(grid.quadrantSize, 2);
  });

  test('Grid size formula is correct', () {
    expect(GridModel(level: 2, seed: 1).gridSize, 6);
    expect(GridModel(level: 3, seed: 1).gridSize, 8);
    expect(GridModel(level: 5, seed: 1).gridSize, 12);
  });

  test('Same seed produces same grid', () {
    final g1 = GridModel(level: 1, seed: 12345);
    final g2 = GridModel(level: 1, seed: 12345);
    for (int r = 0; r < g1.gridSize; r++) {
      for (int c = 0; c < g1.gridSize; c++) {
        expect(g1.getCell(r, c), g2.getCell(r, c));
      }
    }
  });
}

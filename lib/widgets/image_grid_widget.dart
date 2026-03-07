import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chromashift/core/constants.dart';
import 'package:chromashift/features/image_puzzle/image_puzzle_provider.dart';
import 'package:chromashift/features/settings/settings_provider.dart';

class ImageGridWidget extends ConsumerStatefulWidget {
  const ImageGridWidget({super.key});

  @override
  ConsumerState<ImageGridWidget> createState() => _ImageGridWidgetState();
}

class _ImageGridWidgetState extends ConsumerState<ImageGridWidget>
    with TickerProviderStateMixin {
  final Map<String, AnimationController> _animControllers = {};
  final Map<String, Animation<double>> _animations = {};

  Offset? _swipeStart;
  int? _swipeRow;
  int? _swipeCol;

  @override
  void dispose() {
    for (final c in _animControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onPanStart(DragStartDetails details, double cellSize) {
    final puzzle = ref.read(imagePuzzleProvider);
    if (puzzle.status != GameStatus.playing) return;

    _swipeStart = details.localPosition;
    _swipeRow = (details.localPosition.dy / cellSize).floor();
    _swipeCol = (details.localPosition.dx / cellSize).floor();
  }

  void _onPanEnd(DragEndDetails details, double cellSize) {
    if (_swipeStart == null) return;

    final puzzle = ref.read(imagePuzzleProvider);
    if (puzzle.status != GameStatus.playing) return;

    final velocity = details.velocity.pixelsPerSecond;
    final dx = velocity.dx;
    final dy = velocity.dy;

    SwipeDirection? direction;
    int? index;

    if (dx.abs() > dy.abs() &&
        dx.abs() > AppConstants.swipeVelocityThreshold) {
      direction = dx > 0 ? SwipeDirection.right : SwipeDirection.left;
      index = _swipeRow;
    } else if (dy.abs() > dx.abs() &&
        dy.abs() > AppConstants.swipeVelocityThreshold) {
      direction = dy > 0 ? SwipeDirection.down : SwipeDirection.up;
      index = _swipeCol;
    }

    if (direction != null && index != null) {
      final gridSize = puzzle.gridSize;
      if (index >= 0 && index < gridSize) {
        _animateMove(index, direction, cellSize);
        HapticFeedback.lightImpact();
      }
    }

    _swipeStart = null;
    _swipeRow = null;
    _swipeCol = null;
  }

  void _animateMove(int index, SwipeDirection direction, double cellSize) {
    final settings = ref.read(settingsProvider);
    final isRow =
        direction == SwipeDirection.left || direction == SwipeDirection.right;
    final key = '${isRow ? 'r' : 'c'}_$index';

    _animControllers[key]?.dispose();

    final controller = AnimationController(
      duration: settings.animationDuration,
      vsync: this,
    );

    final isForward =
        direction == SwipeDirection.right || direction == SwipeDirection.down;
    final tween = Tween<double>(
      begin: 0,
      end: isForward ? cellSize : -cellSize,
    );

    _animControllers[key] = controller;
    _animations[key] = tween.animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOut),
    );

    controller.forward().then((_) {
      ref.read(imagePuzzleProvider.notifier).makeMove(index, direction);
      _animControllers[key]?.dispose();
      _animControllers.remove(key);
      _animations.remove(key);
      if (mounted) setState(() {});
    });

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final puzzle = ref.watch(imagePuzzleProvider);
    final grid = puzzle.grid;
    final tiles = puzzle.tiles;
    final gridSize = puzzle.gridSize;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableSize = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final totalSize = availableSize - (AppConstants.gridPadding * 2);
        final cellSize = (totalSize / gridSize)
            .clamp(AppConstants.minCellSize, double.infinity);
        final gridPixelSize = cellSize * gridSize;

        return Center(
          child: GestureDetector(
            onPanStart: (d) => _onPanStart(d, cellSize),
            onPanEnd: (d) => _onPanEnd(d, cellSize),
            child: SizedBox(
              width: gridPixelSize,
              height: gridPixelSize,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // Background
                    Container(color: Colors.black),

                    // Image tiles
                    ...List.generate(gridSize, (row) {
                      return List.generate(gridSize, (col) {
                        final tileIndex = grid.getCell(row, col);

                        double offsetX = 0;
                        double offsetY = 0;

                        final rowKey = 'r_$row';
                        if (_animations.containsKey(rowKey)) {
                          offsetX = _animations[rowKey]!.value;
                        }

                        final colKey = 'c_$col';
                        if (_animations.containsKey(colKey)) {
                          offsetY = _animations[colKey]!.value;
                        }

                        return Positioned(
                          left: col * cellSize + offsetX,
                          top: row * cellSize + offsetY,
                          child: RepaintBoundary(
                            child: Container(
                              width: cellSize - 0.5,
                              height: cellSize - 0.5,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                border: Border.all(
                                  color: Colors.black.withAlpha(40),
                                  width: 0.5,
                                ),
                              ),
                              child: tiles.isNotEmpty &&
                                      tileIndex < tiles.length
                                  ? ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(1.5),
                                      child: RawImage(
                                        image: tiles[tileIndex],
                                        fit: BoxFit.cover,
                                        width: cellSize - 0.5,
                                        height: cellSize - 0.5,
                                      ),
                                    )
                                  : Container(
                                      color: Colors.grey.withAlpha(60),
                                    ),
                            ),
                          ),
                        );
                      });
                    }).expand((e) => e),

                    // Grid lines (subtle)
                    for (int i = 1; i < gridSize; i++) ...[
                      Positioned(
                        left: 0,
                        top: i * cellSize - 0.25,
                        child: Container(
                          width: gridPixelSize,
                          height: 0.5,
                          color: Colors.white.withAlpha(30),
                        ),
                      ),
                      Positioned(
                        left: i * cellSize - 0.25,
                        top: 0,
                        child: Container(
                          width: 0.5,
                          height: gridPixelSize,
                          color: Colors.white.withAlpha(30),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

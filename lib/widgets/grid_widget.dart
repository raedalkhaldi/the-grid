import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chromashift/core/constants.dart';
import 'package:chromashift/features/game/game_provider.dart';
import 'package:chromashift/features/settings/settings_provider.dart';

class GridWidget extends ConsumerStatefulWidget {
  const GridWidget({super.key});

  @override
  ConsumerState<GridWidget> createState() => _GridWidgetState();
}

class _GridWidgetState extends ConsumerState<GridWidget>
    with TickerProviderStateMixin {
  // Track active animation per row/column
  final Map<String, AnimationController> _animControllers = {};
  final Map<String, Animation<double>> _animations = {};

  // Swipe tracking
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
    final game = ref.read(gameProvider);
    if (game.status != GameStatus.playing) return;

    _swipeStart = details.localPosition;
    _swipeRow = (details.localPosition.dy / cellSize).floor();
    _swipeCol = (details.localPosition.dx / cellSize).floor();
  }

  void _onPanEnd(DragEndDetails details, double cellSize) {
    if (_swipeStart == null) return;

    final game = ref.read(gameProvider);
    if (game.status != GameStatus.playing) return;

    final velocity = details.velocity.pixelsPerSecond;
    final dx = velocity.dx;
    final dy = velocity.dy;

    SwipeDirection? direction;
    int? index;

    if (dx.abs() > dy.abs() && dx.abs() > AppConstants.swipeVelocityThreshold) {
      direction = dx > 0 ? SwipeDirection.right : SwipeDirection.left;
      index = _swipeRow;
    } else if (dy.abs() > dx.abs() &&
        dy.abs() > AppConstants.swipeVelocityThreshold) {
      direction = dy > 0 ? SwipeDirection.down : SwipeDirection.up;
      index = _swipeCol;
    }

    if (direction != null && index != null) {
      final gridSize = game.grid.gridSize;
      if (index >= 0 && index < gridSize) {
        _animateMove(index, direction, cellSize);
        HapticFeedback.lightImpact();
      }
    }

    _swipeStart = null;
    _swipeRow = null;
    _swipeCol = null;
  }

  void _onPanUpdate(DragUpdateDetails details, double cellSize) {
    // Could add drag preview here in the future
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
      ref.read(gameProvider.notifier).makeMove(index, direction);
      _animControllers[key]?.dispose();
      _animControllers.remove(key);
      _animations.remove(key);
      if (mounted) setState(() {});
    });

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);
    final settings = ref.watch(settingsProvider);
    final grid = game.grid;
    final colors = settings.activeColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableSize =
            constraints.maxWidth < constraints.maxHeight
                ? constraints.maxWidth
                : constraints.maxHeight;
        final totalSize = availableSize - (AppConstants.gridPadding * 2);
        final cellSize = (totalSize / grid.gridSize)
            .clamp(AppConstants.minCellSize, double.infinity);
        final gridPixelSize = cellSize * grid.gridSize;

        return Center(
          child: GestureDetector(
            onPanStart: (d) => _onPanStart(d, cellSize),
            onPanUpdate: (d) => _onPanUpdate(d, cellSize),
            onPanEnd: (d) => _onPanEnd(d, cellSize),
            child: SizedBox(
              width: gridPixelSize,
              height: gridPixelSize,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // Grid cells
                    ...List.generate(grid.gridSize, (row) {
                      return List.generate(grid.gridSize, (col) {
                        final colorIndex = grid.getCell(row, col);
                        final color = colors[colorIndex];

                        double offsetX = 0;
                        double offsetY = 0;

                        // Apply row animation offset
                        final rowKey = 'r_$row';
                        if (_animations.containsKey(rowKey)) {
                          offsetX = _animations[rowKey]!.value;
                        }

                        // Apply column animation offset
                        final colKey = 'c_$col';
                        if (_animations.containsKey(colKey)) {
                          offsetY = _animations[colKey]!.value;
                        }

                        return Positioned(
                          left: col * cellSize + offsetX,
                          top: row * cellSize + offsetY,
                          child: Container(
                            width: cellSize - 1,
                            height: cellSize - 1,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(
                                cellSize > 30 ? 4 : 2,
                              ),
                            ),
                          ),
                        );
                      });
                    }).expand((e) => e),

                    // Quadrant dividers
                    // Horizontal divider
                    Positioned(
                      left: 0,
                      top: grid.quadrantSize * cellSize -
                          AppConstants.dividerWidth / 2,
                      child: Container(
                        width: gridPixelSize,
                        height: AppConstants.dividerWidth,
                        color: Colors.white.withAlpha(80),
                      ),
                    ),
                    // Vertical divider
                    Positioned(
                      left: grid.quadrantSize * cellSize -
                          AppConstants.dividerWidth / 2,
                      top: 0,
                      child: Container(
                        width: AppConstants.dividerWidth,
                        height: gridPixelSize,
                        color: Colors.white.withAlpha(80),
                      ),
                    ),
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

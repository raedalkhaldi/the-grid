import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chromashift/core/constants.dart';
import 'package:chromashift/features/game/game_provider.dart';
import 'package:chromashift/widgets/grid_widget.dart';
import 'package:chromashift/widgets/game_hud.dart';
import 'package:chromashift/widgets/win_dialog.dart';

class GameScreen extends ConsumerStatefulWidget {
  final int level;

  const GameScreen({super.key, required this.level});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameProvider.notifier).startLevel(widget.level);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ref.read(gameProvider.notifier).pause();
    }
  }

  void _showPauseMenu() {
    ref.read(gameProvider.notifier).pause();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Paused',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(gameProvider.notifier).resume();
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Resume'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF4ECDC4)),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(gameProvider.notifier).restart();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Restart'),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.home_rounded),
            label: const Text('Home'),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);
    final gridSize = game.grid.gridSize;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _showPauseMenu,
                        icon: const Icon(Icons.pause_rounded,
                            color: Colors.white70, size: 28),
                      ),
                      Text(
                        '${gridSize}x$gridSize',
                        style: TextStyle(
                          color: Colors.white.withAlpha(100),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 48), // balance
                    ],
                  ),
                ),

                // HUD
                const GameHud(),

                const SizedBox(height: 16),

                // Grid
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.gridPadding),
                    child: const GridWidget(),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),

            // Win overlay
            if (game.status == GameStatus.won) const WinDialog(),
          ],
        ),
      ),
    );
  }
}

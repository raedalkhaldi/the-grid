import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chromashift/core/constants.dart';
import 'package:chromashift/features/game/game_provider.dart';
import 'package:chromashift/features/multiplayer/multiplayer_provider.dart';
import 'package:chromashift/features/multiplayer/multiplayer_win_dialog.dart';
import 'package:chromashift/models/room_model.dart';
import 'package:chromashift/widgets/grid_widget.dart';
import 'package:chromashift/widgets/game_hud.dart';

class MultiplayerGameScreen extends ConsumerStatefulWidget {
  final int level;
  final int seed;

  const MultiplayerGameScreen({
    super.key,
    required this.level,
    required this.seed,
  });

  @override
  ConsumerState<MultiplayerGameScreen> createState() =>
      _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends ConsumerState<MultiplayerGameScreen>
    with WidgetsBindingObserver {
  Timer? _syncTimer;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(gameProvider.notifier)
          .startLevel(widget.level, seed: widget.seed);
      _startSyncTimer();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final mp = ref.read(multiplayerProvider);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (mp.roomCode != null && mp.myUid != null) {
        ref
            .read(multiplayerProvider.notifier)
            .syncGameState(
              ref.read(gameProvider).moveCount,
              ref.read(gameProvider).elapsed.inMilliseconds,
              ref.read(gameProvider).status == GameStatus.won,
            );
      }
    }
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final game = ref.read(gameProvider);
      ref.read(multiplayerProvider.notifier).syncGameState(
            game.moveCount,
            game.elapsed.inMilliseconds,
            game.status == GameStatus.won,
          );
    });
  }


  Future<void> _showForfeitDialog() async {
    final shouldForfeit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Forfeit?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
        content: const Text(
          'Your opponent will win.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Forfeit'),
          ),
        ],
      ),
    );

    if (shouldForfeit == true && mounted) {
      await ref.read(multiplayerProvider.notifier).forfeit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);
    final mp = ref.watch(multiplayerProvider);
    final opponentAsync = ref.watch(opponentStreamProvider);
    final gridSize = game.grid.gridSize;

    // Listen for game win → sync immediately
    ref.listen(gameProvider, (prev, next) {
      if (prev?.status != GameStatus.won && next.status == GameStatus.won) {
        _syncTimer?.cancel();
        ref.read(multiplayerProvider.notifier).syncGameState(
              next.moveCount,
              next.elapsed.inMilliseconds,
              true,
            );
      }
    });

    // Listen for room finished
    ref.listen(multiplayerProvider, (prev, next) {
      if (next.phase == MultiplayerPhase.finished && !_showResult) {
        setState(() => _showResult = true);
      }
    });

    // Also show result if local player won
    if (game.status == GameStatus.won && !_showResult) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _showResult = true);
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _showForfeitDialog();
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Top bar with forfeit
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: _showForfeitDialog,
                          icon: const Icon(Icons.flag_rounded,
                              color: Colors.redAccent, size: 28),
                        ),
                        Text(
                          '${gridSize}x$gridSize',
                          style: TextStyle(
                            color: Colors.white.withAlpha(100),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),

                  // Opponent status bar
                  opponentAsync.when(
                    data: (opponent) =>
                        _OpponentStatusBar(opponent: opponent),
                    loading: () => const _OpponentStatusBar(opponent: null),
                    error: (_, __) => const _OpponentStatusBar(opponent: null),
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

              // Win/Loss overlay
              if (_showResult)
                MultiplayerWinDialog(
                  isWinner: mp.room?.winnerId == mp.myUid,
                  myMoves: game.moveCount,
                  myTime: game.elapsed,
                  opponent: mp.room?.getOpponent(mp.myUid ?? ''),
                  opponentDisconnected:
                      mp.room?.getOpponent(mp.myUid ?? '')?.connected == false,
                  onHome: () {
                    ref.read(multiplayerProvider.notifier).reset();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpponentStatusBar extends StatelessWidget {
  final PlayerState? opponent;

  const _OpponentStatusBar({required this.opponent});

  String _formatMs(int ms) {
    final d = Duration(milliseconds: ms);
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person_rounded,
            size: 18,
            color: Colors.white.withAlpha(100),
          ),
          const SizedBox(width: 8),
          Text(
            'Opponent',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withAlpha(150),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (opponent == null)
            Text(
              'Connecting...',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withAlpha(60),
              ),
            )
          else ...[
            if (opponent!.solved)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF4ECDC4).withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'SOLVED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4ECDC4),
                  ),
                ),
              )
            else if (!opponent!.connected)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'OFFLINE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Icon(Icons.swipe_rounded,
                size: 14, color: Colors.white.withAlpha(80)),
            const SizedBox(width: 4),
            Text(
              '${opponent!.moveCount}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withAlpha(150),
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.timer_rounded,
                size: 14, color: Colors.white.withAlpha(80)),
            const SizedBox(width: 4),
            Text(
              _formatMs(opponent!.elapsedMs),
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withAlpha(150),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

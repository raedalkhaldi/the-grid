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

  Future<void> _showExitDialog() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Leave Game?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
        content: const Text(
          'You will be marked as disconnected.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (shouldExit == true && mounted) {
      await ref.read(multiplayerProvider.notifier).exitGame();
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);
    final mp = ref.watch(multiplayerProvider);
    final playersAsync = ref.watch(playersStreamProvider);
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
        await _showExitDialog();
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Top bar with leave button
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: _showExitDialog,
                          icon: const Icon(Icons.exit_to_app_rounded,
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

                  // Live leaderboard
                  playersAsync.when(
                    data: (players) => _LiveLeaderboard(
                      players: players,
                      myUid: mp.myUid ?? '',
                    ),
                    loading: () => const _LiveLeaderboard(
                      players: [],
                      myUid: '',
                    ),
                    error: (_, __) => const _LiveLeaderboard(
                      players: [],
                      myUid: '',
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

              // Results overlay
              if (_showResult)
                MultiplayerWinDialog(
                  myUid: mp.myUid ?? '',
                  room: mp.room,
                  myMoves: game.moveCount,
                  myTime: game.elapsed,
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

class _LiveLeaderboard extends StatelessWidget {
  final List<PlayerState> players;
  final String myUid;

  const _LiveLeaderboard({
    required this.players,
    required this.myUid,
  });

  String _formatMs(int ms) {
    final d = Duration(milliseconds: ms);
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return const SizedBox(height: 40);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      constraints: const BoxConstraints(maxHeight: 150),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: players.length,
          itemBuilder: (_, i) {
            final player = players[i];
            final isMe = player.uid == myUid;
            final rank = i + 1;

            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isMe
                    ? const Color(0xFF4ECDC4).withAlpha(15)
                    : Colors.transparent,
                border: i < players.length - 1
                    ? Border(
                        bottom:
                            BorderSide(color: Colors.white.withAlpha(10)))
                    : null,
              ),
              child: Row(
                children: [
                  // Rank
                  SizedBox(
                    width: 24,
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: rank == 1
                            ? Colors.amber
                            : rank == 2
                                ? Colors.grey.shade300
                                : rank == 3
                                    ? Colors.orange.shade300
                                    : Colors.white.withAlpha(100),
                      ),
                    ),
                  ),
                  // Player label
                  Icon(
                    Icons.person_rounded,
                    size: 14,
                    color: isMe
                        ? const Color(0xFF4ECDC4)
                        : Colors.white.withAlpha(80),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      isMe ? 'You' : 'Player',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isMe ? FontWeight.w600 : FontWeight.normal,
                        color: isMe
                            ? const Color(0xFF4ECDC4)
                            : Colors.white.withAlpha(150),
                      ),
                    ),
                  ),
                  // Status badges
                  if (player.solved)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ECDC4).withAlpha(40),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'DONE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4ECDC4),
                        ),
                      ),
                    )
                  else if (!player.connected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withAlpha(40),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'LEFT',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  // Moves
                  Icon(Icons.swipe_rounded,
                      size: 12, color: Colors.white.withAlpha(60)),
                  const SizedBox(width: 3),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${player.moveCount}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withAlpha(140),
                      ),
                    ),
                  ),
                  // Time
                  Icon(Icons.timer_rounded,
                      size: 12, color: Colors.white.withAlpha(60)),
                  const SizedBox(width: 3),
                  Text(
                    _formatMs(player.elapsedMs),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withAlpha(140),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

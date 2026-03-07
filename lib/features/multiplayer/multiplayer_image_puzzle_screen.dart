import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chromashift/core/constants.dart';
import 'package:chromashift/features/image_puzzle/image_puzzle_provider.dart';
import 'package:chromashift/features/multiplayer/multiplayer_provider.dart';
import 'package:chromashift/features/multiplayer/multiplayer_win_dialog.dart';
import 'package:chromashift/models/room_model.dart';
import 'package:chromashift/services/image_slicer.dart';
import 'package:chromashift/widgets/image_grid_widget.dart';

class MultiplayerImagePuzzleScreen extends ConsumerStatefulWidget {
  final int gridSize;
  final int seed;
  final String? imageData;

  const MultiplayerImagePuzzleScreen({
    super.key,
    required this.gridSize,
    required this.seed,
    this.imageData,
  });

  @override
  ConsumerState<MultiplayerImagePuzzleScreen> createState() =>
      _MultiplayerImagePuzzleScreenState();
}

class _MultiplayerImagePuzzleScreenState
    extends ConsumerState<MultiplayerImagePuzzleScreen>
    with WidgetsBindingObserver {
  Timer? _syncTimer;
  bool _showResult = false;
  bool _loading = true;
  ui.Image? _sourceImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAndStart());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAndStart() async {
    if (widget.imageData == null) return;

    // Decode base64 image
    final bytes = base64Decode(widget.imageData!);
    final image = await ImageSlicer.decodeImage(bytes);
    final tiles = await ImageSlicer.slice(image, widget.gridSize);

    if (!mounted) return;

    setState(() {
      _sourceImage = image;
      _loading = false;
    });

    // Start the puzzle with same seed for all players
    ref.read(imagePuzzleProvider.notifier).startPuzzle(
          widget.gridSize,
          tiles,
        );

    _startSyncTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final mp = ref.read(multiplayerProvider);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (mp.roomCode != null && mp.myUid != null) {
        final puzzle = ref.read(imagePuzzleProvider);
        ref.read(multiplayerProvider.notifier).syncGameState(
              puzzle.moveCount,
              puzzle.elapsed.inMilliseconds,
              puzzle.status == GameStatus.won,
            );
      }
    }
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final puzzle = ref.read(imagePuzzleProvider);
      ref.read(multiplayerProvider.notifier).syncGameState(
            puzzle.moveCount,
            puzzle.elapsed.inMilliseconds,
            puzzle.status == GameStatus.won,
          );
    });
  }

  Future<void> _showExitDialog() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final puzzle = ref.watch(imagePuzzleProvider);
    final mp = ref.watch(multiplayerProvider);
    final playersAsync = ref.watch(playersStreamProvider);

    // Listen for puzzle win → sync immediately
    ref.listen(imagePuzzleProvider, (prev, next) {
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
    if (puzzle.status == GameStatus.won && !_showResult) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _showResult = true);
      });
    }

    if (_loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFFFF6B6B),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading image...',
                style: TextStyle(color: Colors.white.withAlpha(120)),
              ),
            ],
          ),
        ),
      );
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
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: _showExitDialog,
                          icon: const Icon(Icons.exit_to_app_rounded,
                              color: Colors.redAccent, size: 28),
                        ),
                        Text(
                          '${widget.gridSize}x${widget.gridSize}',
                          style: TextStyle(
                            color: Colors.white.withAlpha(100),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        // Mini preview
                        if (_sourceImage != null)
                          GestureDetector(
                            onTap: () => _showPreview(),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withAlpha(40),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: RawImage(
                                  image: _sourceImage,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 44),
                      ],
                    ),
                  ),

                  // Live leaderboard
                  playersAsync.when(
                    data: (players) => _CompactLeaderboard(
                      players: players,
                      myUid: mp.myUid ?? '',
                    ),
                    loading: () => const _CompactLeaderboard(
                      players: [],
                      myUid: '',
                    ),
                    error: (_, __) => const _CompactLeaderboard(
                      players: [],
                      myUid: '',
                    ),
                  ),

                  // HUD
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.swipe_rounded,
                                color: Color(0xFFFF6B6B), size: 18),
                            const SizedBox(width: 6),
                            Text(
                              '${puzzle.moveCount}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_rounded,
                                color: Color(0xFFFF6B6B), size: 18),
                            const SizedBox(width: 6),
                            Text(
                              _formatDuration(puzzle.elapsed),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Image grid
                  Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(AppConstants.gridPadding),
                      child: const ImageGridWidget(),
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
                  myMoves: puzzle.moveCount,
                  myTime: puzzle.elapsed,
                  onHome: () {
                    ref.read(multiplayerProvider.notifier).reset();
                    Navigator.of(context)
                        .popUntil((route) => route.isFirst);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPreview() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: RawImage(
            image: _sourceImage,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _CompactLeaderboard extends StatelessWidget {
  final List<PlayerState> players;
  final String myUid;

  const _CompactLeaderboard({
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
    if (players.isEmpty) return const SizedBox(height: 40);

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
                    ? const Color(0xFFFF6B6B).withAlpha(15)
                    : Colors.transparent,
                border: i < players.length - 1
                    ? Border(
                        bottom:
                            BorderSide(color: Colors.white.withAlpha(10)))
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: rank == 1
                            ? Colors.amber
                            : Colors.white.withAlpha(100),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.person_rounded,
                    size: 14,
                    color: isMe
                        ? const Color(0xFFFF6B6B)
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
                            ? const Color(0xFFFF6B6B)
                            : Colors.white.withAlpha(150),
                      ),
                    ),
                  ),
                  if (player.solved)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B6B).withAlpha(40),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'DONE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF6B6B),
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

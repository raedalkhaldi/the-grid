import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:chromashift/core/constants.dart';
import 'package:chromashift/features/multiplayer/multiplayer_provider.dart';
import 'package:chromashift/features/multiplayer/multiplayer_game_screen.dart';
import 'package:chromashift/models/room_model.dart';

class WaitingRoomScreen extends ConsumerStatefulWidget {
  const WaitingRoomScreen({super.key});

  @override
  ConsumerState<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends ConsumerState<WaitingRoomScreen> {
  int _countdown = 3;
  Timer? _countdownTimer;
  bool _navigated = false;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _countdown = 3);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        timer.cancel();
        _startGame();
      }
    });
  }

  Future<void> _startGame() async {
    if (_navigated) return;
    _navigated = true;

    // Host triggers the status change
    final mp = ref.read(multiplayerProvider);
    if (mp.room?.hostId == mp.myUid) {
      await ref.read(multiplayerProvider.notifier).startGame();
    }

    if (!mounted) return;

    final room = ref.read(multiplayerProvider).room;
    if (room == null) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MultiplayerGameScreen(
          level: room.level,
          seed: room.seed,
        ),
      ),
    );
  }

  Future<void> _leaveRoom() async {
    await ref.read(multiplayerProvider.notifier).leaveRoom();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final mp = ref.watch(multiplayerProvider);

    // Listen for phase transitions
    ref.listen<MultiplayerState>(multiplayerProvider, (prev, next) {
      if (prev?.phase != MultiplayerPhase.countdown &&
          next.phase == MultiplayerPhase.countdown) {
        _startCountdown();
      }
      if (next.phase == MultiplayerPhase.playing && !_navigated) {
        _navigated = true;
        final room = next.room;
        if (room != null && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MultiplayerGameScreen(
                level: room.level,
                seed: room.seed,
              ),
            ),
          );
        }
      }
    });

    // If already in countdown when screen loads (guest joining)
    if (mp.phase == MultiplayerPhase.countdown && _countdownTimer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startCountdown());
    }

    final isCountdown = mp.phase == MultiplayerPhase.countdown;
    final roomCode = mp.roomCode ?? '------';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _leaveRoom();
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                if (isCountdown) ...[
                  // Countdown display
                  Text(
                    'GET READY',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withAlpha(180),
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    '$_countdown',
                    style: const TextStyle(
                      fontSize: 96,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4ECDC4),
                    ),
                  ),
                ] else ...[
                  // Waiting display
                  Text(
                    'Waiting for opponent...',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white.withAlpha(180),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Room code
                  Text(
                    'ROOM CODE',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withAlpha(100),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: roomCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Code copied!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF4ECDC4).withAlpha(100),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            roomCode,
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4ECDC4),
                              letterSpacing: 8,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.copy_rounded,
                              color: Colors.white.withAlpha(100)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Share button
                  TextButton.icon(
                    onPressed: () {
                      Share.share(
                        'Join my ChromaShift game! Room code: $roomCode',
                      );
                    },
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share Code'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Loading indicator
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF4ECDC4),
                    ),
                  ),
                ],

                const Spacer(flex: 2),

                if (!isCountdown)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _leaveRoom,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

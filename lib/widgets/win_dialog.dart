import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chromashift/features/game/game_provider.dart';

class WinDialog extends ConsumerStatefulWidget {
  const WinDialog({super.key});

  @override
  ConsumerState<WinDialog> createState() => _WinDialogState();
}

class _WinDialogState extends ConsumerState<WinDialog> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);

    return Stack(
      children: [
        // Dim background
        GestureDetector(
          onTap: () {},
          child: Container(color: Colors.black.withAlpha(180)),
        ),

        // Confetti
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Color(0xFFFF6B6B),
              Color(0xFF4ECDC4),
              Color(0xFFFFE66D),
              Color(0xFF6C5CE7),
              Colors.white,
            ],
            numberOfParticles: 30,
            maxBlastForce: 20,
            minBlastForce: 5,
          ),
        ),

        // Dialog
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF6C5CE7).withAlpha(128),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C5CE7).withAlpha(50),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'SOLVED!',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Level ${game.level}',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withAlpha(180),
                  ),
                ),
                const SizedBox(height: 24),

                // Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatDisplay(
                      icon: Icons.timer_rounded,
                      value: _formatDuration(game.elapsed),
                      label: 'Time',
                    ),
                    _StatDisplay(
                      icon: Icons.swipe_rounded,
                      value: '${game.moveCount}',
                      label: 'Moves',
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ref.read(gameProvider.notifier).nextLevel();
                    },
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Next Level'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ref.read(gameProvider.notifier).restart();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Restart'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withAlpha(50)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatDisplay extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatDisplay({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF4ECDC4), size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withAlpha(128),
          ),
        ),
      ],
    );
  }
}

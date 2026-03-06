import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:chromashift/models/room_model.dart';

class MultiplayerWinDialog extends StatefulWidget {
  final bool isWinner;
  final int myMoves;
  final Duration myTime;
  final PlayerState? opponent;
  final bool opponentDisconnected;
  final VoidCallback onHome;

  const MultiplayerWinDialog({
    super.key,
    required this.isWinner,
    required this.myMoves,
    required this.myTime,
    this.opponent,
    this.opponentDisconnected = false,
    required this.onHome,
  });

  @override
  State<MultiplayerWinDialog> createState() => _MultiplayerWinDialogState();
}

class _MultiplayerWinDialogState extends State<MultiplayerWinDialog> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    if (widget.isWinner) {
      _confettiController.play();
    }
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

  String _formatMs(int ms) {
    return _formatDuration(Duration(milliseconds: ms));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.opponentDisconnected
        ? 'OPPONENT LEFT'
        : widget.isWinner
            ? 'YOU WIN!'
            : 'DEFEATED';
    final titleColor = widget.isWinner || widget.opponentDisconnected
        ? const Color(0xFF4ECDC4)
        : Colors.redAccent;
    final borderColor = widget.isWinner || widget.opponentDisconnected
        ? const Color(0xFF4ECDC4)
        : Colors.redAccent;

    return Stack(
      children: [
        // Dim background
        GestureDetector(
          onTap: () {},
          child: Container(color: Colors.black.withAlpha(180)),
        ),

        // Confetti (only on win)
        if (widget.isWinner)
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
                color: borderColor.withAlpha(128),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: borderColor.withAlpha(50),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                    letterSpacing: 4,
                  ),
                ),

                if (widget.opponentDisconnected) ...[
                  const SizedBox(height: 8),
                  Text(
                    'You win by default',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withAlpha(150),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Your stats
                Text(
                  'YOUR STATS',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withAlpha(100),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatDisplay(
                      icon: Icons.timer_rounded,
                      value: _formatDuration(widget.myTime),
                      label: 'Time',
                    ),
                    _StatDisplay(
                      icon: Icons.swipe_rounded,
                      value: '${widget.myMoves}',
                      label: 'Moves',
                    ),
                  ],
                ),

                // Opponent stats
                if (widget.opponent != null) ...[
                  const SizedBox(height: 20),
                  Divider(color: Colors.white.withAlpha(30)),
                  const SizedBox(height: 12),
                  Text(
                    'OPPONENT',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withAlpha(100),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatDisplay(
                        icon: Icons.timer_rounded,
                        value: _formatMs(widget.opponent!.elapsedMs),
                        label: 'Time',
                      ),
                      _StatDisplay(
                        icon: Icons.swipe_rounded,
                        value: '${widget.opponent!.moveCount}',
                        label: 'Moves',
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 32),

                // Home button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.onHome,
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Home'),
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
        Icon(icon, color: const Color(0xFF4ECDC4), size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withAlpha(128),
          ),
        ),
      ],
    );
  }
}

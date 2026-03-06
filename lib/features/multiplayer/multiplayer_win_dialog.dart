import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:chromashift/models/room_model.dart';

class MultiplayerWinDialog extends StatefulWidget {
  final String myUid;
  final RoomModel? room;
  final int myMoves;
  final Duration myTime;
  final VoidCallback onHome;

  const MultiplayerWinDialog({
    super.key,
    required this.myUid,
    required this.room,
    required this.myMoves,
    required this.myTime,
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
    final rank = widget.room?.getMyRank(widget.myUid) ?? 99;
    if (rank == 1) {
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

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}TH';
    switch (n % 10) {
      case 1:
        return '${n}ST';
      case 2:
        return '${n}ND';
      case 3:
        return '${n}RD';
      default:
        return '${n}TH';
    }
  }

  Color _rankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey.shade300;
      case 3:
        return Colors.orange.shade300;
      default:
        return Colors.white.withAlpha(180);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final myRank = room?.getMyRank(widget.myUid) ?? 1;
    final rankedPlayers = room?.getRankedPlayers() ?? [];
    final isFirst = myRank == 1;
    final borderColor = isFirst ? const Color(0xFF4ECDC4) : _rankColor(myRank);

    return Stack(
      children: [
        // Dim background
        GestureDetector(
          onTap: () {},
          child: Container(color: Colors.black.withAlpha(180)),
        ),

        // Confetti (only 1st place)
        if (isFirst)
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
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxHeight: 480),
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
                // Rank title
                Text(
                  _ordinal(myRank),
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: _rankColor(myRank),
                    letterSpacing: 4,
                  ),
                ),
                Text(
                  'PLACE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _rankColor(myRank).withAlpha(180),
                    letterSpacing: 6,
                  ),
                ),

                const SizedBox(height: 16),

                // Your stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatChip(
                      icon: Icons.timer_rounded,
                      value: _formatDuration(widget.myTime),
                    ),
                    _StatChip(
                      icon: Icons.swipe_rounded,
                      value: '${widget.myMoves} moves',
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Divider(color: Colors.white.withAlpha(30)),
                const SizedBox(height: 8),

                // Leaderboard header
                Text(
                  'LEADERBOARD',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withAlpha(100),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),

                // Rankings list
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: rankedPlayers.length,
                    itemBuilder: (_, i) {
                      final player = rankedPlayers[i];
                      final rank = i + 1;
                      final isMe = player.uid == widget.myUid;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMe
                              ? const Color(0xFF4ECDC4).withAlpha(15)
                              : Colors.white.withAlpha(5),
                          borderRadius: BorderRadius.circular(8),
                          border: isMe
                              ? Border.all(
                                  color:
                                      const Color(0xFF4ECDC4).withAlpha(50))
                              : null,
                        ),
                        child: Row(
                          children: [
                            // Rank number
                            SizedBox(
                              width: 28,
                              child: Text(
                                '$rank',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _rankColor(rank),
                                ),
                              ),
                            ),
                            // Player
                            Expanded(
                              child: Text(
                                isMe ? 'You' : 'Player',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isMe
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isMe
                                      ? const Color(0xFF4ECDC4)
                                      : Colors.white.withAlpha(180),
                                ),
                              ),
                            ),
                            // Status
                            if (player.solved)
                              Text(
                                _formatMs(player.elapsedMs),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withAlpha(150),
                                ),
                              )
                            else if (!player.connected)
                              Text(
                                'LEFT',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent.withAlpha(180),
                                ),
                              )
                            else
                              Text(
                                'DNF',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withAlpha(80),
                                ),
                              ),
                            const SizedBox(width: 12),
                            // Moves
                            Text(
                              '${player.moveCount} mv',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withAlpha(100),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

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

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;

  const _StatChip({
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF4ECDC4), size: 18),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

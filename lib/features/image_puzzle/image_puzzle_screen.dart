import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chromashift/core/constants.dart';
import 'package:chromashift/features/image_puzzle/image_puzzle_provider.dart';
import 'package:chromashift/services/image_slicer.dart';
import 'package:chromashift/widgets/image_grid_widget.dart';

class ImagePuzzleScreen extends ConsumerStatefulWidget {
  const ImagePuzzleScreen({super.key});

  @override
  ConsumerState<ImagePuzzleScreen> createState() => _ImagePuzzleScreenState();
}

class _ImagePuzzleScreenState extends ConsumerState<ImagePuzzleScreen> {
  int _selectedGridSize = 3;
  ui.Image? _sourceImage;
  List<ui.Image>? _tiles;
  bool _loading = false;
  bool _gameStarted = false;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 90,
    );

    if (picked == null) return;

    setState(() => _loading = true);

    final bytes = await picked.readAsBytes();
    final image = await ImageSlicer.decodeImage(bytes);
    final tiles = await ImageSlicer.slice(image, _selectedGridSize);

    if (!mounted) return;

    setState(() {
      _sourceImage = image;
      _tiles = tiles;
      _loading = false;
    });
  }

  void _startGame() {
    if (_tiles == null) return;

    ref
        .read(imagePuzzleProvider.notifier)
        .startPuzzle(_selectedGridSize, _tiles!);

    setState(() => _gameStarted = true);
  }

  void _reslice() async {
    if (_sourceImage == null) return;
    setState(() => _loading = true);

    final tiles = await ImageSlicer.slice(_sourceImage!, _selectedGridSize);

    if (!mounted) return;
    setState(() {
      _tiles = tiles;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_gameStarted) {
      return _GameView(
        sourceImage: _sourceImage,
        onBack: () {
          setState(() => _gameStarted = false);
        },
      );
    }

    return _SetupView(
      selectedGridSize: _selectedGridSize,
      sourceImage: _sourceImage,
      tiles: _tiles,
      loading: _loading,
      onGridSizeChanged: (size) {
        setState(() => _selectedGridSize = size);
        if (_sourceImage != null) _reslice();
      },
      onPickGallery: () => _pickImage(ImageSource.gallery),
      onPickCamera: () => _pickImage(ImageSource.camera),
      onStart: _startGame,
    );
  }
}

// --- Setup View (image picker + preview) ---

class _SetupView extends StatelessWidget {
  final int selectedGridSize;
  final ui.Image? sourceImage;
  final List<ui.Image>? tiles;
  final bool loading;
  final ValueChanged<int> onGridSizeChanged;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final VoidCallback onStart;

  const _SetupView({
    required this.selectedGridSize,
    this.sourceImage,
    this.tiles,
    required this.loading,
    required this.onGridSizeChanged,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Puzzle'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // Grid size selector
              Text(
                'Grid Size',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withAlpha(180),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [3, 4, 5].map((size) {
                  final selected = size == selectedGridSize;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      label: Text('${size}x$size'),
                      selected: selected,
                      onSelected: (_) => onGridSizeChanged(size),
                      selectedColor: const Color(0xFFFF6B6B),
                      backgroundColor: Colors.white.withAlpha(15),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 28),

              // Image preview or picker
              if (loading)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: Color(0xFFFF6B6B),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Slicing image...',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                )
              else if (sourceImage != null) ...[
                // Preview
                Expanded(
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: RawImage(
                        image: sourceImage,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Change image
                TextButton.icon(
                  onPressed: onPickGallery,
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Change Image'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white54,
                  ),
                ),
              ] else ...[
                // Pick image buttons
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.image_rounded,
                          size: 80,
                          color: Colors.white.withAlpha(40),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Choose a photo to puzzle',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withAlpha(120),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _PickerButton(
                              icon: Icons.photo_library_rounded,
                              label: 'Gallery',
                              onTap: onPickGallery,
                            ),
                            const SizedBox(width: 20),
                            _PickerButton(
                              icon: Icons.camera_alt_rounded,
                              label: 'Camera',
                              onTap: onPickCamera,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Start button
              if (sourceImage != null && !loading)
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text(
                      'Start Puzzle',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B6B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFFF6B6B), size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withAlpha(150),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Game View ---

class _GameView extends ConsumerWidget {
  final ui.Image? sourceImage;
  final VoidCallback onBack;

  const _GameView({
    this.sourceImage,
    required this.onBack,
  });

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final puzzle = ref.watch(imagePuzzleProvider);
    final gridSize = puzzle.gridSize;

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
                        onPressed: () {
                          if (puzzle.status == GameStatus.won) {
                            onBack();
                          } else {
                            _showExitDialog(context, ref);
                          }
                        },
                        icon: const Icon(Icons.arrow_back_rounded,
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
                      // Mini preview
                      if (sourceImage != null)
                        GestureDetector(
                          onTap: () => _showPreview(context),
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
                                image: sourceImage,
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

                // HUD (moves + time)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _HudItem(
                        icon: Icons.swipe_rounded,
                        value: '${puzzle.moveCount}',
                        label: 'Moves',
                      ),
                      _HudItem(
                        icon: Icons.timer_rounded,
                        value: _formatDuration(puzzle.elapsed),
                        label: 'Time',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Grid
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.gridPadding),
                    child: const ImageGridWidget(),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),

            // Win overlay
            if (puzzle.status == GameStatus.won)
              _WinOverlay(
                moves: puzzle.moveCount,
                time: puzzle.elapsed,
                sourceImage: sourceImage,
                onHome: onBack,
                onRestart: () {
                  ref.read(imagePuzzleProvider.notifier).restart();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showExitDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Leave Puzzle?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 22),
        ),
        content: const Text(
          'Your progress will be lost.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onBack();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _showPreview(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: RawImage(
            image: sourceImage,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _HudItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _HudItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFFF6B6B), size: 18),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withAlpha(100),
          ),
        ),
      ],
    );
  }
}

class _WinOverlay extends StatelessWidget {
  final int moves;
  final Duration time;
  final ui.Image? sourceImage;
  final VoidCallback onHome;
  final VoidCallback onRestart;

  const _WinOverlay({
    required this.moves,
    required this.time,
    this.sourceImage,
    required this.onHome,
    required this.onRestart,
  });

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withAlpha(180),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFFF6B6B).withAlpha(128),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B6B).withAlpha(40),
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
                  color: Color(0xFFFF6B6B),
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 20),

              // Completed image preview
              if (sourceImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 140,
                    height: 140,
                    child: RawImage(
                      image: sourceImage,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      const Icon(Icons.timer_rounded,
                          color: Color(0xFFFF6B6B), size: 22),
                      const SizedBox(height: 4),
                      Text(
                        _formatDuration(time),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Time',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withAlpha(100),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Icon(Icons.swipe_rounded,
                          color: Color(0xFFFF6B6B), size: 22),
                      const SizedBox(height: 4),
                      Text(
                        '$moves',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Moves',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withAlpha(100),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 28),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRestart,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Again'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(
                            color: Colors.white.withAlpha(50)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onHome,
                      icon: const Icon(Icons.home_rounded),
                      label: const Text('Home'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

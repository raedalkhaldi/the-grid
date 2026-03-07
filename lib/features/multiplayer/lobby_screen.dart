import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chromashift/core/constants.dart';
import 'package:chromashift/features/game/game_provider.dart';
import 'package:chromashift/features/multiplayer/multiplayer_provider.dart';
import 'package:chromashift/features/multiplayer/waiting_room_screen.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  final _codeController = TextEditingController();
  int _selectedLevel = 1;
  int _selectedGridSize = 3;
  GameMode _gameMode = GameMode.colorPuzzle;
  Uint8List? _imageBytes;
  bool _isCreating = false;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    final storage = ref.read(storageServiceProvider);
    _selectedLevel = storage.getCurrentLevel().clamp(1, 99);
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 500,
      maxHeight: 500,
      imageQuality: 70,
    );

    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() => _imageBytes = bytes);
  }

  Future<void> _createRoom() async {
    if (_gameMode == GameMode.imagePuzzle && _imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick an image first')),
      );
      return;
    }

    setState(() => _isCreating = true);

    String? imageData;
    if (_gameMode == GameMode.imagePuzzle && _imageBytes != null) {
      imageData = base64Encode(_imageBytes!);
    }

    await ref.read(multiplayerProvider.notifier).createRoom(
          _selectedLevel,
          gameMode: _gameMode,
          imageData: imageData,
          gridSize: _selectedGridSize,
        );
    if (!mounted) return;

    final mp = ref.read(multiplayerProvider);
    if (mp.errorMessage != null) {
      setState(() => _isCreating = false);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WaitingRoomScreen()),
    );
    setState(() => _isCreating = false);
  }

  Future<void> _joinRoom() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a 6-character room code')),
      );
      return;
    }

    setState(() => _isJoining = true);
    await ref.read(multiplayerProvider.notifier).joinRoom(code);
    if (!mounted) return;

    final mp = ref.read(multiplayerProvider);
    if (mp.errorMessage != null) {
      setState(() => _isJoining = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mp.errorMessage!)),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WaitingRoomScreen()),
    );
    setState(() => _isJoining = false);
  }

  @override
  Widget build(BuildContext context) {
    final isImageMode = _gameMode == GameMode.imagePuzzle;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Multiplayer'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // Game mode toggle
              Text(
                'Game Mode',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withAlpha(180),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ModeButton(
                      icon: Icons.grid_view_rounded,
                      label: 'Colors',
                      selected: !isImageMode,
                      color: const Color(0xFF4ECDC4),
                      onTap: () =>
                          setState(() => _gameMode = GameMode.colorPuzzle),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ModeButton(
                      icon: Icons.image_rounded,
                      label: 'Image',
                      selected: isImageMode,
                      color: const Color(0xFFFF6B6B),
                      onTap: () =>
                          setState(() => _gameMode = GameMode.imagePuzzle),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Mode-specific options
              if (isImageMode) ...[
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
                    final selected = size == _selectedGridSize;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text('${size}x$size'),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _selectedGridSize = size),
                        selectedColor: const Color(0xFFFF6B6B),
                        backgroundColor: Colors.white.withAlpha(15),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // Image picker
                if (_imageBytes != null)
                  Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _imageBytes!,
                          height: 150,
                          width: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                        label: const Text('Change'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white54,
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PickerChip(
                        icon: Icons.photo_library_rounded,
                        label: 'Gallery',
                        onTap: () => _pickImage(ImageSource.gallery),
                      ),
                      const SizedBox(width: 16),
                      _PickerChip(
                        icon: Icons.camera_alt_rounded,
                        label: 'Camera',
                        onTap: () => _pickImage(ImageSource.camera),
                      ),
                    ],
                  ),
              ] else ...[
                // Level selector (color puzzle)
                Text(
                  'Select Level',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withAlpha(180),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 10,
                    itemBuilder: (_, i) {
                      final level = i + 1;
                      final gridSize = (level + 1) * 2;
                      final selected = level == _selectedLevel;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('$level (${gridSize}x$gridSize)'),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _selectedLevel = level),
                          selectedColor: const Color(0xFF4ECDC4),
                          backgroundColor: Colors.white.withAlpha(15),
                          labelStyle: TextStyle(
                            color: selected ? Colors.black : Colors.white70,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Create room button
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isCreating ? null : _createRoom,
                  icon: _isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_rounded),
                  label: Text(
                    _isCreating ? 'Creating...' : 'Create Room',
                    style: const TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isImageMode
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFF4ECDC4),
                    foregroundColor: isImageMode ? Colors.white : Colors.black,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Divider
              Row(
                children: [
                  Expanded(
                    child: Divider(color: Colors.white.withAlpha(50)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        color: Colors.white.withAlpha(100),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(color: Colors.white.withAlpha(50)),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Join room
              Text(
                'Join a Room',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withAlpha(180),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(6),
                ],
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'ABCDEF',
                  hintStyle: TextStyle(
                    color: Colors.white.withAlpha(30),
                    letterSpacing: 8,
                  ),
                  filled: true,
                  fillColor: Colors.white.withAlpha(10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.white.withAlpha(30)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.white.withAlpha(30)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF4ECDC4)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _isJoining ? null : _joinRoom,
                  icon: _isJoining
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login_rounded),
                  label: Text(
                    _isJoining ? 'Joining...' : 'Join Room',
                    style: const TextStyle(fontSize: 18),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white.withAlpha(50)),
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

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(30) : Colors.white.withAlpha(8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color.withAlpha(150) : Colors.white.withAlpha(20),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? color : Colors.white54, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? color : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFFF6B6B), size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withAlpha(150),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

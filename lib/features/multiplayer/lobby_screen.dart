import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  Future<void> _createRoom() async {
    setState(() => _isCreating = true);
    await ref.read(multiplayerProvider.notifier).createRoom(_selectedLevel);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multiplayer'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              // Level selector
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
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 32),

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
                    backgroundColor: const Color(0xFF4ECDC4),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),

              const SizedBox(height: 32),

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

              const SizedBox(height: 32),

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
            ],
          ),
        ),
      ),
    );
  }
}

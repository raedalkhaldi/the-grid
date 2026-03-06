import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chromashift/core/constants.dart';
import 'package:chromashift/features/game/game_provider.dart';
import 'package:chromashift/features/multiplayer/lobby_screen.dart';
import 'package:chromashift/features/settings/settings_screen.dart';
import 'package:chromashift/features/solo/game_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.read(storageServiceProvider);
    final currentLevel = storage.getCurrentLevel();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Logo / Title
              const _AnimatedTitle(),

              const SizedBox(height: 12),
              Text(
                'Color-sorting puzzle game',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withAlpha(128),
                  letterSpacing: 1,
                ),
              ),

              const Spacer(flex: 2),

              // Play button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GameScreen(level: currentLevel),
                      ),
                    );
                  },
                  child: Text(
                    currentLevel == 1
                        ? 'Play'
                        : 'Continue (Level $currentLevel)',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Multiplayer
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LobbyScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.people_rounded),
                  label: const Text(
                    'Multiplayer',
                    style: TextStyle(fontSize: 20),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECDC4),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Level select
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () => _showLevelPicker(context, currentLevel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white.withAlpha(50)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Select Level',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Settings
              SizedBox(
                width: double.infinity,
                height: 56,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text(
                    'Settings',
                    style: TextStyle(fontSize: 18),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white54,
                  ),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  void _showLevelPicker(BuildContext context, int maxLevel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Level',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 250,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: maxLevel + 5, // show a few locked levels ahead
                  itemBuilder: (_, i) {
                    final level = i + 1;
                    final unlocked = level <= maxLevel;
                    final gridSize = (level + 1) * 2;

                    return GestureDetector(
                      onTap: unlocked
                          ? () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GameScreen(level: level),
                                ),
                              );
                            }
                          : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color: unlocked
                              ? const Color(0xFF6C5CE7).withAlpha(50)
                              : Colors.white.withAlpha(10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: unlocked
                                ? const Color(0xFF6C5CE7).withAlpha(100)
                                : Colors.white.withAlpha(20),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!unlocked)
                              Icon(Icons.lock_rounded,
                                  size: 16,
                                  color: Colors.white.withAlpha(50)),
                            Text(
                              '$level',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: unlocked
                                    ? Colors.white
                                    : Colors.white.withAlpha(50),
                              ),
                            ),
                            Text(
                              '${gridSize}x$gridSize',
                              style: TextStyle(
                                fontSize: 10,
                                color: unlocked
                                    ? Colors.white.withAlpha(128)
                                    : Colors.white.withAlpha(30),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedTitle extends StatefulWidget {
  const _AnimatedTitle();

  @override
  State<_AnimatedTitle> createState() => _AnimatedTitleState();
}

class _AnimatedTitleState extends State<_AnimatedTitle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (_, __) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                AppConstants.defaultColors[0],
                AppConstants.defaultColors[1],
                AppConstants.defaultColors[2],
                AppConstants.defaultColors[3],
              ],
            ).createShader(bounds);
          },
          child: const Text(
            'CHROMASHIFT',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 4,
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chromashift/core/constants.dart';
import 'package:chromashift/features/settings/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Sound
          _SettingsTile(
            icon: Icons.volume_up_rounded,
            title: 'Sound Effects',
            trailing: Switch.adaptive(
              value: settings.soundEnabled,
              onChanged: (_) =>
                  ref.read(settingsProvider.notifier).toggleSound(),
              activeColor: const Color(0xFF6C5CE7),
            ),
          ),

          const SizedBox(height: 16),

          // Animation speed
          _SettingsTile(
            icon: Icons.speed_rounded,
            title: 'Animation Speed',
            trailing: SegmentedButton<AnimationSpeedSetting>(
              segments: const [
                ButtonSegment(
                  value: AnimationSpeedSetting.slow,
                  label: Text('Slow'),
                ),
                ButtonSegment(
                  value: AnimationSpeedSetting.medium,
                  label: Text('Med'),
                ),
                ButtonSegment(
                  value: AnimationSpeedSetting.fast,
                  label: Text('Fast'),
                ),
              ],
              selected: {settings.animationSpeed},
              onSelectionChanged: (s) => ref
                  .read(settingsProvider.notifier)
                  .setAnimationSpeed(s.first),
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return Colors.white54;
                }),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFF6C5CE7);
                  }
                  return Colors.white.withAlpha(10);
                }),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Colors
          const Text(
            'Quadrant Colors',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (index) {
              final color = settings.activeColors[index];
              return GestureDetector(
                onTap: () => _showColorPicker(context, ref, index, color),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withAlpha(50),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.edit, color: Colors.white54, size: 20),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 12),

          if (settings.customColors.isNotEmpty)
            Center(
              child: TextButton(
                onPressed: () =>
                    ref.read(settingsProvider.notifier).resetColors(),
                child: const Text(
                  'Reset to Default Colors',
                  style: TextStyle(color: Color(0xFF4ECDC4)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showColorPicker(
      BuildContext context, WidgetRef ref, int index, Color current) {
    final presetColors = [
      const Color(0xFFFF6B6B),
      const Color(0xFFFF8E53),
      const Color(0xFFFFE66D),
      const Color(0xFF51CF66),
      const Color(0xFF4ECDC4),
      const Color(0xFF339AF0),
      const Color(0xFF6C5CE7),
      const Color(0xFFCC5DE8),
      const Color(0xFFFF6B9D),
      const Color(0xFFE8590C),
      const Color(0xFF20C997),
      const Color(0xFF845EF7),
    ];

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
              Text(
                'Quadrant ${index + 1} Color',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: presetColors.map((color) {
                  final isSelected = color.toARGB32() == current.toARGB32();
                  return GestureDetector(
                    onTap: () {
                      ref
                          .read(settingsProvider.notifier)
                          .setCustomColor(index, color);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 24),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }
}

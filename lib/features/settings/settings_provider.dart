import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chromashift/core/constants.dart';
import 'package:chromashift/features/game/game_provider.dart';
import 'package:chromashift/models/settings_model.dart';

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsModel>((ref) {
  return SettingsNotifier(ref);
});

class SettingsNotifier extends StateNotifier<SettingsModel> {
  final Ref ref;

  SettingsNotifier(this.ref) : super(const SettingsModel());

  void loadFromStorage() {
    final storage = ref.read(storageServiceProvider);
    state = storage.loadSettings();
  }

  void toggleSound() {
    state = state.copyWith(soundEnabled: !state.soundEnabled);
    _save();
  }

  void setAnimationSpeed(AnimationSpeedSetting speed) {
    state = state.copyWith(animationSpeed: speed);
    _save();
  }

  void setCustomColor(int index, Color color) {
    final colors = List<Color>.from(
      state.customColors.isEmpty
          ? AppConstants.defaultColors
          : state.customColors,
    );
    colors[index] = color;
    state = state.copyWith(customColors: colors);
    _save();
  }

  void resetColors() {
    state = state.copyWith(customColors: []);
    _save();
  }

  void _save() {
    final storage = ref.read(storageServiceProvider);
    storage.saveSettings(state);
  }
}

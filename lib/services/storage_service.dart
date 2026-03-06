import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chromashift/core/constants.dart';
import 'package:chromashift/models/settings_model.dart';

class StorageService {
  static const _keyCurrentLevel = 'current_level';
  static const _keySoundEnabled = 'sound_enabled';
  static const _keyAnimationSpeed = 'animation_speed';
  static const _keyCustomColors = 'custom_colors';

  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Level
  int getCurrentLevel() => _prefs.getInt(_keyCurrentLevel) ?? 1;
  Future<void> setCurrentLevel(int level) =>
      _prefs.setInt(_keyCurrentLevel, level);

  // Settings
  SettingsModel loadSettings() {
    final soundEnabled = _prefs.getBool(_keySoundEnabled) ?? true;
    final speedIndex = _prefs.getInt(_keyAnimationSpeed) ?? 1;
    final colorStrings = _prefs.getStringList(_keyCustomColors);

    List<Color> customColors = [];
    if (colorStrings != null && colorStrings.length == 4) {
      customColors = colorStrings
          .map((s) => Color(int.parse(s)))
          .toList();
    }

    return SettingsModel(
      soundEnabled: soundEnabled,
      animationSpeed: AnimationSpeedSetting.values[speedIndex],
      customColors: customColors,
    );
  }

  Future<void> saveSettings(SettingsModel settings) async {
    await _prefs.setBool(_keySoundEnabled, settings.soundEnabled);
    await _prefs.setInt(
        _keyAnimationSpeed, settings.animationSpeed.index);
    if (settings.customColors.isNotEmpty) {
      await _prefs.setStringList(
        _keyCustomColors,
        settings.customColors.map((c) => c.toARGB32().toString()).toList(),
      );
    } else {
      await _prefs.remove(_keyCustomColors);
    }
  }
}

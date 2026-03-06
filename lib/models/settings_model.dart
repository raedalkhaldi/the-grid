import 'package:flutter/material.dart';
import 'package:chromashift/core/constants.dart';

class SettingsModel {
  final bool soundEnabled;
  final AnimationSpeedSetting animationSpeed;
  final List<Color> customColors;

  const SettingsModel({
    this.soundEnabled = true,
    this.animationSpeed = AnimationSpeedSetting.medium,
    this.customColors = const [],
  });

  List<Color> get activeColors =>
      customColors.isNotEmpty ? customColors : AppConstants.defaultColors;

  Duration get animationDuration {
    switch (animationSpeed) {
      case AnimationSpeedSetting.slow:
        return AppConstants.slowAnimation;
      case AnimationSpeedSetting.medium:
        return AppConstants.mediumAnimation;
      case AnimationSpeedSetting.fast:
        return AppConstants.fastAnimation;
    }
  }

  SettingsModel copyWith({
    bool? soundEnabled,
    AnimationSpeedSetting? animationSpeed,
    List<Color>? customColors,
  }) {
    return SettingsModel(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      animationSpeed: animationSpeed ?? this.animationSpeed,
      customColors: customColors ?? this.customColors,
    );
  }
}

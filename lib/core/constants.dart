import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'ChromaShift';

  // Grid
  static const double minCellSize = 20.0;
  static const double gridPadding = 16.0;
  static const double dividerWidth = 2.0;

  // Default colors for the 4 quadrants
  static const List<Color> defaultColors = [
    Color(0xFFFF6B6B), // Red
    Color(0xFF4ECDC4), // Teal
    Color(0xFFFFE66D), // Yellow
    Color(0xFF6C5CE7), // Purple
  ];

  // Animation
  static const Duration fastAnimation = Duration(milliseconds: 50);
  static const Duration mediumAnimation = Duration(milliseconds: 120);
  static const Duration slowAnimation = Duration(milliseconds: 200);

  // Swipe
  static const double minSwipeDistance = 20.0;
  static const double swipeVelocityThreshold = 100.0;

  // Scramble: base moves + multiplier per level
  static const int scrambleBaseMoves = 5;
  static const int scrambleMovesPerLevel = 3;
}

enum SwipeDirection { left, right, up, down }

enum AnimationSpeedSetting { slow, medium, fast }

enum GameStatus { playing, paused, won }

// Multiplayer
enum RoomStatus { waiting, countdown, playing, finished }

enum MultiplayerPhase { lobby, waiting, countdown, playing, finished }

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chromashift/core/theme.dart';
import 'package:chromashift/features/game/game_provider.dart';
import 'package:chromashift/features/settings/settings_provider.dart';
import 'package:chromashift/services/storage_service.dart';
import 'package:chromashift/features/solo/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Dark status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Init storage
  final storageService = StorageService();
  await storageService.init();

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
      ],
      child: const ChromaShiftApp(),
    ),
  );
}

class ChromaShiftApp extends ConsumerStatefulWidget {
  const ChromaShiftApp({super.key});

  @override
  ConsumerState<ChromaShiftApp> createState() => _ChromaShiftAppState();
}

class _ChromaShiftAppState extends ConsumerState<ChromaShiftApp> {
  @override
  void initState() {
    super.initState();
    // Load saved settings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingsProvider.notifier).loadFromStorage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChromaShift',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}

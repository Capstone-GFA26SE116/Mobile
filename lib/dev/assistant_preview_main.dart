import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../core/constants/app_colors.dart';
import '../features/assistant/screens/assistant_screen.dart';

/// Dev-only entry point: opens AssistantScreen directly, skipping login.
/// Without a token the briefing call answers 401 ("Phiên đăng nhập hết hạn").
/// Run: flutter run -t lib/dev/assistant_preview_main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // AppConfig falls back to default URLs, as in main.dart.
  }
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: const AssistantScreen(),
    ),
  );
}

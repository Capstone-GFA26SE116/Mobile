import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../features/assistant/screens/assistant_screen.dart';

/// Dev-only entry point: opens AssistantScreen directly, skipping login.
/// Run: flutter run -t lib/dev/assistant_preview_main.dart
void main() {
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

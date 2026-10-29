import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../core/constants/app_colors.dart';
import '../core/services/storage_service.dart';
import '../features/assistant/screens/assistant_screen.dart';

/// Dev-only entry point: opens AssistantScreen directly, skipping login.
/// Without a token the briefing call answers 401 ("Phiên đăng nhập hết hạn").
/// Run: flutter run -t lib/dev/assistant_preview_main.dart
///
/// Debug-only options (ignored in profile/release builds):
///   `--dart-define=DEV_JWT=TOKEN`            use a real token, e.g. copied from Android (C1)
///   --dart-define=DEV_UTTERANCE="Hôm nay…"   say this 2 s after the avatar is ready (C3)
///   --dart-define=DEV_AVATAR_TOUR=true       cycle emotions + mouth for screenshots (C4)
const String _devJwt = String.fromEnvironment('DEV_JWT');
const String _devUtterance = String.fromEnvironment('DEV_UTTERANCE');
const bool _devTour = bool.fromEnvironment('DEV_AVATAR_TOUR');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // AppConfig falls back to default URLs, as in main.dart.
  }
  if (kDebugMode && _devJwt.isNotEmpty) {
    await StorageService().saveAccessToken(_devJwt);
  }
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: AssistantScreen(
        devUtterance: kDebugMode ? _devUtterance : null,
        devTour: kDebugMode && _devTour,
      ),
    ),
  );
}

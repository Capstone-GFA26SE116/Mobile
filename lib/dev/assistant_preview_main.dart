import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../core/constants/app_colors.dart';
import '../core/services/storage_service.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/assistant/screens/assistant_screen.dart';

/// Dev-only entry point: opens AssistantScreen directly, skipping login.
/// Without a token the assistant calls answer 401 ("Phiên đăng nhập hết hạn"); in debug the
/// stored token is refreshed first, so signing in once in the app is enough.
/// Run: flutter run -t lib/dev/assistant_preview_main.dart
///
/// Debug-only options (ignored in profile/release builds):
///   `--dart-define=DEV_JWT=TOKEN`            use a real token, e.g. copied from Android (C1)
///   --dart-define=DEV_UTTERANCE="Hôm nay…"   say this 2 s after the avatar is ready (C3);
///                                            "câu 1|câu 2" says them one after another
///   --dart-define=DEV_UTTERANCE_GAP=60      seconds between those sentences (default 2)
///   --dart-define=DEV_AVATAR_TOUR=true       cycle emotions + mouth for screenshots (C4)
const String _devJwt = String.fromEnvironment('DEV_JWT');
const String _devUtterance = String.fromEnvironment('DEV_UTTERANCE');
const int _devUtteranceGap = int.fromEnvironment('DEV_UTTERANCE_GAP', defaultValue: 2);
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
  } else if (kDebugMode) {
    // The access token is short-lived and this screen skips the app's login flow:
    // renew it from the stored refresh token, as the app does.
    try {
      await AuthRepository().refreshToken();
      debugPrint('[dev] access token refreshed');
    } catch (e) {
      debugPrint('[dev] token refresh failed: $e');
    }
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
        devUtteranceGap: _devUtteranceGap,
        devTour: kDebugMode && _devTour,
      ),
    ),
  );
}

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized Application Configuration
/// Loads values from the '.env' file with safe defaults.
class AppConfig {
  static const String defaultApiUrl = 'http://10.0.2.2:5036';
  static const String defaultLocalApiUrl = 'http://10.0.2.2:5036';

  static const String defaultAiUrl = 'http://10.0.2.2:8000';
  static const String defaultLocalAiUrl = 'http://10.0.2.2:8000';

  /// Whether the app should target the local backend server (Android emulator: 10.0.2.2)
  static bool get useLocalServer {
    final val = dotenv.maybeGet('USE_LOCAL_SERVER');
    return val?.toLowerCase() == 'true';
  }

  /// Base URL for the Core ASP.NET Core Backend
  static String get apiBaseUrl {
    if (useLocalServer) {
      return dotenv.get('API_LOCAL_URL', fallback: defaultLocalApiUrl);
    }
    return dotenv.get('API_BASE_URL', fallback: defaultApiUrl);
  }

  /// Whether the app should target the local AI Python service
  static bool get useLocalAi {
    final val = dotenv.maybeGet('USE_LOCAL_AI');
    return val?.toLowerCase() == 'true';
  }

  /// Base URL for the AI Cognitive Service (FastAPI)
  static String get aiServiceUrl {
    if (useLocalAi) {
      return dotenv.get('AI_LOCAL_URL', fallback: defaultLocalAiUrl);
    }
    return dotenv.get('AI_SERVICE_URL', fallback: defaultAiUrl);
  }
}

import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/token_refresher.dart';
import '../../../core/services/storage_service.dart';
import '../models/today_briefing.dart';

/// Why the card has no briefing. There is no fake fallback.
class BriefingException implements Exception {
  final String message;

  const BriefingException(this.message);

  @override
  String toString() => message;
}

/// W6-02: today's AI briefing straight from the AI service (no AI call used).
class BriefingRepository {
  final Dio _ai;

  /// Tests pass a fake Dio; [BriefingRepository.create] builds the real one.
  BriefingRepository(this._ai);

  factory BriefingRepository.create() {
    final storage = StorageService();
    final ai = Dio(
      BaseOptions(
        baseUrl: AppConfig.aiServiceUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Accept': 'application/json'},
      ),
    );
    ai.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await storage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] =
                token.startsWith('Bearer ') ? token : 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
    ai.interceptors.add(RefreshOnUnauthorized(ai));
    return BriefingRepository(ai);
  }

  Future<TodayBriefing> today({String language = 'en'}) async {
    try {
      final response = await _ai.get<dynamic>(
        ApiEndpoints.aiBriefingToday,
        queryParameters: {'language': language},
      );
      return TodayBriefing.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw BriefingException(
        e.response?.statusCode == 401
            ? 'Your session has expired. Please sign in again.'
            : 'AI briefing is unavailable. Pull down to retry.',
      );
    } on TypeError {
      throw const BriefingException('AI briefing is unavailable. Pull down to retry.');
    } on FormatException {
      throw const BriefingException('AI briefing is unavailable. Pull down to retry.');
    }
  }
}

import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/token_refresher.dart';
import '../../../core/services/storage_service.dart';
import '../logic/estimation_coach.dart';

/// Reads the learned estimate habit per work domain from the AI service
/// (GET /analytics/overview, no AI call, no quota).
class EstimationCoachRepository {
  final Dio _ai;

  /// Tests pass a fake Dio; [EstimationCoachRepository.create] builds the real one.
  EstimationCoachRepository(this._ai);

  factory EstimationCoachRepository.create() {
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
            options.headers['Authorization'] = token.startsWith('Bearer ')
                ? token
                : 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
    ai.interceptors.add(RefreshOnUnauthorized(ai));
    return EstimationCoachRepository(ai);
  }

  /// Domain id → habit. Empty when the service cannot be reached: the coach just stays quiet.
  Future<Map<String, DomainBias>> habits() async {
    try {
      final response = await _ai.get<dynamic>(
        ApiEndpoints.aiAnalyticsOverview,
        queryParameters: {'range': 'all', 'language': 'en'},
      );
      final domains =
          (response.data as Map<String, dynamic>)['domains']
              as List<dynamic>? ??
          [];
      return {
        for (final d in domains.cast<Map<String, dynamic>>())
          d['domain_id'] as String: DomainBias.fromJson(d),
      };
    } on DioException {
      return {};
    } on TypeError {
      return {};
    }
  }
}

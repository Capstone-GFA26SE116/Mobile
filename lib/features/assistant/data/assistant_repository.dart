import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/storage_service.dart';
import '../models/briefing.dart';

enum AssistantErrorKind { unauthorized, network, server }

/// A failure the avatar reads aloud. There is no fake-data fallback (plan decision #7).
class AssistantException implements Exception {
  final AssistantErrorKind kind;

  const AssistantException(this.kind);

  String get message => switch (kind) {
        AssistantErrorKind.unauthorized => 'Phiên đăng nhập hết hạn, bạn đăng nhập lại nhé.',
        AssistantErrorKind.network ||
        AssistantErrorKind.server =>
          'Mình chưa kết nối được máy chủ, thử lại sau nhé.',
      };

  @override
  String toString() => 'AssistantException($kind)';
}

/// Calls the AI service directly, with the same JWT header as `CopilotRepository`.
class AssistantRepository {
  final Dio _aiDio;
  final StorageService _storageService;

  /// [dio] is for tests (plan decision #9); without it a Dio pointed at the AI service is created.
  AssistantRepository({Dio? dio, StorageService? storageService})
      : _aiDio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.aiServiceUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 15),
                headers: {'Accept': 'application/json'},
              ),
            ),
        _storageService = storageService ?? StorageService() {
    _aiDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storageService.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] =
                token.startsWith('Bearer ') ? token : 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  Future<Briefing> getTodayBriefing() async {
    final Response<dynamic> response;
    try {
      response = await _aiDio.get(
        ApiEndpoints.aiBriefingToday,
        queryParameters: {'language': 'vi'},
      );
    } on DioException catch (e) {
      throw AssistantException(_kindOf(e));
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const AssistantException(AssistantErrorKind.server);
    }
    try {
      return Briefing.fromJson(data);
    } on TypeError {
      throw const AssistantException(AssistantErrorKind.server);
    }
  }

  static AssistantErrorKind _kindOf(DioException e) {
    if (e.response?.statusCode == 401) return AssistantErrorKind.unauthorized;
    return switch (e.type) {
      DioExceptionType.badResponse => AssistantErrorKind.server,
      _ => AssistantErrorKind.network,
    };
  }
}

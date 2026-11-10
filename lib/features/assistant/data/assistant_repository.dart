import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/storage_service.dart';
import '../models/assistant_turn.dart';
import '../models/briefing.dart';

/// [quotaExceeded] is 429 and [noPlan] is 409 `no_active_plan` (FR-22 section 1).
enum AssistantErrorKind { unauthorized, quotaExceeded, noPlan, network, server }

/// A failure the avatar reads aloud. There is no fake-data fallback (plan decision #7).
class AssistantException implements Exception {
  final AssistantErrorKind kind;

  const AssistantException(this.kind);

  String get message => switch (kind) {
        AssistantErrorKind.unauthorized => 'Phiên đăng nhập hết hạn, bạn đăng nhập lại nhé.',
        AssistantErrorKind.quotaExceeded =>
          'Bạn đã hết lượt AI của kỳ này. Mình vẫn đọc được việc hôm nay nếu bạn hỏi “Hôm nay tôi nên làm gì?”.',
        AssistantErrorKind.noPlan =>
          'Bạn chưa có gói dịch vụ đang dùng nên mình chưa trả lời được câu này.',
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

  /// One assistant turn (FR-22). [history] is sent as is; the caller keeps it within the limits.
  /// [selectedId] answers the options of the previous `clarify` turn, sent with the same [text].
  Future<Turn> turn(
    String text,
    List<TurnHistoryEntry> history, {
    String? selectedId,
  }) async {
    final Response<dynamic> response;
    try {
      response = await _aiDio.post(
        ApiEndpoints.aiAssistantTurn,
        data: {
          'text': text,
          'language': 'vi',
          'history': [for (final entry in history) entry.toJson()],
          'selected_id': ?selectedId,
        },
      );
    } on DioException catch (e) {
      throw AssistantException(_kindOf(e));
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const AssistantException(AssistantErrorKind.server);
    }
    try {
      return Turn.fromJson(data);
    } on FormatException {
      throw const AssistantException(AssistantErrorKind.server);
    } on TypeError {
      throw const AssistantException(AssistantErrorKind.server);
    }
  }

  static AssistantErrorKind _kindOf(DioException e) {
    debugPrint('[assistant] ${e.requestOptions.path} failed: '
        '${e.response?.statusCode ?? e.type.name} ${e.response?.data ?? ''}');
    switch (e.response?.statusCode) {
      case 401:
        return AssistantErrorKind.unauthorized;
      case 409:
        return AssistantErrorKind.noPlan;
      case 429:
        return AssistantErrorKind.quotaExceeded;
    }
    return switch (e.type) {
      DioExceptionType.badResponse => AssistantErrorKind.server,
      _ => AssistantErrorKind.network,
    };
  }
}

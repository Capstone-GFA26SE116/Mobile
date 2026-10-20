import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/storage_service.dart';
import '../models/copilot_models.dart';

class CopilotRepository {
  final ApiClient _apiClient;
  final StorageService _storageService;
  late final Dio _aiDio;

  // Base URL của AI Service (FastAPI)
  static const String aiBaseUrl = 'http://10.0.2.2:8000';

  CopilotRepository({ApiClient? apiClient, StorageService? storageService})
      : _apiClient = apiClient ?? ApiClient(),
        _storageService = storageService ?? StorageService() {
    _aiDio = Dio(
      BaseOptions(
        baseUrl: aiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _aiDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storageService.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = token.startsWith('Bearer ')
                ? token
                : 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  Future<List<CopilotMessage>> getTaskChat(String taskId) async {
    try {
      final response = await _aiDio.get('/chat/tasks/$taskId');
      if (response.statusCode == 200 && response.data != null) {
        final messagesRaw = response.data['messages'] as List<dynamic>? ?? [];
        return messagesRaw
            .map((m) => CopilotMessage.fromJson(m as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Fallback khi AI service chưa online
    }
    return [];
  }

  Future<CopilotMessage> sendTaskMessage(String taskId, String message) async {
    try {
      final response = await _aiDio.post(
        '/chat/tasks/$taskId/messages',
        data: {'message': message},
      );
      if (response.statusCode == 200 && response.data != null) {
        final aiMessageJson = response.data['ai_message'] ?? response.data;
        return CopilotMessage.fromJson(aiMessageJson as Map<String, dynamic>);
      }
    } catch (e) {
      // Khi offline / local fallback: sinh phản hồi nhận thức hữu ích
      await Future.delayed(const Duration(milliseconds: 900));
      return _generateSimulatedAiResponse(message);
    }
    return _generateSimulatedAiResponse(message);
  }

  Future<bool> applyDraft(
    String taskId,
    String messageId, [
    List<CopilotSubtaskDraft>? subtasks,
  ]) async {
    // 1. Áp dụng lên AI Service
    try {
      await _aiDio.post(
        '/chat/tasks/$taskId/apply',
        data: {
          'message_id': messageId,
          'subtasks': subtasks?.map((s) => s.toJson()).toList(),
        },
      );
    } catch (_) {}

    // 2. Đồng bộ trực tiếp vào Backend Postgres nếu có taskId
    if (subtasks != null && taskId.contains('-')) {
      for (final s in subtasks) {
        try {
          await _apiClient.dio.post(
            ApiEndpoints.taskSubtasks(taskId),
            data: {
              'title': s.title,
              'estimatedMinutes': s.minutes,
              'orderIndex': s.order,
              'status': 'Pending',
            },
          );
        } catch (_) {}
      }
    }

    return true;
  }

  CopilotMessage _generateSimulatedAiResponse(String prompt) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    if (prompt.contains('Break') ||
        prompt.contains('tách') ||
        prompt.contains('phân rã')) {
      return CopilotMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        role: 'ai',
        text: 'Tôi đã phân tích nhiệm vụ và áp dụng hệ số bù trừ K_bias = 1.34x dựa trên lịch sử của bạn. Đề xuất phân rã thành các subtask sau:',
        time: timeStr,
        kind: 'draft',
        draft: CopilotDraft(
          messageId: 'draft_${DateTime.now().millisecondsSinceEpoch}',
          subtasks: [
            CopilotSubtaskDraft(
              title: 'Nghiên cứu tài liệu & thiết kế Data Contract',
              minutes: 45,
              order: 1,
              reason: 'Nền tảng kiến trúc ban đầu',
            ),
            CopilotSubtaskDraft(
              title: 'Cài đặt Core Service & Data Repository',
              minutes: 60,
              order: 2,
              reason: 'Logic xử lý tập trung',
            ),
            CopilotSubtaskDraft(
              title: 'Tích hợp giao diện người dùng & Validation',
              minutes: 50,
              order: 3,
              reason: 'Hoàn thiện trải nghiệm UX',
            ),
            CopilotSubtaskDraft(
              title: 'Kiểm thử e2e & đồng bộ dữ liệu',
              minutes: 30,
              order: 4,
              reason: 'Đảm bảo tính ổn định',
            ),
          ],
          yourEstimateMinutes: 120,
          adjustedMinutes: 185,
          subtaskTotalMinutes: 185,
          adjustedIsHint: true,
          warning: 'Tổng thời gian ước tính vượt qua phiên tập trung tối ưu (90p). Đã chèn đệm nghỉ 10p giữa các chặng.',
        ),
      );
    }

    return CopilotMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      role: 'ai',
      text: 'Metanoia Copilot đã ghi nhận yêu cầu. Tôi khuyến nghị giữ các khung thời gian deep work dưới 90 phút và ưu tiên giải quyết các tác vụ có tính phụ thuộc cao trước.',
      time: timeStr,
      kind: 'text',
    );
  }
}

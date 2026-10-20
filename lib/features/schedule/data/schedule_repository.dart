import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../dashboard/models/dashboard_models.dart';
import '../models/schedule_models.dart';

class ScheduleRepository {
  final ApiClient _apiClient;

  ScheduleRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<List<CalendarSlotModel>> getCalendarRange(DateTime from, DateTime to) async {
    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.calendar,
        queryParameters: {
          'from': from.toUtc().toIso8601String(),
          'to': to.toUtc().toIso8601String(),
          'includeCancelled': false,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>? ?? [];
        return items
            .map((e) => CalendarSlotModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Lỗi lấy lịch làm việc: ${e.message}');
    }
  }

  Future<AiProposalResponse> proposeSchedule({List<String>? taskIds, String language = 'vi'}) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.proposeSchedule,
        data: {
          'taskIds': taskIds,
          'language': language,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return AiProposalResponse.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Không nhận được đề xuất lịch');
    } on DioException catch (e) {
      final msg = ApiClient.extractErrorMessage(e, 'Lỗi kết nối dịch vụ AI xếp lịch');
      throw Exception(msg);
    }
  }

  Future<AiProposalResponse?> getPendingProposal() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.pendingProposal);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        // Chuyển đổi ScheduleProposalDto sang AiProposalResponse
        final slotsRaw = data['slots'] as List<dynamic>? ?? [];
        final slots = slotsRaw.map((s) {
          final slotMap = s as Map<String, dynamic>;
          final start = DateTime.tryParse(slotMap['start'] as String? ?? '')?.toLocal() ?? DateTime.now();
          final end = DateTime.tryParse(slotMap['end'] as String? ?? '')?.toLocal() ?? DateTime.now();
          final minutes = end.difference(start).inMinutes;

          return AiSlotItem(
            slotId: slotMap['id']?.toString() ?? '',
            taskId: slotMap['taskId']?.toString() ?? '',
            subTaskId: slotMap['subTaskId']?.toString(),
            start: start,
            end: end,
            proposedMinutes: minutes,
            explanation: 'Đề xuất chờ duyệt',
          );
        }).toList();

        return AiProposalResponse(
          proposalId: data['id']?.toString(),
          isFeasible: data['isFeasible'] as bool? ?? true,
          missingMinutes: data['missingMinutes'] as int?,
          explanation: data['explanation'] as String? ?? 'Bản đề xuất lịch chưa duyệt',
          slots: slots,
          warnings: [],
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> approveProposal(String proposalId) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.approveProposal(proposalId),
      );
      if (response.statusCode != 200) {
        throw Exception('Duyệt đề xuất thất bại');
      }
    } on DioException catch (e) {
      final msg = ApiClient.extractErrorMessage(e, 'Duyệt đề xuất thất bại');
      throw Exception('Lỗi duyệt đề xuất: $msg');
    }
  }

  Future<void> cancelSlot(String slotId) async {
    try {
      await _apiClient.dio.delete(ApiEndpoints.scheduleSlotDetail(slotId));
    } on DioException catch (e) {
      final msg = ApiClient.extractErrorMessage(e, 'Hủy slot thất bại');
      throw Exception('Lỗi hủy slot: $msg');
    }
  }

  Future<String> syncGoogleCalendar() async {
    try {
      final response = await _apiClient.dio.post(ApiEndpoints.googleCalendarSync);
      if (response.statusCode == 200 && response.data != null) {
        final syncedCount = response.data['syncedEventsCount'] ?? 0;
        return 'Đồng bộ thành công $syncedCount sự kiện từ Google Calendar';
      }
      return 'Đã đồng bộ Google Calendar';
    } on DioException catch (e) {
      final msg = ApiClient.extractErrorMessage(e, 'Đồng bộ Google Calendar thất bại');
      throw Exception('Lỗi đồng bộ Google Calendar: $msg');
    }
  }

  Future<String> getGoogleCalendarStatus() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.googleCalendarStatus);
      if (response.statusCode == 200 && response.data != null) {
        return response.data['status'] as String? ?? 'NotConnected';
      }
      return 'NotConnected';
    } catch (_) {
      return 'NotConnected';
    }
  }
}

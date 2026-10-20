import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../models/dashboard_models.dart';

class DashboardRepository {
  final ApiClient _apiClient;

  DashboardRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<UserProfileModel> getUserProfile() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.me);
      if (response.statusCode == 200 && response.data != null) {
        return UserProfileModel.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Không tìm thấy thông tin người dùng');
    } on DioException catch (e) {
      throw Exception('Lỗi tải thông tin: ${e.message}');
    }
  }

  Future<List<CalendarSlotModel>> getTodaySlots() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).toUtc().toIso8601String();

      final response = await _apiClient.dio.get(
        ApiEndpoints.calendar,
        queryParameters: {
          'from': startOfDay,
          'to': endOfDay,
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
    } catch (_) {
      return [];
    }
  }

  Future<int> getActiveProjectsCount() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.projects);
      if (response.statusCode == 200 && response.data != null) {
        final list = response.data as List<dynamic>;
        return list.length;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }
}

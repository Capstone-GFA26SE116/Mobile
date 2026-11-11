import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../models/notification_models.dart';

class NotificationRepository {
  final ApiClient _apiClient;

  NotificationRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Fetch notifications from backend inbox.
  Future<List<NotificationItem>> getNotifications({
    bool unreadOnly = false,
    int take = 50,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.notifications,
        queryParameters: {
          'unreadOnly': unreadOnly,
          'take': take,
        },
      );

      if (response.data is List) {
        return (response.data as List)
            .whereType<Map<String, dynamic>>()
            .map((item) => NotificationItem.fromJson(item))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception(ApiClient.extractErrorMessage(
          e, 'Failed to fetch notifications.'));
    }
  }

  /// Mark a single notification as read.
  Future<void> markAsRead(String notificationId) async {
    try {
      await _apiClient.dio.post(
        ApiEndpoints.notificationRead(notificationId),
      );
    } catch (e) {
      throw Exception(ApiClient.extractErrorMessage(
          e, 'Failed to mark notification as read.'));
    }
  }

  /// Mark all notifications as read.
  Future<int> markAllAsRead() async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.notificationReadAll,
      );
      if (response.data is Map && response.data['updated'] != null) {
        return (response.data['updated'] as num).toInt();
      }
      return 0;
    } catch (e) {
      throw Exception(ApiClient.extractErrorMessage(
          e, 'Failed to mark all notifications as read.'));
    }
  }
}


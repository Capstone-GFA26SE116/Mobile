import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../models/focus_models.dart';

class FocusConflictException implements Exception {
  final String message;
  final FocusCurrentResponse? runningSession;

  FocusConflictException(this.message, [this.runningSession]);

  @override
  String toString() => message;
}

class FocusRepository {
  final ApiClient _apiClient;

  FocusRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Start a focus session. If user already has an active session (409 Conflict),
  /// throws [FocusConflictException] containing the active session.
  Future<FocusStartResponse> startSession(FocusStartRequest request) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.focusStart,
        data: request.toJson(),
      );

      if (response.data is Map<String, dynamic>) {
        return FocusStartResponse.fromJson(
            response.data as Map<String, dynamic>);
      }
      throw Exception('Invalid server response format.');
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final data = e.response?.data;
        FocusCurrentResponse? running;
        String msg = 'A focus session is already in progress.';
        if (data is Map<String, dynamic>) {
          if (data['message'] != null) {
            msg = data['message'].toString();
          }
          if (data['details'] is Map<String, dynamic>) {
            try {
              running = FocusCurrentResponse.fromJson(
                  data['details'] as Map<String, dynamic>);
            } catch (_) {}
          }
        }
        throw FocusConflictException(msg, running);
      }
      throw Exception(ApiClient.extractErrorMessage(
          e, 'Failed to start focus session.'));
    } catch (e) {
      if (e is FocusConflictException) rethrow;
      throw Exception(ApiClient.extractErrorMessage(
          e, 'Failed to start focus session.'));
    }
  }

  /// Get the currently active focus session (200 OK) or null (204 No Content).
  Future<FocusCurrentResponse?> getCurrentSession() async {
    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.focusCurrent,
        options: Options(
          validateStatus: (status) =>
              status != null && (status >= 200 && status < 300),
        ),
      );

      if (response.statusCode == 204 || response.data == null) {
        return null;
      }

      if (response.data is Map<String, dynamic>) {
        return FocusCurrentResponse.fromJson(
            response.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 204) return null;
      throw Exception(ApiClient.extractErrorMessage(
          e, 'Failed to fetch current focus session.'));
    } catch (e) {
      return null;
    }
  }

  /// Stop a focus session with reason (Completed, Interrupted, Blocked, Other).
  Future<FocusStopResponse> stopSession(
    String sessionId,
    FocusStopRequest request,
  ) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.focusStop(sessionId),
        data: request.toJson(),
      );

      if (response.data is Map<String, dynamic>) {
        return FocusStopResponse.fromJson(
            response.data as Map<String, dynamic>);
      }
      throw Exception('Invalid server response format.');
    } catch (e) {
      throw Exception(ApiClient.extractErrorMessage(
          e, 'Failed to stop focus session.'));
    }
  }

  /// Fetch sessions auto-timed-out that need user confirmation.
  Future<List<FocusPendingConfirmationItem>> getPendingConfirmations() async {
    try {
      final response =
          await _apiClient.dio.get(ApiEndpoints.focusPendingConfirmation);
      if (response.data is List) {
        return (response.data as List)
            .whereType<Map<String, dynamic>>()
            .map((item) => FocusPendingConfirmationItem.fromJson(item))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Confirm or correct an auto-timeout session.
  Future<void> confirmSession(
    String sessionId, {
    required bool confirmed,
    int? correctedMinutes,
  }) async {
    try {
      await _apiClient.dio.post(
        ApiEndpoints.focusConfirm(sessionId),
        data: {
          'confirmed': confirmed,
          if (correctedMinutes != null) 'correctedMinutes': correctedMinutes,
        },
      );
    } catch (e) {
      throw Exception(ApiClient.extractErrorMessage(
          e, 'Failed to confirm focus session.'));
    }
  }

  /// Fetch focus ambient audio tracks.
  Future<List<FocusTrackItem>> getFocusTracks() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.focusTracks);
      if (response.data is List) {
        return (response.data as List)
            .whereType<Map<String, dynamic>>()
            .map((item) => FocusTrackItem.fromJson(item))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}


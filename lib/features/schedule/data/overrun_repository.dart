import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/token_refresher.dart';
import '../../../core/services/storage_service.dart';
import '../models/overrun_models.dart';

/// Why a proposal or its approval failed, said on the sheet.
class OverrunException implements Exception {
  final String message;

  const OverrunException(this.message);

  @override
  String toString() => message;
}

/// FR-16b on the phone: ask the AI service for a proposal, and apply it through the
/// Backend once the user approves (AI plan decision #2, option A).
class OverrunRepository {
  final Dio _backend;
  final Dio _ai;

  /// The Backend Dio, then the AI service one. Tests pass fakes;
  /// [OverrunRepository.create] builds the real ones.
  OverrunRepository(this._backend, this._ai);

  factory OverrunRepository.create() {
    final storage = StorageService();
    final ai = Dio(
      BaseOptions(
        baseUrl: AppConfig.aiServiceUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
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
    return OverrunRepository(ApiClient().dio, ai);
  }

  Future<OverrunPlan> propose({
    required String slotId,
    required int extraMinutes,
    String language = 'en',
  }) async {
    try {
      final response = await _ai.post<dynamic>(
        ApiEndpoints.aiScheduleOverrun,
        data: {
          'slot_id': slotId,
          'extra_minutes': extraMinutes,
          'language': language,
        },
      );
      return OverrunPlan.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw OverrunException(switch (e.response?.statusCode) {
        404 => 'This slot no longer exists.',
        409 => 'This slot is finished or cannot be extended.',
        422 => 'Please choose between 5 and 480 minutes.',
        401 => 'Your session has expired. Please sign in again.',
        _ => 'Could not reach the server. Please try again.',
      });
    } on TypeError {
      throw const OverrunException('The server sent an unexpected answer.');
    }
  }

  /// Updates each slot of the plan, the late one first. Returns how many failed.
  ///
  /// `PUT /api/schedule-slots/{id}` replaces the whole slot, so the current slot is
  /// read first and sent back with only the times changed.
  Future<int> apply(OverrunPlan plan) async {
    var failed = 0;
    for (final change in plan.changes) {
      try {
        await _moveSlot(change);
      } on DioException {
        failed++;
      } on TypeError {
        failed++;
      }
    }
    return failed;
  }

  Future<void> _moveSlot(SlotTimes change) async {
    final path = ApiEndpoints.scheduleSlotDetail(change.slotId);
    final current = (await _backend.get<dynamic>(path)).data as Map<String, dynamic>;
    await _backend.put<dynamic>(
      path,
      data: {
        'subTaskId': current['subTaskId'],
        'scheduleProposalId': current['scheduleProposalId'],
        'startTime': change.start.toUtc().toIso8601String(),
        'endTime': change.end.toUtc().toIso8601String(),
        'originalStartTime': current['originalStartTime'],
        'isManualOverride': current['isManualOverride'] ?? false,
        'kbiasUsed': current['kbiasUsed'],
        'explanation': current['explanation'],
        'status': current['status'],
      },
    );
  }
}

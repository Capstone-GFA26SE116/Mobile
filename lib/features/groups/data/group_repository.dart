import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/token_refresher.dart';
import '../../../core/services/storage_service.dart';
import '../models/group_models.dart';

/// A group call that failed, with the message to show.
class GroupException implements Exception {
  final String message;
  final int? status;

  /// Backend `code` (e.g. GROUP_ASSIGNEE_BUSY, SLOT_OVERLAP) or AI `detail.code`.
  final String? code;

  const GroupException(this.message, {this.status, this.code});

  @override
  String toString() => message;
}

/// Work Group on the phone (plans/work-group.md). Backend for the group data and every
/// write; the AI service only suggests (FR-23 who, FR-25 when) and writes nothing.
class GroupRepository {
  final Dio _backend;
  final Dio _ai;
  final Future<String?> Function() _userId;

  GroupRepository(this._backend, this._ai, {Future<String?> Function()? userId})
    : _userId = userId ?? (() async => null);

  factory GroupRepository.create() {
    final storage = StorageService();
    final ai = Dio(
      BaseOptions(
        baseUrl: AppConfig.aiServiceUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
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
    return GroupRepository(ApiClient().dio, ai, userId: storage.getUserId);
  }

  /// The signed-in user, to know which work is "mine".
  Future<String?> myUserId() => _userId();

  // --- reads (Backend) ---

  Future<List<GroupSummary>> groups() =>
      _list('/api/groups', GroupSummary.fromJson);

  Future<GroupSummary> group(String id) =>
      _call(() async => GroupSummary.fromJson(await _get('/api/groups/$id')));

  Future<List<GroupMember>> members(String groupId) =>
      _list('/api/groups/$groupId/members', GroupMember.fromJson);

  Future<List<GroupInvitation>> invitations() =>
      _list('/api/group-invitations', GroupInvitation.fromJson);

  Future<List<GroupTask>> tasks(String groupId) =>
      _list('/api/groups/$groupId/tasks', GroupTask.fromJson);

  Future<GroupTask> task(String taskId) => _call(
    () async => GroupTask.fromJson(await _get('/api/group-tasks/$taskId')),
  );

  Future<List<GroupSubTask>> subTasks(String taskId) =>
      _list('/api/group-tasks/$taskId/subtasks', GroupSubTask.fromJson);

  Future<GroupProgress> progress(String groupId) => _call(
    () async =>
        GroupProgress.fromJson(await _get('/api/groups/$groupId/progress')),
  );

  Future<List<MyGroupWork>> myWork() => _call(
    () async => MyGroupWork.listFromJson(await _get('/api/my-group-tasks')),
  );

  /// The caller's running group focus session, or null.
  Future<GroupFocus?> currentFocus() => _call(() async {
    final r = await _backend.get<dynamic>('/api/group-focus/current');
    return r.statusCode == 204 || r.data is! Map
        ? null
        : GroupFocus.fromJson(r.data as Map<String, dynamic>);
  });

  // --- writes (Backend) ---

  Future<void> acceptInvitation(String id) =>
      _call(() => _backend.post<dynamic>('/api/group-invitations/$id/accept'));

  Future<void> declineInvitation(String id) =>
      _call(() => _backend.post<dynamic>('/api/group-invitations/$id/decline'));

  Future<void> setTaskStatus(String taskId, String status) => _call(
    () => _backend.put<dynamic>(
      '/api/group-tasks/$taskId/status',
      data: {'status': status},
    ),
  );

  Future<void> setSubTaskStatus(String subTaskId, String status) => _call(
    () => _backend.put<dynamic>(
      '/api/group-subtasks/$subTaskId/status',
      data: {'status': status},
    ),
  );

  /// Leader. Throws [GroupException] with code GROUP_ASSIGNEE_BUSY when the person is
  /// busy or overloaded; call again with [confirmConflicts] after the Leader agrees.
  Future<void> assign(
    String taskId,
    String userId, {
    bool confirmConflicts = false,
  }) => _call(
    () => _backend.put<dynamic>(
      '/api/group-tasks/$taskId/assignee',
      data: {
        'assigneeId': userId,
        if (confirmConflicts) 'confirmConflicts': true,
      },
    ),
  );

  Future<String> startFocus(String taskId, {String? subTaskId}) =>
      _call(() async {
        final r = await _backend.post<dynamic>(
          '/api/group-tasks/$taskId/focus/start',
          data: {'subTaskId': subTaskId, 'scheduleSlotId': null},
        );
        return (r.data as Map<String, dynamic>)['sessionId'] as String;
      });

  Future<void> stopFocus(String sessionId, {required bool completed}) => _call(
    () => _backend.post<dynamic>(
      '/api/group-focus/$sessionId/stop',
      data: {
        'stopReason': completed ? 'Completed' : 'Interrupted',
        'note': null,
      },
    ),
  );

  /// FR-25: saves the chosen suggestions one by one. Returns how many were saved; a time
  /// taken meanwhile (409 SLOT_OVERLAP) is skipped.
  Future<int> addSlots(String taskId, List<SlotSuggestion> slots) async {
    var saved = 0;
    for (final s in slots) {
      try {
        await _backend.post<dynamic>(
          '/api/group-tasks/$taskId/schedule-slots',
          data: {
            'subTaskId': s.subtaskId,
            'startTime': s.start.toUtc().toIso8601String(),
            'endTime': s.end.toUtc().toIso8601String(),
            'explanation': s.reason,
            'status': 'Approved',
          },
        );
        saved++;
      } on DioException catch (e) {
        if (e.response?.statusCode != 409) throw _backendError(e);
      }
    }
    return saved;
  }

  // --- AI suggestions (write nothing) ---

  /// FR-23, Leader only. Hết lượt AI vẫn trả xếp hạng, chỉ thiếu lý do.
  Future<AssigneeSuggestions> suggestAssignees(
    String taskId, {
    String? domainId,
  }) => _aiCall(
    () async => AssigneeSuggestions.fromJson(
      (await _ai.post<dynamic>(
            '/groups/tasks/$taskId/assignee-suggestions',
            data: {'domain_id': domainId, 'language': 'vi'},
          )).data
          as Map<String, dynamic>,
    ),
  );

  /// FR-25, for the person given the task. No AI call is charged.
  Future<SlotSuggestions> suggestSlots(String taskId) => _aiCall(
    () async => SlotSuggestions.fromJson(
      (await _ai.post<dynamic>(
            '/groups/tasks/$taskId/slot-suggestions',
            data: {'language': 'vi'},
          )).data
          as Map<String, dynamic>,
    ),
  );

  // --- helpers ---

  Future<Map<String, dynamic>> _get(String path) async =>
      (await _backend.get<dynamic>(path)).data as Map<String, dynamic>;

  Future<List<T>> _list<T>(
    String path,
    T Function(Map<String, dynamic>) read,
  ) => _call(() async {
    final data = (await _backend.get<dynamic>(path)).data;
    return [
      for (final item in data as List<dynamic>? ?? const [])
        read(item as Map<String, dynamic>),
    ];
  });

  Future<T> _call<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw _backendError(e);
    } on TypeError {
      throw const GroupException('The server sent an unexpected answer.');
    }
  }

  static GroupException _backendError(DioException e) {
    final status = e.response?.statusCode;
    final body = e.response?.data;
    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    final message = map['message'] as String?;
    return GroupException(
      switch (status) {
        null => 'Could not reach the server. Please try again.',
        401 => 'Your session has expired. Please sign in again.',
        403 => message ?? 'Your role in this group cannot do this.',
        404 => 'Not found, or you are not in this group.',
        _ => message ?? 'Something went wrong. Please try again.',
      },
      status: status,
      code: map['code'] as String?,
    );
  }

  /// AI errors are FastAPI-shaped: `{detail: "..."}` or `{detail: {code: ...}}`.
  Future<T> _aiCall<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      final detail = body is Map<String, dynamic> ? body['detail'] : null;
      final code = detail is Map<String, dynamic>
          ? detail['code'] as String?
          : detail as String?;
      throw GroupException(
        switch (status) {
          null => 'Could not reach the AI service. Please try again.',
          401 => 'Your session has expired. Please sign in again.',
          403 => 'Only the people this is for can use this suggestion.',
          404 => 'Not found, or you are not in this group.',
          409 => switch (code) {
            'no_active_plan' => 'You have no active plan.',
            _ => 'This task is finished, has a fixed time, or the group is archived.',
          },
          429 => 'You have used all AI calls of your plan.',
          _ => 'The AI is busy. Please try again later.',
        },
        status: status,
        code: code,
      );
    } on TypeError {
      throw const GroupException('The AI service sent an unexpected answer.');
    }
  }
}

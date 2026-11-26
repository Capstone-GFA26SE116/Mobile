import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/token_refresher.dart';
import '../../../core/services/storage_service.dart';
import '../models/reshuffle_models.dart';

/// A step that did not go through, said aloud / shown on the card.
class ReshuffleException implements Exception {
  final String message;

  const ReshuffleException(this.message);

  @override
  String toString() => message;
}

/// A project or kind of work the urgent task can go into.
typedef PickItem = ({String id, String name});

/// FR-22d on the phone (plans/assistant-reshuffle.md): asks the AI service for
/// proposals and applies them through the Backend once the user agrees, keeping
/// what is needed to undo them (M18).
class ReshuffleRepository {
  final Dio _backend;
  final Dio _ai;

  /// The Backend Dio, then the AI service one. Tests pass fakes.
  ReshuffleRepository(this._backend, this._ai);

  factory ReshuffleRepository.create() {
    final storage = StorageService();
    final ai = Dio(
      BaseOptions(
        baseUrl: AppConfig.aiServiceUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
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
    return ReshuffleRepository(ApiClient().dio, ai);
  }

  // --- proposals (AI service, writes nothing) ---

  /// M4 "another time": the same urgent work at a new time.
  Future<InsertPreview> previewInsert(
    String title,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final response = await _ai.post<dynamic>(
        ApiEndpoints.aiInsertBlock,
        data: {
          'title': title,
          'start': start.toUtc().toIso8601String(),
          'end': end.toUtc().toIso8601String(),
          'language': 'vi',
        },
      );
      return InsertPreview.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ReshuffleException(switch (e.response?.statusCode) {
        401 => 'Phiên đăng nhập hết hạn, bạn đăng nhập lại nhé.',
        422 => 'Khung giờ đó không xếp được nữa.',
        _ => 'Mình chưa xem được lịch, bạn thử lại sau nhé.',
      });
    } on TypeError {
      throw const ReshuffleException('Máy chủ trả lời không như mong đợi.');
    }
  }

  /// Active projects, for the urgent task when the AI has no default project.
  Future<List<PickItem>> projects() async {
    final response = await _backend.get<dynamic>(
      ApiEndpoints.projects,
      queryParameters: {'includeArchived': false},
    );
    return [
      for (final p in response.data as List<dynamic>)
        if ((p as Map<String, dynamic>)['status'] != 'Archived')
          (id: p['id'] as String, name: p['name'] as String? ?? ''),
    ];
  }

  /// Kinds of work, when the AI has no recent one for this user.
  Future<List<PickItem>> domains() async {
    final response = await _backend.get<dynamic>(ApiEndpoints.domains);
    return [
      for (final d in response.data as List<dynamic>)
        (
          id: (d as Map<String, dynamic>)['id'] as String,
          name: d['name'] as String? ?? '',
        ),
    ];
  }

  // --- applying (Backend) ---

  /// M3 / M4: creates the urgent Fixed task, moves the covered slots and, on overwrite,
  /// sets the Fixed tasks in the way to Skipped. Throws when the task cannot be created
  /// (then nothing changed). Returns what to undo and how many later steps failed.
  Future<({ReshuffleUndo undo, int failed})> applyInsert(
    InsertPreview preview, {
    required bool overwrite,
    required String projectId,
    required String domainId,
  }) async {
    final String taskId;
    try {
      final created = await _backend.post<dynamic>(
        ApiEndpoints.projectTasks(projectId),
        data: {
          'title': preview.title,
          'description': null,
          'taskType': 'Fixed',
          'status': null,
          'domainId': domainId,
          'milestoneId': null,
          'deadline': null,
          'estimatedMinutes': null,
          'aiEstimatedMinutes': null,
          'fixedStart': preview.start.toUtc().toIso8601String(),
          'fixedEnd': preview.end.toUtc().toIso8601String(),
        },
      );
      taskId = (created.data as Map<String, dynamic>)['id'] as String;
    } on DioException catch (e) {
      throw ReshuffleException(_failure(e));
    } on TypeError {
      throw const ReshuffleException('Máy chủ trả lời không như mong đợi.');
    }

    final moved = await _moveAll(preview.moves);
    final skipped = <({String taskId, String status})>[];
    var failed = moved.failed;
    if (overwrite) {
      for (final id in preview.skipTaskIds) {
        try {
          final old = await _setTaskStatus(id, 'Skipped');
          skipped.add((taskId: id, status: old));
        } on DioException {
          failed++;
        } on TypeError {
          failed++;
        }
      }
    }
    return (
      undo: ReshuffleUndo(
        createdTaskId: taskId,
        slots: moved.done,
        skippedTasks: skipped,
        appliedAt: DateTime.now(),
      ),
      failed: failed,
    );
  }

  /// M7 / M10: moves each slot; a Missed slot becomes Approved again.
  Future<({ReshuffleUndo undo, int failed})> applyMoves(
    List<ReshuffleMove> moves,
  ) async {
    final moved = await _moveAll(moves);
    if (moved.done.isEmpty && moves.isNotEmpty) {
      throw const ReshuffleException(
        'Mình chưa cập nhật được lịch, bạn thử lại sau nhé.',
      );
    }
    return (
      undo: ReshuffleUndo(
        createdTaskId: null,
        slots: moved.done,
        skippedTasks: const [],
        appliedAt: DateTime.now(),
      ),
      failed: moved.failed,
    );
  }

  /// M18: puts everything back, the last change first. Returns how many steps failed.
  Future<int> undo(ReshuffleUndo undo) async {
    var failed = 0;
    for (final slot in undo.slots.reversed) {
      try {
        await _putSlot(slot.slotId, slot.start, slot.end, status: slot.status);
      } on DioException {
        failed++;
      } on TypeError {
        failed++;
      }
    }
    for (final task in undo.skippedTasks) {
      try {
        await _setTaskStatus(task.taskId, task.status);
      } on DioException {
        failed++;
      } on TypeError {
        failed++;
      }
    }
    final created = undo.createdTaskId;
    if (created != null) {
      try {
        await _backend.delete<dynamic>(ApiEndpoints.taskDetail(created));
      } on DioException {
        failed++;
      }
    }
    return failed;
  }

  Future<
    ({
      List<({String slotId, DateTime start, DateTime end, String status})> done,
      int failed,
    })
  >
  _moveAll(List<ReshuffleMove> moves) async {
    final done =
        <({String slotId, DateTime start, DateTime end, String status})>[];
    var failed = 0;
    for (final move in moves) {
      try {
        final old = await _putSlot(move.slotId, move.newStart, move.newEnd);
        done.add((
          slotId: move.slotId,
          start: move.oldStart,
          end: move.oldEnd,
          status: old,
        ));
      } on DioException {
        failed++;
      } on TypeError {
        failed++;
      }
    }
    return (done: done, failed: failed);
  }

  /// `PUT /api/schedule-slots/{id}` replaces the whole slot: read it first and send
  /// it back with new times. Without [status], a Missed slot becomes Approved (M10).
  /// Returns the status the slot had.
  Future<String> _putSlot(
    String slotId,
    DateTime start,
    DateTime end, {
    String? status,
  }) async {
    final path = ApiEndpoints.scheduleSlotDetail(slotId);
    final current =
        (await _backend.get<dynamic>(path)).data as Map<String, dynamic>;
    final old = current['status'] as String? ?? 'Approved';
    await _backend.put<dynamic>(
      path,
      data: {
        'subTaskId': current['subTaskId'],
        'scheduleProposalId': current['scheduleProposalId'],
        'startTime': start.toUtc().toIso8601String(),
        'endTime': end.toUtc().toIso8601String(),
        'originalStartTime': current['originalStartTime'],
        'isManualOverride': current['isManualOverride'] ?? false,
        'kbiasUsed': current['kbiasUsed'],
        'explanation': current['explanation'],
        'status': status ?? (old == 'Missed' ? 'Approved' : old),
      },
    );
    return old;
  }

  /// `PUT /api/tasks/{id}` replaces the whole task too. Returns the old status.
  Future<String> _setTaskStatus(String taskId, String status) async {
    final path = ApiEndpoints.taskDetail(taskId);
    final t = (await _backend.get<dynamic>(path)).data as Map<String, dynamic>;
    await _backend.put<dynamic>(
      path,
      data: {
        'title': t['title'],
        'description': t['description'],
        'taskType': t['taskType'],
        'status': status,
        'domainId': t['domainId'],
        'milestoneId': t['milestoneId'],
        'deadline': t['deadline'],
        'estimatedMinutes': t['estimatedMinutes'],
        'aiEstimatedMinutes': t['aiEstimatedMinutes'],
        'fixedStart': t['fixedStart'],
        'fixedEnd': t['fixedEnd'],
      },
    );
    return t['status'] as String? ?? 'ToDo';
  }

  static String _failure(DioException e) => switch (e.response?.statusCode) {
    401 => 'Phiên đăng nhập hết hạn, bạn đăng nhập lại nhé.',
    null => 'Mình chưa kết nối được máy chủ, thử lại sau nhé.',
    _ => 'Mình chưa thêm được việc gấp, bạn thử lại sau nhé.',
  };
}

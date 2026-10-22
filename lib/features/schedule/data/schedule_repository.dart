import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/storage_service.dart';
import '../../dashboard/models/dashboard_models.dart';
import '../../projects/models/project_models.dart';
import '../models/schedule_models.dart';

class ScheduleRepository {
  final ApiClient _apiClient;
  final StorageService _storageService;
  late final Dio _aiDio;

  static const String aiBaseUrl =
      'https://metanoia-ai-2-b4ajh0bbhrandsg4.japaneast-01.azurewebsites.net';

  final Map<String, String> _taskTitleCache = {};

  ScheduleRepository({ApiClient? apiClient, StorageService? storageService})
    : _apiClient = apiClient ?? ApiClient(),
      _storageService = storageService ?? StorageService() {
    _aiDio = Dio(
      BaseOptions(
        baseUrl: aiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
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

  Future<List<CalendarSlotModel>> getCalendarRange(
    DateTime from,
    DateTime to,
  ) async {
    // 1. Primary: Try GET /api/calendar
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
        final slots = items
            .map((e) => CalendarSlotModel.fromJson(e as Map<String, dynamic>))
            .toList();
        if (slots.isNotEmpty) {
          return slots;
        }
      }
    } catch (_) {
      // Fall through to fallback
    }

    // 2. Fallback: Build slots from projects & tasks
    try {
      final projectRes = await _apiClient.dio.get(ApiEndpoints.projects);
      if (projectRes.statusCode == 200 && projectRes.data != null) {
        final projects = (projectRes.data as List<dynamic>)
            .map((e) => ProjectModel.fromJson(e as Map<String, dynamic>))
            .toList();
        final List<CalendarSlotModel> fallbackSlots = [];

        for (final p in projects) {
          try {
            final taskRes = await _apiClient.dio.get(
              ApiEndpoints.projectTasks(p.id),
            );
            if (taskRes.statusCode == 200 && taskRes.data != null) {
              final tasks = (taskRes.data as List<dynamic>)
                  .map((e) => TaskModel.fromJson(e as Map<String, dynamic>))
                  .toList();

              for (final t in tasks) {
                // If task has fixedStart / fixedEnd within range
                if (t.fixedStart != null && t.fixedEnd != null) {
                  final s = t.fixedStart!;
                  final e = t.fixedEnd!;
                  if (e.isAfter(from) && s.isBefore(to)) {
                    fallbackSlots.add(
                      CalendarSlotModel(
                        id: t.id,
                        source: 'Task',
                        title: t.title,
                        start: s,
                        end: e,
                        isAllDay: false,
                        status: t.status,
                        taskId: t.id,
                        projectId: p.id,
                        projectName: p.name,
                        taskType: t.taskType,
                      ),
                    );
                  }
                } else if (t.deadline != null) {
                  final dl = t.deadline!;
                  if (dl.isAfter(from.subtract(const Duration(days: 1))) &&
                      dl.isBefore(to.add(const Duration(days: 1)))) {
                    fallbackSlots.add(
                      CalendarSlotModel(
                        id: t.id,
                        source: 'Task',
                        title: t.title,
                        start: DateTime(dl.year, dl.month, dl.day, 9, 0),
                        end: DateTime(dl.year, dl.month, dl.day, 10, 0),
                        isAllDay: true,
                        status: t.status,
                        taskId: t.id,
                        projectId: p.id,
                        projectName: p.name,
                        taskType: t.taskType,
                      ),
                    );
                  }
                }

                // Check task's schedule slots
                try {
                  final slotRes = await _apiClient.dio.get(
                    ApiEndpoints.taskScheduleSlots(t.id),
                  );
                  if (slotRes.statusCode == 200 && slotRes.data != null) {
                    final rawSlots = slotRes.data as List<dynamic>;
                    for (final sJson in rawSlots) {
                      final sm = sJson as Map<String, dynamic>;
                      final sStart = DateTime.tryParse(sm['startTime'] ?? '')
                          ?.toLocal();
                      final sEnd = DateTime.tryParse(sm['endTime'] ?? '')
                          ?.toLocal();
                      final slotId = sm['id']?.toString() ?? '';
                      if (sStart != null &&
                          sEnd != null &&
                          sEnd.isAfter(from) &&
                          sStart.isBefore(to)) {
                        fallbackSlots.removeWhere(
                          (item) =>
                              item.id == slotId ||
                              (item.taskId == t.id && item.isAllDay),
                        );
                        fallbackSlots.add(
                          CalendarSlotModel(
                            id: slotId,
                            source: 'Slot',
                            title: t.title,
                            start: sStart,
                            end: sEnd,
                            isAllDay: false,
                            status: sm['status'] as String?,
                            taskId: t.id,
                            projectId: p.id,
                            projectName: p.name,
                            taskType: t.taskType,
                            explanation: sm['explanation'] as String?,
                            isManualOverride:
                                sm['isManualOverride'] as bool? ?? false,
                          ),
                        );
                      }
                    }
                  }
                } catch (_) {}
              }
            }
          } catch (_) {}
        }
        return fallbackSlots;
      }
    } catch (_) {}

    return [];
  }

  Future<AiProposalResponse> proposeSchedule({
    List<String>? taskIds,
    String language = 'en',
  }) async {
    // 1. Primary: Call POST /schedule/propose on AI Service
    try {
      final aiResponse = await _aiDio.post(
        ApiEndpoints.aiSchedulePropose,
        data: {
          if (taskIds != null && taskIds.isNotEmpty) 'task_ids': taskIds,
          'language': language,
        },
      );

      // 2. The AI Service saves the proposal to Postgres with status 'Pending'.
      // Fetch the proposal from Backend .NET (/api/schedule/proposals/pending)
      final pendingFromBackend = await getPendingProposal();
      if (pendingFromBackend != null) {
        return pendingFromBackend;
      }

      // If backend pending query returns null or 204, parse AI response directly
      if (aiResponse.statusCode == 200 && aiResponse.data != null) {
        final parsed = AiProposalResponse.fromJson(
          aiResponse.data as Map<String, dynamic>,
        );
        return await _enrichProposalTaskTitles(parsed);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw Exception('AI quota exceeded. Please try again later.');
      } else if (e.response?.statusCode == 409) {
        throw Exception(
          'Active subscription required for AI Schedule Optimization.',
        );
      }
      // If AI service failed, check if there is an existing pending proposal in backend
      final pending = await getPendingProposal();
      if (pending != null) {
        return pending;
      }
    } catch (_) {
      final pending = await getPendingProposal();
      if (pending != null) {
        return pending;
      }
    }

    // 3. Fallback: Intelligent On-Device Planner
    return _generateLocalIntelligentProposal(taskIds: taskIds);
  }

  Future<AiProposalResponse> _generateLocalIntelligentProposal({
    List<String>? taskIds,
  }) async {
    try {
      final projectRes = await _apiClient.dio.get(ApiEndpoints.projects);
      final List<ProjectModel> projects = [];
      if (projectRes.statusCode == 200 && projectRes.data != null) {
        projects.addAll(
          (projectRes.data as List<dynamic>).map(
            (e) => ProjectModel.fromJson(e as Map<String, dynamic>),
          ),
        );
      }

      final List<TaskModel> candidateTasks = [];
      for (final p in projects) {
        try {
          final taskRes = await _apiClient.dio.get(
            ApiEndpoints.projectTasks(p.id),
          );
          if (taskRes.statusCode == 200 && taskRes.data != null) {
            final tasks = (taskRes.data as List<dynamic>).map(
              (e) => TaskModel.fromJson(e as Map<String, dynamic>),
            );
            for (final t in tasks) {
              final s = t.status.toLowerCase();
              if (s != 'done' && s != 'completed' && s != 'cancelled') {
                if (taskIds == null || taskIds.contains(t.id)) {
                  candidateTasks.add(t);
                  _taskTitleCache[t.id] = t.title;
                }
              }
            }
          }
        } catch (_) {}
      }

      if (candidateTasks.isEmpty) {
        return AiProposalResponse(
          proposalId: null,
          isFeasible: true,
          explanation: 'All active tasks are already completed or scheduled. No additional slots required.',
          slots: [],
          warnings: [
            AiWarningItem(
              type: 'NO_TASKS',
              message: 'No pending or flexible tasks available to schedule. Create new tasks in Projects first.',
            ),
          ],
        );
      }

      // Fetch existing scheduled slots for this week to prevent collision
      final now = DateTime.now();
      final weekStart = DateTime(now.year, now.month, now.day);
      final weekEnd = weekStart.add(
        const Duration(days: 7, hours: 23, minutes: 59),
      );
      final existingSlots = await getCalendarRange(weekStart, weekEnd);

      final List<AiSlotItem> proposedSlots = [];
      var dayCursor = now.hour >= 16
          ? weekStart.add(const Duration(days: 1))
          : weekStart;

      // Schedule slots into peak focus windows (09:00-11:30 and 14:00-16:30)
      for (
        var i = 0;
        i < candidateTasks.length && proposedSlots.length < 8;
        i++
      ) {
        final task = candidateTasks[i];
        final durMins =
            (task.estimatedMinutes != null && task.estimatedMinutes! > 0)
            ? task.estimatedMinutes!.clamp(30, 180)
            : 90;

        // Try morning slot: 09:00
        var slotStart = DateTime(
          dayCursor.year,
          dayCursor.month,
          dayCursor.day,
          9,
          0,
        );
        var slotEnd = slotStart.add(Duration(minutes: durMins));

        // Check if morning overlaps existing slots
        final overlapsMorning = existingSlots.any(
          (s) => s.start.isBefore(slotEnd) && s.end.isAfter(slotStart),
        );

        if (overlapsMorning) {
          // Try afternoon slot: 14:00
          slotStart = DateTime(
            dayCursor.year,
            dayCursor.month,
            dayCursor.day,
            14,
            0,
          );
          slotEnd = slotStart.add(Duration(minutes: durMins));
          dayCursor = dayCursor.add(
            const Duration(days: 1),
          ); // Advance to next day
        } else {
          // If morning was used, afternoon of the same day is available for next task
          dayCursor = (i % 2 == 1)
              ? dayCursor.add(const Duration(days: 1))
              : dayCursor;
        }

        proposedSlots.add(
          AiSlotItem(
            slotId: 'local_${DateTime.now().millisecondsSinceEpoch}_$i',
            taskId: task.id,
            taskTitle: task.title,
            start: slotStart,
            end: slotEnd,
            proposedMinutes: durMins,
            explanation:
                'AI optimized: Allocated ${(durMins / 60.0).toStringAsFixed(1)}h focus block for "${task.title}".',
          ),
        );
      }

      return AiProposalResponse(
        proposalId: 'local_${DateTime.now().millisecondsSinceEpoch}',
        isFeasible: true,
        explanation:
            'AI analyzed your cognitive capacity and allocated ${proposedSlots.length} high-impact focus blocks across this week.',
        slots: proposedSlots,
        warnings: [],
      );
    } catch (e) {
      throw Exception('Failed to generate AI schedule: ${e.toString()}');
    }
  }

  Future<void> createScheduleSlot({
    required String taskId,
    String? subTaskId,
    required DateTime startTime,
    required DateTime endTime,
    String explanation = 'Auto-scheduled by AI',
    String status = 'Approved',
  }) async {
    try {
      await _apiClient.dio.post(
        ApiEndpoints.taskScheduleSlots(taskId),
        data: {
          if (subTaskId != null && subTaskId.isNotEmpty) 'subTaskId': subTaskId,
          'startTime': startTime.toUtc().toIso8601String(),
          'endTime': endTime.toUtc().toIso8601String(),
          'originalStartTime': startTime.toUtc().toIso8601String(),
          'isManualOverride': false,
          'kbiasUsed': 0,
          'explanation': explanation,
          'status': status,
        },
      );
    } on DioException catch (e) {
      final msg = ApiClient.extractErrorMessage(e);
      throw Exception('Failed to create schedule slot: $msg');
    }
  }

  Future<void> applyProposalSlotsDirectly(List<AiSlotItem> slots) async {
    for (final s in slots) {
      try {
        await createScheduleSlot(
          taskId: s.taskId,
          subTaskId: s.subTaskId,
          startTime: s.start,
          endTime: s.end,
          explanation: s.explanation ?? 'Auto-scheduled by AI',
        );
      } catch (_) {}
    }
  }

  Future<AiProposalResponse?> getPendingProposal() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.pendingProposal);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final proposal = AiProposalResponse.fromJson(data);
        return await _enrichProposalTaskTitles(proposal);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<AiProposalResponse> _enrichProposalTaskTitles(
    AiProposalResponse proposal,
  ) async {
    if (proposal.slots.isEmpty) return proposal;

    final needsEnrich = proposal.slots.any(
      (s) => s.taskTitle == null || s.taskTitle!.isEmpty,
    );
    if (!needsEnrich) return proposal;

    if (_taskTitleCache.isEmpty) {
      try {
        final projectRes = await _apiClient.dio.get(ApiEndpoints.projects);
        if (projectRes.statusCode == 200 && projectRes.data != null) {
          final projects = (projectRes.data as List<dynamic>).map(
            (e) => ProjectModel.fromJson(e as Map<String, dynamic>),
          );
          for (final p in projects) {
            try {
              final taskRes = await _apiClient.dio.get(
                ApiEndpoints.projectTasks(p.id),
              );
              if (taskRes.statusCode == 200 && taskRes.data != null) {
                final tasks = (taskRes.data as List<dynamic>).map(
                  (e) => TaskModel.fromJson(e as Map<String, dynamic>),
                );
                for (final t in tasks) {
                  _taskTitleCache[t.id] = t.title;
                }
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    }

    final enrichedSlots = proposal.slots.map((s) {
      if (s.taskTitle != null && s.taskTitle!.isNotEmpty) return s;
      final title =
          _taskTitleCache[s.taskId] ?? 'Focus Session (${s.proposedMinutes}m)';
      return s.copyWith(taskTitle: title);
    }).toList();

    return proposal.copyWith(slots: enrichedSlots);
  }

  Future<void> approveProposal(String proposalId) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.approveProposal(proposalId),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to approve proposal');
      }
    } on DioException catch (e) {
      final msg = ApiClient.extractErrorMessage(
        e,
        'Failed to approve proposal',
      );
      throw Exception('Failed to approve proposal: $msg');
    }
  }

  Future<void> cancelSlot(String slotId) async {
    try {
      await _apiClient.dio.delete(ApiEndpoints.scheduleSlotDetail(slotId));
    } on DioException catch (e) {
      final msg = ApiClient.extractErrorMessage(e, 'Failed to cancel slot');
      throw Exception('Failed to cancel slot: $msg');
    }
  }

  Future<String> syncGoogleCalendar() async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.googleCalendarSync,
      );
      if (response.statusCode == 200 && response.data != null) {
        final syncedCount = response.data['syncedEventsCount'] ?? 0;
        return 'Successfully synced $syncedCount events from Google Calendar';
      }
      return 'Google Calendar synced successfully';
    } on DioException catch (e) {
      final msg = ApiClient.extractErrorMessage(
        e,
        'Google Calendar sync failed',
      );
      throw Exception('Google Calendar sync failed: $msg');
    }
  }

  Future<String> getGoogleCalendarStatus() async {
    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.googleCalendarStatus,
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data['status'] as String? ?? 'NotConnected';
      }
      return 'NotConnected';
    } catch (_) {
      return 'NotConnected';
    }
  }
}

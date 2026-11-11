import 'package:flutter_test/flutter_test.dart';
import 'package:metanoia_mobile/features/focus/models/focus_models.dart';

void main() {
  group('Focus Models Tests', () {
    test('FocusStartRequest serializes correctly', () {
      final req = FocusStartRequest(
        taskId: 'task-123',
        subTaskId: 'sub-456',
        scheduleSlotId: 'slot-789',
        focusTrackId: 'track-1',
      );

      final json = req.toJson();
      expect(json['taskId'], 'task-123');
      expect(json['subTaskId'], 'sub-456');
      expect(json['scheduleSlotId'], 'slot-789');
      expect(json['focusTrackId'], 'track-1');
    });

    test('FocusStartResponse deserializes correctly', () {
      final json = {
        'sessionId': 'sess-001',
        'startedAt': '2026-11-11T10:00:00Z',
        'captureMethod': 'Timer',
        'plannedMinutes': 45,
        'expectedEndAt': '2026-11-11T10:45:00Z',
        'startedEarlyMinutes': 10,
        'warning': null,
      };

      final res = FocusStartResponse.fromJson(json);
      expect(res.sessionId, 'sess-001');
      expect(res.captureMethod, 'Timer');
      expect(res.plannedMinutes, 45);
      expect(res.startedEarlyMinutes, 10);
      expect(res.expectedEndAt, isNotNull);
    });

    test('FocusCurrentResponse deserializes correctly', () {
      final json = {
        'sessionId': 'sess-002',
        'taskId': 'task-1',
        'taskTitle': 'Implement Focus UI',
        'subTaskId': 'sub-1',
        'subTaskTitle': 'Design Timer Widget',
        'scheduleSlotId': 'slot-1',
        'startedAt': '2026-11-11T10:00:00Z',
        'elapsedSeconds': 1500,
        'serverTime': '2026-11-11T10:25:00Z',
        'isOverrun': false,
      };

      final res = FocusCurrentResponse.fromJson(json);
      expect(res.sessionId, 'sess-002');
      expect(res.taskTitle, 'Implement Focus UI');
      expect(res.subTaskTitle, 'Design Timer Widget');
      expect(res.elapsedSeconds, 1500);
      expect(res.isOverrun, false);
    });

    test('FocusStopRequest serializes stop reason and note', () {
      final req = FocusStopRequest(
        stopReason: FocusStopReason.completed,
        note: 'Everything completed smoothly',
      );

      final json = req.toJson();
      expect(json['stopReason'], 'Completed');
      expect(json['note'], 'Everything completed smoothly');
    });

    test('FocusStopResponse deserializes session duration and task totals', () {
      final json = {
        'sessionId': 'sess-003',
        'endedAt': '2026-11-11T10:30:00Z',
        'sessionMinutes': 30,
        'taskTotalMinutes': 90,
        'checkInRequired': true,
      };

      final res = FocusStopResponse.fromJson(json);
      expect(res.sessionId, 'sess-003');
      expect(res.sessionMinutes, 30);
      expect(res.taskTotalMinutes, 90);
      expect(res.checkInRequired, true);
    });

    test('FocusPendingConfirmationItem deserializes correctly', () {
      final json = {
        'sessionId': 'sess-auto-1',
        'taskTitle': 'Long coding task',
        'startedAt': '2026-11-11T08:00:00Z',
        'endedAt': '2026-11-11T10:00:00Z',
        'durationMinutes': 120,
        'plannedMinutes': 60,
      };

      final item = FocusPendingConfirmationItem.fromJson(json);
      expect(item.sessionId, 'sess-auto-1');
      expect(item.durationMinutes, 120);
      expect(item.plannedMinutes, 60);
    });
  });
}


import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../features/assistant/data/assistant_repository.dart';
import '../features/assistant/models/assistant_turn.dart';
import '../features/assistant/models/briefing.dart';
import '../features/assistant/screens/assistant_screen.dart';
import '../features/schedule/data/reshuffle_repository.dart';
import '../features/schedule/models/reshuffle_models.dart';

/// Dev-only: the FR-22d card on a device with no login (plans/assistant-reshuffle.md T9).
/// The AI answer is the real one from the AI real run of 2026-11-26; the Backend is a
/// stand-in that only logs. Run:
///   flutter run -t lib/dev/reshuffle_preview_main.dart
void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: AssistantScreen(
        devUtterance:
            'Mai 2 giờ chiều đến 4 giờ tôi có việc gấp sửa lỗi cho khách',
        repository: _DemoAssistant(),
        reshuffle: _DemoBackend(),
      ),
    ),
  );
}

DateTime _tomorrow(int h, [int m = 0]) {
  final d = DateTime.now().add(const Duration(days: 1));
  return DateTime(d.year, d.month, d.day, h, m);
}

String _iso(DateTime t) => t.toUtc().toIso8601String();

Map<String, Object?> _insert({required bool clash, DateTime? start}) {
  final s = start ?? _tomorrow(14);
  final e = s.add(const Duration(hours: 2));
  return {
    'block': {'title': 'sửa lỗi cho khách', 'start': _iso(s), 'end': _iso(e)},
    'past_day_end': false,
    'project_id': null,
    'domain_id': 'coding',
    'moves': [
      {
        'slot_id': 'c',
        'task_title': 'Thiết kế banner',
        'old_start': _iso(_tomorrow(14, 30)),
        'old_end': _iso(_tomorrow(15, 30)),
        'new_start': _iso(_tomorrow(16, 10)),
        'new_end': _iso(_tomorrow(17, 10)),
      },
    ],
    'not_placed': <Object>[],
    'conflicts': clash
        ? [
            {
              'kind': 'fixed_task',
              'id': 'meeting',
              'title': 'Họp khách Lam Sơn',
              'start': _iso(_tomorrow(15)),
              'end': _iso(_tomorrow(15, 30)),
              'important': true,
              'why': 'client',
            },
          ]
        : <Object>[],
    'options': clash ? ['other_time', 'overwrite', 'cancel'] : <Object>[],
    'recommendation': clash ? 'other_time' : null,
    'other_time': clash
        ? {'start': _iso(_tomorrow(8)), 'end': _iso(_tomorrow(10))}
        : null,
    'skip_task_ids': clash ? ['meeting'] : <Object>[],
    'summary': clash
        ? 'Việc gấp từ 14 giờ ngày mai đến 16 giờ trùng với Họp khách Lam Sơn (việc với khách). '
              'Mình gợi ý làm từ 8 giờ ngày mai đến 10 giờ, hoặc bạn ghi đè hay hủy. Sẽ cần dời 1 việc.'
        : 'Thêm sửa lỗi cho khách từ 8 giờ ngày mai đến 10 giờ, không cần dời việc nào. Đồng ý không?',
  };
}

class _DemoAssistant implements AssistantRepository {
  @override
  Future<Turn> turn(
    String text,
    List<TurnHistoryEntry> history, {
    String? selectedId,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    final preview = _insert(clash: true);
    return Turn.fromJson({
      'kind': 'confirm',
      'tool': 'insert_block',
      'reply': preview['summary'],
      'emotion': 'thinking',
      'action': {'type': 'insert_block', 'preview': preview},
    });
  }

  @override
  Future<Briefing> getTodayBriefing() async => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DemoBackend extends ReshuffleRepository {
  _DemoBackend() : super(Dio(), Dio());

  @override
  Future<List<PickItem>> projects() async => const [
    (id: 'web', name: 'Web Lam Sơn'),
    (id: 'personal', name: 'Cá nhân'),
  ];

  @override
  Future<InsertPreview> previewInsert(
    String title,
    DateTime start,
    DateTime end,
  ) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final json = _insert(clash: false, start: start)..['moves'] = <Object>[];
    return InsertPreview.fromJson(json);
  }

  @override
  Future<({ReshuffleUndo undo, int failed})> applyInsert(
    InsertPreview preview, {
    required bool overwrite,
    required String projectId,
    required String domainId,
  }) async {
    debugPrint('[demo] applyInsert overwrite=$overwrite project=$projectId');
    await Future.delayed(const Duration(milliseconds: 600));
    return (
      undo: ReshuffleUndo(
        createdTaskId: 'urgent',
        slots: const [],
        skippedTasks: const [],
        appliedAt: DateTime.now(),
      ),
      failed: 0,
    );
  }

  @override
  Future<int> undo(ReshuffleUndo undo) async {
    debugPrint('[demo] undo');
    return 0;
  }
}

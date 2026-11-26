import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metanoia_mobile/features/assistant/data/assistant_repository.dart';
import 'package:metanoia_mobile/features/assistant/logic/assistant_controller.dart';
import 'package:metanoia_mobile/features/assistant/models/assistant_turn.dart';
import 'package:metanoia_mobile/features/assistant/models/briefing.dart';
import 'package:metanoia_mobile/features/assistant/widgets/reshuffle_card.dart';
import 'package:metanoia_mobile/features/schedule/data/reshuffle_repository.dart';
import 'package:metanoia_mobile/features/schedule/models/reshuffle_models.dart';

// FR-22d on the phone (plans/assistant-reshuffle.md): parsing, applying through the
// Backend with undo, the controller flow and the card. T1–T8.

class _FakeAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  _FakeAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object? body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

Dio _dio(_FakeAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://x.test'))..httpClientAdapter = adapter;

Map<String, Object?> _move(
  String id,
  String title,
  String oldStart,
  String newStart,
) => {
  'slot_id': id,
  'task_title': title,
  'old_start': '2026-11-27T$oldStart:00+07:00',
  'old_end': '2026-11-27T${_plus1(oldStart)}:00+07:00',
  'new_start': '2026-11-27T$newStart:00+07:00',
  'new_end': '2026-11-27T${_plus1(newStart)}:00+07:00',
};

String _plus1(String hm) =>
    '${(int.parse(hm.split(':')[0]) + 1).toString().padLeft(2, '0')}:${hm.split(':')[1]}';

// The body of a real run (AI scripts/try_reshuffle.py, 2026-11-26).
Map<String, Object?> _insert({bool clash = true, String? project}) => {
  'block': {
    'title': 'Sửa lỗi gấp',
    'start': '2026-11-27T14:00:00+07:00',
    'end': '2026-11-27T16:00:00+07:00',
  },
  'past_day_end': false,
  'project_id': project,
  'domain_id': 'coding',
  'moves': [_move('c', 'Thiết kế banner', '14:30', '16:10')],
  'not_placed': <Object>[],
  'conflicts': clash
      ? [
          {
            'kind': 'fixed_task',
            'id': 'meeting',
            'title': 'Họp khách Lam Sơn',
            'start': '2026-11-27T15:00:00+07:00',
            'end': '2026-11-27T15:30:00+07:00',
            'important': true,
            'why': 'client',
          },
        ]
      : <Object>[],
  'options': clash ? ['other_time', 'overwrite', 'cancel'] : <Object>[],
  'recommendation': clash ? 'other_time' : null,
  'other_time': clash
      ? {
          'start': '2026-11-27T08:00:00+07:00',
          'end': '2026-11-27T10:00:00+07:00',
        }
      : null,
  'skip_task_ids': clash ? ['meeting'] : <Object>[],
  'summary': 'Việc gấp trùng với Họp khách Lam Sơn.',
};

Turn _turn(String type, Map<String, Object?> preview, {String? slot}) =>
    Turn.fromJson({
      'kind': 'confirm',
      'tool': type,
      'reply': preview['summary'] ?? 'Đồng ý không?',
      'emotion': 'thinking',
      'action': {'type': type, 'slot_id': slot, 'preview': preview},
    });

final _postpone = {
  'slot_id': 'c',
  'task_title': 'Thiết kế banner',
  'move': _move('c', 'Thiết kế banner', '14:30', '08:00'),
  'not_placed': false,
  'summary': 'Dời Thiết kế banner sang 8 giờ ngày 28/11 nhé?',
};

void main() {
  group('T1 parsing', () {
    test('insert preview with a clash', () {
      final action = _turn('insert_block', _insert()).action!;
      final p = action.insert!;
      expect(action.type, TurnActionType.insertBlock);
      expect((p.title, p.start.hour, p.end.hour), ('Sửa lỗi gấp', 14, 16));
      expect(p.conflicts.single.whyLabel, 'việc với khách');
      expect(p.options, [
        BlockChoice.otherTime,
        BlockChoice.overwrite,
        BlockChoice.cancel,
      ]);
      expect(p.recommendation, BlockChoice.otherTime);
      expect(p.otherTime!.start.hour, 8);
      expect(p.skipTaskIds, ['meeting']);
      expect(p.moves.single.newStart.minute, 10);
    });

    test('postpone and catch up', () {
      expect(
        _turn('postpone', _postpone).action!.postponed!.move!.newStart.hour,
        8,
      );
      final catchUp = _turn('catch_up', {
        'moves': [_move('m1', 'Gửi báo giá', '09:00', '13:00')],
        'not_placed': [
          {'slot_id': 'm2', 'task_title': 'Email'},
        ],
        'summary': 'Có 2 việc bị lỡ.',
      }).action!.catchUp!;
      expect(catchUp.moves.length, 1);
      expect(catchUp.notPlaced, ['Email']);
    });

    test('a postpone without a move is not a usable action', () {
      expect(
        () => _turn('postpone', {..._postpone, 'move': null}),
        throwsFormatException,
      );
    });
  });

  group('T2–T4 applying through the Backend', () {
    late _FakeAdapter backend;
    late Map<String, String> slotStatus;
    late Map<String, String> taskStatus;
    late ReshuffleRepository repo;

    setUp(() {
      slotStatus = {'c': 'Approved', 'm1': 'Missed'};
      taskStatus = {'meeting': 'Scheduled'};
      backend = _FakeAdapter((o) async {
        final path = o.path;
        if (o.method == 'POST' && path.endsWith('/tasks')) {
          return _json(201, {'id': 'urgent'});
        }
        if (path.startsWith('/api/schedule-slots/')) {
          final id = path.split('/').last;
          if (o.method == 'GET') {
            return _json(200, {
              'subTaskId': 'sub',
              'explanation': 'old reason',
              'status': slotStatus[id],
            });
          }
          slotStatus[id] = (o.data as Map)['status'] as String;
          return _json(200, {});
        }
        if (path.startsWith('/api/tasks/')) {
          final id = path.split('/').last;
          if (o.method == 'GET') {
            return _json(200, {
              'title': 'Họp',
              'taskType': 'Fixed',
              'status': taskStatus[id],
              'domainId': 'd',
            });
          }
          if (o.method == 'PUT') {
            taskStatus[id] = (o.data as Map)['status'] as String;
          }
          return _json(200, {});
        }
        return _json(404, null);
      });
      repo = ReshuffleRepository(
        _dio(backend),
        _dio(_FakeAdapter((_) async => _json(500, null))),
      );
    });

    test('T2 insert: Fixed task, moved slot keeps its fields, overwrite skips the meeting', () async {
      final preview = InsertPreview.fromJson(_insert());
      final result = await repo.applyInsert(
        preview,
        overwrite: true,
        projectId: 'p1',
        domainId: 'coding',
      );

      expect(result.failed, 0);
      final create = backend.requests.first;
      expect((create.method, create.path), ('POST', '/api/projects/p1/tasks'));
      expect((create.data as Map)['taskType'], 'Fixed');
      expect((create.data as Map)['fixedStart'], '2026-11-27T07:00:00.000Z');
      final put = backend.requests.firstWhere(
        (r) => r.method == 'PUT' && r.path.contains('schedule-slots'),
      );
      expect((put.data as Map)['subTaskId'], 'sub');
      expect((put.data as Map)['explanation'], 'old reason');
      expect((put.data as Map)['startTime'], '2026-11-27T09:10:00.000Z');
      expect(taskStatus['meeting'], 'Skipped');
      expect(result.undo.createdTaskId, 'urgent');
      expect(result.undo.skippedTasks.single.status, 'Scheduled');
    });

    test(
      'T3 a Missed slot comes back as Approved; undo puts every change back',
      () async {
        final moves = [
          ReshuffleMove.fromJson(_move('m1', 'Gửi báo giá', '09:00', '13:00')),
        ];
        final result = await repo.applyMoves(moves);
        expect(slotStatus['m1'], 'Approved');

        final failed = await repo.undo(result.undo);
        expect(failed, 0);
        expect(slotStatus['m1'], 'Missed');
        final last = backend.requests.last;
        expect(
          (last.data as Map)['startTime'],
          '2026-11-27T02:00:00.000Z',
        ); // 09:00 +07
      },
    );

    test(
      'T4 undo of an insert deletes the new task and reopens the meeting',
      () async {
        final result = await repo.applyInsert(
          InsertPreview.fromJson(_insert()),
          overwrite: true,
          projectId: 'p1',
          domainId: 'coding',
        );
        await repo.undo(result.undo);
        expect(taskStatus['meeting'], 'Scheduled');
        expect(
          backend.requests.any(
            (r) => r.method == 'DELETE' && r.path == '/api/tasks/urgent',
          ),
          isTrue,
        );
      },
    );

    test('T4 the task cannot be created → nothing changes', () async {
      final failing = ReshuffleRepository(
        _dio(_FakeAdapter((_) async => _json(400, null))),
        _dio(backend),
      );
      expect(
        () => failing.applyInsert(
          InsertPreview.fromJson(_insert()),
          overwrite: false,
          projectId: 'p',
          domainId: 'd',
        ),
        throwsA(isA<ReshuffleException>()),
      );
    });
  });

  group('T5–T7 controller', () {
    late _Repository assistant;
    late _Reshuffle reshuffle;
    late AssistantController controller;
    late List<String> spoken;
    var now = DateTime(2026, 11, 26, 20);

    setUp(() {
      spoken = [];
      now = DateTime(2026, 11, 26, 20);
      reshuffle = _Reshuffle();
      assistant = _Repository(_turn('insert_block', _insert()));
      controller = AssistantController(
        repository: assistant,
        speak: (text) async {
          spoken.add(text);
          return true;
        },
        reshuffle: reshuffle,
        now: () => now,
      );
    });

    test(
      'T5 a clash shows the card; overwrite applies with the picked project',
      () async {
        await controller.ask('Mai 2 giờ chiều có việc gấp');
        expect(controller.proposal?.type, TurnActionType.insertBlock);
        expect(controller.suggestions, isEmpty); // the card holds the choices
        expect(controller.projectId, 'personal'); // "Cá nhân" preselected
        controller.selectProject('web');

        await controller.pick(BlockChoice.overwrite);
        expect(reshuffle.inserted.single, (overwrite: true, project: 'web'));
        expect(controller.proposal, isNull);
        expect(controller.canUndo, isTrue);
        expect(spoken.last, contains('Bấm Hoàn tác'));
        expect(controller.suggestions, [AssistantController.undoWord]);
      },
    );

    test(
      'T5 "Có" takes the suggestion: another time asks the AI again',
      () async {
        await controller.ask('Mai 2 giờ chiều có việc gấp');
        reshuffle.nextPreview = InsertPreview.fromJson(
          _insert(clash: false, project: 'p'),
        );

        await controller.ask('Có');
        expect(reshuffle.previews.single.start.hour, 8);
        expect(controller.proposal?.insert?.hasConflicts, isFalse);
        expect(controller.suggestions, [
          AssistantController.yes,
          AssistantController.no,
        ]);

        await controller.ask('Ok');
        expect(reshuffle.inserted.single, (overwrite: false, project: 'p'));
      },
    );

    test(
      'T6 postpone by voice, then undo by voice; undo closes after 5 minutes',
      () async {
        assistant.next = _turn('postpone', _postpone);
        await controller.ask('Để mai làm việc này');
        await controller.ask('Có');
        expect(reshuffle.moved.single.single.slotId, 'c');
        expect(
          spoken.last,
          startsWith('Đã dời Thiết kế banner sang 8:00 ngày 27/11.'),
        );

        await controller.ask('Hoàn tác');
        expect(reshuffle.undone, 1);
        expect(controller.canUndo, isFalse);

        await controller.ask('Để mai làm việc này');
        await controller.ask('Có');
        now = now.add(const Duration(minutes: 6));
        expect(controller.canUndo, isFalse);
      },
    );

    test('T7 cancel and "Không" change nothing', () async {
      await controller.ask('Mai 2 giờ chiều có việc gấp');
      await controller.pick(BlockChoice.cancel);
      expect(spoken.last, AssistantController.cancelled);

      assistant.next = _turn('postpone', _postpone);
      await controller.ask('Để mai');
      await controller.ask('Không');
      expect(reshuffle.inserted, isEmpty);
      expect(reshuffle.moved, isEmpty);
    });
  });

  testWidgets('T8 the card shows the clash, the moves and the choices', (
    tester,
  ) async {
    BlockChoice? picked;
    var tapped = false;
    final action = _turn('insert_block', _insert()).action!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReshuffleCard(
            action: action,
            projects: const [(id: 'p', name: 'Cá nhân')],
            projectId: 'p',
            onPick: (c) {
              picked = c;
              tapped = true;
            },
          ),
        ),
      ),
    );
    expect(
      find.text('Trùng: Họp khách Lam Sơn (việc với khách)'),
      findsOneWidget,
    );
    expect(find.text('Thiết kế banner'), findsOneWidget);
    expect(find.text('14:30 → 16:10'), findsOneWidget);
    expect(find.text('Cá nhân'), findsOneWidget);
    await tester.tap(find.text('Ghi đè'));
    expect((tapped, picked), (true, BlockChoice.overwrite));
    expect(find.text('Giờ khác 08:00–10:00'), findsOneWidget);
  });
}

class _Repository implements AssistantRepository {
  Turn next;

  _Repository(this.next);

  @override
  Future<Turn> turn(
    String text,
    List<TurnHistoryEntry> history, {
    String? selectedId,
  }) async => next;

  @override
  Future<Briefing> getTodayBriefing() async => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reshuffle extends ReshuffleRepository {
  final List<({bool overwrite, String project})> inserted = [];
  final List<List<ReshuffleMove>> moved = [];
  final List<({DateTime start, DateTime end})> previews = [];
  InsertPreview? nextPreview;
  int undone = 0;

  _Reshuffle() : super(Dio(), Dio());

  ReshuffleUndo _undo() => ReshuffleUndo(
    createdTaskId: 'x',
    slots: const [],
    skippedTasks: const [],
    appliedAt: DateTime(2026, 11, 26, 20),
  );

  @override
  Future<List<PickItem>> projects() async => const [
    (id: 'web', name: 'Web Lam Sơn'),
    (id: 'personal', name: 'Cá nhân'),
  ];

  @override
  Future<List<PickItem>> domains() async => const [
    (id: 'coding', name: 'Coding'),
  ];

  @override
  Future<InsertPreview> previewInsert(
    String title,
    DateTime start,
    DateTime end,
  ) async {
    previews.add((start: start, end: end));
    return nextPreview!;
  }

  @override
  Future<({ReshuffleUndo undo, int failed})> applyInsert(
    InsertPreview preview, {
    required bool overwrite,
    required String projectId,
    required String domainId,
  }) async {
    inserted.add((overwrite: overwrite, project: projectId));
    return (undo: _undo(), failed: 0);
  }

  @override
  Future<({ReshuffleUndo undo, int failed})> applyMoves(
    List<ReshuffleMove> moves,
  ) async {
    moved.add(moves);
    return (undo: _undo(), failed: 0);
  }

  @override
  Future<int> undo(ReshuffleUndo undo) async {
    undone++;
    return 0;
  }
}

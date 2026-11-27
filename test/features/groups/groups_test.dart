import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metanoia_mobile/features/groups/data/group_repository.dart';
import 'package:metanoia_mobile/features/groups/models/group_models.dart';
import 'package:metanoia_mobile/features/groups/screens/group_task_screen.dart';
import 'package:metanoia_mobile/features/groups/screens/groups_screen.dart';

// Work Group on the phone (plans/work-group.md): parsing, Backend / AI calls, screens.

class _Adapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions o) handler;
  final List<RequestOptions> requests = [];

  _Adapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) {
    requests.add(o);
    return handler(o);
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

Dio _dio(_Adapter a) =>
    Dio(BaseOptions(baseUrl: 'https://x.test'))..httpClientAdapter = a;

const _me = 'u-me';
const _other = 'u-other';

GroupTask _task({String? assignee = _me, int subTasks = 0, DateTime? fixed}) =>
    GroupTask(
      id: 't1',
      groupId: 'g1',
      title: 'Viết báo cáo',
      status: 'ToDo',
      assigneeId: assignee,
      assigneeName: assignee == null ? null : (assignee == _me ? 'Hiếu' : 'Tú'),
      estimatedMinutes: 120,
      subTaskCount: subTasks,
      fixedStart: fixed,
      fixedEnd: fixed?.add(const Duration(hours: 1)),
    );

class _Fake extends GroupRepository {
  GroupTask current;
  GroupRole role;
  final List<String> calls = [];
  bool busyOnce = false;

  _Fake({required this.current, this.role = GroupRole.member})
    : super(Dio(), Dio());

  @override
  Future<String?> myUserId() async => _me;

  @override
  Future<List<GroupSummary>> groups() async => [
    GroupSummary(id: 'g1', name: 'Capstone', myRole: role, memberCount: 2),
  ];

  @override
  Future<List<GroupInvitation>> invitations() async => const [
    GroupInvitation(id: 'i1', groupName: 'Lab AI', role: 'Member'),
  ];

  @override
  Future<List<MyGroupWork>> myWork() async => const [
    MyGroupWork(
      taskId: 't1',
      title: 'Viết báo cáo',
      status: 'ToDo',
      groupName: 'Capstone',
    ),
    MyGroupWork(
      taskId: 't9',
      title: 'Cũ',
      status: 'Done',
      groupName: 'Capstone',
    ),
  ];

  @override
  Future<GroupSummary> group(String id) async =>
      GroupSummary(id: id, name: 'Capstone', myRole: role);

  @override
  Future<List<GroupMember>> members(String groupId) async => const [
    GroupMember(
      userId: _me,
      fullName: 'Hiếu',
      email: 'h@x',
      role: GroupRole.leader,
    ),
    GroupMember(
      userId: _other,
      fullName: 'Tú',
      email: 't@x',
      role: GroupRole.member,
    ),
  ];

  @override
  Future<GroupTask> task(String taskId) async => current;

  @override
  Future<List<GroupSubTask>> subTasks(String taskId) async => const [];

  @override
  Future<GroupFocus?> currentFocus() async => null;

  @override
  Future<AssigneeSuggestions> suggestAssignees(
    String taskId, {
    String? domainId,
  }) async => const AssigneeSuggestions([
    AssigneeSuggestion(
      userId: _other,
      rank: 1,
      freeMinutes: 2700,
      fits: true,
      reason: 'Còn 45 giờ rảnh.',
    ),
    AssigneeSuggestion(userId: _me, rank: 2, freeMinutes: 365, fits: true),
  ], null);

  @override
  Future<void> assign(
    String taskId,
    String userId, {
    bool confirmConflicts = false,
  }) async {
    calls.add('assign $userId confirm=$confirmConflicts');
    if (busyOnce && !confirmConflicts) {
      throw const GroupException(
        'Tú đang bận giờ đó.',
        status: 409,
        code: 'GROUP_ASSIGNEE_BUSY',
      );
    }
  }
}

void main() {
  group('parsing', () {
    test('my group work reads taskId for tasks and parts', () {
      final work = MyGroupWork.listFromJson({
        'tasks': [
          {
            'taskId': 't1',
            'title': 'Báo cáo',
            'status': 'ToDo',
            'groupName': 'G',
            'deadline': '2026-11-30T10:00:00Z',
          },
        ],
        'subTasks': [
          {
            'subTaskId': 's1',
            'taskId': 't2',
            'taskTitle': 'Slide',
            'title': 'Phần 1',
            'status': 'InProgress',
          },
        ],
      });
      expect(
        [for (final w in work) (w.taskId, w.title)],
        [('t1', 'Báo cáo'), ('t2', 'Slide: Phần 1')],
      );
      expect(work.first.deadline, isNotNull);
    });

    test('AI suggestions: people sorted by rank, times keep their part', () {
      final who = AssigneeSuggestions.fromJson({
        'suggestions': [
          {'user_id': 'b', 'rank': 2, 'fits': null},
          {
            'user_id': 'a',
            'rank': 1,
            'fits': true,
            'busy_at_fixed_time': true,
            'reason': 'x',
          },
        ],
        'reasons_skipped': 'quota',
      });
      expect(who.suggestions.map((s) => s.userId), ['a', 'b']);
      expect(
        (who.suggestions.first.busyAtFixedTime, who.reasonsSkipped),
        (true, 'quota'),
      );

      final when = SlotSuggestions.fromJson({
        'slots': [
          {
            'subtask_id': 's3',
            'title': 'Báo cáo: Phần 3',
            'start': '2026-11-23T10:00:00+07:00',
            'end': '2026-11-23T11:00:00+07:00',
            'minutes': 60,
          },
        ],
        'warnings': [
          {'type': 'beyond_window'},
        ],
        'summary': 'Mình gợi ý 1 khung giờ.',
      });
      expect(when.slots.single.subtaskId, 's3');
      expect(when.slots.single.minutes, 60);
      expect(when.warnings, ['beyond_window']);
    });
  });

  group('calls', () {
    test('adding times skips the ones taken meanwhile (409)', () async {
      var n = 0;
      final backend = _Adapter(
        (o) async => _json(n++ == 1 ? 409 : 201, {'code': 'SLOT_OVERLAP'}),
      );
      final repo = GroupRepository(_dio(backend), Dio());
      final slot = SlotSuggestion(
        subtaskId: 's1',
        title: 'x',
        start: DateTime(2026, 11, 23, 10),
        end: DateTime(2026, 11, 23, 11),
        minutes: 60,
        reason: 'r',
      );
      expect(await repo.addSlots('t1', [slot, slot, slot]), 2);
      final body = backend.requests.first.data as Map;
      expect(
        (backend.requests.first.path, body['subTaskId'], body['status']),
        ('/api/group-tasks/t1/schedule-slots', 's1', 'Approved'),
      );
    });

    test(
      'assign sends confirmConflicts only when asked; busy keeps its code',
      () async {
        final backend = _Adapter((o) async {
          final confirm = (o.data as Map)['confirmConflicts'] == true;
          return confirm
              ? _json(200, {})
              : _json(409, {'code': 'GROUP_ASSIGNEE_BUSY', 'message': 'Bận.'});
        });
        final repo = GroupRepository(_dio(backend), Dio());
        await expectLater(
          repo.assign('t1', 'u'),
          throwsA(
            isA<GroupException>().having(
              (e) => e.code,
              'code',
              'GROUP_ASSIGNEE_BUSY',
            ),
          ),
        );
        await repo.assign('t1', 'u', confirmConflicts: true);
        expect((backend.requests.last.data as Map)['assigneeId'], 'u');
      },
    );

    test('AI errors are read from FastAPI "detail"', () async {
      final ai = _Adapter(
        (o) async => _json(409, {
          'detail': {'code': 'no_active_plan'},
        }),
      );
      final repo = GroupRepository(Dio(), _dio(ai));
      await expectLater(
        repo.suggestSlots('t1'),
        throwsA(
          isA<GroupException>().having(
            (e) => e.message,
            'message',
            'You have no active plan.',
          ),
        ),
      );
      expect(ai.requests.single.path, '/groups/tasks/t1/slot-suggestions');
    });
  });

  group('screens', () {
    testWidgets('Groups tab: invitation, open work only, my groups', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GroupsScreen(repository: _Fake(current: _task())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lab AI · as Member'), findsOneWidget);
      expect(find.text('Viết báo cáo'), findsOneWidget);
      expect(find.text('Cũ'), findsNothing); // done work is hidden
      expect(find.text('2 members'), findsOneWidget); // the group card
    });

    testWidgets('a member with the task: timer and times, no "Suggest who"', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GroupTaskScreen(
            taskId: 't1',
            repository: _Fake(current: _task()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Start timer'), findsOneWidget);
      expect(find.text('Suggest times'), findsOneWidget);
      expect(find.text('Suggest who'), findsNothing);
    });

    testWidgets('a fixed-time task has no time suggestion', (tester) async {
      final fake = _Fake(current: _task(fixed: DateTime(2026, 11, 30, 9)));
      await tester.pumpWidget(
        MaterialApp(
          home: GroupTaskScreen(taskId: 't1', repository: fake),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Suggest times'), findsNothing);
    });

    testWidgets(
      'the Leader picks from the AI list; a busy warning asks before assigning',
      (tester) async {
        final fake = _Fake(
          current: _task(assignee: null),
          role: GroupRole.leader,
        )..busyOnce = true;
        await tester.pumpWidget(
          MaterialApp(
            home: GroupTaskScreen(taskId: 't1', repository: fake),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Suggest who'));
        await tester.pumpAndSettle();
        expect(find.text('Tú'), findsOneWidget);
        expect(find.textContaining('Còn 45 giờ rảnh.'), findsOneWidget);

        await tester.tap(find.text('Tú'));
        await tester.pumpAndSettle();
        expect(find.text('This person looks busy'), findsOneWidget);
        await tester.tap(find.text('Assign'));
        await tester.pumpAndSettle();
        expect(fake.calls, [
          'assign $_other confirm=false',
          'assign $_other confirm=true',
        ]);
      },
    );
  });
}

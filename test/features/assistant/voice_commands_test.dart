import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metanoia_mobile/features/assistant/data/assistant_repository.dart';
import 'package:metanoia_mobile/features/assistant/data/command_repository.dart';
import 'package:metanoia_mobile/features/assistant/logic/assistant_controller.dart';
import 'package:metanoia_mobile/features/assistant/models/assistant_turn.dart';
import 'package:metanoia_mobile/features/assistant/models/briefing.dart';
import 'package:metanoia_mobile/features/assistant/widgets/avatar_view.dart';
import 'package:metanoia_mobile/features/schedule/data/overrun_repository.dart';
import 'package:metanoia_mobile/features/schedule/models/overrun_models.dart';

// FR-22c / W6-07 on the phone: confirm turns, yes / no, running the action.

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

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

Dio _dio(_FakeAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://x.test'))..httpClientAdapter = adapter;

class _Repository implements AssistantRepository {
  final List<String> asked = [];
  Turn next;

  _Repository(this.next);

  @override
  Future<Turn> turn(String text, List<TurnHistoryEntry> history, {String? selectedId}) async {
    asked.add(text);
    return next;
  }

  @override
  Future<Briefing> getTodayBriefing() async => throw UnimplementedError();
}

class _Commands extends CommandRepository {
  final List<TurnAction> ran = [];
  OverrunPlan? preview;

  _Commands() : super(Dio(), OverrunRepository(Dio(), Dio()));

  @override
  Future<OverrunPlan> previewExtend(TurnAction action) async => preview!;

  @override
  Future<String> run(TurnAction action, {OverrunPlan? plan}) async {
    ran.add(action);
    return 'Đã làm.';
  }
}

Turn _confirm(Map<String, Object?> action) => Turn.fromJson({
      'kind': 'confirm',
      'tool': 'x',
      'reply': 'Bắt đầu bấm giờ cho Viết blog nhé?',
      'emotion': 'thinking',
      'options': [],
      'suggestions': [],
      'action': action,
    });

const _start = {'type': 'start_timer', 'task_id': 't1', 'task_title': 'Viết blog', 'slot_id': 's1'};

void main() {
  group('Turn / TurnAction', () {
    test('a confirm turn carries its action', () {
      final turn = _confirm(_start);

      expect(turn.kind, TurnKind.confirm);
      expect(turn.action!.type, TurnActionType.startTimer);
      expect(turn.action!.slotId, 's1');
    });

    test('a confirm turn without a usable action is rejected', () {
      expect(() => _confirm({'type': 'delete_task'}), throwsFormatException);
      expect(() => _confirm({'type': 'stop_timer'}), throwsFormatException); // no session
      expect(
        () => Turn.fromJson({'kind': 'confirm', 'reply': 'x', 'emotion': 'neutral'}),
        throwsFormatException,
      );
    });
  });

  group('confirmation()', () {
    for (final yes in ['Có', 'ok', 'Ừ', 'Đồng ý', 'Ok làm đi', 'yes', 'Vâng']) {
      test('yes: $yes', () => expect(AssistantController.confirmation(yes), isTrue));
    }
    for (final no in ['Không', 'Thôi', 'Hủy', 'Không đồng ý', 'no', 'Khoan đã, thôi']) {
      test('no: $no', () => expect(AssistantController.confirmation(no), isFalse));
    }
    for (final other in ['Chiều nay tôi có lịch gì?', 'Còn bao nhiêu lượt AI', '']) {
      test('neither: $other', () => expect(AssistantController.confirmation(other), isNull));
    }
  });

  group('controller', () {
    late _Repository repository;
    late _Commands commands;
    late List<String> spoken;

    AssistantController make(Turn first) {
      repository = _Repository(first);
      commands = _Commands();
      spoken = [];
      return AssistantController(
        repository: repository,
        commands: commands,
        speak: (text) async {
          spoken.add(text);
          return true;
        },
      );
    }

    test('asks first, shows Có / Không, runs on yes without calling the AI again', () async {
      final c = make(_confirm(_start));

      await c.ask('Bắt đầu bấm giờ việc viết blog');

      expect(c.confirming, isTrue);
      expect(c.suggestions, [AssistantController.yes, AssistantController.no]);
      expect(commands.ran, isEmpty);

      c.startListening(); // the mic opens for the answer: the command is kept
      await c.ask('Có');

      expect(commands.ran.single.taskId, 't1');
      expect(repository.asked, hasLength(1)); // "Có" never reached the AI service
      expect(spoken.last, 'Đã làm.');
      expect(c.confirming, isFalse);
    });

    test('no cancels', () async {
      final c = make(_confirm(_start));
      await c.ask('Bắt đầu bấm giờ việc viết blog');

      await c.ask('Thôi');

      expect(commands.ran, isEmpty);
      expect(spoken.last, AssistantController.cancelled);
    });

    test('a new question drops the waiting command', () async {
      final c = make(_confirm(_start));
      await c.ask('Bắt đầu bấm giờ việc viết blog');
      repository.next = Turn(
        kind: TurnKind.answer,
        reply: 'Chiều nay bạn chưa có lịch nào.',
        emotion: AvatarEmotion.happy,
      );

      await c.ask('Chiều nay tôi có lịch gì?');
      await c.ask('Có');

      expect(commands.ran, isEmpty);
      expect(repository.asked, ['Bắt đầu bấm giờ việc viết blog', 'Chiều nay tôi có lịch gì?', 'Có']);
    });

    test('adding time shows what moves before asking', () async {
      final c = make(_confirm({'type': 'extend_timer', 'slot_id': 's1', 'minutes': 30}));
      commands.preview = OverrunPlan.fromJson({
        'kind': 'replan',
        'extended': {
          'slot_id': 's1',
          'start': '2026-11-12T02:00:00Z',
          'end': '2026-11-12T03:35:00Z',
        },
        'moves': [],
        'not_placed': [],
        'past_day_end': false,
        'summary': 'Để làm tiếp Viết blog đến 10 giờ 35, nên dời 1 việc: Thiết kế sang 13 giờ.',
      });

      await c.ask('Cần thêm nửa tiếng');

      expect(spoken.last, endsWith('Thiết kế sang 13 giờ. Áp dụng nhé?'));
      await c.ask('Ok');
      expect(commands.ran.single.type, TurnActionType.extendTimer);
    });
  });

  group('CommandRepository', () {
    test('start_timer posts the task and the slot', () async {
      final backend = _FakeAdapter((_) async => _json(200, {'sessionId': 'x'}));
      final repo = CommandRepository(_dio(backend), OverrunRepository(Dio(), Dio()));

      final said = await repo.run(TurnAction.fromJson(_start));

      expect(backend.requests.single.path, '/api/focus/start');
      expect(backend.requests.single.data, {'taskId': 't1', 'scheduleSlotId': 's1'});
      expect(said, startsWith('Đã bắt đầu bấm giờ cho Viết blog'));
    });

    test('finish posts Completed to the session', () async {
      final backend = _FakeAdapter((_) async => _json(200, {}));
      final repo = CommandRepository(_dio(backend), OverrunRepository(Dio(), Dio()));

      final said = await repo.run(TurnAction.fromJson({
        'type': 'stop_timer',
        'session_id': 'sess',
        'stop_reason': 'Completed',
        'task_title': 'Viết blog',
      }));

      expect(backend.requests.single.path, '/api/focus/sess/stop');
      expect(backend.requests.single.data, {'stopReason': 'Completed', 'note': null});
      expect(said, startsWith('Đã ghi nhận Viết blog là xong'));
    });

    test('approve posts to the proposal', () async {
      final backend = _FakeAdapter((_) async => _json(200, {}));
      final repo = CommandRepository(_dio(backend), OverrunRepository(Dio(), Dio()));

      await repo.run(TurnAction.fromJson({'type': 'approve_proposal', 'proposal_id': 'p1'}));

      expect(backend.requests.single.path, '/api/schedule/proposals/p1/approve');
    });

    test('a timer already running (409) is said plainly', () async {
      final backend = _FakeAdapter((_) async => _json(409, {}));
      final repo = CommandRepository(_dio(backend), OverrunRepository(Dio(), Dio()));

      expect(
        repo.run(TurnAction.fromJson(_start)),
        throwsA(isA<CommandException>().having(
          (e) => e.message,
          'message',
          'Bạn đang có một phiên bấm giờ khác, dừng nó trước nhé.',
        )),
      );
    });
  });
}

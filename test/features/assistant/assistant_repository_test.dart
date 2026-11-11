import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metanoia_mobile/core/services/storage_service.dart';
import 'package:metanoia_mobile/features/assistant/data/assistant_repository.dart';
import 'package:metanoia_mobile/features/assistant/models/assistant_turn.dart';
import 'package:metanoia_mobile/features/assistant/widgets/avatar_view.dart';

// T3 (AC6) — hand-written fake adapter, no extra package (plan decision #9).
class _FakeAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;
  RequestOptions? lastRequest;

  _FakeAdapter(this.handler);

  static _FakeAdapter json(int status, Object body) => _FakeAdapter(
        (_) async => ResponseBody.fromString(
          jsonEncode(body),
          status,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    lastRequest = options;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

class _FakeStorage extends StorageService {
  @override
  Future<String?> getAccessToken() async => 'jwt-123';
}

AssistantRepository _repository(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://ai.test'))..httpClientAdapter = adapter;
  return AssistantRepository(dio: dio, storageService: _FakeStorage());
}

Matcher _throwsKind(AssistantErrorKind kind) =>
    throwsA(isA<AssistantException>().having((e) => e.kind, 'kind', kind));

void main() {
  test('200 → Briefing, with JWT and language=vi', () async {
    final adapter = _FakeAdapter.json(200, {
      'calendar_connected': false,
      'schedule': [
        {'kind': 'slot', 'title': 'A'},
        {'kind': 'google', 'title': 'B'},
      ],
      'all_day': [
        {'title': 'Nghỉ lễ'},
      ],
      'top_tasks': [
        {
          'task_id': '1',
          'title': 'Viết landing page',
          'reasons': [
            {'code': 'deadline_soon', 'text': 'Hạn hôm nay.'},
          ],
        },
      ],
      'at_risk': [
        {'task_id': '1', 'title': 'Viết landing page', 'missing_minutes': 60},
      ],
    });

    final briefing = await _repository(adapter).getTodayBriefing();

    expect(briefing.calendarConnected, isFalse);
    expect(briefing.scheduleCount, 2);
    expect(briefing.topTasks.single.title, 'Viết landing page');
    expect(briefing.topTasks.single.reason, 'Hạn hôm nay.');
    expect(briefing.atRiskTitles, ['Viết landing page']);

    final request = adapter.lastRequest!;
    expect(request.path, '/briefing/today');
    expect(request.queryParameters, {'language': 'vi'});
    expect(request.headers['Authorization'], 'Bearer jwt-123');
  });

  test('401 → unauthorized', () async {
    final adapter = _FakeAdapter.json(401, {'detail': 'Token expired'});
    await expectLater(
      _repository(adapter).getTodayBriefing(),
      _throwsKind(AssistantErrorKind.unauthorized),
    );
  });

  test('500 → server', () async {
    final adapter = _FakeAdapter.json(500, {'detail': 'boom'});
    await expectLater(
      _repository(adapter).getTodayBriefing(),
      _throwsKind(AssistantErrorKind.server),
    );
  });

  test('timeout → network', () async {
    final adapter = _FakeAdapter(
      (options) async => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionTimeout,
      ),
    );
    await expectLater(
      _repository(adapter).getTodayBriefing(),
      _throwsKind(AssistantErrorKind.network),
    );
  });

  test('unexpected body → server, not fake data', () async {
    final adapter = _FakeAdapter.json(200, ['not', 'a', 'briefing']);
    await expectLater(
      _repository(adapter).getTodayBriefing(),
      _throwsKind(AssistantErrorKind.server),
    );
  });

  test('error messages are short user-facing sentences', () {
    expect(
      const AssistantException(AssistantErrorKind.unauthorized).message,
      startsWith('Phiên đăng nhập hết hạn'),
    );
    expect(
      const AssistantException(AssistantErrorKind.network).message,
      'Mình chưa kết nối được máy chủ, thử lại sau nhé.',
    );
  });

  // Agent plan T1 (AC4) — POST /assistant/turn.
  group('turn', () {
    Map<String, dynamic> turnJson(String kind, {Map<String, dynamic> extra = const {}}) => {
          'kind': kind,
          'tool': null,
          'reply': 'Câu trả lời.',
          'emotion': 'neutral',
          'options': [],
          'suggestions': [],
          ...extra,
        };

    test('200 answer → Turn, with JWT, language=vi and history', () async {
      final adapter = _FakeAdapter.json(
        200,
        turnJson('answer', extra: {
          'tool': 'today_briefing',
          'reply': 'Hôm nay bạn có 3 việc trên lịch.',
          'emotion': 'happy',
        }),
      );

      final turn = await _repository(adapter).turn(
        'Hôm nay tôi nên làm gì?',
        const [
          TurnHistoryEntry(TurnRole.user, 'Chào'),
          TurnHistoryEntry(TurnRole.assistant, 'Chào bạn!'),
        ],
      );

      expect(turn.kind, TurnKind.answer);
      expect(turn.tool, 'today_briefing');
      expect(turn.reply, 'Hôm nay bạn có 3 việc trên lịch.');
      expect(turn.emotion, AvatarEmotion.happy);

      final request = adapter.lastRequest!;
      expect(request.method, 'POST');
      expect(request.path, '/assistant/turn');
      expect(request.headers['Authorization'], 'Bearer jwt-123');
      expect(request.data, {
        'text': 'Hôm nay tôi nên làm gì?',
        'language': 'vi',
        'history': [
          {'role': 'user', 'text': 'Chào'},
          {'role': 'assistant', 'text': 'Chào bạn!'},
        ],
      });
    });

    test('selected_id is sent only when given', () async {
      final adapter = _FakeAdapter.json(200, turnJson('answer'));
      await _repository(adapter).turn('Dự án landing tới đâu rồi?', const [], selectedId: 'p-1');
      expect((adapter.lastRequest!.data as Map)['selected_id'], 'p-1');
    });

    test('200 clarify → at most 3 options, thinking', () async {
      final adapter = _FakeAdapter.json(
        200,
        turnJson('clarify', extra: {
          'emotion': 'thinking',
          'options': [
            for (var i = 1; i <= 4; i++) {'id': 'p-$i', 'title': 'Landing page $i'},
          ],
        }),
      );
      final turn = await _repository(adapter).turn('Landing tới đâu?', const []);
      expect(turn.kind, TurnKind.clarify);
      expect(turn.emotion, AvatarEmotion.thinking);
      expect(turn.options.map((o) => o.id), ['p-1', 'p-2', 'p-3']);
      expect(turn.options.first.title, 'Landing page 1');
    });

    test('200 unsupported → suggestions', () async {
      final adapter = _FakeAdapter.json(
        200,
        turnJson('unsupported', extra: {
          'suggestions': ['Hôm nay tôi nên làm gì?', 'Deadline nào đang gấp?'],
        }),
      );
      final turn = await _repository(adapter).turn('Bật timer giúp tôi', const []);
      expect(turn.kind, TurnKind.unsupported);
      expect(turn.tool, isNull);
      expect(turn.suggestions, ['Hôm nay tôi nên làm gì?', 'Deadline nào đang gấp?']);
    });

    test('200 smalltalk, unknown emotion → neutral', () async {
      final adapter = _FakeAdapter.json(200, turnJson('smalltalk', extra: {'emotion': 'excited'}));
      final turn = await _repository(adapter).turn('Cảm ơn nhé', const []);
      expect(turn.kind, TurnKind.smalltalk);
      expect(turn.emotion, AvatarEmotion.neutral);
    });

    for (final (status, kind) in [
      (401, AssistantErrorKind.unauthorized),
      (409, AssistantErrorKind.noPlan),
      (422, AssistantErrorKind.server),
      (429, AssistantErrorKind.quotaExceeded),
      (502, AssistantErrorKind.server),
    ]) {
      test('$status → ${kind.name}', () async {
        final adapter = _FakeAdapter.json(status, {'detail': 'x'});
        await expectLater(
          _repository(adapter).turn('Hôm nay tôi nên làm gì?', const []),
          _throwsKind(kind),
        );
      });
    }

    test('timeout → network', () async {
      final adapter = _FakeAdapter(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        ),
      );
      await expectLater(
        _repository(adapter).turn('Hôm nay tôi nên làm gì?', const []),
        _throwsKind(AssistantErrorKind.network),
      );
    });

    test('unknown kind or empty reply → server, not fake data', () async {
      for (final body in [
        turnJson('confirm'),
        turnJson('answer', extra: {'reply': '  '}),
        ['not', 'a', 'turn'],
      ]) {
        await expectLater(
          _repository(_FakeAdapter.json(200, body)).turn('Hôm nay tôi nên làm gì?', const []),
          _throwsKind(AssistantErrorKind.server),
          reason: '$body',
        );
      }
    });
  });
}

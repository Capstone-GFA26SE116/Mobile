import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metanoia_mobile/core/services/storage_service.dart';
import 'package:metanoia_mobile/features/assistant/data/assistant_repository.dart';

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
}

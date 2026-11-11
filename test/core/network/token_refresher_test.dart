import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metanoia_mobile/core/network/token_refresher.dart';
import 'package:metanoia_mobile/core/services/storage_service.dart';

// Hand-written fake adapter, no extra package (like the assistant repository tests).
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

Map<String, Object> _auth(String access, String refresh) => {
  'userId': 'u1',
  'email': 'a@b.c',
  'fullName': 'A',
  'role': 'User',
  'accessToken': access,
  'refreshToken': refresh,
};

/// In-memory session, so tests never touch the secure-storage plugin.
class _MemoryStorage extends StorageService {
  String? access;
  String? refresh;

  _MemoryStorage({this.access, this.refresh});

  @override
  Future<String?> getAccessToken() async => access;

  @override
  Future<String?> getRefreshToken() async => refresh;

  @override
  Future<void> saveAuthData({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String email,
    required String fullName,
    required String role,
  }) async {
    access = accessToken;
    refresh = refreshToken;
  }

  @override
  Future<void> clearAuth() async {
    access = null;
    refresh = null;
  }
}

class _Setup {
  final _MemoryStorage storage;
  final _FakeAdapter backend; // the refresh endpoint
  final _FakeAdapter api; // the API being called
  final Dio dio;

  _Setup(this.storage, this.backend, this.api, this.dio);

  factory _Setup.create({
    required Future<ResponseBody> Function(RequestOptions) refresh,
    required Future<ResponseBody> Function(RequestOptions) api,
  }) {
    final storage = _MemoryStorage(
      access: 'old-access',
      refresh: 'old-refresh',
    );
    final backend = _FakeAdapter(refresh);
    final refresher = TokenRefresher(
      storage: storage,
      dio: Dio(BaseOptions(baseUrl: 'https://backend.test'))
        ..httpClientAdapter = backend,
    );
    final apiAdapter = _FakeAdapter(api);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = apiAdapter;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.headers['Authorization'] =
              'Bearer ${await storage.getAccessToken()}';
          handler.next(options);
        },
      ),
    );
    dio.interceptors.add(RefreshOnUnauthorized(dio, refresher: refresher));
    return _Setup(storage, backend, apiAdapter, dio);
  }
}

/// 401 for the old token, 200 for the new one.
Future<ResponseBody> _okWithNewToken(RequestOptions o) async =>
    o.headers['Authorization'] == 'Bearer new-access'
    ? _json(200, {'ok': true})
    : _json(401, {'detail': 'expired'});

void main() {
  test(
    '401 → refresh once → retry with the new token → 200; new tokens saved',
    () async {
      final s = _Setup.create(
        refresh: (o) async => _json(200, _auth('new-access', 'new-refresh')),
        api: _okWithNewToken,
      );

      final response = await s.dio.get<dynamic>('/api/me');

      expect(response.statusCode, 200);
      expect(s.backend.requests, hasLength(1));
      expect(s.backend.requests.single.data, {'refreshToken': 'old-refresh'});
      expect(s.api.requests, hasLength(2));
      expect(s.storage.access, 'new-access');
      expect(s.storage.refresh, 'new-refresh');
    },
  );

  test('parallel 401s share one refresh (the Backend revokes the old refresh token)', () async {
    final gate = Completer<void>();
    final s = _Setup.create(
      refresh: (o) async {
        await gate.future;
        return _json(200, _auth('new-access', 'new-refresh'));
      },
      api: _okWithNewToken,
    );

    final calls = [
      s.dio.get<dynamic>('/a'),
      s.dio.get<dynamic>('/b'),
      s.dio.get<dynamic>('/c'),
    ];
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    final responses = await Future.wait(calls);

    expect(responses.map((r) => r.statusCode), everyElement(200));
    expect(s.backend.requests, hasLength(1));
  });

  test(
    'refresh token refused (401) → session cleared, caller gets the 401',
    () async {
      final s = _Setup.create(
        refresh: (o) async => _json(401, {'code': 'INVALID_REFRESH_TOKEN'}),
        api: _okWithNewToken,
      );

      await expectLater(
        s.dio.get<dynamic>('/api/me'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            401,
          ),
        ),
      );
      expect(s.storage.access, isNull);
      expect(s.storage.refresh, isNull);
    },
  );

  test('refresh times out (cold Backend) → session kept, caller gets the timeout, not 401', () async {
    final s = _Setup.create(
      refresh: (o) async => throw DioException.receiveTimeout(
        timeout: const Duration(seconds: 60),
        requestOptions: o,
      ),
      api: _okWithNewToken,
    );

    await expectLater(
      s.dio.get<dynamic>('/api/me'),
      throwsA(
        isA<DioException>()
            .having((e) => e.type, 'type', DioExceptionType.receiveTimeout)
            .having((e) => e.response?.statusCode, 'status', isNull),
      ),
    );
    expect(s.storage.refresh, 'old-refresh');
  });

  test('retry still 401 → no second refresh, no loop', () async {
    final s = _Setup.create(
      refresh: (o) async => _json(200, _auth('new-access', 'new-refresh')),
      api: (o) async => _json(401, {'detail': 'forbidden'}),
    );

    await expectLater(
      s.dio.get<dynamic>('/api/me'),
      throwsA(isA<DioException>()),
    );
    expect(s.backend.requests, hasLength(1));
    expect(s.api.requests, hasLength(2));
  });

  test('other errors are left alone', () async {
    final s = _Setup.create(
      refresh: (o) async => _json(200, _auth('new-access', 'new-refresh')),
      api: (o) async => _json(500, {'detail': 'boom'}),
    );

    await expectLater(
      s.dio.get<dynamic>('/api/me'),
      throwsA(isA<DioException>()),
    );
    expect(s.backend.requests, isEmpty);
  });

  test('no refresh token stored → caller gets the 401, nothing sent to the Backend', () async {
    final s = _Setup.create(
      refresh: (o) async => _json(200, _auth('new-access', 'new-refresh')),
      api: _okWithNewToken,
    );
    s.storage.refresh = null;

    await expectLater(
      s.dio.get<dynamic>('/api/me'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          401,
        ),
      ),
    );
    expect(s.backend.requests, isEmpty);
  });
}

import 'package:dio/dio.dart';

import '../../features/auth/models/auth_response.dart';
import '../config/app_config.dart';
import '../constants/api_endpoints.dart';
import '../services/storage_service.dart';

/// The Backend refused the stored refresh token (400/401): the user must sign in again.
class SessionExpiredException implements Exception {
  const SessionExpiredException();

  @override
  String toString() => 'SessionExpiredException';
}

/// Renews the session with the stored refresh token (W1-03).
///
/// One refresh at a time, shared by every caller: the Backend revokes the old refresh token
/// on each refresh, so two parallel refreshes would log the user out.
class TokenRefresher {
  static final TokenRefresher instance = TokenRefresher();

  final StorageService _storage;
  // Built on first use: AppConfig reads .env, which is not loaded yet when clients are created.
  late final Dio _dio = _injectedDio ?? _backendDio();
  final Dio? _injectedDio;
  Future<AuthResponse>? _running;

  TokenRefresher({StorageService? storage, Dio? dio})
    : _storage = storage ?? StorageService(),
      _injectedDio = dio;

  static Dio _backendDio() => Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      // Long enough for a cold Backend on Azure: a refresh that times out on the
      // phone may still succeed on the server and revoke the token we hold.
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  /// New tokens, already saved. Throws [SessionExpiredException] (and clears the stored
  /// session) when the Backend refuses the refresh token; a timeout or network error
  /// keeps the session so the next try can still work.
  Future<AuthResponse> refresh() {
    return _running ??= _refresh().whenComplete(() => _running = null);
  }

  Future<AuthResponse> _refresh() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const SessionExpiredException();
    }
    final Response<dynamic> response;
    try {
      response = await _dio.post(
        ApiEndpoints.refreshToken,
        data: {'refreshToken': refreshToken},
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 400 || status == 401) {
        await _storage.clearAuth();
        throw const SessionExpiredException();
      }
      rethrow;
    }
    final auth = AuthResponse.fromJson(response.data as Map<String, dynamic>);
    await _storage.saveAuthData(
      accessToken: auth.accessToken,
      refreshToken: auth.refreshToken,
      userId: auth.userId,
      email: auth.email,
      fullName: auth.fullName,
      role: auth.role,
    );
    return auth;
  }
}

/// On 401: renew the session once, then send the request again with the new token.
/// Add it to every Dio that sends the user's JWT (Backend and AI service).
class RefreshOnUnauthorized extends Interceptor {
  static const String _retriedKey = 'auth_retried';

  final Dio _dio;
  final TokenRefresher _refresher;

  RefreshOnUnauthorized(this._dio, {TokenRefresher? refresher})
    : _refresher = refresher ?? TokenRefresher.instance;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 || options.extra[_retriedKey] == true) {
      return handler.next(err);
    }
    try {
      final auth = await _refresher.refresh();
      options.extra[_retriedKey] = true;
      options.headers['Authorization'] = 'Bearer ${auth.accessToken}';
      return handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      // A refresh that timed out (not a 401) or the retried request's own error.
      return handler.next(e);
    } catch (_) {
      // Session expired, or storage not available: the caller sees the original 401.
      return handler.next(err);
    }
  }
}

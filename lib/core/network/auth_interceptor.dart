import 'dart:async';

import 'package:dio/dio.dart';

import '../../features/auth/infrastructure/datasources/auth_remote_data_source.dart';
import '../storage/secure_storage_service.dart';

/// Attaches the current access token to outgoing requests. When any request
/// comes back 401, tries a single refresh + retry before surfacing the error
/// so an expired access token is invisible to the app.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage, this._remoteFactory);

  final SecureStorageService _storage;
  // Passed as a factory to break the DI cycle: AuthInterceptor is needed to
  // build Dio, and AuthRemoteDataSource uses that same Dio. Late-binding via
  // the factory means we only resolve the data source at request time, after
  // the whole graph is wired.
  final AuthRemoteDataSource Function() _remoteFactory;

  // Custom flag on RequestOptions.extra — the retry request sets this so we
  // never try to refresh on the *retry* if it also 401s.
  static const _kSkipRefresh = 'auth_skip_refresh';

  // Serialize concurrent refreshes: if 3 parallel requests all get 401 at
  // once, we do exactly one POST /auth/refresh and share the result.
  Future<String?>? _inflightRefresh;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final isUnauthorized = response?.statusCode == 401;
    final skipRefresh = err.requestOptions.extra[_kSkipRefresh] == true;
    // /auth/refresh returning 401 must never trigger another refresh — that
    // means the refresh token itself is dead.
    final isRefreshCall = err.requestOptions.path.contains('/auth/refresh');

    if (!isUnauthorized || skipRefresh || isRefreshCall) {
      return handler.next(err);
    }

    final newToken = await _refreshOnce();
    if (newToken == null) {
      // Refresh failed → clear and surface the original 401. The auth
      // controller's next bootstrap will detect the empty storage and route
      // back to login.
      await _storage.clear();
      return handler.next(err);
    }

    // Retry the original request with the fresh token, marked so this
    // interceptor won't try to refresh again if it 401s a second time.
    final retryOptions = err.requestOptions.copyWith(
      extra: {...err.requestOptions.extra, _kSkipRefresh: true},
    );
    retryOptions.headers['Authorization'] = 'Bearer $newToken';

    try {
      // Use a fresh Dio instance to bypass this interceptor entirely on the
      // retry — otherwise onError could recurse if the new token also fails.
      final retryDio = Dio(BaseOptions(
        baseUrl: err.requestOptions.baseUrl,
        headers: {
          for (final e in err.requestOptions.headers.entries) e.key: e.value,
        },
      ));
      final response = await retryDio.fetch(retryOptions);
      handler.resolve(response);
    } on DioException catch (retryErr) {
      handler.next(retryErr);
    }
  }

  Future<String?> _refreshOnce() {
    // If another request is already refreshing, piggyback on that.
    final inflight = _inflightRefresh;
    if (inflight != null) return inflight;

    final future = _doRefresh();
    _inflightRefresh = future;
    future.whenComplete(() => _inflightRefresh = null);
    return future;
  }

  Future<String?> _doRefresh() async {
    try {
      final refreshToken = await _storage.readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return null;
      final tokens = await _remoteFactory().refresh(refreshToken);
      await _storage.writeTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      return tokens.accessToken;
    } catch (_) {
      return null;
    }
  }
}

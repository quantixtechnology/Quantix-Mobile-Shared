import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../branding/brand_provider.dart';
import '../config/app_config.dart';
import '../exceptions/app_exception.dart';
import '../storage/secure_storage.dart';

class ApiClient {
  late final Dio _dio;
  final String tenantId;

  ApiClient(SecureStorage storage, {required this.tenantId}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(milliseconds: AppConfig.connectTimeout),
        receiveTimeout: const Duration(milliseconds: AppConfig.receiveTimeout),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(_TenantInterceptor(tenantId));
    _dio.interceptors.add(_AuthInterceptor(storage, _dio));
  }

  Dio get dio => _dio;
}

class _TenantInterceptor extends Interceptor {
  final String _tenantId;
  _TenantInterceptor(this._tenantId);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['X-Business-ID'] = _tenantId;
    handler.next(options);
  }
}

class _AuthInterceptor extends Interceptor {
  final SecureStorage _storage;
  final Dio _dio;
  bool _isRefreshing = false;

  _AuthInterceptor(this._storage, this._dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
      debugPrint('[API] Bearer ✓ → ${options.method} ${options.path}');
    } else {
      debugPrint('[API] No token → ${options.method} ${options.path}');
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 || _isRefreshing) {
      handler.next(err);
      return;
    }

    // Skip refresh for auth endpoints themselves (avoids loops)
    final path = err.requestOptions.path;
    if (path.contains('/auth/refresh') ||
        path.contains('/auth/login') ||
        path.contains('/auth/verify-otp') ||
        path.contains('/auth/send-otp')) {
      handler.next(err);
      return;
    }

    _isRefreshing = true;
    debugPrint('[AUTH REFRESH] 401 on ${err.requestOptions.path} — attempting token refresh');

    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        debugPrint('[AUTH REFRESH] no refresh token stored — clearing auth');
        await _storage.clearAll();
        _isRefreshing = false;
        handler.next(_unauthorizedError(err));
        return;
      }

      final refreshDio = Dio(BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));

      debugPrint('[AUTH REFRESH] POST /api/core/auth/refresh');
      final res = await refreshDio.post('/api/core/auth/refresh', data: {
        'refreshToken': refreshToken,
      });

      final newAccess = res.data['accessToken'] as String?
          ?? res.data['token'] as String?;
      if (newAccess == null) throw Exception('No accessToken in refresh response');

      final newRefresh = res.data['refreshToken'] as String?;
      await _storage.saveToken(newAccess);
      if (newRefresh != null) await _storage.saveRefreshToken(newRefresh);
      debugPrint('[AUTH REFRESH] token refreshed ✓ — retrying original request');

      final opts = err.requestOptions;
      opts.headers['Authorization'] = 'Bearer $newAccess';
      final retryRes = await _dio.fetch(opts);
      handler.resolve(retryRes);

    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        // Refresh token itself is revoked/expired — full logout required
        debugPrint('[AUTH REFRESH] refresh token rejected ($status) — clearing auth');
        await _storage.clearAll();
        handler.next(_unauthorizedError(err));
      } else {
        // Network error during refresh — do NOT clear tokens, let app use
        // cached user until connectivity returns
        debugPrint('[AUTH REFRESH] network error during refresh (${e.type}) — keeping tokens');
        handler.next(err);
      }
    } catch (e) {
      debugPrint('[AUTH REFRESH] unexpected error: $e — keeping tokens');
      handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }

  DioException _unauthorizedError(DioException original) => DioException(
        requestOptions: original.requestOptions,
        response: original.response,
        error: const UnauthorizedException(),
        type: DioExceptionType.badResponse,
      );
}

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final brand = ref.watch(brandConfigProvider);
  return ApiClient(storage, tenantId: brand.businessId);
});

import 'package:dio/dio.dart';
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
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 || _isRefreshing) {
      handler.next(err);
      return;
    }

    // Mark refresh in-flight so concurrent 401s don't stack
    _isRefreshing = true;
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        await _storage.clearAll();
        _isRefreshing = false;
        handler.next(err);
        return;
      }

      // Use a fresh Dio instance to avoid interceptor loops
      final refreshDio = Dio(BaseOptions(baseUrl: AppConfig.baseUrl));
      final res = await refreshDio.post('/auth/refresh', data: {
        'refreshToken': refreshToken,
      });

      final newAccess = res.data['accessToken'] as String;
      final newRefresh = res.data['refreshToken'] as String?;
      await _storage.saveToken(newAccess);
      if (newRefresh != null) await _storage.saveRefreshToken(newRefresh);

      // Retry original request with fresh token
      final opts = err.requestOptions;
      opts.headers['Authorization'] = 'Bearer $newAccess';
      final retryRes = await _dio.fetch(opts);
      handler.resolve(retryRes);
    } catch (_) {
      await _storage.clearAll();
      handler.next(DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        error: const UnauthorizedException(),
        type: DioExceptionType.badResponse,
      ));
    } finally {
      _isRefreshing = false;
    }
  }
}

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final brand = ref.watch(brandConfigProvider);
  return ApiClient(storage, tenantId: brand.businessId);
});

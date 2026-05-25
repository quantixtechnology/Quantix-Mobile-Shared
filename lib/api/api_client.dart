import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../branding/brand_provider.dart';
import '../config/app_config.dart';
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
    _dio.interceptors.add(_AuthInterceptor(storage));
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

  _AuthInterceptor(this._storage);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err);
  }
}

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final brand = ref.watch(brandConfigProvider);
  return ApiClient(storage, tenantId: brand.businessId);
});

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../exceptions/app_exception.dart';
import '../storage/secure_storage.dart';
import 'user_model.dart';

class AuthService {
  final ApiClient _api;
  final SecureStorage _storage;

  AuthService(this._api, this._storage);

  // ── Customer: email → OTP ───────────────────────────────────────────────

  Future<void> requestEmailOtp(String email) async {
    debugPrint('[AUTH] POST /api/core/auth/send-otp email=$email');
    try {
      final res = await _api.dio.post('/api/core/auth/send-otp', data: {
        'email': email.trim(),
        'channel': 'EMAIL_OTP',
      });
      debugPrint('[AUTH] send-otp → status=${res.statusCode} body=${res.data}');
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) {
        throw ValidationException(body['error'] as String? ?? 'Failed to send OTP');
      }
    } on DioException catch (e) {
      debugPrint('[AUTH] send-otp DioException: ${e.response?.statusCode} ${e.response?.data}');
      throw _mapDioError(e);
    }
  }

  Future<UserModel> verifyOtp(String email, String code) async {
    final effectiveUrl = '${_api.dio.options.baseUrl}/api/core/auth/verify-otp';
    final payload = {'email': email.trim(), 'code': code.trim(), 'channel': 'EMAIL_OTP'};
    debugPrint('[VERIFY] START email=$email code=$code');
    debugPrint('[VERIFY] API URL: $effectiveUrl');
    debugPrint('[VERIFY] BODY: $payload');
    try {
      final res = await _api.dio.post(
        '/api/core/auth/verify-otp',
        data: payload,
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );
      debugPrint('[VERIFY] RESPONSE status=${res.statusCode}');
      debugPrint('[VERIFY] RESPONSE body=${res.data}');
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) {
        debugPrint('[VERIFY] success=false error=${body['error']}');
        throw ValidationException(body['error'] as String? ?? 'Invalid OTP');
      }
      final data = body['data'] as Map<String, dynamic>;
      final token = data['token'] as String;
      final userJson = data['user'] as Map<String, dynamic>;
      final businesses = data['businesses'] as List<dynamic>;
      final businessId = businesses.isNotEmpty
          ? (businesses[0] as Map<String, dynamic>)['businessId'] as String? ?? _api.tenantId
          : _api.tenantId;
      await _storeTokens(token: token, userId: userJson['id'] as String);
      debugPrint('[VERIFY] PARSED USER: ${userJson['name']} (${userJson['id']}) businessId=$businessId');
      debugPrint('[VERIFY] NAVIGATION TARGET: /home');
      return UserModel.fromBackend(userJson, businessId: businessId);
    } on DioException catch (e) {
      debugPrint('[VERIFY] DioException type=${e.type} status=${e.response?.statusCode} body=${e.response?.data}');
      throw _mapDioError(e);
    } catch (e, st) {
      debugPrint('[VERIFY] Unexpected error: $e');
      debugPrint('[VERIFY] Stacktrace: $st');
      if (e is AppException) rethrow;
      throw ServerException('Verification failed: ${e.runtimeType}');
    }
  }

  // ── Session restore ──────────────────────────────────────────────────────

  Future<UserModel?> restoreSession() async {
    final token = await _storage.getToken();
    debugPrint('[AUTH] restoreSession hasToken=${token != null}');
    if (token == null) return null;

    String? userId;
    try {
      final payload = jsonDecode(utf8.decode(base64Decode(base64.normalize(token))));
      userId = payload['userId'] as String?;
      final exp = payload['exp'] as int?;
      if (exp != null && DateTime.now().millisecondsSinceEpoch > exp) {
        debugPrint('[AUTH] token expired');
        await _storage.clearAll();
        return null;
      }
    } catch (_) {
      debugPrint('[AUTH] invalid token format');
      await _storage.clearAll();
      return null;
    }

    if (userId == null) {
      await _storage.clearAll();
      return null;
    }

    debugPrint('[AUTH] GET /api/core/auth/me?userId=$userId');
    try {
      final res = await _api.dio.get('/api/core/auth/me', queryParameters: {'userId': userId});
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) {
        await _storage.clearAll();
        return null;
      }
      final data = body['data'] as Map<String, dynamic>;
      final userJson = data['user'] as Map<String, dynamic>;
      final businesses = data['businesses'] as List<dynamic>;
      final businessId = businesses.isNotEmpty
          ? (businesses[0] as Map<String, dynamic>)['businessId'] as String? ?? _api.tenantId
          : _api.tenantId;
      return UserModel.fromBackend(userJson, businessId: businessId);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 404) {
        await _storage.clearAll();
      }
      return null;
    }
  }

  // ── Rider / Admin: email + password ─────────────────────────────────────

  Future<UserModel> loginWithPassword({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    debugPrint('[AUTH] POST /api/core/auth/login email=$email role=${role.name}');
    try {
      final res = await _api.dio.post('/api/core/auth/login', data: {
        'email': email,
        'password': password,
        'role': role.name,
        'businessId': _api.tenantId,
      });
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) {
        throw ValidationException(body['error'] as String? ?? 'Login failed');
      }
      final data = body['data'] as Map<String, dynamic>;
      final token = data['token'] as String;
      final userJson = data['user'] as Map<String, dynamic>;
      await _storeTokens(token: token, userId: userJson['id'] as String);
      return UserModel.fromBackend(userJson, businessId: _api.tenantId);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  // ── Logout ───────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await _storage.clearAll();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<void> _storeTokens({required String token, required String userId}) async {
    await _storage.saveToken(token);
    await _storage.saveUserId(userId);
  }

  AppException _mapDioError(DioException e) {
    final status = e.response?.statusCode;
    String message = 'Request failed';
    if (e.response?.data is Map) {
      message = (e.response!.data['error'] as String?) ??
          (e.response!.data['message'] as String?) ??
          'Request failed';
    }
    if (status == 401) return ValidationException(message.isNotEmpty ? message : 'Invalid or expired OTP');
    if (status == 429) return ValidationException('Too many requests. Try again later.');
    if (status == 422 || status == 400) return ValidationException(message);
    if (status != null && status >= 500) return ServerException(message, statusCode: status);
    return NetworkException(message, statusCode: status);
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  final api = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthService(api, storage);
});

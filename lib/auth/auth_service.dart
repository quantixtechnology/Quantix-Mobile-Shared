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

  Future<String?> requestEmailOtp(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    debugPrint('[AUTH] ── requestEmailOtp ──────────────────────');
    debugPrint('[AUTH] POST /api/core/auth/send-otp email=$normalizedEmail businessId=${_api.tenantId}');
    try {
      final res = await _api.dio.post('/api/core/auth/send-otp', data: {
        'email': normalizedEmail,
        'channel': 'EMAIL_OTP',
        'businessId': _api.tenantId,
      });
      debugPrint('[AUTH] send-otp status=${res.statusCode} body=${res.data}');
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) {
        throw ValidationException(body['error'] as String? ?? 'Failed to send OTP');
      }
      final devOtp = body['devOtp'] as String?;
      debugPrint('[AUTH] send-otp devOtp=${devOtp ?? 'null (email mode)'}');
      return devOtp;
    } on DioException catch (e) {
      debugPrint('[AUTH] send-otp DioException: status=${e.response?.statusCode} body=${e.response?.data}');
      throw _mapDioError(e);
    }
  }

  Future<UserModel> verifyOtp(String email, String code) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedCode = code.trim();
    debugPrint('[AUTH] ── verifyOtp ──────────────────────────────');
    final url = '${_api.dio.options.baseUrl}/api/core/auth/verify-otp';
    final payload = {
      'email': normalizedEmail,
      'code': normalizedCode,
      'channel': 'EMAIL_OTP',
      'businessId': _api.tenantId,
    };
    debugPrint('[AUTH] POST $url');
    debugPrint('[AUTH] body: $payload');
    try {
      final res = await _api.dio.post(
        '/api/core/auth/verify-otp',
        data: payload,
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );
      debugPrint('[AUTH] verify-otp status=${res.statusCode}');
      debugPrint('[AUTH] verify-otp FULL body=${res.data}');
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) {
        debugPrint('[AUTH] verify-otp success=false error=${body['error']}');
        throw ValidationException(body['error'] as String? ?? 'Invalid OTP');
      }

      // Log full data shape so we can see the actual keys
      final rawData = body['data'];
      debugPrint('[AUTH] verify-otp data type=${rawData.runtimeType} value=$rawData');
      final data = rawData as Map<String, dynamic>;

      // Token may be under 'token' or 'accessToken'
      final token = (data['token'] ?? data['accessToken']) as String?;
      debugPrint('[AUTH] verify-otp token=${token != null ? '${token.length}chars' : 'NULL'} keys=${data.keys.toList()}');
      if (token == null) {
        throw ServerException('No token in verify-OTP response. Keys: ${data.keys.toList()}');
      }

      // User object may be nested or flat
      final rawUser = data['user'] ?? data['customer'] ?? data;
      debugPrint('[AUTH] verify-otp rawUser type=${rawUser.runtimeType} value=$rawUser');
      final userJson = rawUser as Map<String, dynamic>;

      // businesses may be null or absent
      final rawBusinesses = data['businesses'];
      debugPrint('[AUTH] verify-otp businesses=$rawBusinesses');
      final businesses = rawBusinesses is List ? rawBusinesses : <dynamic>[];
      final businessId = businesses.isNotEmpty
          ? ((businesses[0] as Map<String, dynamic>)['businessId'] as String?) ?? _api.tenantId
          : _api.tenantId;

      final refreshToken = data['refreshToken'] as String?;
      debugPrint('[AUTH] verify-otp: parts=${token.split('.').length} userId=${userJson['id']} businessId=$businessId refreshToken=${refreshToken != null ? '${refreshToken.length}chars' : 'null'}');
      await _storeTokens(token: token, userId: userJson['id'] as String? ?? '');
      if (refreshToken != null) await _storage.saveRefreshToken(refreshToken);
      debugPrint('[AUTH] verify-otp: token saved ✓');

      final user = UserModel.fromBackend(userJson, businessId: businessId);
      debugPrint('[AUTH] verify-otp: user=${user.name} id=${user.id} email=${user.email}');
      return user;
    } on DioException catch (e) {
      debugPrint('[AUTH] verify-otp DioException: type=${e.type} status=${e.response?.statusCode} body=${e.response?.data}');
      throw _mapDioError(e);
    } catch (e, st) {
      debugPrint('[AUTH] verify-otp unexpected: $e\n$st');
      if (e is AppException) rethrow;
      throw ServerException('Verification failed: ${e.runtimeType}');
    }
  }

  // ── Session restore ──────────────────────────────────────────────────────

  Future<UserModel?> restoreSession() async {
    debugPrint('[AUTH] ── restoreSession ─────────────────────────');

    final token = await _storage.getToken();
    final storedUserId = await _storage.getUserId();
    debugPrint('[AUTH] token: ${token != null ? '${token.length}chars' : 'null'}');
    debugPrint('[AUTH] storedUserId: $storedUserId');

    if (token == null) {
      debugPrint('[AUTH] no token — must log in');
      return null;
    }

    // ── Decode JWT payload to check expiry ─────────────────────────────────
    // JWT = base64url(header).base64url(payload).signature — decode part[1] only
    String? userId;
    try {
      final parts = token.split('.');
      debugPrint('[AUTH] JWT parts: ${parts.length}');
      if (parts.length == 3) {
        final payloadJson = utf8.decode(base64Decode(base64.normalize(parts[1])));
        final jwtPayload = jsonDecode(payloadJson) as Map<String, dynamic>;
        debugPrint('[AUTH] JWT payload keys: ${jwtPayload.keys.toList()}');

        // Accept common claim names for user ID
        userId = jwtPayload['userId'] as String?
            ?? jwtPayload['sub'] as String?
            ?? jwtPayload['id'] as String?;
        debugPrint('[AUTH] JWT userId: $userId');

        // exp is Unix seconds — compare in seconds, not milliseconds
        final exp = jwtPayload['exp'] as int?;
        if (exp != null) {
          final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final isExpired = nowSec > exp;
          debugPrint('[AUTH] JWT exp=$exp nowSec=$nowSec expired=$isExpired');
          if (isExpired) {
            debugPrint('[AUTH] token expired — clearing and returning null');
            await _storage.clearAll();
            return null;
          }
        }
      } else {
        debugPrint('[AUTH] non-JWT token (${parts.length} parts) — skipping decode');
      }
    } catch (e) {
      debugPrint('[AUTH] JWT decode error: $e — continuing with storedUserId');
    }

    // Fall back to separately stored userId if JWT decode failed or was non-JWT
    userId ??= storedUserId;
    debugPrint('[AUTH] effective userId: $userId');

    if (userId == null) {
      debugPrint('[AUTH] no userId — clearing and returning null');
      await _storage.clearAll();
      return null;
    }

    // ── Validate token with backend ────────────────────────────────────────
    debugPrint('[AUTH] GET /api/core/auth/me?userId=$userId');
    try {
      final res = await _api.dio.get('/api/core/auth/me', queryParameters: {'userId': userId});
      final body = res.data as Map<String, dynamic>;
      debugPrint('[AUTH] /me status=${res.statusCode} success=${body['success']} keys=${body.keys.toList()}');
      if (body['success'] != true) {
        debugPrint('[AUTH] /me success=false — clearing storage');
        await _storage.clearAll();
        return null;
      }
      final data = body['data'] as Map<String, dynamic>;
      final userJson = data['user'] as Map<String, dynamic>;
      final rawBusinesses = data['businesses'];
      final businesses = rawBusinesses is List ? rawBusinesses : <dynamic>[];
      final businessId = businesses.isNotEmpty
          ? (businesses[0] as Map<String, dynamic>)['businessId'] as String? ?? _api.tenantId
          : _api.tenantId;
      final user = UserModel.fromBackend(userJson, businessId: businessId);
      debugPrint('[AUTH] session restored ✓ name=${user.name} id=${user.id} businessId=${user.businessId}');
      return user;
    } on DioException catch (e) {
      debugPrint('[AUTH] /me DioException: status=${e.response?.statusCode} body=${e.response?.data}');
      if (e.response?.statusCode == 401 || e.response?.statusCode == 404) {
        debugPrint('[AUTH] /me 401/404 — clearing storage');
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
    debugPrint('[AUTH] logout — clearing storage');
    await _storage.clearAll();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<void> _storeTokens({required String token, required String userId}) async {
    debugPrint('[AUTH] _storeTokens: token=${token.length}chars userId=$userId');
    await _storage.saveToken(token);
    await _storage.saveUserId(userId);
    // Verify immediately after writing
    final verify = await _storage.getToken();
    debugPrint('[AUTH] _storeTokens verify: ${verify != null ? 'persisted ✓ ${verify.length}chars' : 'FAILED to persist ✗'}');
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

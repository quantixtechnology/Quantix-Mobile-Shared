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

  // ── Customer: email → OTP ───────────────────────────────────────────────────

  Future<String?> requestEmailOtp(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    debugPrint('[AUTH LOGIN] requestEmailOtp email=$normalizedEmail businessId=${_api.tenantId}');
    try {
      final res = await _api.dio.post('/api/core/auth/send-otp', data: {
        'email': normalizedEmail,
        'channel': 'EMAIL_OTP',
        'businessId': _api.tenantId,
      });
      debugPrint('[AUTH LOGIN] send-otp status=${res.statusCode}');
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) {
        throw ValidationException(body['error'] as String? ?? 'Failed to send OTP');
      }
      final devOtp = body['devOtp'] as String?;
      debugPrint('[AUTH LOGIN] send-otp devOtp=${devOtp ?? 'null (email mode)'}');
      return devOtp;
    } on DioException catch (e) {
      debugPrint('[AUTH LOGIN] send-otp DioException: status=${e.response?.statusCode}');
      throw _mapDioError(e);
    }
  }

  Future<UserModel> verifyOtp(String email, String code) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedCode = code.trim();
    debugPrint('[AUTH LOGIN] verifyOtp email=$normalizedEmail');
    final payload = {
      'email': normalizedEmail,
      'code': normalizedCode,
      'channel': 'EMAIL_OTP',
      'businessId': _api.tenantId,
    };
    try {
      final res = await _api.dio.post(
        '/api/core/auth/verify-otp',
        data: payload,
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );
      debugPrint('[AUTH LOGIN] verify-otp status=${res.statusCode}');
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) {
        throw ValidationException(body['error'] as String? ?? 'Invalid OTP');
      }

      final data = body['data'] as Map<String, dynamic>;
      final token = (data['token'] ?? data['accessToken']) as String?;
      debugPrint('[AUTH LOGIN] verify-otp token=${token != null ? '${token.length}chars' : 'NULL'}');
      if (token == null) {
        throw ServerException('No token in verify-OTP response. Keys: ${data.keys.toList()}');
      }

      final rawUser = data['user'] ?? data['customer'] ?? data;
      final userJson = rawUser as Map<String, dynamic>;

      final rawBusinesses = data['businesses'];
      final businesses = rawBusinesses is List ? rawBusinesses : <dynamic>[];
      final businessId = businesses.isNotEmpty
          ? ((businesses[0] as Map<String, dynamic>)['businessId'] as String?) ?? _api.tenantId
          : _api.tenantId;

      final refreshToken = data['refreshToken'] as String?;
      final hasPassword = data['hasPassword'] as bool? ?? false;

      await _storeSession(
        token: token,
        refreshToken: refreshToken,
        userId: userJson['id'] as String? ?? '',
        email: normalizedEmail,
        userJson: userJson,
        businessId: businessId,
      );
      debugPrint('[AUTH LOGIN] verify-otp: session stored ✓ hasPassword=$hasPassword');

      return UserModel.fromBackend(userJson,
          businessId: businessId, hasPassword: hasPassword);
    } on DioException catch (e) {
      debugPrint('[AUTH LOGIN] verify-otp DioException: status=${e.response?.statusCode}');
      throw _mapDioError(e);
    } catch (e, st) {
      debugPrint('[AUTH LOGIN] verify-otp unexpected: $e\n$st');
      if (e is AppException) rethrow;
      throw ServerException('Verification failed: ${e.runtimeType}');
    }
  }

  // ── Customer: email + password ──────────────────────────────────────────────

  Future<UserModel> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    debugPrint('[AUTH LOGIN] loginWithEmailPassword email=$normalizedEmail');
    try {
      final res = await _api.dio.post('/api/core/auth/login', data: {
        'email': normalizedEmail,
        'password': password,
        'role': 'customer',
        'businessId': _api.tenantId,
      });
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) {
        throw ValidationException(body['error'] as String? ?? 'Login failed');
      }
      final data = body['data'] as Map<String, dynamic>;
      final token = (data['token'] ?? data['accessToken']) as String?;
      if (token == null) throw ServerException('No token in login response');

      final rawUser = data['user'] ?? data['customer'] ?? data;
      final userJson = rawUser as Map<String, dynamic>;
      final refreshToken = data['refreshToken'] as String?;

      await _storeSession(
        token: token,
        refreshToken: refreshToken,
        userId: userJson['id'] as String? ?? '',
        email: normalizedEmail,
        userJson: userJson,
        businessId: _api.tenantId,
      );
      debugPrint('[AUTH LOGIN] loginWithEmailPassword: session stored ✓');
      return UserModel.fromBackend(userJson,
          businessId: _api.tenantId, hasPassword: true);
    } on DioException catch (e) {
      debugPrint('[AUTH LOGIN] loginWithEmailPassword DioException: status=${e.response?.statusCode}');
      throw _mapDioError(e);
    }
  }

  // ── Password management ─────────────────────────────────────────────────────

  Future<void> createPassword(String password) async {
    debugPrint('[AUTH LOGIN] createPassword');
    try {
      final res = await _api.dio.post('/api/core/auth/set-password', data: {
        'password': password,
        'businessId': _api.tenantId,
      });
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) {
        throw ValidationException(body['error'] as String? ?? 'Failed to set password');
      }
      debugPrint('[AUTH LOGIN] createPassword: success ✓');
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  // ── Forgot password ─────────────────────────────────────────────────────────

  Future<String?> forgotPasswordSendOtp(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    debugPrint('[AUTH LOGIN] forgotPasswordSendOtp email=$normalizedEmail');
    try {
      final res = await _api.dio.post(
          '/api/core/auth/forgot-password/send-otp', data: {
        'email': normalizedEmail,
        'businessId': _api.tenantId,
      });
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) {
        throw ValidationException(body['error'] as String? ?? 'Failed to send reset OTP');
      }
      return body['devOtp'] as String?;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<String> forgotPasswordVerifyOtp(String email, String code) async {
    debugPrint('[AUTH LOGIN] forgotPasswordVerifyOtp email=$email');
    try {
      final res = await _api.dio.post(
          '/api/core/auth/forgot-password/verify', data: {
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
        'businessId': _api.tenantId,
      });
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) {
        throw ValidationException(body['error'] as String? ?? 'Invalid OTP');
      }
      final resetToken = body['data']?['resetToken'] as String?;
      if (resetToken == null) throw ServerException('No resetToken in response');
      return resetToken;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<UserModel> forgotPasswordReset({
    required String resetToken,
    required String newPassword,
    required String email,
  }) async {
    debugPrint('[AUTH LOGIN] forgotPasswordReset');
    try {
      final res = await _api.dio.post(
          '/api/core/auth/forgot-password/reset', data: {
        'resetToken': resetToken,
        'password': newPassword,
        'businessId': _api.tenantId,
      });
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) {
        throw ValidationException(body['error'] as String? ?? 'Failed to reset password');
      }
      final data = body['data'] as Map<String, dynamic>? ?? {};
      final token = (data['token'] ?? data['accessToken']) as String?;
      final rawUser = data['user'] ?? data['customer'];
      final userJson = rawUser as Map<String, dynamic>?;
      final refreshToken = data['refreshToken'] as String?;

      if (token != null && userJson != null) {
        await _storeSession(
          token: token,
          refreshToken: refreshToken,
          userId: userJson['id'] as String? ?? '',
          email: email.trim().toLowerCase(),
          userJson: userJson,
          businessId: _api.tenantId,
        );
        return UserModel.fromBackend(userJson,
            businessId: _api.tenantId, hasPassword: true);
      }

      // Backend didn't return a new session — user must log in manually
      throw ServerException('Password reset successful. Please log in with your new password.');
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  // ── Session restore ─────────────────────────────────────────────────────────

  Future<UserModel?> restoreSession() async {
    debugPrint('[AUTH RESTORE] ── restoreSession ────────────────────────');

    final token = await _storage.getToken();
    debugPrint('[AUTH RESTORE] token: ${token != null ? '${token.length}chars' : 'null'}');

    if (token == null) {
      // No token at all — check if we have a refresh token we can exchange
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        debugPrint('[AUTH RESTORE] no token + no refreshToken — must log in');
        return null;
      }
      debugPrint('[AUTH RESTORE] no access token but refresh token exists — trying refresh');
      return _refreshAndRestore();
    }

    // Decode JWT to inspect expiry (but don't bail early — let the server decide)
    bool tokenLikelyExpired = false;
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payloadJson = utf8.decode(base64Decode(base64.normalize(parts[1])));
        final jwtPayload = jsonDecode(payloadJson) as Map<String, dynamic>;
        final exp = jwtPayload['exp'] as int?;
        if (exp != null) {
          final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          tokenLikelyExpired = nowSec > exp;
          debugPrint('[AUTH RESTORE] JWT exp=$exp nowSec=$nowSec expired=$tokenLikelyExpired');
        }
      }
    } catch (e) {
      debugPrint('[AUTH RESTORE] JWT decode error: $e — proceeding anyway');
    }

    // If we know the token is expired, try refresh first (avoids a round-trip
    // to /me that will just 401)
    if (tokenLikelyExpired) {
      debugPrint('[AUTH RESTORE] token expired — trying refresh before /me call');
      final refreshed = await _refreshAndRestore();
      if (refreshed != null) return refreshed;
      // Refresh failed — fall through to cached restore
      return _restoreFromCache();
    }

    // Token appears valid — validate with backend
    debugPrint('[AUTH RESTORE] token looks valid — calling /me');
    return _validateWithServer(token);
  }

  Future<UserModel?> _validateWithServer(String token) async {
    final storedUserId = await _storage.getUserId();
    // Extract userId from JWT or fall back to storage
    String? userId;
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payloadJson = utf8.decode(base64Decode(base64.normalize(parts[1])));
        final jwtPayload = jsonDecode(payloadJson) as Map<String, dynamic>;
        userId = jwtPayload['userId'] as String?
            ?? jwtPayload['sub'] as String?
            ?? jwtPayload['id'] as String?;
      }
    } catch (_) {}
    userId ??= storedUserId;

    if (userId == null) {
      debugPrint('[AUTH RESTORE] no userId — clearing and returning null');
      await _storage.clearAll();
      return null;
    }

    debugPrint('[AUTH RESTORE] GET /api/core/auth/me?userId=$userId');
    try {
      final res = await _api.dio
          .get('/api/core/auth/me', queryParameters: {'userId': userId});
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) {
        debugPrint('[AUTH RESTORE] /me success=false — clearing tokens');
        await _storage.clearTokens();
        return null;
      }
      final data = body['data'] as Map<String, dynamic>;
      final userJson = data['user'] as Map<String, dynamic>;
      final rawBusinesses = data['businesses'];
      final businesses = rawBusinesses is List ? rawBusinesses : <dynamic>[];
      final businessId = businesses.isNotEmpty
          ? (businesses[0] as Map<String, dynamic>)['businessId'] as String? ?? _api.tenantId
          : _api.tenantId;
      // Refresh cache
      await _storage.saveUserJson({...userJson, 'businessId': businessId});
      final user = UserModel.fromBackend(userJson, businessId: businessId);
      debugPrint('[AUTH RESTORE] session restored ✓ name=${user.name} id=${user.id}');
      return user;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      debugPrint('[AUTH RESTORE] /me DioException: status=$status type=${e.type}');
      if (status == 401) {
        // Access token rejected — try refresh
        debugPrint('[AUTH RESTORE] /me 401 — trying refresh');
        final refreshed = await _refreshAndRestore();
        if (refreshed != null) return refreshed;
        // Refresh also failed
        await _storage.clearAll();
        return null;
      }
      // Network/timeout error — use cached user, don't logout
      debugPrint('[AUTH RESTORE] network error — restoring from cache');
      return _restoreFromCache();
    }
  }

  Future<UserModel?> _refreshAndRestore() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) {
      debugPrint('[AUTH REFRESH] no refresh token available');
      return null;
    }
    debugPrint('[AUTH REFRESH] attempting silent token refresh');
    try {
      final refreshDio = Dio(BaseOptions(
        baseUrl: _api.dio.options.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final res = await refreshDio.post('/api/core/auth/refresh', data: {
        'refreshToken': refreshToken,
      });
      final newAccess = res.data['accessToken'] as String?
          ?? res.data['token'] as String?;
      if (newAccess == null) throw Exception('No accessToken in refresh response');

      final newRefresh = res.data['refreshToken'] as String?;
      await _storage.saveToken(newAccess);
      if (newRefresh != null) await _storage.saveRefreshToken(newRefresh);
      debugPrint('[AUTH REFRESH] tokens refreshed ✓ — validating with /me');

      return _validateWithServer(newAccess);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      debugPrint('[AUTH REFRESH] DioException: status=$status type=${e.type}');
      if (status == 401 || status == 403) {
        // Refresh token is revoked — force logout
        debugPrint('[AUTH REFRESH] refresh token rejected — clearing all');
        await _storage.clearAll();
        return null;
      }
      // Network error during refresh — restore from cache
      debugPrint('[AUTH REFRESH] network error — restoring from cache');
      return _restoreFromCache();
    } catch (e) {
      debugPrint('[AUTH REFRESH] unexpected error: $e — restoring from cache');
      return _restoreFromCache();
    }
  }

  Future<UserModel?> _restoreFromCache() async {
    debugPrint('[AUTH RESTORE] restoring from cached user JSON');
    try {
      final cached = await _storage.getUserJson();
      if (cached == null) {
        debugPrint('[AUTH RESTORE] no cache — must log in');
        return null;
      }
      final businessId = cached['businessId'] as String? ?? _api.tenantId;
      final user = UserModel.fromBackend(cached, businessId: businessId);
      debugPrint('[AUTH RESTORE] cache restore ✓ name=${user.name} (offline mode)');
      return user;
    } catch (e) {
      debugPrint('[AUTH RESTORE] cache restore failed: $e');
      return null;
    }
  }

  // ── Rider / Admin: email + password ─────────────────────────────────────────

  Future<UserModel> loginWithPassword({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    debugPrint('[AUTH LOGIN] POST /api/core/auth/login email=$email role=${role.name}');
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
      final token = (data['token'] ?? data['accessToken']) as String;
      final userJson = data['user'] as Map<String, dynamic>;
      final refreshToken = data['refreshToken'] as String?;
      await _storeSession(
        token: token,
        refreshToken: refreshToken,
        userId: userJson['id'] as String,
        email: email,
        userJson: userJson,
        businessId: _api.tenantId,
      );
      return UserModel.fromBackend(userJson,
          businessId: _api.tenantId, hasPassword: true);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  // ── Logout ───────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    debugPrint('[AUTH LOGOUT] logout — clearing all storage');
    await _storage.clearAll();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Future<void> _storeSession({
    required String token,
    String? refreshToken,
    required String userId,
    required String email,
    required Map<String, dynamic> userJson,
    required String businessId,
  }) async {
    debugPrint('[AUTH LOGIN] _storeSession userId=$userId email=$email');
    await Future.wait([
      _storage.saveToken(token),
      _storage.saveUserId(userId),
      _storage.saveEmail(email),
      _storage.saveUserJson({...userJson, 'businessId': businessId}),
      if (refreshToken != null) _storage.saveRefreshToken(refreshToken),
    ]);
    // Verify token was written
    final verify = await _storage.getToken();
    debugPrint('[AUTH LOGIN] _storeSession verify: ${verify != null ? 'persisted ✓' : 'FAILED ✗'}');
  }

  AppException _mapDioError(DioException e) {
    final status = e.response?.statusCode;
    String message = 'Request failed';
    if (e.response?.data is Map) {
      message = (e.response!.data['error'] as String?)
          ?? (e.response!.data['message'] as String?)
          ?? 'Request failed';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.unknown) {
      return NetworkException('No internet connection. Please try again.', statusCode: 0);
    }
    if (status == 401) return ValidationException(message.isNotEmpty ? message : 'Invalid credentials');
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

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

  // ── Customer OTP login ──────────────────────────────────────────────────────

  Future<String?> requestEmailOtp(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    debugPrint('[AUTH] POST /api/customer/auth/login-otp email=$normalizedEmail');
    try {
      final res = await _api.dio.post('/api/customer/auth/login-otp', data: {
        'email': normalizedEmail,
        'businessId': _api.tenantId,
      });
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) {
        throw ValidationException(body['error'] as String? ?? 'Failed to send OTP');
      }
      final devOtp = body['devOtp'] as String?;
      debugPrint('[AUTH] login-otp sent; devOtp=${devOtp ?? 'null (email mode)'}');
      return devOtp;
    } on DioException catch (e) {
      debugPrint('[AUTH] login-otp DioException: status=${e.response?.statusCode}');
      throw _mapDioError(e);
    }
  }

  Future<UserModel> verifyOtp(String email, String code) async {
    final normalizedEmail = email.trim().toLowerCase();
    debugPrint('[AUTH] POST /api/customer/auth/verify-otp email=$normalizedEmail');
    try {
      final res = await _api.dio.post(
        '/api/customer/auth/verify-otp',
        data: {
          'email': normalizedEmail,
          'code': code.trim(),
          'businessId': _api.tenantId,
        },
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) {
        throw ValidationException(body['error'] as String? ?? 'Invalid OTP');
      }

      // Backend returns a flat response — token and user are top-level keys
      final token = (body['token'] ?? body['accessToken']) as String?;
      if (token == null) {
        throw ServerException('No token in verify-OTP response. Keys: ${body.keys.toList()}');
      }

      final rawUser = body['user'] ?? body['customer'];
      final userJson = (rawUser as Map<String, dynamic>?) ?? body;
      final refreshToken = body['refreshToken'] as String?;
      // isPasswordSet is top-level; hasPassword lives inside the user object
      final hasPassword = body['isPasswordSet'] as bool?
          ?? (body['user'] as Map<String, dynamic>?)?['hasPassword'] as bool?
          ?? false;

      final rawBusinesses = body['businesses'];
      final businesses = rawBusinesses is List ? rawBusinesses : <dynamic>[];
      final businessId = businesses.isNotEmpty
          ? ((businesses[0] as Map<String, dynamic>)['businessId'] as String?) ?? _api.tenantId
          : _api.tenantId;

      await _storeSession(
        token: token,
        refreshToken: refreshToken,
        userId: userJson['id'] as String? ?? '',
        email: normalizedEmail,
        userJson: userJson,
        businessId: businessId,
      );
      debugPrint('[AUTH] verify-otp: session stored ✓ hasPassword=$hasPassword');
      return UserModel.fromBackend(userJson, businessId: businessId, hasPassword: hasPassword);
    } on DioException catch (e) {
      debugPrint('[AUTH] verify-otp DioException: status=${e.response?.statusCode}');
      throw _mapDioError(e);
    } catch (e, st) {
      debugPrint('[AUTH] verify-otp unexpected: $e\n$st');
      if (e is AppException) rethrow;
      throw ServerException('Verification failed: ${e.runtimeType}');
    }
  }

  // ── Role-based password login (delivery + admin apps) ──────────────────────

  Future<UserModel> loginWithPassword({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final segment = role == UserRole.rider ? 'rider'
        : role == UserRole.admin ? 'admin'
        : 'customer';
    final endpoint = '/api/$segment/auth/login-password';
    final normalizedEmail = email.trim().toLowerCase();
    debugPrint('[AUTH] POST $endpoint role=${role.name} email=$normalizedEmail');
    try {
      final res = await _api.dio.post(endpoint, data: {
        'email': normalizedEmail,
        'password': password,
        'businessId': _api.tenantId,
      });
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) {
        throw ValidationException(body['error'] as String? ?? 'Login failed');
      }
      final data = body['data'] as Map<String, dynamic>;
      final token = (data['token'] ?? data['accessToken']) as String?;
      if (token == null) throw ServerException('No token in login response');

      final rawUser = data['user'] ?? data['rider'] ?? data['admin'] ?? data;
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
      debugPrint('[AUTH] $segment login: session stored ✓');
      return UserModel.fromBackend(userJson, businessId: _api.tenantId, hasPassword: true);
    } on DioException catch (e) {
      debugPrint('[AUTH] loginWithPassword DioException: status=${e.response?.statusCode}');
      throw _mapDioError(e);
    }
  }

  // ── Customer password login ─────────────────────────────────────────────────

  Future<UserModel> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    debugPrint('[AUTH] POST /api/customer/auth/login-password email=$normalizedEmail');
    try {
      final res = await _api.dio.post('/api/customer/auth/login-password', data: {
        'email': normalizedEmail,
        'password': password,
        'businessId': _api.tenantId,
      });
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) {
        throw ValidationException(body['error'] as String? ?? 'Login failed');
      }
      // Backend returns a flat response — token and user are top-level keys
      final token = (body['token'] ?? body['accessToken']) as String?;
      if (token == null) throw ServerException('No token in login response');

      final rawUser = body['user'] ?? body['customer'];
      final userJson = (rawUser as Map<String, dynamic>?) ?? body;
      final refreshToken = body['refreshToken'] as String?;

      await _storeSession(
        token: token,
        refreshToken: refreshToken,
        userId: userJson['id'] as String? ?? '',
        email: normalizedEmail,
        userJson: userJson,
        businessId: _api.tenantId,
      );
      debugPrint('[AUTH] login-password: session stored ✓');
      return UserModel.fromBackend(userJson, businessId: _api.tenantId, hasPassword: true);
    } on DioException catch (e) {
      debugPrint('[AUTH] login-password DioException: status=${e.response?.statusCode}');
      throw _mapDioError(e);
    }
  }

  // ── Create password (first-time after OTP) ──────────────────────────────────

  Future<void> createPassword(String password) async {
    debugPrint('[AUTH] POST /api/customer/auth/create-password');
    try {
      final res = await _api.dio.post('/api/customer/auth/create-password', data: {
        'password': password,
        'confirmPassword': password,
      });
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) {
        throw ValidationException(body['error'] as String? ?? 'Failed to create password');
      }
      debugPrint('[AUTH] create-password: success ✓');
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  // ── Change password (authenticated) ────────────────────────────────────────

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    debugPrint('[AUTH] POST /api/customer/auth/change-password');
    try {
      final res = await _api.dio.post('/api/customer/auth/change-password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmPassword': newPassword,
      });
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) {
        throw ValidationException(body['error'] as String? ?? 'Failed to change password');
      }
      debugPrint('[AUTH] change-password: success ✓');
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  // ── Forgot password — send reset link via email ─────────────────────────────

  Future<void> forgotPassword(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    debugPrint('[AUTH] POST /api/customer/auth/forgot-password email=$normalizedEmail');
    try {
      final res = await _api.dio.post('/api/customer/auth/forgot-password', data: {
        'email': normalizedEmail,
        'businessId': _api.tenantId,
      });
      final body = res.data as Map<String, dynamic>;
      // Accept both success:true and success:false (backend always returns 200
      // even for unknown emails to prevent account enumeration)
      debugPrint('[AUTH] forgot-password: sent ✓ success=${body['success']}');
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  // ── Validate reset token (from deep link) ──────────────────────────────────

  Future<bool> validateResetToken(String token) async {
    debugPrint('[AUTH] POST /api/customer/auth/validate-reset-token');
    try {
      final res = await _api.dio.post('/api/customer/auth/validate-reset-token', data: {
        'token': token,
      });
      final body = res.data as Map<String, dynamic>;
      return body['success'] == true;
    } on DioException catch (e) {
      debugPrint('[AUTH] validate-reset-token DioException: ${e.response?.statusCode}');
      if (e.response?.statusCode == 400 || e.response?.statusCode == 422) return false;
      throw _mapDioError(e);
    }
  }

  // ── Reset password (from deep link token) ──────────────────────────────────

  Future<UserModel?> resetPassword({
    required String token,
    required String password,
  }) async {
    debugPrint('[AUTH] POST /api/customer/auth/reset-password');
    try {
      final res = await _api.dio.post('/api/customer/auth/reset-password', data: {
        'token': token,
        'password': password,
        'confirmPassword': password,
      });
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) {
        throw ValidationException(body['error'] as String? ?? 'Failed to reset password');
      }
      // Backend returns a flat response — token and user are top-level keys
      final newToken = (body['token'] ?? body['accessToken']) as String?;
      final rawUser = body['user'] ?? body['customer'];
      final userJson = rawUser as Map<String, dynamic>?;
      final refreshToken = body['refreshToken'] as String?;

      if (newToken != null && userJson != null) {
        await _storeSession(
          token: newToken,
          refreshToken: refreshToken,
          userId: userJson['id'] as String? ?? '',
          email: userJson['email'] as String? ?? '',
          userJson: userJson,
          businessId: _api.tenantId,
        );
        return UserModel.fromBackend(userJson, businessId: _api.tenantId, hasPassword: true);
      }
      return null;
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
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        debugPrint('[AUTH RESTORE] no token + no refreshToken — must log in');
        return null;
      }
      return _refreshAndRestore();
    }

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

    if (tokenLikelyExpired) {
      debugPrint('[AUTH RESTORE] token expired — trying refresh before /me call');
      final refreshed = await _refreshAndRestore();
      if (refreshed != null) return refreshed;
      return _restoreFromCache();
    }

    debugPrint('[AUTH RESTORE] token looks valid — calling /me');
    return _validateWithServer(token);
  }

  Future<UserModel?> _validateWithServer(String token) async {
    final storedUserId = await _storage.getUserId();
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

    debugPrint('[AUTH RESTORE] GET /api/customer/auth/me?userId=$userId');
    try {
      final res = await _api.dio
          .get('/api/customer/auth/me', queryParameters: {'userId': userId});
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) {
        debugPrint('[AUTH RESTORE] /me success=false — clearing tokens');
        await _storage.clearTokens();
        return null;
      }
      // /me returns flat — user is top-level, businessId is inside the user object
      final userJson = body['user'] as Map<String, dynamic>;
      final businessId = userJson['businessId'] as String? ?? _api.tenantId;
      await _storage.saveUserJson({...userJson, 'businessId': businessId});
      final user = UserModel.fromBackend(userJson, businessId: businessId);
      debugPrint('[AUTH RESTORE] session restored ✓ name=${user.name}');
      return user;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      debugPrint('[AUTH RESTORE] /me DioException: status=$status type=${e.type}');
      if (status == 401) {
        final refreshed = await _refreshAndRestore();
        if (refreshed != null) return refreshed;
        await _storage.clearAll();
        return null;
      }
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
      final res = await refreshDio.post('/api/customer/auth/refresh', data: {
        'refreshToken': refreshToken,
      });
      final newAccess = res.data['accessToken'] as String? ?? res.data['token'] as String?;
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
        debugPrint('[AUTH REFRESH] refresh token rejected — clearing all');
        await _storage.clearAll();
        return null;
      }
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

  // ── Logout ───────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    debugPrint('[AUTH] logout — clearing all storage');
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
    debugPrint('[AUTH] _storeSession userId=$userId email=$email');
    await Future.wait([
      _storage.saveToken(token),
      _storage.saveUserId(userId),
      _storage.saveEmail(email),
      _storage.saveUserJson({...userJson, 'businessId': businessId}),
      if (refreshToken != null) _storage.saveRefreshToken(refreshToken),
    ]);
    final verify = await _storage.getToken();
    debugPrint('[AUTH] _storeSession verify: ${verify != null ? 'persisted ✓' : 'FAILED ✗'}');
  }

  AppException _mapDioError(DioException e) {
    final status = e.response?.statusCode;
    final rawData = e.response?.data;

    // HTML response means backend gateway/proxy returned an error page (e.g. 404 from Next.js)
    if (rawData is String && rawData.contains('<!DOCTYPE')) {
      return ServerException('Service temporarily unavailable. Please try again later.', statusCode: status);
    }

    String message = 'Request failed';
    if (rawData is Map) {
      message = (rawData['error'] as String?)
          ?? (rawData['message'] as String?)
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

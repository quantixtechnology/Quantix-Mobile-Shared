import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../demo/demo_data.dart';
import '../exceptions/app_exception.dart';
import '../storage/secure_storage.dart';
import 'user_model.dart';

class AuthService {
  final ApiClient _api;
  final SecureStorage _storage;

  AuthService(this._api, this._storage);

  // ── Customer: email → OTP ───────────────────────────────────────────────

  Future<String> requestEmailOtp(String email) async {
    debugPrint('[AUTH] requestEmailOtp USE_DEMO_DATA=$kUseDemoData');
    if (kUseDemoData) {
      final normalised = email.trim().toLowerCase();
      debugPrint('[AUTH] MODE=DEMO EMAIL=$normalised');
      final found = DemoData.customers.any(
        (c) => c.email?.toLowerCase() == normalised,
      );
      if (!found) {
        debugPrint('[AUTH] DEMO email not found in DemoData');
        throw const ValidationException('No account found for this email');
      }
      debugPrint('[AUTH] DEMO OTP issued → demo_session_$normalised');
      return 'demo_session_$normalised';
    }
    debugPrint('[AUTH] MODE=API → POST /auth/otp/email/request');
    try {
      final res = await _api.dio.post('/auth/otp/email/request', data: {
        'email': email.trim(),
        'businessId': _api.tenantId,
      });
      return res.data['sessionToken'] as String;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<UserModel> verifyOtp(String sessionToken, String code) async {
    debugPrint('[AUTH] verifyOtp USE_DEMO_DATA=$kUseDemoData token=${sessionToken.substring(0, sessionToken.length.clamp(0, 20))}...');
    if (kUseDemoData && sessionToken.startsWith('demo_session_')) {
      final email = sessionToken.substring('demo_session_'.length);
      debugPrint('[AUTH] DEMO verifyOtp EMAIL=$email');
      final user = DemoData.customers.firstWhere(
        (c) => c.email?.toLowerCase() == email,
        orElse: () => throw const ValidationException('Account not found'),
      );
      await _storeTokens({
        'accessToken': 'demo_token_${user.id}',
        'refreshToken': 'demo_refresh_${user.id}',
        'user': user.toJson(),
      });
      debugPrint('[AUTH] DEMO authenticated → ${user.name} (${user.id})');
      return user;
    }
    debugPrint('[AUTH] MODE=API → POST /auth/otp/verify');
    try {
      final res = await _api.dio.post('/auth/otp/verify', data: {
        'sessionToken': sessionToken,
        'code': code,
      });
      await _storeTokens(res.data);
      return UserModel.fromJson(res.data['user'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  // ── Rider / Admin: email + password ─────────────────────────────────────

  Future<UserModel> loginWithPassword({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    try {
      final res = await _api.dio.post('/auth/login', data: {
        'email': email,
        'password': password,
        'role': role.name,
        'businessId': _api.tenantId,
      });
      await _storeTokens(res.data);
      return UserModel.fromJson(res.data['user'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  // ── Session restore ──────────────────────────────────────────────────────

  Future<UserModel?> restoreSession() async {
    final token = await _storage.getToken();
    debugPrint('[AUTH] restoreSession USE_DEMO_DATA=$kUseDemoData hasToken=${token != null}');
    if (token == null) return null;

    if (kUseDemoData && token.startsWith('demo_token_')) {
      final userId = token.substring('demo_token_'.length);
      debugPrint('[AUTH] DEMO restoreSession userId=$userId');
      try {
        final user = DemoData.customers.firstWhere((c) => c.id == userId);
        debugPrint('[AUTH] DEMO session restored → ${user.name}');
        return user;
      } catch (_) {
        await _storage.clearAll();
        return null;
      }
    }

    debugPrint('[AUTH] MODE=API → GET /auth/me');
    try {
      final res = await _api.dio.get('/auth/me');
      return UserModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Token expired — try refresh
        try {
          await refreshToken();
          final res = await _api.dio.get('/auth/me');
          return UserModel.fromJson(res.data as Map<String, dynamic>);
        } catch (_) {
          await _storage.clearAll();
          return null;
        }
      }
      return null;
    }
  }

  // ── Token refresh ────────────────────────────────────────────────────────

  Future<void> refreshToken() async {
    final refresh = await _storage.getRefreshToken();
    if (refresh == null) throw const UnauthorizedException();
    try {
      final res = await _api.dio.post('/auth/refresh', data: {
        'refreshToken': refresh,
      });
      await _storeTokens(res.data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  // ── Logout ───────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      await _api.dio.post('/auth/logout');
    } catch (_) {
      // best-effort server call; always clear local state
    }
    await _storage.clearAll();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<void> _storeTokens(Map<String, dynamic> data) async {
    await _storage.saveToken(data['accessToken'] as String);
    await _storage.saveRefreshToken(data['refreshToken'] as String);
    final userId = (data['user'] as Map<String, dynamic>?)?['id'] as String?;
    if (userId != null) await _storage.saveUserId(userId);
  }

  AppException _mapDioError(DioException e) {
    final status = e.response?.statusCode;
    final message = (e.response?.data is Map)
        ? (e.response!.data['message'] as String? ?? 'Request failed')
        : 'Request failed';
    if (status == 401) return const UnauthorizedException();
    if (status == 422) return ValidationException(message);
    if (status != null && status >= 500) return ServerException(message, statusCode: status);
    return NetworkException(message, statusCode: status);
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  final api = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthService(api, storage);
});

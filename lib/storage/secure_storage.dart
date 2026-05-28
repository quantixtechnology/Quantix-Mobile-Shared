import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _userEmailKey = 'user_email';
  static const _userJsonKey = 'user_json';
  static const _fcmTokenKey = 'fcm_token';

  // ── Access token ────────────────────────────────────────────────────────────

  Future<void> saveToken(String token) async {
    debugPrint('[STORAGE] saveToken: ${token.length}chars [${token.substring(0, min(20, token.length))}...]');
    await _storage.write(key: _tokenKey, value: token);
    debugPrint('[STORAGE] saveToken: written ✓');
  }

  Future<String?> getToken() async {
    final token = await _storage.read(key: _tokenKey);
    debugPrint('[STORAGE] getToken: ${token != null ? '${token.length}chars found' : 'null'}');
    return token;
  }

  Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  // ── Refresh token ───────────────────────────────────────────────────────────

  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _refreshTokenKey, value: token);

  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> deleteRefreshToken() => _storage.delete(key: _refreshTokenKey);

  // ── User identity ───────────────────────────────────────────────────────────

  Future<void> saveUserId(String id) =>
      _storage.write(key: _userIdKey, value: id);

  Future<String?> getUserId() => _storage.read(key: _userIdKey);

  Future<void> saveEmail(String email) =>
      _storage.write(key: _userEmailKey, value: email);

  Future<String?> getEmail() => _storage.read(key: _userEmailKey);

  // ── Cached user object (for offline restore) ────────────────────────────────

  Future<void> saveUserJson(Map<String, dynamic> json) =>
      _storage.write(key: _userJsonKey, value: jsonEncode(json));

  Future<Map<String, dynamic>?> getUserJson() async {
    final raw = await _storage.read(key: _userJsonKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── FCM token ───────────────────────────────────────────────────────────────

  Future<void> saveFcmToken(String token) =>
      _storage.write(key: _fcmTokenKey, value: token);

  Future<String?> getFcmToken() => _storage.read(key: _fcmTokenKey);

  Future<void> clearFcmToken() => _storage.delete(key: _fcmTokenKey);

  // ── Clear ───────────────────────────────────────────────────────────────────

  /// Clears all auth credentials. FCM token is intentionally retained.
  Future<void> clearAll() async {
    debugPrint('[STORAGE] clearAll: removing token, refreshToken, userId, email, userJson');
    await Future.wait([
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _userIdKey),
      _storage.delete(key: _userEmailKey),
      _storage.delete(key: _userJsonKey),
    ]);
    debugPrint('[STORAGE] clearAll: done ✓');
  }

  /// Clears only access + refresh tokens while keeping identity (userId, email,
  /// userJson). Used when we want to force re-auth without losing the cached
  /// user object for a smoother offline fallback.
  Future<void> clearTokens() async {
    debugPrint('[STORAGE] clearTokens: removing token + refreshToken only');
    await Future.wait([
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }
}

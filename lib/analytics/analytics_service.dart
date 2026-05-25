import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnalyticsService {
  final FirebaseAnalytics _analytics;
  final FirebaseCrashlytics _crashlytics;

  AnalyticsService()
      : _analytics = FirebaseAnalytics.instance,
        _crashlytics = FirebaseCrashlytics.instance;

  // ── Identity ─────────────────────────────────────────────────────────────

  Future<void> setUser(String userId, {String? tenantId}) async {
    await _analytics.setUserId(id: userId);
    if (tenantId != null) {
      await _analytics.setUserProperty(name: 'tenant_id', value: tenantId);
    }
    await _crashlytics.setUserIdentifier(userId);
  }

  Future<void> clearUser() async {
    await _analytics.setUserId(id: null);
    await _crashlytics.setUserIdentifier('');
  }

  // ── Auth events ───────────────────────────────────────────────────────────

  Future<void> logLogin({required String method}) =>
      _analytics.logLogin(loginMethod: method);

  Future<void> logLogout() =>
      _log('logout');

  Future<void> logRegistration({required String method}) =>
      _analytics.logSignUp(signUpMethod: method);

  // ── Catalog events ────────────────────────────────────────────────────────

  Future<void> logViewProduct({
    required String productId,
    required String productName,
    required double price,
  }) =>
      _analytics.logViewItem(
        items: [
          AnalyticsEventItem(
            itemId: productId,
            itemName: productName,
            price: price,
          ),
        ],
      );

  Future<void> logAddToCart({
    required String productId,
    required String productName,
    required double price,
    required int quantity,
  }) =>
      _analytics.logAddToCart(
        items: [
          AnalyticsEventItem(
            itemId: productId,
            itemName: productName,
            price: price,
            quantity: quantity,
          ),
        ],
        value: price * quantity,
        currency: 'PKR',
      );

  // ── Checkout events ───────────────────────────────────────────────────────

  Future<void> logBeginCheckout({required double total}) =>
      _analytics.logBeginCheckout(value: total, currency: 'PKR');

  Future<void> logOrderPlaced({
    required String orderId,
    required double total,
    required String paymentMethod,
  }) =>
      _analytics.logPurchase(
        transactionId: orderId,
        value: total,
        currency: 'PKR',
        parameters: {'payment_method': paymentMethod},
      );

  // ── Delivery events ───────────────────────────────────────────────────────

  Future<void> logDeliveryAccepted({required String orderId}) =>
      _log('delivery_accepted', {'order_id': orderId});

  Future<void> logDeliveryCompleted({
    required String orderId,
    required int durationMinutes,
  }) =>
      _log('delivery_completed', {
        'order_id': orderId,
        'duration_minutes': durationMinutes,
      });

  Future<void> logDeliveryRejected({required String orderId}) =>
      _log('delivery_rejected', {'order_id': orderId});

  // ── Admin events ──────────────────────────────────────────────────────────

  Future<void> logInventoryUpdate({
    required String productId,
    required int newStock,
  }) =>
      _log('inventory_update', {
        'product_id': productId,
        'new_stock': newStock,
      });

  Future<void> logOrderStatusChanged({
    required String orderId,
    required String status,
  }) =>
      _log('order_status_changed', {
        'order_id': orderId,
        'status': status,
      });

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<void> logNotificationReceived({required String type}) =>
      _log('notification_received', {'type': type});

  Future<void> logNotificationTapped({required String type}) =>
      _log('notification_tapped', {'type': type});

  // ── Errors / Crashlytics ──────────────────────────────────────────────────

  void recordError(Object error, StackTrace? stack, {bool fatal = false}) {
    if (kDebugMode) {
      debugPrint('[Crashlytics] $error\n$stack');
      return;
    }
    _crashlytics.recordError(error, stack, fatal: fatal);
  }

  void setCustomKey(String key, Object value) {
    _crashlytics.setCustomKey(key, value);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _log(String name, [Map<String, Object>? params]) =>
      _analytics.logEvent(name: name, parameters: params);
}

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

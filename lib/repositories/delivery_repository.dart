import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../demo/demo_data.dart';
import '../exceptions/app_exception.dart';
import '../models/order_model.dart';
import '../utils/error_mapper.dart';

class DeliveryRepository {
  final ApiClient _api;
  DeliveryRepository(this._api);

  Future<List<OrderModel>> getAssignedOrders() async {
    if (kUseDemoData) {
      return DemoData.orders
          .where((o) =>
              o.status == OrderStatus.dispatched ||
              o.status == OrderStatus.confirmed ||
              o.status == OrderStatus.preparing)
          .toList();
    }
    try {
      final res = await _api.dio.get('/deliveries/assigned');
      final list = res.data as List<dynamic>;
      return list
          .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      final err = mapDioError(e);
      if (err is OfflineException) return DemoData.orders;
      throw err;
    }
  }

  Future<OrderModel> getDelivery(String id) async {
    if (kUseDemoData) {
      return DemoData.orders.firstWhere(
        (o) => o.id == id,
        orElse: () => DemoData.orders.first,
      );
    }
    try {
      final res = await _api.dio.get('/deliveries/$id');
      final data = res.data as Map<String, dynamic>;
      return OrderModel.fromJson(
          data['order'] as Map<String, dynamic>? ?? data);
    } on DioException catch (e) {
      final err = mapDioError(e);
      if (err is OfflineException) {
        return DemoData.orders.firstWhere(
          (o) => o.id == id,
          orElse: () => DemoData.orders.first,
        );
      }
      throw err;
    }
  }

  Future<void> updateStatus(
    String id,
    String status, {
    double? lat,
    double? lng,
  }) async {
    if (kUseDemoData) return;
    try {
      final body = <String, dynamic>{'status': status};
      if (lat != null && lng != null) {
        body['location'] = {'lat': lat, 'lng': lng};
      }
      await _api.dio.patch('/deliveries/$id/status', data: body);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<void> broadcastLocation(
    String id, {
    required double lat,
    required double lng,
    double? heading,
  }) async {
    if (kUseDemoData) return;
    try {
      final data = <String, dynamic>{'lat': lat, 'lng': lng};
      if (heading != null) data['heading'] = heading;
      await _api.dio.post('/deliveries/$id/location', data: data);
    } on DioException catch (e) {
      final err = mapDioError(e);
      // Swallow offline errors for location broadcast — non-critical
      if (err is OfflineException) return;
      throw err;
    }
  }
}

final deliveryRepositoryProvider = Provider<DeliveryRepository>((ref) {
  return DeliveryRepository(ref.watch(apiClientProvider));
});

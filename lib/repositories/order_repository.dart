import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../demo/demo_data.dart';
import '../exceptions/app_exception.dart';
import '../models/order_model.dart';
import '../utils/error_mapper.dart';

class OrderRepository {
  final ApiClient _api;
  OrderRepository(this._api);

  Future<List<OrderModel>> getOrders({String? status, int page = 1}) async {
    if (kUseDemoData) {
      final all = DemoData.orders;
      if (status == null) return all;
      return all.where((o) => o.status.name == status).toList();
    }
    try {
      final params = <String, dynamic>{'page': page};
      if (status case final s?) params['status'] = s;
      final res = await _api.dio.get('/orders', queryParameters: params);
      final data = res.data as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>;
      return items
          .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      final err = mapDioError(e);
      if (err is OfflineException) return DemoData.orders;
      throw err;
    }
  }

  Future<OrderModel> getOrder(String id) async {
    if (kUseDemoData) {
      return DemoData.orders.firstWhere(
        (o) => o.id == id,
        orElse: () => DemoData.orders.first,
      );
    }
    try {
      final res = await _api.dio.get('/orders/$id');
      return OrderModel.fromJson(res.data as Map<String, dynamic>);
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

  Future<OrderModel> placeOrder({
    required List<Map<String, dynamic>> items,
    required String addressId,
    required String paymentMethod,
  }) async {
    if (kUseDemoData) {
      return OrderModel(
        id: 'ord_demo_${DateTime.now().millisecondsSinceEpoch}',
        status: OrderStatus.pending,
        items: items
            .map((i) => OrderItem(
                  productId: i['productId'] as String,
                  name: i['productId'] as String,
                  quantity: i['qty'] as int? ?? 1,
                  price: 0,
                ))
            .toList(),
        total: 0,
        createdAt: DateTime.now(),
      );
    }
    try {
      final res = await _api.dio.post('/orders', data: {
        'items': items,
        'addressId': addressId,
        'paymentMethod': paymentMethod,
      });
      return OrderModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<OrderModel> cancelOrder(String id, String reason) async {
    if (kUseDemoData) {
      return DemoData.orders.firstWhere(
        (o) => o.id == id,
        orElse: () => DemoData.orders.first,
      );
    }
    try {
      final res = await _api.dio
          .patch('/orders/$id/cancel', data: {'reason': reason});
      return OrderModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ref.watch(apiClientProvider));
});

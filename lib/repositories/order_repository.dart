import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/order_model.dart';

class OrderRepository {
  final ApiClient _api;
  OrderRepository(this._api);

  Future<List<OrderModel>> getOrders({String? status, int page = 1}) async {
    final params = <String, dynamic>{'page': page};
    if (status case final s?) params['status'] = s;
    final res = await _api.dio.get('/orders', queryParameters: params);
    final data = res.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>;
    return items.map((e) => OrderModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<OrderModel> getOrder(String id) async {
    final res = await _api.dio.get('/orders/$id');
    return OrderModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<OrderModel> placeOrder({
    required List<Map<String, dynamic>> items,
    required String addressId,
    required String paymentMethod,
  }) async {
    final res = await _api.dio.post('/orders', data: {
      'items': items,
      'addressId': addressId,
      'paymentMethod': paymentMethod,
    });
    return OrderModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<OrderModel> cancelOrder(String id, String reason) async {
    final res = await _api.dio.patch('/orders/$id/cancel', data: {'reason': reason});
    return OrderModel.fromJson(res.data as Map<String, dynamic>);
  }
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ref.watch(apiClientProvider));
});

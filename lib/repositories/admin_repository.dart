import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../auth/user_model.dart';
import '../demo/demo_data.dart';
import '../exceptions/app_exception.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../utils/error_mapper.dart';

class AdminStats {
  final int todayOrders;
  final double revenue;
  final int activeRiders;
  final int pendingOrders;

  const AdminStats({
    required this.todayOrders,
    required this.revenue,
    required this.activeRiders,
    required this.pendingOrders,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) => AdminStats(
        todayOrders: json['todayOrders'] as int? ?? 0,
        revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
        activeRiders: json['activeRiders'] as int? ?? 0,
        pendingOrders: json['pendingOrders'] as int? ?? 0,
      );
}

class InventoryItem {
  final ProductModel product;
  final int stock;

  const InventoryItem({required this.product, required this.stock});

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        product: ProductModel.fromJson(
            json['product'] as Map<String, dynamic>? ?? json),
        stock: json['stock'] as int? ?? 0,
      );
}

class AdminRepository {
  final ApiClient _api;
  AdminRepository(this._api);

  Future<AdminStats> getStats({String? date}) async {
    if (kUseDemoData) return AdminStats.fromJson(DemoData.adminStats);
    try {
      final params = <String, dynamic>{};
      if (date != null) params['date'] = date;
      final res =
          await _api.dio.get('/admin/stats', queryParameters: params);
      return AdminStats.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final err = mapDioError(e);
      if (err is OfflineException) return AdminStats.fromJson(DemoData.adminStats);
      throw err;
    }
  }

  Future<List<OrderModel>> getOrders({
    String? status,
    int page = 1,
    String? search,
  }) async {
    if (kUseDemoData) return DemoData.orders;
    try {
      final params = <String, dynamic>{'page': page};
      if (status != null) params['status'] = status;
      if (search != null) params['search'] = search;
      final res = await _api.dio.get('/admin/orders', queryParameters: params);
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

  Future<OrderModel> updateOrderStatus(String id, String status) async {
    if (kUseDemoData) {
      return DemoData.orders.firstWhere(
        (o) => o.id == id,
        orElse: () => DemoData.orders.first,
      );
    }
    try {
      final res = await _api.dio
          .patch('/admin/orders/$id/status', data: {'status': status});
      return OrderModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<List<UserModel>> getCustomers({int page = 1, String? search}) async {
    if (kUseDemoData) return DemoData.customers;
    try {
      final params = <String, dynamic>{'page': page};
      if (search != null) params['search'] = search;
      final res =
          await _api.dio.get('/admin/customers', queryParameters: params);
      final data = res.data as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>;
      return items
          .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      final err = mapDioError(e);
      if (err is OfflineException) return DemoData.customers;
      throw err;
    }
  }

  Future<List<InventoryItem>> getInventory({
    String? category,
    bool? lowStock,
  }) async {
    if (kUseDemoData) {
      return DemoData.inventoryItems
          .map((e) => InventoryItem.fromJson(e))
          .toList();
    }
    try {
      final params = <String, dynamic>{};
      if (category != null) params['category'] = category;
      if (lowStock != null) params['lowStock'] = lowStock;
      final res =
          await _api.dio.get('/admin/inventory', queryParameters: params);
      final data = res.data as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>;
      return items
          .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      final err = mapDioError(e);
      if (err is OfflineException) {
        return DemoData.inventoryItems
            .map((e) => InventoryItem.fromJson(e))
            .toList();
      }
      throw err;
    }
  }

  Future<ProductModel> updateInventory(
    String id, {
    int? stock,
    double? price,
  }) async {
    if (kUseDemoData) {
      return DemoData.products.firstWhere(
        (p) => p.id == id,
        orElse: () => DemoData.products.first,
      );
    }
    try {
      final body = <String, dynamic>{};
      if (stock != null) body['stock'] = stock;
      if (price != null) body['price'] = price;
      final res = await _api.dio.patch('/admin/inventory/$id', data: body);
      return ProductModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(apiClientProvider));
});

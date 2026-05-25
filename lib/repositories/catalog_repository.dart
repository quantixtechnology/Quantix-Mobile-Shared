import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../demo/demo_data.dart';
import '../exceptions/app_exception.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../utils/error_mapper.dart';

class CatalogRepository {
  final ApiClient _api;
  CatalogRepository(this._api);

  Future<List<CategoryModel>> getCategories() async {
    if (kUseDemoData) return DemoData.categories;
    try {
      final res = await _api.dio.get('/categories');
      final list = res.data as List<dynamic>;
      return list
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      final err = mapDioError(e);
      if (err is OfflineException) return DemoData.categories;
      throw err;
    }
  }

  Future<List<ProductModel>> getProducts({
    String? categoryId,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    if (kUseDemoData) return _filterDemo(categoryId, search);
    try {
      final params = <String, dynamic>{'page': page, 'limit': limit};
      if (categoryId case final id?) params['category'] = id;
      if (search case final s? when s.isNotEmpty) params['search'] = s;
      final res = await _api.dio.get('/products', queryParameters: params);
      final data = res.data as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>;
      return items
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      final err = mapDioError(e);
      if (err is OfflineException) return _filterDemo(categoryId, search);
      throw err;
    }
  }

  Future<ProductModel> getProduct(String id) async {
    if (kUseDemoData) {
      return DemoData.products.firstWhere(
        (p) => p.id == id,
        orElse: () => DemoData.products.first,
      );
    }
    try {
      final res = await _api.dio.get('/products/$id');
      return ProductModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final err = mapDioError(e);
      if (err is OfflineException) {
        return DemoData.products.firstWhere(
          (p) => p.id == id,
          orElse: () => DemoData.products.first,
        );
      }
      throw err;
    }
  }

  List<ProductModel> _filterDemo(String? categoryId, String? search) {
    var items = DemoData.products;
    if (categoryId != null) {
      items = items.where((p) => p.category == categoryId).toList();
    }
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      items = items.where((p) => p.name.toLowerCase().contains(q)).toList();
    }
    return items;
  }
}

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(ref.watch(apiClientProvider));
});

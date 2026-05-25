import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';

class CatalogRepository {
  final ApiClient _api;
  CatalogRepository(this._api);

  Future<List<CategoryModel>> getCategories() async {
    final res = await _api.dio.get('/categories');
    final list = res.data as List<dynamic>;
    return list.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ProductModel>> getProducts({
    String? categoryId,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (categoryId case final id?) params['category'] = id;
    if (search case final s? when s.isNotEmpty) params['search'] = s;
    final res = await _api.dio.get('/products', queryParameters: params);
    final data = res.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>;
    return items.map((e) => ProductModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ProductModel> getProduct(String id) async {
    final res = await _api.dio.get('/products/$id');
    return ProductModel.fromJson(res.data as Map<String, dynamic>);
  }
}

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(ref.watch(apiClientProvider));
});

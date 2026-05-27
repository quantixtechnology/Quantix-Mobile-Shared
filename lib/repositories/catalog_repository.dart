import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../branding/brand_provider.dart';
import '../demo/demo_data.dart';
import '../exceptions/app_exception.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../utils/error_mapper.dart';

class CatalogRepository {
  final ApiClient _api;
  final String _imageBaseUrl;

  CatalogRepository(this._api, this._imageBaseUrl);

  Future<List<CategoryModel>> getCategories() async {
    if (kUseDemoData) return DemoData.categories;
    try {
      final res = await _api.dio.get(
        '/api/core/storefront/categories',
        queryParameters: {'businessId': _api.tenantId},
      );
      final body = res.data as Map<String, dynamic>;
      final list = body['data'] as List<dynamic>;
      return list
          .map((e) => CategoryModel.fromJson(
                e as Map<String, dynamic>,
                imageBaseUrl: _imageBaseUrl,
              ))
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
      final params = <String, dynamic>{
        'businessId': _api.tenantId,
        'page': page,
        'limit': limit,
      };
      if (categoryId != null) params['categoryId'] = categoryId;
      if (search != null && search.isNotEmpty) params['search'] = search;
      final res = await _api.dio.get(
        '/api/core/storefront/products',
        queryParameters: params,
      );
      final body = res.data as Map<String, dynamic>;
      final items = body['data'] as List<dynamic>;
      return items
          .map((e) => ProductModel.fromStorefrontJson(
                e as Map<String, dynamic>,
                imageBaseUrl: _imageBaseUrl,
              ))
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
      final res = await _api.dio.get(
        '/api/core/storefront/products/$id',
        queryParameters: {'businessId': _api.tenantId},
      );
      final body = res.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      return ProductModel.fromStorefrontJson(data, imageBaseUrl: _imageBaseUrl);
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
  final api = ref.watch(apiClientProvider);
  final flavor = ref.watch(brandFlavorProvider);
  final imageBaseUrl = 'https://$flavor.quantixtechnology.in';
  return CatalogRepository(api, imageBaseUrl);
});

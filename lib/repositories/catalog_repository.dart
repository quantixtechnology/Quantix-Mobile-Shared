import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../branding/brand_provider.dart';
import '../exceptions/app_exception.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../utils/error_mapper.dart';

class CatalogRepository {
  final ApiClient _api;
  final String _businessId;

  CatalogRepository(this._api, {required String businessId})
      : _businessId = businessId;

  Future<List<CategoryModel>> getCategories() async {
    debugPrint('[PRODUCTS] getCategories businessId=$_businessId endpoint=/api/core/categories');
    try {
      final res = await _api.dio.get(
        '/api/core/categories',
        queryParameters: {'businessId': _businessId},
      );
      final data = res.data as Map<String, dynamic>;
      final list = data['data'] as List<dynamic>;
      final categories = list
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
      debugPrint('[PRODUCTS] getCategories count=${categories.length} response=OK');
      return categories;
    } on DioException catch (e) {
      debugPrint('[PRODUCTS] getCategories error: ${e.type} ${e.response?.statusCode}');
      throw mapDioError(e);
    }
  }

  Future<List<ProductModel>> getProducts({
    String? categoryId,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    debugPrint(
      '[PRODUCTS] getProducts businessId=$_businessId categoryId=${categoryId ?? "all"} '
      'search=${search ?? ""} page=$page limit=$limit endpoint=/api/core/products',
    );
    try {
      final params = <String, dynamic>{
        'businessId': _businessId,
        'page': page,
        'limit': limit,
      };
      if (categoryId != null) params['categoryId'] = categoryId;
      if (search != null && search.isNotEmpty) params['search'] = search;

      final res = await _api.dio.get(
        '/api/core/products',
        queryParameters: params,
      );
      final data = res.data as Map<String, dynamic>;
      final items = (data['data'] as Map<String, dynamic>)['items'] as List<dynamic>;
      final products = items
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList();
      debugPrint('[PRODUCTS] getProducts count=${products.length} response=OK');
      return products;
    } on DioException catch (e) {
      debugPrint('[PRODUCTS] getProducts error: ${e.type} ${e.response?.statusCode}');
      throw mapDioError(e);
    }
  }

  Future<ProductModel> getProduct(String id) async {
    debugPrint('[PRODUCTS] getProduct id=$id businessId=$_businessId');
    try {
      final res = await _api.dio.get(
        '/api/core/products/$id',
        queryParameters: {'businessId': _businessId},
      );
      final data = res.data as Map<String, dynamic>;
      final product = ProductModel.fromJson(data['data'] as Map<String, dynamic>);
      debugPrint('[PRODUCTS] getProduct response=OK name=${product.name}');
      return product;
    } on DioException catch (e) {
      debugPrint('[PRODUCTS] getProduct error: ${e.type} ${e.response?.statusCode}');
      throw mapDioError(e);
    }
  }
}

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  final brand = ref.watch(brandConfigProvider);
  return CatalogRepository(api, businessId: brand.businessId);
});

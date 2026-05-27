import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../branding/brand_config.dart';
import '../branding/brand_provider.dart';
import '../exceptions/app_exception.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../utils/error_mapper.dart';

class CatalogRepository {
  final ApiClient _api;
  final BrandConfig _brand;
  final String _flavor;

  CatalogRepository(this._api, this._brand, this._flavor);

  String get _businessId => _brand.businessId;
  String get _currency => _brand.currency;
  // Image paths from storefront API are relative (/uploads/...).
  // They are served from the tenant's storefront domain.
  String get _imageBaseUrl => 'https://$_flavor.quantixtechnology.in';

  Future<List<CategoryModel>> getCategories() async {
    debugPrint('[CATALOG_SYNC] getCategories businessId=$_businessId endpoint=/api/core/storefront/categories');
    try {
      final res = await _api.dio.get(
        '/api/core/storefront/categories',
        queryParameters: {'businessId': _businessId},
      );
      final data = res.data as Map<String, dynamic>;
      final list = data['data'] as List<dynamic>;
      final categories = list.map((e) {
        final map = e as Map<String, dynamic>;
        final rawImage = map['image'];
        debugPrint('[IMAGE] category id=${map['id']} name=${map['name']} raw=$rawImage');
        final cat = CategoryModel.fromJson(map, imageBaseUrl: _imageBaseUrl);
        debugPrint('[IMAGE] category id=${map['id']} normalized=${cat.image ?? "null"}');
        return cat;
      }).toList();
      debugPrint('[CATALOG_SYNC] categories businessId=$_businessId count=${categories.length} response=OK');
      return categories;
    } on DioException catch (e) {
      debugPrint('[CATALOG_SYNC] getCategories error: ${e.type} ${e.response?.statusCode} ${e.response?.data}');
      throw mapDioError(e);
    }
  }

  Future<List<ProductModel>> getProducts({
    String? categoryId,
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    debugPrint(
      '[CATALOG_SYNC] getProducts businessId=$_businessId categoryId=${categoryId ?? "all"} '
      'search=${search ?? ""} endpoint=/api/core/storefront/products',
    );
    try {
      final params = <String, dynamic>{'businessId': _businessId};
      if (categoryId != null) params['categoryId'] = categoryId;
      if (search != null && search.isNotEmpty) params['search'] = search;

      final res = await _api.dio.get(
        '/api/core/storefront/products',
        queryParameters: params,
      );
      final data = res.data as Map<String, dynamic>;
      final items = data['data'] as List<dynamic>;
      final products = items.map((e) {
        final map = e as Map<String, dynamic>;
        final rawImages = map['images'];
        debugPrint('[IMAGE] product id=${map['id']} name=${map['name']} raw_images=$rawImages');
        final p = ProductModel.fromStorefrontJson(map, currency: _currency, imageBaseUrl: _imageBaseUrl);
        debugPrint('[IMAGE] product id=${map['id']} normalized=${p.image ?? "null"}');
        return p;
      }).toList();
      debugPrint(
        '[CATALOG_SYNC] websiteProducts=${products.length} mobileProducts=${products.length} '
        'endpoint=/api/core/storefront/products businessId=$_businessId response=OK',
      );
      return products;
    } on DioException catch (e) {
      debugPrint('[CATALOG_SYNC] getProducts error: ${e.type} ${e.response?.statusCode}');
      throw mapDioError(e);
    }
  }

  Future<ProductModel> getProduct(String id) async {
    debugPrint('[CATALOG_SYNC] getProduct id=$id businessId=$_businessId');
    try {
      final res = await _api.dio.get(
        '/api/core/storefront/products/$id',
        queryParameters: {'businessId': _businessId},
      );
      final data = res.data as Map<String, dynamic>;
      final rawProduct = data['data'] as Map<String, dynamic>;
      final product = ProductModel.fromStorefrontJson(
        rawProduct,
        currency: _currency,
        imageBaseUrl: _imageBaseUrl,
      );
      debugPrint('[CATALOG_SYNC] getProduct response=OK name=${product.name}');
      return product;
    } on DioException catch (e) {
      debugPrint('[CATALOG_SYNC] getProduct error: ${e.type} ${e.response?.statusCode}');
      throw mapDioError(e);
    }
  }
}

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  final brand = ref.watch(brandConfigProvider);
  final flavor = ref.watch(brandFlavorProvider);
  return CatalogRepository(api, brand, flavor);
});

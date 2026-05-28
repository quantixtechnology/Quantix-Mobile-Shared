import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/store_model.dart';

class StoreRepository {
  final ApiClient _api;
  StoreRepository(this._api);

  Future<List<StoreModel>> getStores({double? lat, double? lng}) async {
    debugPrint('[STORE] fetching stores businessId=${_api.tenantId}');
    try {
      final body = <String, dynamic>{'businessId': _api.tenantId};
      if (lat != null && lng != null) {
        body['lat'] = lat;
        body['lng'] = lng;
      }
      final res = await _api.dio.post(
        '/api/core/storefront/nearest-store',
        data: body,
      );
      final data = res.data as Map<String, dynamic>;
      final list = (data['data'] as List<dynamic>?) ?? [];
      debugPrint('[STORE] received ${list.length} stores');
      return list
          .map((e) => StoreModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint('[STORE] error ${e.response?.statusCode}: ${e.message}');
      rethrow;
    }
  }
}

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return StoreRepository(ref.watch(apiClientProvider));
});

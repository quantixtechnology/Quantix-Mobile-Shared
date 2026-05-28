import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../auth/user_model.dart';
import '../demo/demo_data.dart';
import '../exceptions/app_exception.dart';
import '../models/address_model.dart';
import '../utils/error_mapper.dart';

class ProfileRepository {
  final ApiClient _api;
  ProfileRepository(this._api);

  Future<UserModel> getProfile() async {
    if (kUseDemoData) return DemoData.customers.first;
    try {
      final res = await _api.dio.get('/api/core/storefront/profile');
      final body = res.data as Map<String, dynamic>;
      return UserModel.fromJson((body['data'] as Map<String, dynamic>?) ?? body);
    } on DioException catch (e) {
      final err = mapDioError(e);
      if (err is OfflineException) return DemoData.customers.first;
      throw err;
    }
  }

  Future<UserModel> updateProfile({String? name, String? email}) async {
    if (kUseDemoData) return DemoData.customers.first;
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (email != null) body['email'] = email;
      final res = await _api.dio.patch('/api/core/storefront/profile', data: body);
      final resBody = res.data as Map<String, dynamic>;
      return UserModel.fromJson((resBody['data'] as Map<String, dynamic>?) ?? resBody);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<List<AddressModel>> getAddresses() async {
    if (kUseDemoData) return DemoData.addresses;
    debugPrint('[PROFILE] GET /api/core/storefront/addresses');
    try {
      final res = await _api.dio.get('/api/core/storefront/addresses');
      final body = res.data as Map<String, dynamic>;
      final list = (body['data'] as List<dynamic>?) ?? [];
      debugPrint('[PROFILE] getAddresses → ${list.length} items');
      return list
          .map((e) => AddressModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint('[PROFILE] getAddresses DioError: status=${e.response?.statusCode} body=${e.response?.data}');
      final err = mapDioError(e);
      if (err is OfflineException) return DemoData.addresses;
      // 404 = route not found or user has no addresses — return empty
      if (e.response?.statusCode == 404) return [];
      throw err;
    }
  }

  Future<AddressModel> addAddress({
    required String label,
    required String line1,
    required String city,
    required double lat,
    required double lng,
  }) async {
    if (kUseDemoData) return DemoData.addresses.first;
    try {
      final res = await _api.dio.post('/api/core/storefront/addresses', data: {
        'label': label,
        'line1': line1,
        'city': city,
        'lat': lat,
        'lng': lng,
      });
      final body = res.data as Map<String, dynamic>;
      return AddressModel.fromJson((body['data'] as Map<String, dynamic>?) ?? body);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<void> deleteAddress(String id) async {
    if (kUseDemoData) return;
    try {
      await _api.dio.delete('/api/core/storefront/addresses/$id');
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});

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
      if (e.response?.statusCode == 404) return [];
      throw err;
    }
  }

  Future<AddressModel> addAddress({
    required String label,
    required String addressLine1,
    String? addressLine2,
    String? area,
    String? landmark,
    required String city,
    String state = '',
    required String pincode,
    String? instructions,
    bool isDefault = false,
    double latitude = 0.0,
    double longitude = 0.0,
  }) async {
    if (kUseDemoData) return DemoData.addresses.first;
    try {
      final res = await _api.dio.post('/api/core/storefront/addresses', data: {
        'label': label,
        'line1': addressLine1,
        if (addressLine2?.isNotEmpty == true) 'line2': addressLine2,
        if (area?.isNotEmpty == true) 'area': area,
        if (landmark?.isNotEmpty == true) 'landmark': landmark,
        'city': city,
        'state': state.isNotEmpty ? state : 'Karnataka',
        'pincode': pincode,
        if (instructions?.isNotEmpty == true) 'instructions': instructions,
        'isDefault': isDefault,
        if (latitude != 0.0) 'latitude': latitude,
        if (longitude != 0.0) 'longitude': longitude,
      });
      final body = res.data as Map<String, dynamic>;
      return AddressModel.fromJson((body['data'] as Map<String, dynamic>?) ?? body);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<AddressModel> updateAddress({
    required String id,
    String? label,
    String? addressLine1,
    String? addressLine2,
    String? area,
    String? landmark,
    String? city,
    String? state,
    String? pincode,
    String? instructions,
    bool? isDefault,
    double? latitude,
    double? longitude,
  }) async {
    if (kUseDemoData) return DemoData.addresses.first;
    try {
      final data = <String, dynamic>{
        if (label != null) 'label': label,
        if (addressLine1 != null) 'line1': addressLine1,
        if (addressLine2 != null) 'line2': addressLine2,
        if (area != null) 'area': area,
        if (landmark != null) 'landmark': landmark,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        if (pincode != null) 'pincode': pincode,
        if (instructions != null) 'instructions': instructions,
        if (isDefault != null) 'isDefault': isDefault,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };
      final res = await _api.dio.patch(
        '/api/core/storefront/addresses/$id',
        data: data,
      );
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

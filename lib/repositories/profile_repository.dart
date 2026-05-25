import 'package:dio/dio.dart';
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
      final res = await _api.dio.get('/profile');
      return UserModel.fromJson(res.data as Map<String, dynamic>);
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
      final res = await _api.dio.patch('/profile', data: body);
      return UserModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<List<AddressModel>> getAddresses() async {
    if (kUseDemoData) return DemoData.addresses;
    try {
      final res = await _api.dio.get('/addresses');
      final list = res.data as List<dynamic>;
      return list
          .map((e) => AddressModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      final err = mapDioError(e);
      if (err is OfflineException) return DemoData.addresses;
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
      final res = await _api.dio.post('/addresses', data: {
        'label': label,
        'line1': line1,
        'city': city,
        'lat': lat,
        'lng': lng,
      });
      return AddressModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<void> deleteAddress(String id) async {
    if (kUseDemoData) return;
    try {
      await _api.dio.delete('/addresses/$id');
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});

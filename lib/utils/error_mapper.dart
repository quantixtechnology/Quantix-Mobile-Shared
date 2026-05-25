import 'package:dio/dio.dart';
import '../exceptions/app_exception.dart';

AppException mapDioError(DioException e) {
  if (e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.unknown) {
    return const OfflineException();
  }
  final status = e.response?.statusCode;
  final body = e.response?.data;
  final message = body is Map ? (body['message'] as String? ?? 'Request failed') : 'Request failed';
  return switch (status) {
    401 => const UnauthorizedException(),
    403 => TenantException(message),
    422 => ValidationException(message),
    int s when s >= 500 => ServerException(message, statusCode: s),
    _ => NetworkException(message, statusCode: status),
  };
}

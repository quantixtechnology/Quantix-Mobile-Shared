class AppException implements Exception {
  final String message;
  final int? statusCode;

  const AppException(this.message, {this.statusCode});

  @override
  String toString() => 'AppException($statusCode): $message';
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.statusCode});
}

class UnauthorizedException extends AppException {
  const UnauthorizedException() : super('Unauthorized', statusCode: 401);
}

class ValidationException extends AppException {
  const ValidationException(super.message) : super(statusCode: 422);
}

class ServerException extends AppException {
  const ServerException(super.message, {super.statusCode});
}

class TenantException extends AppException {
  const TenantException(super.message) : super(statusCode: 403);
}

class OfflineException extends AppException {
  const OfflineException() : super('No internet connection', statusCode: 0);
}

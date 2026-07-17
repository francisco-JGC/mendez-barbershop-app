/// Infrastructure-layer exceptions. Thrown by data sources and translated into
/// domain-level [Failure] types by repository implementations.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

class ServerException extends AppException {
  const ServerException(super.message, {this.statusCode, super.cause});
  final int? statusCode;
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause});
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Unauthorized']);
}

class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Not found']);
}

class ValidationException extends AppException {
  const ValidationException(super.message, {this.fieldErrors, super.cause});
  final Map<String, List<String>>? fieldErrors;
}

class CacheException extends AppException {
  const CacheException(super.message, {super.cause});
}

class BluetoothException extends AppException {
  const BluetoothException(super.message, {super.cause});
}

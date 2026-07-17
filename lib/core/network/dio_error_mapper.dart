import 'package:dio/dio.dart';

import '../errors/exceptions.dart';

/// Shared translation from [DioException] → typed [AppException]. Kept in one
/// place so every data source maps errors the same way.
AppException mapDioError(DioException e) {
  final status = e.response?.statusCode;
  if (status == 401) return const UnauthorizedException();
  if (status == 404) return const NotFoundException();
  if (status != null && status >= 400 && status < 500) {
    final data = e.response?.data;
    String message = 'Error de solicitud';
    if (data is Map && data['message'] != null) {
      final msg = data['message'];
      message = msg is List ? msg.join(', ') : msg.toString();
    }
    return ServerException(message, statusCode: status, cause: e);
  }
  if (e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout) {
    return NetworkException('Sin conexión al servidor', cause: e);
  }
  return ServerException('Error del servidor', statusCode: status, cause: e);
}

import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/user_model.dart';

abstract interface class AuthRemoteDataSource {
  /// [identifier] is the email (for admins) or username (for barbers/sellers)
  /// — the backend accepts either on the same field.
  Future<AuthTokensDto> login({
    required String identifier,
    required String password,
  });

  Future<AuthTokensDto> refresh(String refreshToken);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this._dio);
  final Dio _dio;

  @override
  Future<AuthTokensDto> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.login,
        data: {'identifier': identifier, 'password': password},
      );
      return AuthTokensDto.fromJson(res.data!);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  @override
  Future<AuthTokensDto> refresh(String refreshToken) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.refresh,
        data: {'refreshToken': refreshToken},
      );
      return AuthTokensDto.fromJson(res.data!);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }
}

AppException _mapDioError(DioException e) {
  final status = e.response?.statusCode;
  if (status == 401) {
    return const UnauthorizedException('Credenciales inválidas');
  }
  if (status != null && status >= 400 && status < 500) {
    final message = e.response?.data is Map
        ? (e.response!.data['message']?.toString() ?? 'Error de solicitud')
        : 'Error de solicitud';
    return ServerException(message, statusCode: status, cause: e);
  }
  if (e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout) {
    return NetworkException('Sin conexión al servidor', cause: e);
  }
  return ServerException('Error del servidor', statusCode: status, cause: e);
}

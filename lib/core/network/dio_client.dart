import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import 'auth_interceptor.dart';
import 'tenant_interceptor.dart';

class DioClient {
  DioClient._();

  static Dio create({
    required String baseUrl,
    required TenantInterceptor tenantInterceptor,
    required AuthInterceptor authInterceptor,
    bool enableLogging = true,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        responseType: ResponseType.json,
      ),
    );

    // Tenant first so the header is present even if the request fails on auth.
    dio.interceptors.add(tenantInterceptor);
    dio.interceptors.add(authInterceptor);
    if (enableLogging) {
      dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: false,
          requestBody: true,
          responseBody: true,
          error: true,
          compact: true,
        ),
      );
    }
    return dio;
  }
}

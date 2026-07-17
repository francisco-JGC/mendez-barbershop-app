import 'package:dio/dio.dart';

import '../tenant/tenant_code_storage.dart';

/// Attaches `X-Tenant-Code` to every outgoing request. Reads the value from
/// storage on each request (not once at Dio construction) so the header stays
/// in sync when the seller switches barbershops without restarting the app.
class TenantInterceptor extends Interceptor {
  TenantInterceptor(this._storage);
  final TenantCodeStorage _storage;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final code = _storage.get();
    if (code != null && code.isNotEmpty) {
      options.headers['X-Tenant-Code'] = code;
    }
    handler.next(options);
  }
}

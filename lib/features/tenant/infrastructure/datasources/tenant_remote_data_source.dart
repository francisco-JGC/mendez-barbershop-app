import 'package:dio/dio.dart';

import '../../../../core/network/dio_error_mapper.dart';
import '../models/tenant_lookup_dto.dart';

abstract interface class TenantRemoteDataSource {
  Future<TenantLookupDto> lookup(String code);
}

class TenantRemoteDataSourceImpl implements TenantRemoteDataSource {
  TenantRemoteDataSourceImpl(this._dio);
  final Dio _dio;

  @override
  Future<TenantLookupDto> lookup(String code) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/tenants/lookup/${Uri.encodeComponent(code)}',
      );
      return TenantLookupDto.fromJson(res.data!);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}

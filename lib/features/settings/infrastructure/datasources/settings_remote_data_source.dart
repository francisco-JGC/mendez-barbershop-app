import 'package:dio/dio.dart';

import '../../../../core/network/dio_error_mapper.dart';
import '../models/settings_dtos.dart';

abstract interface class SettingsRemoteDataSource {
  Future<BarbershopSettingsDto> fetchSettings();
  Future<BarbershopInfoDto> fetchBarbershop();
}

class SettingsRemoteDataSourceImpl implements SettingsRemoteDataSource {
  SettingsRemoteDataSourceImpl(this._dio);
  final Dio _dio;

  @override
  Future<BarbershopSettingsDto> fetchSettings() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/settings');
      return BarbershopSettingsDto.fromJson(res.data!);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  @override
  Future<BarbershopInfoDto> fetchBarbershop() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/tenants/current');
      return BarbershopInfoDto.fromJson(res.data!);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}

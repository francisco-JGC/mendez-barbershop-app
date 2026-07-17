import 'package:dio/dio.dart';

import '../../../../core/network/dio_error_mapper.dart';
import '../models/user_response_dto.dart';

abstract interface class StaffRemoteDataSource {
  Future<List<UserResponseDto>> listUsers();
}

class StaffRemoteDataSourceImpl implements StaffRemoteDataSource {
  StaffRemoteDataSourceImpl(this._dio);
  final Dio _dio;

  @override
  Future<List<UserResponseDto>> listUsers() async {
    try {
      final res = await _dio.get<List<dynamic>>('/users');
      return (res.data ?? [])
          .map((e) => UserResponseDto.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}

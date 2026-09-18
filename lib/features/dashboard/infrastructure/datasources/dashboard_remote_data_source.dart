import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_error_mapper.dart';
import '../../domain/entities/dashboard_period.dart';
import '../models/barber_dashboard_dto.dart';

abstract interface class DashboardRemoteDataSource {
  Future<BarberDashboardSummaryDto> barberSummary(DashboardPeriod period);
}

class DashboardRemoteDataSourceImpl implements DashboardRemoteDataSource {
  DashboardRemoteDataSourceImpl(this._dio);
  final Dio _dio;

  @override
  Future<BarberDashboardSummaryDto> barberSummary(
    DashboardPeriod period,
  ) async {
    try {
      // The endpoint scopes everything to the barber in the JWT — there is no
      // barberId to send, and none can be spoofed from here.
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.barberDashboard,
        queryParameters: {'period': period.value},
      );
      return BarberDashboardSummaryDto.fromJson(res.data!);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}

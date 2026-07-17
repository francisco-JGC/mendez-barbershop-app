import 'package:dio/dio.dart';

import '../../../../core/network/dio_error_mapper.dart';
import '../../domain/repositories/ticket_repository.dart';
import '../models/ticket_dto.dart';

abstract interface class TicketsRemoteDataSource {
  Future<TicketDto> create(CreateTicketParams params);
  Future<PaginatedTicketsDto> list({
    int page,
    int limit,
    String? barberId,
  });
}

class TicketsRemoteDataSourceImpl implements TicketsRemoteDataSource {
  TicketsRemoteDataSourceImpl(this._dio);
  final Dio _dio;

  @override
  Future<TicketDto> create(CreateTicketParams params) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/tickets',
        data: {
          if (params.barberId != null) 'barberId': params.barberId,
          'items': params.items
              .map((i) => {
                    'itemType': i.itemType.wireName,
                    'itemId': i.itemId,
                    'quantity': i.quantity,
                  })
              .toList(),
        },
      );
      return TicketDto.fromJson(res.data!);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  @override
  Future<PaginatedTicketsDto> list({
    int page = 1,
    int limit = 20,
    String? barberId,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/tickets',
        queryParameters: {
          'page': page,
          'limit': limit,
          // ignore: use_null_aware_elements
          if (barberId != null) 'barberId': barberId,
        },
      );
      return PaginatedTicketsDto.fromJson(res.data!);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}

import 'package:dio/dio.dart';

import '../../../../core/network/dio_error_mapper.dart';
import '../models/catalog_dtos.dart';

abstract interface class CatalogRemoteDataSource {
  Future<List<ServiceDto>> listServices();
  Future<List<ProductDto>> listProducts();
  Future<ProductDto> productByBarcode(String barcode);
}

class CatalogRemoteDataSourceImpl implements CatalogRemoteDataSource {
  CatalogRemoteDataSourceImpl(this._dio);
  final Dio _dio;

  @override
  Future<List<ServiceDto>> listServices() async {
    try {
      final res = await _dio.get<List<dynamic>>('/services');
      return (res.data ?? [])
          .map((e) => ServiceDto.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  @override
  Future<List<ProductDto>> listProducts() async {
    try {
      final res = await _dio.get<List<dynamic>>('/products');
      return (res.data ?? [])
          .map((e) => ProductDto.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  @override
  Future<ProductDto> productByBarcode(String barcode) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/products/by-barcode/${Uri.encodeComponent(barcode)}',
      );
      return ProductDto.fromJson(res.data!);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}

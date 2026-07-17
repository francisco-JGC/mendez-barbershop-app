import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/service.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../datasources/catalog_remote_data_source.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl(this._remote);
  final CatalogRemoteDataSource _remote;

  @override
  Future<Either<Failure, List<Service>>> listServices() async {
    try {
      final dtos = await _remote.listServices();
      return Right(dtos
          .map((e) => e.toDomain())
          .where((s) => s.isActive)
          .toList(growable: false));
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, List<Product>>> listProducts() async {
    try {
      final dtos = await _remote.listProducts();
      return Right(dtos
          .map((e) => e.toDomain())
          .where((p) => p.isActive)
          .toList(growable: false));
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, Product>> productByBarcode(String barcode) async {
    try {
      final dto = await _remote.productByBarcode(barcode);
      return Right(dto.toDomain());
    } on NotFoundException {
      return const Left(NotFoundFailure('Producto no encontrado'));
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }
}

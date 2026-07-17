import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/tenant_lookup.dart';
import '../../domain/repositories/tenant_repository.dart';
import '../datasources/tenant_remote_data_source.dart';

class TenantRepositoryImpl implements TenantRepository {
  TenantRepositoryImpl(this._remote);
  final TenantRemoteDataSource _remote;

  @override
  Future<Either<Failure, TenantLookup>> lookup(String code) async {
    try {
      final dto = await _remote.lookup(code);
      return Right(dto.toDomain());
    } on NotFoundException {
      return const Left(NotFoundFailure('No encontramos esa sucursal'));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }
}

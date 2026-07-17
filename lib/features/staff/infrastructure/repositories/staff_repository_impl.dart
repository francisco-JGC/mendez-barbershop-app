import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/barber.dart';
import '../../domain/repositories/staff_repository.dart';
import '../datasources/staff_remote_data_source.dart';

class StaffRepositoryImpl implements StaffRepository {
  StaffRepositoryImpl(this._remote);
  final StaffRemoteDataSource _remote;

  @override
  Future<Either<Failure, List<Barber>>> listBarbers() async {
    try {
      final dtos = await _remote.listUsers();
      // Backend returns all roles; filter here — mirrors what the web POS does
      // client-side so both stay consistent.
      return Right(dtos
          .where((u) => u.role == 'barber' && u.isActive)
          .map((u) => u.toBarber())
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
}

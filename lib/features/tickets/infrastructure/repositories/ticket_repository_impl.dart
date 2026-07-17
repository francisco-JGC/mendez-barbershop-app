import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/ticket.dart';
import '../../domain/repositories/ticket_repository.dart';
import '../datasources/tickets_remote_data_source.dart';

class TicketRepositoryImpl implements TicketRepository {
  TicketRepositoryImpl(this._remote);
  final TicketsRemoteDataSource _remote;

  @override
  Future<Either<Failure, Ticket>> create(CreateTicketParams params) async {
    try {
      final dto = await _remote.create(params);
      return Right(dto.toDomain());
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, ListTicketsPage>> list({
    int page = 1,
    int limit = 20,
    String? barberId,
  }) async {
    try {
      final dto =
          await _remote.list(page: page, limit: limit, barberId: barberId);
      return Right(ListTicketsPage(
        items: dto.items.map((e) => e.toDomain()).toList(growable: false),
        total: dto.total,
        page: page,
        limit: limit,
      ));
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

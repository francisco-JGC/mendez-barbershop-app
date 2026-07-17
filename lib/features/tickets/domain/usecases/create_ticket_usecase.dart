import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/ticket.dart';
import '../repositories/ticket_repository.dart';
import '../value_objects/ticket_item_type.dart';

class CreateTicketUseCase {
  const CreateTicketUseCase(this._repo);
  final TicketRepository _repo;

  Future<Either<Failure, Ticket>> call(CreateTicketParams params) {
    if (params.items.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Agrega al menos un item al ticket')),
      );
    }
    final hasService =
        params.items.any((i) => i.itemType == TicketItemType.service);
    if (hasService && (params.barberId == null || params.barberId!.isEmpty)) {
      return Future.value(
        const Left(ValidationFailure(
          'Selecciona un barbero cuando el ticket incluye un servicio',
        )),
      );
    }
    return _repo.create(params);
  }
}

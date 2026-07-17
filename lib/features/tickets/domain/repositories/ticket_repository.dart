import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/ticket.dart';
import '../value_objects/ticket_item_type.dart';

class DraftTicketItem {
  const DraftTicketItem({
    required this.itemType,
    required this.itemId,
    required this.quantity,
  });
  final TicketItemType itemType;
  final String itemId;
  final int quantity;
}

class CreateTicketParams {
  const CreateTicketParams({required this.items, this.barberId});
  final String? barberId;
  final List<DraftTicketItem> items;
}

class ListTicketsPage {
  const ListTicketsPage({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });
  final List<Ticket> items;
  final int total;
  final int page;
  final int limit;
}

abstract interface class TicketRepository {
  Future<Either<Failure, Ticket>> create(CreateTicketParams params);
  Future<Either<Failure, ListTicketsPage>> list({
    int page = 1,
    int limit = 20,
    String? barberId,
  });
}

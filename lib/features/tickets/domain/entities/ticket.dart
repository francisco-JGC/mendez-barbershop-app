import 'ticket_item.dart';

class Ticket {
  const Ticket({
    required this.id,
    required this.barbershopId,
    required this.total,
    required this.createdAt,
    required this.items,
    this.barberId,
    this.stationId,
  });

  final String id;
  final String barbershopId;
  final String? barberId;
  final String? stationId;
  final String total;
  final List<TicketItem> items;
  final DateTime createdAt;
}

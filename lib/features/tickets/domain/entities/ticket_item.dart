import '../value_objects/ticket_item_type.dart';

/// Server-side representation of a ticket line. Prices are decimal strings
/// (e.g. "150.00") to match backend precision — parse on demand for math.
class TicketItem {
  const TicketItem({
    required this.id,
    required this.ticketId,
    required this.itemType,
    required this.itemId,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  final String id;
  final String ticketId;
  final TicketItemType itemType;
  final String itemId;
  final int quantity;
  final String unitPrice;
  final String subtotal;
}

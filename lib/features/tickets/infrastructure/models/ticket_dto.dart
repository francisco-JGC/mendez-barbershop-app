import '../../domain/entities/ticket.dart';
import '../../domain/entities/ticket_item.dart';
import '../../domain/value_objects/ticket_item_type.dart';

class TicketItemDto {
  const TicketItemDto({
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
  final String itemType;
  final String itemId;
  final int quantity;
  final String unitPrice;
  final String subtotal;

  factory TicketItemDto.fromJson(Map<String, dynamic> json) => TicketItemDto(
        id: json['id'] as String,
        ticketId: json['ticketId'] as String,
        itemType: json['itemType'] as String,
        itemId: json['itemId'] as String,
        quantity: (json['quantity'] as num).toInt(),
        unitPrice: json['unitPrice'].toString(),
        subtotal: json['subtotal'].toString(),
      );

  TicketItem toDomain() => TicketItem(
        id: id,
        ticketId: ticketId,
        itemType: TicketItemType.fromWire(itemType),
        itemId: itemId,
        quantity: quantity,
        unitPrice: unitPrice,
        subtotal: subtotal,
      );
}

class TicketDto {
  const TicketDto({
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
  final DateTime createdAt;
  final List<TicketItemDto> items;

  factory TicketDto.fromJson(Map<String, dynamic> json) => TicketDto(
        id: json['id'] as String,
        barbershopId: json['barbershopId'] as String,
        barberId: json['barberId'] as String?,
        stationId: json['stationId'] as String?,
        total: json['total'].toString(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => TicketItemDto.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );

  Ticket toDomain() => Ticket(
        id: id,
        barbershopId: barbershopId,
        barberId: barberId,
        stationId: stationId,
        total: total,
        createdAt: createdAt,
        items: items.map((e) => e.toDomain()).toList(growable: false),
      );
}

class PaginatedTicketsDto {
  const PaginatedTicketsDto({
    required this.items,
    required this.total,
  });

  final List<TicketDto> items;
  final int total;

  factory PaginatedTicketsDto.fromJson(Map<String, dynamic> json) =>
      PaginatedTicketsDto(
        items: (json['items'] as List<dynamic>)
            .map((e) => TicketDto.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        total: (json['total'] as num).toInt(),
      );
}

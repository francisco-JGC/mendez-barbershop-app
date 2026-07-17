import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../core/di/injection.dart';
import '../../../core/errors/failures.dart';
import '../../catalog/domain/entities/product.dart';
import '../../catalog/domain/entities/service.dart';
import '../domain/entities/ticket.dart';
import '../domain/repositories/ticket_repository.dart';
import '../domain/usecases/create_ticket_usecase.dart';
import '../domain/value_objects/ticket_item_type.dart';

/// A pending line the seller has added to the current cart. Prices are held
/// locally only for preview — the backend recomputes them at create time.
class CartLine {
  const CartLine({
    required this.itemType,
    required this.itemId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
  });

  final TicketItemType itemType;
  final String itemId;
  final String name;
  final String unitPrice;
  final int quantity;

  double get subtotal => double.parse(unitPrice) * quantity;

  CartLine copyWith({int? quantity}) => CartLine(
        itemType: itemType,
        itemId: itemId,
        name: name,
        unitPrice: unitPrice,
        quantity: quantity ?? this.quantity,
      );
}

class NewTicketState {
  const NewTicketState({
    this.lines = const [],
    this.barberId,
    this.isSubmitting = false,
    this.errorMessage,
    this.lastCreated,
  });

  final List<CartLine> lines;
  final String? barberId;
  final bool isSubmitting;
  final String? errorMessage;
  final Ticket? lastCreated;

  double get total => lines.fold(0, (a, l) => a + l.subtotal);
  int get totalUnits => lines.fold(0, (a, l) => a + l.quantity);
  bool get isEmpty => lines.isEmpty;
  bool get requiresBarber =>
      lines.any((l) => l.itemType == TicketItemType.service);

  NewTicketState copyWith({
    List<CartLine>? lines,
    String? barberId,
    bool? isSubmitting,
    String? errorMessage,
    Ticket? lastCreated,
    bool clearError = false,
    bool clearBarber = false,
    bool clearLastCreated = false,
  }) {
    return NewTicketState(
      lines: lines ?? this.lines,
      barberId: clearBarber ? null : (barberId ?? this.barberId),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastCreated:
          clearLastCreated ? null : (lastCreated ?? this.lastCreated),
    );
  }
}

class NewTicketController extends Notifier<NewTicketState> {
  late final CreateTicketUseCase _create;

  @override
  NewTicketState build() {
    _create = sl<CreateTicketUseCase>();
    return const NewTicketState();
  }

  void addService(Service service) => _addLine(
        itemType: TicketItemType.service,
        itemId: service.id,
        name: service.name,
        unitPrice: service.price,
      );

  void addProduct(Product product) => _addLine(
        itemType: TicketItemType.product,
        itemId: product.id,
        name: product.name,
        unitPrice: product.price,
      );

  void _addLine({
    required TicketItemType itemType,
    required String itemId,
    required String name,
    required String unitPrice,
  }) {
    final existing = state.lines.indexWhere(
      (l) => l.itemType == itemType && l.itemId == itemId,
    );
    List<CartLine> next;
    if (existing >= 0) {
      next = [...state.lines];
      next[existing] = next[existing].copyWith(
        quantity: next[existing].quantity + 1,
      );
    } else {
      next = [
        ...state.lines,
        CartLine(
          itemType: itemType,
          itemId: itemId,
          name: name,
          unitPrice: unitPrice,
          quantity: 1,
        ),
      ];
    }
    state = state.copyWith(lines: next, clearError: true);
  }

  void updateQuantity(int index, int quantity) {
    final next = [...state.lines];
    if (quantity <= 0) {
      next.removeAt(index);
    } else {
      next[index] = next[index].copyWith(quantity: quantity);
    }
    state = state.copyWith(lines: next);
  }

  void removeAt(int index) => updateQuantity(index, 0);

  void setBarberId(String? id) {
    state = state.copyWith(barberId: id, clearBarber: id == null);
  }

  void reset() => state = const NewTicketState();

  Future<Either<Failure, Ticket>> submit() async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    final result = await _create(
      CreateTicketParams(
        barberId: state.barberId,
        items: state.lines
            .map((l) => DraftTicketItem(
                  itemType: l.itemType,
                  itemId: l.itemId,
                  quantity: l.quantity,
                ))
            .toList(growable: false),
      ),
    );
    result.match(
      (f) => state = state.copyWith(
        isSubmitting: false,
        errorMessage: f.message,
      ),
      (ticket) => state = state.copyWith(
        isSubmitting: false,
        lastCreated: ticket,
      ),
    );
    return result;
  }
}

final newTicketControllerProvider =
    NotifierProvider<NewTicketController, NewTicketState>(
        NewTicketController.new);

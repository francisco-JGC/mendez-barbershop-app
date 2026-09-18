import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/injection.dart';
import '../../tickets/domain/repositories/ticket_repository.dart';

/// Tickets rung up under the signed-in barber. No `barberId` is sent: the
/// backend scopes `GET /tickets` to the barber in the JWT and ignores the
/// param for that role, so there is no way to ask for someone else's sales.
final barberHistoryProvider =
    FutureProvider.autoDispose<ListTicketsPage>((ref) async {
  final repo = sl<TicketRepository>();
  final result = await repo.list(page: 1, limit: 50);
  return result.match((f) => throw f, (page) => page);
});

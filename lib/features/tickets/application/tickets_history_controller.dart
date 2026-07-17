import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/injection.dart';
import '../domain/repositories/ticket_repository.dart';

final ticketsHistoryProvider =
    FutureProvider.autoDispose<ListTicketsPage>((ref) async {
  final repo = sl<TicketRepository>();
  final result = await repo.list(page: 1, limit: 50);
  return result.match((f) => throw f, (p) => p);
});

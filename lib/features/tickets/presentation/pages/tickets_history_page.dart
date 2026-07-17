import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/formatters.dart';
import '../../application/tickets_history_controller.dart';
import '../../domain/entities/ticket.dart';

class TicketsHistoryPage extends ConsumerWidget {
  const TicketsHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ticketsHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de ventas')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(ticketsHistoryProvider.future),
        child: async.when(
          data: (page) => page.items.isEmpty
              ? const _Empty()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: page.items.length,
                  separatorBuilder: (_, _) => const Gap(8),
                  itemBuilder: (_, i) => _TicketTile(ticket: page.items[i]),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                error is Failure ? error.message : 'No se pudo cargar',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(
            child: Icon(Icons.inbox_outlined,
                size: 72, color: Colors.grey.shade400)),
        const Gap(12),
        Center(
          child: Text('Todavía no hay ventas registradas',
              style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket});
  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final totalUnits = ticket.items.fold<int>(0, (a, i) => a + i.quantity);
    return Card(
      child: ListTile(
        title: Text(
          'Ticket ${ticket.id.substring(0, 8).toUpperCase()} · $totalUnits item(s)',
        ),
        subtitle: Text(Formatters.dateTime(ticket.createdAt)),
        trailing: Text(
          Formatters.money(ticket.total),
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        onTap: () => context.go('/sales/${ticket.id}'),
      ),
    );
  }
}

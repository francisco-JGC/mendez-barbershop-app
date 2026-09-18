import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../catalog/application/catalog_providers.dart';
import '../../../catalog/domain/entities/service.dart';
import '../../../tickets/domain/entities/ticket.dart';
import '../../../tickets/domain/entities/ticket_item.dart';
import '../../../tickets/domain/value_objects/ticket_item_type.dart';
import '../../application/barber_history_providers.dart';

/// Ticket-by-ticket history for the signed-in barber. Deliberately shows only
/// the service lines and their subtotal: products rung up on the same ticket
/// belong to the shop and never reach the barber's commission, so mixing them
/// into these totals would contradict the numbers on "Mi día".
class BarberHistoryPage extends ConsumerWidget {
  const BarberHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(barberHistoryProvider);
    // Names are a nicety — if the catalog call is still in flight (or fails)
    // we fall back to "Servicio" instead of blocking the list.
    final services =
        ref.watch(servicesProvider).asData?.value ?? const <Service>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis servicios'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(barberHistoryProvider.future),
        child: async.when(
          data: (page) {
            final tickets = page.items
                .where((t) => t.items.any(_isService))
                .toList(growable: false);
            if (tickets.isEmpty) return const _Empty();
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: tickets.length,
              separatorBuilder: (_, _) => const Gap(8),
              itemBuilder: (_, i) => _TicketCard(
                ticket: tickets[i],
                services: services,
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _Message(
            message: error is Failure
                ? error.message
                : 'No se pudo cargar tu historial',
            onRetry: () => ref.invalidate(barberHistoryProvider),
          ),
        ),
      ),
    );
  }
}

bool _isService(TicketItem item) => item.itemType == TicketItemType.service;

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.services});

  final Ticket ticket;
  final List<Service> services;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = ticket.items.where(_isService).toList(growable: false);
    final servicesTotal = lines.fold<double>(
      0,
      (sum, item) => sum + (double.tryParse(item.subtotal) ?? 0),
    );
    final units = lines.fold<int>(0, (sum, item) => sum + item.quantity);
    final hasProducts = ticket.items.any((i) => !_isService(i));

    String nameFor(String id) =>
        services.where((s) => s.id == id).map((s) => s.name).firstOrNull ??
        'Servicio';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: AppColors.muted),
                const Gap(6),
                Expanded(
                  child: Text(
                    Formatters.dateTime(ticket.createdAt),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                ),
                Text(
                  Formatters.money(servicesTotal),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const Gap(10),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        line.quantity > 1
                            ? '${line.quantity} × ${nameFor(line.itemId)}'
                            : nameFor(line.itemId),
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const Gap(8),
                    Text(
                      Formatters.money(line.subtotal),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            if (hasProducts) ...[
              const Gap(8),
              Text(
                'Este ticket también incluye productos, que no cuentan '
                'para tu comisión.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
            ],
            const Gap(6),
            Text(
              '$units servicio${units == 1 ? '' : 's'}',
              style:
                  theme.textTheme.labelSmall?.copyWith(color: AppColors.muted),
            ),
          ],
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
          child: Icon(Icons.content_cut, size: 64, color: Colors.grey.shade400),
        ),
        const Gap(12),
        Center(
          child: Text(
            'Todavía no tienes servicios registrados',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Icon(Icons.cloud_off, size: 56, color: Colors.grey.shade400),
        const Gap(12),
        Center(child: Text(message, textAlign: TextAlign.center)),
        const Gap(12),
        Center(
          child: FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Reintentar'),
          ),
        ),
      ],
    );
  }
}

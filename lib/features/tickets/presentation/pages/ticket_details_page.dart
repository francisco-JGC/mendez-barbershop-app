import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/formatters.dart';
import '../../../catalog/application/catalog_providers.dart';
import '../../../catalog/domain/entities/product.dart';
import '../../../catalog/domain/entities/service.dart';
import '../../../printer_settings/domain/services/printer_service.dart';
import '../../../settings/application/settings_providers.dart';
import '../../../staff/application/barbers_provider.dart';
import '../../../staff/domain/entities/barber.dart';
import '../../application/tickets_history_controller.dart';
import '../../domain/entities/ticket.dart';
import '../../domain/value_objects/ticket_item_type.dart';

class TicketDetailsPage extends ConsumerWidget {
  const TicketDetailsPage({super.key, required this.ticketId});

  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(ticketsHistoryProvider);

    return historyAsync.when(
      loading: () => _scaffold(
        title: 'Detalles del ticket',
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _scaffold(
        title: 'Detalles del ticket',
        body: _MessageView(
          message: e is Failure ? e.message : 'No se pudo cargar el ticket',
        ),
      ),
      data: (page) {
        // firstWhere with orElse-throw was surfacing as a Flutter "red screen"
        // whenever the ticket wasn't in the cached page (e.g. deep-link,
        // stale cache). Use where().firstOrNull so we can render a proper
        // "not found" state instead of crashing.
        final ticket =
            page.items.where((t) => t.id == ticketId).firstOrNull;
        if (ticket == null) {
          return _scaffold(
            title: 'Detalles del ticket',
            body: _MessageView(
              message:
                  'No encontramos este ticket. Refresca el historial e intenta de nuevo.',
            ),
          );
        }
        return _TicketDetailsView(ticket: ticket);
      },
    );
  }

  Widget _scaffold({required String title, required Widget body}) =>
      Scaffold(appBar: AppBar(title: Text(title)), body: body);
}

class _TicketDetailsView extends ConsumerStatefulWidget {
  const _TicketDetailsView({required this.ticket});

  final Ticket ticket;

  @override
  ConsumerState<_TicketDetailsView> createState() =>
      _TicketDetailsViewState();
}

class _TicketDetailsViewState extends ConsumerState<_TicketDetailsView> {
  bool _printing = false;

  Future<void> _reprint() async {
    if (_printing) return;
    setState(() => _printing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final settings = await ref.read(settingsProvider.future);
      final barbershop = await ref.read(barbershopInfoProvider.future);
      final services = await ref.read(servicesProvider.future);
      final products = await ref.read(productsProvider.future);
      final barbers = await ref.read(barbersProvider.future);
      final barberName = widget.ticket.barberId == null
          ? null
          : barbers
              .where((b) => b.id == widget.ticket.barberId)
              .map((b) => b.displayName)
              .firstOrNull;

      final res = await sl<PrinterService>().printTicket(PrintTicketArgs(
        ticket: widget.ticket,
        settings: settings,
        barbershop: barbershop,
        catalog: PrintableCatalog(services: services, products: products),
        barberName: barberName,
      ));
      res.match(
        (f) => messenger.showSnackBar(
          SnackBar(content: Text('No se pudo imprimir: ${f.message}')),
        ),
        (_) => messenger.showSnackBar(
          const SnackBar(content: Text('Ticket enviado a la impresora')),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    // asData.value returns null while loading/erroring — we degrade to an
    // empty list so the details view always renders, even if names are
    // temporarily missing.
    final barbers = ref.watch(barbersProvider).asData?.value ?? const <Barber>[];
    final services =
        ref.watch(servicesProvider).asData?.value ?? const <Service>[];
    final products =
        ref.watch(productsProvider).asData?.value ?? const <Product>[];

    final barberName = ticket.barberId == null
        ? null
        : barbers
            .where((b) => b.id == ticket.barberId)
            .map((b) => b.displayName)
            .firstOrNull;

    String nameFor(String type, String id) {
      if (type == TicketItemType.service.wireName) {
        return services
                .where((s) => s.id == id)
                .map((s) => s.name)
                .firstOrNull ??
            'Servicio';
      }
      return products
              .where((p) => p.id == id)
              .map((p) => p.name)
              .firstOrNull ??
          'Producto';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Ticket ${_shortId(ticket.id)}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('Fecha', Formatters.dateTime(ticket.createdAt)),
                  _row(
                    'Barbero',
                    barberName ??
                        (ticket.barberId == null ? 'Sin asignar' : '—'),
                  ),
                  _row(
                    'Artículos',
                    '${ticket.items.fold<int>(0, (a, i) => a + i.quantity)}',
                  ),
                ],
              ),
            ),
          ),
          const Gap(16),
          Text('Conceptos', style: Theme.of(context).textTheme.titleSmall),
          const Gap(8),
          if (ticket.items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Sin conceptos'),
              ),
            )
          else
            ...ticket.items.map(
              (item) => Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  title: Text(nameFor(item.itemType.wireName, item.itemId)),
                  subtitle: Text(
                    '${item.quantity} × ${_safeMoney(item.unitPrice)}',
                  ),
                  trailing: Text(
                    _safeMoney(item.subtotal),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          const Gap(16),
          Card(
            color: Colors.grey.shade100,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  Text(
                    _safeMoney(ticket.total),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Gap(20),
          FilledButton.icon(
            onPressed: _printing ? null : _reprint,
            icon: _printing
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.print),
            label: Text(_printing ? 'Imprimiendo…' : 'Reimprimir ticket'),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Text(
                label,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
      );
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
}

/// The backend gives IDs shorter than 8 chars in tests/synthetic data — the
/// old `substring(0, 8)` was crashing on those. Guard the call.
String _shortId(String id) =>
    id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();

/// Backend sends monetary amounts as decimal strings. If for any reason the
/// string can't be parsed (empty, "null", weird server payload), we render
/// the raw value instead of crashing the whole page.
String _safeMoney(String value) {
  try {
    return Formatters.money(value);
  } catch (_) {
    return value;
  }
}

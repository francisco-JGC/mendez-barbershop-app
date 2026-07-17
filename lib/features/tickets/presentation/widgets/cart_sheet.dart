import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/utils/formatters.dart';
import '../../../staff/application/barbers_provider.dart';
import '../../application/new_ticket_controller.dart';

/// Full-height bottom sheet with the current cart lines, barber picker, and
/// the "Cobrar" action. Rendered as a modal so the seller can focus on
/// confirming without the catalog underneath being distracting.
class CartSheet extends ConsumerWidget {
  const CartSheet({super.key, required this.onSubmit});

  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(newTicketControllerProvider);
    final controller = ref.read(newTicketControllerProvider.notifier);
    final barbersAsync = ref.watch(barbersProvider);

    final barbers = barbersAsync.asData?.value ?? const [];
    final barberMissing = state.requiresBarber && state.barberId == null;
    final canSubmit =
        !state.isEmpty && !state.isSubmitting && !barberMissing;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Column(
          children: [
            _handle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ticket',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${state.totalUnits} artículo(s)',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  _BarberSelector(
                    barbersAsync: barbersAsync,
                    selectedId: state.barberId,
                    required: state.requiresBarber,
                    onChanged: controller.setBarberId,
                  ),
                  const Gap(16),
                  ...state.lines.asMap().entries.map(
                        (entry) => _LineTile(
                          line: entry.value,
                          onIncrement: () => controller.updateQuantity(
                            entry.key,
                            entry.value.quantity + 1,
                          ),
                          onDecrement: () => controller.updateQuantity(
                            entry.key,
                            entry.value.quantity - 1,
                          ),
                          onRemove: () => controller.removeAt(entry.key),
                        ),
                      ),
                  if (barbers.isEmpty && barbersAsync.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child:
                          Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
            _Footer(
              total: state.total,
              canSubmit: canSubmit,
              isSubmitting: state.isSubmitting,
              barberMissing: barberMissing,
              onSubmit: onSubmit,
            ),
          ],
        );
      },
    );
  }

  Widget _handle() => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
}

class _BarberSelector extends StatelessWidget {
  const _BarberSelector({
    required this.barbersAsync,
    required this.selectedId,
    required this.required,
    required this.onChanged,
  });

  final AsyncValue barbersAsync;
  final String? selectedId;
  final bool required;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final barbers = barbersAsync.asData?.value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Barbero',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (required) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Requerido',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        const Gap(6),
        DropdownButtonFormField<String?>(
          initialValue: selectedId,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            hintText: barbers.isEmpty ? 'No hay barberos' : 'Selecciona un barbero',
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Sin barbero'),
            ),
            ...barbers.map(
              (b) => DropdownMenuItem<String?>(
                value: b.id,
                child: Text(b.displayName),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({
    required this.line,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final CartLine line;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${Formatters.money(line.unitPrice)} c/u',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: onDecrement,
                ),
                SizedBox(
                  width: 24,
                  child: Text(
                    '${line.quantity}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: onIncrement,
                ),
              ],
            ),
            SizedBox(
              width: 76,
              child: Text(
                Formatters.money(line.subtotal),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.total,
    required this.canSubmit,
    required this.isSubmitting,
    required this.barberMissing,
    required this.onSubmit,
  });

  final double total;
  final bool canSubmit;
  final bool isSubmitting;
  final bool barberMissing;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(
                    Formatters.money(total),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const Gap(8),
              if (barberMissing)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Este ticket incluye un servicio — selecciona un barbero para continuar.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              FilledButton.icon(
                onPressed: canSubmit ? onSubmit : null,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(isSubmitting ? 'Registrando…' : 'Cobrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../catalog/application/catalog_providers.dart';
import '../../../catalog/domain/entities/product.dart';
import '../../../catalog/domain/entities/service.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../printer_settings/application/printer_settings_controller.dart';
import '../../../printer_settings/domain/services/printer_service.dart';
import '../../../settings/application/settings_providers.dart';
import '../../../staff/application/barbers_provider.dart';
import '../../application/new_ticket_controller.dart';
import '../../domain/entities/ticket.dart';
import 'barcode_scanner_page.dart';
import '../widgets/cart_sheet.dart';
import '../widgets/catalog_card.dart';

class NewTicketPage extends ConsumerStatefulWidget {
  const NewTicketPage({super.key});

  @override
  ConsumerState<NewTicketPage> createState() => _NewTicketPageState();
}

class _NewTicketPageState extends ConsumerState<NewTicketPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  final _barcodeCtrl = TextEditingController();
  final _barcodeFocus = FocusNode();
  bool _lookingUpBarcode = false;

  @override
  void dispose() {
    _tab.dispose();
    _barcodeCtrl.dispose();
    _barcodeFocus.dispose();
    super.dispose();
  }

  // ─── Barcode handling ─────────────────────────────────────────────────

  Future<void> _processBarcode(String rawCode) async {
    final code = rawCode.trim();
    if (code.isEmpty || _lookingUpBarcode) return;
    setState(() => _lookingUpBarcode = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await sl<CatalogRepository>().productByBarcode(code);
      result.match(
        (failure) => messenger.showSnackBar(
          SnackBar(content: Text(_barcodeErrorMessage(failure))),
        ),
        (product) {
          if (product.isOutOfStock) {
            messenger.showSnackBar(
              SnackBar(content: Text('${product.name} está sin stock')),
            );
            return;
          }
          ref.read(newTicketControllerProvider.notifier).addProduct(product);
          messenger.showSnackBar(
            SnackBar(
              content: Text('${product.name} agregado'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
      );
    } finally {
      _barcodeCtrl.clear();
      if (mounted) {
        setState(() => _lookingUpBarcode = false);
        _barcodeFocus.requestFocus();
      }
    }
  }

  String _barcodeErrorMessage(Failure f) =>
      f is NotFoundFailure ? 'Código no encontrado' : f.message;

  Future<void> _openCameraScanner() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (code != null) await _processBarcode(code);
  }

  // ─── Cart submit ──────────────────────────────────────────────────────

  Future<void> _openCartSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CartSheet(
        onSubmit: () async {
          Navigator.of(context).pop();
          await _submit();
        },
      ),
    );
  }

  Future<void> _submit() async {
    final controller = ref.read(newTicketControllerProvider.notifier);
    final result = await controller.submit();
    if (!mounted) return;
    result.match(
      (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(f.message)),
      ),
      (ticket) => _onTicketCreated(ticket),
    );
  }

  Future<void> _onTicketCreated(Ticket ticket) async {
    final auto = ref.read(printerSettingsControllerProvider).autoPrint;
    if (auto) {
      await _print(ticket);
      ref.read(newTicketControllerProvider.notifier).reset();
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Venta registrada'),
        content: Text(
          'Total: ${Formatters.money(ticket.total)}\n'
          '${ticket.items.length} concepto(s)',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(newTicketControllerProvider.notifier).reset();
            },
            child: const Text('Cerrar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('Imprimir ticket'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _print(ticket);
              ref.read(newTicketControllerProvider.notifier).reset();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _print(Ticket ticket) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final settings = await ref.read(settingsProvider.future);
      final barbershop = await ref.read(barbershopInfoProvider.future);
      final services = await ref.read(servicesProvider.future);
      final products = await ref.read(productsProvider.future);
      final barbersAsync = ref.read(barbersProvider);
      final barbers = barbersAsync.asData?.value ?? const [];
      final barberName = ticket.barberId == null
          ? null
          : barbers
              .firstWhere(
                (b) => b.id == ticket.barberId,
                orElse: () => barbers.isEmpty
                    ? throw StateError('no barbers')
                    : barbers.first,
              )
              .displayName;
      final printer = sl<PrinterService>();
      final res = await printer.printTicket(PrintTicketArgs(
        ticket: ticket,
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
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(newTicketControllerProvider);
    final controller = ref.read(newTicketControllerProvider.notifier);
    final user = ref.watch(authControllerProvider).user;
    final services = ref.watch(servicesProvider);
    final products = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva venta'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Column(
            children: [
              _BarcodeInputRow(
                controller: _barcodeCtrl,
                focus: _barcodeFocus,
                isLoading: _lookingUpBarcode,
                onSubmit: _processBarcode,
                onCameraTap: _openCameraScanner,
              ),
              TabBar(
                controller: _tab,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: 'Servicios', icon: Icon(Icons.content_cut)),
                  Tab(text: 'Productos', icon: Icon(Icons.shopping_bag)),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Vendedor: ${user.name}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _ServicesTab(async: services, onTap: controller.addService),
                _ProductsTab(async: products, onTap: controller.addProduct),
              ],
            ),
          ),
          _CartBar(
            state: state,
            onOpenCart: _openCartSheet,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Widgets internos
// ──────────────────────────────────────────────────────────────────────────

class _BarcodeInputRow extends StatelessWidget {
  const _BarcodeInputRow({
    required this.controller,
    required this.focus,
    required this.isLoading,
    required this.onSubmit,
    required this.onCameraTap,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool isLoading;
  final Future<void> Function(String code) onSubmit;
  final VoidCallback onCameraTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              enabled: !isLoading,
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmit,
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Escanear código de barras...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.12),
                prefixIcon: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.qr_code_scanner, color: Colors.white),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          const Gap(8),
          IconButton.filledTonal(
            onPressed: isLoading ? null : onCameraTap,
            icon: const Icon(Icons.photo_camera),
            tooltip: 'Escanear con cámara',
          ),
        ],
      ),
    );
  }
}

class _ServicesTab extends StatelessWidget {
  const _ServicesTab({required this.async, required this.onTap});
  final AsyncValue<List<Service>> async;
  final void Function(Service) onTap;

  @override
  Widget build(BuildContext context) {
    return async.when(
      data: (services) => services.isEmpty
          ? const _EmptyCatalog(label: 'No hay servicios activos')
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.3,
              ),
              itemCount: services.length,
              itemBuilder: (_, i) => CatalogCard(
                title: services[i].name,
                priceLabel: Formatters.money(services[i].price),
                icon: Icons.content_cut,
                onTap: () => onTap(services[i]),
              ),
            ),
      error: (e, _) => _ErrorState(message: e.toString()),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ProductsTab extends StatelessWidget {
  const _ProductsTab({required this.async, required this.onTap});
  final AsyncValue<List<Product>> async;
  final void Function(Product) onTap;

  @override
  Widget build(BuildContext context) {
    return async.when(
      data: (products) => products.isEmpty
          ? const _EmptyCatalog(label: 'No hay productos activos')
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.15,
              ),
              itemCount: products.length,
              itemBuilder: (_, i) {
                final p = products[i];
                return CatalogCard(
                  title: p.name,
                  priceLabel: Formatters.money(p.price),
                  icon: Icons.shopping_bag,
                  onTap: p.isOutOfStock ? null : () => onTap(p),
                  badge: p.isOutOfStock
                      ? 'Sin stock'
                      : p.isLowStock
                          ? 'Stock: ${p.stock}'
                          : 'Stock: ${p.stock}',
                  badgeColor: p.isOutOfStock
                      ? Colors.red.shade100
                      : p.isLowStock
                          ? Colors.orange.shade100
                          : Colors.green.shade100,
                  badgeTextColor: p.isOutOfStock
                      ? Colors.red.shade900
                      : p.isLowStock
                          ? Colors.orange.shade900
                          : Colors.green.shade900,
                );
              },
            ),
      error: (e, _) => _ErrorState(message: e.toString()),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
}

class _CartBar extends StatelessWidget {
  const _CartBar({required this.state, required this.onOpenCart});

  final NewTicketState state;
  final VoidCallback onOpenCart;

  @override
  Widget build(BuildContext context) {
    final disabled = state.isEmpty;
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: disabled ? null : onOpenCart,
              style: FilledButton.styleFrom(
                backgroundColor: disabled ? Colors.grey.shade400 : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shopping_cart, color: Colors.white),
                      const Gap(8),
                      Text(
                        disabled
                            ? 'Ticket vacío'
                            : '${state.totalUnits} artículo(s)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    Formatters.money(state.total),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

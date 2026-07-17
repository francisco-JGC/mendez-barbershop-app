import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../../../catalog/domain/entities/product.dart';
import '../../../catalog/domain/entities/service.dart';
import '../../../settings/domain/entities/barbershop_info.dart';
import '../../../settings/domain/entities/barbershop_settings.dart';
import '../../../tickets/domain/entities/ticket.dart';
import '../entities/thermal_printer_device.dart';

/// Names the printer needs to render items — catalog IDs alone aren't enough
/// because the receipt shows `Nx <name>`.
class PrintableCatalog {
  const PrintableCatalog({
    required this.services,
    required this.products,
  });

  final List<Service> services;
  final List<Product> products;

  String nameFor(String itemType, String itemId) {
    if (itemType == 'service') {
      return services
          .firstWhere(
            (s) => s.id == itemId,
            orElse: () => const Service(
                id: '', name: 'Servicio', price: '0', isActive: true),
          )
          .name;
    }
    return products
        .firstWhere(
          (p) => p.id == itemId,
          orElse: () => const Product(
            id: '',
            name: 'Producto',
            price: '0',
            stock: 0,
            lowStockThreshold: 0,
            isActive: true,
          ),
        )
        .name;
  }
}

class PrintTicketArgs {
  const PrintTicketArgs({
    required this.ticket,
    required this.settings,
    required this.barbershop,
    required this.catalog,
    this.barberName,
    this.stationLabel,
    this.paperOverride,
  });

  final Ticket ticket;
  final BarbershopSettings settings;
  final BarbershopInfo barbershop;
  final PrintableCatalog catalog;
  final String? barberName;
  final String? stationLabel;

  /// If set, the printer service uses this paper width instead of the one
  /// stored in preferences. The UI passes what the user has selected in the
  /// settings toggle so there is no chance of a stale preference read.
  final PaperWidth? paperOverride;
}

abstract interface class PrinterService {
  Future<Either<Failure, List<ThermalPrinterDevice>>> listPairedDevices();
  Future<Either<Failure, Unit>> connect(ThermalPrinterDevice device);
  Future<Either<Failure, Unit>> disconnect();
  Future<Either<Failure, bool>> isConnected();

  Future<Either<Failure, Unit>> printTicket(PrintTicketArgs args);
  Future<Either<Failure, Unit>> printTest(
    BarbershopInfo barbershop, {
    PaperWidth? paperOverride,
  });

  /// Absolute-minimum print: ESC @ + 5 plain lines + line feeds + cut. No
  /// grid, no font selection, no bold — literally the smallest ESC/POS ticket
  /// possible. If this looks broken, the problem is hardware/pairing, not
  /// layout.
  Future<Either<Failure, Unit>> printMinimalTest();

  Future<Either<Failure, ThermalPrinterDevice?>> defaultDevice();
  Future<Either<Failure, Unit>> setDefaultDevice(ThermalPrinterDevice device);
  Future<Either<Failure, Unit>> clearDefaultDevice();

  Future<Either<Failure, PaperWidth>> paperWidth();
  Future<Either<Failure, Unit>> setPaperWidth(PaperWidth width);

  Future<Either<Failure, bool>> autoPrint();
  Future<Either<Failure, Unit>> setAutoPrint(bool enabled);
}

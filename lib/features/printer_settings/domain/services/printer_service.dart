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
  });

  final Ticket ticket;
  final BarbershopSettings settings;
  final BarbershopInfo barbershop;
  final PrintableCatalog catalog;
  final String? barberName;
  final String? stationLabel;
}

abstract interface class PrinterService {
  Future<Either<Failure, List<ThermalPrinterDevice>>> listPairedDevices();
  Future<Either<Failure, Unit>> connect(ThermalPrinterDevice device);
  Future<Either<Failure, Unit>> disconnect();
  Future<Either<Failure, bool>> isConnected();

  Future<Either<Failure, Unit>> printTicket(PrintTicketArgs args);
  Future<Either<Failure, Unit>> printTest(BarbershopInfo barbershop);

  Future<Either<Failure, ThermalPrinterDevice?>> defaultDevice();
  Future<Either<Failure, Unit>> setDefaultDevice(ThermalPrinterDevice device);
  Future<Either<Failure, Unit>> clearDefaultDevice();

  Future<Either<Failure, PaperWidth>> paperWidth();
  Future<Either<Failure, Unit>> setPaperWidth(PaperWidth width);

  Future<Either<Failure, bool>> autoPrint();
  Future<Either<Failure, Unit>> setAutoPrint(bool enabled);
}

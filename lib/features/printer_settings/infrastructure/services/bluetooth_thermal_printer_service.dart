import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/errors/failures.dart';
import '../../../printing/domain/receipt.dart';
import '../../../printing/infrastructure/image_dithering.dart';
import '../../domain/entities/thermal_printer_device.dart';
import '../../domain/services/printer_service.dart';

class BluetoothThermalPrinterService implements PrinterService {
  BluetoothThermalPrinterService(this._prefs, {ReceiptImageEncoder? encoder})
    : _encoder = encoder ?? const ReceiptImageEncoder();

  final SharedPreferences _prefs;
  // Preserved for future re-enablement of logo printing. See `printTicket`.
  // ignore: unused_field
  final ReceiptImageEncoder _encoder;

  static const _kMac = 'printer.default_mac';
  static const _kName = 'printer.default_name';
  static const _kPaper = 'printer.paper_width_mm';
  static const _kAutoPrint = 'printer.auto_print';

  @override
  Future<Either<Failure, List<ThermalPrinterDevice>>>
  listPairedDevices() async {
    try {
      final devices = await PrintBluetoothThermal.pairedBluetooths;
      return Right(
        devices
            .map(
              (d) => ThermalPrinterDevice(
                name: d.name.isEmpty ? d.macAdress : d.name,
                macAddress: d.macAdress,
              ),
            )
            .toList(growable: false),
      );
    } catch (e) {
      return Left(BluetoothFailure('No se pudieron listar dispositivos: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> connect(ThermalPrinterDevice device) async {
    try {
      final ok = await PrintBluetoothThermal.connect(
        macPrinterAddress: device.macAddress,
      );
      if (!ok) {
        return const Left(
          BluetoothFailure('No se pudo conectar a la impresora'),
        );
      }
      return const Right(unit);
    } catch (e) {
      return Left(BluetoothFailure('Error de conexión: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
      // The plugin keeps a "dead" socket handle for a few hundred ms after
      // disconnect. Without this pause the next `connect` returns true but
      // `writeBytes` fails silently — the classic "impresora rechazó los
      // datos" symptom on PT-210/GOOJPRT clones.
      await Future.delayed(_postDisconnectSettle);
      return const Right(unit);
    } catch (e) {
      return Left(BluetoothFailure('Error al desconectar: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> isConnected() async {
    try {
      return Right(await PrintBluetoothThermal.connectionStatus);
    } catch (e) {
      return Left(BluetoothFailure('Error al consultar estado: $e'));
    }
  }

  @override
  Future<Either<Failure, ThermalPrinterDevice?>> defaultDevice() async {
    final mac = _prefs.getString(_kMac);
    if (mac == null || mac.isEmpty) return const Right(null);
    final name = _prefs.getString(_kName) ?? mac;
    return Right(ThermalPrinterDevice(name: name, macAddress: mac));
  }

  @override
  Future<Either<Failure, Unit>> setDefaultDevice(
    ThermalPrinterDevice device,
  ) async {
    await _prefs.setString(_kMac, device.macAddress);
    await _prefs.setString(_kName, device.name);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> clearDefaultDevice() async {
    await _prefs.remove(_kMac);
    await _prefs.remove(_kName);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, PaperWidth>> paperWidth() async {
    final mm = _prefs.getInt(_kPaper) ?? PaperWidth.mm54.mm;
    return Right(
      PaperWidth.values.firstWhere(
        (w) => w.mm == mm,
        orElse: () => PaperWidth.mm54,
      ),
    );
  }

  @override
  Future<Either<Failure, Unit>> setPaperWidth(PaperWidth width) async {
    await _prefs.setInt(_kPaper, width.mm);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, bool>> autoPrint() async {
    return Right(_prefs.getBool(_kAutoPrint) ?? false);
  }

  @override
  Future<Either<Failure, Unit>> setAutoPrint(bool enabled) async {
    await _prefs.setBool(_kAutoPrint, enabled);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> printTicket(PrintTicketArgs args) {
    return _ensureConnectedAndSend(() async {
      // Prefer the explicit override from the UI so we never race the prefs
      // read against a just-changed toggle. Fall back to prefs only when the
      // caller can't tell us (e.g. auto-print from a background flow).
      final paper = await _resolvePaper(args.paperOverride);
      debugPrint('[printer] paper=${paper.mm}mm');
      // Logo rendering is intentionally disabled: even with 1-bit dithering
      // and atomic raster chunking, PT-210 clones don't render bitmaps
      // reliably. Re-enable by wiring `_encoder.encode(args.settings.logo,
      // maxWidthDots: paper.logoMaxDots)` back into `logo:` below.
      final input = ReceiptInput(
        charsPerLine: paper.charsPerLine,
        barbershopName: args.barbershop.name,
        ticketId: args.ticket.id,
        createdAt: args.ticket.createdAt.toIso8601String(),
        barberName: args.barberName,
        stationLabel: args.stationLabel,
        lines: args.ticket.items
            .map(
              (i) => ReceiptLineItem(
                name: args.catalog.nameFor(i.itemType.wireName, i.itemId),
                quantity: i.quantity,
                unitPrice: i.unitPrice,
              ),
            )
            .toList(growable: false),
        total: args.ticket.total,
        footer: args.settings.receiptFooter,
        logo: null,
        printBarbershopName: args.settings.printBarbershopName,
      );
      return buildReceipt(input);
    });
  }

  @override
  Future<Either<Failure, Unit>> printTest(
    barbershop, {
    PaperWidth? paperOverride,
  }) {
    return _ensureConnectedAndSend(() async {
      final paper = await _resolvePaper(paperOverride);
      debugPrint('[printer] test paper=${paper.mm}mm');
      return _buildTestTicket(paper, barbershopName: barbershop.name);
    });
  }

  @override
  Future<Either<Failure, Unit>> printMinimalTest() {
    return _ensureConnectedAndSend(() async {
      debugPrint('[printer] minimal test');
      // Only ESC @ (init) + plain ASCII lines + LFs + full cut. No fonts,
      // no alignment, no codepage. If this doesn't come out clean, no ESC/POS
      // library on earth will help — the socket is the problem.
      return <int>[
        0x1B, 0x40, // ESC @ — initialize
        ...'HOLA MUNDO\n'.codeUnits,
        ...'LINEA 2\n'.codeUnits,
        ...'LINEA 3\n'.codeUnits,
        ...'LINEA 4\n'.codeUnits,
        ...'LINEA 5\n'.codeUnits,
        0x0A, 0x0A, 0x0A, // 3 line feeds
        0x1D, 0x56, 0x00, // GS V 0 — full cut (ignored if no cutter)
      ];
    });
  }

  /// Small sample ticket — same layout the seller sees in real prints so
  /// they can validate alignment/columns before hitting a real sale.
  List<int> _buildTestTicket(
    PaperWidth paper, {
    required String barbershopName,
  }) {
    return buildReceipt(ReceiptInput(
      charsPerLine: paper.charsPerLine,
      barbershopName: barbershopName,
      ticketId: 'TEST0000',
      createdAt: DateTime.now().toIso8601String(),
      lines: const [
        ReceiptLineItem(name: 'Corte clasico', quantity: 1, unitPrice: '150.00'),
        ReceiptLineItem(name: 'Barba', quantity: 1, unitPrice: '80.00'),
        ReceiptLineItem(name: 'Cera para cabello', quantity: 2, unitPrice: '50.00'),
      ],
      total: '330.00',
      footer: 'Impresora configurada correctamente',
      printBarbershopName: true,
    ));
  }

  /// Central place to resolve which paper width to use for a print. Priority:
  /// explicit override from the UI → persisted preference → default 58mm.
  /// Written as a plain helper so the type is unambiguous — Dart's generic
  /// inference on `Either.match` kept typing the local as `PaperWidth?`.
  Future<PaperWidth> _resolvePaper(PaperWidth? override) async {
    if (override != null) return override;
    final res = await paperWidth();
    return res.getRight().toNullable() ?? PaperWidth.mm54;
  }

  // Cheap 58mm thermal printers (PT-210, GOOJPRT, and clones) have very small
  // BT SPP buffers — often 100-256 bytes. Web POS uses 100/20ms over BLE and
  // that works; on Classic SPP the printer needs more breathing room, so we
  // pair small chunks with a longer inter-chunk pause and a generous
  // post-connect settle window (the PT-210 drops the first bytes otherwise).
  // Some PT-210 firmwares have an effective SPP write MTU as small as 40-64
  // bytes: a 100-byte packet is silently rejected while a 40-byte one goes
  // through. We favor the conservative end here because slow prints are
  // acceptable while failed prints aren't. If you want to speed this up
  // later, try 80 and see if it still prints reliably.
  static const int _chunkBytes = 40;
  static const Duration _interChunkDelay = Duration(milliseconds: 80);
  static const Duration _postConnectSettle = Duration(milliseconds: 1000);
  static const Duration _postDisconnectSettle = Duration(milliseconds: 300);

  Future<Either<Failure, Unit>> _ensureConnectedAndSend(
    Future<List<int>> Function() build,
  ) async {
    final def = (await defaultDevice()).getRight().toNullable();
    if (def == null) {
      return const Left(
        BluetoothFailure('No hay impresora configurada. Configúrala primero.'),
      );
    }

    final bytes = await build();
    // First attempt: use the existing connection if any; otherwise open one.
    final firstAttempt = await _attemptSend(
      bytes,
      device: def,
      freshOpen: false,
    );
    if (firstAttempt.isRight()) return firstAttempt;

    // The `writeBytes` failure is almost always a zombie socket — the plugin
    // thinks it's connected but the printer isn't listening. Force a full
    // disconnect + settle + reconnect + retry. Second failure is real.
    return _attemptSend(bytes, device: def, freshOpen: true);
  }

  Future<Either<Failure, Unit>> _attemptSend(
    List<int> bytes, {
    required ThermalPrinterDevice device,
    required bool freshOpen,
  }) async {
    try {
      if (freshOpen) {
        // Best-effort: swallow errors — disconnect can throw if the socket
        // was already dead, which is exactly the case we're recovering from.
        try {
          await PrintBluetoothThermal.disconnect;
        } catch (_) {}
        await Future.delayed(_postDisconnectSettle);
      }

      final connected = await PrintBluetoothThermal.connectionStatus;
      debugPrint(
        '[printer] pre-connect status: $connected, freshOpen=$freshOpen, device=${device.name} (${device.macAddress})',
      );
      if (!connected || freshOpen) {
        final connectResult = await connect(device);
        final failure = connectResult.getLeft().toNullable();
        if (failure != null) {
          debugPrint('[printer] connect failed: ${failure.message}');
          return Left(failure);
        }
        // Some firmwares drop the first few bytes if we write immediately
        // after the socket is opened. A short settle window avoids that.
        await Future.delayed(_postConnectSettle);
      }

      // Definitive check right before writing. If this comes back false, the
      // socket was never real regardless of what `connect` said — no point
      // trying to write.
      final reallyConnected = await PrintBluetoothThermal.connectionStatus;
      debugPrint('[printer] post-settle status: $reallyConnected');
      if (!reallyConnected) {
        return Left(
          BluetoothFailure(
            'La conexión con "${device.name}" se cerró antes de imprimir. '
            'Puede ser que la impresora sea BLE (no Bluetooth clásico) o que '
            'necesites re-emparejarla desde ajustes de Android.',
          ),
        );
      }

      // Warmup: send just the ESC @ (initialize) command as a tiny 2-byte
      // packet. If this fails, the socket itself is dead — the ticket-sized
      // chunk was never the issue. Failing early gives a much better error
      // message than "chunk en 0, 0 bytes enviados de N".
      debugPrint('[printer] warmup: ESC @ (2 bytes)');
      final warmupOk = await PrintBluetoothThermal.writeBytes([0x1b, 0x40]);
      debugPrint('[printer] warmup result: $warmupOk');
      if (!warmupOk) {
        return Left(
          BluetoothFailure(
            'La impresora "${device.name}" no responde. Verifica que esté '
            'encendida, con papel y en rango. Si el problema sigue, apaga y '
            'enciende la impresora, o elimínala y vuelve a emparejarla.',
          ),
        );
      }
      await Future.delayed(_interChunkDelay);

      final chunks = _chunkOnLineBreaks(bytes, _chunkBytes);
      debugPrint(
        '[printer] sending ${bytes.length} bytes in ${chunks.length} line-aligned chunks',
      );
      var written = 0;
      for (var i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        // IMPORTANT: the plugin's Kotlin side expects `List<Int>` (which the
        // platform channel serializes as ArrayList<Integer>); passing a
        // Uint8List makes Flutter send `byte[]` instead and blows up with
        // `ClassCastException: byte[] cannot be cast to java.util.List`.
        // The helper already returns List<int>, but keep the copy to be safe.
        final ok = await PrintBluetoothThermal.writeBytes(chunk);
        if (!ok) {
          debugPrint(
            '[printer] REJECTED at chunk $i (size=${chunk.length}, written=$written)',
          );
          return Left(
            BluetoothFailure(
              'La impresora rechazó los datos '
              '(chunk $i, $written bytes enviados de ${bytes.length})',
            ),
          );
        }
        written += chunk.length;
        if (i < chunks.length - 1) {
          await Future.delayed(_interChunkDelay);
        }
      }
      debugPrint('[printer] print OK ($written bytes)');
      return const Right(unit);
    } catch (e) {
      return Left(BluetoothFailure('Error de impresión: $e'));
    }
  }

  /// Splits [bytes] into chunks whose length never exceeds [maxSize] except
  /// when a raster image is in flight — those must be sent as one atomic
  /// block or the printer misinterprets the pixel bytes as new commands.
  /// For text, cuts always land on a `\n` boundary so no printed line is
  /// split between two BT writes.
  static List<List<int>> _chunkOnLineBreaks(List<int> bytes, int maxSize) {
    final chunks = <List<int>>[];
    var start = 0;
    while (start < bytes.length) {
      // Raster image command: GS v 0 m xL xH yL yH d1..dk
      // Length of the payload is (xL|xH<<8) * (yL|yH<<8) bytes AFTER the
      // 8-byte header. We MUST emit the header + payload as a single write,
      // otherwise 0x0A bytes inside the bitmap look like line feeds to the
      // chunker and the image gets corrupted.
      if (start + 8 <= bytes.length &&
          bytes[start] == 0x1D &&
          bytes[start + 1] == 0x76 &&
          bytes[start + 2] == 0x30) {
        final widthBytes = bytes[start + 4] | (bytes[start + 5] << 8);
        final height = bytes[start + 6] | (bytes[start + 7] << 8);
        final rasterEnd = start + 8 + widthBytes * height;
        final clamped = rasterEnd > bytes.length ? bytes.length : rasterEnd;
        chunks.add(List<int>.from(bytes.sublist(start, clamped)));
        start = clamped;
        continue;
      }

      final hardEnd =
          (start + maxSize) > bytes.length ? bytes.length : start + maxSize;
      if (hardEnd == bytes.length) {
        chunks.add(List<int>.from(bytes.sublist(start, hardEnd)));
        start = hardEnd;
        continue;
      }
      // Find the last 0x0A within [start, hardEnd). If none, we have a line
      // longer than maxSize — send the whole slice as one big chunk.
      var lastLf = -1;
      for (var i = hardEnd - 1; i >= start; i--) {
        if (bytes[i] == 0x0A) {
          lastLf = i;
          break;
        }
      }
      final cutAt = lastLf >= 0 ? lastLf + 1 : hardEnd;
      chunks.add(List<int>.from(bytes.sublist(start, cutAt)));
      start = cutAt;
    }
    return chunks;
  }
}

extension _PaperMap on PaperWidth {
  // Empirical values based on printed samples from a real PT-210 clone (the
  // previous 22-char guess was too conservative — actual usable width was
  // ~30% wider once we fixed the mid-line chunk boundary bug):
  // - 54mm roll → 32 chars (Font A, ~48mm imprintable area)
  // - 58mm roll → 32 chars (same font, marginally more paper)
  // - 80mm roll → 48 chars (standard for 80mm ESC/POS)
  int get charsPerLine => switch (this) {
        PaperWidth.mm54 => 32,
        PaperWidth.mm58 => 32,
        PaperWidth.mm80 => 48,
      };

  // Preserved for future re-enablement of logo printing.
  // ignore: unused_element
  int get logoMaxDots => switch (this) {
        PaperWidth.mm54 => 320,
        PaperWidth.mm58 => 384,
        PaperWidth.mm80 => 576,
      };
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/di/injection.dart';
import '../../settings/application/settings_providers.dart';
import '../domain/entities/thermal_printer_device.dart';
import '../domain/services/printer_service.dart';
import 'printer_connection_keeper.dart';

class PrinterSettingsState {
  const PrinterSettingsState({
    this.devices = const [],
    this.selected,
    this.paperWidth = PaperWidth.mm54,
    this.autoPrint = false,
    this.isScanning = false,
    this.isConnecting = false,
    this.isTesting = false,
    this.isConnected = false,
    this.errorMessage,
    this.infoMessage,
  });

  final List<ThermalPrinterDevice> devices;
  final ThermalPrinterDevice? selected;
  final PaperWidth paperWidth;
  final bool autoPrint;
  final bool isScanning;
  final bool isConnecting;
  final bool isTesting;
  final bool isConnected;
  final String? errorMessage;
  final String? infoMessage;

  PrinterSettingsState copyWith({
    List<ThermalPrinterDevice>? devices,
    ThermalPrinterDevice? selected,
    PaperWidth? paperWidth,
    bool? autoPrint,
    bool? isScanning,
    bool? isConnecting,
    bool? isTesting,
    bool? isConnected,
    String? errorMessage,
    String? infoMessage,
    bool clearError = false,
    bool clearInfo = false,
    bool clearSelected = false,
  }) {
    return PrinterSettingsState(
      devices: devices ?? this.devices,
      selected: clearSelected ? null : (selected ?? this.selected),
      paperWidth: paperWidth ?? this.paperWidth,
      autoPrint: autoPrint ?? this.autoPrint,
      isScanning: isScanning ?? this.isScanning,
      isConnecting: isConnecting ?? this.isConnecting,
      isTesting: isTesting ?? this.isTesting,
      isConnected: isConnected ?? this.isConnected,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
    );
  }
}

class PrinterSettingsController extends Notifier<PrinterSettingsState> {
  late final PrinterService _service;
  late final PrinterConnectionKeeper _keeper;
  StreamSubscription<bool>? _sub;

  @override
  PrinterSettingsState build() {
    _service = sl<PrinterService>();
    _keeper = sl<PrinterConnectionKeeper>();
    _sub = _keeper.connectionStream.listen((connected) {
      state = state.copyWith(isConnected: connected);
    });
    ref.onDispose(() => _sub?.cancel());
    Future.microtask(_bootstrap);
    return PrinterSettingsState(isConnected: _keeper.isConnected);
  }

  Future<void> _bootstrap() async {
    final selectedRes = await _service.defaultDevice();
    final paperRes = await _service.paperWidth();
    final autoRes = await _service.autoPrint();
    final connectedRes = await _service.isConnected();
    state = state.copyWith(
      selected: selectedRes.getRight().toNullable(),
      paperWidth: paperRes.match((_) => PaperWidth.mm54, (v) => v),
      autoPrint: autoRes.match((_) => false, (v) => v),
      isConnected: connectedRes.match((_) => false, (v) => v),
    );
  }

  Future<void> scan() async {
    state = state.copyWith(isScanning: true, clearError: true, clearInfo: true);
    if (!await _ensurePermissions()) {
      state = state.copyWith(
        isScanning: false,
        errorMessage: 'Se requieren permisos de Bluetooth para escanear',
      );
      return;
    }
    final result = await _service.listPairedDevices();
    result.match(
      (f) =>
          state = state.copyWith(isScanning: false, errorMessage: f.message),
      (devices) => state = state.copyWith(
        isScanning: false,
        devices: devices,
        infoMessage: devices.isEmpty
            ? 'No hay dispositivos emparejados. Empareja la impresora primero.'
            : null,
      ),
    );
  }

  Future<void> selectDevice(ThermalPrinterDevice device) async {
    state = state.copyWith(
      isConnecting: true,
      clearError: true,
      clearInfo: true,
    );
    final result = await _service.connect(device);
    await result.match(
      (f) async =>
          state = state.copyWith(isConnecting: false, errorMessage: f.message),
      (_) async {
        await _service.setDefaultDevice(device);
        state = state.copyWith(
          isConnecting: false,
          selected: device,
          isConnected: true,
          infoMessage: 'Conectado a ${device.name}',
        );
        // Wake up the keeper so it takes over the reconnect loop for the new
        // device without waiting for the next tick.
        unawaited(_keeper.ping());
      },
    );
  }

  Future<void> changePaperWidth(PaperWidth width) async {
    await _service.setPaperWidth(width);
    state = state.copyWith(paperWidth: width);
  }

  Future<void> toggleAutoPrint(bool enabled) async {
    await _service.setAutoPrint(enabled);
    state = state.copyWith(autoPrint: enabled);
  }

  /// Manual disconnect. Pauses the keeper for 30 seconds so it doesn't
  /// immediately reconnect behind the seller's back — the default device is
  /// preserved so a later tap on "Conectar" (via selectDevice) or letting the
  /// pause elapse will reconnect to the same printer.
  Future<void> disconnect() async {
    _keeper.pauseFor(const Duration(seconds: 30));
    final result = await _service.disconnect();
    result.match(
      (f) => state = state.copyWith(errorMessage: f.message),
      (_) => state = state.copyWith(
        isConnected: false,
        infoMessage: 'Impresora desconectada',
      ),
    );
  }

  /// Disconnect + clear the persisted default device. Use when the seller
  /// wants to swap printers or stop the auto-reconnect loop entirely.
  Future<void> forgetPrinter() async {
    _keeper.pauseFor(const Duration(seconds: 60));
    await _service.disconnect();
    await _service.clearDefaultDevice();
    state = state.copyWith(
      isConnected: false,
      clearSelected: true,
      infoMessage: 'Impresora olvidada',
    );
  }

  Future<void> printMinimalTest() async {
    state = state.copyWith(isTesting: true, clearError: true, clearInfo: true);
    final result = await _service.printMinimalTest();
    result.match(
      (f) => state = state.copyWith(isTesting: false, errorMessage: f.message),
      (_) => state = state.copyWith(
        isTesting: false,
        infoMessage: 'Test mínimo enviado',
      ),
    );
  }

  Future<void> printTest(WidgetRef ref) async {
    state = state.copyWith(isTesting: true, clearError: true, clearInfo: true);
    final barbershop = await ref.read(barbershopInfoProvider.future);
    final result = await _service.printTest(
      barbershop,
      paperOverride: state.paperWidth,
    );
    result.match(
      (f) =>
          state = state.copyWith(isTesting: false, errorMessage: f.message),
      (_) => state = state.copyWith(
        isTesting: false,
        infoMessage: 'Ticket de prueba enviado',
      ),
    );
  }

  Future<bool> _ensurePermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    return statuses.values.any((s) => s.isGranted);
  }
}

final printerSettingsControllerProvider =
    NotifierProvider<PrinterSettingsController, PrinterSettingsState>(
        PrinterSettingsController.new);

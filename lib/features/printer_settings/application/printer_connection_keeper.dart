import 'dart:async';

import 'package:flutter/widgets.dart';

import '../domain/services/printer_service.dart';

/// Background watchdog that keeps the Bluetooth thermal printer connected.
///
/// The BT socket dies with the app process, and the printer can also go idle
/// (powered off, out of range). This service:
///
/// 1. Reads the persisted default printer at startup and connects to it.
/// 2. Polls the connection status on a timer and reconnects when it drops.
/// 3. Reconnects on `AppLifecycleState.resumed` so opening the app from
///    background is enough to have the printer ready.
///
/// Emits [connectionStream] events on every transition so the UI (settings
/// screen, print buttons) can reflect the state without polling itself.
class PrinterConnectionKeeper with WidgetsBindingObserver {
  PrinterConnectionKeeper(
    this._service, {
    this.pollInterval = const Duration(seconds: 8),
  });

  final PrinterService _service;
  final Duration pollInterval;

  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  Timer? _timer;
  bool _tickInFlight = false;
  bool _started = false;
  bool _lastKnownConnected = false;
  DateTime? _pausedUntil;
  bool get isConnected => _lastKnownConnected;

  /// Prevents the auto-reconnect loop from running for [duration]. Used when
  /// the seller explicitly disconnects — otherwise the very next tick would
  /// undo their action.
  void pauseFor(Duration duration) {
    _pausedUntil = DateTime.now().add(duration);
  }

  /// Cancel the pause and force an immediate reconnect attempt.
  void resume() {
    _pausedUntil = null;
    unawaited(_tick());
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(pollInterval, (_) => _tick());
    await _tick();
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
    await _connectionController.close();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // No await — lifecycle callbacks should return synchronously.
      unawaited(_tick());
    }
  }

  /// Force a check + reconnect attempt. Safe to call from UI (e.g. after the
  /// user picks a new default device from settings).
  Future<void> ping() => _tick();

  Future<void> _tick() async {
    if (_tickInFlight) return;
    if (_pausedUntil != null && DateTime.now().isBefore(_pausedUntil!)) return;
    _tickInFlight = true;
    try {
      final statusResult = await _service.isConnected();
      final connected = statusResult.match((_) => false, (v) => v);
      _emit(connected);
      if (connected) return;

      final deviceResult = await _service.defaultDevice();
      final device = deviceResult.getRight().toNullable();
      if (device == null) return; // Nothing to reconnect to.

      final connectResult = await _service.connect(device);
      _emit(connectResult.isRight());
    } catch (_) {
      _emit(false);
    } finally {
      _tickInFlight = false;
    }
  }

  void _emit(bool connected) {
    if (connected == _lastKnownConnected) return;
    _lastKnownConnected = connected;
    if (!_connectionController.isClosed) {
      _connectionController.add(connected);
    }
  }
}

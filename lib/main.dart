import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'features/printer_settings/application/printer_connection_keeper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env is bundled as an asset (see pubspec.yaml). --dart-define still wins
  // over .env when both are provided, so CI/release builds can override
  // without editing the file.
  await dotenv.load(fileName: '.env');
  await initializeDateFormatting('es_NI');

  final apiBaseUrl = _envVar('API_BASE_URL');
  if (apiBaseUrl.isEmpty) {
    throw StateError(
      'API_BASE_URL is not set. Copy .env.example to .env or pass '
      '--dart-define=API_BASE_URL=... to flutter run/build.',
    );
  }

  await configureDependencies(
    AppEnv(apiBaseUrl: _normalizeApiBaseUrl(apiBaseUrl)),
  );

  // Fire-and-forget: the keeper will retry silently in the background if the
  // printer is off/out of range. Awaiting would block splash on the BT stack.
  unawaited(sl<PrinterConnectionKeeper>().start());

  runApp(const ProviderScope(child: MendezPosApp()));
}

/// Read [key] from --dart-define first, falling back to .env.
String _envVar(String key) {
  final fromDefine = switch (key) {
    'API_BASE_URL' => const String.fromEnvironment('API_BASE_URL'),
    _ => '',
  };
  return fromDefine.isNotEmpty ? fromDefine : (dotenv.env[key] ?? '');
}

/// The backend is behind `app.setGlobalPrefix('api')`. The web dev server
/// adds this transparently via a Vite proxy, so the same base URL that works
/// on the web (without `/api`) would 404 here. Normalize both forms.
String _normalizeApiBaseUrl(String raw) {
  final trimmed = raw.replaceFirst(RegExp(r'/+$'), '');
  return trimmed.endsWith('/api') ? trimmed : '$trimmed/api';
}

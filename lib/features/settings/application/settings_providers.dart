import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/injection.dart';
import '../domain/entities/barbershop_info.dart';
import '../domain/entities/barbershop_settings.dart';
import '../domain/repositories/settings_repository.dart';

/// Kept as regular (non-autoDispose) providers so the printer can read the
/// cached values without triggering a network hit on every ticket.
final settingsProvider = FutureProvider<BarbershopSettings>((ref) async {
  final repo = sl<SettingsRepository>();
  final result = await repo.fetchSettings();
  return result.match((f) => throw f, (s) => s);
});

final barbershopInfoProvider = FutureProvider<BarbershopInfo>((ref) async {
  final repo = sl<SettingsRepository>();
  final result = await repo.fetchBarbershop();
  return result.match((f) => throw f, (b) => b);
});

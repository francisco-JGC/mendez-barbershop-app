import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/injection.dart';
import '../domain/entities/barber_dashboard_summary.dart';
import '../domain/entities/dashboard_period.dart';
import '../domain/repositories/dashboard_repository.dart';

/// Period the barber is currently looking at. Kept outside the data provider
/// so switching tabs doesn't rebuild the whole page.
final dashboardPeriodProvider = StateProvider.autoDispose<DashboardPeriod>(
  (ref) => DashboardPeriod.day,
);

/// Summary for one period. Auto-refreshes every 60s while the page is open —
/// same cadence as the web dashboard, so a barber who leaves the phone on the
/// counter still sees today's number grow as tickets are rung up.
final barberDashboardProvider = FutureProvider.autoDispose
    .family<BarberDashboardSummary, DashboardPeriod>((ref, period) async {
  final timer = Timer.periodic(
    const Duration(seconds: 60),
    (_) => ref.invalidateSelf(),
  );
  ref.onDispose(timer.cancel);

  final repo = sl<DashboardRepository>();
  final result = await repo.barberSummary(period);
  return result.match((f) => throw f, (summary) => summary);
});

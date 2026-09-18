/// How many times the barber performed one given service in the period.
class ServiceBreakdownEntry {
  const ServiceBreakdownEntry({
    required this.serviceId,
    required this.serviceName,
    required this.count,
  });

  final String serviceId;
  final String serviceName;
  final int count;
}

/// Personal summary for the signed-in barber. Only services they performed
/// count here — products rung up on their tickets belong to the shop, not to
/// them, so they never show up in these numbers.
class BarberDashboardSummary {
  const BarberDashboardSummary({
    required this.cutsCount,
    required this.totalRevenue,
    required this.commission,
    required this.serviceBreakdown,
    this.stationNumber,
  });

  final int cutsCount;

  /// Decimal strings, as the backend sends them — kept verbatim so no
  /// rounding creeps in between the API and what the barber reads.
  final String totalRevenue;
  final String commission;

  /// Chair the barber is assigned to right now, or null if unassigned.
  final int? stationNumber;
  final List<ServiceBreakdownEntry> serviceBreakdown;

  double get totalRevenueValue => double.tryParse(totalRevenue) ?? 0;
  double get commissionValue => double.tryParse(commission) ?? 0;

  double get averagePerCut =>
      cutsCount > 0 ? totalRevenueValue / cutsCount : 0;

  /// Commission rate implied by this period's numbers. The rate lives in shop
  /// settings, which barbers can't read (`GET /settings` is admin/seller
  /// only), so we derive it instead of hardcoding a percentage.
  double? get impliedCommissionRate =>
      totalRevenueValue > 0 ? commissionValue / totalRevenueValue : null;

  bool get isEmpty => cutsCount == 0;
}

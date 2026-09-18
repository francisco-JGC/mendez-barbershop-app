import '../../domain/entities/barber_dashboard_summary.dart';

class ServiceBreakdownEntryDto {
  const ServiceBreakdownEntryDto({
    required this.serviceId,
    required this.serviceName,
    required this.count,
  });

  final String serviceId;
  final String serviceName;
  final int count;

  factory ServiceBreakdownEntryDto.fromJson(Map<String, dynamic> json) =>
      ServiceBreakdownEntryDto(
        serviceId: json['serviceId'] as String,
        serviceName: json['serviceName'] as String? ?? '',
        // The API aggregates with SUM(quantity), which Postgres returns as a
        // string through the raw query builder.
        count: int.tryParse(json['count'].toString()) ?? 0,
      );

  ServiceBreakdownEntry toDomain() => ServiceBreakdownEntry(
        serviceId: serviceId,
        serviceName: serviceName,
        count: count,
      );
}

class BarberDashboardSummaryDto {
  const BarberDashboardSummaryDto({
    required this.cutsCount,
    required this.totalRevenue,
    required this.commission,
    required this.serviceBreakdown,
    this.stationNumber,
  });

  final int cutsCount;
  final String totalRevenue;
  final String commission;
  final int? stationNumber;
  final List<ServiceBreakdownEntryDto> serviceBreakdown;

  factory BarberDashboardSummaryDto.fromJson(Map<String, dynamic> json) =>
      BarberDashboardSummaryDto(
        cutsCount: int.tryParse(json['cutsCount'].toString()) ?? 0,
        totalRevenue: json['totalRevenue'].toString(),
        commission: json['commission'].toString(),
        stationNumber: (json['stationNumber'] as num?)?.toInt(),
        serviceBreakdown: (json['serviceBreakdown'] as List<dynamic>? ?? [])
            .map((e) =>
                ServiceBreakdownEntryDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  BarberDashboardSummary toDomain() => BarberDashboardSummary(
        cutsCount: cutsCount,
        totalRevenue: totalRevenue,
        commission: commission,
        stationNumber: stationNumber,
        serviceBreakdown:
            serviceBreakdown.map((e) => e.toDomain()).toList(growable: false),
      );
}

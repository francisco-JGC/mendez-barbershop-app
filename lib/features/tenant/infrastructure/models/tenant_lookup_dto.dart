import '../../domain/entities/tenant_lookup.dart';

class TenantLookupDto {
  const TenantLookupDto({
    required this.name,
    required this.isActive,
    this.logo,
  });

  final String name;
  final String? logo;
  final bool isActive;

  factory TenantLookupDto.fromJson(Map<String, dynamic> json) => TenantLookupDto(
        name: json['name'] as String,
        logo: json['logo'] as String?,
        isActive: json['isActive'] as bool? ?? true,
      );

  TenantLookup toDomain() =>
      TenantLookup(name: name, logo: logo, isActive: isActive);
}

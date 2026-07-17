import '../../domain/entities/barbershop_info.dart';
import '../../domain/entities/barbershop_settings.dart';

class BarbershopSettingsDto {
  const BarbershopSettingsDto({
    required this.barbershopId,
    required this.commissionRate,
    required this.receiptFooter,
    required this.printBarbershopName,
    this.logo,
  });

  final String barbershopId;
  final String commissionRate;
  final String receiptFooter;
  final bool printBarbershopName;
  final String? logo;

  factory BarbershopSettingsDto.fromJson(Map<String, dynamic> json) =>
      BarbershopSettingsDto(
        barbershopId: json['barbershopId'] as String,
        commissionRate: json['commissionRate'].toString(),
        receiptFooter: json['receiptFooter'] as String? ?? '',
        printBarbershopName: json['printBarbershopName'] as bool? ?? true,
        logo: json['logo'] as String?,
      );

  BarbershopSettings toDomain() => BarbershopSettings(
        barbershopId: barbershopId,
        commissionRate: commissionRate,
        receiptFooter: receiptFooter,
        printBarbershopName: printBarbershopName,
        logo: logo,
      );
}

class BarbershopInfoDto {
  const BarbershopInfoDto({
    required this.id,
    required this.name,
    required this.code,
  });

  final String id;
  final String name;
  final String code;

  factory BarbershopInfoDto.fromJson(Map<String, dynamic> json) =>
      BarbershopInfoDto(
        id: json['id'] as String,
        name: json['name'] as String,
        code: json['code'] as String? ?? '',
      );

  BarbershopInfo toDomain() =>
      BarbershopInfo(id: id, name: name, code: code);
}

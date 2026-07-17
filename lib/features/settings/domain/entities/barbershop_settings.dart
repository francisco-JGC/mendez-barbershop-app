/// Print/receipt settings persisted per barbershop. Matches the Web POS
/// exactly so tickets render the same on both terminals.
class BarbershopSettings {
  const BarbershopSettings({
    required this.barbershopId,
    required this.commissionRate,
    required this.receiptFooter,
    required this.printBarbershopName,
    this.logo,
  });

  final String barbershopId;
  final String commissionRate; // decimal string, e.g. "0.5000"
  final String receiptFooter;
  final bool printBarbershopName;
  final String? logo; // data URL

  BarbershopSettings copyWith({
    String? commissionRate,
    String? receiptFooter,
    bool? printBarbershopName,
    String? logo,
  }) {
    return BarbershopSettings(
      barbershopId: barbershopId,
      commissionRate: commissionRate ?? this.commissionRate,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      printBarbershopName: printBarbershopName ?? this.printBarbershopName,
      logo: logo ?? this.logo,
    );
  }
}

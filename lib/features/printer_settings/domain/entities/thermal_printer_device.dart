/// Represents a paired thermal printer discoverable via Bluetooth Classic.
class ThermalPrinterDevice {
  const ThermalPrinterDevice({required this.name, required this.macAddress});

  final String name;
  final String macAddress;

  @override
  bool operator ==(Object other) =>
      other is ThermalPrinterDevice && other.macAddress == macAddress;

  @override
  int get hashCode => macAddress.hashCode;
}

/// Paper widths supported by the ESC/POS driver used in this app.
enum PaperWidth {
  // Very small PT-210 clones — physical roll is 54mm, imprintable area
  // ~40mm. Default because it's what the Mendez shop uses in the field.
  mm54(54),
  mm58(58),
  mm80(80);

  const PaperWidth(this.mm);
  final int mm;
}

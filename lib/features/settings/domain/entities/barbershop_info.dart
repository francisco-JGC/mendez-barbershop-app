/// Non-sensitive info about the current tenant that the receipt header needs.
class BarbershopInfo {
  const BarbershopInfo({
    required this.id,
    required this.name,
    required this.code,
  });

  final String id;
  final String name;
  final String code;
}

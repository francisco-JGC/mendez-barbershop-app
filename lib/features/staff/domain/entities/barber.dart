/// Minimal staff-member view the POS needs — just enough to render the barber
/// selector and print their name on receipts.
class Barber {
  const Barber({
    required this.id,
    required this.name,
    required this.isActive,
    this.email,
    this.username,
  });

  final String id;
  final String name;
  final String? email;
  final String? username;
  final bool isActive;

  String get displayName => name.isNotEmpty ? name : (username ?? email ?? id);
}

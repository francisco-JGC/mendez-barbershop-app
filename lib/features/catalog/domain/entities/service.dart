/// Grooming service offered by the barbershop (haircut, beard, etc.).
class Service {
  const Service({
    required this.id,
    required this.name,
    required this.price,
    required this.isActive,
  });

  final String id;
  final String name;
  final String price;
  final bool isActive;
}

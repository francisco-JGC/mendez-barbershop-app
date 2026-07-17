/// Retail item sold by the barbershop (wax, shampoo, etc.).
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.lowStockThreshold,
    required this.isActive,
    this.barcode,
  });

  final String id;
  final String name;
  final String? barcode;
  final String price;
  final int stock;
  final int lowStockThreshold;
  final bool isActive;

  bool get isOutOfStock => stock <= 0;
  bool get isLowStock => stock > 0 && stock <= lowStockThreshold;
}

import '../../domain/entities/product.dart';
import '../../domain/entities/service.dart';

class ServiceDto {
  const ServiceDto({
    required this.id,
    required this.name,
    required this.price,
    required this.isActive,
  });

  final String id;
  final String name;
  final String price;
  final bool isActive;

  factory ServiceDto.fromJson(Map<String, dynamic> json) => ServiceDto(
        id: json['id'] as String,
        name: json['name'] as String,
        price: json['price'].toString(),
        isActive: json['isActive'] as bool? ?? true,
      );

  Service toDomain() =>
      Service(id: id, name: name, price: price, isActive: isActive);
}

class ProductDto {
  const ProductDto({
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

  factory ProductDto.fromJson(Map<String, dynamic> json) => ProductDto(
        id: json['id'] as String,
        name: json['name'] as String,
        barcode: json['barcode'] as String?,
        price: json['price'].toString(),
        stock: (json['stock'] as num?)?.toInt() ?? 0,
        lowStockThreshold: (json['lowStockThreshold'] as num?)?.toInt() ?? 3,
        isActive: json['isActive'] as bool? ?? true,
      );

  Product toDomain() => Product(
        id: id,
        name: name,
        barcode: barcode,
        price: price,
        stock: stock,
        lowStockThreshold: lowStockThreshold,
        isActive: isActive,
      );
}

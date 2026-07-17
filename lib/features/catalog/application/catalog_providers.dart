import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/injection.dart';
import '../domain/entities/product.dart';
import '../domain/entities/service.dart';
import '../domain/repositories/catalog_repository.dart';

final servicesProvider = FutureProvider.autoDispose<List<Service>>((ref) async {
  final repo = sl<CatalogRepository>();
  final result = await repo.listServices();
  return result.match((f) => throw f, (list) => list);
});

final productsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final repo = sl<CatalogRepository>();
  final result = await repo.listProducts();
  return result.match((f) => throw f, (list) => list);
});

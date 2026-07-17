import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/product.dart';
import '../entities/service.dart';

abstract interface class CatalogRepository {
  Future<Either<Failure, List<Service>>> listServices();
  Future<Either<Failure, List<Product>>> listProducts();
  Future<Either<Failure, Product>> productByBarcode(String barcode);
}

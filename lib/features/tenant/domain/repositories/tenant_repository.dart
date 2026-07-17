import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/tenant_lookup.dart';

abstract interface class TenantRepository {
  Future<Either<Failure, TenantLookup>> lookup(String code);
}

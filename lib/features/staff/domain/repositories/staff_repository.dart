import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/barber.dart';

abstract interface class StaffRepository {
  /// Returns only active barbers — sellers picking one for a service ticket
  /// should never see inactive staff.
  Future<Either<Failure, List<Barber>>> listBarbers();
}

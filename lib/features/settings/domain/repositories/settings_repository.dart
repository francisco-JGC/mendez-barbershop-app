import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/barbershop_info.dart';
import '../entities/barbershop_settings.dart';

abstract interface class SettingsRepository {
  Future<Either<Failure, BarbershopSettings>> fetchSettings();
  Future<Either<Failure, BarbershopInfo>> fetchBarbershop();
}

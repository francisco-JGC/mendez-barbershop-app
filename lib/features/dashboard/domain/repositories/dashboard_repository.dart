import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/barber_dashboard_summary.dart';
import '../entities/dashboard_period.dart';

abstract interface class DashboardRepository {
  Future<Either<Failure, BarberDashboardSummary>> barberSummary(
    DashboardPeriod period,
  );
}

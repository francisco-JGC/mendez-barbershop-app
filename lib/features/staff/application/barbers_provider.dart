import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/injection.dart';
import '../domain/entities/barber.dart';
import '../domain/repositories/staff_repository.dart';

final barbersProvider = FutureProvider<List<Barber>>((ref) async {
  final repo = sl<StaffRepository>();
  final result = await repo.listBarbers();
  return result.match((f) => throw f, (list) => list);
});

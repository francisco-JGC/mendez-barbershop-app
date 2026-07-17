import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/user.dart';

abstract interface class AuthRepository {
  /// [identifier] is username or email — the backend accepts either.
  Future<Either<Failure, User>> login({
    required String identifier,
    required String password,
  });

  /// Returns the user derived from the persisted access token, or null when
  /// there is no valid token stored.
  Future<Either<Failure, User?>> currentUser();

  Future<Either<Failure, Unit>> logout();
}

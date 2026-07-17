import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  const LoginUseCase(this._repo);
  final AuthRepository _repo;

  Future<Either<Failure, User>> call({
    required String identifier,
    required String password,
  }) {
    final trimmed = identifier.trim();
    if (trimmed.isEmpty || password.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Usuario y contraseña son obligatorios')),
      );
    }
    return _repo.login(identifier: trimmed, password: password);
  }
}

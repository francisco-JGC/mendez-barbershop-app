/// Domain-layer failures. Repositories return `Either<Failure, T>` so the
/// application layer can handle errors without try/catch.
sealed class Failure {
  const Failure(this.message);
  final String message;

  @override
  String toString() => '$runtimeType($message)';
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode});
  final int? statusCode;
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Sin conexión a internet']);
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Sesión expirada']);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Recurso no encontrado']);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {this.fieldErrors});
  final Map<String, List<String>>? fieldErrors;
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Error de almacenamiento local']);
}

class BluetoothFailure extends Failure {
  const BluetoothFailure(super.message);
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'Ocurrió un error inesperado']);
}

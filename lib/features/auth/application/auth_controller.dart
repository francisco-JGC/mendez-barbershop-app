import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/injection.dart';
import '../../../core/errors/failures.dart';
import '../domain/entities/user.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/usecases/login_usecase.dart';

/// Authentication state exposed to the router and UI.
class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
    this.isSubmitting = false,
  });

  final AuthStatus status;
  final User? user;
  final String? errorMessage;
  final bool isSubmitting;

  bool get isUnknown => status == AuthStatus.unknown;
  bool get isAuthenticated => status == AuthStatus.authenticated;

  const AuthState.unknown() : this(status: AuthStatus.unknown);
  const AuthState.unauthenticated({String? errorMessage})
      : this(status: AuthStatus.unauthenticated, errorMessage: errorMessage);
  const AuthState.authenticated(User user)
      : this(status: AuthStatus.authenticated, user: user);

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
    bool? isSubmitting,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthController extends Notifier<AuthState> {
  late final AuthRepository _repo;
  late final LoginUseCase _login;

  @override
  AuthState build() {
    _repo = sl<AuthRepository>();
    _login = sl<LoginUseCase>();
    Future.microtask(_bootstrap);
    return const AuthState.unknown();
  }

  Future<void> _bootstrap() async {
    final result = await _repo.currentUser();
    result.match(
      (_) => state = const AuthState.unauthenticated(),
      (user) => state = user == null || user.role != UserRole.seller
          ? const AuthState.unauthenticated()
          : AuthState.authenticated(user),
    );
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    final result = await _login(identifier: identifier, password: password);
    result.match(
      (failure) => state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: _messageFor(failure),
        isSubmitting: false,
      ),
      (user) => state = AuthState.authenticated(user),
    );
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState.unauthenticated();
  }

  String _messageFor(Failure f) => f.message;
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

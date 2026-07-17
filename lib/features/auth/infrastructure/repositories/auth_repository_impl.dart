import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this.remote,
    required this.storage,
  });

  final AuthRemoteDataSource remote;
  final SecureStorageService storage;

  @override
  Future<Either<Failure, User>> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final tokens = await remote.login(
        identifier: identifier,
        password: password,
      );
      final user = _userFromToken(tokens.accessToken);
      if (user == null) {
        return const Left(ServerFailure('Token inválido del servidor'));
      }
      if (user.role != UserRole.seller) {
        // Never persist a non-seller token in this app — otherwise the shell
        // would render POS screens for someone who can't use them.
        return const Left(
          UnauthorizedFailure(
            'Este usuario no tiene permisos para usar la app de ventas',
          ),
        );
      }
      await storage.writeTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      return Right(user);
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, User?>> currentUser() async {
    final token = await storage.readAccessToken();
    if (token == null || token.isEmpty) return const Right(null);

    var payload = JwtPayload.tryParse(token);
    if (payload == null) {
      await storage.clear();
      return const Right(null);
    }

    // Access expired but refresh probably still valid (backend defaults are
    // 15m / 7d). Try to swap for a fresh pair before dropping the session —
    // this is what keeps sellers logged in for the full week the shop is open.
    if (payload.isExpired) {
      final refreshToken = await storage.readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        await storage.clear();
        return const Right(null);
      }
      try {
        final tokens = await remote.refresh(refreshToken);
        await storage.writeTokens(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
        );
        payload = JwtPayload.tryParse(tokens.accessToken);
        if (payload == null) {
          await storage.clear();
          return const Right(null);
        }
      } catch (_) {
        // Refresh failed (expired refresh token, revoked session, network
        // error, etc.). Force re-login — safer than letting the seller
        // operate with stale credentials.
        await storage.clear();
        return const Right(null);
      }
    }

    final user = payload.toUser();
    if (user == null || user.role != UserRole.seller) {
      await storage.clear();
      return const Right(null);
    }
    return Right(user);
  }

  @override
  Future<Either<Failure, Unit>> logout() async {
    await storage.clear();
    return const Right(unit);
  }

  User? _userFromToken(String token) {
    final payload = JwtPayload.tryParse(token);
    return payload?.toUser();
  }
}

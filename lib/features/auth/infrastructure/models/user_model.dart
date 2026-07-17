import 'dart:convert';

import '../../domain/entities/user.dart';

/// Payload returned by `POST /auth/login` and `POST /auth/refresh`. The
/// backend does not return the user object — it only returns the tokens; the
/// user data is embedded in the JWT payload (`sub`, `name`, `email`,
/// `username`, `role`, `barbershopId`, `barbershopName`).
class AuthTokensDto {
  const AuthTokensDto({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;

  factory AuthTokensDto.fromJson(Map<String, dynamic> json) => AuthTokensDto(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
      );
}

/// Manual JWT decoder — no third-party dep, no signature validation (the
/// backend already did that when it issued the token, and we only read it
/// locally to know who the user is).
class JwtPayload {
  const JwtPayload(this.claims);
  final Map<String, dynamic> claims;

  static JwtPayload? tryParse(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      return JwtPayload(map);
    } catch (_) {
      return null;
    }
  }

  bool get isExpired {
    final exp = claims['exp'];
    if (exp is! num) return false; // If missing, assume valid — server decides.
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
    return DateTime.now().isAfter(expiresAt);
  }

  User? toUser() {
    final sub = claims['sub'];
    final name = claims['name'];
    final role = claims['role'];
    if (sub is! String || name is! String || role is! String) return null;
    return User(
      id: sub,
      name: name,
      email: claims['email'] as String?,
      username: claims['username'] as String?,
      role: UserRole.fromString(role),
      barbershopId: claims['barbershopId'] as String?,
    );
  }
}

/// Domain-layer roles the app cares about. Mirrors backend `Role` enum but
/// only lists what the mobile app understands; unknown values map to [unknown].
enum UserRole {
  seller,
  admin,
  superAdmin,
  barber,
  unknown;

  static UserRole fromString(String value) {
    switch (value) {
      case 'seller':
        return UserRole.seller;
      case 'admin':
        return UserRole.admin;
      case 'super_admin':
        return UserRole.superAdmin;
      case 'barber':
        return UserRole.barber;
      default:
        return UserRole.unknown;
    }
  }
}

class User {
  const User({
    required this.id,
    required this.name,
    required this.role,
    required this.barbershopId,
    this.email,
    this.username,
  });

  final String id;
  final String name;
  final String? email;
  final String? username;
  final UserRole role;
  final String? barbershopId;

  bool get isSeller => role == UserRole.seller;

  /// Whatever the user typed at login — for display in the app bar.
  String get displayIdentifier => username ?? email ?? '';
}

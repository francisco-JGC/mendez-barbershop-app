/// Domain-layer roles the app cares about. Mirrors backend `Role` enum but
/// only lists what the mobile app understands; unknown values map to [unknown].
enum UserRole {
  seller,
  admin,
  supervisor,
  barber,
  unknown;

  static UserRole fromString(String value) {
    switch (value) {
      case 'seller':
        return UserRole.seller;
      case 'admin':
        return UserRole.admin;
      case 'supervisor':
        return UserRole.supervisor;
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
  bool get isBarber => role == UserRole.barber;

  /// Roles that have a surface in this app. Sellers get the POS (ring up
  /// services and products); barbers get their own read-only summary. Admins
  /// and supervisors run the shop from the web client, not from here.
  bool get canUseApp => isSeller || isBarber;

  /// Whatever the user typed at login — for display in the app bar.
  String get displayIdentifier => username ?? email ?? '';
}

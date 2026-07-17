import '../../domain/entities/barber.dart';

/// Mirrors `UserResponseDto` from the backend — same fields the admin/staff
/// listing exposes.
class UserResponseDto {
  const UserResponseDto({
    required this.id,
    required this.name,
    required this.role,
    required this.isActive,
    this.email,
    this.username,
  });

  final String id;
  final String name;
  final String? email;
  final String? username;
  final String role;
  final bool isActive;

  factory UserResponseDto.fromJson(Map<String, dynamic> json) =>
      UserResponseDto(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String?,
        username: json['username'] as String?,
        role: json['role'] as String,
        isActive: json['isActive'] as bool? ?? true,
      );

  Barber toBarber() => Barber(
        id: id,
        name: name,
        email: email,
        username: username,
        isActive: isActive,
      );
}

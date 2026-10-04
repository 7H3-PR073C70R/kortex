import 'package:equatable/equatable.dart';

/// Core domain representation of an authenticated Kortex user.
class UserEntity extends Equatable {
  const UserEntity({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.academicInstitution,
    this.token,
    this.refreshToken,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? academicInstitution;
  final String? token;
  final String? refreshToken;

  @override
  List<Object?> get props => [
    id,
    email,
    displayName,
    photoUrl,
    academicInstitution,
    token,
    refreshToken,
  ];

  UserEntity copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    String? academicInstitution,
    String? token,
    String? refreshToken,
  }) {
    return UserEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      academicInstitution: academicInstitution ?? this.academicInstitution,
      token: token ?? this.token,
      refreshToken: refreshToken ?? this.refreshToken,
    );
  }
}

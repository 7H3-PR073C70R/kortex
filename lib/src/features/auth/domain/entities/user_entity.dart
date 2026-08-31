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
  });

  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? academicInstitution;
  final String? token;

  @override
  List<Object?> get props => [
        id,
        email,
        displayName,
        photoUrl,
        academicInstitution,
        token,
      ];
}

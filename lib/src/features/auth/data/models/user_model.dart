import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/auth/domain/entities/user_entity.dart';

class UserModel extends Equatable {
  const UserModel({
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

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final refreshToken = json['refresh_token'] as String?;
    if (json.containsKey('user') && json['user'] is Map<String, dynamic>) {
      final userObj = json['user'] as Map<String, dynamic>;
      final userMeta = userObj['user_metadata'] as Map<String, dynamic>?;
      return UserModel(
        id: userObj['id'] as String? ?? '',
        email: userObj['email'] as String? ?? '',
        displayName:
            userMeta?['display_name'] as String? ??
            userObj['display_name'] as String?,
        photoUrl:
            userMeta?['avatar_url'] as String? ??
            userObj['photo_url'] as String?,
        academicInstitution:
            userMeta?['academic_institution'] as String? ??
            userObj['academic_institution'] as String?,
        token: json['access_token'] as String? ?? json['token'] as String?,
        refreshToken: refreshToken,
      );
    }
    return UserModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName:
          json['displayName'] as String? ?? json['display_name'] as String?,
      photoUrl: json['photoUrl'] as String? ?? json['photo_url'] as String?,
      academicInstitution:
          json['academicInstitution'] as String? ??
          json['academic_institution'] as String?,
      token: json['token'] as String? ?? json['access_token'] as String?,
      refreshToken: refreshToken ?? json['refreshToken'] as String?,
    );
  }

  UserEntity toEntity() => UserEntity(
    id: id,
    email: email,
    displayName: displayName,
    photoUrl: photoUrl,
    academicInstitution: academicInstitution,
    token: token,
    refreshToken: refreshToken,
  );

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
}

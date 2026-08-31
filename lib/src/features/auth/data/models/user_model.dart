import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kortex/src/features/auth/domain/entities/user_entity.dart';

part 'user_model.freezed.dart';

@freezed
abstract class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    required String email,
    String? displayName,
    String? photoUrl,
    String? academicInstitution,
    String? token,
  }) = _UserModel;

  const UserModel._();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('user') && json['user'] is Map<String, dynamic>) {
      final userObj = json['user'] as Map<String, dynamic>;
      final userMeta = userObj['user_metadata'] as Map<String, dynamic>?;
      return UserModel(
        id: userObj['id'] as String? ?? '',
        email: userObj['email'] as String? ?? '',
        displayName: userMeta?['display_name'] as String? ??
            userObj['display_name'] as String?,
        photoUrl: userMeta?['avatar_url'] as String? ??
            userObj['photo_url'] as String?,
        academicInstitution: userMeta?['academic_institution'] as String? ??
            userObj['academic_institution'] as String?,
        token: json['access_token'] as String?,
      );
    }
    return UserModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ??
          json['display_name'] as String?,
      photoUrl: json['photoUrl'] as String? ?? json['photo_url'] as String?,
      academicInstitution: json['academicInstitution'] as String? ??
          json['academic_institution'] as String?,
      token: json['token'] as String? ?? json['access_token'] as String?,
    );
  }

  UserEntity toEntity() => UserEntity(
        id: id,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        academicInstitution: academicInstitution,
        token: token,
      );
}

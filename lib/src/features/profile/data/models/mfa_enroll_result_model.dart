import 'package:kortex/src/features/profile/domain/entities/mfa_enroll_result_entity.dart';

/// Data model for MFA enrollment response.
class MfaEnrollResultModel extends MfaEnrollResultEntity {
  const MfaEnrollResultModel({
    required super.factorId,
    required super.secret,
    super.uri,
  });

  factory MfaEnrollResultModel.fromJson(Map<String, dynamic> json) {
    return MfaEnrollResultModel(
      factorId: json['id'] as String? ?? json['factor_id'] as String? ?? '',
      secret: json['secret'] as String? ?? '',
      uri: json['uri'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'factor_id': factorId,
      'secret': secret,
      if (uri != null) 'uri': uri,
    };
  }
}

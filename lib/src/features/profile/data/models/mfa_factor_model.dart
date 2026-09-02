import 'package:kortex/src/features/profile/domain/entities/mfa_factor_entity.dart';

/// Data model for an enrolled MFA factor.
class MfaFactorModel extends MfaFactorEntity {
  const MfaFactorModel({
    required super.id,
    required super.factorType,
    required super.status,
  });

  factory MfaFactorModel.fromJson(Map<String, dynamic> json) {
    return MfaFactorModel(
      id: json['id'] as String? ?? '',
      factorType: json['factor_type'] as String? ?? json['type'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'factor_type': factorType,
      'status': status,
    };
  }
}

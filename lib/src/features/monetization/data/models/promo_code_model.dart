import 'package:equatable/equatable.dart';

/// Data model representing the result of a promo code redemption attempt.
class PromoRedemptionResultModel extends Equatable {
  const PromoRedemptionResultModel({
    required this.success,
    this.code,
    this.durationDays,
    this.proUntil,
    this.errorCode,
    this.message,
  });

  factory PromoRedemptionResultModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedProUntil;
    if (json['pro_until'] != null) {
      parsedProUntil = DateTime.tryParse(json['pro_until'].toString());
    }

    return PromoRedemptionResultModel(
      success: json['success'] as bool? ?? false,
      code: json['code'] as String?,
      durationDays: json['duration_days'] as int? ??
          (json['duration_days'] != null
              ? int.tryParse(json['duration_days'].toString())
              : null),
      proUntil: parsedProUntil,
      errorCode: json['error_code'] as String?,
      message: json['message'] as String?,
    );
  }

  final bool success;
  final String? code;
  final int? durationDays;
  final DateTime? proUntil;
  final String? errorCode;
  final String? message;

  Map<String, dynamic> toJson() => {
        'success': success,
        'code': code,
        'duration_days': durationDays,
        'pro_until': proUntil?.toIso8601String(),
        'error_code': errorCode,
        'message': message,
      };

  @override
  List<Object?> get props => [
        success,
        code,
        durationDays,
        proUntil,
        errorCode,
        message,
      ];
}

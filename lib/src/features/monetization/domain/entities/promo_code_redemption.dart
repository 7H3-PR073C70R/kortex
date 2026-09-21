import 'package:equatable/equatable.dart';

/// Domain entity representing the result of redeeming a promo code.
class PromoRedemptionResult extends Equatable {
  const PromoRedemptionResult({
    required this.success,
    this.code,
    this.durationDays,
    this.proUntil,
    this.errorCode,
    this.message,
  });

  final bool success;
  final String? code;
  final int? durationDays;
  final DateTime? proUntil;
  final String? errorCode;
  final String? message;

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

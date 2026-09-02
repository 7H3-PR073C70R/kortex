import 'package:equatable/equatable.dart';

/// Domain entity representing an enrolled MFA factor.
class MfaFactorEntity extends Equatable {
  const MfaFactorEntity({
    required this.id,
    required this.factorType,
    required this.status,
  });

  final String id;
  final String factorType;
  final String status;

  @override
  List<Object?> get props => [id, factorType, status];
}

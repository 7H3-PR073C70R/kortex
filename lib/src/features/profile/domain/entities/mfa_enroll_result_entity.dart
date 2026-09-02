import 'package:equatable/equatable.dart';

/// Domain entity representing the result of an MFA enrollment request.
class MfaEnrollResultEntity extends Equatable {
  const MfaEnrollResultEntity({
    required this.factorId,
    required this.secret,
    this.uri,
  });

  final String factorId;
  final String secret;
  final String? uri;

  @override
  List<Object?> get props => [factorId, secret, uri];
}

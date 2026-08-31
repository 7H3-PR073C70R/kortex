import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_request_model.freezed.dart';
part 'auth_request_model.g.dart';

@freezed
abstract class LoginRequestModel with _$LoginRequestModel {
  const factory LoginRequestModel({
    required String email,
    required String password,
  }) = _LoginRequestModel;

  factory LoginRequestModel.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestModelFromJson(json);
}

@freezed
abstract class RegisterRequestModel with _$RegisterRequestModel {
  const factory RegisterRequestModel({
    required String email,
    required String password,
    String? displayName,
  }) = _RegisterRequestModel;

  factory RegisterRequestModel.fromJson(Map<String, dynamic> json) =>
      _$RegisterRequestModelFromJson(json);
}

@freezed
abstract class SocialAuthRequestModel with _$SocialAuthRequestModel {
  const factory SocialAuthRequestModel({
    required String provider,
    required String idToken,
    String? rawNonce,
  }) = _SocialAuthRequestModel;

  factory SocialAuthRequestModel.fromJson(Map<String, dynamic> json) =>
      _$SocialAuthRequestModelFromJson(json);
}

@freezed
abstract class ResetPasswordRequestModel with _$ResetPasswordRequestModel {
  const factory ResetPasswordRequestModel({
    required String email,
  }) = _ResetPasswordRequestModel;

  factory ResetPasswordRequestModel.fromJson(Map<String, dynamic> json) =>
      _$ResetPasswordRequestModelFromJson(json);
}

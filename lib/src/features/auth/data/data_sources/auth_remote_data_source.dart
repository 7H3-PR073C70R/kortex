import 'package:kortex/src/features/auth/data/models/auth_request_model.dart';
import 'package:kortex/src/features/auth/data/models/user_model.dart';

/// Abstract remote data source contract for authentication endpoints.
abstract class AuthRemoteDataSource {
  Future<UserModel> login(LoginRequestModel request);
  Future<UserModel> register(RegisterRequestModel request);
  Future<UserModel> loginWithSocial(SocialAuthRequestModel request);
  Future<void> resetPassword(ResetPasswordRequestModel request);
}

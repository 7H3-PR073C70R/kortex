import 'package:kortex/src/features/auth/data/client/auth_api_client.dart';
import 'package:kortex/src/features/auth/data/data_sources/auth_remote_data_source.dart';
import 'package:kortex/src/features/auth/data/models/auth_request_model.dart';
import 'package:kortex/src/features/auth/data/models/user_model.dart';

/// Implementation of [AuthRemoteDataSource] relying on Retrofit
/// [AuthApiClient].
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl({
    required AuthApiClient apiClient,
  }) : _apiClient = apiClient;

  final AuthApiClient _apiClient;

  @override
  Future<UserModel> login(LoginRequestModel request) {
    return _apiClient.login(request);
  }

  @override
  Future<UserModel> register(RegisterRequestModel request) {
    return _apiClient.register(request);
  }

  @override
  Future<UserModel> loginWithSocial(SocialAuthRequestModel request) {
    return _apiClient.loginWithSocial(request);
  }

  @override
  Future<void> resetPassword(ResetPasswordRequestModel request) {
    return _apiClient.resetPassword(request);
  }
}

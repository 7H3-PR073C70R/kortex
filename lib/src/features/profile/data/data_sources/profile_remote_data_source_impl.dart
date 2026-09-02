import 'package:dio/dio.dart';
import 'package:kortex/src/core/error/exceptions.dart';
import 'package:kortex/src/features/profile/data/client/profile_api_client.dart';
import 'package:kortex/src/features/profile/data/data_sources/profile_remote_data_source.dart';
import 'package:kortex/src/features/profile/data/models/mfa_enroll_result_model.dart';
import 'package:kortex/src/features/profile/data/models/mfa_factor_model.dart';
import 'package:kortex/src/services/user_storage_service.dart';

/// Concrete implementation of [ProfileRemoteDataSource] using
/// pure REST API client.
class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  const ProfileRemoteDataSourceImpl({
    required ProfileApiClient profileApiClient,
    required UserStorageService userStorage,
  })  : _profileApiClient = profileApiClient,
        _userStorage = userStorage;

  final ProfileApiClient _profileApiClient;
  final UserStorageService _userStorage;

  String get _authToken => _userStorage.getToken() ?? '';
  String get _userId => _userStorage.getUserId() ?? '';

  @override
  Future<void> updateDisplayName(String displayName) async {
    try {
      await _profileApiClient.updateProfile(
        userId: _userId,
        authToken: _authToken,
        displayName: displayName,
      );
    } on DioException catch (e) {
      throw ServerException(message: e.message ?? 'Failed to update name');
    } on Object catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> updateAvatarUrl(String photoUrl) async {
    try {
      await _profileApiClient.updateProfile(
        userId: _userId,
        authToken: _authToken,
        photoUrl: photoUrl,
      );
    } on DioException catch (e) {
      throw ServerException(message: e.message ?? 'Failed to update avatar');
    } on Object catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      await _profileApiClient.updatePassword(
        newPassword: newPassword,
        authToken: _authToken,
      );
    } on DioException catch (e) {
      throw ServerException(message: e.message ?? 'Failed to update password');
    } on Object catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _profileApiClient.sendPasswordResetEmail(email);
    } on DioException catch (e) {
      throw ServerException(
        message: e.message ?? 'Failed to send reset email',
      );
    } on Object catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<MfaEnrollResultModel> enrollMfaTotp() async {
    try {
      return await _profileApiClient.enrollMfaTotp(authToken: _authToken);
    } on DioException catch (e) {
      throw ServerException(
        message: e.message ?? 'Failed to enroll MFA TOTP',
      );
    } on Object catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> verifyMfaTotp({
    required String factorId,
    required String code,
  }) async {
    try {
      await _profileApiClient.verifyMfaTotp(
        factorId: factorId,
        code: code,
        authToken: _authToken,
      );
    } on DioException catch (e) {
      throw ServerException(
        message: e.message ?? 'Failed to verify MFA TOTP',
      );
    } on Object catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> unenrollMfaTotp(String factorId) async {
    try {
      await _profileApiClient.unenrollMfaTotp(
        factorId: factorId,
        authToken: _authToken,
      );
    } on DioException catch (e) {
      throw ServerException(
        message: e.message ?? 'Failed to unenroll MFA factor',
      );
    } on Object catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<MfaFactorModel>> listMfaFactors() async {
    try {
      return await _profileApiClient.listMfaFactors(authToken: _authToken);
    } on DioException catch (e) {
      throw ServerException(
        message: e.message ?? 'Failed to list MFA factors',
      );
    } on Object {
      return const [];
    }
  }

  @override
  Future<void> signOutOtherSessions() async {
    try {
      await _profileApiClient.signOutOtherSessions(authToken: _authToken);
    } on DioException catch (e) {
      throw ServerException(
        message: e.message ?? 'Failed to sign out other sessions',
      );
    } on Object catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _profileApiClient.deleteAccount(
        userId: _userId,
        authToken: _authToken,
      );
    } on DioException catch (e) {
      throw ServerException(
        message: e.message ?? 'Failed to delete account',
      );
    } on Object catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}

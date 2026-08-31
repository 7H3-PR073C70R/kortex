import 'dart:async';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/repository_extension.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/auth/data/data_sources/auth_remote_data_source.dart';
import 'package:kortex/src/features/auth/data/models/auth_request_model.dart';
import 'package:kortex/src/features/auth/domain/entities/user_entity.dart';
import 'package:kortex/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:kortex/src/services/user_storage_service.dart';

/// Implementation of [AuthRepository] handling remote requests and storage.
class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required UserStorageService userStorageService,
  })  : _remoteDataSource = remoteDataSource,
        _userStorageService = userStorageService;

  final AuthRemoteDataSource _remoteDataSource;
  final UserStorageService _userStorageService;

  @override
  Future<Either<Failure, UserEntity>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _remoteDataSource
        .login(
          LoginRequestModel(email: email, password: password),
        )
        .makeRequest();

    return response.fold(
      Left.new,
      (userModel) {
        if (userModel.token != null) {
          unawaited(_userStorageService.saveToken(userModel.token!));
        }
        return Right(userModel.toEntity());
      },
    );
  }

  @override
  Future<Either<Failure, UserEntity>> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final response = await _remoteDataSource
        .register(
          RegisterRequestModel(
            email: email,
            password: password,
            displayName: displayName,
          ),
        )
        .makeRequest();

    return response.fold(
      Left.new,
      (userModel) {
        if (userModel.token != null) {
          unawaited(_userStorageService.saveToken(userModel.token!));
        }
        return Right(userModel.toEntity());
      },
    );
  }

  @override
  Future<Either<Failure, UserEntity>> loginWithSocial({
    required String provider,
    required String idToken,
    String? rawNonce,
  }) async {
    final response = await _remoteDataSource
        .loginWithSocial(
          SocialAuthRequestModel(
            provider: provider,
            idToken: idToken,
            rawNonce: rawNonce,
          ),
        )
        .makeRequest();

    return response.fold(
      Left.new,
      (userModel) {
        if (userModel.token != null) {
          unawaited(_userStorageService.saveToken(userModel.token!));
        }
        return Right(userModel.toEntity());
      },
    );
  }

  @override
  Future<Either<Failure, void>> resetPassword({
    required String email,
  }) {
    return _remoteDataSource
        .resetPassword(ResetPasswordRequestModel(email: email))
        .makeRequest();
  }
}

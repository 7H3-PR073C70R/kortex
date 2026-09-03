import 'dart:async';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/repository_extension.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/auth/data/data_sources/auth_remote_data_source.dart';
import 'package:kortex/src/features/auth/data/models/auth_request_model.dart';
import 'package:kortex/src/features/auth/domain/entities/auth_status.dart';
import 'package:kortex/src/features/auth/domain/entities/user_entity.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required UserStorageService userStorageService,
  }) : _remoteDataSource = remoteDataSource,
       _userStorageService = userStorageService;

  final AuthRemoteDataSource _remoteDataSource;
  final UserStorageService _userStorageService;

  final StreamController<AuthSessionStatus> _authStateController =
      StreamController<AuthSessionStatus>.broadcast();

  @override
  Stream<AuthSessionStatus> observeAuthState() => _authStateController.stream;

  @override
  Future<Either<Failure, UserProfileEntity>> getUserProfile() {
    return _remoteDataSource
        .fetchUserProfile()
        .then((model) => model.toEntity())
        .makeRequest();
  }

  @override
  Future<Either<Failure, UserProfileEntity>> completeOnboarding({
    required String track,
    required int dailyTarget,
    double retentionBenchmark = 0.85,
  }) {
    return _remoteDataSource
        .updateUserProfileTrackAndGoal(
          track: track,
          dailyTarget: dailyTarget,
          retentionBenchmark: retentionBenchmark,
        )
        .then((model) => model.toEntity())
        .makeRequest(
          onSuccess: (_) =>
              _authStateController.add(AuthSessionStatus.authenticatedComplete),
        );
  }

  @override
  Future<Either<Failure, UserProfileEntity>> updateCourseTrack({
    required String track,
    required int dailyTarget,
    double retentionBenchmark = 0.85,
  }) {
    return _remoteDataSource
        .updateUserProfileTrackAndGoal(
          track: track,
          dailyTarget: dailyTarget,
          retentionBenchmark: retentionBenchmark,
        )
        .then((model) => model.toEntity())
        .makeRequest();
  }

  @override
  Future<Either<Failure, UserEntity>> loginWithEmail({
    required String email,
    required String password,
  }) {
    return _remoteDataSource
        .login(LoginRequestModel(email: email, password: password))
        .then((model) async {
          final entity = model.toEntity();
          if (entity.token != null) {
            if (entity.refreshToken != null) {
              await _userStorageService.saveAuthTokens(
                accessToken: entity.token!,
                refreshToken: entity.refreshToken!,
              );
            } else {
              await _userStorageService.saveToken(entity.token!);
            }
          }
          _authStateController.add(AuthSessionStatus.authenticatedComplete);
          return entity;
        })
        .makeRequest();
  }

  @override
  Future<Either<Failure, UserEntity>> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) {
    return _remoteDataSource
        .register(
          RegisterRequestModel(
            email: email,
            password: password,
            displayName: displayName,
          ),
        )
        .then((model) async {
          final entity = model.toEntity();
          if (entity.token != null) {
            if (entity.refreshToken != null) {
              await _userStorageService.saveAuthTokens(
                accessToken: entity.token!,
                refreshToken: entity.refreshToken!,
              );
            } else {
              await _userStorageService.saveToken(entity.token!);
            }
          }
          _authStateController.add(
            AuthSessionStatus.authenticatedNeedsOnboarding,
          );
          return entity;
        })
        .makeRequest();
  }

  @override
  Future<Either<Failure, UserEntity>> loginWithSocial({
    required String provider,
    required String idToken,
    String? rawNonce,
  }) {
    return _remoteDataSource
        .loginWithSocial(
          SocialAuthRequestModel(
            provider: provider,
            idToken: idToken,
            rawNonce: rawNonce,
          ),
        )
        .then((model) async {
          final entity = model.toEntity();
          if (entity.token != null) {
            if (entity.refreshToken != null) {
              await _userStorageService.saveAuthTokens(
                accessToken: entity.token!,
                refreshToken: entity.refreshToken!,
              );
            } else {
              await _userStorageService.saveToken(entity.token!);
            }
          }
          _authStateController.add(AuthSessionStatus.authenticatedComplete);
          return entity;
        })
        .makeRequest();
  }

  @override
  Future<Either<Failure, void>> resetPassword({
    required String email,
  }) {
    return _remoteDataSource
        .resetPassword(ResetPasswordRequestModel(email: email))
        .makeRequest();
  }

  @override
  Future<Either<Failure, void>> sendMagicLink({
    required String email,
  }) {
    return _remoteDataSource.sendMagicLink(email).makeRequest();
  }

  @override
  Future<Either<Failure, UserEntity>> verifyOtp({
    required String email,
    required String token,
    String type = 'signup',
  }) {
    return _remoteDataSource
        .verifyOtp(email: email, token: token, type: type)
        .then((model) async {
          final entity = model.toEntity();
          if (entity.token != null) {
            if (entity.refreshToken != null) {
              await _userStorageService.saveAuthTokens(
                accessToken: entity.token!,
                refreshToken: entity.refreshToken!,
              );
            } else {
              await _userStorageService.saveToken(entity.token!);
            }
          }
          _authStateController.add(AuthSessionStatus.authenticatedComplete);
          return entity;
        })
        .makeRequest();
  }

  @override
  Future<Either<Failure, void>> signOut() {
    return Future<void>.sync(() {
      _userStorageService.clearStorage();
      _authStateController.add(AuthSessionStatus.unauthenticated);
    }).makeRequest();
  }
}

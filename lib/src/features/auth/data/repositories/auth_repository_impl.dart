import 'dart:async';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/auth/data/data_sources/auth_remote_data_source.dart';
import 'package:kortex/src/features/auth/data/models/auth_request_model.dart';
import 'package:kortex/src/features/auth/domain/entities/auth_status.dart';
import 'package:kortex/src/features/auth/domain/entities/user_entity.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required UserStorageService userStorageService,
  })  : _remoteDataSource = remoteDataSource,
        _userStorageService = userStorageService;

  final AuthRemoteDataSource _remoteDataSource;
  final UserStorageService _userStorageService;

  final StreamController<AuthSessionStatus> _authStateController =
      StreamController<AuthSessionStatus>.broadcast();

  @override
  Stream<AuthSessionStatus> observeAuthState() => _authStateController.stream;

  @override
  Future<Either<Failure, UserProfileEntity>> getUserProfile() async {
    try {
      final model = await _remoteDataSource.fetchUserProfile();
      return Right(model.toEntity());
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserProfileEntity>> completeOnboarding({
    required String track,
    required int dailyTarget,
    double retentionBenchmark = 0.85,
  }) async {
    try {
      final model =
          await _remoteDataSource.updateUserProfileTrackAndGoal(
        track: track,
        dailyTarget: dailyTarget,
        retentionBenchmark: retentionBenchmark,
      );
      _authStateController.add(AuthSessionStatus.authenticatedComplete);
      return Right(model.toEntity());
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserProfileEntity>> updateCourseTrack({
    required String track,
    required int dailyTarget,
    double retentionBenchmark = 0.85,
  }) async {
    try {
      final model =
          await _remoteDataSource.updateUserProfileTrackAndGoal(
        track: track,
        dailyTarget: dailyTarget,
        retentionBenchmark: retentionBenchmark,
      );
      return Right(model.toEntity());
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final model = await _remoteDataSource.login(
        LoginRequestModel(email: email, password: password),
      );
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
      return Right(entity);
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final model = await _remoteDataSource.register(
        RegisterRequestModel(
          email: email,
          password: password,
          displayName: displayName,
        ),
      );
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
      _authStateController
          .add(AuthSessionStatus.authenticatedNeedsOnboarding);
      return Right(entity);
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> loginWithSocial({
    required String provider,
    required String idToken,
    String? rawNonce,
  }) async {
    try {
      final model = await _remoteDataSource.loginWithSocial(
        SocialAuthRequestModel(
          provider: provider,
          idToken: idToken,
          rawNonce: rawNonce,
        ),
      );
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
      return Right(entity);
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> resetPassword({
    required String email,
  }) async {
    try {
      await _remoteDataSource.resetPassword(
        ResetPasswordRequestModel(email: email),
      );
      return const Right(null);
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> sendMagicLink({
    required String email,
  }) async {
    try {
      await _remoteDataSource.sendMagicLink(email);
      return const Right(null);
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> verifyOtp({
    required String email,
    required String token,
    String type = 'signup',
  }) async {
    try {
      final model = await _remoteDataSource.verifyOtp(
        email: email,
        token: token,
        type: type,
      );
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
      return Right(entity);
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      _userStorageService.clearStorage();
      _authStateController.add(AuthSessionStatus.unauthenticated);
      return const Right(null);
    } on Object {
      _userStorageService.clearStorage();
      _authStateController.add(AuthSessionStatus.unauthenticated);
      return const Right(null);
    }
  }
}

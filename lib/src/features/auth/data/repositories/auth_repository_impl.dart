import 'dart:async';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/repository_extension.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/auth/data/data_sources/auth_remote_data_source.dart';
import 'package:kortex/src/features/auth/data/models/auth_request_model.dart';
import 'package:kortex/src/features/auth/domain/entities/auth_status.dart';
import 'package:kortex/src/features/auth/domain/entities/user_entity.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:kortex/src/services/user_storage_service.dart';

/// Implementation of [AuthRepository] handling remote requests and storage.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required UserStorageService userStorageService,
  })  : _remoteDataSource = remoteDataSource,
        _userStorageService = userStorageService {
    _initAuthState();
  }

  final AuthRemoteDataSource _remoteDataSource;
  final UserStorageService _userStorageService;
  final StreamController<AuthSessionStatus> _authStateController =
      StreamController<AuthSessionStatus>.broadcast();

  void _initAuthState() {
    final token = _userStorageService.getToken();
    if (token == null || token.isEmpty) {
      _authStateController.add(AuthSessionStatus.unauthenticated);
    } else {
      _authStateController.add(AuthSessionStatus.authenticatedComplete);
    }
  }

  @override
  Stream<AuthSessionStatus> observeAuthState() => _authStateController.stream;

  @override
  Future<Either<Failure, UserProfileEntity>> getUserProfile() async {
    final response =
        await _remoteDataSource.fetchUserProfile().makeRequest();

    return response.fold(
      Left.new,
      (model) => Right(model.toEntity()),
    );
  }

  @override
  Future<Either<Failure, UserProfileEntity>> completeOnboarding({
    required String track,
    required int dailyTarget,
    double retentionBenchmark = 0.85,
  }) async {
    final response = await _remoteDataSource
        .updateUserProfileTrackAndGoal(
          track: track,
          dailyTarget: dailyTarget,
          retentionBenchmark: retentionBenchmark,
        )
        .makeRequest();

    return response.fold(
      Left.new,
      (model) {
        _authStateController.add(AuthSessionStatus.authenticatedComplete);
        return Right(model.toEntity());
      },
    );
  }

  @override
  Future<Either<Failure, UserProfileEntity>> updateCourseTrack({
    required String track,
    required int dailyTarget,
    double retentionBenchmark = 0.85,
  }) async {
    final response = await _remoteDataSource
        .updateUserProfileTrackAndGoal(
          track: track,
          dailyTarget: dailyTarget,
          retentionBenchmark: retentionBenchmark,
        )
        .makeRequest();

    return response.fold(
      Left.new,
      (model) => Right(model.toEntity()),
    );
  }

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
        _authStateController.add(AuthSessionStatus.authenticatedComplete);
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
        _authStateController
            .add(AuthSessionStatus.authenticatedNeedsOnboarding);
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
        _authStateController.add(AuthSessionStatus.authenticatedComplete);
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
  }) async {
    final response = await _remoteDataSource
        .verifyOtp(
          email: email,
          token: token,
          type: type,
        )
        .makeRequest();

    return response.fold(
      Left.new,
      (userModel) {
        if (userModel.token != null) {
          unawaited(_userStorageService.saveToken(userModel.token!));
        }
        _authStateController
            .add(AuthSessionStatus.authenticatedNeedsOnboarding);
        return Right(userModel.toEntity());
      },
    );
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    _userStorageService.clearStorage();
    _authStateController.add(AuthSessionStatus.unauthenticated);
    return const Right(null);
  }
}

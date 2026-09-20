import 'package:kortex/src/core/error/exceptions.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/monetization/data/datasources/promo_code_remote_data_source.dart';
import 'package:kortex/src/features/monetization/domain/entities/promo_code_redemption.dart';
import 'package:kortex/src/features/monetization/domain/repositories/promo_code_repository.dart';

class PromoCodeRepositoryImpl implements PromoCodeRepository {
  const PromoCodeRepositoryImpl({
    required PromoCodeRemoteDataSource remoteDataSource,
    required UserStorageService userStorageService,
  })  : _remoteDataSource = remoteDataSource,
        _userStorageService = userStorageService;

  final PromoCodeRemoteDataSource _remoteDataSource;
  final UserStorageService _userStorageService;

  @override
  Future<Either<Failure, PromoRedemptionResult>> redeemPromoCode({
    required String code,
  }) async {
    try {
      final model = await _remoteDataSource.redeemPromoCode(code: code);

      final result = PromoRedemptionResult(
        success: model.success,
        code: model.code,
        durationDays: model.durationDays,
        proUntil: model.proUntil,
        errorCode: model.errorCode,
        message: model.message,
      );

      if (model.success || model.errorCode == 'ALREADY_REDEEMED') {
        // Save Pro status to local storage so SubscriptionGuard.isPro is immediately true
        await _userStorageService.saveProStatus(isPro: true);

        // Notify AuthBloc if registered
        try {
          if (locator.isRegistered<AuthBloc>()) {
            locator<AuthBloc>().add(const AuthSubscriptionUpdated(isPro: true));
            locator<AuthBloc>().add(const AuthProfileFetchRequested());
          }
        } on Object catch (_) {}
      }

      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}

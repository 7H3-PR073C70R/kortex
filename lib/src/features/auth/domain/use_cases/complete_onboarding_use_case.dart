import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/features/auth/domain/repositories/auth_repository.dart';

class CompleteOnboardingUseCase {
  const CompleteOnboardingUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, UserProfileEntity>> call({
    required String track,
    required int dailyTarget,
    double retentionBenchmark = 0.85,
  }) {
    return _repository.completeOnboarding(
      track: track,
      dailyTarget: dailyTarget,
      retentionBenchmark: retentionBenchmark,
    );
  }
}

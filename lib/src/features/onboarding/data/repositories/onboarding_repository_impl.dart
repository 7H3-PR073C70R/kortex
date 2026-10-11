import 'package:kortex/src/features/onboarding/data/datasources/onboarding_local_data_source.dart';
import 'package:kortex/src/features/onboarding/domain/repositories/onboarding_repository.dart';

class OnboardingRepositoryImpl implements OnboardingRepository {
  const OnboardingRepositoryImpl({
    required OnboardingLocalDataSource localDataSource,
  }) : _localDataSource = localDataSource;

  final OnboardingLocalDataSource _localDataSource;

  @override
  bool hasCompletedOnboarding() => _localDataSource.hasCompletedOnboarding();

  @override
  Future<void> markOnboardingCompleted() =>
      _localDataSource.markOnboardingCompleted();
}

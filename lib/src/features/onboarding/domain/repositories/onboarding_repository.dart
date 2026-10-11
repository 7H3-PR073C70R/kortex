/// Domain contract for managing user onboarding state and persistence.
abstract class OnboardingRepository {
  const OnboardingRepository();

  /// Checks whether user has already completed the intro onboarding flow.
  bool hasCompletedOnboarding();

  /// Marks the intro onboarding flow as completed in persistent local storage.
  Future<void> markOnboardingCompleted();
}

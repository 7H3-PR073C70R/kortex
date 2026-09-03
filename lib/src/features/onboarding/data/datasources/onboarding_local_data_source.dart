import 'package:flutter/widgets.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/onboarding_illustrations.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/onboarding_page_view.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_badge.dart';

/// Data source interface for managing localized onboarding slide data
/// and local onboarding completion persistence.
abstract class OnboardingLocalDataSource {
  const OnboardingLocalDataSource();

  /// Resolves the 4 localized onboarding slides using [BuildContext].
  List<OnboardingSlideData> getOnboardingSlides(BuildContext context);

  /// Persists onboarding completion flag to local storage.
  Future<void> markOnboardingCompleted();

  /// Checks whether user has already completed the onboarding flow.
  bool hasCompletedOnboarding();
}

/// Implementation of [OnboardingLocalDataSource] backed by LocalStorageService.
class OnboardingLocalDataSourceImpl implements OnboardingLocalDataSource {
  const OnboardingLocalDataSourceImpl({
    required LocalStorageService storageService,
  }) : _storageService = storageService;

  final LocalStorageService _storageService;

  @override
  List<OnboardingSlideData> getOnboardingSlides(BuildContext context) {
    final l10n = context.l10n;

    return [
      OnboardingSlideData(
        badge: l10n.onboardingSlide1Badge,
        badgeVariant: AppBadgeVariant.primary,
        tagline: l10n.onboardingSlide1Title,
        description: l10n.onboardingSlide1Desc,
        illustrationBuilder: (context) =>
            OnboardingIllustrations.documentIngestion(context: context),
      ),
      OnboardingSlideData(
        badge: l10n.onboardingSlide2Badge,
        badgeVariant: AppBadgeVariant.syllabot,
        tagline: l10n.onboardingSlide2Title,
        description: l10n.onboardingSlide2Desc,
        illustrationBuilder: (context) =>
            OnboardingIllustrations.stemOcr(context: context),
      ),
      OnboardingSlideData(
        badge: l10n.onboardingSlide3Badge,
        badgeVariant: AppBadgeVariant.success,
        tagline: l10n.onboardingSlide3Title,
        description: l10n.onboardingSlide3Desc,
        illustrationBuilder: (context) =>
            OnboardingIllustrations.spacedRepetition(context: context),
      ),
      OnboardingSlideData(
        badge: l10n.onboardingSlide4Badge,
        badgeVariant: AppBadgeVariant.syllabot,
        tagline: l10n.onboardingSlide4Title,
        description: l10n.onboardingSlide4Desc,
        illustrationBuilder: (context) =>
            OnboardingIllustrations.socraticAi(context: context),
      ),
    ];
  }

  @override
  Future<void> markOnboardingCompleted() async {
    await _storageService.savePreference(
      key: PrefKeys.hasCompletedOnboarding,
      data: 'true',
    );
  }

  @override
  bool hasCompletedOnboarding() {
    return _storageService.getPreference(
          key: PrefKeys.hasCompletedOnboarding,
        ) ==
        'true';
  }
}

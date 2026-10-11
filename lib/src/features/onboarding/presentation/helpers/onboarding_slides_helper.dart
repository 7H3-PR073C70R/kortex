import 'package:flutter/widgets.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/onboarding_illustrations.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/onboarding_page_view.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_badge.dart';

/// Presentation helper for building localized onboarding slide definitions.
class OnboardingSlidesHelper {
  const OnboardingSlidesHelper._();

  /// Resolves the 4 localized onboarding slides using [BuildContext].
  static List<OnboardingSlideData> getSlides(BuildContext context) {
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
}

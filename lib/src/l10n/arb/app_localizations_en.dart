// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get sample => 'sample';

  @override
  String get appName => 'KORTEX';

  @override
  String get engineSubtitle => 'ENGINE: SYLLABOT AI';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Continue';

  @override
  String get onboardingGetStarted => 'Get Started with Kortex';

  @override
  String get onboardingCarouselSemantics => 'Kortex Onboarding Carousel';

  @override
  String get onboardingSkipSemantics => 'Skip onboarding and enter app';

  @override
  String get onboardingNextSemantics => 'Continue to next onboarding slide';

  @override
  String get onboardingGetStartedSemantics =>
      'Get Started with Kortex and finish onboarding';

  @override
  String get onboardingSlide1Badge => 'ZERO-LATENCY INGESTION';

  @override
  String get onboardingSlide1Title => 'Drop. Parse. Master.';

  @override
  String get onboardingSlide1Desc =>
      'Transform dense syllabi, past papers, and STEM lecture slides into structured active-recall systems instantly.';

  @override
  String get onboardingSlide2Badge => 'PRECISION STEM OCR';

  @override
  String get onboardingSlide2Title => 'Flawless Math & Science OCR';

  @override
  String get onboardingSlide2Desc =>
      'Extract complex equations, integral bounds, and chemical formulas with exact LaTeX precision—no broken characters.';

  @override
  String get onboardingSlide3Badge => 'EBBINGHAUS SM-2';

  @override
  String get onboardingSlide3Title => 'Forget About Forgetting';

  @override
  String get onboardingSlide3Desc =>
      'Adaptive forgetting curves schedule your reviews at the exact moment memories fade. Say goodbye to the cramming illusion.';

  @override
  String get onboardingSlide4Badge => 'SOCRATIC TUTORING';

  @override
  String get onboardingSlide4Title => 'Calibrate Your Confidence';

  @override
  String get onboardingSlide4Desc =>
      'Test your true readiness with timed mock exams and guided Socratic tutoring that leads you to the answer without spoiling it.';

  @override
  String onboardingPageIndicatorSemantics(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String onboardingPageAnnouncement(int current, int total, String title) {
    return 'Page $current of $total: $title';
  }

  @override
  String get loadingAnnouncement => 'Loading, please wait';

  @override
  String get passwordVisible => 'Password visible';

  @override
  String get passwordHidden => 'Password hidden';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get dismissSheet => 'Dismiss sheet';

  @override
  String get closeSheet => 'Close sheet';

  @override
  String get dismissDialog => 'Dismiss dialog';

  @override
  String get defaultDialogTitle => 'Dialog';

  @override
  String get defaultBottomSheetTitle => 'Bottom Sheet';

  @override
  String get defaultUser => 'User';

  @override
  String profilePictureOf(String name) {
    return 'Profile picture of $name';
  }

  @override
  String profilePictureOfWithStatus(String name) {
    return 'Profile picture of $name, active status';
  }

  @override
  String viewProfileOf(String name) {
    return 'View profile of $name';
  }

  @override
  String viewProfileOfWithStatus(String name) {
    return 'View profile of $name, active status';
  }

  @override
  String statusIndicator(String status) {
    return '$status status indicator';
  }

  @override
  String unreadItemsCount(int count) {
    return '$count unread items';
  }

  @override
  String unreadItemsMoreThan(int max) {
    return 'more than $max unread items';
  }

  @override
  String badgeSuffix(String label) {
    return '$label badge';
  }

  @override
  String get loadingContent => 'Loading content';

  @override
  String get loadingProfileAvatar => 'Loading profile avatar';
}

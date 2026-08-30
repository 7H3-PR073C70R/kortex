import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'arb/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Sample text
  ///
  /// In en, this message translates to:
  /// **'sample'**
  String get sample;

  /// Application name
  ///
  /// In en, this message translates to:
  /// **'KORTEX'**
  String get appName;

  /// Engine subtitle shown on splash screen
  ///
  /// In en, this message translates to:
  /// **'ENGINE: SYLLABOT AI'**
  String get engineSubtitle;

  /// Skip button label
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// Continue button label
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingNext;

  /// Get Started button label
  ///
  /// In en, this message translates to:
  /// **'Get Started with Kortex'**
  String get onboardingGetStarted;

  /// Accessibility label for the onboarding carousel
  ///
  /// In en, this message translates to:
  /// **'Kortex Onboarding Carousel'**
  String get onboardingCarouselSemantics;

  /// Accessibility label for skip button
  ///
  /// In en, this message translates to:
  /// **'Skip onboarding and enter app'**
  String get onboardingSkipSemantics;

  /// Accessibility label for next slide button
  ///
  /// In en, this message translates to:
  /// **'Continue to next onboarding slide'**
  String get onboardingNextSemantics;

  /// Accessibility label for get started button
  ///
  /// In en, this message translates to:
  /// **'Get Started with Kortex and finish onboarding'**
  String get onboardingGetStartedSemantics;

  /// Badge for slide 1
  ///
  /// In en, this message translates to:
  /// **'ZERO-LATENCY INGESTION'**
  String get onboardingSlide1Badge;

  /// Title for slide 1
  ///
  /// In en, this message translates to:
  /// **'Drop. Parse. Master.'**
  String get onboardingSlide1Title;

  /// Description for slide 1
  ///
  /// In en, this message translates to:
  /// **'Transform dense syllabi, past papers, and STEM lecture slides into structured active-recall systems instantly.'**
  String get onboardingSlide1Desc;

  /// Badge for slide 2
  ///
  /// In en, this message translates to:
  /// **'PRECISION STEM OCR'**
  String get onboardingSlide2Badge;

  /// Title for slide 2
  ///
  /// In en, this message translates to:
  /// **'Flawless Math & Science OCR'**
  String get onboardingSlide2Title;

  /// Description for slide 2
  ///
  /// In en, this message translates to:
  /// **'Extract complex equations, integral bounds, and chemical formulas with exact LaTeX precision—no broken characters.'**
  String get onboardingSlide2Desc;

  /// Badge for slide 3
  ///
  /// In en, this message translates to:
  /// **'EBBINGHAUS SM-2'**
  String get onboardingSlide3Badge;

  /// Title for slide 3
  ///
  /// In en, this message translates to:
  /// **'Forget About Forgetting'**
  String get onboardingSlide3Title;

  /// Description for slide 3
  ///
  /// In en, this message translates to:
  /// **'Adaptive forgetting curves schedule your reviews at the exact moment memories fade. Say goodbye to the cramming illusion.'**
  String get onboardingSlide3Desc;

  /// Badge for slide 4
  ///
  /// In en, this message translates to:
  /// **'SOCRATIC TUTORING'**
  String get onboardingSlide4Badge;

  /// Title for slide 4
  ///
  /// In en, this message translates to:
  /// **'Calibrate Your Confidence'**
  String get onboardingSlide4Title;

  /// Description for slide 4
  ///
  /// In en, this message translates to:
  /// **'Test your true readiness with timed mock exams and guided Socratic tutoring that leads you to the answer without spoiling it.'**
  String get onboardingSlide4Desc;

  /// Accessibility label for page indicator dots
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String onboardingPageIndicatorSemantics(int current, int total);

  /// Voiceover announcement on slide transition
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}: {title}'**
  String onboardingPageAnnouncement(int current, int total, String title);

  /// Accessibility announcement when loading starts
  ///
  /// In en, this message translates to:
  /// **'Loading, please wait'**
  String get loadingAnnouncement;

  /// Accessibility announcement when password becomes visible
  ///
  /// In en, this message translates to:
  /// **'Password visible'**
  String get passwordVisible;

  /// Accessibility announcement when password becomes hidden
  ///
  /// In en, this message translates to:
  /// **'Password hidden'**
  String get passwordHidden;

  /// Tooltip and semantics label for show password button
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// Tooltip and semantics label for hide password button
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// Accessibility label for sheet drag handle dismiss
  ///
  /// In en, this message translates to:
  /// **'Dismiss sheet'**
  String get dismissSheet;

  /// Accessibility label for sheet close button
  ///
  /// In en, this message translates to:
  /// **'Close sheet'**
  String get closeSheet;

  /// Accessibility label for dialog barrier
  ///
  /// In en, this message translates to:
  /// **'Dismiss dialog'**
  String get dismissDialog;

  /// Default semantic label for dialog
  ///
  /// In en, this message translates to:
  /// **'Dialog'**
  String get defaultDialogTitle;

  /// Default semantic label for bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Bottom Sheet'**
  String get defaultBottomSheetTitle;

  /// Default user fallback name
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get defaultUser;

  /// Accessibility label for user profile avatar
  ///
  /// In en, this message translates to:
  /// **'Profile picture of {name}'**
  String profilePictureOf(String name);

  /// Accessibility label for user profile avatar with active badge
  ///
  /// In en, this message translates to:
  /// **'Profile picture of {name}, active status'**
  String profilePictureOfWithStatus(String name);

  /// Button label to view user profile
  ///
  /// In en, this message translates to:
  /// **'View profile of {name}'**
  String viewProfileOf(String name);

  /// Button label to view user profile with active status
  ///
  /// In en, this message translates to:
  /// **'View profile of {name}, active status'**
  String viewProfileOfWithStatus(String name);

  /// Accessibility label for status dot badge
  ///
  /// In en, this message translates to:
  /// **'{status} status indicator'**
  String statusIndicator(String status);

  /// Accessibility label for count badge
  ///
  /// In en, this message translates to:
  /// **'{count} unread items'**
  String unreadItemsCount(int count);

  /// Accessibility label for count badge exceeding max
  ///
  /// In en, this message translates to:
  /// **'more than {max} unread items'**
  String unreadItemsMoreThan(int max);

  /// Accessibility label for generic badge
  ///
  /// In en, this message translates to:
  /// **'{label} badge'**
  String badgeSuffix(String label);

  /// Accessibility label for shimmer placeholder
  ///
  /// In en, this message translates to:
  /// **'Loading content'**
  String get loadingContent;

  /// Accessibility label for circular shimmer avatar
  ///
  /// In en, this message translates to:
  /// **'Loading profile avatar'**
  String get loadingProfileAvatar;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

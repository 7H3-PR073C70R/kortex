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
  /// **'KORTEXIFY'**
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
  /// **'Get Started with Kortexify'**
  String get onboardingGetStarted;

  /// Accessibility label for the onboarding carousel
  ///
  /// In en, this message translates to:
  /// **'Kortexify Onboarding Carousel'**
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
  /// **'Get Started with Kortexify and finish onboarding'**
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
  /// **'Transform dense syllabi, past papers, and course lecture slides into structured active-recall systems instantly.'**
  String get onboardingSlide1Desc;

  /// Badge for slide 2
  ///
  /// In en, this message translates to:
  /// **'PRECISION ACADEMIC OCR'**
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

  /// Button label to switch to quick form mode
  ///
  /// In en, this message translates to:
  /// **'Quick Form'**
  String get authSwitchToForm;

  /// Button label to switch to AI chat mode
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get authSwitchToChat;

  /// Social sign in with Google button label
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authSocialGoogle;

  /// Social sign in with Apple button label
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get authSocialApple;

  /// Warm initial greeting with motivational quote from Syllabot in auth chat
  ///
  /// In en, this message translates to:
  /// **'Hi Stranger! 👋 Welcome to Kortexify.\n\n✨ \"The beautiful thing about learning is that no one can take it away from you.\" — B.B. King\n\nI\'m Syllabot, your AI study partner. How would you like to get started today?'**
  String get authChatWelcome;

  /// Syllabot asking for user email
  ///
  /// In en, this message translates to:
  /// **'Please enter your academic or personal email address.'**
  String get authChatAskEmail;

  /// Syllabot asking for password
  ///
  /// In en, this message translates to:
  /// **'Great! Set a secure password (at least 6 characters).'**
  String get authChatAskPassword;

  /// Quick action chip to switch to login mode
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get authChipLogin;

  /// Quick action chip to switch to sign up mode
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get authChipSignUp;

  /// Quick action chip for forgot password
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get authChipForgotPassword;

  /// Quick action chip to use Google auth
  ///
  /// In en, this message translates to:
  /// **'Use Google'**
  String get authChipGoogle;

  /// Title for forgot password page
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get authForgotPasswordTitle;

  /// Subtitle for forgot password page
  ///
  /// In en, this message translates to:
  /// **'Enter your registered email address and we will send you instructions to reset your password.'**
  String get authForgotPasswordSubtitle;

  /// Label for email text field
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get authEmailLabel;

  /// Hint for email text field
  ///
  /// In en, this message translates to:
  /// **'student@university.edu'**
  String get authEmailHint;

  /// Label for password text field
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// Hint for password text field
  ///
  /// In en, this message translates to:
  /// **'••••••••'**
  String get authPasswordHint;

  /// Label for display name text field
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get authDisplayNameLabel;

  /// Hint for display name text field
  ///
  /// In en, this message translates to:
  /// **'Ada Lovelace'**
  String get authDisplayNameHint;

  /// Submit button for login
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get authSubmitLogin;

  /// Submit button for registration
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get authSubmitRegister;

  /// Submit button for password reset
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get authSubmitReset;

  /// Toggle link to switch from register to login
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign In'**
  String get authAlreadyHaveAccount;

  /// Toggle link to switch from login to register
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign Up'**
  String get authNeedAccount;

  /// Chat message send button
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get authSend;

  /// Hint for chat message input
  ///
  /// In en, this message translates to:
  /// **'Type a response or tap a quick action...'**
  String get authChatInputHint;

  /// Validation error message for invalid email
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get authInvalidEmail;

  /// Validation error message for short password
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get authPasswordTooShort;

  /// Generic authentication error message
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Please try again.'**
  String get authGenericError;

  /// Success message upon authentication
  ///
  /// In en, this message translates to:
  /// **'Welcome to Kortexify!'**
  String get authSuccessMessage;

  /// Accessibility label for mode toggle button
  ///
  /// In en, this message translates to:
  /// **'Switch to {mode}'**
  String authModeToggleSemantics(String mode);

  /// Accessibility label for Google sign-in button
  ///
  /// In en, this message translates to:
  /// **'Sign in with your Google account'**
  String get authSocialGoogleSemantics;

  /// Accessibility label for Apple sign-in button
  ///
  /// In en, this message translates to:
  /// **'Sign in with your Apple ID'**
  String get authSocialAppleSemantics;

  /// Live screen reader announcement when auth mode changes
  ///
  /// In en, this message translates to:
  /// **'Switched to {mode} view'**
  String authModeSwitchedAnnouncement(String mode);

  /// Hero title for desktop auth panel
  ///
  /// In en, this message translates to:
  /// **'Your AI-Augmented Academic Workspace'**
  String get authDesktopHeroTitle;

  /// Hero subtitle for desktop auth panel
  ///
  /// In en, this message translates to:
  /// **'Ingest syllabi, academic equations, and lecture slides into an active-recall mastery system in seconds.'**
  String get authDesktopHeroSubtitle;

  /// Hero bullet feature 1
  ///
  /// In en, this message translates to:
  /// **'Zero-latency multimodal Document OCR'**
  String get authDesktopFeature1;

  /// Hero bullet feature 2
  ///
  /// In en, this message translates to:
  /// **'Adaptive SM-2 spaced repetition schedules'**
  String get authDesktopFeature2;

  /// Hero bullet feature 3
  ///
  /// In en, this message translates to:
  /// **'Socratic AI dialogue & calibration'**
  String get authDesktopFeature3;

  /// Accessibility label for chat input field
  ///
  /// In en, this message translates to:
  /// **'Chat response input field'**
  String get authChatInputSemantics;

  /// Accessibility label for chat send button
  ///
  /// In en, this message translates to:
  /// **'Send chat response'**
  String get authChatSendSemantics;

  /// Accessibility label for forgot password link
  ///
  /// In en, this message translates to:
  /// **'Reset password screen link'**
  String get authForgotPasswordLinkSemantics;

  /// Accessibility label for toggle form type button
  ///
  /// In en, this message translates to:
  /// **'Toggle between Sign In and Create Account forms'**
  String get authToggleFormTypeSemantics;

  /// Top header title for calibration wizard
  ///
  /// In en, this message translates to:
  /// **'Academic Calibration'**
  String get calibrationTitle;

  /// Subtitle for calibration wizard
  ///
  /// In en, this message translates to:
  /// **'Personalize Syllabot AI for your academic trajectory'**
  String get calibrationSubtitle;

  /// Welcome message for calibration chat
  ///
  /// In en, this message translates to:
  /// **'Awesome, you\'re in! To customize your workspace, let\'s set up your academic profile.'**
  String get calibrationChatWelcome;

  /// Prompt asking for academic focus in chat mode
  ///
  /// In en, this message translates to:
  /// **'Are you studying at a University/Polytechnic or preparing for High School exams?'**
  String get calibrationChatFocusPrompt;

  /// Prompt asking for level in chat mode
  ///
  /// In en, this message translates to:
  /// **'Got it! Which specific exam or degree track are you focusing on?'**
  String get calibrationChatLevelPrompt;

  /// Prompt asking for field in chat mode
  ///
  /// In en, this message translates to:
  /// **'Excellent. What is your specific field of study or main subjects?'**
  String get calibrationChatFieldPrompt;

  /// Question prompt for user's primary goal in conversational calibration
  ///
  /// In en, this message translates to:
  /// **'Perfect. How can Kortexify best support you right now?'**
  String get calibrationChatGoalPrompt;

  /// Calibration goal option for exams
  ///
  /// In en, this message translates to:
  /// **'Ace Upcoming Exams'**
  String get calibrationOptionExams;

  /// Calibration goal option for daily habit
  ///
  /// In en, this message translates to:
  /// **'Daily Habit & Spaced Retention'**
  String get calibrationOptionDailyReview;

  /// Calibration goal option for catching up
  ///
  /// In en, this message translates to:
  /// **'Catch Up on Coursework'**
  String get calibrationOptionCatchUp;

  /// Calibration goal option for deep mastery
  ///
  /// In en, this message translates to:
  /// **'Deep Conceptual Mastery'**
  String get calibrationOptionDeepMastery;

  /// Completion message in conversational calibration
  ///
  /// In en, this message translates to:
  /// **'You\'re all set! I\'ve personalized your study engine with adaptive FSRS scheduling and tailored your daily quotas. Let\'s conquer this semester.'**
  String get calibrationChatReady;

  /// University option in chat mode
  ///
  /// In en, this message translates to:
  /// **'University / Polytechnic'**
  String get calibrationFocusHigherEd;

  /// High school option in chat mode
  ///
  /// In en, this message translates to:
  /// **'High School / Exam Prep'**
  String get calibrationFocusHighSchool;

  /// Accessibility announcement for calibration step transition
  ///
  /// In en, this message translates to:
  /// **'Calibration step {current} of {total}: {title}'**
  String calibrationStepAnnouncement(int current, int total, String title);

  /// Back button in calibration wizard
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get calibrationBack;

  /// Continue button in calibration wizard
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get calibrationContinue;

  /// Finish button in calibration wizard
  ///
  /// In en, this message translates to:
  /// **'Calibrate & Launch Kortexify'**
  String get calibrationFinish;

  /// Question 1 in calibration
  ///
  /// In en, this message translates to:
  /// **'What is your current academic focus?'**
  String get calibrationQuestion1;

  /// University option chip
  ///
  /// In en, this message translates to:
  /// **'University / Polytechnic'**
  String get calibrationOptionUniversity;

  /// High school option chip
  ///
  /// In en, this message translates to:
  /// **'High School / Exam Prep'**
  String get calibrationOptionHighSchool;

  /// Question A2 in calibration
  ///
  /// In en, this message translates to:
  /// **'What is your current academic level?'**
  String get calibrationQuestionA2;

  /// OND option
  ///
  /// In en, this message translates to:
  /// **'OND (Ordinary National Diploma)'**
  String get calibrationOptionOND;

  /// HND option
  ///
  /// In en, this message translates to:
  /// **'HND (Higher National Diploma)'**
  String get calibrationOptionHND;

  /// BSc option
  ///
  /// In en, this message translates to:
  /// **'BSc (Bachelor of Science)'**
  String get calibrationOptionBSc;

  /// MSc option
  ///
  /// In en, this message translates to:
  /// **'MSc (Master of Science)'**
  String get calibrationOptionMSc;

  /// PhD option
  ///
  /// In en, this message translates to:
  /// **'PhD (Doctor of Philosophy)'**
  String get calibrationOptionPhD;

  /// Question A3 in calibration
  ///
  /// In en, this message translates to:
  /// **'What is your specific field of study?'**
  String get calibrationQuestionA3;

  /// Subtitle for question A3
  ///
  /// In en, this message translates to:
  /// **'Select your primary domain to optimize Syllabot\'s knowledge retrieval'**
  String get calibrationQuestionA3Subtitle;

  /// Math field
  ///
  /// In en, this message translates to:
  /// **'Mathematics & Data Science'**
  String get calibrationFieldMath;

  /// Physics field
  ///
  /// In en, this message translates to:
  /// **'Advanced Physics / Quantum Mechanics'**
  String get calibrationFieldPhysics;

  /// Chemical Engineering field
  ///
  /// In en, this message translates to:
  /// **'Chemical Engineering'**
  String get calibrationFieldChemEng;

  /// Medical field
  ///
  /// In en, this message translates to:
  /// **'Medical & Health Sciences'**
  String get calibrationFieldMedicine;

  /// Robotics field
  ///
  /// In en, this message translates to:
  /// **'Robotics & Mechanical Engineering'**
  String get calibrationFieldRobotics;

  /// Computer Science field
  ///
  /// In en, this message translates to:
  /// **'Computer Science & Artificial Intelligence'**
  String get calibrationFieldComputerScience;

  /// Law & Legal Studies field
  ///
  /// In en, this message translates to:
  /// **'Law & Legal Studies'**
  String get calibrationFieldLaw;

  /// Business, Finance & Accounting field
  ///
  /// In en, this message translates to:
  /// **'Business, Finance & Accounting'**
  String get calibrationFieldBusiness;

  /// Humanities, History & Literature field
  ///
  /// In en, this message translates to:
  /// **'Humanities, History & Literature'**
  String get calibrationFieldHumanities;

  /// Social Sciences & Economics field
  ///
  /// In en, this message translates to:
  /// **'Social Sciences & Economics'**
  String get calibrationFieldSocialSciences;

  /// Question A4 in calibration
  ///
  /// In en, this message translates to:
  /// **'How can Kortexify best support you right now?'**
  String get calibrationQuestionA4;

  /// Subtitle for question A4
  ///
  /// In en, this message translates to:
  /// **'Select all features you want Syllabot to prioritize for you'**
  String get calibrationQuestionA4Subtitle;

  /// Thesis support goal
  ///
  /// In en, this message translates to:
  /// **'Thesis / Dissertation Support'**
  String get calibrationGoalThesis;

  /// Socratic AI goal
  ///
  /// In en, this message translates to:
  /// **'Deep-Dive Socratic AI Tutor'**
  String get calibrationGoalSocratic;

  /// Spaced repetition goal
  ///
  /// In en, this message translates to:
  /// **'Spaced Repetition (SM-2) Mastery'**
  String get calibrationGoalSpacedRep;

  /// Mock exams goal
  ///
  /// In en, this message translates to:
  /// **'Comprehensive Mock Exams'**
  String get calibrationGoalMockExams;

  /// Case law & essay goal
  ///
  /// In en, this message translates to:
  /// **'Case Law & Essay Preparation'**
  String get calibrationGoalCaseLaw;

  /// Essay prep goal
  ///
  /// In en, this message translates to:
  /// **'Structured Essay & Argument Mapping'**
  String get calibrationGoalEssayPrep;

  /// Question B2 in calibration
  ///
  /// In en, this message translates to:
  /// **'What exam are you preparing for?'**
  String get calibrationQuestionB2;

  /// WAEC exam
  ///
  /// In en, this message translates to:
  /// **'WAEC / GCE'**
  String get calibrationExamWAEC;

  /// NECO exam
  ///
  /// In en, this message translates to:
  /// **'NECO / SSCE'**
  String get calibrationExamNECO;

  /// JAMB exam
  ///
  /// In en, this message translates to:
  /// **'JAMB / UTME'**
  String get calibrationExamJAMB;

  /// SAT exam
  ///
  /// In en, this message translates to:
  /// **'SAT'**
  String get calibrationExamSAT;

  /// IELTS exam
  ///
  /// In en, this message translates to:
  /// **'IELTS / TOEFL'**
  String get calibrationExamIELTS;

  /// IGCSE exam
  ///
  /// In en, this message translates to:
  /// **'IGCSE / A-Levels'**
  String get calibrationExamIGCSE;

  /// Question B3 in calibration
  ///
  /// In en, this message translates to:
  /// **'What subjects do you need to master?'**
  String get calibrationQuestionB3;

  /// Subtitle for question B3
  ///
  /// In en, this message translates to:
  /// **'Select all subjects for active-recall flashcard generation'**
  String get calibrationQuestionB3Subtitle;

  /// Core Math subject
  ///
  /// In en, this message translates to:
  /// **'Mathematics (Core)'**
  String get calibrationSubjectCoreMath;

  /// Further Math subject
  ///
  /// In en, this message translates to:
  /// **'Further Mathematics'**
  String get calibrationSubjectFurtherMath;

  /// Physics subject
  ///
  /// In en, this message translates to:
  /// **'Physics'**
  String get calibrationSubjectPhysics;

  /// Chemistry subject
  ///
  /// In en, this message translates to:
  /// **'Chemistry'**
  String get calibrationSubjectChemistry;

  /// Biology subject
  ///
  /// In en, this message translates to:
  /// **'Biology'**
  String get calibrationSubjectBiology;

  /// English Language subject
  ///
  /// In en, this message translates to:
  /// **'English Language'**
  String get calibrationSubjectEnglish;

  /// Financial Accounting subject
  ///
  /// In en, this message translates to:
  /// **'Financial Accounting'**
  String get calibrationSubjectAccounting;

  /// Economics subject
  ///
  /// In en, this message translates to:
  /// **'Economics'**
  String get calibrationSubjectEconomics;

  /// Commerce subject
  ///
  /// In en, this message translates to:
  /// **'Commerce'**
  String get calibrationSubjectCommerce;

  /// Literature in English subject
  ///
  /// In en, this message translates to:
  /// **'Literature in English'**
  String get calibrationSubjectLiterature;

  /// Government subject
  ///
  /// In en, this message translates to:
  /// **'Government'**
  String get calibrationSubjectGovernment;

  /// History subject
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get calibrationSubjectHistory;

  /// Christian/Islamic Religious Knowledge subject
  ///
  /// In en, this message translates to:
  /// **'CRK / IRK'**
  String get calibrationSubjectCRK;

  /// Core subject track label
  ///
  /// In en, this message translates to:
  /// **'Core'**
  String get calibrationTrackCore;

  /// Science track label
  ///
  /// In en, this message translates to:
  /// **'Science'**
  String get calibrationTrackScience;

  /// Commercial track label
  ///
  /// In en, this message translates to:
  /// **'Commercial'**
  String get calibrationTrackCommercial;

  /// Arts & Humanities track label
  ///
  /// In en, this message translates to:
  /// **'Arts / Humanities'**
  String get calibrationTrackArts;

  /// Question B4 in calibration
  ///
  /// In en, this message translates to:
  /// **'When is your exam?'**
  String get calibrationQuestionB4;

  /// 1 Month timeline
  ///
  /// In en, this message translates to:
  /// **'Next 1 Month'**
  String get calibrationTimeline1Month;

  /// 3 Months timeline
  ///
  /// In en, this message translates to:
  /// **'Next 3 Months'**
  String get calibrationTimeline3Months;

  /// 6 Months timeline
  ///
  /// In en, this message translates to:
  /// **'Next 6 Months'**
  String get calibrationTimeline6Months;

  /// Next year timeline
  ///
  /// In en, this message translates to:
  /// **'Next Year'**
  String get calibrationTimelineNextYear;

  /// Desktop hero title in calibration
  ///
  /// In en, this message translates to:
  /// **'Calibrating Neural Learning Engine'**
  String get calibrationDesktopHeroTitle;

  /// Desktop hero subtitle in calibration
  ///
  /// In en, this message translates to:
  /// **'Syllabot AI is adapting its retrieval indices, Socratic dialogue trees, and memory decay formulas specifically for your curriculum.'**
  String get calibrationDesktopHeroSubtitle;

  /// Desktop metric 1
  ///
  /// In en, this message translates to:
  /// **'Adaptive RAG Knowledge Base'**
  String get calibrationDesktopMetric1;

  /// Desktop metric 2
  ///
  /// In en, this message translates to:
  /// **'Curriculum-Specific Study Prompts'**
  String get calibrationDesktopMetric2;

  /// Desktop metric 3
  ///
  /// In en, this message translates to:
  /// **'Personalized Spaced Repetition Intervals'**
  String get calibrationDesktopMetric3;

  /// Accessibility label for selecting an option
  ///
  /// In en, this message translates to:
  /// **'Select {option}'**
  String calibrationSelectOptionSemantics(String option);

  /// Accessibility label for a selected option
  ///
  /// In en, this message translates to:
  /// **'{option}, selected'**
  String calibrationSelectedOptionSemantics(String option);

  /// Title for content recommendation screen
  ///
  /// In en, this message translates to:
  /// **'Pre-Calibrated Workspace'**
  String get contentRecommendationTitle;

  /// Subtitle for content recommendation screen
  ///
  /// In en, this message translates to:
  /// **'Curated resources ready in your dashboard'**
  String get contentRecommendationSubtitle;

  /// Accessibility announcement for recommendation slide change
  ///
  /// In en, this message translates to:
  /// **'Recommendation {current} of {total}: {title}'**
  String contentRecommendationAnnouncement(
    int current,
    int total,
    String title,
  );

  /// Tagline for past papers slide
  ///
  /// In en, this message translates to:
  /// **'Instant Exam Readiness'**
  String get contentPastPapersTagline;

  /// Description for past papers slide
  ///
  /// In en, this message translates to:
  /// **'Based on your target ({examType}), we\'ve selected high-yield past papers from our database for {subjects}.'**
  String contentPastPapersDesc(String examType, String subjects);

  /// Tagline for flashcards slide
  ///
  /// In en, this message translates to:
  /// **'Deep Mastery of {field}'**
  String contentFlashcardsTagline(String field);

  /// Description for flashcards slide
  ///
  /// In en, this message translates to:
  /// **'Dive into structured flashcards for core topics in {field}. Master key concepts instantly with SM-2 Spaced Repetition.'**
  String contentFlashcardsDesc(String field);

  /// Tagline for Socratic AI tutoring slide
  ///
  /// In en, this message translates to:
  /// **'Syllabot AI is Ready'**
  String get contentSocraticTagline;

  /// Description for Socratic AI tutoring slide
  ///
  /// In en, this message translates to:
  /// **'We\'ve created tutoring threads covering mandatory topics for {level} students in {field}. Ask Syllabot anything!'**
  String contentSocraticDesc(String level, String field);

  /// Next button tooltip and label
  ///
  /// In en, this message translates to:
  /// **'Next Recommendation'**
  String get contentNextButton;

  /// Get started button tooltip and label
  ///
  /// In en, this message translates to:
  /// **'Launch Dashboard'**
  String get contentGetStartedButton;

  /// Skip button label
  ///
  /// In en, this message translates to:
  /// **'Skip to Dashboard'**
  String get contentSkipButton;

  /// Desktop hero title in content recommendation
  ///
  /// In en, this message translates to:
  /// **'Your Pre-Loaded Academic Hub'**
  String get contentDesktopHeroTitle;

  /// Desktop hero subtitle in content recommendation
  ///
  /// In en, this message translates to:
  /// **'Zero blank pages. We\'ve pre-seeded your library with verified past exams, adaptive study decks, and automated Socratic dialogue channels.'**
  String get contentDesktopHeroSubtitle;

  /// Content recommendation feature 1
  ///
  /// In en, this message translates to:
  /// **'Pre-indexed exam question banks'**
  String get contentFeature1;

  /// Content recommendation feature 2
  ///
  /// In en, this message translates to:
  /// **'Automated SM-2 spaced repetition decks'**
  String get contentFeature2;

  /// Content recommendation feature 3
  ///
  /// In en, this message translates to:
  /// **'Dedicated 24/7 Syllabot AI course assistants'**
  String get contentFeature3;

  /// Badge label for pre-populated content
  ///
  /// In en, this message translates to:
  /// **'DATABASE PRE-POPULATED'**
  String get contentBadgeCurated;

  /// Badge label for active recall deck
  ///
  /// In en, this message translates to:
  /// **'ACTIVE RECALL DECK'**
  String get contentBadgeActiveRecall;

  /// Badge label for socratic dialogue
  ///
  /// In en, this message translates to:
  /// **'SOCRATIC DIALOGUE'**
  String get contentBadgeSocratic;

  /// Title on OTP verification screen
  ///
  /// In en, this message translates to:
  /// **'Check your inbox'**
  String get otpTitle;

  /// Subtitle on OTP screen with email placeholder
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit verification code to {email}. Enter it below to verify your account.'**
  String otpSubtitle(String email);

  /// Label on OTP verify button
  ///
  /// In en, this message translates to:
  /// **'Verify Email'**
  String get otpVerifyButton;

  /// Label on resend OTP link
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get otpResendCode;

  /// Label while OTP is being resent
  ///
  /// In en, this message translates to:
  /// **'Resending…'**
  String get otpResending;

  /// Countdown label before resend is allowed
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String otpResendIn(int seconds);

  /// Snackbar confirmation that OTP was resent
  ///
  /// In en, this message translates to:
  /// **'A new code has been sent to your email.'**
  String get otpResentMessage;

  /// Screen reader announcement when verifying OTP
  ///
  /// In en, this message translates to:
  /// **'Verifying your code, please wait.'**
  String get otpVerifyingAnnouncement;

  /// Screen reader announcement when OTP is verified
  ///
  /// In en, this message translates to:
  /// **'Email verified successfully. Welcome to Kortexify!'**
  String get otpVerifiedAnnouncement;

  /// Semantics label for OTP PIN input
  ///
  /// In en, this message translates to:
  /// **'Six digit verification code input'**
  String get otpInputSemantics;

  /// Semantics label for verify button
  ///
  /// In en, this message translates to:
  /// **'Verify your email address'**
  String get otpVerifyButtonSemantics;

  /// Semantics label for resend button
  ///
  /// In en, this message translates to:
  /// **'Resend verification code'**
  String get otpResendSemantics;

  /// Title on permissions interstitial page
  ///
  /// In en, this message translates to:
  /// **'Supercharge Your Focus'**
  String get permissionsTitle;

  /// Subtitle on permissions page
  ///
  /// In en, this message translates to:
  /// **'Allow Kortexify to send you study reminders and scan your documents for instant AI indexing.'**
  String get permissionsSubtitle;

  /// Notification permission card title
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get permissionsNotifTitle;

  /// Notification permission card description
  ///
  /// In en, this message translates to:
  /// **'Receive spaced-repetition reminders and active-recall session alerts calibrated to your study streak.'**
  String get permissionsNotifDescription;

  /// Storage permission card title
  ///
  /// In en, this message translates to:
  /// **'Camera & Storage Access'**
  String get permissionsStorageTitle;

  /// Storage permission card description
  ///
  /// In en, this message translates to:
  /// **'Snap textbook pages for OCR parsing and drop in PDF or PPTX lecture slides for instant AI indexing.'**
  String get permissionsStorageDescription;

  /// Button label to allow a permission
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get permissionsAllow;

  /// Continue button on permissions page
  ///
  /// In en, this message translates to:
  /// **'Continue to Dashboard'**
  String get permissionsContinue;

  /// Skip button on permissions page
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get permissionsSkip;

  /// Screen reader announcement when permissions step is done
  ///
  /// In en, this message translates to:
  /// **'Permissions configured. Opening your dashboard.'**
  String get permissionsCompleteAnnouncement;

  /// Semantics label for notification permission allow button
  ///
  /// In en, this message translates to:
  /// **'Allow push notifications for study reminders'**
  String get permissionsNotifSemantics;

  /// Semantics label for storage permission allow button
  ///
  /// In en, this message translates to:
  /// **'Allow camera and storage access for document scanning'**
  String get permissionsStorageSemantics;

  /// Semantics label for skip permissions button
  ///
  /// In en, this message translates to:
  /// **'Skip permissions and proceed to dashboard'**
  String get permissionsSkipSemantics;

  /// Skip button label on calibration page
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get calibrationSkip;

  /// Semantics label for skip calibration button
  ///
  /// In en, this message translates to:
  /// **'Skip academic profile setup and use default settings'**
  String get calibrationSkipSemantics;

  /// Accessibility label for main navigation bar
  ///
  /// In en, this message translates to:
  /// **'Main Navigation'**
  String get navBarSemanticsLabel;

  /// Home tab label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navTabHome;

  /// Syllabot AI tab label
  ///
  /// In en, this message translates to:
  /// **'Syllabot AI'**
  String get navTabSyllabot;

  /// Decks tab label
  ///
  /// In en, this message translates to:
  /// **'Study Decks'**
  String get navTabDecks;

  /// Community tab label
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get navTabCommunity;

  /// Profile tab label
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navTabProfile;

  /// Voiceover announcement when a navigation tab is selected
  ///
  /// In en, this message translates to:
  /// **'Switched to {tab} tab'**
  String navTabAnnouncement(String tab);

  /// Accessibility label for navigation tab item
  ///
  /// In en, this message translates to:
  /// **'{tab}, tab {current} of {total}'**
  String navTabSemantics(String tab, int current, int total);

  /// User greeting in dashboard header
  ///
  /// In en, this message translates to:
  /// **'Hey, {name} 👋'**
  String dashboardHeyUser(String name);

  /// Fallback name when username is not set
  ///
  /// In en, this message translates to:
  /// **'Scholar'**
  String get dashboardScholarFallback;

  /// Accessibility label for streak counter
  ///
  /// In en, this message translates to:
  /// **'{count} day study streak'**
  String dashboardStreakTooltip(int count);

  /// Semantics for viewing analytics detail
  ///
  /// In en, this message translates to:
  /// **'View detailed study analytics and streaks'**
  String get dashboardViewAnalyticsSemantics;

  /// Title for uncalibrated profile banner
  ///
  /// In en, this message translates to:
  /// **'Calibrate Your Neural Workspace'**
  String get dashboardUncalibratedTitle;

  /// Subtitle for uncalibrated profile banner
  ///
  /// In en, this message translates to:
  /// **'Tailor past papers, flashcards & exam simulator to your exact course.'**
  String get dashboardUncalibratedSubtitle;

  /// Button label for calibration banner
  ///
  /// In en, this message translates to:
  /// **'Calibrate'**
  String get dashboardCalibrateButton;

  /// Semantics label for uncalibrated profile banner
  ///
  /// In en, this message translates to:
  /// **'Profile is not calibrated. Tap to configure your academic track.'**
  String get dashboardUncalibratedSemantics;

  /// Error title on dashboard
  ///
  /// In en, this message translates to:
  /// **'Unable to Load Dashboard'**
  String get dashboardUnableToLoad;

  /// Error description on dashboard
  ///
  /// In en, this message translates to:
  /// **'Please check your network connection and try again.'**
  String get dashboardConnectionError;

  /// Retry button on dashboard
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get dashboardRetry;

  /// Title for spaced repetition review queue
  ///
  /// In en, this message translates to:
  /// **'Spaced Repetition Queue'**
  String get dashboardSpacedRepetitionQueue;

  /// Total decks badge count
  ///
  /// In en, this message translates to:
  /// **'{count} DECKS'**
  String dashboardDecksCount(int count);

  /// Active curated courses count
  ///
  /// In en, this message translates to:
  /// **'{count} ACTIVE'**
  String dashboardActiveCoursesCount(int count);

  /// Title for curated courses section
  ///
  /// In en, this message translates to:
  /// **'Curated Course Repositories'**
  String get dashboardCuratedCourses;

  /// Count of resources in course
  ///
  /// In en, this message translates to:
  /// **'{count} resources'**
  String dashboardResourcesCount(int count);

  /// Count of flashcards due today
  ///
  /// In en, this message translates to:
  /// **'{count} DUE'**
  String dashboardDueCount(int count);

  /// Memory retention label
  ///
  /// In en, this message translates to:
  /// **'Memory Retention'**
  String get dashboardMemoryRetention;

  /// Review deck action button
  ///
  /// In en, this message translates to:
  /// **'Review Deck'**
  String get dashboardReviewDeck;

  /// Estimated review duration
  ///
  /// In en, this message translates to:
  /// **'~{minutes} mins'**
  String dashboardEstimatedMinutes(int minutes);

  /// Hint in quick AI prompt bar
  ///
  /// In en, this message translates to:
  /// **'Ask Syllabot anything (e.g. Solve PDE #3)...'**
  String get dashboardAskSyllabotHint;

  /// Semantics for send prompt button
  ///
  /// In en, this message translates to:
  /// **'Send prompt to Syllabot AI'**
  String get dashboardSendPromptSemantics;

  /// Semantics for AI prompt input bar
  ///
  /// In en, this message translates to:
  /// **'Ask Syllabot AI instant study question'**
  String get dashboardAskSyllabotSemantics;

  /// Title for retention heat map widget
  ///
  /// In en, this message translates to:
  /// **'Retention & Study Matrix'**
  String get dashboardRetentionMatrix;

  /// Link to full analytics stats
  ///
  /// In en, this message translates to:
  /// **'Full Stats'**
  String get dashboardFullStats;

  /// Retention chip label
  ///
  /// In en, this message translates to:
  /// **'Retention'**
  String get dashboardRetentionChip;

  /// Mastered cards chip label
  ///
  /// In en, this message translates to:
  /// **'Mastered'**
  String get dashboardMasteredChip;

  /// Study time chip label
  ///
  /// In en, this message translates to:
  /// **'Study Time'**
  String get dashboardStudyTimeChip;

  /// Study time formatted in minutes
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String dashboardStudyTimeMinutes(int minutes);

  /// Semantics for floating speed dial action bar
  ///
  /// In en, this message translates to:
  /// **'Quick action bar: Upload PDF, create active recall deck, or start AI study chat'**
  String get dashboardQuickActionsSemantics;

  /// Upload notes action button
  ///
  /// In en, this message translates to:
  /// **'Upload Notes'**
  String get dashboardUploadNotes;

  /// New deck action button
  ///
  /// In en, this message translates to:
  /// **'New Deck'**
  String get dashboardNewDeck;

  /// AI Partner action button
  ///
  /// In en, this message translates to:
  /// **'AI Partner'**
  String get dashboardAiPartner;

  /// Title for study material upload sheet
  ///
  /// In en, this message translates to:
  /// **'Ingest Study Material'**
  String get dashboardIngestTitle;

  /// Subtitle for study material upload sheet
  ///
  /// In en, this message translates to:
  /// **'Drop lecture slides, PDFs or handwritten past papers. Syllabot will parse Document OCR & generate flashcards.'**
  String get dashboardIngestSubtitle;

  /// Upload PDF option
  ///
  /// In en, this message translates to:
  /// **'Upload PDF'**
  String get dashboardUploadPdf;

  /// Lecture slides subtitle
  ///
  /// In en, this message translates to:
  /// **'Lecture Slides'**
  String get dashboardLectureSlides;

  /// Scan handwritten notes option
  ///
  /// In en, this message translates to:
  /// **'Scan Notes'**
  String get dashboardScanNotes;

  /// Document OCR subtitle
  ///
  /// In en, this message translates to:
  /// **'Document OCR'**
  String get dashboardStemOcr;

  /// Exam countdown days remaining badge
  ///
  /// In en, this message translates to:
  /// **'{count} DAYS LEFT'**
  String dashboardDaysLeft(int count);

  /// Syllabus mastery label
  ///
  /// In en, this message translates to:
  /// **'Syllabus Mastery'**
  String get dashboardSyllabusMastery;

  /// Syllabus mastery percentage complete
  ///
  /// In en, this message translates to:
  /// **'{percent}% complete'**
  String dashboardSyllabusPercentComplete(int percent);

  /// Launch mock exam simulator button
  ///
  /// In en, this message translates to:
  /// **'Launch Mock Simulator ({completed}/{total})'**
  String dashboardLaunchMockSimulator(int completed, int total);

  /// Semantics for launch mock simulator button
  ///
  /// In en, this message translates to:
  /// **'Launch {examName} Mock Simulator'**
  String dashboardLaunchMockSimulatorSemantics(String examName);

  /// Title for active recall flashcard session
  ///
  /// In en, this message translates to:
  /// **'Active Recall Session'**
  String get deckDetailTitle;

  /// Current flashcard review progress
  ///
  /// In en, this message translates to:
  /// **'Card {current} of {total}'**
  String deckDetailCardProgress(int current, int total);

  /// SM-2 queue badge label
  ///
  /// In en, this message translates to:
  /// **'SM-2 SPATIAL QUEUE'**
  String get deckDetailSm2QueueBadge;

  /// Back of flashcard badge
  ///
  /// In en, this message translates to:
  /// **'ANSWER / FORMULA'**
  String get deckDetailAnswerFormula;

  /// Front of flashcard badge
  ///
  /// In en, this message translates to:
  /// **'QUESTION'**
  String get deckDetailQuestion;

  /// Hint to tap and flip flashcard
  ///
  /// In en, this message translates to:
  /// **'Tap card to flip'**
  String get deckDetailTapToFlip;

  /// Hard rating button for SM-2
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get deckDetailHard;

  /// Good rating button for SM-2
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get deckDetailGood;

  /// Easy rating button for SM-2
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get deckDetailEasy;

  /// Back button semantics on deck detail page
  ///
  /// In en, this message translates to:
  /// **'Back to Dashboard'**
  String get deckDetailBackSemantics;

  /// Title for mock exam simulator lobby
  ///
  /// In en, this message translates to:
  /// **'Exam Simulator Lobby'**
  String get mockExamLobbyTitle;

  /// Description of mock exam simulator
  ///
  /// In en, this message translates to:
  /// **'Simulate computer-based testing with dynamic negative marking, question timers, and Syllabot AI error diagnostics.'**
  String get mockExamLobbyDescription;

  /// Header for selecting simulation mode
  ///
  /// In en, this message translates to:
  /// **'Select Simulation Mode'**
  String get mockExamSelectMode;

  /// Standard timed mode title
  ///
  /// In en, this message translates to:
  /// **'Standard Timed (CBT)'**
  String get mockExamModeStandardTitle;

  /// Standard timed mode subtitle
  ///
  /// In en, this message translates to:
  /// **'50 Questions · 60 Mins · Live Timer & Negative Marking'**
  String get mockExamModeStandardSubtitle;

  /// Socratic practice mode title
  ///
  /// In en, this message translates to:
  /// **'Socratic Practice Mode'**
  String get mockExamModeSocraticTitle;

  /// Socratic practice mode subtitle
  ///
  /// In en, this message translates to:
  /// **'Untimed · Instant Step-by-Step AI Solutions per question'**
  String get mockExamModeSocraticSubtitle;

  /// Weak areas targeted drill mode title
  ///
  /// In en, this message translates to:
  /// **'Weak Areas Targeted Drill'**
  String get mockExamModeDrillTitle;

  /// Weak areas targeted drill mode subtitle
  ///
  /// In en, this message translates to:
  /// **'Focused on concepts where your retention score is < 80%'**
  String get mockExamModeDrillSubtitle;

  /// Begin exam simulation session button
  ///
  /// In en, this message translates to:
  /// **'Begin Simulation Session'**
  String get mockExamBeginButton;

  /// Title for analytics detail page
  ///
  /// In en, this message translates to:
  /// **'Neural Analytics & Retention'**
  String get analyticsDetailTitle;

  /// Streak days headline in analytics
  ///
  /// In en, this message translates to:
  /// **'{count} Day Study Streak 🔥'**
  String analyticsStreakDays(int count);

  /// Streak record encouragement subtitle
  ///
  /// In en, this message translates to:
  /// **'Your record is 28 days. Keep studying to reach Neural Master rank!'**
  String get analyticsStreakRecord;

  /// Title for Ebbinghaus retention breakdown
  ///
  /// In en, this message translates to:
  /// **'Memory Retention Curve (Ebbinghaus SM-2)'**
  String get analyticsRetentionCurveTitle;

  /// Count of mastered concept cards
  ///
  /// In en, this message translates to:
  /// **'{count} concept cards mastered in active recall'**
  String analyticsMasteredCountSubtitle(int count);

  /// Section header for past papers
  ///
  /// In en, this message translates to:
  /// **'Past Papers & Problem Sets'**
  String get courseModulePastPapersTitle;

  /// Verified OCR description subtitle
  ///
  /// In en, this message translates to:
  /// **'Verified OCR · Step-by-Step AI Solutions'**
  String get courseModuleVerifiedSubtitle;

  /// Title for Decks page
  ///
  /// In en, this message translates to:
  /// **'Study Decks'**
  String get decksTitle;

  /// Subtitle for Decks page
  ///
  /// In en, this message translates to:
  /// **'Active recall queues powered by SuperMemo-2'**
  String get decksSubtitle;

  /// Search input hint for decks
  ///
  /// In en, this message translates to:
  /// **'Search decks or subjects...'**
  String get decksSearchHint;

  /// Cards due badge
  ///
  /// In en, this message translates to:
  /// **'{count} Due'**
  String decksDueBadge(int count);

  /// Pluralized card count in a deck
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 card} other{{count} cards}}'**
  String decksTotalCards(int count);

  /// Empty state title for decks
  ///
  /// In en, this message translates to:
  /// **'No Study Decks Yet'**
  String get decksEmptyStateTitle;

  /// Empty state subtitle for decks
  ///
  /// In en, this message translates to:
  /// **'Ingest lecture notes or past papers to generate SM-2 spaced repetition decks automatically.'**
  String get decksEmptyStateSubtitle;

  /// Button to create a new deck
  ///
  /// In en, this message translates to:
  /// **'Create New Deck'**
  String get decksCreateDeckButton;

  /// Filter tab for all decks
  ///
  /// In en, this message translates to:
  /// **'All Decks'**
  String get decksFilterAll;

  /// Filter tab for due decks
  ///
  /// In en, this message translates to:
  /// **'Due Today'**
  String get decksFilterDue;

  /// Filter tab for mastered decks
  ///
  /// In en, this message translates to:
  /// **'Mastered'**
  String get decksFilterMastered;

  /// Button label to start studying a deck
  ///
  /// In en, this message translates to:
  /// **'Start Study Session'**
  String get decksStartSession;

  /// Deck mastery percentage label
  ///
  /// In en, this message translates to:
  /// **'{percent}% mastery'**
  String decksMasteryPercent(int percent);

  /// App bar title during study session
  ///
  /// In en, this message translates to:
  /// **'Active Recall'**
  String get studySessionTitle;

  /// Card index display during study session
  ///
  /// In en, this message translates to:
  /// **'{current} / {total}'**
  String studySessionCardIndex(int current, int total);

  /// Hint to flip card
  ///
  /// In en, this message translates to:
  /// **'Tap card or press Spacebar to reveal answer'**
  String get studySessionTapToFlip;

  /// Swipe gesture hint
  ///
  /// In en, this message translates to:
  /// **'Swipe left for Hard · Swipe right for Good'**
  String get studySessionSwipeHint;

  /// Keyboard shortcuts guide
  ///
  /// In en, this message translates to:
  /// **'Space: Flip · 1: Again · 2: Hard · 3: Good · 4: Easy'**
  String get studySessionKeyboardShortcuts;

  /// Front face badge
  ///
  /// In en, this message translates to:
  /// **'PROMPT / EQUATION'**
  String get studySessionFrontBadge;

  /// Back face badge
  ///
  /// In en, this message translates to:
  /// **'EXPLANATION / DERIVATION'**
  String get studySessionBackBadge;

  /// SM-2 Again button label
  ///
  /// In en, this message translates to:
  /// **'Again'**
  String get studyRatingAgain;

  /// SM-2 Again interval
  ///
  /// In en, this message translates to:
  /// **'< 10m'**
  String get studyRatingAgainInterval;

  /// SM-2 Hard button label
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get studyRatingHard;

  /// SM-2 Hard interval
  ///
  /// In en, this message translates to:
  /// **'1d'**
  String get studyRatingHardInterval;

  /// SM-2 Good button label
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get studyRatingGood;

  /// SM-2 Good interval
  ///
  /// In en, this message translates to:
  /// **'6d'**
  String get studyRatingGoodInterval;

  /// SM-2 Easy button label
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get studyRatingEasy;

  /// SM-2 Easy interval
  ///
  /// In en, this message translates to:
  /// **'12d'**
  String get studyRatingEasyInterval;

  /// Title of create or ingest modal sheet
  ///
  /// In en, this message translates to:
  /// **'Create or Ingest Deck'**
  String get decksCreateSheetTitle;

  /// Subtitle of create or ingest modal sheet
  ///
  /// In en, this message translates to:
  /// **'Choose how you want to add active recall cards to your study deck.'**
  String get decksCreateSheetSubtitle;

  /// Action tile title for AI generation
  ///
  /// In en, this message translates to:
  /// **'Generate with Syllabot AI'**
  String get decksGenerateWithAiTitle;

  /// Action tile subtitle for AI generation
  ///
  /// In en, this message translates to:
  /// **'Create recall decks automatically from any topic.'**
  String get decksGenerateWithAiSubtitle;

  /// Action tile title for uploading documents
  ///
  /// In en, this message translates to:
  /// **'Scan & Upload Course Material'**
  String get decksUploadDocTitle;

  /// Action tile subtitle for uploading documents
  ///
  /// In en, this message translates to:
  /// **'Extract cards from PDFs, lecture notes, or slides.'**
  String get decksUploadDocSubtitle;

  /// Default prompt when creating deck via AI chat
  ///
  /// In en, this message translates to:
  /// **'Generate a new active recall flashcard deck.'**
  String get decksAiPromptDefault;

  /// Hint shown on back face of card
  ///
  /// In en, this message translates to:
  /// **'Rate recall below or swipe card'**
  String get studySessionTapToFlipBack;

  /// Gesture swipe guide for study session
  ///
  /// In en, this message translates to:
  /// **'Swipe Left: Hard · Right: Good · Up: Easy · Down: Again'**
  String get studySessionSwipe4WayHint;

  /// Key shortcut hint below rating button
  ///
  /// In en, this message translates to:
  /// **'Key {key}'**
  String studyRatingKeyShortcut(String key);

  /// Swipe route badge for Hard
  ///
  /// In en, this message translates to:
  /// **'Hard ({interval})'**
  String studySessionRouteHard(String interval);

  /// Swipe route badge for Good
  ///
  /// In en, this message translates to:
  /// **'Good ({interval})'**
  String studySessionRouteGood(String interval);

  /// Swipe route badge for Easy
  ///
  /// In en, this message translates to:
  /// **'Easy ({interval})'**
  String studySessionRouteEasy(String interval);

  /// Swipe route badge for Again
  ///
  /// In en, this message translates to:
  /// **'Again ({interval})'**
  String studySessionRouteAgain(String interval);

  /// Timer label in study session
  ///
  /// In en, this message translates to:
  /// **'Session Time: {time}'**
  String studySessionTimer(String time);

  /// Title on session summary page
  ///
  /// In en, this message translates to:
  /// **'Session Complete! 🎉'**
  String get sessionSummaryTitle;

  /// Subtitle on session summary page
  ///
  /// In en, this message translates to:
  /// **'Your neural pathways have been reinforced. SM-2 intervals updated.'**
  String get sessionSummarySubtitle;

  /// Stat label for reviewed cards
  ///
  /// In en, this message translates to:
  /// **'Cards Reviewed'**
  String get sessionSummaryCardsReviewed;

  /// Stat label for retention score
  ///
  /// In en, this message translates to:
  /// **'Retention Score'**
  String get sessionSummaryRetentionRate;

  /// Stat label for study duration
  ///
  /// In en, this message translates to:
  /// **'Study Duration'**
  String get sessionSummaryTimeSpent;

  /// Streak bonus announcement
  ///
  /// In en, this message translates to:
  /// **'+{xp} XP Earned · Streak Kept!'**
  String sessionSummaryStreakBonus(int xp);

  /// Button to return to dashboard
  ///
  /// In en, this message translates to:
  /// **'Return to Dashboard'**
  String get sessionSummaryReturnDashboard;

  /// Button to review another deck
  ///
  /// In en, this message translates to:
  /// **'Review More Decks'**
  String get sessionSummaryReviewAgain;

  /// Title of the Syllabot AI feature
  ///
  /// In en, this message translates to:
  /// **'Syllabot AI'**
  String get syllabotTitle;

  /// Socratic mode label for guided step-by-step reasoning
  ///
  /// In en, this message translates to:
  /// **'Step-by-Step'**
  String get socraticStepByStep;

  /// Socratic mode label for concise direct answers
  ///
  /// In en, this message translates to:
  /// **'Direct Answer'**
  String get socraticDirectAnswer;

  /// Socratic mode label for mock exam simulation
  ///
  /// In en, this message translates to:
  /// **'Exam Sim'**
  String get socraticExamSim;

  /// Socratic mode label for theoretical research breakdown
  ///
  /// In en, this message translates to:
  /// **'Deep Research'**
  String get socraticDeepResearch;

  /// Engine status label for remote Supabase LLM
  ///
  /// In en, this message translates to:
  /// **'Cloud Neural Engine'**
  String get engineCloudSupabase;

  /// Engine status label for local on-device LLM
  ///
  /// In en, this message translates to:
  /// **'Offline On-Device LLM'**
  String get engineLocalOnDevice;

  /// Snackbar text on converting chat to flashcards
  ///
  /// In en, this message translates to:
  /// **'Converted to Flashcard Deck successfully!'**
  String get convertToDeckSuccess;

  /// Input field placeholder text in Syllabot chat
  ///
  /// In en, this message translates to:
  /// **'Ask Syllabot anything (e.g. Derive Euler-Lagrange equations)...'**
  String get inputFieldPlaceholder;

  /// Status text while voice input is listening
  ///
  /// In en, this message translates to:
  /// **'Listening to your question...'**
  String get voiceInputListening;

  /// Notice when falling back to on-device LLM
  ///
  /// In en, this message translates to:
  /// **'Offline mode: Running on-device neural model.'**
  String get offlineFallbackNotice;

  /// Button label to start a new chat session
  ///
  /// In en, this message translates to:
  /// **'New Chat'**
  String get newChatSession;

  /// Header title for historical chat sessions drawer
  ///
  /// In en, this message translates to:
  /// **'Chat History'**
  String get chatSessionsHistory;

  /// Empty state label for chat sessions history
  ///
  /// In en, this message translates to:
  /// **'No chat sessions yet. Ask your first question!'**
  String get noChatSessionsFound;

  /// Title for bottom sheet converting chat to deck
  ///
  /// In en, this message translates to:
  /// **'Convert Chat to Flashcard Deck'**
  String get convertToDeckTitle;

  /// Description in convert to deck modal
  ///
  /// In en, this message translates to:
  /// **'Syllabot AI will extract key formulas, terms, and concepts into an active-recall deck.'**
  String get convertToDeckDescription;

  /// Input label for generated deck title
  ///
  /// In en, this message translates to:
  /// **'Deck Title'**
  String get deckNameLabel;

  /// Button label to generate deck
  ///
  /// In en, this message translates to:
  /// **'Generate Spaced Repetition Deck'**
  String get createDeckAction;

  /// Loading label while synthesizing flashcard deck
  ///
  /// In en, this message translates to:
  /// **'Synthesizing flashcards with AI...'**
  String get generatingDeckProgress;

  /// Button label to retry a failed message
  ///
  /// In en, this message translates to:
  /// **'Retry Response'**
  String get retryFailedMessage;

  /// A11y announcement for completed streaming
  ///
  /// In en, this message translates to:
  /// **'Syllabot response completed.'**
  String get streamingComplete;

  /// A11y announcement when engine changes
  ///
  /// In en, this message translates to:
  /// **'Switched engine to {engine}'**
  String engineSwitched(String engine);

  /// Error label when audio permission is not granted
  ///
  /// In en, this message translates to:
  /// **'Audio recording permission required'**
  String get audioInputDisabled;

  /// Confirmation prompt before clearing chat history
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear chat history?'**
  String get clearHistoryConfirmation;

  /// Confirmation button to clear
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearAction;

  /// Button label to cancel action
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;

  /// Title of the ingestion and OCR feature hub
  ///
  /// In en, this message translates to:
  /// **'Document Ingestion & OCR'**
  String get ingestionTitle;

  /// Instruction for drop zone widget
  ///
  /// In en, this message translates to:
  /// **'Drag & drop PDF, PPTX, or image files here'**
  String get dragAndDropHint;

  /// Button to open device file picker
  ///
  /// In en, this message translates to:
  /// **'Browse Files'**
  String get browseFilesButton;

  /// Button to open camera scanner overlay
  ///
  /// In en, this message translates to:
  /// **'Scan with Camera'**
  String get cameraCaptureButton;

  /// Progress message during file upload
  ///
  /// In en, this message translates to:
  /// **'Uploading document...'**
  String get uploadingStatus;

  /// Progress message during OCR processing
  ///
  /// In en, this message translates to:
  /// **'Extracting formulas & text...'**
  String get processingOcrStatus;

  /// Progress message during flashcard generation
  ///
  /// In en, this message translates to:
  /// **'Generating active recall cards...'**
  String get generatingCardsStatus;

  /// Title for the OCR preview and editor page
  ///
  /// In en, this message translates to:
  /// **'Document OCR Live Editor'**
  String get ocrPreviewTitle;

  /// Button to convert OCR snippets into cards
  ///
  /// In en, this message translates to:
  /// **'Convert to Flashcards'**
  String get saveToDecksButton;

  /// Error message when selected file format is not supported
  ///
  /// In en, this message translates to:
  /// **'Unsupported file format. Please choose a PDF, PPTX, or Image file.'**
  String get invalidFileFormatError;

  /// Footnote describing supported document types
  ///
  /// In en, this message translates to:
  /// **'Supported formats: PDF, PPTX, PNG, JPG (Max 50MB)'**
  String get supportedFormatsNotice;

  /// Count banner in OCR preview
  ///
  /// In en, this message translates to:
  /// **'{count} formulas & concepts extracted'**
  String extractedSnippetsCount(int count);

  /// Action button in OCR preview
  ///
  /// In en, this message translates to:
  /// **'Generate SM-2 Cards'**
  String get generateCardsAction;

  /// Title for generated flashcards review page
  ///
  /// In en, this message translates to:
  /// **'Review Generated Flashcards'**
  String get reviewCardsTitle;

  /// Action button to save deck and start study
  ///
  /// In en, this message translates to:
  /// **'Save & Start Study Session'**
  String get confirmAndStudyAction;

  /// Title for camera scanner viewfinder
  ///
  /// In en, this message translates to:
  /// **'Scan Study Material'**
  String get cameraScanTitle;

  /// Instruction in camera viewfinder
  ///
  /// In en, this message translates to:
  /// **'Align lecture slide or textbook page inside the frame'**
  String get cameraCaptureHint;

  /// Snackbar notice when file hash matches an existing document
  ///
  /// In en, this message translates to:
  /// **'File already indexed. Loaded existing document extractions instantly.'**
  String get contentAlreadyUploadedNotice;

  /// Label for Tier 1 Fast Local Extraction mode
  ///
  /// In en, this message translates to:
  /// **'Fast Local'**
  String get fastLocalModeTitle;

  /// Badge for Tier 1 Fast Local mode
  ///
  /// In en, this message translates to:
  /// **'FREE'**
  String get fastLocalModeBadge;

  /// Subtitle description for Fast Local mode
  ///
  /// In en, this message translates to:
  /// **'Offline, instant deterministic rule-based cards'**
  String get fastLocalModeSubtitle;

  /// Label for Tier 2 AI Smart Synthesis mode
  ///
  /// In en, this message translates to:
  /// **'AI Smart Gen'**
  String get aiSmartModeTitle;

  /// Badge for Tier 2 AI Smart Gen mode
  ///
  /// In en, this message translates to:
  /// **'PRO'**
  String get aiSmartModeBadge;

  /// Subtitle description for AI Smart Gen mode
  ///
  /// In en, this message translates to:
  /// **'Deep conceptual multi-step synthesis with diagrams'**
  String get aiSmartModeSubtitle;

  /// Stage status message when reading document on device
  ///
  /// In en, this message translates to:
  /// **'Reading document locally...'**
  String get readingDocumentLocallyStatus;

  /// Stage status message when structuring cards from extractions
  ///
  /// In en, this message translates to:
  /// **'Structuring flashcards...'**
  String get structuringFlashcardsStatus;

  /// Stage status message when syncing deck to Supabase
  ///
  /// In en, this message translates to:
  /// **'Syncing to Supabase...'**
  String get syncingToSupabaseStatus;

  /// Stage status message when sync is complete
  ///
  /// In en, this message translates to:
  /// **'Deck & flashcards synced to Supabase'**
  String get deckAndFlashcardsSyncedStatus;

  /// Stage status message when synthesizing with AI
  ///
  /// In en, this message translates to:
  /// **'Synthesizing with AI Smart Synthesis...'**
  String get aiSynthesizingStatus;

  /// Status message when extraction is ready
  ///
  /// In en, this message translates to:
  /// **'Document extraction ready'**
  String get documentExtractionReady;

  /// Label for attached diagram thumbnail
  ///
  /// In en, this message translates to:
  /// **'Attached Diagram'**
  String get attachedDiagramLabel;

  /// Label for visual diagram linked to OCR snippet
  ///
  /// In en, this message translates to:
  /// **'Visual Diagram Linked to Snippet'**
  String get visualDiagramLinkedLabel;

  /// Tooltip/hint for zooming diagram
  ///
  /// In en, this message translates to:
  /// **'Tap image to enlarge & zoom diagram'**
  String get tapToEnlargeDiagramHint;

  /// Title for interactive full-screen diagram viewer
  ///
  /// In en, this message translates to:
  /// **'Diagram Viewer'**
  String get interactiveDiagramViewerTitle;

  /// Badge label for flashcard question field
  ///
  /// In en, this message translates to:
  /// **'QUESTION'**
  String get cardQuestionBadge;

  /// Hint text for flashcard question field
  ///
  /// In en, this message translates to:
  /// **'Enter question or recall prompt...'**
  String get cardQuestionHint;

  /// Label for flashcard answer field
  ///
  /// In en, this message translates to:
  /// **'ANSWER'**
  String get cardAnswerLabel;

  /// Hint text for flashcard answer field
  ///
  /// In en, this message translates to:
  /// **'Enter answer or detailed explanation...'**
  String get cardAnswerHint;

  /// Label for LaTeX equation block editor
  ///
  /// In en, this message translates to:
  /// **'LaTeX Equation / Formula (Optional)'**
  String get cardEquationLabel;

  /// Hint text for LaTeX formula input
  ///
  /// In en, this message translates to:
  /// **'e.g. \\\\int f(x) dx or \\\\text(Risk-to-Reward) >= 3:1'**
  String get cardEquationHint;

  /// Header for live LaTeX math rendering preview
  ///
  /// In en, this message translates to:
  /// **'Live Formula Preview'**
  String get liveFormulaPreviewLabel;

  /// Header for extracted diagram visual asset box
  ///
  /// In en, this message translates to:
  /// **'Extracted Diagram / Visual Asset'**
  String get extractedVisualDiagramLabel;

  /// Title of the Community Hub
  ///
  /// In en, this message translates to:
  /// **'Community & Study Hub'**
  String get communityTitle;

  /// Label for live study rooms tab
  ///
  /// In en, this message translates to:
  /// **'Live Rooms'**
  String get liveRoomsTab;

  /// Label for track discussion forum tab
  ///
  /// In en, this message translates to:
  /// **'Track Forum'**
  String get forumTab;

  /// Label for community deck marketplace tab
  ///
  /// In en, this message translates to:
  /// **'Deck Market'**
  String get marketplaceTab;

  /// Label for streak and XP leaderboard tab
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboardTab;

  /// Button label to join a live study room
  ///
  /// In en, this message translates to:
  /// **'Join Focus Room'**
  String get joinRoomButton;

  /// Button label to clone a shared deck
  ///
  /// In en, this message translates to:
  /// **'Clone to My Decks'**
  String get cloneDeckButton;

  /// Button to create a forum post
  ///
  /// In en, this message translates to:
  /// **'Create Post'**
  String get createPostButton;

  /// Subtitle showing active participant count in room
  ///
  /// In en, this message translates to:
  /// **'{count} active peers'**
  String activeParticipantsCount(int count);

  /// Leaderboard item rank and streak badge
  ///
  /// In en, this message translates to:
  /// **'Rank #{rank} • {streak} Day Streak'**
  String dailyStreakRank(int rank, int streak);

  /// Notification when a shared deck is cloned
  ///
  /// In en, this message translates to:
  /// **'Deck cloned successfully! Added to your study space.'**
  String get deckClonedSuccessNotice;

  /// Title of live study room page
  ///
  /// In en, this message translates to:
  /// **'Synchronized Focus Room'**
  String get focusRoomTitle;

  /// Pomodoro focusing state
  ///
  /// In en, this message translates to:
  /// **'Deep Focus'**
  String get pomodoroFocus;

  /// Pomodoro break state
  ///
  /// In en, this message translates to:
  /// **'Short Break'**
  String get pomodoroBreak;

  /// Button label to leave live room
  ///
  /// In en, this message translates to:
  /// **'Leave Room'**
  String get leaveRoomButton;

  /// Title of share deck bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Share a Flashcard Deck'**
  String get shareDeckTitle;

  /// Hint for forum thread title
  ///
  /// In en, this message translates to:
  /// **'Thread title (e.g. Solving Maxwell\'s Equations...)'**
  String get postTitleHint;

  /// Hint for forum thread body
  ///
  /// In en, this message translates to:
  /// **'Describe your academic question or insight...'**
  String get postContentHint;

  /// Dropdown hint for academic track
  ///
  /// In en, this message translates to:
  /// **'Select Academic Track'**
  String get selectTrackHint;

  /// Button label to reply to forum thread
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get replyAction;

  /// Button label to upvote a thread
  ///
  /// In en, this message translates to:
  /// **'Upvote'**
  String get upvoteAction;

  /// Label for live pulse badge
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get liveIndicator;

  /// Action to raise hand in live room
  ///
  /// In en, this message translates to:
  /// **'Raise Hand'**
  String get raiseHand;

  /// Label when participant is on stage
  ///
  /// In en, this message translates to:
  /// **'On Stage'**
  String get onStage;

  /// Section header for audience in live room
  ///
  /// In en, this message translates to:
  /// **'Audience'**
  String get audienceLabel;

  /// Participant count indicator in room
  ///
  /// In en, this message translates to:
  /// **'{count} in this room'**
  String inThisRoom(int count);

  /// State when microphone is muted
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get micMuted;

  /// State when microphone is unmuted
  ///
  /// In en, this message translates to:
  /// **'Unmuted'**
  String get micUnmuted;

  /// Action to mute microphone
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get muteMicAction;

  /// Action to unmute microphone
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmuteMicAction;

  /// Notification when a participant raises their hand
  ///
  /// In en, this message translates to:
  /// **'{name} raised their hand'**
  String handRaisedNotice(String name);

  /// Header for replies section in forum thread
  ///
  /// In en, this message translates to:
  /// **'Replies'**
  String get repliesHeader;

  /// Empty state text for forum replies
  ///
  /// In en, this message translates to:
  /// **'No replies yet — be the first to help!'**
  String get noRepliesYet;

  /// Placeholder for replying to forum post
  ///
  /// In en, this message translates to:
  /// **'Write a helpful reply...'**
  String get writeHelpfulReply;

  /// Button to send reply
  ///
  /// In en, this message translates to:
  /// **'Send Reply'**
  String get sendReply;

  /// Time ago text for immediate timestamps
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// Time ago format in minutes
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String minutesAgo(int count);

  /// Time ago format in hours
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String hoursAgo(int count);

  /// Time ago format in days
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String daysAgo(int count);

  /// Label for formula block in forum
  ///
  /// In en, this message translates to:
  /// **'FORMULA / EQUATION'**
  String get formulaEquation;

  /// Leaderboard current user position highlight header
  ///
  /// In en, this message translates to:
  /// **'Your Ranking'**
  String get yourPosition;

  /// Header showing count of active focus rooms
  ///
  /// In en, this message translates to:
  /// **'Active Focus Rooms ({count})'**
  String activeFocusRooms(int count);

  /// Button to create a new study room
  ///
  /// In en, this message translates to:
  /// **'New Room'**
  String get newRoomAction;

  /// Empty state title for rooms
  ///
  /// In en, this message translates to:
  /// **'No active study rooms right now'**
  String get noActiveRooms;

  /// Button to launch a focus room
  ///
  /// In en, this message translates to:
  /// **'Launch Focus Room'**
  String get launchFocusRoom;

  /// Subtitle for empty rooms state
  ///
  /// In en, this message translates to:
  /// **'Launch a synchronized Pomodoro room for your study group.'**
  String get launchRoomSubtitle;

  /// Empty state title for forum
  ///
  /// In en, this message translates to:
  /// **'No forum discussions found'**
  String get noForumDiscussions;

  /// Empty state subtitle for forum
  ///
  /// In en, this message translates to:
  /// **'Start a question, share notes, or discuss past paper solutions.'**
  String get startQuestionSubtitle;

  /// Header showing count of shared decks
  ///
  /// In en, this message translates to:
  /// **'Community Shared Decks ({count})'**
  String communitySharedDecks(int count);

  /// Button to share a deck
  ///
  /// In en, this message translates to:
  /// **'Share Deck'**
  String get shareDeckAction;

  /// Empty state title for shared decks
  ///
  /// In en, this message translates to:
  /// **'No community decks available yet'**
  String get noDecksAvailable;

  /// Empty state subtitle for shared decks
  ///
  /// In en, this message translates to:
  /// **'Publish flashcard decks to help peers study and earn community XP.'**
  String get publishDecksSubtitle;

  /// Button to share the first deck
  ///
  /// In en, this message translates to:
  /// **'Share First Deck'**
  String get shareFirstDeck;

  /// Title on login / welcome screen
  ///
  /// In en, this message translates to:
  /// **'Welcome to Kortexify'**
  String get welcomeTitle;

  /// Subtitle on welcome screen
  ///
  /// In en, this message translates to:
  /// **'Your AI-powered adaptive study companion'**
  String get welcomeSubtitle;

  /// Prompt on onboarding track selection step
  ///
  /// In en, this message translates to:
  /// **'Select Your Focus Track'**
  String get selectCourseTrackPrompt;

  /// Description on onboarding track selection step
  ///
  /// In en, this message translates to:
  /// **'We\'ll tailor your daily active-recall intervals, exam countdowns, and mock exams to match your syllabus.'**
  String get selectCourseTrackDesc;

  /// Title for daily target cards goal
  ///
  /// In en, this message translates to:
  /// **'Daily Review Target'**
  String get dailyTargetCardGoal;

  /// Description for daily target cards goal
  ///
  /// In en, this message translates to:
  /// **'Target number of flashcards to master every day to keep your Ebbinghaus retention curve above 85%.'**
  String get dailyTargetCardGoalDesc;

  /// Label for WAEC track
  ///
  /// In en, this message translates to:
  /// **'WAEC / WASSCE'**
  String get waecTrackLabel;

  /// Description for WAEC track
  ///
  /// In en, this message translates to:
  /// **'Senior secondary school core curriculum & final exams'**
  String get waecTrackDesc;

  /// Label for JAMB track
  ///
  /// In en, this message translates to:
  /// **'JAMB / UTME'**
  String get jambTrackLabel;

  /// Description for JAMB track
  ///
  /// In en, this message translates to:
  /// **'High-speed multiple choice drills & past questions'**
  String get jambTrackDesc;

  /// Label for SAT track
  ///
  /// In en, this message translates to:
  /// **'SAT Prep'**
  String get satTrackLabel;

  /// Description for SAT track
  ///
  /// In en, this message translates to:
  /// **'Standardized math, reading, and problem solving'**
  String get satTrackDesc;

  /// Label for University track
  ///
  /// In en, this message translates to:
  /// **'University & Higher Ed'**
  String get universityTrackLabel;

  /// Description for University track
  ///
  /// In en, this message translates to:
  /// **'Sciences, humanities, engineering, and business'**
  String get universityTrackDesc;

  /// Button to finalize onboarding stepper
  ///
  /// In en, this message translates to:
  /// **'Complete Setup & Launch'**
  String get completeOnboardingButton;

  /// Generic continue button
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// Generic back button
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backButton;

  /// Step indicator in onboarding stepper
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String onboardingStepIndicator(int current, int total);

  /// Button to sign in with Google
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get signInWithGoogle;

  /// Button to sign in with Apple
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get signInWithApple;

  /// Button to send magic link
  ///
  /// In en, this message translates to:
  /// **'Send Magic Sign-In Link'**
  String get sendMagicLink;

  /// Notice after sending magic link
  ///
  /// In en, this message translates to:
  /// **'A magic sign-in link has been sent to your email.'**
  String get magicLinkSentNotice;

  /// Title of user profile page
  ///
  /// In en, this message translates to:
  /// **'Profile & Settings'**
  String get userProfileTitle;

  /// Section header for track and goal settings
  ///
  /// In en, this message translates to:
  /// **'Active Academic Track & Target'**
  String get editTrackAndGoals;

  /// Cards per day format
  ///
  /// In en, this message translates to:
  /// **'{count} cards / day'**
  String cardsPerDay(int count);

  /// Target retention percentage format
  ///
  /// In en, this message translates to:
  /// **'{percent}% Retention'**
  String retentionTarget(int percent);

  /// Button to save profile settings
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChangesButton;

  /// Snackbar notice on profile saved
  ///
  /// In en, this message translates to:
  /// **'Profile and track goals updated successfully!'**
  String get profileSavedSuccessNotice;

  /// Button label to sign out
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutButton;

  /// Confirmation message when signing out
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get signOutConfirmation;

  /// Button to switch onboarding mode to traditional form
  ///
  /// In en, this message translates to:
  /// **'Switch to Form View'**
  String get switchToFormView;

  /// Button to switch onboarding mode to conversational AI chat
  ///
  /// In en, this message translates to:
  /// **'Switch to AI Chat'**
  String get switchToChatView;

  /// Welcome message from Syllabot in conversational onboarding
  ///
  /// In en, this message translates to:
  /// **'Welcome to Kortexify! I am Syllabot, your AI Academic Guide. Let\'s calibrate your curriculum and study goals.'**
  String get onboardingChatWelcome;

  /// Title for the track selection step
  ///
  /// In en, this message translates to:
  /// **'Target Academic Track'**
  String get onboardingStepTrackTitle;

  /// Title for the daily goal calibration step
  ///
  /// In en, this message translates to:
  /// **'Daily Review Target'**
  String get onboardingStepGoalTitle;

  /// Button label to finalize onboarding and go to dashboard
  ///
  /// In en, this message translates to:
  /// **'Launch Kortexify Workspace'**
  String get completeAndGoToDashboard;

  /// Label for AI chat onboarding mode
  ///
  /// In en, this message translates to:
  /// **'AI Guide'**
  String get onboardingAiChatTitle;

  /// Label for traditional form onboarding mode
  ///
  /// In en, this message translates to:
  /// **'Form View'**
  String get onboardingFormTitle;

  /// Hint text for AI onboarding chat input
  ///
  /// In en, this message translates to:
  /// **'Type a message or question about your syllabus...'**
  String get askAiAboutCurriculum;

  /// Status text while Syllabot AI is formulating a response
  ///
  /// In en, this message translates to:
  /// **'Syllabot is preparing your personalized plan...'**
  String get aiThinking;

  /// Notification title when a peer community is auto-created
  ///
  /// In en, this message translates to:
  /// **'We auto-created the {courseCode} Community Hub!'**
  String autoCommunityCreatedTitle(String courseCode);

  /// Subtitle showing active peer count in the newly joined community
  ///
  /// In en, this message translates to:
  /// **'{count} peers are currently studying this material.'**
  String autoCommunityJoinedSubtitle(int count);

  /// Badge shown for users who are first to study a topic or track
  ///
  /// In en, this message translates to:
  /// **'Founding Member 🌟'**
  String get foundingMemberBadge;

  /// Action button to view peer discussion forum
  ///
  /// In en, this message translates to:
  /// **'View Peer Discussion'**
  String get viewPeerDiscussion;

  /// Action button to navigate to community hub
  ///
  /// In en, this message translates to:
  /// **'Open Hub'**
  String get openCommunityHub;

  /// Label for quick join study room chip
  ///
  /// In en, this message translates to:
  /// **'Quick Join Focus Room'**
  String get quickJoinStudyRoom;

  /// Active participants indicator in focus room chip
  ///
  /// In en, this message translates to:
  /// **'{count} peers studying now'**
  String activeRoomPeers(int count);

  /// Peer hub title with course code
  ///
  /// In en, this message translates to:
  /// **'{courseCode} Peer Hub'**
  String peerHubTitle(String courseCode);

  /// Count of peers connected in study hub
  ///
  /// In en, this message translates to:
  /// **'{count} Active Peers'**
  String connectedPeersCount(int count);

  /// Status text while generating vector embeddings for document chunks
  ///
  /// In en, this message translates to:
  /// **'Indexing course material into neural vector memory...'**
  String get indexingDocumentProgress;

  /// Notice showing count of matched document chunks for Syllabot
  ///
  /// In en, this message translates to:
  /// **'Found {count} relevant textbook sections.'**
  String ragContextFoundNotice(int count);

  /// Badge showing semantic similarity match score for retrieved chunk
  ///
  /// In en, this message translates to:
  /// **'Verified Course Context ({score}% Match)'**
  String retrievedContextBadge(int score);

  /// Hint shown over live camera OCR frame
  ///
  /// In en, this message translates to:
  /// **'Align textbook or lecture note text within frame'**
  String get alignCameraTextHint;

  /// Notice when OCR is executed on-device offline
  ///
  /// In en, this message translates to:
  /// **'Processed locally. Will sync with LaTeX AI when online.'**
  String get offlineOcrProcessedNotice;

  /// Badge showing number of queued OCR items waiting for cloud sync
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item pending sync} other{{count} items pending sync}}'**
  String syncPendingCount(int count);

  /// Toast when offline sync queue completes
  ///
  /// In en, this message translates to:
  /// **'Cloud sync and LaTeX enhancement complete'**
  String get syncCompletedNotice;

  /// Label for predicted memory retention curve in dashboard chart
  ///
  /// In en, this message translates to:
  /// **'Predicted Retention (FSRS-4.5)'**
  String get predictedRetentionLabel;

  /// Label for actual measured retention curve in dashboard chart
  ///
  /// In en, this message translates to:
  /// **'Actual Recall Rate'**
  String get actualRetentionLabel;

  /// Description of FSRS-4.5 scheduler
  ///
  /// In en, this message translates to:
  /// **'Adaptive Stability & Difficulty decay modeling for optimal study load'**
  String get fsrsModeDescription;

  /// Description of classical SM-2 scheduler
  ///
  /// In en, this message translates to:
  /// **'Classical SuperMemo-2 interval and ease factor spacing'**
  String get sm2ModeDescription;

  /// Title of spaced repetition algorithm settings section
  ///
  /// In en, this message translates to:
  /// **'Spaced Repetition Scheduler'**
  String get schedulerAlgorithmTitle;

  /// Title for 7-day review workload card
  ///
  /// In en, this message translates to:
  /// **'7-Day Projected Review Workload'**
  String get projectedWorkloadTitle;

  /// Status banner text while voice microphone is recording
  ///
  /// In en, this message translates to:
  /// **'Listening... Speak your academic question clearly'**
  String get listeningVoiceInput;

  /// Button tooltip to stop TTS audio output
  ///
  /// In en, this message translates to:
  /// **'Stop audio narration'**
  String get stopAudioPlayback;

  /// Button label for TTS audio speed
  ///
  /// In en, this message translates to:
  /// **'{speed}x Speed'**
  String speechSpeedLabel(String speed);

  /// Hint text when microphone is ready
  ///
  /// In en, this message translates to:
  /// **'Tap microphone to speak'**
  String get tapToSpeakHint;

  /// Button label to trigger text to speech audio
  ///
  /// In en, this message translates to:
  /// **'Read Aloud'**
  String get readAloudLabel;

  /// Exam countdown banner days remaining
  ///
  /// In en, this message translates to:
  /// **'{count} days until {examName}'**
  String daysUntilExam(int count, String examName);

  /// Daily cram target calculation label
  ///
  /// In en, this message translates to:
  /// **'Target pace: {count} cards/day'**
  String recommendedDailyPace(int count);

  /// Header title for adding an exam countdown
  ///
  /// In en, this message translates to:
  /// **'Add Exam Countdown'**
  String get addExamTitle;

  /// Input field label for exam title
  ///
  /// In en, this message translates to:
  /// **'Exam Name'**
  String get examNameLabel;

  /// Input field label for exam date
  ///
  /// In en, this message translates to:
  /// **'Target Exam Date'**
  String get targetDateLabel;

  /// Input field label for exam subject or track
  ///
  /// In en, this message translates to:
  /// **'Subject / Track'**
  String get examSubjectLabel;

  /// Submit button for saving exam countdown
  ///
  /// In en, this message translates to:
  /// **'Save Exam Countdown'**
  String get saveExamCountdown;

  /// Title of the quiz workspace view
  ///
  /// In en, this message translates to:
  /// **'Practice Quiz & Mock Exam'**
  String get quizTitle;

  /// Progress of current question in quiz
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String quizQuestionProgress(int current, int total);

  /// Score percentage label on results screen
  ///
  /// In en, this message translates to:
  /// **'Your Score: {score}%'**
  String quizScoreLabel(int score);

  /// Button to review flashcards for weak sub-topics
  ///
  /// In en, this message translates to:
  /// **'Practice Weak Flashcards'**
  String get practiceWeakCards;

  /// Accordion header for question solution
  ///
  /// In en, this message translates to:
  /// **'Explanation & Solution'**
  String get quizExplanationTitle;

  /// Button label to submit and finalize quiz
  ///
  /// In en, this message translates to:
  /// **'Submit Quiz'**
  String get submitQuizButton;

  /// Button label to advance to next question
  ///
  /// In en, this message translates to:
  /// **'Next Question'**
  String get nextQuestionButton;

  /// Header title for topic weakness analysis
  ///
  /// In en, this message translates to:
  /// **'Weak Areas by Sub-Topic'**
  String get quizTopicWeakness;

  /// Time counter for quiz
  ///
  /// In en, this message translates to:
  /// **'Time: {time}'**
  String quizTimeRemaining(String time);

  /// Title for the multi-format export sheet
  ///
  /// In en, this message translates to:
  /// **'Export Flashcard Deck'**
  String get exportDeckTitle;

  /// Option title for Anki export
  ///
  /// In en, this message translates to:
  /// **'Anki Package (.apkg / .csv)'**
  String get exportAnkiTitle;

  /// Option description for Anki export
  ///
  /// In en, this message translates to:
  /// **'Import into Anki Desktop & Mobile with full LaTeX formatting'**
  String get exportAnkiSubtitle;

  /// Option title for Printable PDF export
  ///
  /// In en, this message translates to:
  /// **'Printable Double-Sided Sheet (PDF)'**
  String get exportPdfTitle;

  /// Option description for Printable PDF export
  ///
  /// In en, this message translates to:
  /// **'Print-ready A4 with 8 cards per page for physical study'**
  String get exportPdfSubtitle;

  /// Option title for Notion CSV export
  ///
  /// In en, this message translates to:
  /// **'Notion Database (CSV)'**
  String get exportNotionTitle;

  /// Option description for Notion CSV export
  ///
  /// In en, this message translates to:
  /// **'Import directly into your Notion workspace study database'**
  String get exportNotionSubtitle;

  /// Loading state message when preparing export files
  ///
  /// In en, this message translates to:
  /// **'Generating export file...'**
  String get exportingFile;

  /// Success message when file is ready for share/save
  ///
  /// In en, this message translates to:
  /// **'Deck exported successfully!'**
  String get exportSuccess;

  /// Title for annual study activity heatmap
  ///
  /// In en, this message translates to:
  /// **'Study Activity & Consistency'**
  String get studyActivityHeatmapTitle;

  /// Tooltip showing review count for a specific date in heatmap
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No reviews} =1{1 card reviewed} other{{count} cards reviewed}} on {date}'**
  String heatmapCardReviewsCount(int count, String date);

  /// Badge showing streak freeze active status
  ///
  /// In en, this message translates to:
  /// **'Streak Freeze Available'**
  String get streakFreezeAvailable;

  /// Description of active streak freeze protection
  ///
  /// In en, this message translates to:
  /// **'Your daily streak is protected against 1 missed day.'**
  String get streakFreezeActiveDesc;

  /// Button to purchase streak freeze using earned XP
  ///
  /// In en, this message translates to:
  /// **'Equip Streak Shield (200 XP)'**
  String get buyStreakFreezeButton;

  /// Success notification on equipping streak freeze
  ///
  /// In en, this message translates to:
  /// **'Streak Shield equipped! 1 missed day is now protected.'**
  String get streakFreezeSuccess;

  /// Error when user does not have enough XP for freeze
  ///
  /// In en, this message translates to:
  /// **'You need 200 XP to equip a Streak Shield.'**
  String get insufficientXpForFreeze;

  /// Title for achievements badge grid
  ///
  /// In en, this message translates to:
  /// **'Earned Badges & Milestones'**
  String get achievementsGridTitle;

  /// Badge title for late night study sessions
  ///
  /// In en, this message translates to:
  /// **'Night Owl'**
  String get badgeNightOwlTitle;

  /// Badge description for Night Owl
  ///
  /// In en, this message translates to:
  /// **'Completed 5 review sessions between 11 PM and 4 AM.'**
  String get badgeNightOwlDesc;

  /// Badge title for 100 card review day
  ///
  /// In en, this message translates to:
  /// **'Century Club'**
  String get badgeCenturyClubTitle;

  /// Badge description for Century Club
  ///
  /// In en, this message translates to:
  /// **'Reviewed 100+ cards in a single study day.'**
  String get badgeCenturyClubDesc;

  /// Badge title for 14 day study streak
  ///
  /// In en, this message translates to:
  /// **'Streak Master'**
  String get badgeStreakMasterTitle;

  /// Badge description for Streak Master
  ///
  /// In en, this message translates to:
  /// **'Maintained an unbroken 14-day study streak.'**
  String get badgeStreakMasterDesc;

  /// Badge title for solving 50 formula cards
  ///
  /// In en, this message translates to:
  /// **'Master Scholar'**
  String get badgeStemAlchemistTitle;

  /// Badge description for Master Scholar
  ///
  /// In en, this message translates to:
  /// **'Mastered 50 complex concept or subject cards.'**
  String get badgeStemAlchemistDesc;

  /// Notice when offline on a low-memory device unable to run local GGUF models
  ///
  /// In en, this message translates to:
  /// **'Cloud connection required for deep AI reasoning on this device.'**
  String get offlineLowMemoryNotice;

  /// Label for Cloud Edge execution mode
  ///
  /// In en, this message translates to:
  /// **'Cloud Edge Accelerated'**
  String get hardwareCloudEdgeMode;

  /// Label for Local GGUF execution mode
  ///
  /// In en, this message translates to:
  /// **'On-Device Neural Engine'**
  String get hardwareLocalGgufMode;

  /// Label for MLKit only execution mode
  ///
  /// In en, this message translates to:
  /// **'Lightweight OCR Only'**
  String get hardwareMlKitOnlyMode;

  /// Notice when thermal throttling is active
  ///
  /// In en, this message translates to:
  /// **'Thermal throttling active. Heavy local AI tasks disabled to protect device.'**
  String get hardwareThermalThrottled;

  /// Notice when low battery triggers cloud fallback
  ///
  /// In en, this message translates to:
  /// **'Battery saving active. Routing AI queries to Cloud Edge.'**
  String get hardwareBatterySavingActive;

  /// Title for past examination questions CBT board page
  ///
  /// In en, this message translates to:
  /// **'Past Questions Bank'**
  String get pastQuestionsBankTitle;

  /// Counter badge for answered questions
  ///
  /// In en, this message translates to:
  /// **'{answered}/{total} Done'**
  String pastQuestionsProgressDone(int answered, int total);

  /// Placeholder for past questions search input
  ///
  /// In en, this message translates to:
  /// **'Search past questions by topic or keyword...'**
  String get pastQuestionsSearchHint;

  /// Loading message when fetching questions
  ///
  /// In en, this message translates to:
  /// **'Loading past examination questions...'**
  String get pastQuestionsLoading;

  /// Title for empty question filter results
  ///
  /// In en, this message translates to:
  /// **'No questions found for this filter'**
  String get pastQuestionsEmptyTitle;

  /// Guidance message when no questions match the selected filter
  ///
  /// In en, this message translates to:
  /// **'Try selecting another subject or year to continue practicing.'**
  String get pastQuestionsEmptyDesc;

  /// Header for step-by-step question explanation
  ///
  /// In en, this message translates to:
  /// **'Explanation & Concept'**
  String get pastQuestionsExplanationTitle;

  /// Button to trigger Socratic AI explanation for a past question
  ///
  /// In en, this message translates to:
  /// **'Explain with Syllabot AI'**
  String get pastQuestionsAskSyllabot;

  /// Speed dial action tile label for Question Bank
  ///
  /// In en, this message translates to:
  /// **'Q-Bank'**
  String get dashboardQBankAction;

  /// Toast message when copying text to clipboard
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// Notice when restore purchases finds no active subscription
  ///
  /// In en, this message translates to:
  /// **'No active Pro subscription found to restore.'**
  String get paywallRestoreNoSub;

  /// Notice when restore purchases successfully restores Pro
  ///
  /// In en, this message translates to:
  /// **'Kortexify Pro subscription successfully restored!'**
  String get paywallRestoreSuccess;

  /// Snack message for generation note error
  ///
  /// In en, this message translates to:
  /// **'Generation note: {error}'**
  String offlineGenNote(String error);

  /// Dropdown label for WAEC track
  ///
  /// In en, this message translates to:
  /// **'WAEC Track'**
  String get examTrackWaecStem;

  /// Dropdown label for JAMB track
  ///
  /// In en, this message translates to:
  /// **'JAMB UTME'**
  String get examTrackJambUtme;

  /// Dropdown label for SAT track
  ///
  /// In en, this message translates to:
  /// **'SAT Digital'**
  String get examTrackSatDigital;

  /// Dropdown label for University track
  ///
  /// In en, this message translates to:
  /// **'University Track'**
  String get examTrackUniversityStem;

  /// App bar title for onboarding wrapper
  ///
  /// In en, this message translates to:
  /// **'Kortexify Onboarding'**
  String get onboardingAppBarTitle;

  /// Retry button for quiz workspace
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get quizRetryButton;

  /// Error fallback message when quiz fails to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load quiz'**
  String get quizFailedToLoad;

  /// Divider text separating social sign in from email
  ///
  /// In en, this message translates to:
  /// **'or email'**
  String get authOrEmail;

  /// Toggle to switch to magic link auth
  ///
  /// In en, this message translates to:
  /// **'Use Magic Link instead'**
  String get authUseMagicLinkInstead;

  /// Toggle to switch to password auth
  ///
  /// In en, this message translates to:
  /// **'Use password instead'**
  String get authUsePasswordInstead;

  /// Restore purchases button on paywall
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get paywallRestore;

  /// Action button to study now
  ///
  /// In en, this message translates to:
  /// **'Study Now'**
  String get studyNowAction;

  /// Button to add a marketplace review
  ///
  /// In en, this message translates to:
  /// **'Add Review'**
  String get marketplaceAddReview;

  /// Notification when deck clone succeeds
  ///
  /// In en, this message translates to:
  /// **'Deck cloned successfully!'**
  String get marketplaceCloneSuccess;

  /// Notification when deck clone fails
  ///
  /// In en, this message translates to:
  /// **'Failed to clone deck'**
  String get marketplaceCloneFailed;

  /// Validation message when rating is missing
  ///
  /// In en, this message translates to:
  /// **'Please select a rating and enter a comment'**
  String get marketplaceRatingRequired;

  /// Success message when review is submitted
  ///
  /// In en, this message translates to:
  /// **'Review submitted successfully!'**
  String get marketplaceReviewSubmitted;

  /// Success message for offline flashcard generation
  ///
  /// In en, this message translates to:
  /// **'Flashcards generated successfully!'**
  String get offlineGenSuccess;

  /// Error message for offline flashcard generation
  ///
  /// In en, this message translates to:
  /// **'Failed to generate flashcards'**
  String get offlineGenFailed;

  /// Hint for offline topic input
  ///
  /// In en, this message translates to:
  /// **'Enter study topic, lecture notes, or syllabus section...'**
  String get offlineGenPromptHint;

  /// Hint for offline deck title input
  ///
  /// In en, this message translates to:
  /// **'e.g. Calculus II - Integration Techniques'**
  String get offlineGenDeckTitleHint;

  /// Label for exam title input in modal
  ///
  /// In en, this message translates to:
  /// **'Exam Title'**
  String get examModalExamTitle;

  /// Hint for exam title input in modal
  ///
  /// In en, this message translates to:
  /// **'e.g., WAEC Further Mathematics'**
  String get examModalExamTitleHint;

  /// Label for target score input in modal
  ///
  /// In en, this message translates to:
  /// **'Target Score (%)'**
  String get examModalTargetScore;

  /// Hint for target score input in modal
  ///
  /// In en, this message translates to:
  /// **'85'**
  String get examModalTargetScoreHint;

  /// Label for exam date picker in modal
  ///
  /// In en, this message translates to:
  /// **'Exam Date'**
  String get examModalExamDate;

  /// Button to add exam countdown
  ///
  /// In en, this message translates to:
  /// **'Add Exam Countdown'**
  String get examModalAddButton;

  /// Hint for convert to deck title field
  ///
  /// In en, this message translates to:
  /// **'Deck Title'**
  String get convertDeckTitleHint;

  /// Hint for convert to deck description field
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get convertDeckDescHint;

  /// Error message when restore purchases fails
  ///
  /// In en, this message translates to:
  /// **'Restore error: {error}'**
  String restoreErrorPrefix(String error);

  /// Link text for Privacy Policy
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Link text for Terms of Service
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// Link text for Terms of Use / EULA
  ///
  /// In en, this message translates to:
  /// **'Terms of Use (EULA)'**
  String get termsOfUseEula;

  /// Title for Socratic reasoning mode bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Socratic Reasoning Mode'**
  String get socraticModeSheetTitle;

  /// Subtitle for Socratic reasoning mode bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Select how Syllabot structures your academic explanations'**
  String get socraticModeSheetSubtitle;

  /// Label for step by step mode
  ///
  /// In en, this message translates to:
  /// **'Step-by-Step Proof'**
  String get socraticModeStepByStepLabel;

  /// Description for step by step mode
  ///
  /// In en, this message translates to:
  /// **'Walk through the problem step-by-step from first principles'**
  String get socraticModeStepByStepDesc;

  /// Short label for step by step mode
  ///
  /// In en, this message translates to:
  /// **'Step-by-Step'**
  String get socraticModeStepByStepShort;

  /// Label for direct answer mode
  ///
  /// In en, this message translates to:
  /// **'Direct Answer'**
  String get socraticModeDirectAnswerLabel;

  /// Description for direct answer mode
  ///
  /// In en, this message translates to:
  /// **'Get a concise, comprehensive answer immediately'**
  String get socraticModeDirectAnswerDesc;

  /// Short label for direct answer mode
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get socraticModeDirectAnswerShort;

  /// Label for exam simulator mode
  ///
  /// In en, this message translates to:
  /// **'Exam Simulator'**
  String get socraticModeExamSimLabel;

  /// Description for exam simulator mode
  ///
  /// In en, this message translates to:
  /// **'Simulate an exam scenario with mark breakdowns'**
  String get socraticModeExamSimDesc;

  /// Short label for exam simulator mode
  ///
  /// In en, this message translates to:
  /// **'Exam Sim'**
  String get socraticModeExamSimShort;

  /// Label for deep research mode
  ///
  /// In en, this message translates to:
  /// **'Deep Research'**
  String get socraticModeDeepResearchLabel;

  /// Description for deep research mode
  ///
  /// In en, this message translates to:
  /// **'Explore deep theoretical proofs and edge cases'**
  String get socraticModeDeepResearchDesc;

  /// Short label for deep research mode
  ///
  /// In en, this message translates to:
  /// **'Research'**
  String get socraticModeDeepResearchShort;

  /// Label for female voice
  ///
  /// In en, this message translates to:
  /// **'Female Voice'**
  String get voiceGenderFemale;

  /// Label for male voice
  ///
  /// In en, this message translates to:
  /// **'Male Voice'**
  String get voiceGenderMale;

  /// Status text while voice dialogue is listening
  ///
  /// In en, this message translates to:
  /// **'Listening to your question...'**
  String get voiceDialogueListening;

  /// Status text while Syllabot is thinking
  ///
  /// In en, this message translates to:
  /// **'Syllabot is thinking...'**
  String get voiceDialogueThinking;

  /// Status text while Syllabot is speaking
  ///
  /// In en, this message translates to:
  /// **'Syllabot is speaking...'**
  String get voiceDialogueSpeaking;

  /// Button text to speak in voice dialogue
  ///
  /// In en, this message translates to:
  /// **'Tap to Speak'**
  String get voiceDialogueTapToSpeak;

  /// Button text when student is done speaking
  ///
  /// In en, this message translates to:
  /// **'Done Speaking'**
  String get voiceDialogueDoneSpeaking;

  /// Tooltip to read message aloud
  ///
  /// In en, this message translates to:
  /// **'Read aloud'**
  String get syllabotReadAloud;

  /// Tooltip to stop reading message
  ///
  /// In en, this message translates to:
  /// **'Stop reading'**
  String get syllabotStopReading;

  /// Tooltip for voice dialogue mode
  ///
  /// In en, this message translates to:
  /// **'Voice Dialogue Mode'**
  String get voiceDialogueModeTooltip;

  /// Subtitle on Syllabot empty greeting
  ///
  /// In en, this message translates to:
  /// **'Your 24/7 AI tutor for concept derivations, exam prep, and flashcards'**
  String get syllabotEmptySubtitle;

  /// Success message when deck created from Syllabot
  ///
  /// In en, this message translates to:
  /// **'Flashcard Deck \"{title}\" created with {count} cards!'**
  String deckCreatedFromSyllabot(String title, int count);

  /// Error banner message when generation fails
  ///
  /// In en, this message translates to:
  /// **'Unable to generate response. Check connection.'**
  String get unableToGenerateResponse;

  /// Retry action button text
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryAction;

  /// Floating overlay pill text
  ///
  /// In en, this message translates to:
  /// **'Ask Syllabot'**
  String get askSyllabotPill;

  /// Tooltip for minimizing chat
  ///
  /// In en, this message translates to:
  /// **'Minimize Chat'**
  String get minimizeChatTooltip;

  /// Tooltip for starting new conversation
  ///
  /// In en, this message translates to:
  /// **'New Conversation'**
  String get newConversationTooltip;

  /// Title for app preferences page
  ///
  /// In en, this message translates to:
  /// **'App & Sensory Settings'**
  String get preferencesTitle;

  /// Appearance section title
  ///
  /// In en, this message translates to:
  /// **'Color Appearance'**
  String get preferencesAppearanceTitle;

  /// Appearance section subtitle
  ///
  /// In en, this message translates to:
  /// **'Switch between sleek dark mode, clear light mode, or sync with system'**
  String get preferencesAppearanceSubtitle;

  /// System theme option
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get preferencesThemeSystem;

  /// Light theme option
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get preferencesThemeLight;

  /// Dark theme option
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get preferencesThemeDark;

  /// Sensory section title
  ///
  /// In en, this message translates to:
  /// **'Sensory & Audio Experience'**
  String get preferencesSensoryTitle;

  /// Sensory section subtitle
  ///
  /// In en, this message translates to:
  /// **'Tactile vibrations and audio cues during study'**
  String get preferencesSensorySubtitle;

  /// Haptics switch title
  ///
  /// In en, this message translates to:
  /// **'Haptic Feedback'**
  String get preferencesHapticsTitle;

  /// Haptics switch subtitle
  ///
  /// In en, this message translates to:
  /// **'Vibrate on card flip & quiz grading'**
  String get preferencesHapticsSubtitle;

  /// Sound effects switch title
  ///
  /// In en, this message translates to:
  /// **'Sound Effects (SFX)'**
  String get preferencesSfxTitle;

  /// Sound effects switch subtitle
  ///
  /// In en, this message translates to:
  /// **'Play audio cues on correct answers'**
  String get preferencesSfxSubtitle;

  /// Notifications section title
  ///
  /// In en, this message translates to:
  /// **'Notifications & Streak Protections'**
  String get preferencesNotificationsTitle;

  /// Notifications section subtitle
  ///
  /// In en, this message translates to:
  /// **'Daily reminders so you never break your study habit'**
  String get preferencesNotificationsSubtitle;

  /// Reminder switch title
  ///
  /// In en, this message translates to:
  /// **'Daily Study Reminder'**
  String get preferencesReminderTitle;

  /// Reminder switch subtitle
  ///
  /// In en, this message translates to:
  /// **'Alert 1 hour before streak reset (8:00 PM)'**
  String get preferencesReminderSubtitle;

  /// Delete deck confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Study Deck'**
  String get deleteStudyDeckTitle;

  /// Delete deck confirmation dialog message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{title}\" and its {count} cards? This action cannot be undone.'**
  String deleteStudyDeckDesc(String title, int count);

  /// Button label to confirm deck deletion
  ///
  /// In en, this message translates to:
  /// **'Delete Deck'**
  String get deleteDeckAction;

  /// Title for the welcome walkthrough dialog
  ///
  /// In en, this message translates to:
  /// **'Welcome to Kortexify!'**
  String get welcomeWalkthroughTitle;

  /// Subtitle for the welcome walkthrough dialog
  ///
  /// In en, this message translates to:
  /// **'Your AI-augmented academic workspace is ready'**
  String get welcomeWalkthroughSubtitle;

  /// Title for slide 1 of welcome walkthrough
  ///
  /// In en, this message translates to:
  /// **'Instant Ingestion & Active Recall'**
  String get welcomeWalkthroughSlide1Title;

  /// Description for slide 1 of welcome walkthrough
  ///
  /// In en, this message translates to:
  /// **'Drop any syllabus, lecture slide, textbook PDF, or past questions to instantly generate high-yield active-recall cards.'**
  String get welcomeWalkthroughSlide1Desc;

  /// Title for slide 2 of welcome walkthrough
  ///
  /// In en, this message translates to:
  /// **'Syllabot AI Contextual Tutor'**
  String get welcomeWalkthroughSlide2Title;

  /// Description for slide 2 of welcome walkthrough
  ///
  /// In en, this message translates to:
  /// **'Chat directly with your course materials. Syllabot breaks down complex STEM proofs, equations, and key test topics.'**
  String get welcomeWalkthroughSlide2Desc;

  /// Title for slide 3 of welcome walkthrough
  ///
  /// In en, this message translates to:
  /// **'Adaptive Spaced Repetition (SM-2)'**
  String get welcomeWalkthroughSlide3Title;

  /// Description for slide 3 of welcome walkthrough
  ///
  /// In en, this message translates to:
  /// **'Keep retention high with daily reviews, custom cram schedules, and smart retention heatmaps calibrated to your target track.'**
  String get welcomeWalkthroughSlide3Desc;

  /// Title for slide 4 of welcome walkthrough
  ///
  /// In en, this message translates to:
  /// **'Collaborative Study Hub & Live Rooms'**
  String get welcomeWalkthroughSlide4Title;

  /// Description for slide 4 of welcome walkthrough
  ///
  /// In en, this message translates to:
  /// **'Join live study rooms, speak with peers, ask questions in community forums, and climb academic leaderboards together.'**
  String get welcomeWalkthroughSlide4Desc;

  /// Next button in walkthrough
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get welcomeWalkthroughNext;

  /// Previous button in walkthrough
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get welcomeWalkthroughPrevious;

  /// Get started / finish button in walkthrough
  ///
  /// In en, this message translates to:
  /// **'Enter Workspace'**
  String get welcomeWalkthroughGetStarted;

  /// Skip button in walkthrough
  ///
  /// In en, this message translates to:
  /// **'Skip Walkthrough'**
  String get welcomeWalkthroughSkip;

  /// Title for toggle to create forum for a deck
  ///
  /// In en, this message translates to:
  /// **'Generate Community Study Forum'**
  String get deckCreateForumTitle;

  /// Subtitle for toggle to create forum for a deck
  ///
  /// In en, this message translates to:
  /// **'Create an open discussion forum for this deck'**
  String get deckCreateForumSubtitle;

  /// Consequence note discouraging forum generation alongside study deck
  ///
  /// In en, this message translates to:
  /// **'Note: Generating a campus forum makes this study deck discoverable to other students. As creator, you\'ll be responsible for answering peer queries and moderating discussions. For distraction-free solo mastery, keeping this disabled is recommended — but the option is yours!'**
  String get deckCreateForumWarning;

  /// Notice that a deck was already generated from current chat
  ///
  /// In en, this message translates to:
  /// **'A study deck has already been synthesized from this conversation.'**
  String get deckAlreadyGeneratedFromChat;

  /// Action prompt on deck created snackbar
  ///
  /// In en, this message translates to:
  /// **'Tap to open study deck'**
  String get deckTapToView;

  /// Title for LMS import tile
  ///
  /// In en, this message translates to:
  /// **'Import from LMS'**
  String get decksImportLmsTitle;

  /// Subtitle for LMS import tile
  ///
  /// In en, this message translates to:
  /// **'Sync course syllabi & assignments from Google Classroom or Canvas.'**
  String get decksImportLmsSubtitle;

  /// Illusion status 1 during deduplication
  ///
  /// In en, this message translates to:
  /// **'Analyzing document structure...'**
  String get dedupSynthesisAnalyzing;

  /// Illusion status 2 during deduplication
  ///
  /// In en, this message translates to:
  /// **'Synthesizing formulas and definitions...'**
  String get dedupSynthesisExtracting;

  /// Illusion status 3 during deduplication
  ///
  /// In en, this message translates to:
  /// **'Finalizing active-recall flashcards...'**
  String get dedupSynthesisCompiling;

  /// Success note when assigning deduplicated deck
  ///
  /// In en, this message translates to:
  /// **'Assigned existing verified deck to your workspace'**
  String get dedupExistingDeckAssigned;

  /// Rocket launch sequence ignited
  ///
  /// In en, this message translates to:
  /// **'Ignition sequence started!'**
  String get launchSequenceIgnited;

  /// Warp drive engaged status banner
  ///
  /// In en, this message translates to:
  /// **'WARP DRIVE ENGAGED'**
  String get warpDriveEngaged;

  /// Hint for interactive flight control
  ///
  /// In en, this message translates to:
  /// **'Drag to steer • Tap for turbo boost'**
  String get launchSteerHint;

  /// Orbit reached notification
  ///
  /// In en, this message translates to:
  /// **'Orbit Reached!'**
  String get launchOrbitReached;

  /// Turbo boost trigger banner
  ///
  /// In en, this message translates to:
  /// **'TURBO BOOST!'**
  String get launchTurboBoost;

  /// Mach speed counter
  ///
  /// In en, this message translates to:
  /// **'Mach {speed}'**
  String launchMachSpeed(String speed);

  /// Transition to workspace
  ///
  /// In en, this message translates to:
  /// **'Entering Kortexify Workspace...'**
  String get launchEnteringWorkspace;

  /// Google Classroom OAuth CTA
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google Classroom'**
  String get lmsConnectWithGoogleClassroom;

  /// Canvas OAuth CTA
  ///
  /// In en, this message translates to:
  /// **'Connect with Canvas LMS'**
  String get lmsConnectWithCanvas;

  /// OAuth 2.0 PKCE security notice
  ///
  /// In en, this message translates to:
  /// **'Secured with OAuth 2.0 PKCE. Your campus credentials and passwords are never stored.'**
  String get lmsOAuthSecureNotice;

  /// Connected student profile
  ///
  /// In en, this message translates to:
  /// **'Connected as {email}'**
  String lmsConnectedAsStudent(String email);

  /// Authorize button for LMS OAuth
  ///
  /// In en, this message translates to:
  /// **'Authorize & Connect'**
  String get lmsAuthorizeAndConnect;

  /// Cancel button for LMS OAuth
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get lmsCancel;

  /// Disconnect account button
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get lmsDisconnect;

  /// Select institution header
  ///
  /// In en, this message translates to:
  /// **'Select Institution'**
  String get lmsSelectInstitution;

  /// Custom Canvas URL label
  ///
  /// In en, this message translates to:
  /// **'Custom Canvas URL'**
  String get lmsCustomDomain;

  /// Permissions notice for LMS
  ///
  /// In en, this message translates to:
  /// **'Kortexify will request read-only access to view your enrolled courses, modules, syllabi, and upcoming assignments to synthesize flashcards.'**
  String get lmsPermissionsNotice;

  /// Connecting OAuth status
  ///
  /// In en, this message translates to:
  /// **'Authorizing with {provider}...'**
  String lmsOAuthConnecting(String provider);

  /// OAuth success message
  ///
  /// In en, this message translates to:
  /// **'Successfully authenticated! Loading enrolled courses...'**
  String get lmsOAuthSuccess;
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

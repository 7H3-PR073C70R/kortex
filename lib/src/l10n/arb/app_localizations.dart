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
  /// **'Hi Stranger! 👋 Welcome to Kortex.\n\n✨ \"The beautiful thing about learning is that no one can take it away from you.\" — B.B. King\n\nI\'m Syllabot, your AI study partner. How would you like to get started today?'**
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
  /// **'Welcome to Kortex!'**
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
  /// **'Ingest syllabi, STEM equations, and lecture slides into an active-recall mastery system in seconds.'**
  String get authDesktopHeroSubtitle;

  /// Hero bullet feature 1
  ///
  /// In en, this message translates to:
  /// **'Zero-latency multimodal STEM OCR'**
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

  /// Prompt asking for goals in chat mode
  ///
  /// In en, this message translates to:
  /// **'Perfect. How can Kortex best support you right now?'**
  String get calibrationChatGoalPrompt;

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
  /// **'Calibrate & Launch Kortex'**
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
  /// **'How can Kortex best support you right now?'**
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
  /// **'Deep-Dive STEM Socratic AI'**
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
  /// **'Curriculum-Specific STEM Prompts'**
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
  /// **'Zero blank pages. We\'ve pre-seeded your library with verified past exams, adaptive STEM decks, and automated Socratic dialogue channels.'**
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
  /// **'Email verified successfully. Welcome to Kortex!'**
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
  /// **'Enable Key Features'**
  String get permissionsTitle;

  /// Subtitle on permissions page
  ///
  /// In en, this message translates to:
  /// **'Allow Kortex to send you study reminders and scan your documents for instant AI indexing.'**
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
  /// **'Drop lecture slides, PDFs or handwritten past papers. Syllabot will parse STEM OCR & generate flashcards.'**
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

  /// STEM OCR subtitle
  ///
  /// In en, this message translates to:
  /// **'STEM OCR'**
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
  /// **'Syllabot AI will extract key STEM formulas, terms, and concepts into an active-recall deck.'**
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

  /// Cancel action
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
  /// **'Extracting STEM formulas & LaTeX...'**
  String get processingOcrStatus;

  /// Progress message during flashcard generation
  ///
  /// In en, this message translates to:
  /// **'Generating active recall cards...'**
  String get generatingCardsStatus;

  /// Title for the OCR preview and editor page
  ///
  /// In en, this message translates to:
  /// **'STEM OCR Live Editor'**
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
  /// **'File already indexed. Loaded existing STEM extractions instantly.'**
  String get contentAlreadyUploadedNotice;

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

  /// Title on login / welcome screen
  ///
  /// In en, this message translates to:
  /// **'Welcome to Kortex'**
  String get welcomeTitle;

  /// Subtitle on welcome screen
  ///
  /// In en, this message translates to:
  /// **'Your AI-powered adaptive STEM study companion'**
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
  /// **'Senior secondary school core curriculum & STEM exams'**
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
  /// **'SAT STEM'**
  String get satTrackLabel;

  /// Description for SAT track
  ///
  /// In en, this message translates to:
  /// **'Standardized math, geometry, and problem solving'**
  String get satTrackDesc;

  /// Label for University track
  ///
  /// In en, this message translates to:
  /// **'University STEM'**
  String get universityTrackLabel;

  /// Description for University track
  ///
  /// In en, this message translates to:
  /// **'Engineering, physics, calculus, and biochemistry'**
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

  /// Welcome message for AI conversational onboarding
  ///
  /// In en, this message translates to:
  /// **'Welcome to Kortex! I am Syllabot, your AI Academic Guide. Let\'s calibrate your curriculum and study goals.'**
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
  /// **'Launch Kortex Workspace'**
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

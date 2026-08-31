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

  @override
  String get authSwitchToForm => 'Quick Form';

  @override
  String get authSwitchToChat => 'AI Assistant';

  @override
  String get authSocialGoogle => 'Continue with Google';

  @override
  String get authSocialApple => 'Continue with Apple';

  @override
  String get authChatWelcome =>
      'Hi Stranger! 👋 Welcome to Kortex.\n\n✨ \"The beautiful thing about learning is that no one can take it away from you.\" — B.B. King\n\nI\'m Syllabot, your AI study partner. How would you like to get started today?';

  @override
  String get authChatAskEmail =>
      'Please enter your academic or personal email address.';

  @override
  String get authChatAskPassword =>
      'Great! Set a secure password (at least 6 characters).';

  @override
  String get authChipLogin => 'Log In';

  @override
  String get authChipSignUp => 'Sign Up';

  @override
  String get authChipForgotPassword => 'Forgot Password?';

  @override
  String get authChipGoogle => 'Use Google';

  @override
  String get authForgotPasswordTitle => 'Reset Password';

  @override
  String get authForgotPasswordSubtitle =>
      'Enter your registered email address and we will send you instructions to reset your password.';

  @override
  String get authEmailLabel => 'Email Address';

  @override
  String get authEmailHint => 'student@university.edu';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordHint => '••••••••';

  @override
  String get authDisplayNameLabel => 'Full Name';

  @override
  String get authDisplayNameHint => 'Ada Lovelace';

  @override
  String get authSubmitLogin => 'Sign In';

  @override
  String get authSubmitRegister => 'Create Account';

  @override
  String get authSubmitReset => 'Send Reset Link';

  @override
  String get authAlreadyHaveAccount => 'Already have an account? Sign In';

  @override
  String get authNeedAccount => 'Don\'t have an account? Sign Up';

  @override
  String get authSend => 'Send';

  @override
  String get authChatInputHint => 'Type a response or tap a quick action...';

  @override
  String get authInvalidEmail => 'Please enter a valid email address';

  @override
  String get authPasswordTooShort => 'Password must be at least 6 characters';

  @override
  String get authGenericError => 'Authentication failed. Please try again.';

  @override
  String get authSuccessMessage => 'Welcome to Kortex!';

  @override
  String authModeToggleSemantics(String mode) {
    return 'Switch to $mode';
  }

  @override
  String get authSocialGoogleSemantics => 'Sign in with your Google account';

  @override
  String get authSocialAppleSemantics => 'Sign in with your Apple ID';

  @override
  String authModeSwitchedAnnouncement(String mode) {
    return 'Switched to $mode view';
  }

  @override
  String get authDesktopHeroTitle => 'Your AI-Augmented Academic Workspace';

  @override
  String get authDesktopHeroSubtitle =>
      'Ingest syllabi, STEM equations, and lecture slides into an active-recall mastery system in seconds.';

  @override
  String get authDesktopFeature1 => 'Zero-latency multimodal STEM OCR';

  @override
  String get authDesktopFeature2 => 'Adaptive SM-2 spaced repetition schedules';

  @override
  String get authDesktopFeature3 => 'Socratic AI dialogue & calibration';

  @override
  String get authChatInputSemantics => 'Chat response input field';

  @override
  String get authChatSendSemantics => 'Send chat response';

  @override
  String get authForgotPasswordLinkSemantics => 'Reset password screen link';

  @override
  String get authToggleFormTypeSemantics =>
      'Toggle between Sign In and Create Account forms';

  @override
  String get calibrationTitle => 'Academic Calibration';

  @override
  String get calibrationSubtitle =>
      'Personalize Syllabot AI for your academic trajectory';

  @override
  String get calibrationChatWelcome =>
      'Awesome, you\'re in! To customize your workspace, let\'s set up your academic profile.';

  @override
  String get calibrationChatFocusPrompt =>
      'Are you studying at a University/Polytechnic or preparing for High School exams?';

  @override
  String get calibrationChatLevelPrompt =>
      'Got it! Which specific exam or degree track are you focusing on?';

  @override
  String get calibrationChatFieldPrompt =>
      'Excellent. What is your specific field of study or main subjects?';

  @override
  String get calibrationChatGoalPrompt =>
      'Perfect. How can Kortex best support you right now?';

  @override
  String get calibrationFocusHigherEd => 'University / Polytechnic';

  @override
  String get calibrationFocusHighSchool => 'High School / Exam Prep';

  @override
  String calibrationStepAnnouncement(int current, int total, String title) {
    return 'Calibration step $current of $total: $title';
  }

  @override
  String get calibrationBack => 'Previous';

  @override
  String get calibrationContinue => 'Continue';

  @override
  String get calibrationFinish => 'Calibrate & Launch Kortex';

  @override
  String get calibrationQuestion1 => 'What is your current academic focus?';

  @override
  String get calibrationOptionUniversity => 'University / Polytechnic';

  @override
  String get calibrationOptionHighSchool => 'High School / Exam Prep';

  @override
  String get calibrationQuestionA2 => 'What is your current academic level?';

  @override
  String get calibrationOptionOND => 'OND (Ordinary National Diploma)';

  @override
  String get calibrationOptionHND => 'HND (Higher National Diploma)';

  @override
  String get calibrationOptionBSc => 'BSc (Bachelor of Science)';

  @override
  String get calibrationOptionMSc => 'MSc (Master of Science)';

  @override
  String get calibrationOptionPhD => 'PhD (Doctor of Philosophy)';

  @override
  String get calibrationQuestionA3 => 'What is your specific field of study?';

  @override
  String get calibrationQuestionA3Subtitle =>
      'Select your primary domain to optimize Syllabot\'s knowledge retrieval';

  @override
  String get calibrationFieldMath => 'Mathematics & Data Science';

  @override
  String get calibrationFieldPhysics => 'Advanced Physics / Quantum Mechanics';

  @override
  String get calibrationFieldChemEng => 'Chemical Engineering';

  @override
  String get calibrationFieldMedicine => 'Medical & Health Sciences';

  @override
  String get calibrationFieldRobotics => 'Robotics & Mechanical Engineering';

  @override
  String get calibrationFieldComputerScience =>
      'Computer Science & Artificial Intelligence';

  @override
  String get calibrationFieldLaw => 'Law & Legal Studies';

  @override
  String get calibrationFieldBusiness => 'Business, Finance & Accounting';

  @override
  String get calibrationFieldHumanities => 'Humanities, History & Literature';

  @override
  String get calibrationFieldSocialSciences => 'Social Sciences & Economics';

  @override
  String get calibrationQuestionA4 =>
      'How can Kortex best support you right now?';

  @override
  String get calibrationQuestionA4Subtitle =>
      'Select all features you want Syllabot to prioritize for you';

  @override
  String get calibrationGoalThesis => 'Thesis / Dissertation Support';

  @override
  String get calibrationGoalSocratic => 'Deep-Dive STEM Socratic AI';

  @override
  String get calibrationGoalSpacedRep => 'Spaced Repetition (SM-2) Mastery';

  @override
  String get calibrationGoalMockExams => 'Comprehensive Mock Exams';

  @override
  String get calibrationGoalCaseLaw => 'Case Law & Essay Preparation';

  @override
  String get calibrationGoalEssayPrep => 'Structured Essay & Argument Mapping';

  @override
  String get calibrationQuestionB2 => 'What exam are you preparing for?';

  @override
  String get calibrationExamWAEC => 'WAEC / GCE';

  @override
  String get calibrationExamNECO => 'NECO / SSCE';

  @override
  String get calibrationExamJAMB => 'JAMB / UTME';

  @override
  String get calibrationExamSAT => 'SAT';

  @override
  String get calibrationExamIELTS => 'IELTS / TOEFL';

  @override
  String get calibrationExamIGCSE => 'IGCSE / A-Levels';

  @override
  String get calibrationQuestionB3 => 'What subjects do you need to master?';

  @override
  String get calibrationQuestionB3Subtitle =>
      'Select all subjects for active-recall flashcard generation';

  @override
  String get calibrationSubjectCoreMath => 'Mathematics (Core)';

  @override
  String get calibrationSubjectFurtherMath => 'Further Mathematics';

  @override
  String get calibrationSubjectPhysics => 'Physics';

  @override
  String get calibrationSubjectChemistry => 'Chemistry';

  @override
  String get calibrationSubjectBiology => 'Biology';

  @override
  String get calibrationSubjectEnglish => 'English Language';

  @override
  String get calibrationSubjectAccounting => 'Financial Accounting';

  @override
  String get calibrationSubjectEconomics => 'Economics';

  @override
  String get calibrationSubjectCommerce => 'Commerce';

  @override
  String get calibrationSubjectLiterature => 'Literature in English';

  @override
  String get calibrationSubjectGovernment => 'Government';

  @override
  String get calibrationSubjectHistory => 'History';

  @override
  String get calibrationSubjectCRK => 'CRK / IRK';

  @override
  String get calibrationTrackCore => 'Core';

  @override
  String get calibrationTrackScience => 'Science';

  @override
  String get calibrationTrackCommercial => 'Commercial';

  @override
  String get calibrationTrackArts => 'Arts / Humanities';

  @override
  String get calibrationQuestionB4 => 'When is your exam?';

  @override
  String get calibrationTimeline1Month => 'Next 1 Month';

  @override
  String get calibrationTimeline3Months => 'Next 3 Months';

  @override
  String get calibrationTimeline6Months => 'Next 6 Months';

  @override
  String get calibrationTimelineNextYear => 'Next Year';

  @override
  String get calibrationDesktopHeroTitle =>
      'Calibrating Neural Learning Engine';

  @override
  String get calibrationDesktopHeroSubtitle =>
      'Syllabot AI is adapting its retrieval indices, Socratic dialogue trees, and memory decay formulas specifically for your curriculum.';

  @override
  String get calibrationDesktopMetric1 => 'Adaptive RAG Knowledge Base';

  @override
  String get calibrationDesktopMetric2 => 'Curriculum-Specific STEM Prompts';

  @override
  String get calibrationDesktopMetric3 =>
      'Personalized Spaced Repetition Intervals';

  @override
  String calibrationSelectOptionSemantics(String option) {
    return 'Select $option';
  }

  @override
  String calibrationSelectedOptionSemantics(String option) {
    return '$option, selected';
  }

  @override
  String get contentRecommendationTitle => 'Pre-Calibrated Workspace';

  @override
  String get contentRecommendationSubtitle =>
      'Curated resources ready in your dashboard';

  @override
  String contentRecommendationAnnouncement(
    int current,
    int total,
    String title,
  ) {
    return 'Recommendation $current of $total: $title';
  }

  @override
  String get contentPastPapersTagline => 'Instant Exam Readiness';

  @override
  String contentPastPapersDesc(String examType, String subjects) {
    return 'Based on your target ($examType), we\'ve selected high-yield past papers from our database for $subjects.';
  }

  @override
  String contentFlashcardsTagline(String field) {
    return 'Deep Mastery of $field';
  }

  @override
  String contentFlashcardsDesc(String field) {
    return 'Dive into structured flashcards for core topics in $field. Master key concepts instantly with SM-2 Spaced Repetition.';
  }

  @override
  String get contentSocraticTagline => 'Syllabot AI is Ready';

  @override
  String contentSocraticDesc(String level, String field) {
    return 'We\'ve created tutoring threads covering mandatory topics for $level students in $field. Ask Syllabot anything!';
  }

  @override
  String get contentNextButton => 'Next Recommendation';

  @override
  String get contentGetStartedButton => 'Launch Dashboard';

  @override
  String get contentSkipButton => 'Skip to Dashboard';

  @override
  String get contentDesktopHeroTitle => 'Your Pre-Loaded Academic Hub';

  @override
  String get contentDesktopHeroSubtitle =>
      'Zero blank pages. We\'ve pre-seeded your library with verified past exams, adaptive STEM decks, and automated Socratic dialogue channels.';

  @override
  String get contentFeature1 => 'Pre-indexed exam question banks';

  @override
  String get contentFeature2 => 'Automated SM-2 spaced repetition decks';

  @override
  String get contentFeature3 => 'Dedicated 24/7 Syllabot AI course assistants';

  @override
  String get contentBadgeCurated => 'DATABASE PRE-POPULATED';

  @override
  String get contentBadgeActiveRecall => 'ACTIVE RECALL DECK';

  @override
  String get contentBadgeSocratic => 'SOCRATIC DIALOGUE';

  @override
  String get otpTitle => 'Check your inbox';

  @override
  String otpSubtitle(String email) {
    return 'We sent a 6-digit verification code to $email. Enter it below to verify your account.';
  }

  @override
  String get otpVerifyButton => 'Verify Email';

  @override
  String get otpResendCode => 'Resend Code';

  @override
  String get otpResending => 'Resending…';

  @override
  String otpResendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get otpResentMessage => 'A new code has been sent to your email.';

  @override
  String get otpVerifyingAnnouncement => 'Verifying your code, please wait.';

  @override
  String get otpVerifiedAnnouncement =>
      'Email verified successfully. Welcome to Kortex!';

  @override
  String get otpInputSemantics => 'Six digit verification code input';

  @override
  String get otpVerifyButtonSemantics => 'Verify your email address';

  @override
  String get otpResendSemantics => 'Resend verification code';

  @override
  String get permissionsTitle => 'Enable Key Features';

  @override
  String get permissionsSubtitle =>
      'Allow Kortex to send you study reminders and scan your documents for instant AI indexing.';

  @override
  String get permissionsNotifTitle => 'Push Notifications';

  @override
  String get permissionsNotifDescription =>
      'Receive spaced-repetition reminders and active-recall session alerts calibrated to your study streak.';

  @override
  String get permissionsStorageTitle => 'Camera & Storage Access';

  @override
  String get permissionsStorageDescription =>
      'Snap textbook pages for OCR parsing and drop in PDF or PPTX lecture slides for instant AI indexing.';

  @override
  String get permissionsAllow => 'Allow';

  @override
  String get permissionsContinue => 'Continue to Dashboard';

  @override
  String get permissionsSkip => 'Skip for now';

  @override
  String get permissionsCompleteAnnouncement =>
      'Permissions configured. Opening your dashboard.';

  @override
  String get permissionsNotifSemantics =>
      'Allow push notifications for study reminders';

  @override
  String get permissionsStorageSemantics =>
      'Allow camera and storage access for document scanning';

  @override
  String get permissionsSkipSemantics =>
      'Skip permissions and proceed to dashboard';

  @override
  String get calibrationSkip => 'Skip';

  @override
  String get calibrationSkipSemantics =>
      'Skip academic profile setup and use default settings';

  @override
  String get navBarSemanticsLabel => 'Main Navigation';

  @override
  String get navTabHome => 'Home';

  @override
  String get navTabSyllabot => 'Syllabot AI';

  @override
  String get navTabDecks => 'Study Decks';

  @override
  String get navTabCommunity => 'Community';

  @override
  String get navTabProfile => 'Profile';

  @override
  String navTabAnnouncement(String tab) {
    return 'Switched to $tab tab';
  }

  @override
  String navTabSemantics(String tab, int current, int total) {
    return '$tab, tab $current of $total';
  }

  @override
  String dashboardHeyUser(String name) {
    return 'Hey, $name 👋';
  }

  @override
  String get dashboardScholarFallback => 'Scholar';

  @override
  String dashboardStreakTooltip(int count) {
    return '$count day study streak';
  }

  @override
  String get dashboardViewAnalyticsSemantics =>
      'View detailed study analytics and streaks';

  @override
  String get dashboardUncalibratedTitle => 'Calibrate Your Neural Workspace';

  @override
  String get dashboardUncalibratedSubtitle =>
      'Tailor past papers, flashcards & exam simulator to your exact course.';

  @override
  String get dashboardCalibrateButton => 'Calibrate';

  @override
  String get dashboardUncalibratedSemantics =>
      'Profile is not calibrated. Tap to configure your academic track.';

  @override
  String get dashboardUnableToLoad => 'Unable to Load Dashboard';

  @override
  String get dashboardConnectionError =>
      'Please check your network connection and try again.';

  @override
  String get dashboardRetry => 'Retry';

  @override
  String get dashboardSpacedRepetitionQueue => 'Spaced Repetition Queue';

  @override
  String dashboardDecksCount(int count) {
    return '$count DECKS';
  }

  @override
  String dashboardActiveCoursesCount(int count) {
    return '$count ACTIVE';
  }

  @override
  String get dashboardCuratedCourses => 'Curated Course Repositories';

  @override
  String dashboardResourcesCount(int count) {
    return '$count resources';
  }

  @override
  String dashboardDueCount(int count) {
    return '$count DUE';
  }

  @override
  String get dashboardMemoryRetention => 'Memory Retention';

  @override
  String get dashboardReviewDeck => 'Review Deck';

  @override
  String dashboardEstimatedMinutes(int minutes) {
    return '~$minutes mins';
  }

  @override
  String get dashboardAskSyllabotHint =>
      'Ask Syllabot anything (e.g. Solve PDE #3)...';

  @override
  String get dashboardSendPromptSemantics => 'Send prompt to Syllabot AI';

  @override
  String get dashboardAskSyllabotSemantics =>
      'Ask Syllabot AI instant study question';

  @override
  String get dashboardRetentionMatrix => 'Retention & Study Matrix';

  @override
  String get dashboardFullStats => 'Full Stats';

  @override
  String get dashboardRetentionChip => 'Retention';

  @override
  String get dashboardMasteredChip => 'Mastered';

  @override
  String get dashboardStudyTimeChip => 'Study Time';

  @override
  String dashboardStudyTimeMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String get dashboardQuickActionsSemantics =>
      'Quick action bar: Upload PDF, create active recall deck, or start AI study chat';

  @override
  String get dashboardUploadNotes => 'Upload Notes';

  @override
  String get dashboardNewDeck => 'New Deck';

  @override
  String get dashboardAiPartner => 'AI Partner';

  @override
  String get dashboardIngestTitle => 'Ingest Study Material';

  @override
  String get dashboardIngestSubtitle =>
      'Drop lecture slides, PDFs or handwritten past papers. Syllabot will parse STEM OCR & generate flashcards.';

  @override
  String get dashboardUploadPdf => 'Upload PDF';

  @override
  String get dashboardLectureSlides => 'Lecture Slides';

  @override
  String get dashboardScanNotes => 'Scan Notes';

  @override
  String get dashboardStemOcr => 'STEM OCR';

  @override
  String dashboardDaysLeft(int count) {
    return '$count DAYS LEFT';
  }

  @override
  String get dashboardSyllabusMastery => 'Syllabus Mastery';

  @override
  String dashboardSyllabusPercentComplete(int percent) {
    return '$percent% complete';
  }

  @override
  String dashboardLaunchMockSimulator(int completed, int total) {
    return 'Launch Mock Simulator ($completed/$total)';
  }

  @override
  String dashboardLaunchMockSimulatorSemantics(String examName) {
    return 'Launch $examName Mock Simulator';
  }

  @override
  String get deckDetailTitle => 'Active Recall Session';

  @override
  String deckDetailCardProgress(int current, int total) {
    return 'Card $current of $total';
  }

  @override
  String get deckDetailSm2QueueBadge => 'SM-2 SPATIAL QUEUE';

  @override
  String get deckDetailAnswerFormula => 'ANSWER / FORMULA';

  @override
  String get deckDetailQuestion => 'QUESTION';

  @override
  String get deckDetailTapToFlip => 'Tap card to flip';

  @override
  String get deckDetailHard => 'Hard';

  @override
  String get deckDetailGood => 'Good';

  @override
  String get deckDetailEasy => 'Easy';

  @override
  String get deckDetailBackSemantics => 'Back to Dashboard';

  @override
  String get mockExamLobbyTitle => 'Exam Simulator Lobby';

  @override
  String get mockExamLobbyDescription =>
      'Simulate computer-based testing with dynamic negative marking, question timers, and Syllabot AI error diagnostics.';

  @override
  String get mockExamSelectMode => 'Select Simulation Mode';

  @override
  String get mockExamModeStandardTitle => 'Standard Timed (CBT)';

  @override
  String get mockExamModeStandardSubtitle =>
      '50 Questions · 60 Mins · Live Timer & Negative Marking';

  @override
  String get mockExamModeSocraticTitle => 'Socratic Practice Mode';

  @override
  String get mockExamModeSocraticSubtitle =>
      'Untimed · Instant Step-by-Step AI Solutions per question';

  @override
  String get mockExamModeDrillTitle => 'Weak Areas Targeted Drill';

  @override
  String get mockExamModeDrillSubtitle =>
      'Focused on concepts where your retention score is < 80%';

  @override
  String get mockExamBeginButton => 'Begin Simulation Session';

  @override
  String get analyticsDetailTitle => 'Neural Analytics & Retention';

  @override
  String analyticsStreakDays(int count) {
    return '$count Day Study Streak 🔥';
  }

  @override
  String get analyticsStreakRecord =>
      'Your record is 28 days. Keep studying to reach Neural Master rank!';

  @override
  String get analyticsRetentionCurveTitle =>
      'Memory Retention Curve (Ebbinghaus SM-2)';

  @override
  String analyticsMasteredCountSubtitle(int count) {
    return '$count concept cards mastered in active recall';
  }

  @override
  String get courseModulePastPapersTitle => 'Past Papers & Problem Sets';

  @override
  String get courseModuleVerifiedSubtitle =>
      'Verified OCR · Step-by-Step AI Solutions';

  @override
  String get decksTitle => 'Study Decks';

  @override
  String get decksSubtitle => 'Active recall queues powered by SuperMemo-2';

  @override
  String get decksSearchHint => 'Search decks or subjects...';

  @override
  String decksDueBadge(int count) {
    return '$count Due';
  }

  @override
  String decksTotalCards(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '1 card',
    );
    return '$_temp0';
  }

  @override
  String get decksEmptyStateTitle => 'No Study Decks Yet';

  @override
  String get decksEmptyStateSubtitle =>
      'Ingest lecture notes or past papers to generate SM-2 spaced repetition decks automatically.';

  @override
  String get decksCreateDeckButton => 'Create New Deck';

  @override
  String get decksFilterAll => 'All Decks';

  @override
  String get decksFilterDue => 'Due Today';

  @override
  String get decksFilterMastered => 'Mastered';

  @override
  String get decksStartSession => 'Start Study Session';

  @override
  String decksMasteryPercent(int percent) {
    return '$percent% mastery';
  }

  @override
  String get studySessionTitle => 'Active Recall';

  @override
  String studySessionCardIndex(int current, int total) {
    return '$current / $total';
  }

  @override
  String get studySessionTapToFlip =>
      'Tap card or press Spacebar to reveal answer';

  @override
  String get studySessionSwipeHint =>
      'Swipe left for Hard · Swipe right for Good';

  @override
  String get studySessionKeyboardShortcuts =>
      'Space: Flip · 1: Again · 2: Hard · 3: Good · 4: Easy';

  @override
  String get studySessionFrontBadge => 'PROMPT / EQUATION';

  @override
  String get studySessionBackBadge => 'EXPLANATION / DERIVATION';

  @override
  String get studyRatingAgain => 'Again';

  @override
  String get studyRatingAgainInterval => '< 10m';

  @override
  String get studyRatingHard => 'Hard';

  @override
  String get studyRatingHardInterval => '1d';

  @override
  String get studyRatingGood => 'Good';

  @override
  String get studyRatingGoodInterval => '6d';

  @override
  String get studyRatingEasy => 'Easy';

  @override
  String get studyRatingEasyInterval => '12d';

  @override
  String studySessionTimer(String time) {
    return 'Session Time: $time';
  }

  @override
  String get sessionSummaryTitle => 'Session Complete! 🎉';

  @override
  String get sessionSummarySubtitle =>
      'Your neural pathways have been reinforced. SM-2 intervals updated.';

  @override
  String get sessionSummaryCardsReviewed => 'Cards Reviewed';

  @override
  String get sessionSummaryRetentionRate => 'Retention Score';

  @override
  String get sessionSummaryTimeSpent => 'Study Duration';

  @override
  String sessionSummaryStreakBonus(int xp) {
    return '+$xp XP Earned · Streak Kept!';
  }

  @override
  String get sessionSummaryReturnDashboard => 'Return to Dashboard';

  @override
  String get sessionSummaryReviewAgain => 'Review More Decks';

  @override
  String get syllabotTitle => 'Syllabot AI';

  @override
  String get socraticStepByStep => 'Step-by-Step';

  @override
  String get socraticDirectAnswer => 'Direct Answer';

  @override
  String get socraticExamSim => 'Exam Sim';

  @override
  String get socraticDeepResearch => 'Deep Research';

  @override
  String get engineCloudSupabase => 'Cloud Neural Engine';

  @override
  String get engineLocalOnDevice => 'Offline On-Device LLM';

  @override
  String get convertToDeckSuccess =>
      'Converted to Flashcard Deck successfully!';

  @override
  String get inputFieldPlaceholder =>
      'Ask Syllabot anything (e.g. Derive Euler-Lagrange equations)...';

  @override
  String get voiceInputListening => 'Listening to your question...';

  @override
  String get offlineFallbackNotice =>
      'Offline mode: Running on-device neural model.';

  @override
  String get newChatSession => 'New Chat';

  @override
  String get chatSessionsHistory => 'Chat History';

  @override
  String get noChatSessionsFound =>
      'No chat sessions yet. Ask your first question!';

  @override
  String get convertToDeckTitle => 'Convert Chat to Flashcard Deck';

  @override
  String get convertToDeckDescription =>
      'Syllabot AI will extract key STEM formulas, terms, and concepts into an active-recall deck.';

  @override
  String get deckNameLabel => 'Deck Title';

  @override
  String get createDeckAction => 'Generate Spaced Repetition Deck';

  @override
  String get generatingDeckProgress => 'Synthesizing flashcards with AI...';

  @override
  String get retryFailedMessage => 'Retry Response';

  @override
  String get streamingComplete => 'Syllabot response completed.';

  @override
  String engineSwitched(String engine) {
    return 'Switched engine to $engine';
  }

  @override
  String get audioInputDisabled => 'Audio recording permission required';

  @override
  String get clearHistoryConfirmation =>
      'Are you sure you want to clear chat history?';

  @override
  String get clearAction => 'Clear';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get ingestionTitle => 'Document Ingestion & OCR';

  @override
  String get dragAndDropHint => 'Drag & drop PDF, PPTX, or image files here';

  @override
  String get browseFilesButton => 'Browse Files';

  @override
  String get cameraCaptureButton => 'Scan with Camera';

  @override
  String get uploadingStatus => 'Uploading document...';

  @override
  String get processingOcrStatus => 'Extracting STEM formulas & LaTeX...';

  @override
  String get generatingCardsStatus => 'Generating active recall cards...';

  @override
  String get ocrPreviewTitle => 'STEM OCR Live Editor';

  @override
  String get saveToDecksButton => 'Convert to Flashcards';

  @override
  String get invalidFileFormatError =>
      'Unsupported file format. Please choose a PDF, PPTX, or Image file.';

  @override
  String get supportedFormatsNotice =>
      'Supported formats: PDF, PPTX, PNG, JPG (Max 50MB)';

  @override
  String extractedSnippetsCount(int count) {
    return '$count formulas & concepts extracted';
  }

  @override
  String get generateCardsAction => 'Generate SM-2 Cards';

  @override
  String get reviewCardsTitle => 'Review Generated Flashcards';

  @override
  String get confirmAndStudyAction => 'Save & Start Study Session';

  @override
  String get cameraScanTitle => 'Scan Study Material';

  @override
  String get cameraCaptureHint =>
      'Align lecture slide or textbook page inside the frame';

  @override
  String get contentAlreadyUploadedNotice =>
      'File already indexed. Loaded existing STEM extractions instantly.';

  @override
  String get communityTitle => 'Community & Study Hub';

  @override
  String get liveRoomsTab => 'Live Rooms';

  @override
  String get forumTab => 'Track Forum';

  @override
  String get marketplaceTab => 'Deck Market';

  @override
  String get leaderboardTab => 'Leaderboard';

  @override
  String get joinRoomButton => 'Join Focus Room';

  @override
  String get cloneDeckButton => 'Clone to My Decks';

  @override
  String get createPostButton => 'Create Post';

  @override
  String activeParticipantsCount(int count) {
    return '$count active peers';
  }

  @override
  String dailyStreakRank(int rank, int streak) {
    return 'Rank #$rank • $streak Day Streak';
  }

  @override
  String get deckClonedSuccessNotice =>
      'Deck cloned successfully! Added to your study space.';

  @override
  String get focusRoomTitle => 'Synchronized Focus Room';

  @override
  String get pomodoroFocus => 'Deep Focus';

  @override
  String get pomodoroBreak => 'Short Break';

  @override
  String get leaveRoomButton => 'Leave Room';

  @override
  String get shareDeckTitle => 'Share a Flashcard Deck';

  @override
  String get postTitleHint =>
      'Thread title (e.g. Solving Maxwell\'s Equations...)';

  @override
  String get postContentHint => 'Describe your academic question or insight...';

  @override
  String get selectTrackHint => 'Select Academic Track';

  @override
  String get replyAction => 'Reply';

  @override
  String get upvoteAction => 'Upvote';

  @override
  String get welcomeTitle => 'Welcome to Kortex';

  @override
  String get welcomeSubtitle => 'Your AI-powered adaptive STEM study companion';

  @override
  String get selectCourseTrackPrompt => 'Select Your Focus Track';

  @override
  String get selectCourseTrackDesc =>
      'We\'ll tailor your daily active-recall intervals, exam countdowns, and mock exams to match your syllabus.';

  @override
  String get dailyTargetCardGoal => 'Daily Review Target';

  @override
  String get dailyTargetCardGoalDesc =>
      'Target number of flashcards to master every day to keep your Ebbinghaus retention curve above 85%.';

  @override
  String get waecTrackLabel => 'WAEC / WASSCE';

  @override
  String get waecTrackDesc =>
      'Senior secondary school core curriculum & STEM exams';

  @override
  String get jambTrackLabel => 'JAMB / UTME';

  @override
  String get jambTrackDesc =>
      'High-speed multiple choice drills & past questions';

  @override
  String get satTrackLabel => 'SAT STEM';

  @override
  String get satTrackDesc => 'Standardized math, geometry, and problem solving';

  @override
  String get universityTrackLabel => 'University STEM';

  @override
  String get universityTrackDesc =>
      'Engineering, physics, calculus, and biochemistry';

  @override
  String get completeOnboardingButton => 'Complete Setup & Launch';

  @override
  String get continueButton => 'Continue';

  @override
  String get backButton => 'Back';

  @override
  String onboardingStepIndicator(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get signInWithGoogle => 'Continue with Google';

  @override
  String get signInWithApple => 'Continue with Apple';

  @override
  String get sendMagicLink => 'Send Magic Sign-In Link';

  @override
  String get magicLinkSentNotice =>
      'A magic sign-in link has been sent to your email.';

  @override
  String get userProfileTitle => 'Profile & Settings';

  @override
  String get editTrackAndGoals => 'Active Academic Track & Target';

  @override
  String cardsPerDay(int count) {
    return '$count cards / day';
  }

  @override
  String retentionTarget(int percent) {
    return '$percent% Retention';
  }

  @override
  String get saveChangesButton => 'Save Changes';

  @override
  String get profileSavedSuccessNotice =>
      'Profile and track goals updated successfully!';

  @override
  String get signOutButton => 'Sign Out';

  @override
  String get signOutConfirmation => 'Are you sure you want to sign out?';

  @override
  String get switchToFormView => 'Switch to Form View';

  @override
  String get switchToChatView => 'Switch to AI Chat';

  @override
  String get onboardingChatWelcome =>
      'Welcome to Kortex! I am Syllabot, your AI Academic Guide. Let\'s calibrate your curriculum and study goals.';

  @override
  String get onboardingStepTrackTitle => 'Target Academic Track';

  @override
  String get onboardingStepGoalTitle => 'Daily Review Target';

  @override
  String get completeAndGoToDashboard => 'Launch Kortex Workspace';

  @override
  String get onboardingAiChatTitle => 'AI Guide';

  @override
  String get onboardingFormTitle => 'Form View';

  @override
  String get askAiAboutCurriculum =>
      'Type a message or question about your syllabus...';

  @override
  String get aiThinking => 'Syllabot is preparing your personalized plan...';

  @override
  String autoCommunityCreatedTitle(String courseCode) {
    return 'We auto-created the $courseCode Community Hub!';
  }

  @override
  String autoCommunityJoinedSubtitle(int count) {
    return '$count peers are currently studying this material.';
  }

  @override
  String get foundingMemberBadge => 'Founding Member 🌟';

  @override
  String get viewPeerDiscussion => 'View Peer Discussion';

  @override
  String get openCommunityHub => 'Open Hub';

  @override
  String get quickJoinStudyRoom => 'Quick Join Focus Room';

  @override
  String activeRoomPeers(int count) {
    return '$count peers studying now';
  }

  @override
  String peerHubTitle(String courseCode) {
    return '$courseCode Peer Hub';
  }

  @override
  String connectedPeersCount(int count) {
    return '$count Active Peers';
  }

  @override
  String get indexingDocumentProgress =>
      'Indexing course material into neural vector memory...';

  @override
  String ragContextFoundNotice(int count) {
    return 'Found $count relevant textbook sections.';
  }

  @override
  String retrievedContextBadge(int score) {
    return 'Verified Course Context ($score% Match)';
  }

  @override
  String get alignCameraTextHint =>
      'Align textbook or lecture note text within frame';

  @override
  String get offlineOcrProcessedNotice =>
      'Processed locally. Will sync with LaTeX AI when online.';

  @override
  String syncPendingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items pending sync',
      one: '1 item pending sync',
    );
    return '$_temp0';
  }

  @override
  String get syncCompletedNotice => 'Cloud sync and LaTeX enhancement complete';

  @override
  String get predictedRetentionLabel => 'Predicted Retention (FSRS-4.5)';

  @override
  String get actualRetentionLabel => 'Actual Recall Rate';

  @override
  String get fsrsModeDescription =>
      'Adaptive Stability & Difficulty decay modeling for optimal study load';

  @override
  String get sm2ModeDescription =>
      'Classical SuperMemo-2 interval and ease factor spacing';

  @override
  String get schedulerAlgorithmTitle => 'Spaced Repetition Scheduler';

  @override
  String get projectedWorkloadTitle => '7-Day Projected Review Workload';

  @override
  String get listeningVoiceInput =>
      'Listening... Speak your academic question clearly';

  @override
  String get stopAudioPlayback => 'Stop audio narration';

  @override
  String speechSpeedLabel(String speed) {
    return '${speed}x Speed';
  }

  @override
  String get tapToSpeakHint => 'Tap microphone to speak';

  @override
  String get readAloudLabel => 'Read Aloud';

  @override
  String daysUntilExam(int count, String examName) {
    return '$count days until $examName';
  }

  @override
  String recommendedDailyPace(int count) {
    return 'Target pace: $count cards/day';
  }

  @override
  String get addExamTitle => 'Add Exam Countdown';

  @override
  String get examNameLabel => 'Exam Name';

  @override
  String get targetDateLabel => 'Target Exam Date';

  @override
  String get examSubjectLabel => 'Subject / Track';

  @override
  String get saveExamCountdown => 'Save Exam Countdown';
}

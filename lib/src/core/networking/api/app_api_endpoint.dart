import 'package:kortex/src/core/constants/app_env.dart';

/// All API endpoints used across the Kortex application.
class AppApiEndpoint {
  const AppApiEndpoint._();

  static const scheme = 'https';
  static String get host {
    var raw = AppEnv.apiBaseURL.trim();
    if (raw.startsWith('https://')) {
      raw = raw.substring(8);
    } else if (raw.startsWith('http://')) {
      raw = raw.substring(7);
    }
    while (raw.endsWith('/')) {
      raw = raw.substring(0, raw.length - 1);
    }
    return raw;
  }

  static const int receiveTimeout = 50000;
  static const int sendTimeout = 50000;

  static String get baseUri => host.isNotEmpty ? '$scheme://$host' : '';

  // Auth & Identity Endpoints
  static const String login = '/auth/v1/token?grant_type=password';
  static const String register = '/auth/v1/signup';
  static const String socialAuth = '/auth/v1/token';
  static const String resetPassword = '/auth/v1/recover';
  static const String refreshToken = '/auth/v1/token?grant_type=refresh_token';
  static const String magicLink = '/auth/v1/magiclink';
  static const String otpVerify = '/auth/v1/verify';
  static const String userProfiles = '/rest/v1/profiles';
  static const String courseTracks = '/rest/v1/course_tracks';
  static const String updateProfileRpc =
      '/rest/v1/rpc/update_user_profile_track_and_goal';

  // Dashboard Endpoints
  static const String dashboardFeed = '/rest/v1/rpc/get_dashboard_feed';
  static const String dashboardAnalyticsSummaryRpc =
      '/rest/v1/rpc/get_dashboard_analytics_summary';
  static const String dashboardReviewQueue =
      '/rest/v1/decks?due_cards=gt.0&order=due_cards.desc&limit=5';
  static const String dashboardStartExam = '/rest/v1/rpc/start_mock_exam';
  static const String curatedCoursesCatalog =
      '/rest/v1/curated_courses?select=*&order=field_category.asc,course_code.asc';
  static const String syncCoursesRpc =
      '/rest/v1/rpc/sync_or_create_user_courses';
  static const String autoCurateExamRpc =
      '/rest/v1/rpc/auto_curate_exam_courses';
  static const String getUserCuratedCoursesRpc =
      '/rest/v1/rpc/get_user_curated_courses';
  static const String userCuratedCoursesRest =
      '/rest/v1/user_curated_courses?select=id,course_id,syllabus_coverage,enrolled_at,curated_courses(*)&order=enrolled_at.desc';
  static const String curriculumMetadata =
      '/rest/v1/app_curriculum_metadata?select=*&is_active=eq.true';
  static const String subjects =
      '/rest/v1/subjects?select=*&order=stream.asc,title.asc';

  // Decks & Flashcards Endpoints
  static const String decks = '/rest/v1/decks?select=*';
  static const String deckCards =
      '/rest/v1/flashcards?deck_id=eq.{id}&select=*';
  static const String sessionResults = '/rest/v1/rpc/record_study_session';

  // Syllabot AI Endpoints
  static const String syllabotStream = '/functions/v1/syllabot-stream';
  static const String syllabotSessions = '/rest/v1/chat_sessions';
  static const String syllabotMessages = '/rest/v1/chat_messages';
  static const String matchDocumentChunksRpc =
      '/rest/v1/rpc/match_document_chunks';
  static const String generateEmbeddings = '/functions/v1/generate-embeddings';

  // Document Ingestion & STEM OCR Endpoints
  static const String storageBucket = '/storage/v1/object/study-documents';
  static const String cardAssetsBucket = '/storage/v1/object/card-assets';
  static const String documents = '/rest/v1/documents';
  static const String extractedSnippets = '/rest/v1/extracted_snippets';
  static const String parseStemOcr = '/functions/v1/parse-stem-ocr';
  static const String transcribeAudioWhisper =
      '/functions/v1/transcribe-audio-whisper';
  static const String findOrCreateDocumentReference =
      '/rest/v1/rpc/find_or_create_document_reference';
  static const String claimOrCreateDocumentPreflight =
      '/rest/v1/rpc/claim_or_create_document_preflight';

  static String getCardAssetPublicUrl(String path) =>
      '$baseUri/storage/v1/object/public/card-assets/$path';

  // Community & Peer Study Hub Endpoints
  static const String studyRooms = '/rest/v1/study_rooms';
  static const String forumPosts = '/rest/v1/forum_posts';
  static const String forumReplies = '/rest/v1/forum_replies';
  static const String studyCircles = '/rest/v1/study_circles';
  static const String studyCircleMembers = '/rest/v1/study_circle_members';
  static const String sharedDecks = '/rest/v1/shared_decks';
  static const String leaderboards = '/rest/v1/leaderboards';
  static const String claimWeeklyXpRpc = '/rest/v1/rpc/claim_weekly_xp';
  static const String cloneSharedDeckRpc = '/rest/v1/rpc/clone_shared_deck';
  static const String rateSharedDeckRpc = '/rest/v1/rpc/rate_shared_deck';
  static const String verifyForumReplyRpc = '/rest/v1/rpc/verify_forum_reply';
  static const String voteForumPostAtomicRpc =
      '/rest/v1/rpc/vote_forum_post_atomic';
  static const String voteForumReplyAtomicRpc =
      '/rest/v1/rpc/vote_forum_reply_atomic';
  static const String autoProvisionCommunityRpc =
      '/rest/v1/rpc/auto_provision_community_rpc';
  static const String nudgeStudyCircleRpc =
      '/rest/v1/rpc/nudge_study_circle_rpc';
  static const String recordPodFocusMinutesRpc =
      '/rest/v1/rpc/record_pod_focus_minutes_rpc';
  static const String notifications = '/rest/v1/notifications';
  static const String studyCommunities = '/rest/v1/study_communities';
  static const String forumPostSubscriptions =
      '/rest/v1/forum_post_subscriptions';
  static const String toggleForumPostSubscriptionRpc =
      '/rest/v1/rpc/toggle_forum_post_subscription';
  static const String isForumPostSubscribedRpc =
      '/rest/v1/rpc/is_forum_post_subscribed';
  static const String fetchForumPostsKeysetRpc =
      '/rest/v1/rpc/fetch_forum_posts_keyset';
  static const String fetchForumThreadTreeRpc =
      '/rest/v1/rpc/fetch_forum_thread_tree';
  static const String saveForumSocraticHintRpc =
      '/rest/v1/rpc/save_forum_socratic_hint';
  static const String generateLiveKitToken =
      '/functions/v1/generate-livekit-token';

  // Past Questions & Question Bank
  static const String pastQuestions = '/rest/v1/past_questions';
  static const String generateQuizQuestions =
      '/functions/v1/generate-quiz-questions';
  static const String generateDuelQuestionsRpc =
      '/rest/v1/rpc/generate_duel_questions';
  static const String submitQuizResultsRpc =
      '/rest/v1/rpc/fn_process_quiz_duel_outcome';
  static const String quizzes = '/rest/v1/quizzes';

  // Planner & Exam Countdown Timetable
  static const String examEvents = '/rest/v1/exam_events';

  // Push Notifications & Device Tokens
  static const String registerDeviceTokenRpc =
      '/rest/v1/rpc/register_device_token';
  static const String upsertNotificationPreferencesRpc =
      '/rest/v1/rpc/upsert_notification_preferences';
  static const String notificationPreferences =
      '/rest/v1/notification_preferences';
  static const String notificationsInbox =
      '/rest/v1/notifications?order=created_at.desc';

  // Monetization & Promo Codes
  static const String redeemPromoCodeRpc = '/rest/v1/rpc/redeem_promo_code';
}

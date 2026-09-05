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
  static const String dashboardReviewQueue =
      '/rest/v1/decks?due_cards=gt.0&order=due_cards.desc&limit=5';
  static const String dashboardStartExam = '/rest/v1/rpc/record_study_session';
  static const String curatedCoursesCatalog =
      '/rest/v1/curated_courses?select=*&order=field_category.asc,course_code.asc';
  static const String syncCoursesRpc =
      '/rest/v1/rpc/sync_or_create_user_courses';
  static const String autoCurateExamRpc =
      '/rest/v1/rpc/auto_curate_exam_courses';

  // Decks & Flashcards Endpoints
  static const String decks = '/rest/v1/decks?select=*';
  static const String deckCards =
      '/rest/v1/flashcards?deck_id=eq.{id}&select=*';
  static const String reviewCard = '/rest/v1/rpc/process_card_sm2_review';
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
  static const String findOrCreateDocumentReference =
      '/rest/v1/rpc/find_or_create_document_reference';

  static String getCardAssetPublicUrl(String path) =>
      '$baseUri/storage/v1/object/public/card-assets/$path';

  // Community & Peer Study Hub Endpoints
  static const String studyRooms = '/rest/v1/study_rooms';
  static const String forumPosts = '/rest/v1/forum_posts';
  static const String forumReplies = '/rest/v1/forum_replies';
  static const String sharedDecks = '/rest/v1/shared_decks';
  static const String leaderboards = '/rest/v1/leaderboards';
  static const String cloneSharedDeckRpc = '/rest/v1/rpc/clone_shared_deck';
  static const String autoProvisionCommunityRpc =
      '/rest/v1/rpc/auto_provision_community_rpc';
  static const String studyCommunities = '/rest/v1/study_communities';

  // Past Questions & Question Bank
  static const String pastQuestions = '/rest/v1/past_questions';

  // Push Notifications & Device Tokens
  static const String registerDeviceTokenRpc =
      '/rest/v1/rpc/register_device_token';
  static const String notificationPreferences =
      '/rest/v1/notification_preferences';
  static const String notificationsInbox =
      '/rest/v1/notifications?order=created_at.desc';
  static const String triggerNotifications =
      '/functions/v1/trigger-notifications';
}

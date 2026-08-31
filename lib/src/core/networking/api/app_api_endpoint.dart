import 'package:kortex/src/core/constants/app_env.dart';

/// All endpoints used in this project are declared in this class.
class AppApiEndpoint {
  const AppApiEndpoint._();

  static const scheme = 'https';
  static String host = AppEnv.apiBaseURL;
  static const int receiveTimeout = 50000;
  static const int sendTimeout = 50000;

  static String baseUri = '$scheme://$host';

  // Auth Endpoints (Supabase GoTrue)
  static const String login = '/auth/v1/token?grant_type=password';
  static const String register = '/auth/v1/signup';
  static const String socialAuth = '/auth/v1/token';
  static const String resetPassword = '/auth/v1/recover';

  // Dashboard Endpoints (Supabase RPC & REST)
  static const String dashboardFeed = '/rest/v1/rpc/get_dashboard_feed';
  static const String dashboardReviewQueue = '/rest/v1/decks?due_cards=gt.0&order=due_cards.desc&limit=5';
  static const String dashboardStartExam = '/rest/v1/rpc/record_study_session';

  // Decks & Flashcards Endpoints (Supabase REST & RPC)
  static const String decks = '/rest/v1/decks?select=*';
  static const String deckCards = '/rest/v1/flashcards?deck_id=eq.{id}&select=*';
  static const String reviewCard = '/rest/v1/rpc/process_card_sm2_review';
  static const String sessionResults = '/rest/v1/rpc/record_study_session';
}

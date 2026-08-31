import 'package:kortex/src/core/constants/app_env.dart';

/// All endpoints used in this project are declared in this class.
class AppApiEndpoint {
  const AppApiEndpoint._();

  static const scheme = 'https';
  static String host = AppEnv.apiBaseURL;
  static const int receiveTimeout = 50000;
  static const int sendTimeout = 50000;

  static String baseUri = '$scheme://$host';

  // Auth Endpoints
  static const String login = '/api/v1/auth/login';
  static const String register = '/api/v1/auth/register';
  static const String socialAuth = '/api/v1/auth/social';
  static const String resetPassword = '/api/v1/auth/reset-password';

  // Dashboard Endpoints
  static const String dashboardFeed = '/api/v1/dashboard/feed';
  static const String dashboardReviewQueue = '/api/v1/dashboard/review-queue';
  static const String dashboardStartExam = '/api/v1/dashboard/start-exam';
}

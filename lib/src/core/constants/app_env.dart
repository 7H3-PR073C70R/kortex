import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  static String get apiBaseURL =>
      dotenv.isInitialized ? (dotenv.env['API_BASE_URL'] ?? '') : '';
  static String get apiKey => dotenv.isInitialized
      ? (dotenv.env['API_KEY'] ?? dotenv.env['SUPABASE_ANON_KEY'] ?? '')
      : '';
  static String get liveKitUrl {
    if (!dotenv.isInitialized) return '';
    final val = dotenv.env['LIVEKIT_URL'];
    assert(val != null && val.isNotEmpty, 'LIVEKIT_URL must be set in .env');
    return val ?? '';
  }

  static String get revenueCatWebApiKey =>
      dotenv.isInitialized ? (dotenv.env['REVENUECAT_WEB_API_KEY'] ?? '') : '';
  static String get revenueCatGoogleApiKey => dotenv.isInitialized
      ? (dotenv.env['REVENUECAT_GOOGLE_API_KEY'] ?? '')
      : '';
  static String get revenueCatAppleApiKey => dotenv.isInitialized
      ? (dotenv.env['REVENUECAT_APPLE_API_KEY'] ?? '')
      : '';

  static String get r2PublicDomain {
    if (!dotenv.isInitialized) return '';
    final val = dotenv.env['R2_PUBLIC_DOMAIN'];
    assert(
      val != null && val.isNotEmpty,
      'R2_PUBLIC_DOMAIN must be set in .env',
    );
    return val ?? '';
  }
}

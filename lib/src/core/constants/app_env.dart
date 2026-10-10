import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  static const String _defaultApiBaseUrl =
      'https://mongizqfijuhycdxltpw.supabase.co';
  static const String _defaultApiKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1vbmdpenFmaWp1aHljZHhsdHB3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgxMjk0ODksImV4cCI6MjEwMzcwNTQ4OX0.WdbPP0hWHnm2P7IWOOPOPv8emJsNql2jf5z6XnPa0wg';
  static const String _defaultLiveKitUrl =
      'wss://kortexify-nj9viqjp.livekit.cloud';
  static const String _defaultR2Domain =
      'https://pub-48d140cd04784f4b93fd2941eedd7223.r2.dev';

  static String get apiBaseURL {
    const defineVal = String.fromEnvironment('API_BASE_URL');
    if (defineVal.isNotEmpty) return defineVal.trim();
    if (dotenv.isInitialized) {
      final val = dotenv.env['API_BASE_URL'];
      if (val != null && val.trim().isNotEmpty) return val.trim();
    }
    return _defaultApiBaseUrl;
  }

  static String get apiKey {
    const key = String.fromEnvironment('API_KEY');
    const anon = String.fromEnvironment('SUPABASE_ANON_KEY');
    final defineVal = key.isNotEmpty ? key : anon;
    if (defineVal.isNotEmpty) return defineVal.trim();
    if (dotenv.isInitialized) {
      final val = dotenv.env['API_KEY'] ?? dotenv.env['SUPABASE_ANON_KEY'];
      if (val != null && val.trim().isNotEmpty) return val.trim();
    }
    return _defaultApiKey;
  }

  static String get liveKitUrl {
    const defineVal = String.fromEnvironment('LIVEKIT_URL');
    if (defineVal.isNotEmpty) return defineVal.trim();
    if (dotenv.isInitialized) {
      final val = dotenv.env['LIVEKIT_URL'];
      if (val != null && val.trim().isNotEmpty) return val.trim();
    }
    return _defaultLiveKitUrl;
  }

  static String get revenueCatWebApiKey {
    const defineVal = String.fromEnvironment('REVENUECAT_WEB_API_KEY');
    if (defineVal.isNotEmpty) return defineVal.trim();
    return dotenv.isInitialized ? (dotenv.env['REVENUECAT_WEB_API_KEY'] ?? '') : '';
  }

  static String get revenueCatGoogleApiKey {
    const defineVal = String.fromEnvironment('REVENUECAT_GOOGLE_API_KEY');
    if (defineVal.isNotEmpty) return defineVal.trim();
    return dotenv.isInitialized ? (dotenv.env['REVENUECAT_GOOGLE_API_KEY'] ?? '') : '';
  }

  static String get revenueCatAppleApiKey {
    const defineVal = String.fromEnvironment('REVENUECAT_APPLE_API_KEY');
    if (defineVal.isNotEmpty) return defineVal.trim();
    return dotenv.isInitialized ? (dotenv.env['REVENUECAT_APPLE_API_KEY'] ?? '') : '';
  }

  static String get r2PublicDomain {
    const defineVal = String.fromEnvironment('R2_PUBLIC_DOMAIN');
    if (defineVal.isNotEmpty) return defineVal.trim();
    if (dotenv.isInitialized) {
      final val = dotenv.env['R2_PUBLIC_DOMAIN'];
      if (val != null && val.trim().isNotEmpty) return val.trim();
    }
    return _defaultR2Domain;
  }
}

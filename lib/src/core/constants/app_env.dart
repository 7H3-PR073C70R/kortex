import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  static String get apiBaseURL =>
      dotenv.isInitialized ? (dotenv.env['API_BASE_URL'] ?? '') : '';
  static String get apiKey => dotenv.isInitialized
      ? (dotenv.env['API_KEY'] ?? dotenv.env['SUPABASE_ANON_KEY'] ?? '')
      : '';
  static String get liveKitUrl => dotenv.isInitialized
      ? (dotenv.env['LIVEKIT_URL'] ??
          'wss://kortexify-nj9viqjp.livekit.cloud')
      : 'wss://kortexify-nj9viqjp.livekit.cloud';
}

import 'package:supabase_flutter/supabase_flutter.dart';

/// Helper to safely access Supabase client without throwing assertion errors
/// if the client has not been initialized (e.g., in test or offline modes).
class SupabaseSafe {
  SupabaseSafe._();

  static SupabaseClient? get client {
    try {
      return Supabase.instance.client;
    } on Object {
      return null;
    }
  }

  static User? get currentUser {
    try {
      return Supabase.instance.client.auth.currentUser;
    } on Object {
      return null;
    }
  }

  static bool get isInitialized {
    try {
      // Accessing instance will throw if not initialized
      final _ = Supabase.instance;
      return true;
    } on Object {
      return false;
    }
  }
}

import 'package:kortex/src/core/services/supabase_safe_helper.dart';
import 'package:kortex/src/features/auth/data/client/supabase_auth_client.dart';
import 'package:kortex/src/features/auth/data/data_sources/auth_remote_data_source.dart';
import 'package:kortex/src/features/auth/data/models/auth_request_model.dart';
import 'package:kortex/src/features/auth/data/models/course_track_model.dart';
import 'package:kortex/src/features/auth/data/models/user_model.dart';
import 'package:kortex/src/features/auth/data/models/user_profile_model.dart';
import 'package:kortex/src/services/user_storage_service.dart';

/// Implementation of [AuthRemoteDataSource] relying on [SupabaseAuthClient]
/// with live Supabase SDK synchronization.
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl({
    required SupabaseAuthClient authClient,
    required UserStorageService userStorage,
  })  : _authClient = authClient,
        _userStorage = userStorage;

  final SupabaseAuthClient _authClient;
  final UserStorageService _userStorage;

  @override
  Future<UserModel> login(LoginRequestModel request) {
    return _authClient.login(request);
  }

  @override
  Future<UserModel> register(RegisterRequestModel request) {
    return _authClient.register(request);
  }

  @override
  Future<UserModel> loginWithSocial(SocialAuthRequestModel request) {
    return _authClient.loginWithSocial(request);
  }

  @override
  Future<void> resetPassword(ResetPasswordRequestModel request) {
    return _authClient.resetPassword(request);
  }

  @override
  Future<void> sendMagicLink(String email) {
    return _authClient.sendMagicLink(email: email);
  }

  @override
  Future<UserModel> verifyOtp({
    required String email,
    required String token,
    String type = 'signup',
  }) {
    return _authClient.verifyOtp(
      email: email,
      token: token,
      type: type,
    );
  }

  @override
  Future<UserProfileModel> fetchUserProfile() async {
    final client = SupabaseSafe.client;
    final user = SupabaseSafe.currentUser;
    if (client != null && user != null) {
      try {
        final res = await client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (res != null) {
          final map = Map<String, dynamic>.from(res);
          map['email'] ??= user.email;
          map['display_name'] ??= user.userMetadata?['display_name'] ??
              user.userMetadata?['full_name'];
          return UserProfileModel.fromJson(map);
        } else {
          return UserProfileModel(
            id: user.id,
            email: user.email ?? '',
            displayName: user.userMetadata?['display_name'] as String? ??
                user.userMetadata?['full_name'] as String?,
          );
        }
      } on Object {
        // Fall back to current user info if profile query fails
        if (user.email != null) {
          return UserProfileModel(
            id: user.id,
            email: user.email!,
            displayName: user.userMetadata?['display_name'] as String? ??
                user.userMetadata?['full_name'] as String?,
          );
        }
      }
    }

    final token = _userStorage.getToken() ?? '';
    final map = await _authClient.fetchUserProfile(authToken: token);
    if (map.isEmpty) {
      return const UserProfileModel(
        id: '',
        email: '',
      );
    }
    return UserProfileModel.fromJson(map);
  }

  @override
  Future<UserProfileModel> updateUserProfileTrackAndGoal({
    required String track,
    required int dailyTarget,
    double retentionBenchmark = 0.85,
    bool isOnboarded = true,
  }) async {
    final client = SupabaseSafe.client;
    final user = SupabaseSafe.currentUser;
    if (client != null && user != null) {
      try {
        final res = await client
            .from('profiles')
            .update({
              'target_track': track,
              'daily_card_target': dailyTarget,
              'retention_benchmark': retentionBenchmark,
              'is_onboarded': isOnboarded,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', user.id)
            .select()
            .maybeSingle();

        if (res != null) {
          final map = Map<String, dynamic>.from(res);
          map['email'] ??= user.email;
          map['display_name'] ??= user.userMetadata?['display_name'] ??
              user.userMetadata?['full_name'];
          return UserProfileModel.fromJson(map);
        }
      } on Object {
        // Fall back to REST endpoint
      }
    }

    final token = _userStorage.getToken() ?? '';
    final map = await _authClient.updateUserProfileTrackAndGoal(
      track: track,
      dailyTarget: dailyTarget,
      retentionBenchmark: retentionBenchmark,
      isOnboarded: isOnboarded,
      authToken: token,
    );
    return UserProfileModel.fromJson(map);
  }

  @override
  Future<List<CourseTrackModel>> fetchCourseTracks() async {
    final list = await _authClient.fetchCourseTracks();
    if (list.isEmpty) {
      return const [
        CourseTrackModel(
          id: 'WAEC',
          name: 'WAEC / WASSCE',
          description:
              'Senior secondary core curriculum (Sciences, Arts & Commercial)',
          iconName: 'school',
          examCountdownDays: 68,
        ),
        CourseTrackModel(
          id: 'JAMB',
          name: 'JAMB / UTME',
          description:
              'High-speed CBT drills, subject combinations & past papers',
          iconName: 'timer',
          defaultDailyTarget: 25,
          examCountdownDays: 45,
        ),
        CourseTrackModel(
          id: 'SAT',
          name: 'SAT',
          description:
              'Standardized Reading, Writing, Math & problem solving',
          iconName: 'calculate',
          examCountdownDays: 90,
        ),
        CourseTrackModel(
          id: 'TOEFL',
          name: 'TOEFL iBT',
          description:
              'Academic English Reading, Listening, Speaking & Writing',
          iconName: 'record_voice_over',
          examCountdownDays: 50,
        ),
        CourseTrackModel(
          id: 'IELTS',
          name: 'IELTS',
          description:
              'International English language proficiency (Academic & General)',
          iconName: 'translate',
          examCountdownDays: 50,
        ),
        CourseTrackModel(
          id: 'Medicine',
          name: 'Medicine & Health Sciences',
          description:
              'Anatomy, Physiology, Pharmacology, Pathology & Clinical Skills',
          iconName: 'medical_services',
          defaultDailyTarget: 35,
          examCountdownDays: 40,
        ),
        CourseTrackModel(
          id: 'Law',
          name: 'Law & Jurisprudence',
          description:
              'Constitutional, Criminal, Torts, Commercial Law & Jurisprudence',
          iconName: 'gavel',
          defaultDailyTarget: 25,
          examCountdownDays: 45,
        ),
        CourseTrackModel(
          id: 'Engineering',
          name: 'Engineering & Technology',
          description:
              'Mechanical, Electrical, Civil, Software & Applied Mathematics',
          iconName: 'engineering',
          defaultDailyTarget: 30,
          examCountdownDays: 35,
        ),
        CourseTrackModel(
          id: 'Business',
          name: 'Business & Economics',
          description:
              'Accounting, Finance, Economics, Marketing & Management',
          iconName: 'trending_up',
          defaultDailyTarget: 25,
          examCountdownDays: 40,
        ),
        CourseTrackModel(
          id: 'Humanities',
          name: 'Arts & Humanities',
          description:
              'Literature, History, Philosophy, Linguistics & Mass Comm',
          iconName: 'menu_book',
          examCountdownDays: 45,
        ),
        CourseTrackModel(
          id: 'ComputerScience',
          name: 'Computer Science & AI',
          description:
              'Algorithms, Data Structures, Operating Systems & Networks',
          iconName: 'terminal',
          defaultDailyTarget: 30,
          examCountdownDays: 30,
        ),
      ];
    }
    return list.map(CourseTrackModel.fromJson).toList();
  }
}

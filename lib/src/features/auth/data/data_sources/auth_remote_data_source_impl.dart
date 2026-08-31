import 'package:kortex/src/features/auth/data/client/supabase_auth_client.dart';
import 'package:kortex/src/features/auth/data/data_sources/auth_remote_data_source.dart';
import 'package:kortex/src/features/auth/data/models/auth_request_model.dart';
import 'package:kortex/src/features/auth/data/models/course_track_model.dart';
import 'package:kortex/src/features/auth/data/models/user_model.dart';
import 'package:kortex/src/features/auth/data/models/user_profile_model.dart';
import 'package:kortex/src/services/user_storage_service.dart';

/// Implementation of [AuthRemoteDataSource] relying on [SupabaseAuthClient].
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
          description: 'Senior secondary school core curriculum & STEM exams',
          iconName: 'school',
          examCountdownDays: 68,
        ),
        CourseTrackModel(
          id: 'JAMB',
          name: 'JAMB / UTME',
          description: 'High-speed multiple choice drills & past questions',
          iconName: 'timer',
          defaultDailyTarget: 25,
          examCountdownDays: 45,
        ),
        CourseTrackModel(
          id: 'SAT',
          name: 'SAT STEM',
          description: 'Standardized math, geometry, and problem solving',
          iconName: 'calculate',
          defaultDailyTarget: 15,
          examCountdownDays: 90,
        ),
        CourseTrackModel(
          id: 'University',
          name: 'University STEM',
          description: 'Engineering, physics, calculus, and biochemistry',
          iconName: 'biotech',
          defaultDailyTarget: 30,
          examCountdownDays: 30,
        ),
      ];
    }
    return list.map(CourseTrackModel.fromJson).toList();
  }
}

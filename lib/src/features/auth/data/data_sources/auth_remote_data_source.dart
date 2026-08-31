import 'package:kortex/src/features/auth/data/models/auth_request_model.dart';
import 'package:kortex/src/features/auth/data/models/course_track_model.dart';
import 'package:kortex/src/features/auth/data/models/user_model.dart';
import 'package:kortex/src/features/auth/data/models/user_profile_model.dart';

/// Abstract remote data source contract for authentication and profile.
abstract class AuthRemoteDataSource {
  Future<UserModel> login(LoginRequestModel request);
  Future<UserModel> register(RegisterRequestModel request);
  Future<UserModel> loginWithSocial(SocialAuthRequestModel request);
  Future<void> resetPassword(ResetPasswordRequestModel request);
  Future<void> sendMagicLink(String email);
  Future<UserModel> verifyOtp({
    required String email,
    required String token,
    String type = 'signup',
  });
  Future<UserProfileModel> fetchUserProfile();
  Future<UserProfileModel> updateUserProfileTrackAndGoal({
    required String track,
    required int dailyTarget,
    double retentionBenchmark = 0.85,
    bool isOnboarded = true,
  });
  Future<List<CourseTrackModel>> fetchCourseTracks();
}

import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/features/auth/data/client/auth_api_client.dart';
import 'package:kortex/src/features/auth/data/data_sources/auth_remote_data_source.dart';
import 'package:kortex/src/features/auth/data/models/auth_request_model.dart';
import 'package:kortex/src/features/auth/data/models/course_track_model.dart';
import 'package:kortex/src/features/auth/data/models/user_model.dart';
import 'package:kortex/src/features/auth/data/models/user_profile_model.dart';

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl({
    required AuthApiClient authClient,
    required UserStorageService userStorage,
  })  : _authClient = authClient,
        _userStorage = userStorage;

  final AuthApiClient _authClient;
  final UserStorageService _userStorage;

  @override
  Future<UserModel> login(LoginRequestModel request) async {
    final response = await _authClient.login(request);
    if (response.token != null && response.token!.isNotEmpty) {
      await _userStorage.saveToken(response.token!);
    }
    if (response.refreshToken != null && response.refreshToken!.isNotEmpty) {
      await _userStorage.saveRefreshToken(response.refreshToken!);
    }
    return response;
  }

  @override
  Future<UserModel> register(RegisterRequestModel request) async {
    final response = await _authClient.register(request.toJson());
    if (response.token != null && response.token!.isNotEmpty) {
      await _userStorage.saveToken(response.token!);
    }
    if (response.refreshToken != null && response.refreshToken!.isNotEmpty) {
      await _userStorage.saveRefreshToken(response.refreshToken!);
    }
    return response;
  }

  @override
  Future<UserModel> loginWithSocial(SocialAuthRequestModel request) async {
    final response = await _authClient.loginWithSocial(request);
    if (response.token != null && response.token!.isNotEmpty) {
      await _userStorage.saveToken(response.token!);
    }
    if (response.refreshToken != null && response.refreshToken!.isNotEmpty) {
      await _userStorage.saveRefreshToken(response.refreshToken!);
    }
    return response;
  }

  @override
  Future<void> resetPassword(ResetPasswordRequestModel request) async {
    await _authClient.resetPassword(request);
  }

  @override
  Future<void> sendMagicLink(String email) async {
    await _authClient.sendMagicLink({'email': email});
  }

  @override
  Future<UserModel> verifyOtp({
    required String email,
    required String token,
    String type = 'signup',
  }) async {
    final response = await _authClient.verifyOtp({
      'email': email,
      'token': token,
      'type': type,
    });
    if (response.token != null && response.token!.isNotEmpty) {
      await _userStorage.saveToken(response.token!);
    }
    if (response.refreshToken != null && response.refreshToken!.isNotEmpty) {
      await _userStorage.saveRefreshToken(response.refreshToken!);
    }
    return response;
  }

  @override
  Future<UserProfileModel> fetchUserProfile() async {
    final res = await _authClient.fetchUserProfile(
      {
        'select': '*',
        'limit': '1',
      },
    );
    final rawData = res.data;
    if (rawData is List && rawData.isNotEmpty) {
      return UserProfileModel.fromJson(rawData.first as Map<String, dynamic>);
    }
    return const UserProfileModel(
      id: '',
      email: '',
    );
  }

  @override
  Future<UserProfileModel> updateUserProfileTrackAndGoal({
    required String track,
    required int dailyTarget,
    double retentionBenchmark = 0.85,
    bool isOnboarded = true,
  }) async {
    final res = await _authClient.updateUserProfileTrackAndGoal(
      {
        'p_target_track': track,
        'p_daily_card_target': dailyTarget,
        'p_retention_benchmark': retentionBenchmark,
        'p_is_onboarded': isOnboarded,
      },
    );
    final rawData = res.data;
    if (rawData is Map<String, dynamic>) {
      return UserProfileModel.fromJson(rawData);
    }
    return const UserProfileModel(id: '', email: '');
  }

  @override
  Future<List<CourseTrackModel>> fetchCourseTracks() async {
    final res = await _authClient.fetchCourseTracks({'select': '*'});
    final rawData = res.data;
    if (rawData is List && rawData.isNotEmpty) {
      return rawData
          .map((e) => CourseTrackModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
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
        description: 'Standardized Reading, Writing, Math & problem solving',
        iconName: 'calculate',
        examCountdownDays: 90,
      ),
      CourseTrackModel(
        id: 'TOEFL',
        name: 'TOEFL iBT',
        description: 'Academic English Reading, Listening, Speaking & Writing',
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
        description: 'Pre-clinical anatomy, physiology & pharmacology review',
        iconName: 'medical_services',
        defaultDailyTarget: 30,
        examCountdownDays: 60,
      ),
      CourseTrackModel(
        id: 'Engineering',
        name: 'Engineering & Physical Sciences',
        description: 'Engineering mathematics, thermodynamics & coding theory',
        iconName: 'engineering',
        defaultDailyTarget: 25,
        examCountdownDays: 60,
      ),
      CourseTrackModel(
        id: 'Law',
        name: 'Law & Jurisprudence',
        description:
            'Constitutional law, torts, criminal law cases & precedents',
        iconName: 'gavel',
        defaultDailyTarget: 20,
        examCountdownDays: 60,
      ),
      CourseTrackModel(
        id: 'General',
        name: 'General University Prep',
        description: 'General studies (GST), research methods & critical logic',
        iconName: 'auto_stories',
        examCountdownDays: 30,
      ),
    ];
  }
}

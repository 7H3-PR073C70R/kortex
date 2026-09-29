import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/services/study_activity_tracker.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/study_rooms/presentation/bloc/study_circle_cubit.dart';
import 'package:mocktail/mocktail.dart';

class MockCommunityRepository extends Mock implements CommunityRepository {}

class MockStudyCircleCubit extends Mock implements StudyCircleCubit {}

void main() {
  late MockCommunityRepository mockCommunityRepo;
  late MockStudyCircleCubit mockStudyCircleCubit;
  late StudyActivityTracker tracker;

  setUpAll(() {
    registerFallbackValue('');
  });

  setUp(() async {
    await GetIt.instance.reset();
    mockCommunityRepo = MockCommunityRepository();
    mockStudyCircleCubit = MockStudyCircleCubit();

    when(
      () => mockCommunityRepo.recordPodFocusMinutes(
        circleId: any(named: 'circleId'),
        minutes: any(named: 'minutes'),
        activityType: any(named: 'activityType'),
      ),
    ).thenAnswer((_) async => const Right({'success': true, 'updated_circles_count': 1}));

    when(() => mockStudyCircleCubit.loadStudyCircles(track: any(named: 'track')))
        .thenAnswer((_) async {});

    GetIt.instance.registerSingleton<CommunityRepository>(mockCommunityRepo);
    GetIt.instance.registerSingleton<StudyCircleCubit>(mockStudyCircleCubit);

    tracker = StudyActivityTrackerImpl(repository: mockCommunityRepo);
  });

  group('StudyActivityTracker Unit Tests', () {
    test('returns 0 minutes when session duration is under 15 seconds', () async {
      final recordedMins = await tracker.recordActivityCompletion(
        durationSeconds: 10,
        activityType: 'quiz',
      );

      expect(recordedMins, equals(0));
      verifyNever(
        () => mockCommunityRepo.recordPodFocusMinutes(
          circleId: any(named: 'circleId'),
          minutes: any(named: 'minutes'),
          activityType: any(named: 'activityType'),
        ),
      );
    });

    test('rounds duration between 15s and 89s to 1 minute minimum', () async {
      final recordedMins = await tracker.recordActivityCompletion(
        durationSeconds: 45,
        activityType: 'quiz',
      );

      expect(recordedMins, equals(1));
      verify(
        () => mockCommunityRepo.recordPodFocusMinutes(
          circleId: '',
          minutes: 1,
          activityType: 'quiz',
        ),
      ).called(1);

      verify(() => mockStudyCircleCubit.loadStudyCircles()).called(1);
    });

    test('rounds 120s duration to 2 minutes for 1v1 duel', () async {
      final recordedMins = await tracker.recordActivityCompletion(
        durationSeconds: 120,
        activityType: 'duel',
      );

      expect(recordedMins, equals(2));
      verify(
        () => mockCommunityRepo.recordPodFocusMinutes(
          circleId: '',
          minutes: 2,
          activityType: 'duel',
        ),
      ).called(1);

      verify(() => mockStudyCircleCubit.loadStudyCircles()).called(1);
    });

    test('rounds 300s duration to 5 minutes for flashcard deck study', () async {
      final recordedMins = await tracker.recordActivityCompletion(
        durationSeconds: 300,
        activityType: 'deck',
      );

      expect(recordedMins, equals(5));
      verify(
        () => mockCommunityRepo.recordPodFocusMinutes(
          circleId: '',
          minutes: 5,
          activityType: 'deck',
        ),
      ).called(1);
    });

    test('handles failure from community repository gracefully without throwing', () async {
      when(
        () => mockCommunityRepo.recordPodFocusMinutes(
          circleId: any(named: 'circleId'),
          minutes: any(named: 'minutes'),
          activityType: any(named: 'activityType'),
        ),
      ).thenAnswer(
        (_) async => const Left(ServerFailure(message: 'Database error')),
      );

      final recordedMins = await tracker.recordActivityCompletion(
        durationSeconds: 180,
        activityType: 'cbt',
      );

      expect(recordedMins, equals(3));
    });
  });
}

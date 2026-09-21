import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/notification_service.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/domain/repositories/planner_repository.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/planner/presentation/pages/exam_timetable_page.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockPlannerRepository extends Mock implements PlannerRepository {}

class MockLocalStorageService extends Mock implements LocalStorageService {}

class MockNotificationService extends Mock implements NotificationService {}

void main() {
  final locator = GetIt.instance;
  late MockPlannerRepository mockRepository;
  late MockLocalStorageService mockStorage;
  late MockNotificationService mockNotification;
  late CramPlannerCubit cubit;

  final tExam = ExamEventEntity(
    id: 'exam-waec-physics',
    userId: 'usr-1',
    examName: 'WAEC Physics',
    targetDate: DateTime.now().add(const Duration(days: 14)),
    subjectTrack: 'WAEC',
    totalCardsCount: 150,
    dailyTarget: 12,
  );

  setUp(() {
    locator.pushNewScope();
    mockRepository = MockPlannerRepository();
    mockStorage = MockLocalStorageService();
    mockNotification = MockNotificationService();

    when(
      () => mockStorage.getPreference(key: any(named: 'key')),
    ).thenReturn('true');

    cubit = CramPlannerCubit(plannerRepository: mockRepository);

    locator
      ..registerSingleton<CramPlannerCubit>(cubit)
      ..registerSingleton<LocalStorageService>(mockStorage)
      ..registerSingleton<NotificationService>(mockNotification);
  });

  tearDown(() async {
    await cubit.close();
    await locator.popScope();
  });

  Widget createTestApp() {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ExamTimetablePage(),
    );
  }

  group('ExamTimetablePage Workstation & Motion Tests', () {
    testWidgets('renders empty state when no active exams exist', (
      tester,
    ) async {
      when(
        () => mockRepository.getActiveExams(),
      ).thenAnswer((_) async => const Right([]));

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Exam Timetable'), findsOneWidget);
      expect(find.text('No Exams Scheduled Yet'), findsOneWidget);
      expect(find.text('Add First Exam'), findsOneWidget);
    });

    testWidgets(
      'renders hero countdown, calibration graph, and tracked exams card when exams exist',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        when(
          () => mockRepository.getActiveExams(),
        ).thenAnswer((_) async => Right([tExam]));

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        expect(find.text('Exam Timetable'), findsOneWidget);
        expect(find.text('ACTIVE TIMETABLE'), findsOneWidget);
        expect(find.text('WAEC Physics'), findsNWidgets(2)); // hero + row card
        expect(find.text('Study Desk Calibration'), findsOneWidget);
        expect(find.text('Tracked Exams (1)'), findsOneWidget);
        expect(find.text('Timetable & Study Alerts'), findsOneWidget);
      },
    );

    testWidgets('toggles notification preference switches', (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      when(
        () => mockRepository.getActiveExams(),
      ).thenAnswer((_) async => Right([tExam]));
      when(
        () => mockStorage.savePreference(
          key: any(named: 'key'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final switchTiles = find.byType(SwitchListTile);
      expect(switchTiles, findsNWidgets(2));

      await tester.tap(switchTiles.first);
      await tester.pumpAndSettle();

      verify(
        () => mockStorage.savePreference(
          key: '__kortex_daily_exam_reminders__',
          data: 'false',
        ),
      ).called(1);
    });
  });
}

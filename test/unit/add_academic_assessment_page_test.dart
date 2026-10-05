import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/planner/data/repositories/planner_repository_impl.dart';
import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/domain/repositories/planner_repository.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/planner/presentation/pages/add_academic_assessment_page.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

void main() {
  setUp(() async {
    await locator.reset();
    locator
      ..registerLazySingleton<LocalStorageService>(_FakeLocalStorageService.new)
      ..registerLazySingleton<PlannerRepository>(
        () => PlannerRepositoryImpl(
          storageService: locator<LocalStorageService>(),
        ),
      )
      ..registerLazySingleton<CramPlannerCubit>(
        () => CramPlannerCubit(
          plannerRepository: locator<PlannerRepository>(),
        ),
      );
  });

  tearDown(() async {
    await locator.reset();
  });

  Widget createWidgetUnderTest(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<CramPlannerCubit>.value(
        value: locator<CramPlannerCubit>(),
        child: child,
      ),
    );
  }

  group('AddAcademicAssessmentPage Unit & Widget Tests', () {
    testWidgets('Renders Add Academic Assessment page with all required controls', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(const AddAcademicAssessmentPage()),
      );

      await tester.pumpAndSettle();

      expect(find.text('Add Academic Assessment'), findsOneWidget);
      expect(find.text('Assessment Type'), findsOneWidget);
      expect(find.text('Final Exam'), findsOneWidget);
      expect(find.text('Quiz'), findsOneWidget);
      expect(find.text('Test / CA'), findsOneWidget);
      expect(find.text('Mid-Term'), findsOneWidget);
      expect(find.text('Mock Exam'), findsOneWidget);
    });

    testWidgets('Preselects initial exam when editing existing assessment', (tester) async {
      final initialExam = ExamEventEntity(
        id: 'exam-99',
        userId: 'user-1',
        examName: 'Advanced Thermodynamics Midterm',
        targetDate: DateTime.now().add(const Duration(days: 14)),
        subjectTrack: 'MECH 301',
        assessmentType: AssessmentType.midterm,
        scopedTopics: const ['Heat Transfer', 'Entropy'],
        weightPercent: 0.30,
      );

      await tester.pumpWidget(
        createWidgetUnderTest(AddAcademicAssessmentPage(initialExam: initialExam)),
      );

      await tester.pumpAndSettle();

      expect(find.text('Edit Assessment'), findsOneWidget);
      expect(find.text('Advanced Thermodynamics Midterm'), findsOneWidget);
      expect(find.text('Heat Transfer'), findsOneWidget);
      expect(find.text('Entropy'), findsOneWidget);
    });
  });
}

class _FakeLocalStorageService implements LocalStorageService {
  final Map<String, String> storage = {};

  @override
  Future<void> initDB() async {}

  @override
  String? getPreference({required String key}) => storage[key];

  @override
  Future<void> savePreference({required String key, required String data}) async {
    storage[key] = data;
  }

  @override
  Future<void> deletePreference({required String key}) async {
    storage.remove(key);
  }

  @override
  Future<void> clearAllPreferences() async {
    storage.clear();
  }
}

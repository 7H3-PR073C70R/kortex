import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/resume_active_cbt_exam_banner.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_cubit.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

class InMemoryLocalStorageService implements LocalStorageService {
  final Map<String, String> _data = {};

  @override
  Future<void> initDB() async {}

  @override
  String? getPreference({required String key}) => _data[key];

  @override
  Future<void> savePreference({
    required String key,
    required String data,
  }) async {
    _data[key] = data;
  }

  @override
  Future<void> deletePreference({required String key}) async {
    _data.remove(key);
  }

  @override
  Future<void> clearAllPreferences() async {
    _data.clear();
  }
}

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryLocalStorageService storage;

  setUp(() async {
    storage = InMemoryLocalStorageService();
    if (locator.isRegistered<LocalStorageService>()) {
      await locator.unregister<LocalStorageService>();
    }
    locator.registerSingleton<LocalStorageService>(storage);
  });

  tearDown(() async {
    if (locator.isRegistered<LocalStorageService>()) {
      await locator.unregister<LocalStorageService>();
    }
  });

  group('ResumeActiveCbtExamBanner Widget Tests', () {
    testWidgets('renders SizedBox.shrink when no active session exists', (tester) async {
      await tester.pumpWidget(
        createTestApp(const ResumeActiveCbtExamBanner()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResumeActiveCbtExamBanner), findsOneWidget);
      expect(find.text('Active CBT Exam in Progress'), findsNothing);
      expect(find.text('Resume Exam'), findsNothing);
    });

    testWidgets('renders active banner with real remaining countdown and question count', (tester) async {
      final deadline = DateTime.now().add(const Duration(minutes: 25));
      final payload = jsonEncode({
        'quizTitle': 'JAMB Government 2026 Mock',
        'currentIndex': 0,
        'startedAt': DateTime.now().toIso8601String(),
        'deadline': deadline.toIso8601String(),
        'durationMinutes': 30,
        'assessmentMode': 'examSimulationMode',
        'questions': [
          {
            'id': 'q-1',
            'prompt': 'Prompt 1',
            'type': 'multipleChoice',
            'options': ['A', 'B'],
            'correct_answer': 'A',
            'explanation': 'Exp',
            'sub_topic': 'Gov',
            'user_selected_answer': 'A',
            'is_answered': true,
          },
          {
            'id': 'q-2',
            'prompt': 'Prompt 2',
            'type': 'multipleChoice',
            'options': ['C', 'D'],
            'correct_answer': 'C',
            'explanation': 'Exp',
            'sub_topic': 'Gov',
            'user_selected_answer': null,
            'is_answered': false,
          },
        ],
      });

      await storage.savePreference(
        key: QuizSessionCubit.activeCbtSessionStorageKey,
        data: payload,
      );

      await tester.pumpWidget(
        createTestApp(const ResumeActiveCbtExamBanner()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active CBT Exam in Progress'), findsOneWidget);
      expect(find.text('JAMB Government 2026 Mock'), findsOneWidget);
      expect(find.text('1/2 answered'), findsOneWidget);
      expect(find.text('Resume Exam'), findsOneWidget);
      expect(find.textContaining('remaining'), findsOneWidget);
    });

    testWidgets('renders expired state when deadline is in the past', (tester) async {
      final deadline = DateTime.now().subtract(const Duration(minutes: 5));
      final payload = jsonEncode({
        'quizTitle': 'Expired Exam Mock',
        'currentIndex': 0,
        'startedAt':
            DateTime.now().subtract(const Duration(minutes: 35)).toIso8601String(),
        'deadline': deadline.toIso8601String(),
        'durationMinutes': 30,
        'assessmentMode': 'examSimulationMode',
        'questions': [
          {
            'id': 'q-1',
            'prompt': 'Prompt 1',
            'type': 'multipleChoice',
            'options': ['A', 'B'],
            'correct_answer': 'A',
            'explanation': 'Exp',
            'sub_topic': 'Gov',
            'user_selected_answer': 'A',
            'is_answered': true,
          },
        ],
      });

      await storage.savePreference(
        key: QuizSessionCubit.activeCbtSessionStorageKey,
        data: payload,
      );

      await tester.pumpWidget(
        createTestApp(const ResumeActiveCbtExamBanner()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active CBT Exam • Time Expired'), findsOneWidget);
      expect(find.text('Expired Exam Mock'), findsOneWidget);
      expect(find.text('Time Expired'), findsOneWidget);
      expect(find.text('Submit Exam'), findsOneWidget);
    });

    testWidgets('discard button dismisses the banner immediately', (tester) async {
      final deadline = DateTime.now().add(const Duration(minutes: 10));
      final payload = jsonEncode({
        'quizTitle': 'JAMB Chemistry Mock',
        'currentIndex': 0,
        'startedAt': DateTime.now().toIso8601String(),
        'deadline': deadline.toIso8601String(),
        'durationMinutes': 10,
        'assessmentMode': 'examSimulationMode',
        'questions': [
          {
            'id': 'q-1',
            'prompt': 'Prompt 1',
            'type': 'multipleChoice',
            'options': ['A', 'B'],
            'correct_answer': 'A',
            'explanation': 'Exp',
            'sub_topic': 'Chem',
            'user_selected_answer': null,
            'is_answered': false,
          },
        ],
      });

      await storage.savePreference(
        key: QuizSessionCubit.activeCbtSessionStorageKey,
        data: payload,
      );

      await tester.pumpWidget(
        createTestApp(const ResumeActiveCbtExamBanner()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active CBT Exam in Progress'), findsOneWidget);

      // Tap discard
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Active CBT Exam in Progress'), findsNothing);
    });
  });
}

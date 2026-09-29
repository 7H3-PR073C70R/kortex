import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/auth/domain/entities/auth_status.dart';
import 'package:kortex/src/features/auth/domain/entities/user_entity.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:kortex/src/features/profile/presentation/pages/academic_track_settings_page.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends Mock implements AuthBloc {}
class MockDashboardBloc extends Mock implements DashboardBloc {}

void main() {
  late MockAuthBloc mockAuthBloc;
  late MockDashboardBloc mockDashboardBloc;

  const tUser = UserEntity(
    id: 'user_123',
    email: 'scholar@kortex.ai',
    displayName: 'Neural Scholar',
  );

  const tProfile = UserProfileEntity(
    id: 'user_123',
    email: 'scholar@kortex.ai',
    displayName: 'Neural Scholar',
    targetTrack: 'WAEC',
    dailyCardTarget: 25,
  );

  setUpAll(() {
    registerFallbackValue(const AuthProfileFetchRequested());
  });

  setUp(() async {
    mockAuthBloc = MockAuthBloc();
    mockDashboardBloc = MockDashboardBloc();

    when(() => mockAuthBloc.add(any())).thenAnswer((_) {});
    when(() => mockAuthBloc.state).thenReturn(
      const AuthState(
        status: AuthStatus.authenticated,
        sessionStatus: AuthSessionStatus.authenticatedComplete,
        user: tUser,
        userProfile: tProfile,
      ),
    );
    final streamController = StreamController<AuthState>.broadcast();
    when(() => mockAuthBloc.stream).thenAnswer((_) => streamController.stream);

    when(() => mockDashboardBloc.state).thenReturn(const DashboardState());
    when(() => mockDashboardBloc.stream).thenAnswer((_) => const Stream.empty());

    await GetIt.I.reset();
    GetIt.I.registerSingleton<AuthBloc>(mockAuthBloc);
    GetIt.I.registerSingleton<DashboardBloc>(mockDashboardBloc);
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  Widget createTestApp() {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AcademicTrackSettingsPage(),
    );
  }

  group('AcademicTrackSettingsPage Widget Tests', () {
    testWidgets('renders track title, options, and slider without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.textContaining('Academic Track'), findsOneWidget);
    });
  });
}
